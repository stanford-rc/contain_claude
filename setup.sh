#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_UNISON="2.54.0"
IMAGE_NAME="claude-sandbox"

echo "=== Claude Sandbox Setup ==="
echo

# Check Docker
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running. Start Docker Desktop and try again."
    exit 1
fi
echo "[ok] Docker is running"

# Install / verify unison on the host
if command -v unison &>/dev/null; then
    HOST_VER=$(unison -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "$HOST_VER" != "$REQUIRED_UNISON" ]]; then
        echo "WARNING: unison $HOST_VER is installed but $REQUIRED_UNISON is required."
        echo "         Run: brew uninstall unison && brew install unison"
        echo "         Then re-run this script."
        exit 1
    fi
    echo "[ok] unison $HOST_VER already installed"
else
    echo "Installing unison $REQUIRED_UNISON via brew..."
    brew install unison
    echo "[ok] unison installed"
fi

# Build Docker image
echo
echo "Building Docker image '$IMAGE_NAME' (this takes a few minutes the first time)..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
echo "[ok] Image '$IMAGE_NAME' built"

echo
echo "=== Setup complete ==="
echo
echo "Usage:"
echo "  You can export your Anthropic API key as an env var or just log-in with your account on launch."
echo "  contain_claude runs sync automatically every 3 seconds. sync_claude requires manual syncing, but will sync automatically on container close."
echo "  export ANTHROPIC_API_KEY=sk-ant-..."
echo "  Instructions in readme for aliasing command so you don't have to keep track of the .sh"
echo "  ./claude-sandbox.sh /path/to/your/project   # autosync to project dir"
echo "  ./claude-sync.sh /path/to/your/project      # manual sync"
echo
echo "Claude will run inside Docker with only that project directory accessible."
echo "Changes sync bidirectionally via unison every few seconds."
