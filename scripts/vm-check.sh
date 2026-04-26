#!/bin/bash
# vm-check.sh - Check host-side VirtualBox prerequisites.

set -euo pipefail

command -v VBoxManage >/dev/null || {
    echo "VBoxManage not found. Install VirtualBox first." >&2
    exit 1
}

echo "VirtualBox: $(VBoxManage --version)"

vbox_with_timeout() {
    python3 - "$@" <<'PY'
import subprocess
import sys

try:
    completed = subprocess.run(["VBoxManage", *sys.argv[1:]], timeout=10)
except subprocess.TimeoutExpired:
    sys.exit(124)

sys.exit(completed.returncode)
PY
}

if ! vbox_with_timeout list systemproperties >/dev/null 2>&1; then
    echo "VirtualBox is installed, but its COM server is not responding." >&2
    echo "Open the VirtualBox app once, approve any macOS permissions, then retry." >&2
    exit 1
fi

os_type="$(vbox_with_timeout list ostypes \
    | awk '/^ID:/ {print $2}' \
    | grep -E 'Ubuntu.*64|Debian.*64|Linux.*64' \
    | head -n 1 || true)"
if [[ -z "$os_type" ]]; then
    echo "Could not find a 64-bit Linux OS type in this VirtualBox installation." >&2
    echo "You can still try vm-create.sh with OS_TYPE=<id> if VBoxManage createvm accepts it." >&2
else
    echo "Detected Linux OS type: $os_type"
fi

command -v ssh >/dev/null || {
    echo "ssh not found." >&2
    exit 1
}

command -v rsync >/dev/null || {
    echo "rsync not found." >&2
    exit 1
}

echo "Host prerequisites look good."
