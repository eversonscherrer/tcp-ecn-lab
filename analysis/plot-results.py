#!/usr/bin/env python3
"""plot-results.py — Generate comparison plots for the three ECN modes.

Usage:
    python3 plot-results.py <results_root_dir>

Outputs (in <results_root_dir>/plots/):
    throughput-comparison.png   — throughput over time, three lines
    retransmits-bar.png         — total retransmits per mode
    cwnd-evolution.png          — cwnd over time per mode
    rtt-evolution.png           — RTT over time per mode
    summary-table.png           — text summary
"""

import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

MODE_COLORS = {"none": "#888888", "classic": "#3b82f6", "accecn": "#10b981"}
MODE_LABELS = {"none": "No ECN", "classic": "Classic ECN", "accecn": "AccECN"}


def load_runs(root: Path) -> dict:
    """Return {mode: latest_run_dir} mapping."""
    runs = defaultdict(list)
    for d in sorted(root.iterdir()):
        if not d.is_dir():
            continue
        match = re.match(r"(\d{8}-\d{6})-(\w+)", d.name)
        if match:
            runs[match.group(2)].append(d)
    # Use the latest run per mode
    return {mode: dirs[-1] for mode, dirs in runs.items()}


def read_csv(path: Path) -> list:
    if not path.exists():
        return []
    with path.open() as f:
        return list(csv.DictReader(f))


def plot_throughput(runs: dict, out: Path) -> None:
    plt.figure(figsize=(10, 5))
    for mode, run_dir in runs.items():
        rows = read_csv(run_dir / "timeseries.csv")
        if not rows:
            continue
        t = [float(r["t_end"]) for r in rows]
        bw = [float(r["throughput_mbps"]) for r in rows]
        plt.plot(t, bw, label=MODE_LABELS.get(mode, mode),
                 color=MODE_COLORS.get(mode), linewidth=2)
    plt.xlabel("Time (s)")
    plt.ylabel("Throughput (Mbps)")
    plt.title("TCP Throughput over Time — ECN modes compared")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(out, dpi=120)
    plt.close()


def plot_retransmits(runs: dict, out: Path) -> None:
    modes = list(runs.keys())
    totals = []
    for mode in modes:
        rows = read_csv(runs[mode] / "timeseries.csv")
        totals.append(sum(int(r["retransmits"]) for r in rows))
    plt.figure(figsize=(7, 5))
    bars = plt.bar([MODE_LABELS.get(m, m) for m in modes], totals,
                   color=[MODE_COLORS.get(m) for m in modes])
    for bar, val in zip(bars, totals):
        plt.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                 str(val), ha="center", va="bottom", fontweight="bold")
    plt.ylabel("Total retransmits")
    plt.title("Total Retransmissions per Mode")
    plt.grid(True, alpha=0.3, axis="y")
    plt.tight_layout()
    plt.savefig(out, dpi=120)
    plt.close()


def plot_cwnd(runs: dict, out: Path) -> None:
    plt.figure(figsize=(10, 5))
    plotted = False
    for mode, run_dir in runs.items():
        rows = read_csv(run_dir / "ss-parsed.csv")
        rows = [r for r in rows if r.get("cwnd")]
        if not rows:
            continue
        t0 = float(rows[0]["timestamp"])
        t = [float(r["timestamp"]) - t0 for r in rows]
        cwnd = [int(r["cwnd"]) for r in rows]
        plt.plot(t, cwnd, label=MODE_LABELS.get(mode, mode),
                 color=MODE_COLORS.get(mode), linewidth=1.5)
        plotted = True
    if not plotted:
        return
    plt.xlabel("Time (s)")
    plt.ylabel("cwnd (segments)")
    plt.title("Congestion Window Evolution")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(out, dpi=120)
    plt.close()


def plot_rtt(runs: dict, out: Path) -> None:
    plt.figure(figsize=(10, 5))
    plotted = False
    for mode, run_dir in runs.items():
        rows = read_csv(run_dir / "timeseries.csv")
        rows = [r for r in rows if r.get("rtt_us")]
        if not rows:
            continue
        t = [float(r["t_end"]) for r in rows]
        rtt = [float(r["rtt_us"]) / 1000.0 for r in rows]  # us -> ms
        plt.plot(t, rtt, label=MODE_LABELS.get(mode, mode),
                 color=MODE_COLORS.get(mode), linewidth=1.5)
        plotted = True
    if not plotted:
        return
    plt.xlabel("Time (s)")
    plt.ylabel("RTT (ms)")
    plt.title("RTT Evolution")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(out, dpi=120)
    plt.close()


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    root = Path(sys.argv[1])
    runs = load_runs(root)
    if not runs:
        print(f"No runs found under {root}")
        return 1
    out_dir = root / "plots"
    out_dir.mkdir(exist_ok=True)
    plot_throughput(runs, out_dir / "throughput-comparison.png")
    plot_retransmits(runs, out_dir / "retransmits-bar.png")
    plot_cwnd(runs, out_dir / "cwnd-evolution.png")
    plot_rtt(runs, out_dir / "rtt-evolution.png")
    print(f"Plots written to {out_dir}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
