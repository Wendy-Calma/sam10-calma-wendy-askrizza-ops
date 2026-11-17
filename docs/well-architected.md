---
layout: page
title: Well-Architected
permalink: /well-architected.html
---

The six pillars of the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html), applied to AskRizza.

- **First pass:** 16 Nov 2026, right after the first deployment worked.
- **Second pass:** after the incident fix (WS-F).

Verdicts are **good**, **adequate** or **gap**.

| Pillar | First pass (after first deploy) | Second pass (now) |
|---|---|---|
| Operational Excellence | gap | adequate |
| Security | gap | good |
| Reliability | gap | adequate |
| Performance Efficiency | adequate | adequate |
| Cost Optimization | gap | adequate |
| Sustainability | adequate | adequate |

## Operational Excellence
- **Framework asks:** run and monitor the workload, automate changes, learn from failures.
- **AskRizza does:** a scripted, repeatable deploy (`bootstrap.sh`, `start.sh`); a dashboard and 7 alarms; two unattended automations; an incident analysed with a root cause and a runbook.
- **Verdict: adequate.** Deploys are still started by hand. There's no CI pipeline yet.

## Security
- **Framework asks:** strong identity, least privilege, protected secrets and data, traceability.
- **AskRizza does:**
  - MFA on the IAM user
  - separate least-privilege roles for EC2 and Lambda (scoped to `/sam10/*` parameters, one bucket, one topic)
  - all 6 secrets as SSM SecureString, with none in code, files or git history
  - no SSH port (Session Manager instead)
  - only ports 80/443 open
  - registration closed
  - CloudTrail on
  - EBS and S3 encrypted
- **Verdict: good.** GuardDuty isn't available on the account's Free plan. Admin rights aren't yet separated into an assume-role.

## Reliability
- **Framework asks:** detect failure, recover automatically, back up and test restores.
- **AskRizza does:** hourly backups to versioned S3; a **tested restore (about 40 s)**; an external health check; containers set to `restart: always`.
- **Verdict: adequate.** **One instance in one Availability Zone is a single point of failure.** If the instance or the AZ fails, the site is down until it's rebuilt by hand.

## Performance Efficiency
- **Framework asks:** right-size resources and measure performance.
- **AskRizza does:**
  - chose c7i-flex.large (4 GiB), the smallest Free-plan-eligible type with enough memory for the containers. t3.small (2 GiB) was too small, and t3.medium wasn't allowed on the plan.
  - measures `/health` latency (~330–375 ms) and AI answer latency (~0.5–1 s) every 15 min
- **Verdict: adequate, but oversized.** The dashboard shows CPU around 1–2% in normal use (peak about 27% only during the first deploy) and memory around 27% of 4 GiB (about 1.1 GiB) over 16 Nov 2026, 03:00–09:30 UTC. The instance is larger than this load needs. A 2 GiB instance would probably fit at this traffic, at about a quarter of the cost, but with little headroom for traffic spikes or LibreChat upgrades. I kept 4 GiB as a deliberate trade-off for stability during the project.

## Cost Optimization
- **Framework asks:** pay only for what you use, and make cost visible.
- **AskRizza does:** every resource tagged `Project=SAM10`; a budget alert; the model is on a free tier; unused containers removed; the 14-day backup lifecycle keeps S3 small.
- **Verdict: adequate.** The budget covers the whole shared account, not just this project. A project-only budget needs the `Project` cost-allocation tag, which IAM users on this account can't activate, so project cost is calculated from usage instead (see [Results](results.html)). Left running, AskRizza would cost about $68/month, 91% of it the instance.

## Sustainability
- **Framework asks:** minimise the resources needed.
- **AskRizza does:** one instance; three unused services disabled (rag_api, vectordb, admin panel); short log retention (14–30 days); everything will be shut down after grading.
- **Verdict: adequate.**

## The gap I would fix first
**Reliability: the single instance.** It's the only failure that would take AskRizza down for a long time with no automatic recovery. The cheapest fix is an EC2 **auto-recovery alarm action** on `StatusCheckFailed_System`, plus a nightly EBS snapshot through Data Lifecycle Manager. Together these recover from a host failure without a second server. A second instance behind a load balancer would fix it properly, but it would double the cost.

<!-- Optional: record these answers in the Well-Architected Tool and link its PDF report here. -->
