#!/usr/bin/env python3
"""T04 — RTT Sweep: throughput, stability and ECN behaviour from DC to WAN.

Panels:
  1. Throughput vs RTT (line chart, one line per mode)
  2. Throughput StdDev vs RTT (instability)
  3. ECN Marks vs RTT
  4. Mean cwnd vs RTT (should grow linearly with RTT to fill BDP)

Usage:
    python3 analysis/plot-t04-rtt-sweep.py [--results results/summary.csv]
                                            [--output  docs/t04-rtt-sweep.png]
"""

import argparse
import csv
import re
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

MODE_ORDER  = ["none", "classic", "accecn", "dctcp"]
MODE_COLORS = {"none": "#e74c3c", "classic": "#3498db",
               "accecn": "#2ecc71", "dctcp": "#f39c12"}
MODE_LABELS = {"none": "No ECN", "classic": "Classic ECN",
               "accecn": "AccECN",  "dctcp": "DCTCP+AccECN"}

DELAY_ORDER = ["1ms", "5ms", "10ms", "25ms", "50ms", "100ms"]


def delay_to_ms(d: str) -> float:
    m = re.match(r"(\d+(?:\.\d+)?)\s*ms", d, re.IGNORECASE)
    return float(m.group(1)) if m else float("nan")


def load(csv_path: Path) -> list[dict]:
    rows = []
    with csv_path.open() as f:
        for row in csv.DictReader(f):
            delay = row.get("delay", "").strip()
            loss  = row.get("loss",  "").strip()
            cc    = row.get("cc_algo", "").strip()
            rate  = row.get("rate", "").strip()
            # T04 rows: delay field set, jitter=0ms (saved as jitter in params),
            # no cc_algo override, loss=0% or blank, rate=100mbit
            if delay and not cc and loss in ("0%", "") and rate in ("100mbit", ""):
                rows.append(row)
    return rows


def aggregate(rows, delay, mode, metric) -> float | None:
    vals = []
    for r in rows:
        if r.get("delay") == delay and r.get("mode") == mode:
            try:
                vals.append(float(r[metric]))
            except (ValueError, KeyError):
                pass
    return float(np.mean(vals)) if vals else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results/summary.csv")
    ap.add_argument("--output",  default="docs/t04-rtt-sweep.png")
    args = ap.parse_args()

    csv_path = Path(args.results)
    if not csv_path.exists():
        print(f"File not found: {csv_path}", file=sys.stderr)
        return 1

    rows = load(csv_path)
    if not rows:
        print("No T04 rows found. Run parse-results.py after the T04 experiments.",
              file=sys.stderr)
        return 1

    delays = [d for d in DELAY_ORDER
              if any(r.get("delay") == d for r in rows)]
    modes  = [m for m in MODE_ORDER
              if any(r.get("mode")  == m for r in rows)]
    delay_ms = [delay_to_ms(d) for d in delays]
    # RTT = 2 × one-way delay
    rtt_ms = [2 * d for d in delay_ms]

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle(
        "T04 — TCP/ECN Performance Across RTTs  (Data Center → WAN)\n"
        "100 Mbps · fq_codel target 5 ms · 0 % loss · 60 s runs",
        fontsize=13, fontweight="bold",
    )

    def line_panel(ax, metric, title, ylabel, logy=False):
        for mode in modes:
            y = [aggregate(rows, d, mode, metric) for d in delays]
            ax.plot(rtt_ms, y, "o-",
                    color=MODE_COLORS[mode], label=MODE_LABELS[mode],
                    linewidth=2, markersize=7)
        ax.set_xlabel("RTT (ms)")
        ax.set_ylabel(ylabel, fontsize=9)
        ax.set_title(title, fontsize=10)
        ax.set_xscale("log")
        ax.xaxis.set_major_formatter(mticker.FuncFormatter(
            lambda v, _: f"{v:g} ms"))
        ax.set_xticks(rtt_ms)
        ax.legend(fontsize=9)
        ax.grid(True, alpha=0.3, which="both")
        if logy:
            ax.set_yscale("log")
        ax.set_ylim(bottom=0 if not logy else None)

    line_panel(axes[0, 0], "throughput_recv_mbps",
               "Throughput vs RTT", "Throughput (Mbps)")

    line_panel(axes[0, 1], "throughput_stddev_mbps",
               "Throughput Instability vs RTT", "StdDev (Mbps)")

    line_panel(axes[1, 0], "ecn_mark",
               "ECN Marks vs RTT", "CE Marks (fq_codel)")

    line_panel(axes[1, 1], "cwnd_mean",
               "Mean cwnd vs RTT", "cwnd (segments)")

    # Overlay theoretical BDP line on cwnd panel
    # BDP (segments) = rate × RTT / (2 × MSS) = 100e6 × RTT_s / (2 × 1460 × 8)
    bdp_segs = [100e6 * (r / 1000) / (2 * 1460 * 8) for r in rtt_ms]
    axes[1, 1].plot(rtt_ms, bdp_segs, "k--", linewidth=1.5,
                    label="BDP (100 Mbps)", zorder=0)
    axes[1, 1].legend(fontsize=8)

    plt.tight_layout()
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
