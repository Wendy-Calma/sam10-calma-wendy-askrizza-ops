#!/usr/bin/env python3
"""Compares AskRizza metrics over two equal time windows (UTC), measured the same way.

Usage (CloudShell, repo root):
  python3 scripts/compare-windows.py 2026-11-16T04:00 2026-11-16T19:00 6
  -> window A = 16 Nov 04:00-10:00, window B = 16 Nov 19:00-17 Nov 01:00 (6 hours each)
"""
import json
import subprocess
import sys
from datetime import datetime, timedelta

REGION = "us-east-1"
INSTANCE_NAME = "askrizza-prod"


def aws(*args):
    out = subprocess.run(["aws", "--region", REGION, "--output", "json", *args],
                         check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def stat(namespace, metric, statistic, start, end, dims=()):
    seconds = int((end - start).total_seconds())
    args = ["cloudwatch", "get-metric-statistics", "--namespace", namespace,
            "--metric-name", metric, "--statistics", statistic,
            "--start-time", start.isoformat() + "Z", "--end-time", end.isoformat() + "Z",
            "--period", str(seconds)]
    if dims:
        args += ["--dimensions", *[f"Name={k},Value={v}" for k, v in dims]]
    points = aws(*args)["Datapoints"]
    return points[0][statistic] if points else None


a_start = datetime.fromisoformat(sys.argv[1])
b_start = datetime.fromisoformat(sys.argv[2])
hours = float(sys.argv[3])
length = timedelta(hours=hours)
windows = [(a_start, a_start + length), (b_start, b_start + length)]

instance_id = aws("ec2", "describe-instances", "--filters", f"Name=tag:Name,Values={INSTANCE_NAME}",
                  "Name=instance-state-name,Values=running")["Reservations"][0]["Instances"][0]["InstanceId"]
inst = [("InstanceId", instance_id)]

rows = [
    ("Availability (HealthCheckOK, % of checks OK)", "SAM10", "HealthCheckOK", "Average", (), lambda v: f"{v * 100:.1f}%"),
    ("Health checks run", "SAM10", "HealthCheckOK", "SampleCount", (), lambda v: f"{v:.0f}"),
    ("AI answer correct (AnswerCheckOK, %)", "SAM10", "AnswerCheckOK", "Average", (), lambda v: f"{v * 100:.1f}%"),
    ("Site response time (HealthLatencyMs, avg)", "SAM10", "HealthLatencyMs", "Average", (), lambda v: f"{v:.0f} ms"),
    ("AI response time (AnswerLatencyMs, avg)", "SAM10", "AnswerLatencyMs", "Average", (), lambda v: f"{v:.0f} ms"),
    ("AI response time (AnswerLatencyMs, max)", "SAM10", "AnswerLatencyMs", "Maximum", (), lambda v: f"{v:.0f} ms"),
    ("Requests (RequestCount, total)", "SAM10", "RequestCount", "Sum", (), lambda v: f"{v:.0f}"),
    ("HTTP 5xx (Error5xx, total)", "SAM10", "Error5xx", "Sum", (), lambda v: f"{v:.0f}"),
    ("CPU average", "AWS/EC2", "CPUUtilization", "Average", inst, lambda v: f"{v:.1f}%"),
    ("CPU maximum (5-min average)", "AWS/EC2", "CPUUtilization", "Maximum", inst, lambda v: f"{v:.1f}%"),
    ("Memory used, average", "CWAgent", "mem_used_percent", "Average", inst, lambda v: f"{v:.1f}%"),
]

fmt_w = lambda w: f"{w[0]:%d %b %H:%M}-{w[1]:%d %b %H:%M} UTC"
print(f"| Metric | A: {fmt_w(windows[0])} | B: {fmt_w(windows[1])} |")
print("|---|---|---|")
for label, ns, metric, statistic, dims, fmt in rows:
    cells = []
    for start, end in windows:
        v = stat(ns, metric, statistic, start, end, dims)
        cells.append(fmt(v) if v is not None else "no data")
    print(f"| {label} | {cells[0]} | {cells[1]} |")
