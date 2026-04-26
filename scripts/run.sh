#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

DURATION="${1:-30}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
LOSS="${LOSS:-0%}"
LOCAL_RESULTS="$ROOT_DIR/results"

mkdir -p "$LOCAL_RESULTS"
"$SCRIPT_DIR/sync.sh"

detect_server_iface() {
    if [[ -n "${SERVER_IFACE:-}" ]]; then
        echo "$SERVER_IFACE"
        return
    fi
    server_ssh "ip route get '$CLIENT_IP' | awk '{for (i=1; i<=NF; i++) if (\$i == \"dev\") {print \$(i+1); exit}}'"
}

cleanup_remote() {
    local iface="${1:-}"
    server_ssh "sudo pkill iperf3 >/dev/null 2>&1 || true" || true
    client_ssh "sudo pkill tcpdump >/dev/null 2>&1 || true" || true
    if [[ -n "$iface" ]]; then
        server_ssh "cd '$REMOTE_DIR' && IFACE='$iface' ./scripts/setup-qdisc.sh clear >/dev/null 2>&1 || true" || true
    fi
}

run_mode() {
    local mode="$1"
    local ts
    local dir
    local iface

    ts="$(date +%Y%m%d-%H%M%S)"
    dir="$LOCAL_RESULTS/$ts-$mode"
    mkdir -p "$dir"

    echo
    echo "############################################################"
    echo "# mode=$mode duration=${DURATION}s"
    echo "############################################################"

    iface="$(detect_server_iface)"
    if [[ -z "$iface" ]]; then
        echo "Could not detect server interface. Set SERVER_IFACE in .env." >&2
        exit 1
    fi
    echo "$iface" > "$dir/server-iface.txt"

    cleanup_remote "$iface"

    server_ssh "cd '$REMOTE_DIR' && ./scripts/configure-ecn.sh '$mode'" | tee "$dir/server-ecn.log"
    client_ssh "cd '$REMOTE_DIR' && ./scripts/configure-ecn.sh '$mode'" | tee "$dir/client-ecn.log"

    server_ssh "cd '$REMOTE_DIR' && IFACE='$iface' RATE='$RATE' DELAY='$DELAY' JITTER='$JITTER' LOSS='$LOSS' ./scripts/setup-qdisc.sh apply" \
        | tee "$dir/qdisc.log"

    client_ssh "rm -f /tmp/accecn-handshake.pcap /tmp/accecn-ss.log /tmp/accecn-tcpdump.log"
    server_ssh "rm -f /tmp/accecn-server.json /tmp/accecn-server.out"

    client_ssh "nohup sudo tcpdump -i any -nn -vv -w /tmp/accecn-handshake.pcap 'tcp port 5201' >/tmp/accecn-tcpdump.log 2>&1 &"
    server_ssh "nohup iperf3 -s -1 --json --logfile /tmp/accecn-server.json >/tmp/accecn-server.out 2>&1 &"

    sleep 2

    client_ssh "nohup bash -lc 'for i in \$(seq 1 $((DURATION * 2))); do now=\$(date +%s.%N); ss -tin dst $SERVER_IP 2>/dev/null | awk -v ts=\$now '\\''NR>1 {print ts\" \"\$0}'\\'' >> /tmp/accecn-ss.log; sleep 0.5; done' >/tmp/accecn-ss.out 2>&1 &"

    echo "Running iperf3..."
    client_ssh "iperf3 -c '$SERVER_IP' -R -t '$DURATION' -J" > "$dir/iperf-client.json"

    sleep 1
    cleanup_remote "$iface"

    scp -P "$CLIENT_PORT" $SSH_OPTS "$CLIENT_USER@$CLIENT_HOST:/tmp/accecn-handshake.pcap" "$dir/handshake.pcap" >/dev/null 2>&1 || true
    scp -P "$CLIENT_PORT" $SSH_OPTS "$CLIENT_USER@$CLIENT_HOST:/tmp/accecn-ss.log" "$dir/ss-samples.log" >/dev/null 2>&1 || true
    scp -P "$SERVER_PORT" $SSH_OPTS "$SERVER_USER@$SERVER_HOST:/tmp/accecn-server.json" "$dir/iperf-server.json" >/dev/null 2>&1 || true

    python3 - "$dir/iperf-client.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)

sent = data["end"]["sum_sent"]
recv = data["end"]["sum_received"]
print(f"sent_mbps={sent['bits_per_second'] / 1e6:.2f}")
print(f"recv_mbps={recv['bits_per_second'] / 1e6:.2f}")
print(f"retransmits={sent.get('retransmits', 'n/a')}")
PY
}

trap 'cleanup_remote "${iface:-}"' EXIT

for mode in none classic accecn; do
    run_mode "$mode"
    sleep 3
done

python3 "$ROOT_DIR/analysis/parse-results.py" "$LOCAL_RESULTS"

echo
echo "Done. Results in $LOCAL_RESULTS"
