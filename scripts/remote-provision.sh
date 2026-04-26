#!/bin/bash
# remote-provision.sh - Install dependencies on the Proxmox VM and sync files.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/remote-env.sh"

"$SCRIPT_DIR/remote-sync.sh"

ssh -o StrictHostKeyChecking=accept-new -p "$REMOTE_PORT" $SSH_OPTS \
    "$REMOTE_USER@$REMOTE_HOST" bash -s <<EOF
    set -euo pipefail
    cd "$REMOTE_DIR"
    chmod +x scripts/*.sh
    if command -v apt-get >/dev/null; then
        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            iproute2 iperf3 iputils-ping tcpdump procps python3 python3-matplotlib rsync
    elif command -v dnf >/dev/null; then
        sudo dnf install -y iproute iperf3 iputils tcpdump procps-ng python3 python3-matplotlib rsync
    else
        echo \"Unsupported distro: install iproute2/tc, iperf3, tcpdump, python3, matplotlib manually.\" >&2
        exit 1
    fi
    sudo ./scripts/setup-lab.sh apply
    sudo ./scripts/setup-lab.sh clear
EOF

echo "Provisioned $REMOTE_HOST. Next:"
echo "  REMOTE_HOST=$REMOTE_HOST REMOTE_USER=$REMOTE_USER ./scripts/remote-run.sh 30"
