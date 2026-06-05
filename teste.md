# Experimental Campaign

This document describes an extended experimental campaign for evaluating Explicit Congestion Notification (ECN), Accurate ECN (AccECN), and DCTCP under diverse network conditions.

---

# Overview

The current laboratory evaluates four ECN modes under a fixed scenario:

- Fixed bandwidth: 100 Mbps
- Fixed RTT: 25 ms
- Single TCP flow
- No packet loss
- FQ-CoDel enabled

The following experiments extend the evaluation to loss resilience, congestion control algorithms, fairness, bufferbloat, flow completion time, queue management strategies, and WAN/DC scenarios.

---

# T01 — Packet Loss Sensitivity

## Objective

Evaluate how each ECN mode behaves under increasing random packet loss.

## Hypothesis

ECN-capable modes can distinguish congestion from packet loss through CE markings, reducing unnecessary retransmissions and maintaining higher throughput.

## Parameters

| Variable | Values |
|-----------|----------|
| Loss Rate | 0.1%, 0.5%, 1%, 2%, 5% |
| Modes | none, classic, accecn, dctcp |
| Duration | 60s |

## Execution

```bash
for LOSS in 0.1 0.5 1.0 2.0 5.0; do
  MODES="none classic accecn dctcp" \
  LOSS="${LOSS}%" \
  DURATION=60 \
  ./scripts/run.sh 60
done
```

## Metrics

- Throughput
- Retransmissions
- ECN Marks
- RTT
- Congestion Window (cwnd)

## Expected Result

ECN modes should sustain higher throughput and lower retransmission rates as loss increases.

## Recommended Plot

- X-axis: Loss (%)
- Y-axis: Throughput
- One line per ECN mode
- Secondary bars: Retransmissions

---

# T02 — Congestion Control Comparison

## Objective

Compare Cubic, Reno, and BBR under different ECN modes.

## Hypothesis

- BBR largely ignores ECN signals.
- Reno reacts more aggressively to congestion.
- Cubic + ECN provides the best balance.

## Parameters

| Variable | Values |
|-----------|----------|
| CC Algorithm | cubic, reno, bbr |
| ECN Mode | none, classic, accecn |
| Duration | 60s |

## Execution

```bash
for CC in cubic reno bbr; do
  for MODE in none classic accecn; do
    CC_ALGO=$CC MODE=$MODE DURATION=60 \
      ./scripts/run.sh 60
  done
done
```

## Required Modification

`scripts/configure-ecn.sh`

```bash
if [ -n "$CC_ALGO" ]; then
  apply_sysctl net.ipv4.tcp_congestion_control "$CC_ALGO"
fi
```

## Metrics

- Throughput
- RTT
- cwnd evolution
- Retransmissions
- ECN Marks

## Expected Result

BBR should maintain throughput despite ECN markings, while Cubic should better leverage ECN feedback.

## Recommended Plot

Heatmap with congestion control algorithm on one axis, ECN mode on the other axis, and cells showing average throughput and average RTT.

---

# T03 — Bandwidth Sweep

## Objective

Evaluate ECN performance across different link capacities.

## Hypothesis

Higher-capacity links benefit more from ECN due to larger Bandwidth-Delay Products (BDPs).

## Parameters

| Variable | Values |
|-----------|----------|
| Link Rate | 10mbit, 100mbit, 1000mbit |
| ECN Mode | none, classic, accecn, dctcp |
| Duration | 60s |

## Execution

```bash
for RATE in 10mbit 100mbit 1000mbit; do
  MODES="none classic accecn dctcp" \
  RATE=$RATE \
  DURATION=60 \
  ./scripts/run.sh 60
done
```

## Metrics

- Throughput
- Efficiency: throughput / configured rate
- RTT
- cwnd
- ECN Marks

## Expected Result

ECN should maintain efficiency above 90% across all bandwidths.

## Recommended Plot

Grouped bar chart with link rate on the X-axis and efficiency (%) on the Y-axis, grouped by ECN mode.

---

# T04 — RTT Sweep: Data Center vs WAN

## Objective

Compare ECN behavior across a wide RTT range, from data center-like latency to WAN-like latency.

## Hypothesis

DCTCP excels in low-latency environments but may become unstable as RTT increases. AccECN and Cubic should be more suitable for WAN-like scenarios.

## Parameters

| Variable | Values |
|-----------|----------|
| Delay | 1ms, 5ms, 10ms, 25ms, 50ms, 100ms |
| Jitter | 0ms |
| ECN Mode | none, classic, accecn, dctcp |
| Duration | 60s |

## Execution

