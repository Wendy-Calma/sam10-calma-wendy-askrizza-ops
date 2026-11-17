#!/usr/bin/env python3
"""CloudWatch metric filters, dashboard and alarms for AskRizza. Idempotent.

Usage (CloudShell, repo root): python3 scripts/monitoring-setup.py
"""
import json
import subprocess

REGION = "us-east-1"
INSTANCE_NAME = "askrizza-prod"
TOPIC_NAME = "sam10-alerts"
DASHBOARD = "AskRizza"
CADDY_LOG_GROUP = "/sam10/caddy"


def aws(*args):
    out = subprocess.run(["aws", "--region", REGION, "--output", "json", *args],
                         check=True, capture_output=True, text=True).stdout
    return json.loads(out) if out.strip() else None


account = aws("sts", "get-caller-identity")["Account"]
topic_arn = f"arn:aws:sns:{REGION}:{account}:{TOPIC_NAME}"
reservations = aws("ec2", "describe-instances", "--filters",
                   f"Name=tag:Name,Values={INSTANCE_NAME}",
                   "Name=instance-state-name,Values=running")["Reservations"]
instance_id = reservations[0]["Instances"][0]["InstanceId"]
print(f"instance {instance_id}, alerts -> {topic_arn}")

disk = aws("cloudwatch", "list-metrics", "--namespace", "CWAgent",
           "--metric-name", "disk_used_percent",
           "--dimensions", f"Name=InstanceId,Value={instance_id}")["Metrics"]
disk = [m for m in disk if {"Name": "path", "Value": "/"} in m["Dimensions"]]
if not disk:
    raise SystemExit("disk_used_percent not found yet: is the CloudWatch agent running? Retry in 5 minutes.")
disk_dims = disk[0]["Dimensions"]

# --- retention on the database log group (created by Docker's awslogs driver) ---
try:
    aws("logs", "put-retention-policy", "--log-group-name", "/sam10/mongodb", "--retention-in-days", "14")
    print("retention /sam10/mongodb 14 days")
except subprocess.CalledProcessError:
    print("note: /sam10/mongodb not created yet; redeploy, then run this again")

# --- metric filters on the Caddy access log (one JSON line per request) ---
for name, pattern in [("RequestCount", "{ $.status > 0 }"),
                      ("Error5xx", "{ $.status >= 500 }")]:
    aws("logs", "put-metric-filter", "--log-group-name", CADDY_LOG_GROUP,
        "--filter-name", f"askrizza-{name}", "--filter-pattern", pattern,
        "--metric-transformations",
        json.dumps([{"metricName": name, "metricNamespace": "SAM10",
                     "metricValue": "1", "defaultValue": 0, "unit": "Count"}]))
    print(f"metric filter {name}")

# --- dashboard ---
def flat(dims):
    out = []
    for d in dims:
        out += [d["Name"], d["Value"]]
    return out


def widget(title, metrics, stat="Average", period=300, x=0, y=0, label=None):
    props = {"title": title, "region": REGION, "view": "timeSeries", "stat": stat,
             "period": period, "metrics": metrics}
    if label:
        props["yAxis"] = {"left": {"label": label, "min": 0}}
    return {"type": "metric", "x": x, "y": y, "width": 12, "height": 6, "properties": props}


widgets = [
    widget("Requests (per 5 min)", [["SAM10", "RequestCount"]], "Sum", 300, 0, 0, "requests"),
    widget("Errors: HTTP 5xx and failed checks",
           [["SAM10", "Error5xx", {"stat": "Sum"}],
            [{"expression": "1-m1", "label": "HealthCheck failed", "id": "e1"}],
            ["SAM10", "HealthCheckOK", {"id": "m1", "visible": False}],
            [{"expression": "1-m2", "label": "AnswerCheck failed", "id": "e2"}],
            ["SAM10", "AnswerCheckOK", {"id": "m2", "visible": False}]],
           "Sum", 900, 12, 0, "count"),
    widget("Response time (ms): site /health and AI answer",
           [["SAM10", "HealthLatencyMs"], ["SAM10", "AnswerLatencyMs"]], "Average", 900, 0, 6, "ms"),
    widget("EC2 CPU (%)", [["AWS/EC2", "CPUUtilization", "InstanceId", instance_id]],
           "Average", 300, 12, 6, "%"),
    widget("Disk used (%)", [["CWAgent", "disk_used_percent", *flat(disk_dims)]],
           "Average", 300, 0, 12, "%"),
    widget("Memory used (%)", [["CWAgent", "mem_used_percent", "InstanceId", instance_id]],
           "Average", 300, 12, 12, "%"),
]
aws("cloudwatch", "put-dashboard", "--dashboard-name", DASHBOARD,
    "--dashboard-body", json.dumps({"widgets": widgets}))
print(f"dashboard {DASHBOARD}")

# --- alarms ---
def alarm(name, description, namespace, metric, dims, stat, period, periods, threshold,
          comparison, missing="missing"):
    args = ["cloudwatch", "put-metric-alarm", "--alarm-name", name,
            "--alarm-description", description, "--namespace", namespace,
            "--metric-name", metric, "--statistic", stat, "--period", str(period),
            "--evaluation-periods", str(periods), "--datapoints-to-alarm", str(periods),
            "--threshold", str(threshold), "--comparison-operator", comparison,
            "--treat-missing-data", missing,
            "--alarm-actions", topic_arn, "--ok-actions", topic_arn,
            "--tags", "Key=Project,Value=SAM10"]
    if dims:
        args += ["--dimensions", *[f"Name={d['Name']},Value={d['Value']}" for d in dims]]
    aws(*args)
    print(f"alarm {name}")


inst = [{"Name": "InstanceId", "Value": instance_id}]
alarm("askrizza-cpu-high", "CPU above 85% for 10 minutes: stuck process or runaway loop.",
      "AWS/EC2", "CPUUtilization", inst, "Average", 300, 2, 85, "GreaterThanThreshold")
alarm("askrizza-status-check-failed", "EC2 status check failed: the instance or its host is unhealthy.",
      "AWS/EC2", "StatusCheckFailed", inst, "Maximum", 60, 1, 0, "GreaterThanThreshold")
alarm("askrizza-disk-high", "Root disk above 85%: clean up or grow the volume before MongoDB fails writes.",
      "CWAgent", "disk_used_percent", disk_dims, "Average", 300, 1, 85, "GreaterThanThreshold")
alarm("askrizza-memory-high", "Memory above 90% for 5 minutes: containers may be killed.",
      "CWAgent", "mem_used_percent", inst, "Average", 300, 1, 90, "GreaterThanThreshold")
alarm("askrizza-http-5xx", "Any HTTP 5xx from the site in 5 minutes.",
      "SAM10", "Error5xx", None, "Sum", 300, 1, 0, "GreaterThanThreshold", "notBreaching")
alarm("askrizza-site-down", "External /health check failed twice in a row (30 minutes).",
      "SAM10", "HealthCheckOK", None, "Minimum", 900, 2, 1, "LessThanThreshold", "breaching")
alarm("askrizza-answers-wrong", "AI answer check failed twice in a row: up but not useful.",
      "SAM10", "AnswerCheckOK", None, "Minimum", 900, 2, 1, "LessThanThreshold", "breaching")
print("done")
