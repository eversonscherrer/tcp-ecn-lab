#!/usr/bin/env python3
"""parse-results.py — Parse iperf3 JSON and ss samples into CSV files.

Usage:
    python3 parse-results.py <results_root_dir>

Reads each subdirectory matching */<timestamp>-<mode>/ and writes:
    results/summary.csv         — one row per run
    results/<run>/timeseries.csv — interval-by-interval throughput
    results/<run>/ss-parsed.csv  — cwnd/rtt/retrans samples
"""

import csv
import json
import re
import sys
from pathlib import Path


def parse_iperf(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open() as f:
        data = json.load(f)
    end = data.get("end", {})
    sent = end.get("sum_sent", {})
    recv = end.get("sum_received", {})
    return {
        "throughput_sent_mbps": sent.get("bits_per_second", 0) / 1e6,
        "throughput_recv_mbps": recv.get("bits_per_second", 0) / 1e6,
        "retransmits": sent.get("retransmits", 0),
        "duration_s": sent.get("seconds", 0),
        "intervals": data.get("intervals", []),
    }


def write_timeseries(intervals: list, out: Path) -> None:
    with out.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["t_start", "t_end", "throughput_mbps", "retransmits", "rtt_us"])
        for it in intervals:
            s = it.get("sum", {})
            streams = it.get("streams", [{}])
            rtt = streams[0].get("rtt", 0) if streams else 0
            w.writerow([
                s.get("start", 0),
                s.get("end", 0),
                s.get("bits_per_second", 0) / 1e6,
                s.get("retransmits", 0),
                rtt,
            ])


# Capture from `ss -tin` output. Format varies; we extract a few key fields.
SS_PATTERNS = {
    "cwnd": re.compile(r"cwnd:(\d+)"),
    "rtt": re.compile(r"rtt:([\d.]+)/"),
    "retrans": re.compile(r"retrans:\d+/(\d+)"),
    "bytes_sent": re.compile(r"bytes_sent:(\d+)"),
    "ecn": re.compile(r"\b(ecn|ecnseen|accecn)\b"),
}


def parse_ss(path: Path, out: Path) -> None:
    if not path.exists():
        return
    rows = []
    with path.open() as f:
        for line in f:
            parts = line.strip().split(None, 1)
            if len(parts) < 2:
                continue
            try:
                ts = float(parts[0])
            except ValueError:
                continue
            row = {"timestamp": ts}
            for key, rx in SS_PATTERNS.items():
                m = rx.search(line)
                if m:
                    row[key] = m.group(1) if m.lastindex else m.group(0)
            if len(row) > 1:
                rows.append(row)
    if not rows:
        return
    fieldnames = ["timestamp", "cwnd", "rtt", "retrans", "bytes_sent", "ecn"]
    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    root = Path(sys.argv[1])
    summary_rows = []
    for run_dir in sorted(root.iterdir()):
        if not run_dir.is_dir():
            continue
        match = re.match(r"(\d{8}-\d{6})-(\w+)", run_dir.name)
        if not match:
            continue
        timestamp, mode = match.groups()
        iperf = parse_iperf(run_dir / "iperf-client.json")
        if not iperf:
            continue
        summary_rows.append({
            "timestamp": timestamp,
            "mode": mode,
            "throughput_sent_mbps": round(iperf["throughput_sent_mbps"], 2),
            "throughput_recv_mbps": round(iperf["throughput_recv_mbps"], 2),
            "retransmits": iperf["retransmits"],
            "duration_s": iperf["duration_s"],
        })
        write_timeseries(iperf.get("intervals", []), run_dir / "timeseries.csv")
        parse_ss(run_dir / "ss-samples.log", run_dir / "ss-parsed.csv")
        print(f"Parsed: {run_dir.name}")

    if summary_rows:
        with (root / "summary.csv").open("w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=summary_rows[0].keys())
            w.writeheader()
            w.writerows(summary_rows)
        print(f"\nSummary written: {root / 'summary.csv'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