```bash
for DELAY_MS in 1 5 10 25 50 100; do
  MODES="none classic accecn dctcp" \
  DELAY="${DELAY_MS}ms" \
  JITTER="0ms" \
  DURATION=60 \
  ./scripts/run.sh 60
done
```

## Metrics

- Throughput
- Observed RTT
- cwnd
- ECN Marks
- Throughput standard deviation

## Expected Result

DCTCP should degrade as RTT increases, especially above typical data center latency ranges.

## Recommended Plot

Line chart with delay on the X-axis and throughput on the Y-axis, one line per ECN mode. A second plot can compare observed RTT against configured RTT.

---

# T05 — Buffer Size Sensitivity

## Objective

Evaluate how FQ-CoDel target and buffer limit affect queueing latency, throughput, drops, and ECN marking frequency.

## Hypothesis

Smaller buffers cause more marks/drops but lower latency. Larger buffers cause bufferbloat in no-ECN scenarios, while ECN should keep latency closer to the configured FQ-CoDel target.

## Parameters

| Variable | Values |
|-----------|----------|
| FQ-CoDel Target | 1ms, 5ms, 20ms, 50ms |
| Buffer Limit | 100, 500, 1000 packets |
| ECN Mode | none, classic, accecn |
| Duration | 60s |

## Execution

```bash
for TARGET in 1ms 5ms 20ms 50ms; do
  for LIMIT in 100 500 1000; do
    MODES="none classic accecn" \
    ECN_TARGET=$TARGET \
    BUFFER_LIMIT=$LIMIT \
    DURATION=60 \
    ./scripts/run.sh 60
  done
done
```

## Required Modification

`scripts/setup-qdisc.sh`

```bash
BUFFER_LIMIT=${BUFFER_LIMIT:-1000}

# Example:
# tc qdisc add dev $IFACE parent 1:10 handle 20: fq_codel \
#   target $ECN_TARGET limit $BUFFER_LIMIT interval 100ms ecn
```

## Metrics

- RTT mean
- RTT p99
- Throughput
- ECN Marks
- Drops

## Expected Result

For no-ECN, latency should increase with larger buffers. For ECN modes, latency should remain closer to the configured target.

## Recommended Plot

Scatter plot with RTT on one axis and throughput on the other, grouped by ECN mode and buffer configuration.

---

# T06 — Fairness Between ECN and Non-ECN Flows

## Objective

Evaluate whether ECN-aware and ECN-unaware flows fairly share the same bottleneck.

## Hypothesis

Non-ECN flows may dominate the bottleneck because they do not react to CE marks, while ECN-aware flows may reduce their sending rate and become penalized.

## Implementation Notes

This experiment requires two simultaneous `iperf3` flows using different ECN configurations. A practical approach is to use separate network namespaces or separate client hosts.

## Example Script

Create `scripts/run-fairness.sh`:

```bash
#!/bin/bash
set -euo pipefail

DURATION=${DURATION:-60}
SERVER=${SERVER:?SERVER is required}
RESULTS_DIR=${RESULTS_DIR:-results/fairness}

mkdir -p "$RESULTS_DIR"

ssh accecn@$SERVER "iperf3 -s -D -p 5201"
ssh accecn@$SERVER "iperf3 -s -D -p 5202"

ip netns exec ns_noecn \
  iperf3 -c "$SERVER" -p 5201 -t "$DURATION" -J \
  > "$RESULTS_DIR/flow_noecn.json" &

ip netns exec ns_ecn \
  iperf3 -c "$SERVER" -p 5202 -t "$DURATION" -J \
  > "$RESULTS_DIR/flow_ecn.json" &

wait
```

## Metrics

- Per-flow throughput
- Jain's Fairness Index
- Per-flow retransmissions

## Fairness Formula

```text
J = (sum(x_i))^2 / (n * sum(x_i^2))
```

## Expected Result

Fairness Index below 0.90 indicates significant unfairness. If the ECN flow obtains less than 80% of the average throughput, it indicates ECN penalization.

## Recommended Plot

Stacked bar chart showing per-flow throughput, with a reference line at the ideal 50/50 share.

---

# T07 — Flow Completion Time

## Objective

Measure the completion time of short TCP flows, simulating web-like traffic.

## Hypothesis

ECN reduces Flow Completion Time (FCT) by avoiding retransmission timeouts. For very short flows, ECN may provide little or no benefit because there is not enough time for the signal to affect the sender.

## Flow Sizes

| Size |
|--------|
| 10 KB |
| 100 KB |
| 1 MB |
| 10 MB |

## Example Script

Create `scripts/run-fct.sh`:

