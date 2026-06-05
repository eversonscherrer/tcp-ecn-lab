#!/bin/bash
# T03 — Bandwidth Sweep
#
# Tests all ECN modes across different link rates (10 / 100 / 1000 Mbps) to
# evaluate whether ECN's advantage holds as the Bandwidth-Delay Product changes.
#
# BDP reference (rate × delay):
#   10 Mbit/s  × 25 ms = 31 KB
#   100 Mbit/s × 25 ms = 312 KB
#   1000 Mbit/s× 25 ms = 3125 KB
#
# Usage:
#   ./scripts/run-t03-bandwidth-sweep.sh [duration]
#
# Overridable env vars:
#   DURATION      seconds per iperf3 run            (default: 60)
#   RATES         space-separated link rates         (default: 10mbit 100mbit 1000mbit)
#   MODES         space-separated ECN modes          (default: none classic accecn dctcp)
#   DELAY         one-way netem delay                (default: 25ms)
#   JITTER        netem jitter                       (default: 2ms)
#   ECN_TARGET    fq_codel ECN marking threshold     (default: 5ms)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

DURATION="${DURATION:-60}"
RATES="${RATES:-10mbit 100mbit 1000mbit}"
MODES="${MODES:-none classic accecn dctcp}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
ECN_TARGET="${ECN_TARGET:-5ms}"

n_rates=$(echo "$RATES"  | wc -w | tr -d ' ')
n_modes=$(echo "$MODES"  | wc -w | tr -d ' ')
total=$(( n_rates * n_modes ))

echo "============================================================"
echo " T03 — Bandwidth Sweep"
echo "------------------------------------------------------------"
echo " Rates       : $RATES"
echo " Modes       : $MODES"
echo " Duration    : ${DURATION}s per run"
echo " Delay       : $DELAY ± $JITTER | ECN target: $ECN_TARGET"
echo " Total runs  : $total  (~$(( total * (DURATION + 10) / 60 )) min)"
echo "============================================================"

for RATE in $RATES; do
    echo
    echo ">>> Rate = $RATE  ($(date '+%H:%M:%S'))"
    MODES="$MODES" RATE="$RATE" DELAY="$DELAY" \
        JITTER="$JITTER" ECN_TARGET="$ECN_TARGET" \
        "$SCRIPT_DIR/run.sh" "$DURATION"
done

echo
echo "============================================================"
echo " T03 complete at $(date '+%H:%M:%S')"
echo " Analyse with:"
echo "   python3 analysis/parse-results.py"
echo "   python3 analysis/plot-t03-bandwidth-sweep.py"
echo "============================================================"
