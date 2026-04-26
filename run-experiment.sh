#!/bin/bash
# run-experiment.sh - Orchestrates ONE experimental run (one ECN mode).
#
# Run from the HOST. Coordinates client and server containers.
#
# Usage:
#   ./run-experiment.sh <mode> [duration]
#     mode: none | classic | accecn
#     duration: seconds (default 30)

set -euo pipefail

MODE="${1:-}"
DURATION="${2:-30}"

if [[ -z "$MODE" ]]; then
    echo "Usage: $0 {none|classic|accecn} [duration_seconds]"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="$REPO_ROOT/results/$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$RESULTS_DIR"

SERVER="accecn-server"
CLIENT="accecn-client"
SERVER_IP="10.99.0.10"

echo "=== Run: mode=$MODE duration=${DURATION}s ==="
echo "Results -> $RESULTS_DIR"

# 1. Configure ECN on both sides
docker exec "$SERVER" /experiment/scripts/configure-ecn.sh "$MODE" \
    | tee "$RESULTS_DIR/server-ecn.log"
docker exec "$CLIENT" /experiment/scripts/configure-ecn.sh "$MODE" \
    | tee "$RESULTS_DIR/client-ecn.log"

# 2. Apply network impairment on the server side (egress to client)
docker exec "$SERVER" /experiment/scripts/setup-network.sh apply \
    | tee "$RESULTS_DIR/netem.log"

# 3. Start tcpdump on client to capture handshake
docker exec -d "$CLIENT" bash -c \
    "tcpdump -i eth0 -nn -vv -w /experiment/results/$(basename $RESULTS_DIR)/handshake.pcap 'tcp port 5201' 2>/dev/null"

# 4. Start iperf3 server in background
docker exec -d "$SERVER" bash -c \
    "iperf3 -s -1 --json --logfile /experiment/results/$(basename $RESULTS_DIR)/iperf-server.json"

# Give server a moment to start
sleep 2

# 5. Start ss sampler in background on client (snapshot every 0.5s)
docker exec -d "$CLIENT" bash -c "
    for i in \$(seq 1 $((DURATION * 2))); do
        ts=\$(date +%s.%N)
        ss -tin dst $SERVER_IP 2>/dev/null \
            | awk -v ts=\$ts 'NR>1 {print ts\" \"\$0}' \
            >> /experiment/results/$(basename $RESULTS_DIR)/ss-samples.log
        sleep 0.5
    done
" &
SS_BG=$!

# 6. Run iperf3 client
echo "Running iperf3 for ${DURATION}s..."
docker exec "$CLIENT" iperf3 -c "$SERVER_IP" -t "$DURATION" -J \
    > "$RESULTS_DIR/iperf-client.json"

# 7. Cleanup
sleep 1
docker exec "$CLIENT" pkill tcpdump 2>/dev/null || true
docker exec "$SERVER" /experiment/scripts/setup-network.sh clear || true
wait $SS_BG 2>/dev/null || true

# 8. Quick summary
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