```bash
#!/bin/bash
set -euo pipefail

SERVER=${SERVER:?SERVER is required}
DURATION=${DURATION:-60}
RESULTS_DIR=${RESULTS_DIR:-results/fct}

mkdir -p "$RESULTS_DIR"

for SIZE_BYTES in 10240 102400 1048576 10485760; do
  for MODE in none classic accecn; do
    ./scripts/configure-ecn.sh "$MODE"

    START=$(date +%s%N)
    iperf3 -c "$SERVER" -n "$SIZE_BYTES" -J \
      > "$RESULTS_DIR/fct_${MODE}_${SIZE_BYTES}.json"
    END=$(date +%s%N)

    FCT_MS=$(( (END - START) / 1000000 ))
    echo "$MODE,$SIZE_BYTES,$FCT_MS" \
      >> "$RESULTS_DIR/fct-summary.csv"
  done
done
```

## Metrics

- FCT in milliseconds
- Retransmissions
- Timeouts

## Expected Result

ECN should reduce FCT mainly for medium-sized flows, especially from 100 KB to 10 MB.

## Recommended Plot

CDF plot of FCT for each ECN mode, with markers by flow-size range.

---

# T08 — Bufferbloat Under Load

## Objective

Measure queueing latency during sustained bulk transfer.

## Hypothesis

Without ECN, the buffer fills before packet drops occur, causing high RTT. With ECN and FQ-CoDel, packets are marked earlier and RTT remains close to the base RTT plus the FQ-CoDel target.

## Execution

```bash
iperf3 -c "$SERVER" -t 60 &
IPERF_PID=$!

ping -i 0.1 -c 600 "$SERVER" | tee "results/ping_${MODE}_${DURATION}.txt"

wait "$IPERF_PID"
```

## Suggested Addition to `scripts/run.sh`

```bash
ssh "$CLIENT_USER@$CLIENT_HOST" \
  "ping -i 0.1 -c $((DURATION*10)) $SERVER_IP" \
  > "$RUN_DIR/ping.log" &

PING_PID=$!
```

## Metrics

- RTT min
- RTT mean
- RTT max
- RTT p95
- RTT p99
- Throughput during ping measurement

## Expected Result

No-ECN should show high RTT under load, while ECN should keep RTT near the baseline.

## Recommended Plot

Time series with ICMP RTT on the Y-axis and time on the X-axis. The bulk transfer interval can be highlighted.

---

# T09 — AQM Comparison

## Objective

Compare FQ-CoDel with simpler queueing strategies to separate the benefit of ECN from the benefit of Active Queue Management.

## Hypothesis

Without AQM, ECN has little effect because there is no proactive marking. The combination ECN + AQM is expected to provide the best result.

## Required Modification

`scripts/setup-qdisc.sh`

```bash
if [ "$AQM" = "none" ]; then
  tc qdisc add dev "$IFACE" root handle 1: htb default 10
  tc class add dev "$IFACE" parent 1: classid 1:10 htb rate "$RATE"
  tc qdisc add dev "$IFACE" parent 1:10 handle 20: netem \
    delay "$DELAY" "$JITTER" loss "$LOSS" limit "$BUFFER_LIMIT"
else
  # Current configuration with fq_codel or other AQM
fi
```

## Execution

```bash
for AQM in fq_codel pfifo tbf none; do
  for MODE in none classic accecn; do
    AQM=$AQM MODE=$MODE DURATION=60 \
      ./scripts/run.sh 60
  done
done
```

## Metrics

- Throughput
- Drops
- ECN Marks
- RTT
- cwnd

## Expected Result

FQ-CoDel + ECN should provide the best latency-throughput tradeoff. ECN without AQM should behave similarly to no-ECN.

## Recommended Plot

Matrix heatmap with AQM type in rows and ECN mode in columns. Cell values can represent average throughput or average RTT.

---

# T10 — Extreme Jitter and Packet Reordering

## Objective

Evaluate the robustness of ECN modes under high jitter and packet reordering.

## Hypothesis

High jitter causes RTT variation that can lead to false congestion signals. Packet reordering may increase retransmissions. ECN-aware modes should be more robust because CE marks provide an additional signal beyond packet loss and timeouts.

## Execution

```bash
for JITTER_MS in 0 2 5 10 25; do
  DELAY=25ms \
  JITTER="${JITTER_MS}ms" \
  MODES="none classic accecn" \
  DURATION=60 \
  ./scripts/run.sh 60
done
```

## Required Modification for Reordering

`scripts/setup-qdisc.sh`

```bash
REORDER=${REORDER:-"0%"}

# Example:
# tc qdisc add dev "$IFACE" parent 1:10 handle 20: netem \
#   delay "$DELAY" "$JITTER" reorder "$REORDER" 50% gap 5
```

