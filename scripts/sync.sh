#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

server_ssh "mkdir -p '$REMOTE_DIR'"
client_ssh "mkdir -p '$REMOTE_DIR'"

rsync -az $(rsync_common_args) \
    -e "ssh -o StrictHostKeyChecking=accept-new -p $SERVER_PORT $SSH_OPTS" \
    "$ROOT_DIR/" "$SERVER_USER@$SERVER_HOST:$REMOTE_DIR/"

rsync -az $(rsync_common_args) \
    -e "ssh -o StrictHostKeyChecking=accept-new -p $CLIENT_PORT $SSH_OPTS" \
    "$ROOT_DIR/" "$CLIENT_USER@$CLIENT_HOST:$REMOTE_DIR/"

server_ssh "cd '$REMOTE_DIR' && chmod +x scripts/*.sh"
client_ssh "cd '$REMOTE_DIR' && chmod +x scripts/*.sh"

echo "Synced to both VMs."
