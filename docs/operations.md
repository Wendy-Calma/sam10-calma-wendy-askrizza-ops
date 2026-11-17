---
layout: page
title: Operations
permalink: /operations.html
---

# Monitoring

## Dashboard
![AskRizza dashboard, 12 hours to 16 Nov 2026 09:30 UTC](assets/img/44-dashboard.png)

What the 12 hours to 16 Nov 2026 09:30 UTC show (data starts when monitoring was set up, about 03:00):
- **Errors:** the only spike is at about **04:10**, my deliberate outage test. HTTP 5xx rose to 12 in that interval, and one health check failed. After that, zero.
- **CPU:** a peak of about 27% at about 03:10 while the containers were first downloaded and started, then about 1–2%.
- **Memory** is steady at about 27% and **disk** at about 45%.
- **Response time:** `/health` about 0.35 s. AI answers are usually 0.5–1 s, with occasional slow calls up to about 5 s.
- **Requests:** the spikes are my own testing.

| Widget | Source |
|---|---|
| Requests per 5 min | Metric filter `RequestCount` on the Caddy access log |
| Errors | HTTP 5xx (metric filter `Error5xx`), plus failed health and answer checks |
| Response time | `HealthLatencyMs` (site) and `AnswerLatencyMs` (AI), measured by the Lambda |
| CPU | `AWS/EC2 CPUUtilization` |
| Disk used | CloudWatch agent `disk_used_percent` for `/` |
| Memory used | CloudWatch agent `mem_used_percent` |

## Alarms
All 7 alarms email the operator through SNS topic `sam10-alerts`, on both ALARM and OK.

| Alarm | Condition | Why this threshold |
|---|---|---|
| askrizza-cpu-high | CPU > 85% for 10 min | A short spike is normal while answering. Ten minutes high means a stuck process or a loop. |
| askrizza-status-check-failed | StatusCheckFailed > 0 for 1 min | Any failed EC2 status check means the machine itself is unhealthy. |
| askrizza-disk-high | Disk > 85% | Leaves room to clean up before MongoDB fails writes at 100%. |
| askrizza-memory-high | Memory > 90% for 5 min | Above this, Linux starts killing containers. |
| askrizza-http-5xx | Any HTTP 5xx in 5 min | A helpdesk site should never return server errors. |
| askrizza-site-down | /health check fails twice in a row (30 min) | One failed check could be a network blip. Two in a row is a real outage. |
| askrizza-answers-wrong | AI answer check fails twice in a row | The site can be "up" but useless if the model or key breaks. This catches that. |

![Seven alarms, all OK](assets/img/20-alarms-ok.png)

## Proof an alert reached a real person
On 16 Nov 2026 I stopped the application container on purpose (`docker stop LibreChat`) to test the alerting.

| Event | Time (UTC) |
|---|---|
| Fault started | 04:10:01 |
| Users see HTTP 502 | from 04:10 |
| `askrizza-http-5xx` → ALARM, email received | **04:11:38** |
| Service restored (`docker start LibreChat`) | 04:14:54 |

**Time to detect: 1 min 37 s.** **Time to restore: 4 min 53 s.**

![Stopping the app](assets/img/21-incident-stop.png)
![Users see a 502](assets/img/22-alert-502.png)
![The alarm email](assets/img/23-alarm-email-5xx.png)
![Restoring the app](assets/img/24-incident-start.png)

## Request log
Caddy writes one JSON line per request (time, method, URI, **status**, **duration**, and the `X-App-Version` header showing which version answered) to CloudWatch Logs `/sam10/caddy` (14-day retention). LibreChat's own logs go to `/sam10/app`.

The health-check Lambda logs the **question asked, how long it took and whether it succeeded** for its test question in `/aws/lambda/wendy-sam10-healthcheck`.

Every log group has a retention period (none set to "Never expire"): 2 weeks for request and app logs, 1 month for automation and Lambda logs.

![Log groups with retention](assets/img/32-log-groups-retention.png)

One request from `/sam10/caddy` (the health check at 09:29:23 UTC, trimmed):

```json
{
  "ts": 1794821363.468672,
  "msg": "handled request",
  "request": {
    "remote_ip": "3.93.191.6",
    "method": "GET",
    "host": "askrizza.duckdns.org",
    "uri": "/health",
    "headers": { "User-Agent": ["Python-urllib/3.12"] }
  },
  "duration": 0.002015087,
  "status": 200,
  "resp_headers": { "X-App-Version": ["v1.0.0"] }
}
```

