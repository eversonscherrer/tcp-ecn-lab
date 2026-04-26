#!/bin/bash
# run-experiment.sh - Run one ECN mode inside the Linux VM.
#
# Usage:
#   sudo ./scripts/run-experiment.sh <mode> [duration]
#     mode: none | classic | accecn
#     duration: seconds (default 30)

set -euo pipefail

MODE="${1:-}"
DURATION="${2:-30}"

if [[ -z "$MODE" ]]; then
    echo "Usage: $0 {none|classic|accecn} [duration_seconds]"
    exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $0 $MODE $DURATION" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="$REPO_ROOT/results/$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$RESULTS_DIR"

CLIENT_NS="${CLIENT_NS:-accecn-client}"
SERVER_NS="${SERVER_NS:-accecn-server}"
SERVER_IP="${SERVER_IP:-10.99.0.10}"

cleanup() {
    "$REPO_ROOT/scripts/setup-network.sh" clear >/dev/null 2>&1 || true
    ip netns exec "$CLIENT_NS" pkill tcpdump >/dev/null 2>&1 || true
    ip netns exec "$SERVER_NS" pkill iperf3 >/dev/null 2>&1 || true
    "$REPO_ROOT/scripts/setup-lab.sh" clear >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=== Run: mode=$MODE duration=${DURATION}s ==="
echo "Results -> $RESULTS_DIR"

"$REPO_ROOT/scripts/setup-lab.sh" apply | tee "$RESULTS_DIR/lab.log"

NS="$SERVER_NS" "$REPO_ROOT/scripts/configure-ecn.sh" "$MODE" \
    | tee "$RESULTS_DIR/server-ecn.log"
NS="$CLIENT_NS" "$REPO_ROOT/scripts/configure-ecn.sh" "$MODE" \
    | tee "$RESULTS_DIR/client-ecn.log"

"$REPO_ROOT/scripts/setup-network.sh" apply | tee "$RESULTS_DIR/netem.log"

ip netns exec "$CLIENT_NS" tcpdump -i veth-client -nn -vv \
    -w "$RESULTS_DIR/handshake.pcap" 'tcp port 5201' >/dev/null 2>&1 &
TCPDUMP_PID=$!

ip netns exec "$SERVER_NS" iperf3 -s -1 --json \
    --logfile "$RESULTS_DIR/iperf-server.json" &
IPERF_SERVER_PID=$!

sleep 2

(
    for _ in $(seq 1 $((DURATION * 2))); do
        ts="$(date +%s.%N)"
        ip netns exec "$CLIENT_NS" ss -tin dst "$SERVER_IP" 2>/dev/null \
            | awk -v ts="$ts" 'NR>1 {print ts" "$0}' \
            >> "$RESULTS_DIR/ss-samples.log"
        sleep 0.5
    done
) &
SS_BG=$!

echo "Running iperf3 for ${DURATION}s..."
ip netns exec "$CLIENT_NS" iperf3 -c "$SERVER_IP" -R -t "$DURATION" -J \
    > "$RESULTS_DIR/iperf-client.json"

sleep 1
kill "$TCPDUMP_PID" >/dev/null 2>&1 || true
wait "$TCPDUMP_PID" >/dev/null 2>&1 || true
wait "$IPERF_SERVER_PID" >/dev/null 2>&1 || true
wait "$SS_BG" >/dev/null 2>&1 || true

echo
echo "=== Summary ==="
python3 -c "
import json
with open('$RESULTS_DIR/iperf-client.json') as f:
    d = json.load(f)
end = d['end']
sent = end['sum_sent']
recv = end['sum_received']
print(f\"Throughput sent: {sent['bits_per_second']/1e6:.2f} Mbps\")
print(f\"Throughput recv: {recv['bits_per_second']/1e6:.2f} Mbps\")
print(f\"Retransmits: {sent.get('retransmits', 'n/a')}\")
"

echo
echo "Done. Results: $RESULTS_DIR"
