#!/bin/bash
# Unison SSH transport shim for Docker.
# Unison calls: sshcmd [sshargs] hostname [ssh-flags] unison -server
# We ignore the SSH-specific flags and run unison -server in the container.
exec docker exec -i "$1" unison -server
