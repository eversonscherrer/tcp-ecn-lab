#!/usr/bin/env python3

import csv
import json
import re
import statistics
import sys
from pathlib import Path
from typing import Optional


def parse_iperf(path: Path) -> Optional[dict]:
    if not path.exists():
        return None
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
    }


def parse_iperf_intervals(path: Path) -> list[float]:
    if not path.exists():
        return []
    with path.open() as f:
        data = json.load(f)
    result = []
    for iv in data.get("intervals", []):
        s = iv.get("sum", {})
        if not s.get("omitted", False) and s.get("bits_per_second", 0) > 0:
            result.append(s["bits_per_second"] / 1e6)
    return result


def parse_qdisc_final(path: Path) -> dict:
    result = {"ecn_mark": 0, "pkt_dropped": 0}
    if not path.exists():
        return result
    text = path.read_text()
    m = re.search(r"\becn_mark\s+(\d+)", text)
    if m:
        result["ecn_mark"] = int(m.group(1))
    # Dropped packets reported in the fq_codel Sent line
    fq_pos = text.find("qdisc fq_codel")
    if fq_pos >= 0:
        m = re.search(r"\(dropped\s+(\d+),", text[fq_pos : fq_pos + 400])
        if m:
            result["pkt_dropped"] = int(m.group(1))
    return result


def parse_ss_stats(path: Path) -> dict:
    """Extract mean RTT and cwnd from an ss -tin log file.

    Works for both client-side (receiver) and server-side (sender) logs.
    cwnd is only meaningful from the sender; the receiver's cwnd stays at ~10.
    """
    empty = {"rtt_mean_ms": None, "cwnd_mean": None, "cwnd_min": None}
    if not path.exists():
        return empty
    rtts: list[float] = []
    cwnds: list[int] = []
    for line in path.read_text().splitlines():
        m = re.search(r"\brtt:(\d+(?:\.\d+)?)", line)
        if m:
            rtts.append(float(m.group(1)))
        m = re.search(r"\bcwnd:(\d+)\b", line)
        if m:
            cwnds.append(int(m.group(1)))
    return {
        "rtt_mean_ms": round(statistics.mean(rtts), 2) if rtts else None,
        "cwnd_mean": round(statistics.mean(cwnds), 1) if cwnds else None,
        "cwnd_min": min(cwnds) if cwnds else None,
    }


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent / "results"
    rows = []
    for run_dir in sorted(root.iterdir()):
        if not run_dir.is_dir():
            continue
        match = re.match(r"(\d{8}-\d{6})-(none|classic|accecn)$", run_dir.name)
        if not match:
            continue
        parsed = parse_iperf(run_dir / "iperf-client.json")
        if not parsed:
            continue
        timestamp, mode = match.groups()

        intervals = parse_iperf_intervals(run_dir / "iperf-client.json")
        qdisc = parse_qdisc_final(run_dir / "qdisc-final.log")

        # Prefer server-side ss (sender cwnd is meaningful); fall back to client
        ss = parse_ss_stats(run_dir / "server-ss.log")
        if ss["rtt_mean_ms"] is None:
            ss = parse_ss_stats(run_dir / "ss-samples.log")

        rows.append({
            "timestamp": timestamp,
            "mode": mode,
            "throughput_sent_mbps": round(parsed["throughput_sent_mbps"], 2),
            "throughput_recv_mbps": round(parsed["throughput_recv_mbps"], 2),
            "throughput_min_mbps": round(min(intervals), 2) if intervals else "",
            "throughput_stddev_mbps": round(statistics.stdev(intervals), 2) if len(intervals) > 1 else "",
            "retransmits": parsed["retransmits"],
            "ecn_mark": qdisc["ecn_mark"],
            "pkt_dropped": qdisc["pkt_dropped"],
            "cwnd_mean": ss["cwnd_mean"] if ss["cwnd_mean"] is not None else "",
            "cwnd_min": ss["cwnd_min"] if ss["cwnd_min"] is not None else "",
            "rtt_mean_ms": ss["rtt_mean_ms"] if ss["rtt_mean_ms"] is not None else "",
            "duration_s": round(parsed["duration_s"], 2),
        })

    if not rows:
        print(f"No valid runs found in {root}", file=sys.stderr)
        return 1

    out = root / "summary.csv"
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
