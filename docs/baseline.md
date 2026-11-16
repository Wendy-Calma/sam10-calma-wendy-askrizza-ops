---
layout: page
title: Baseline
permalink: /baseline.html
---

This page records the system **before I hardened and operated it**, as first deployed on **16 Nov 2026** (around 03:05 UTC).

## Environment before

| Area | State at first deploy |
|---|---|
| Application | Stock LibreChat with its default `docker-compose.yml`: **6 containers** (LibreChat, MongoDB, Meilisearch, pgvector, rag_api, Caddy) |
| Health | **2 of 6 containers crash-looping**: Meilisearch (`Permission denied (os error 13)`) and rag_api (`Missing credentials… OPENAI_API_KEY`) |
| Secrets | LibreChat generates temporary secrets into `.env.temp` on the server's disk when none are set |
| Access | **Public registration open**: anyone could create an account and use the AI quota |
| Monitoring | None. No dashboard, no alarms, no request logs leaving the server. |
| Backups | None. MongoDB data lived only on the instance's disk. |
| Automation | None |
| Cost | The account had already spent **$25.61 month-to-date** (forecast **$61.94**) on other workloads before AskRizza existed |

![First deploy: containers started](assets/img/12-start-sh-containers-up.png)

![First deploy: chat-meilisearch Restarting (1)](assets/img/48-first-deploy-meilisearch-restarting.png)
![Meilisearch log: Permission denied](assets/img/49-meilisearch-permission-denied.png)

![Registration open to anyone](assets/img/13-login-signup-open.png)

![Account cost before the project](assets/img/04-budget.png)

## Account security before

| Item | Before |
|---|---|
| MFA on my IAM user | **Not set** |
| CloudTrail trail | None for this project |
| EBS default encryption | Off |
| Budget alert | None |

![IAM user without MFA](assets/img/01-iam-users-before-mfa.png)
