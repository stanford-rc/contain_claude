# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker sandbox for running Claude Code safely. Claude operates on a copy of a host project inside a container — no access to SSH keys, git credentials, or the rest of the filesystem. Unison syncs changes bidirectionally between the host project dir and `/workspace` inside the container.

## Setup (one-time)

```bash
./setup.sh        # installs unison via brew, builds the Docker image
source ~/.zshrc   # picks up the claude-sandbox and claude-sync aliases
```

## Daily use

```bash
contain_claude ~/path/to/project              # auto-sync every 3s + claude session
contain_claude --no-watch ~/path/to/project   # manual sync only
claude-sync                                   # trigger a sync from any terminal
```

## Architecture

**Sync transport:** unison uses `ssh://` protocol but the "SSH command" is overridden via `docker-unison-exec.sh` to run `docker exec -i <container> unison -server`. This sidesteps socket mode (which breaks due to OCaml version mismatch between brew and the container) and avoids needing sshd.

**OCaml version constraint:** unison's wire protocol embeds the OCaml version string. The Dockerfile uses a multi-stage build — `ocaml/opam:ubuntu-24.04-ocaml-5.2` compiles unison 2.54.0, then the binary is copied into the `ubuntu:24.04` runtime image. If brew upgrades unison to a new OCaml version and syncs break, rebuild the image after updating the opam base tag in the Dockerfile.

**Auth persistence:** `~/.claude-sandbox/` on the Mac is mounted as `/home/sandbox/.claude` in the container. First run triggers a browser OAuth flow; subsequent runs reuse those credentials. This dir is separate from `~/.claude/` to avoid interfering with your main Claude Code session.

**Container lifecycle:** `claude-sandbox.sh` starts a named container (`claude-sandbox-<project-dir-name>`), runs an initial sync, optionally starts a background watch loop, launches `claude` interactively via `docker exec`, then on exit runs a final sync and removes the container.

## Rebuilding the image

Required after any change to `Dockerfile`:

```bash
./setup.sh
```

The opam build stage is slow (5–10 min) but cached after the first build.

## Key files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage: builds unison with OCaml 5.x, installs Node 20 + Claude Code CLI |
| `claude-sandbox.sh` | Main launcher — parses args, starts container, manages sync loop, runs claude |
| `claude-sync.sh` | Standalone sync trigger — finds running container, runs unison manually |
| `docker-unison-exec.sh` | Shim that unison calls as its "ssh command"; runs `docker exec -i <container> unison -server` |
| `setup.sh` | One-time setup: checks Docker, installs unison via brew, builds image |
