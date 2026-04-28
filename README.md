# AccECN TCP Experiment

Experiment comparing TCP throughput and congestion behavior across four modes:
**No ECN**, **Classic ECN** (RFC 3168), **AccECN** (RFC 9331), and **DCTCP+AccECN** —
using two Ubuntu Server 26.04 VMs on Proxmox. The orchestration scripts run on one of
the VMs (or any Linux host with SSH access to both) and control the experiment remotely
via SSH.

## Topology

```mermaid
graph LR
    subgraph Proxmox ["Proxmox Host"]
        direction LR

        C["accecn2\nUbuntu Server 26.04\n─────────────\niperf3 receiver\n(client role)"]
        S["accecn1\nUbuntu Server 26.04\n─────────────\niperf3 sender\n(server role)"]

        C -- "data flow · iperf3 -R\nTCP port 5201" --> S
        S -. "tc qdisc on egress:\nHTB → netem → fq_codel ecn" .-> C
    end

    C -- "run.sh executed here\n(SSH into accecn1)" --> S
```

> **Why `-R` (reverse)?** Traffic flows from server to client, so the `tc` qdisc applied
> on the server's egress shapes the experiment traffic. The client only sends ACKs.

## How It Works

For each mode (`none` → `classic` → `accecn` → `dctcp`) the orchestrator:

1. Configures `net.ipv4.tcp_ecn`, `net.ipv4.tcp_ecn_option`, and optionally
   `net.ipv4.tcp_congestion_control` on both VMs.
2. Applies a `tc` qdisc stack on the server's egress interface:
   - **HTB** — rate limiter (default `RATE=100mbit`)
   - **netem** — adds controlled delay and jitter (default `DELAY=25ms JITTER=2ms`)
   - **fq_codel ecn** — AQM with ECN marking (configurable `ECN_TARGET`, default `5ms`)
3. Starts `iperf3 -s` on the server and `iperf3 -c -R` on the client.
4. Samples `ss -tin` every 500 ms on **both** sides (client: RTT / receiver window; server: sender cwnd).
5. Captures the full TCP flow with `tcpdump`, then derives a small handshake pcap
   for quick SYN/SYN-ACK inspection.
6. After the transfer, collects `tc -s qdisc show` to record ECN marks and packet drops.
7. Downloads all artefacts and runs `analysis/parse-results.py` → `results/summary.csv`.

### ECN mode sysctl table

| Mode | `tcp_ecn` | `tcp_ecn_option` | `tcp_congestion_control` | Effect |
|------|-----------|-------------------|--------------------------|--------|
| `none` | 0 | — | cubic | No ECN; fq_codel drops instead of marking → throughput collapses |
| `classic` | 1 | 0 | cubic | RFC 3168 ECN; fq_codel marks; binary cwnd halving on each CE |
| `accecn` | 3 | 2 | cubic | RFC 9331 AccECN; ACKs carry exact CE count; Cubic still halves |
| `dctcp` | 3 | 2 | dctcp | DCTCP uses the AccECN CE count for proportional cwnd reduction |

## Experimental Results

All validated experiments below ran on kernel **7.0.0-14-generic**, link rate
**100 Mbit/s**, one-way delay **25 ms ± 2 ms**, `fq_codel target 5ms`, and one
iperf stream. These runs were collected after fixing AccECN configuration to use
`net.ipv4.tcp_ecn=3`.

### Corrected 60 s run

| Mode | Recv throughput | Min non-zero interval | Stddev | fq_codel marks | fq_codel drops | Mean cwnd |
|------|----------------:|----------------------:|-------:|---------------:|---------------:|----------:|
| No ECN | 9.42 Mbps | 6.28 Mbps | 27.42 | 0 | 1 | 16.7 |
| Classic ECN | 93.78 Mbps | 79.61 Mbps | 2.97 | 16 | 0 | 100.2 |
| AccECN | 92.87 Mbps | 78.56 Mbps | 3.08 | 19 | 0 | 122.4 |
| DCTCP+AccECN | 90.70 Mbps | 9.43 Mbps | 15.53 | 3,899 | 0 | 133.4 |

