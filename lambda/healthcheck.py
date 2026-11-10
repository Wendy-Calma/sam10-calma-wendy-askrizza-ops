"""AskRizza health check (EventBridge, every 15 min).

Metrics (namespace SAM10): HealthCheckOK, HealthLatencyMs, AnswerCheckOK, AnswerLatencyMs.
Env: SITE_URL, CHECK_ANSWER, LLM_BASE_URL, LLM_MODEL, LLM_KEY_PARAM.
"""
import json
import os
import time
import urllib.request

import boto3

cloudwatch = boto3.client("cloudwatch")
ssm = boto3.client("ssm")

TEST_QUESTION = "What Wi-Fi network should students use?"
EXPECTED_KEYWORD = "RP-Student"
FACTS = "Student Wi-Fi network: RP-Student. Guest Wi-Fi: RP-Guest."


def check_health(site_url):
    start = time.time()
    try:
        with urllib.request.urlopen(site_url.rstrip("/") + "/health", timeout=10) as resp:
            ok = 1 if resp.status == 200 else 0
            error = None
    except Exception as exc:
        ok, error = 0, str(exc)
    return ok, int((time.time() - start) * 1000), error


def check_answer(base_url, model, key_param):
    key = ssm.get_parameter(Name=key_param, WithDecryption=True)["Parameter"]["Value"]
    body = json.dumps({
        "model": model,
        "temperature": 0,
        "messages": [
            {"role": "system", "content": "Answer only from these facts: " + FACTS},
            {"role": "user", "content": TEST_QUESTION},
        ],
    }).encode()
    req = urllib.request.Request(
        base_url.rstrip("/") + "/chat/completions",
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                 "User-Agent": "askrizza-healthcheck"},
    )
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            answer = json.load(resp)["choices"][0]["message"]["content"]
        ok = 1 if EXPECTED_KEYWORD.lower() in answer.lower() else 0
        error = None if ok else "expected keyword missing"
    except Exception as exc:
        ok, error = 0, str(exc)
    return ok, int((time.time() - start) * 1000), error


def handler(event, context):
    site_url = os.environ["SITE_URL"]
    health_ok, health_ms, health_err = check_health(site_url)
    metrics = [
        {"MetricName": "HealthCheckOK", "Value": health_ok},
        {"MetricName": "HealthLatencyMs", "Value": health_ms, "Unit": "Milliseconds"},
    ]
    record = {"check": "health", "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "url": site_url, "health_ok": health_ok, "health_ms": health_ms, "health_error": health_err}

    if os.environ.get("CHECK_ANSWER", "false").lower() == "true":
        ans_ok, ans_ms, ans_err = check_answer(
            os.environ.get("LLM_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai/"),
            os.environ.get("LLM_MODEL", "gemini-3.5-flash-lite"),
            os.environ.get("LLM_KEY_PARAM", "/sam10/LLM_API_KEY"),
        )
        metrics += [
            {"MetricName": "AnswerCheckOK", "Value": ans_ok},
            {"MetricName": "AnswerLatencyMs", "Value": ans_ms, "Unit": "Milliseconds"},
        ]
        record.update({"question": TEST_QUESTION, "answer_ok": ans_ok, "answer_ms": ans_ms,
                       "answer_error": ans_err})

    cloudwatch.put_metric_data(Namespace="SAM10", MetricData=metrics)
    print(json.dumps(record))
    return record
