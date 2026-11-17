---
layout: page
title: Well-Architected
permalink: /well-architected.html
lede: 'I reviewed AskRizza against the six pillars of the AWS Well-Architected Framework twice: once from the state of the first deployment, and again after the incident fix and the operational work.'
---

## Scorecard

The verdicts are my own judgement against what each pillar asks for: **good**, **adequate** or **gap**. These aren't numeric scores, and no pillar is "fully optimised".

| Pillar | First pass (first deploy) | Second pass (now) | Main reason for the change |
|---|---|---|---|
| Operational Excellence | <span class="chip chip-gap">gap</span> | <span class="chip chip-adequate">adequate</span> | Scripted deploys, dashboard, alarms, two automations, a runbook |
| Security | <span class="chip chip-gap">gap</span> | <span class="chip chip-good">good</span> | MFA, least-privilege roles, secrets in Parameter Store, no SSH, sign-up closed, CloudTrail |
| Reliability | <span class="chip chip-gap">gap</span> | <span class="chip chip-adequate">adequate</span> | Hourly backups and a tested restore. Still one server in one zone. |
| Performance Efficiency | <span class="chip chip-adequate">adequate</span> | <span class="chip chip-adequate">adequate</span> | Now measured, which showed the server is larger than it needs to be |
| Cost Optimization | <span class="chip chip-gap">gap</span> | <span class="chip chip-adequate">adequate</span> | Tagged, budgeted, unused services off; project-only billing isn't visible to me |
| Sustainability | <span class="chip chip-adequate">adequate</span> | <span class="chip chip-adequate">adequate</span> | One server, three unused services switched off, short log retention |

Framework: <https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html>

## Operational Excellence
**What it asks:** run and monitor the workload, make changes in small and safe steps, and learn from failures.

**What AskRizza does:** a repeatable deploy (`bootstrap.sh` for a new server, `start.sh` for every change), a CloudWatch dashboard, 7 alarms, two unattended automations, and an incident written up with its root cause and a runbook.

**Verdict:** <span class="chip chip-adequate">adequate</span> I still start deploys by hand, and there's no pipeline that deploys from the repository.

## Security
**What it asks:** strong identities, least privilege, protected secrets and data, and traceability.

**What AskRizza does:**
- MFA on my IAM user
- separate least-privilege roles for the server and the health-check Lambda
- all 6 secrets in Parameter Store, and none in code, files or git history (checked with gitleaks)
- no SSH port; only 80 and 443 are open
- sign-up closed
- CloudTrail recording
- encrypted disk and S3

**Verdict:** <span class="chip chip-good">good</span> GuardDuty isn't available on this account's Free plan. Admin rights aren't separated into a switch-role. I also can't change the root user, because it belongs to my instructor.

## Reliability
**What it asks:** detect failures, recover from them, and back up and test restores.

**What AskRizza does:** hourly backups to versioned S3, a restore tested at about 40 seconds, an external health check every 15 minutes, and containers that restart themselves.

**Verdict:** <span class="chip chip-adequate">adequate</span> **One server in one Availability Zone is a single point of failure.** If it or its zone fails, AskRizza is down until I rebuild it.

## Performance Efficiency
**What it asks:** choose resources that fit the load, and measure performance.

**What AskRizza does:** c7i-flex.large (2 vCPU, 4 GiB) was the smallest instance with enough memory that the account's Free plan allowed: t3.medium wasn't available, and 2 GiB looked too tight for the containers. Site and AI response times are measured every 15 minutes.

**Verdict:** <span class="chip chip-adequate">adequate, but oversized</span> Across 16–17 Nov, CPU averaged about 1.5–1.8% and memory about 25% of 4 GiB (roughly 1 GiB). A 2 GiB instance would probably cope at this traffic, at about half the cost, but with little room for traffic spikes or upgrades. I kept 4 GiB on purpose, for stability during the project.

## Cost Optimization
**What it asks:** pay only for what you use, and keep spending visible.

**What AskRizza does:** every resource is tagged `Project=SAM10`, there's a budget alert, the AI model is on a free tier, unused containers are off, and backups expire after 14 days.

**Verdict:** <span class="chip chip-adequate">adequate</span> The budget covers the whole shared account. IAM users here can't see billing data or activate the `Project` tag, so I calculated AskRizza's cost from its real running hours instead (about $2.15 for the first 23 hours, see [Results](results.html#cost)). Left running, it would cost about $68 a month, 91% of it the server.

## Sustainability
**What it asks:** use as few resources as the job needs.

**What AskRizza does:** one server, three unused services switched off (document search, vector database, admin panel), 14–30 day log retention, and everything shut down after grading.

**Verdict:** <span class="chip chip-adequate">adequate</span>

## The gap I'd fix first

<div class="callout">
<span class="callout-label">Reliability: the single server</span>
It's the only failure that would keep AskRizza down for a long time with nothing to bring it back automatically. The cheapest fix is an EC2 auto-recovery action on <code>StatusCheckFailed_System</code>, plus a nightly EBS snapshot through Data Lifecycle Manager. Together they recover from a host failure without paying for a second server. A second server behind a load balancer would fix it properly, but would double the cost.
</div>
