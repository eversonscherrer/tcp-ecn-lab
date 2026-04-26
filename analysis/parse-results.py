#!/usr/bin/env python3

import csv
import json
import re
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


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "results")
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
        rows.append({
            "timestamp": timestamp,
            "mode": mode,
            "throughput_sent_mbps": round(parsed["throughput_sent_mbps"], 2),
            "throughput_recv_mbps": round(parsed["throughput_recv_mbps"], 2),
            "retransmits": parsed["retransmits"],
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
