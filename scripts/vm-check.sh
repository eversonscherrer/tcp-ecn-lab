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

if ! vbox_with_timeout list ostypes | grep -q '^ID:.*Ubuntu_64'; then
    echo "Ubuntu_64 OS type was not found in this VirtualBox installation." >&2
    exit 1
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
