#!/bin/bash
# T06 — Multi-flow Sweep
#
# Varies the number of parallel iperf3 streams (1–8) across all ECN modes
# to evaluate whether AccECN's per-flow byte-accurate CE feedback produces
# measurable throughput or fairness gains under flow contention.
#
# fq_codel is per-flow, so each stream receives independent marking.
# The research question: does AccECN's CE byte count help individual flows
# calibrate cwnd more precisely when competing for the same bottleneck?
#
# Fixed: 100 Mbps, 25 ms RTT, 0% loss, fq_codel target=5ms, buffer=1000
#
# Usage:
#   ./scripts/run-t06-multiflow-sweep.sh [duration]
#
# Overridable env vars:
#   DURATION      seconds per iperf3 run         (default: 60)
#   STREAMS_LIST  space-separated stream counts   (default: 1 2 4 8)
#   MODES         space-separated ECN modes       (default: none classic accecn dctcp)
#   RATE          link rate                        (default: 100mbit)
#   DELAY         one-way netem delay             (default: 25ms)
#   JITTER        netem jitter                    (default: 2ms)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

DURATION="${DURATION:-60}"
STREAMS_LIST="${STREAMS_LIST:-1 2 4 8}"
MODES="${MODES:-none classic accecn dctcp}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
LOSS="${LOSS:-0%}"
ECN_TARGET="${ECN_TARGET:-5ms}"
BUFFER_LIMIT="${BUFFER_LIMIT:-1000}"

n_streams=$(echo "$STREAMS_LIST" | wc -w | tr -d ' ')
n_modes=$(echo "$MODES"         | wc -w | tr -d ' ')
total=$(( n_streams * n_modes ))

echo "============================================================"
echo " T06 — Multi-flow Sweep"
echo "------------------------------------------------------------"
echo " Streams       : $STREAMS_LIST"
echo " Modes         : $MODES"
echo " Rate          : $RATE | Delay: $DELAY ± $JITTER | Loss: $LOSS"
echo " ECN target    : $ECN_TARGET | Buffer: $BUFFER_LIMIT pkts"
echo " Duration      : ${DURATION}s per run"
echo " Total runs    : $total  (~$(( total * (DURATION + 10) / 60 )) min)"
echo "============================================================"

for N in $STREAMS_LIST; do
    echo
    echo ">>> streams=$N  ($(date '+%H:%M:%S'))"
    MODES="$MODES" RATE="$RATE" DELAY="$DELAY" JITTER="$JITTER" \
        LOSS="$LOSS" ECN_TARGET="$ECN_TARGET" BUFFER_LIMIT="$BUFFER_LIMIT" \
        STREAMS="$N" \
        "$SCRIPT_DIR/run.sh" "$DURATION"
done

echo
echo "============================================================"
echo " T06 complete at $(date '+%H:%M:%S')"
echo " Analyse with:"
echo "   python3 analysis/parse-results.py"
echo "   python3 analysis/plot-t06-multiflow-sweep.py"
echo "============================================================"
