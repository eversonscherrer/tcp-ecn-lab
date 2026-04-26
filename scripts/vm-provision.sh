#!/bin/bash
# vm-provision.sh - Install dependencies and sync scripts into the lab VM.

set -euo pipefail

VM_PASS="${VM_PASS:-accecn}"
VM_USER="${VM_USER:-accecn}"
SSH_HOST="${SSH_HOST:-127.0.0.1}"
SSH_PORT="${SSH_PORT:-2222}"
REMOTE_DIR="${REMOTE_DIR:-/home/$VM_USER/accecn-tcp-experiment}"

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
    -p "$SSH_PORT" "$VM_USER@$SSH_HOST" true >/dev/null 2>&1; then
    echo "Cannot reach the VM over SSH at $VM_USER@$SSH_HOST:$SSH_PORT." >&2
    echo "Create the VM first, wait for Ubuntu installation to finish, then retry." >&2
    echo "You can test manually with: ./scripts/vm-ssh.sh" >&2
    exit 1
fi

"$(dirname "$0")/vm-sync.sh"

"$(dirname "$0")/vm-ssh.sh" bash -lc "
    set -euo pipefail
    echo '$VM_PASS' | sudo -S apt-get update
    echo '$VM_PASS' | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        iperf3 iproute2 iputils-ping tcpdump procps python3 python3-pip
    cd $REMOTE_DIR
    chmod +x scripts/*.sh
    sudo ./scripts/setup-lab.sh apply
    sudo ./scripts/setup-lab.sh clear
"

echo "VM provisioned. Run inside the VM:"
echo "  cd $REMOTE_DIR && sudo ./scripts/run-all.sh 30"
