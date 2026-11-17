---
layout: page
title: Next Steps
permalink: /next-steps.html
lede: 'What''s finished, what''s still limited, and what I''d do next, kept apart so nothing here reads as done when it isn''t.'
---

## Done

- AskRizza reskinned and running on AWS over HTTPS, answering from campus facts stored in S3
- All secrets in Parameter Store, least-privilege roles, MFA, no SSH, sign-up closed, CloudTrail, encrypted disk
- Dashboard and 7 alarms, with a real alert received in 1 min 37 s
- Hourly backups and a tested restore (about 40 s)
- Two automations running unattended
- One real incident fixed, with its prevention tested and a runbook written

## Still limited

- **One server in one Availability Zone.** If it fails, AskRizza is down until I rebuild it.
- **The app image isn't pinned.** I run `librechat-dev:latest`, so a redeploy could pull a changed version.
- **I deploy by hand** with `start.sh`.
- **No admin role separation** inside this shared account, and no access to its root user or billing data
- **The server is oversized** for the traffic: about 2% CPU
- **Slow AI answers aren't alarmed.** Gemini reached 14.8 s overnight without any alert.
- **GuardDuty isn't available** on the account's Free plan.

## What I'd do next, in priority order

1. **Recover automatically from a host failure.** An EC2 auto-recovery action on `StatusCheckFailed_System`, plus nightly EBS snapshots with Data Lifecycle Manager. This covers the reliability gap without paying for a second server.
2. **Pin the version.** Run a numbered LibreChat release instead of `librechat-dev:latest`, and upgrade on purpose, recording each one in the runbook's change history.
3. **Deploy from the repository.** A GitHub Action that, on a push to `main`, runs `git pull` and `deploy/start.sh` on the server through SSM Run Command, so every change is deployed the same tested way.
4. **Separate admin rights.** A daily IAM user with read and deploy permissions only, and an MFA-protected admin role to switch into for IAM and billing changes.
5. **Right-size the server.** After a week of data, try a 2 GiB instance, and keep it if the memory alarm stays quiet.
