#!/bin/bash
# vm-create.sh - Create a VirtualBox VM for the experiment.
#
# Host script for macOS. Requires an Ubuntu Server ISO.
#
# Usage:
#   ISO_PATH=/path/to/ubuntu.iso ./scripts/vm-create.sh

set -euo pipefail

VM_NAME="${VM_NAME:-accecn-lab}"
ISO_PATH="${ISO_PATH:-}"
VM_USER="${VM_USER:-accecn}"
VM_PASS="${VM_PASS:-accecn}"
VM_CPUS="${VM_CPUS:-2}"
VM_MEMORY_MB="${VM_MEMORY_MB:-4096}"
VM_DISK_MB="${VM_DISK_MB:-30000}"
SSH_PORT="${SSH_PORT:-2222}"
VM_DIR="${VM_DIR:-$HOME/VirtualBox VMs/$VM_NAME}"
OS_TYPE="${OS_TYPE:-}"

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
    echo "Set ISO_PATH to a real Ubuntu Server ISO path." >&2
    echo "Example: ISO_PATH=$HOME/Downloads/ubuntu-24.04.2-live-server-amd64.iso $0" >&2
    exit 1
fi

"$(dirname "$0")/vm-check.sh"

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "VM already exists: $VM_NAME"
    exit 0
fi

if [[ -z "$OS_TYPE" ]]; then
    OS_TYPE="$(python3 - <<'PY' || true
import subprocess
import sys

try:
    out = subprocess.check_output(["VBoxManage", "list", "ostypes"], text=True, timeout=10)
except Exception:
    sys.exit(1)

ids = [line.split(":", 1)[1].strip() for line in out.splitlines() if line.startswith("ID:")]
for prefix in ("Ubuntu", "Debian", "Linux"):
    for value in ids:
        if value.startswith(prefix) and "64" in value:
            print(value)
            sys.exit(0)
sys.exit(1)
PY
)"
fi

if [[ -z "$OS_TYPE" ]]; then
    echo "Could not auto-detect a VirtualBox 64-bit Linux OS type." >&2
    echo "Retry with OS_TYPE=<id>, for example OS_TYPE=Ubuntu24_LTS_64." >&2
    exit 1
fi

mkdir -p "$VM_DIR"

echo "Using VirtualBox OS type: $OS_TYPE"

VBoxManage createvm --name "$VM_NAME" --ostype "$OS_TYPE" --register
VBoxManage modifyvm "$VM_NAME" \
    --cpus "$VM_CPUS" \
    --memory "$VM_MEMORY_MB" \
    --vram 16 \
    --graphicscontroller vmsvga \
    --nic1 nat \
    --natpf1 "ssh,tcp,127.0.0.1,$SSH_PORT,,22"

VBoxManage createhd --filename "$VM_DIR/$VM_NAME.vdi" --size "$VM_DISK_MB" --variant Standard
VBoxManage storagectl "$VM_NAME" --name SATA --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 0 --device 0 \
    --type hdd --medium "$VM_DIR/$VM_NAME.vdi"
VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 1 --device 0 \
    --type dvddrive --medium "$ISO_PATH"

VBoxManage unattended install "$VM_NAME" \
    --iso="$ISO_PATH" \
    --user="$VM_USER" \
    --password="$VM_PASS" \
    --full-user-name="AccECN Lab" \
    --hostname="$VM_NAME.local" \
    --install-additions \
    --time-zone=UTC

VBoxManage startvm "$VM_NAME" --type headless

echo "VM started: $VM_NAME"
echo "SSH will be available after installation:"
echo "  VM_USER=$VM_USER VM_PASS=$VM_PASS SSH_PORT=$SSH_PORT ./scripts/vm-ssh.sh"
