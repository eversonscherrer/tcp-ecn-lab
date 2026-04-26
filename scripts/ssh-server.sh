#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

exec ssh -o StrictHostKeyChecking=accept-new -p "$SERVER_PORT" $SSH_OPTS \
    "$SERVER_USER@$SERVER_HOST" "$@"