![Request log in CloudWatch (my own IP address blacked out)](assets/img/45-caddy-request-log.png)

---

# Backup and restore

## What would have to be restored

| Item | Where it lives | Protection |
|---|---|---|
| MongoDB (user accounts, all conversations) | EC2 disk, `/opt/app/LibreChat/data-node` | `mongodump` to S3 **every hour**, kept 14 days |
| Assistant content (`knowledge.md`) | S3 `content/` | S3 **versioning** (old versions kept 30 days), plus a copy in git |
| Secrets (6) | SSM Parameter Store | Managed by AWS, not on the server |
| Configuration and code | GitHub repository | Git history |
| HTTPS certificate | Caddy volume | Not backed up; Caddy re-issues it automatically |
| Meilisearch index | EC2 disk | Not backed up; rebuilt from MongoDB |

![Backup automation run](assets/img/28-backup-log.png)

## Restore test (16 Nov 2026)
1. Created a chat "Restore test 1" and took a backup (04:20:03 UTC).
2. **Simulated losing the database:** stopped the app, moved the data folder away and started an empty MongoDB, which showed **0 users** (04:20:42).
3. Ran `scripts/restore.sh`: downloaded the newest dump from S3 and restored **74 documents, 0 failed** (1 user, 2 conversations, 6 messages) in **9 s**.
4. Started the app (04:21:22), logged in, and the "Restore test 1" chat was back.

![Before: the test chat](assets/img/27-restore-test-chat-before.png)
![Data loss: the database is empty](assets/img/29-restore-data-loss.png)
![Restore output](assets/img/30-restore-output.png)
![After: the chat is back](assets/img/31-restore-chat-after.png)

**RPO:** at most 1 hour of chats could be lost, because the database is dumped to S3 every hour.
**RTO:** the measured restore took about 40 seconds from data loss to service back (9 s for the restore itself), so about 10 minutes including someone noticing and following the runbook.

---

# Security

| Control | Before | After | Risk it addresses |
|---|---|---|---|
| MFA on IAM user | Off | **On (virtual)** | A stolen password alone can't access the account. |
| Personal IAM user, no root | Root not used | Own IAM user `wendy`. Root is the instructor's <!-- TODO: add the instructor's confirmation that root has MFA. --> | Every action is traceable to one person. |
| Secrets | Generated into a file on disk | **6 SSM SecureStrings**, read at deploy time. None in code, config files or git history. | A leaked repository or disk image exposes no keys. |
| Least privilege | n/a | EC2 role: only `/sam10/*` parameters, one bucket, one SNS topic. Lambda: only PutMetricData (namespace SAM10) and one parameter. | A compromised server or function can't touch anything else. |
| Network | n/a | Only 80/443 open. **No SSH**: Session Manager only. MongoDB is never exposed. | No password-guessing on SSH. The database isn't reachable from the internet. |
| Registration | **Open to anyone** | **Closed** | Strangers can't create accounts and use the AI quota. |
| Personal data | n/a | All content invented. The system prompt forbids asking for personal data. `scripts/pii-check.sh` scans every user message in MongoDB for emails and phone numbers Result on 16 Nov 2026 08:29 UTC: **14 user messages scanned, 0 emails, 0 phone numbers: clean.**. | Nothing personal leaves the account for Google. |
| Audit trail | None | **CloudTrail** `sam10-trail`, multi-region | We can see who changed what, and when. |
| Encryption at rest | Default off | **EBS default encryption on**. S3 SSE on. | Disks and backups are unreadable if copied. |
| Threat detection | n/a | GuardDuty **not available** on the Free account plan (documented gap) | n/a |

![MFA enabled](assets/img/03-iam-users-mfa.png)
![Secrets in Parameter Store](assets/img/08-ssm-parameters.png)
![EC2 role: least privilege](assets/img/10-ec2-role-policies.png)
![CloudTrail logging](assets/img/05-cloudtrail.png)
![EBS default encryption](assets/img/07-ebs-encryption-enabled.png)
![Registration closed](assets/img/15-login-signup-closed.png)

![Security group sam10-web: inbound HTTPS 443 and HTTP 80 only, no SSH](assets/img/46-security-group-inbound.png)
![Personal-data check: clean](assets/img/38-pii-check-and-redeploy.png)

**Secret scan:** I ran [gitleaks](https://github.com/gitleaks/gitleaks) over the full history of the official repository (16 Nov 2026, 09:54 UTC): **12 commits scanned, no leaks found.** No key has ever been committed, including in older commits.

![gitleaks: no leaks found](assets/img/53-gitleaks-no-leaks.png)
