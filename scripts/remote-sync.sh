#!/bin/bash
# remote-sync.sh - Copy this repository to the Proxmox VM.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/remote-env.sh"

ssh_cmd "mkdir -p '$REMOTE_DIR'"
rsync_ssh "$REPO_ROOT/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"

echo "Synced repository to $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