### Corrected 120 s run

| Mode | Recv throughput | Min non-zero interval | Stddev | fq_codel marks | fq_codel drops | Mean cwnd |
|------|----------------:|----------------------:|-------:|---------------:|---------------:|----------:|
| No ECN | 0.10 Mbps | 12.57 Mbps | n/a | 0 | 4 | 6.4 |
| Classic ECN | 93.77 Mbps | 77.54 Mbps | 2.98 | 32 | 0 | 122.9 |
| AccECN | 92.98 Mbps | 78.56 Mbps | 2.70 | 33 | 0 | 120.8 |
| DCTCP+AccECN | 92.75 Mbps | 9.43 Mbps | 11.21 | 8,393 | 0 | 137.5 |

### Packet-capture validation

The new `flow.pcap` files show that the corrected AccECN and DCTCP runs really
negotiate and use AccECN. Classic ECN does not.

| Run | Mode | AE packets | AccECN option packets | AccECN SYNs | Classic ECN SYNs |
|-----|------|-----------:|----------------------:|------------:|-----------------:|
| 60 s | Classic ECN | 0 | 0 | 0 | 2 |
| 60 s | AccECN | 2 | 123,513 | 2 | 0 |
| 60 s | DCTCP+AccECN | 4 | 119,181 | 2 | 0 |
| 120 s | Classic ECN | 0 | 0 | 0 | 2 |
| 120 s | AccECN | 2 | 246,683 | 2 | 0 |
| 120 s | DCTCP+AccECN | 4 | 241,879 | 2 | 0 |

### Updated conclusions

The original `accecn` runs were not valid AccECN evidence. They used
`tcp_ecn=1`, so packet captures showed Classic ECN SYN negotiation and no TCP
AE bit or AccECN option. The corrected runs use `tcp_ecn=3`, and the new pcaps
confirm AccECN negotiation.

With the default 5 ms `fq_codel` target, **Classic ECN and AccECN with Cubic are
nearly identical in throughput**. This is expected: AccECN improves feedback
accuracy, but Cubic still reacts to congestion in a Classic ECN-like way. In
these runs, AccECN is a protocol-level difference more than a throughput win.

**No ECN collapses under the same queue discipline.** When packets are not
ECT-capable, `fq_codel ecn` has to drop instead of marking. The 60 s run still
delivered 9.42 Mbps, but the 120 s run fell to 0.10 Mbps, showing that the
non-ECN case is unstable and highly sensitive to drop timing.

**DCTCP+AccECN receives far more CE marks and keeps high average throughput, but
it is not the smoothest result in this setup.** DCTCP saw 3,899 marks in 60 s
and 8,393 marks in 120 s, versus only 16-33 marks for Classic/AccECN Cubic.
Average throughput stayed close to line rate, but the low minimum throughput and
higher standard deviation show startup or transient dips that need more targeted
analysis before claiming DCTCP is strictly more stable here.

### What differentiates each mode now

| Observation | No ECN | Classic ECN | AccECN (Cubic) | DCTCP+AccECN |
|-------------|--------|-------------|----------------|--------------|
| Negotiates AccECN | no | no | yes | yes |
| Uses AccECN TCP option | no | no | yes | yes |
| Avoids fq_codel drops | no | yes | yes | yes |
| Maintains high average throughput | no | yes | yes | yes |
| Clear throughput gain over Classic ECN | no | baseline | no | not at target 5 ms |
| Receives many proportional CE samples | no | no | no | yes |
| Needs more stability analysis | yes | no | no | yes |

## Setup

### Prerequisites

- Two Ubuntu Server 26.04 VMs with SSH access between them (kernel ≥ 7.0 required for `tcp_ecn_option`).
- Passwordless `sudo` on each VM (required for `tc`, `tcpdump`, `sysctl`):

```bash
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/accecn
sudo chmod 440 /etc/sudoers.d/accecn
```

### 1. Configure

```bash
cp .env.example .env
# Edit .env with the real IPs, users, and ports of both VMs.
```

### 2. Verify access

```bash
./scripts/check.sh
```

### 3. Install VM dependencies

