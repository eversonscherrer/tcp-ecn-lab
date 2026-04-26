#!/bin/bash
# remote-ssh.sh - SSH into the Proxmox VM.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/remote-env.sh"

exec ssh -o StrictHostKeyChecking=accept-new -p "$REMOTE_PORT" $SSH_OPTS \
    "$REMOTE_USER@$REMOTE_HOST" "$@"
