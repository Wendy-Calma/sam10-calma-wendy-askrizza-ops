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

Two **6-hour windows**, same metrics, same statistics, pulled straight from CloudWatch with `scripts/compare-windows.py`:
- **Window A, the first day:** the outage drill, the restore test, the content fix, and my own testing.
- **Window B, steady state:** the system running on its own overnight, with no changes and nobody touching it.

| Metric | **A:** 16 Nov 04:00–10:00 UTC | **B:** 16 Nov 19:00 – 17 Nov 01:00 UTC |
|---|---|---|
| Availability (health checks OK) | 95.8% (23 of 24) | **100%** (24 of 24) |
| AI answer check correct | 100% | 100% |
| Site response time, `/health` average | 356 ms | 366 ms |
| AI response time, average | 1,193 ms | **4,383 ms** |
| AI response time, maximum | 5,204 ms | **14,834 ms** |
| Requests | 1,405 | 119 |
| HTTP 5xx | 13 | **0** |
| CPU average / max (5-min) | 1.8% / 26.8% | 1.5% / 3.3% |
| Memory used, average | 25.4% | 24.2% |

![The comparison as printed by the script](assets/img/54-window-comparison.png)

**What the numbers say:**
- **The only failures in either window were the ones I caused on purpose.** The one failed health check and all 13 HTTP 5xx in window A are the outage drill at 04:10. Left alone (window B), AskRizza was 100% available with zero errors.
- **The server is not the bottleneck.** The site itself answers in about 0.36 s in both windows, and CPU and memory stay low. That confirms the right-sizing finding on the [Well-Architected page](well-architected.html).
- **The slowest part is outside AWS.** Gemini's answers were almost **4× slower overnight** (4.4 s average, up to 14.8 s) than during window A, even though my server was idle. Window B is daytime in the US, so this is most likely load on Google's free tier. My monitoring catches a *wrong* answer, but not a *slow* one. An alarm on `AnswerLatencyMs` (for example, average above 8 s for 30 minutes) would be the next one to add.

![Dashboard, 12 hours to 16 Nov 2026 09:30 UTC: the error spike at 04:10 is the outage drill](assets/img/44-dashboard.png)

## Cost

On this account, **IAM users can't see billing data**: Cost Explorer and cost allocation tags return "IAM user access not activated", and only the root user can turn that on. So AskRizza's cost below is **calculated from real usage** (how long each resource has run, from `describe-instances` and `describe-volumes`) **multiplied by AWS's published us-east-1 on-demand prices**. Only the Budgets totals are read directly from AWS.

| Resource | Usage (16 Nov 02:53:45 → 17 Nov 02:01:45 UTC = 23.1 h) | Price | Cost |
|---|---|---|---|
| EC2 c7i-flex.large | 23.1 h | $0.08479/h | $1.96 |
| Public IPv4 (Elastic IP) | 23.1 h | $0.005/h | $0.12 |
| EBS gp3, 30 GB | 23.1 h | $0.08/GB-month | $0.08 |
| S3, Lambda, SNS, SSM | ~20 KB backups per hour, 96 Lambda runs per day | free tier / fractions of a cent | ≈ $0.00 |
| CloudWatch (8 custom metrics, 7 alarms, 1 dashboard, logs) | | free tier if the account has room; at most ≈ $0.20/day | $0.00–0.20 |
| Gemini API | free tier | | $0.00 |
| **Total, first 23 hours** | | | **≈ $2.15–2.35** |

| | Amount | Source |
|---|---|---|
| Account spend, month to date, **before** AskRizza (16 Nov) | $25.61 (forecast $61.94) | AWS Budgets |
| Account spend, month to date, **after** one day (17 Nov 02:01 UTC) | $28.79 (forecast $74.31) | AWS Budgets, `describe-budgets` |
| Difference | +$3.18 | Includes AskRizza (≈ $2.2) and other people's resources on this shared account |
| AskRizza if left running for a whole month | **≈ $68/month**, almost all of it the EC2 instance | Calculated |

![Inputs for the cost calculation](assets/img/55-cost-inputs.png)

**What this means:** 91% of the cost is the instance itself, and the dashboard shows it running at about 2% CPU. Right-sizing to a 2 GiB instance (next steps) would roughly halve the monthly cost. Shutting everything down after grading takes it to $0.