```bash
./scripts/provision.sh
# Installs: iproute2, iperf3, tcpdump, python3
```

## Running Experiments

```bash
# Quick smoke test (5 s per mode)
./scripts/run.sh 5

# Standard run — all 4 modes, 60 s each (recommended)
MODES="none classic accecn dctcp" ./scripts/run.sh 60

# Aggressive marking: expose DCTCP vs Cubic difference
MODES="none classic accecn dctcp" ECN_TARGET=1ms ./scripts/run.sh 60

# Multiple parallel streams + aggressive marking
MODES="none classic accecn dctcp" ECN_TARGET=1ms STREAMS=4 ./scripts/run.sh 60

# Custom network conditions
RATE=50mbit DELAY=50ms JITTER=5ms ./scripts/run.sh 60
```

Results are saved under `results/<timestamp>-<mode>/`. Each directory also contains a
`params.txt` with the exact environment variables used for that run.

## Analysis

```bash
# (Re-)generate summary.csv from all result directories
python3 analysis/parse-results.py

# Generate results/comparison.png (4-panel comparison chart)
python3 analysis/plot-results.py

# Validate packet captures for ECN/AccECN evidence
python3 analysis/validate-pcaps.py
```

Both scripts work from any working directory; paths are resolved relative to the script
location. The chart adapts automatically to whichever modes are present in the data.

### Output files per run

| File | Contents |
|------|----------|
| `iperf-client.json` | Full iperf3 JSON (per-second intervals + summary) |
| `iperf-server.json` | Server-side iperf3 JSON |
| `ss-samples.log` | Client `ss -tin` samples every 500 ms (RTT, receiver window) |
| `server-ss.log` | Server `ss -tin` samples every 500 ms (sender cwnd) |
| `flow.pcap` | Full tcpdump capture for `tcp port 5201` (verify AccECN options and ECT/CE marking) |
| `handshake.pcap` | SYN/SYN-ACK packets extracted from `flow.pcap` for quick ECN setup inspection |
| `qdisc.log` | `tc qdisc show` at test start |
| `qdisc-final.log` | `tc -s qdisc show` at test end (`ecn_mark`, `pkt_dropped`) |
| `params.txt` | Run parameters: `rate`, `delay`, `ecn_target`, `streams` |
| `server-ecn.log` | sysctl state on server after configuration |
| `client-ecn.log` | sysctl state on client after configuration |

### summary.csv columns

| Column | Description |
|--------|-------------|
| `mode` | `none`, `classic`, `accecn`, or `dctcp` |
| `ecn_target` | fq_codel marking threshold used in this run |
| `streams` | Number of parallel iperf3 streams |
| `throughput_recv_mbps` | Mean receive throughput over the full run |
| `throughput_min_mbps` | Minimum per-second throughput (worst-case interval) |
| `throughput_stddev_mbps` | Std deviation of per-second throughput |
| `ecn_mark` | ECN marks issued by fq_codel |
| `pkt_dropped` | Packets dropped by fq_codel |
| `rtt_mean_ms` | Mean RTT from `ss` samples |
| `cwnd_mean` | Mean sender cwnd from `server-ss.log` |
| `cwnd_min` | Minimum sender cwnd (captures worst congestion response) |

`validate-pcaps.py` writes `results/pcap-validation.csv` with packet-level evidence:
ECT/CE packets, CE packets, TCP AE-bit packets, AccECN option packets, and SYNs that
look like Classic ECN or AccECN setup.

## AccECN Kernel Requirement

AccECN requires `net.ipv4.tcp_ecn_option` to exist in `/proc/sys`. This sysctl was
added in Linux 6.x. If it is absent the `accecn` and `dctcp` modes exit with an error —
this is expected on older kernels.

```bash
sysctl net.ipv4.tcp_ecn          # must accept value 3 for AccECN initiation
sysctl net.ipv4.tcp_ecn_option   # must return 0, 1, 2, or 3
```

DCTCP is available as a loadable kernel module and is loaded automatically by
`configure-ecn.sh` when the `dctcp` mode is selected:

```bash
sudo modprobe tcp_dctcp
```
