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

"$(dirname "$0")/vm-check.sh"

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
    echo "Set ISO_PATH to an Ubuntu Server ISO path." >&2
    exit 1
fi

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "VM already exists: $VM_NAME"
    exit 0
fi

mkdir -p "$VM_DIR"

VBoxManage createvm --name "$VM_NAME" --ostype Ubuntu_64 --register
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
