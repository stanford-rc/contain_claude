#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="claude-sandbox"
SYNC_INTERVAL=3
WATCH_PID_FILE="/tmp/unison-watch-$$.pid"
UNISON_EXEC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/docker-unison-exec.sh"
AUTO_WATCH=true

usage() {
    echo "Usage: $(basename "$0") [--no-watch] PROJECT_DIR"
    echo
    echo "  PROJECT_DIR  Directory on your Mac to give Claude access to."
    echo "               Claude works on a container copy; changes sync bidirectionally."
    echo
    echo "  --no-watch   Skip automatic sync. Run 'claude-sync' manually instead."
    echo
    echo "  Auth: on first run, Claude will open a browser to log in."
    echo "        Credentials are saved to ~/.claude-sandbox/ and reused automatically."
    echo "        Set ANTHROPIC_API_KEY in your environment to use an API key instead."
    exit 1
}

cleanup() {
    echo
    echo "==> Shutting down..."

    if [[ -f "$WATCH_PID_FILE" ]]; then
        kill "$(cat "$WATCH_PID_FILE")" 2>/dev/null || true
        rm -f "$WATCH_PID_FILE"
    fi

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "==> Final sync container → host..."
        unison "$PROJECT_DIR" "ssh://$CONTAINER_NAME//workspace" \
            -sshcmd "$UNISON_EXEC" -sshargs "" \
            "${UNISON_OPTS[@]}" 2>/dev/null || true

        echo "==> Stopping container..."
        docker stop "$CONTAINER_NAME" &>/dev/null || true
        docker rm  "$CONTAINER_NAME" &>/dev/null || true
    fi

    echo "==> Done. Your files are in: $PROJECT_DIR"
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-watch) AUTO_WATCH=false; shift ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) break ;;
    esac
done

if [[ $# -lt 1 ]]; then usage; fi
PROJECT_DIR="$(cd "$1" && pwd)"
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "ERROR: '$1' is not a directory."
    exit 1
fi

SANDBOX_CLAUDE_DIR="$HOME/.claude-sandbox"
mkdir -p "$SANDBOX_CLAUDE_DIR"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    USE_API_KEY=false
else
    USE_API_KEY=true
fi

CONTAINER_NAME="claude-sandbox-$(basename "$PROJECT_DIR")"

UNISON_OPTS=(
    -perms 0 -dontchmod -batch -auto -times
    -ignore "Path .git"
    -ignore "Name .DS_Store"
    -ignore "Name node_modules"
    -ignore "Name __pycache__"
    -ignore "Name *.pyc" -ignore "Name *.pyo"
    -ignore "Name .env" -ignore "Name .env.local"
    -ignore "Name *.log"
    -prefer newer
)

if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "ERROR: Docker image '$IMAGE_NAME' not found. Run ./setup.sh first."
    exit 1
fi

docker rm -f "$CONTAINER_NAME" &>/dev/null || true

trap cleanup EXIT INT TERM

# --- Start container ---
echo "==> Starting sandbox container for: $PROJECT_DIR"
DOCKER_ARGS=(
    --name "$CONTAINER_NAME"
    -v "${SANDBOX_CLAUDE_DIR}:/home/sandbox/.claude"
)
if [[ "$USE_API_KEY" == true ]]; then
    DOCKER_ARGS+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
fi
docker run -d "${DOCKER_ARGS[@]}" "$IMAGE_NAME"

sleep 1

# --- Initial sync: host → container ---
echo "==> Initial sync: host → container..."
unison "$PROJECT_DIR" "ssh://$CONTAINER_NAME//workspace" \
    -sshcmd "$UNISON_EXEC" -sshargs "" \
    "${UNISON_OPTS[@]}"

# --- Watch loop (or manual mode) ---
if [[ "$AUTO_WATCH" == true ]]; then
    (
        while true; do
            sleep "$SYNC_INTERVAL"
            unison "$PROJECT_DIR" "ssh://$CONTAINER_NAME//workspace" \
                -sshcmd "$UNISON_EXEC" -sshargs "" \
                "${UNISON_OPTS[@]}" -silent 2>/dev/null || true
        done
    ) &
    echo $! > "$WATCH_PID_FILE"
    echo "==> Sync watch running (every ${SYNC_INTERVAL}s) — run 'claude-sync' to sync manually too."
else
    echo "==> Manual sync mode. Run 'claude-sync' to sync at any time."
fi

# --- Launch Claude inside container ---
echo
echo "==> Launching Claude Code inside sandbox."
echo "    Your project is at /workspace inside the container."
echo "    Press Ctrl+C or type 'exit' to stop Claude and sync final changes back."
echo
EXEC_ARGS=(-it -w /workspace)
if [[ "$USE_API_KEY" == true ]]; then
    EXEC_ARGS+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
fi
docker exec "${EXEC_ARGS[@]}" "$CONTAINER_NAME" bash -c "claude"
