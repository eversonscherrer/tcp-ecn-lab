#!/bin/bash
# T01 — Packet Loss Sweep
#
# Runs all ECN modes under increasing packet loss to evaluate how well
# each mode sustains throughput when the network is lossy.
#
# Usage:
#   ./scripts/run-t01-loss-sweep.sh [duration]
#
# Overridable env vars:
#   DURATION      seconds per iperf3 run         (default: 60)
#   MODES         space-separated ECN modes       (default: none classic accecn dctcp)
#   LOSS_VALUES   space-separated loss percentages (default: 0% 0.1% 0.5% 1.0% 2.0% 5.0%)
#   RATE          link rate                        (default: 100mbit)
#   DELAY         one-way netem delay              (default: 25ms)
#   JITTER        netem jitter                     (default: 2ms)
#   ECN_TARGET    fq_codel ECN marking threshold   (default: 5ms)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

DURATION="${DURATION:-60}"
MODES="${MODES:-none classic accecn dctcp}"
LOSS_VALUES="${LOSS_VALUES:-0% 0.1% 0.5% 1.0% 2.0% 5.0%}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
ECN_TARGET="${ECN_TARGET:-5ms}"

n_loss=$(echo "$LOSS_VALUES" | wc -w | tr -d ' ')
n_modes=$(echo "$MODES" | wc -w | tr -d ' ')
total=$(( n_loss * n_modes ))

echo "============================================================"
echo " T01 — Packet Loss Sweep"
echo "------------------------------------------------------------"
echo " Modes       : $MODES"
echo " Loss values : $LOSS_VALUES"
echo " Duration    : ${DURATION}s per run"
echo " Rate        : $RATE | Delay: $DELAY ± $JITTER"
echo " fq_codel    : target=$ECN_TARGET"
echo " Total runs  : $total  (~$(( total * (DURATION + 10) / 60 )) min)"
echo "============================================================"

for LOSS in $LOSS_VALUES; do
    echo
    echo ">>> Loss = $LOSS  ($(date '+%H:%M:%S'))"
    MODES="$MODES" LOSS="$LOSS" RATE="$RATE" DELAY="$DELAY" \
        JITTER="$JITTER" ECN_TARGET="$ECN_TARGET" \
        "$SCRIPT_DIR/run.sh" "$DURATION"
done

echo
echo "============================================================"
echo " T01 complete at $(date '+%H:%M:%S')"
echo " Analyse with:"
echo "   python3 analysis/parse-results.py"
echo "   python3 analysis/plot-t01-loss-sweep.py"
echo "============================================================"
