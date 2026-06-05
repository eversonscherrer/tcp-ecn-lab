#!/usr/bin/env python3
"""T03 — Bandwidth Sweep: throughput efficiency and behaviour across link rates.

Panels:
  1. Absolute throughput per mode per rate (grouped bars)
  2. Link utilisation % = throughput / rate  (grouped bars)
  3. ECN marks per mode per rate             (grouped bars)
  4. Mean cwnd per mode per rate             (grouped bars)

Usage:
    python3 analysis/plot-t03-bandwidth-sweep.py [--results results/summary.csv]
                                                  [--output  docs/t03-bandwidth-sweep.png]
"""

import argparse
import csv
import re
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

MODE_ORDER  = ["none", "classic", "accecn", "dctcp"]
MODE_COLORS = {"none": "#e74c3c", "classic": "#3498db",
               "accecn": "#2ecc71", "dctcp": "#f39c12"}
MODE_LABELS = {"none": "No ECN", "classic": "Classic ECN",
               "accecn": "AccECN",  "dctcp": "DCTCP+AccECN"}

RATE_ORDER = ["10mbit", "100mbit", "1000mbit"]
RATE_LABELS = {"10mbit": "10 Mbps", "100mbit": "100 Mbps", "1000mbit": "1 Gbps"}


def rate_to_mbps(rate_str: str) -> float:
    """Convert '10mbit' → 10.0, '1000mbit' → 1000.0."""
    m = re.match(r"(\d+(?:\.\d+)?)\s*mbit", rate_str, re.IGNORECASE)
    return float(m.group(1)) if m else float("nan")


def load(csv_path: Path) -> list[dict]:
    rows = []
    with csv_path.open() as f:
        for row in csv.DictReader(f):
            # T03 rows: have a rate field AND no cc_algo override AND loss is 0% or blank
            rate = row.get("rate", "").strip()
            cc   = row.get("cc_algo", "").strip()
            loss = row.get("loss", "").strip()
            if rate and not cc and loss in ("0%", ""):
                rows.append(row)
    return rows


def mean_of(rows, rate, mode, metric) -> float | None:
    vals = []
    for r in rows:
        if r.get("rate") == rate and r.get("mode") == mode:
            try:
                vals.append(float(r[metric]))
            except (ValueError, KeyError):
                pass
    return float(np.mean(vals)) if vals else None


def grouped_bars(ax, rows, rates, modes, metric, title, ylabel,
                 rate_labels, scale_fn=None):
    x = np.arange(len(rates))
    w = 0.72 / max(len(modes), 1)
    offset = -(len(modes) - 1) / 2
    for i, mode in enumerate(modes):
        y = []
        for rate in rates:
            v = mean_of(rows, rate, mode, metric)
            if v is not None and scale_fn:
                v = scale_fn(v, rate)
            y.append(v if v is not None else 0)
        ax.bar(x + (offset + i) * w, y, w,
               color=MODE_COLORS.get(mode, "gray"),
               label=MODE_LABELS.get(mode, mode), alpha=0.85)
    ax.set_xticks(x)
    ax.set_xticklabels([rate_labels.get(r, r) for r in rates], fontsize=10)
    ax.set_title(title, fontsize=10)
    ax.set_ylabel(ylabel, fontsize=9)
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3, axis="y")
    ax.set_ylim(bottom=0)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results/summary.csv")
    ap.add_argument("--output",  default="docs/t03-bandwidth-sweep.png")
    args = ap.parse_args()

    csv_path = Path(args.results)
    if not csv_path.exists():
        print(f"File not found: {csv_path}", file=sys.stderr)
        return 1

    rows = load(csv_path)
    if not rows:
        print("No T03 rows found. Run parse-results.py after the T03 experiments.",
              file=sys.stderr)
        return 1

    # Only keep rates and modes present in the data
    rates = [r for r in RATE_ORDER
             if any(row.get("rate") == r for row in rows)]
    modes = [m for m in MODE_ORDER
             if any(row.get("mode") == m for row in rows)]

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle(
        "T03 — TCP/ECN Performance Across Link Rates\n"
        "25 ms RTT · fq_codel target 5 ms · 0 % loss · 60 s runs",
        fontsize=13, fontweight="bold",
    )

    # Panel 1 — Absolute throughput
    grouped_bars(axes[0, 0], rows, rates, modes,
                 "throughput_recv_mbps",
                 "Absolute Throughput", "Throughput (Mbps)",
                 RATE_LABELS)

    # Panel 2 — Link utilisation %
    def utilisation(v, rate):
        cap = rate_to_mbps(rate)
        return (v / cap * 100) if cap else 0

    grouped_bars(axes[0, 1], rows, rates, modes,
                 "throughput_recv_mbps",
                 "Link Utilisation", "Utilisation (%)",
                 RATE_LABELS, scale_fn=utilisation)
    axes[0, 1].axhline(90, color="gray", linestyle="--", linewidth=1,
                       label="90 % reference")
    axes[0, 1].set_ylim(0, 110)

    # Panel 3 — ECN marks
    grouped_bars(axes[1, 0], rows, rates, modes,
                 "ecn_mark",
                 "ECN Marks (fq_codel)", "CE Marks",
                 RATE_LABELS)

    # Panel 4 — Mean cwnd
    grouped_bars(axes[1, 1], rows, rates, modes,
                 "cwnd_mean",
                 "Mean Sender cwnd", "cwnd (segments)",
                 RATE_LABELS)

    plt.tight_layout()
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
