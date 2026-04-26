#!/bin/bash
set -e

echo "=== Container started ==="
echo "Kernel: $(uname -r)"
echo "Hostname: $(hostname)"
echo "IPs:"
ip -4 addr show | awk '/inet /{print "  "$2}'
echo "========================="

exec "$@"
