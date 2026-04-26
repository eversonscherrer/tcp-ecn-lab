#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

"$SCRIPT_DIR/sync.sh"

install_deps() {
    local label="$1"
    shift
    echo
    echo "=== installing on $label ==="
    "$@" bash -s <<'REMOTE'
set -euo pipefail
if ! sudo -n true >/dev/null 2>&1; then
    echo "Passwordless sudo is required for remote automation." >&2
    echo "On this VM, run: echo \"$USER ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/accecn" >&2
    echo "Then run: sudo chmod 440 /etc/sudoers.d/accecn" >&2
    exit 1
fi
if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        iproute2 iperf3 iputils-ping tcpdump procps python3 rsync
else
    echo "Unsupported distro. Install iproute2, iperf3, tcpdump, python3, rsync manually." >&2
    exit 1
fi
REMOTE
}

install_deps "accecn1/server" server_ssh
install_deps "accecn2/client" client_ssh

"$SCRIPT_DIR/check.sh"
