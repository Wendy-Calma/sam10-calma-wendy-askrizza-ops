---
layout: page
title: Results
permalink: /results.html
---

## Before and after

| Measure | Before (first deploy, 16 Nov 03:06 UTC) | After (16 Nov 2026) | How measured |
|---|---|---|---|
| Healthy containers | 4 of 6 (2 crash-looping) | **4 of 4** | `docker compose ps` |
| Alarms | 0 | **7** | CloudWatch → Alarms |
| Time to detect an outage | unknown (no monitoring) | **1 min 37 s** | Test outage, 16 Nov 04:10 UTC |
| Backups / RPO | none / everything lost | hourly / **≤ 1 hour** | `backup.sh` log |
| Restore / RTO | never tested | **~40 s** tested | Restore test, 16 Nov 04:20 UTC |
| Secrets on disk or in repo | generated into `.env.temp` | **0**, all 6 in SSM | `grep` of `.env`, SSM list |
| Open inbound ports | n/a | 80, 443 only (no SSH) | Security group |
| Public registration | open | **closed** | Login page |
| Answer quality | not measured | **13/14** test questions before, **14/14** after the gym content fix, plus a continuous AnswerCheckOK | Test questions, Lambda |

## Measured over equal periods
Measure **the same thing, the same way, over the same length of time** on both sides, and put the date range next to every number.

<!-- TODO: fill in two equal windows from the dashboard (Average stat). -->

| Metric | Window A (TODO) | Window B (TODO) |
|---|---|---|
| Availability: HealthCheckOK, % of checks = 1 | | |
| Site response time: HealthLatencyMs, average | | |
| AI response time: AnswerLatencyMs, average | | |
| HTTP 5xx count | | |
| CPU average / max | | |
| Memory average | | |

<!-- TODO: add one dashboard graph with its date range in the caption. -->

## Cost

| | Amount | Period / source |
|---|---|---|
| Account spend before AskRizza existed | **$25.61** month-to-date (forecast $61.94) | 1–16 Nov 2026, AWS Budgets |
| AskRizza estimated running cost | about **$2.10/day**: c7i-flex.large ~$2.04 + Elastic IP $0.12 + 30 GB gp3 ~$0.08. S3, Lambda, CloudWatch ≈ $0 at this size. | AWS on-demand prices, us-east-1 |
| AskRizza actual cost | TODO | Cost Explorer, tag `Project=SAM10` (TODO: date range) |
| Model cost | $0 | Gemini API free tier |