## Metrics

- Throughput standard deviation
- RTT variance
- cwnd oscillations
- ECN Marks
- Retransmissions

## Expected Result

ECN-aware modes should be more robust to jitter because ECN marks provide additional congestion information beyond loss and timeout behavior.

## Recommended Plot

Violin plot showing throughput distribution for each jitter level and ECN mode.

---

# Proposed Repository Organization

```text
tcp-ecn-lab/
├── experiments/
│   ├── baseline.env
│   ├── loss-sweep.env
│   ├── cc-comparison.env
│   ├── bandwidth-sweep.env
│   ├── rtt-sweep.env
│   ├── buffer-sweep.env
│   └── ...
├── scripts/
│   ├── lib.sh
│   ├── run.sh
│   ├── run-suite.sh
│   ├── configure-ecn.sh
│   └── setup-qdisc.sh
├── analysis/
│   ├── parse-results.py
│   ├── plot-results.py
│   ├── plot-fct.py
│   ├── plot-bufferbloat.py
│   └── fairness.py
├── results/
│   └── YYYYMMDD-experiment-name/
└── docs/
    └── EXPERIMENTS.md
```

---

# Automation

Create `scripts/run-suite.sh`:

```bash
#!/bin/bash
set -euo pipefail

SUITE=${1:-"all"}

for ENV_FILE in experiments/${SUITE}*.env; do
  echo "=== Running experiment: $ENV_FILE ==="

  set -a
  source "$ENV_FILE"
  set +a

  ./scripts/run.sh "$DURATION"

  python3 analysis/parse-results.py
  python3 analysis/plot-results.py \
    --output "results/latest-$(basename "$ENV_FILE" .env).png"
done
```

---

# Result Standardization

Each run should generate a `params.json` file:

```json
{
  "experiment_id": "T02-bbr-vs-cubic",
  "timestamp": "20260601-120000",
  "parameters": {
    "rate": "100mbit",
    "delay": "25ms",
    "cc": "bbr",
    "mode": "accecn"
  },
  "git_commit": "$(git rev-parse HEAD)",
  "kernel": "$(uname -r)"
}
```

---

# Reproducibility Recommendations

- Add a `Makefile` with targets:
  - `make test-smoke`
  - `make test-full`
  - `make analyze`
  - `make plots`
- Save the kernel version using `uname -r` in every run.
- Save the current Git commit using `git rev-parse HEAD`.
- Add a pinned `requirements.txt`.
- Add a `docker-compose.yml` for local analysis of previously collected results.

Example `requirements.txt`:

```text
matplotlib==3.9.0
pandas==2.2.2
numpy==1.26.4
scapy==2.5.0
```

---

# Experiment Plan

| ID | Scenario | Main Variable | Metrics | Expected Result | Priority |
|----|----------|---------------|---------|-----------------|----------|
| T01 | Packet loss sweep | Loss rate (%) | throughput, retransmissions, ECN marks | ECN maintains higher throughput under loss | High |
| T02 | Cubic vs Reno vs BBR | Congestion control algorithm | throughput, cwnd, RTT, ECN marks | BBR ignores ECN; Cubic+ECN is balanced | High |
| T03 | Bandwidth sweep | Link capacity | efficiency, throughput, ECN marks | ECN maintains high efficiency | High |
| T04 | RTT sweep | Base latency | throughput, RTT, cwnd, stddev | DCTCP degrades with high RTT | High |
| T05 | Buffer variation | target and limit | RTT p99, throughput, ECN marks, drops | ECN keeps RTT near target | Medium |
| T06 | ECN vs non-ECN fairness | Mixed flows | per-flow throughput, Jain FI | Non-ECN may dominate | High |
| T07 | Flow Completion Time | Flow size | FCT, retransmissions, timeouts | ECN reduces FCT for medium flows | Medium |
| T08 | Bufferbloat | Background load | RTT ICMP, throughput | ECN limits queueing delay | High |
| T09 | AQM comparison | Queue discipline | throughput, drops, RTT, ECN marks | FQ-CoDel+ECN is best | Medium |
| T10 | Jitter and reordering | Jitter/reorder | throughput stddev, RTT variance, retransmissions | ECN is more robust | Low |

---

# Summary

The current lab is solid for comparing the four ECN modes under ideal conditions: fixed RTT, no packet loss, one flow, 100 Mbps, and FQ-CoDel enabled.

The proposed experiments expand the evaluation to fairness, flow completion time, bufferbloat, congestion control algorithms, buffer size, delay, loss, bandwidth, and AQM comparison. These scenarios are essential for a broader characterization of ECN behavior in production-like environments.
