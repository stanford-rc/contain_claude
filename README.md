# contain_claude

Runs Claude Code inside a Docker container so it can only touch the project directory you give it — no access to SSH keys, git credentials, or the rest of your filesystem. Changes sync bidirectionally via unison.

## Requirements

- macOS with [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- Homebrew

## Setup

```bash
git clone <this-repo> contain_claude
cd contain_claude
./setup.sh
```

Then add the aliases to your shell (replace the path if you cloned elsewhere):

```bash
echo 'alias contain_claude="~/contain_claude/claude-sandbox.sh"' >> ~/.zshrc
echo 'alias sync_claude="~/contain_claude/claude-sync.sh"' >> ~/.zshrc
source ~/.zshrc
```

`setup.sh` will install unison via brew and build the Docker image. The build takes a few minutes the first time.

## Usage

**Auto-sync** — syncs every 3 seconds while Claude is running:
```bash
contain_claude ~/path/to/project
```

**Manual sync** — only syncs on start and exit:
```bash
sync_claude ~/path/to/project
```

## First run

On first use, Claude will open a browser window to log in with your Anthropic account. Credentials are saved to `~/.claude-sandbox/` and reused automatically after that.

Alternatively, set `ANTHROPIC_API_KEY` in your environment to skip the browser login.

## How it works

Your project files are copied into `/workspace` inside the container at the start of each session and synced back to your Mac on exit. The container is destroyed when you exit Claude.
