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

| | Amount | Period / source |
|---|---|---|
| Account spend before AskRizza existed | **$25.61** month-to-date (forecast $61.94) | 1–16 Nov 2026, AWS Budgets |
| AskRizza estimated running cost | about **$2.10/day**: c7i-flex.large ~$2.04 + Elastic IP $0.12 + 30 GB gp3 ~$0.08. S3, Lambda, CloudWatch ≈ $0 at this size. | AWS on-demand prices, us-east-1 |
| AskRizza actual cost | TODO | Cost Explorer, tag `Project=SAM10` (TODO: date range) |
| Model cost | $0 | Gemini API free tier |
