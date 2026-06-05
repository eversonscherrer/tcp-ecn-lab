#!/bin/bash
# T02 — Congestion Control Algorithm Sweep
#
# Tests Cubic, Reno and BBR under three ECN modes (none, classic, accecn)
# plus DCTCP as its own mode, to compare how different CC algorithms
# interact with ECN signalling.
#
# Matrix:
#   CC algos : cubic  reno  bbr
#   ECN modes: none   classic  accecn
#   + dctcp mode (always uses dctcp CC, independent row)
#
# Usage:
#   ./scripts/run-t02-cc-sweep.sh [duration]
#
# Overridable env vars:
#   DURATION    seconds per iperf3 run                    (default: 60)
#   CC_ALGOS    space-separated CC algorithms to test     (default: cubic reno bbr)
#   ECN_MODES   space-separated ECN modes per CC algo     (default: none classic accecn)
#   WITH_DCTCP  include dctcp mode run (yes/no)           (default: yes)
#   RATE        link rate                                  (default: 100mbit)
#   DELAY       one-way netem delay                       (default: 25ms)
#   JITTER      netem jitter                              (default: 2ms)
#   ECN_TARGET  fq_codel ECN marking threshold            (default: 5ms)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

DURATION="${DURATION:-60}"
CC_ALGOS="${CC_ALGOS:-cubic reno bbr}"
ECN_MODES="${ECN_MODES:-none classic accecn}"
WITH_DCTCP="${WITH_DCTCP:-yes}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
ECN_TARGET="${ECN_TARGET:-5ms}"

n_cc=$(echo "$CC_ALGOS" | wc -w | tr -d ' ')
n_modes=$(echo "$ECN_MODES" | wc -w | tr -d ' ')
total=$(( n_cc * n_modes + (WITH_DCTCP == "yes" ? 1 : 0) ))

echo "============================================================"
echo " T02 — Congestion Control Algorithm Sweep"
echo "------------------------------------------------------------"
echo " CC algos    : $CC_ALGOS"
echo " ECN modes   : $ECN_MODES"
echo " DCTCP mode  : $WITH_DCTCP"
echo " Duration    : ${DURATION}s per run"
echo " Rate        : $RATE | Delay: $DELAY ± $JITTER"
echo " fq_codel    : target=$ECN_TARGET"
echo " Total runs  : $total  (~$(( total * (DURATION + 10) / 60 )) min)"
echo "============================================================"

for CC in $CC_ALGOS; do
    echo
    echo ">>> CC=$CC  ($(date '+%H:%M:%S'))"
    CC_ALGO="$CC" MODES="$ECN_MODES" RATE="$RATE" DELAY="$DELAY" \
        JITTER="$JITTER" ECN_TARGET="$ECN_TARGET" \
        "$SCRIPT_DIR/run.sh" "$DURATION"
done

if [[ "$WITH_DCTCP" == "yes" ]]; then
    echo
    echo ">>> CC=dctcp (mode=dctcp)  ($(date '+%H:%M:%S'))"
    CC_ALGO="" MODES="dctcp" RATE="$RATE" DELAY="$DELAY" \
        JITTER="$JITTER" ECN_TARGET="$ECN_TARGET" \
        "$SCRIPT_DIR/run.sh" "$DURATION"
fi

echo
echo "============================================================"
echo " T02 complete at $(date '+%H:%M:%S')"
echo " Analyse with:"
echo "   python3 analysis/parse-results.py"
echo "   python3 analysis/plot-t02-cc-sweep.py"
echo "============================================================"
