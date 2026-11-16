---
layout: page
title: Infrastructure
permalink: /infrastructure.html
---

![AskRizza AWS infrastructure](assets/infrastructure.svg)

## Services and what each one is for

| Service | Resource | Purpose |
|---|---|---|
| EC2 | `askrizza-prod`, c7i-flex.large, Ubuntu 24.04, 30 GB encrypted gp3, Elastic IP | Runs the application in Docker: Caddy, LibreChat, MongoDB, Meilisearch |
| VPC security group | `sam10-web` | Inbound **TCP 80 and 443 only**. No SSH: administration goes through Systems Manager Session Manager. |
| Systems Manager | Parameter Store `/sam10/*` (6 SecureString) and Session Manager | Secrets read at deploy time, and shell access without an open port |
| S3 | `sam10-askrizza-data-2026` (private, versioned, encrypted) | `content/knowledge.md` (the assistant's facts) and `backups/mongo/` (hourly dumps, deleted after 14 days) |
| CloudWatch | Logs, metric filters, dashboard `AskRizza`, 7 alarms | Request logs, resource metrics, alerting |
| Lambda + EventBridge | `wendy-sam10-healthcheck`, every 15 minutes | External check of the site and of one AI answer |
| SNS | `sam10-alerts` | Emails alarms and backup failures to the operator |
| CloudTrail | `sam10-trail` | Audit trail of who changed what |
| Budgets | `sam10-account-monthly` | Cost alert |
| IAM | `sam10-ec2-role`, health-check Lambda role, user `wendy` with MFA | Least-privilege permissions |
| Outside AWS | Google Gemini API (`gemini-3.5-flash-lite`, free tier), DuckDNS | The AI model, and the free domain name |

## How a question travels

1. The browser resolves `askrizza.duckdns.org` to the **Elastic IP** and connects over **HTTPS** to **Caddy** on port 443. Caddy holds a free Let's Encrypt certificate and renews it automatically.
2. Caddy forwards the request to **LibreChat** on the internal Docker network and writes one JSON log line (status, duration, URL). The CloudWatch agent ships that line to `/sam10/caddy`.
3. LibreChat loads the user's session from **MongoDB**. It adds the AskRizza system prompt, which contains the facts downloaded from S3 at deploy time, and sends the question to the **Gemini API** with a key that came from Parameter Store.
4. Gemini's answer streams back through LibreChat and Caddy to the browser, and the conversation is saved in MongoDB.

## Deployment

`deploy/start.sh` in the repository rebuilds the configuration from scratch on every deploy:
- secrets come from SSM
- content comes from S3
- non-secret settings come from `deploy/settings.env`

It then starts the containers and restarts the app so the changes apply. A fresh server is built with `deploy/bootstrap.sh` (see the [README](https://github.com/Wendy-Calma/sam10-calma-wendy-askrizza-ops#readme)).

![Instance launched](assets/img/11-ec2-instance.png)
