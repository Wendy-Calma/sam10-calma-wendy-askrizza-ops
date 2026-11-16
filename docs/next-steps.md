---
layout: page
title: Next steps
permalink: /next-steps.html
---

In priority order:

1. **Recover automatically from a host failure.** Add an EC2 auto-recovery action on `StatusCheckFailed_System`, plus nightly EBS snapshots with Data Lifecycle Manager. This fixes the Reliability gap (single instance, single AZ) without paying for a second server.
2. **Pin versions.** Run a numbered LibreChat release instead of `librechat-dev:latest`, so a redeploy can't silently pull a changed or broken image. Upgrade on purpose, and record it in the runbook's change history.
3. **Deploy from the repository automatically.** A GitHub Action that, on a push to `main`, runs `git pull && deploy/start.sh` on the instance through SSM Run Command. Every change is then deployed the same, tested way.
4. **Separate admin rights.** Give the daily IAM user read-only plus deploy permissions, and require switching into an MFA-protected admin role for IAM and billing changes.
5. **Right-size the instance.** Measured CPU is about 2% and memory about 27%. After a week of data, try a 2 GiB instance and keep it if the memory alarm stays quiet.
