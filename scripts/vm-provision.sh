#!/bin/bash
# vm-provision.sh - Install dependencies and sync scripts into the lab VM.

set -euo pipefail

VM_PASS="${VM_PASS:-accecn}"
VM_USER="${VM_USER:-accecn}"
REMOTE_DIR="${REMOTE_DIR:-/home/$VM_USER/accecn-tcp-experiment}"

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
