#!/usr/bin/env bash
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude-sandbox.sh" --no-watch "$@"
