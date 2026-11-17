---
layout: page
title: Baseline
permalink: /baseline.html
lede: 'The system as first deployed on 16 Nov 2026 at about 03:05 UTC, before I hardened or operated it. Every later improvement is measured against this.'
---

## What I started with

The first deployment was stock LibreChat with its default `docker-compose.yml`: six containers on one server, reachable over HTTPS. It worked, in the sense that the page loaded. It wasn't something anyone should rely on.

| Area | At first deploy | Why it mattered | Now |
|---|---|---|---|
| Container health | <span class="chip chip-gap">2 of 6 crash-looping</span> Meilisearch ("Permission denied") and rag_api ("Missing credentials… OPENAI_API_KEY") | Chat search was broken, and MongoDB had the same permission fault waiting to happen | <span class="chip chip-good">4 of 4 healthy</span> |
| Secrets | <span class="chip chip-gap">Auto-generated into a file</span> LibreChat writes temporary keys to `.env.temp` on the disk when none are set | Anyone with the disk or a copy of it has the keys | <span class="chip chip-good">In Parameter Store</span> |
| Sign-up | <span class="chip chip-gap">Open to anyone</span> | Strangers could create accounts and use up the AI quota | <span class="chip chip-good">Closed</span> |
| Monitoring | <span class="chip chip-gap">None</span> no dashboard, no alarms, no logs leaving the server | A failure would only be noticed when a student complained | <span class="chip chip-good">Dashboard and 7 alarms</span> |
| Backups | <span class="chip chip-gap">None</span> MongoDB only on the server's disk | Losing the disk would mean losing every account and chat | <span class="chip chip-good">Hourly to S3, restore tested</span> |
| Automation | <span class="chip chip-gap">None</span> | Every check depended on me remembering to do it | <span class="chip chip-good">2 running unattended</span> |

<div class="compare">
<div class="compare-col before" markdown="1">
#### First deploy
![The first start.sh output: chat-meilisearch is "Restarting (1)"](assets/img/48-first-deploy-meilisearch-restarting.png)
![Meilisearch's log: Permission denied, with its folders owned by root](assets/img/49-meilisearch-permission-denied.png)
</div>
<div class="compare-col after" markdown="1">
#### After the fixes
![All 4 containers up after a deploy](assets/img/38-pii-check-and-redeploy.png)
</div>
</div>

<div class="compare">
<div class="compare-col before" markdown="1">
#### Sign-up open
![Login page with "Don't have an account? Sign up"](assets/img/13-login-signup-open.png)
</div>
<div class="compare-col after" markdown="1">
#### Sign-up closed
![Login page with no sign-up link](assets/img/15-login-signup-closed.png)
</div>
</div>

## The account, before

| Item | Before | Now |
|---|---|---|
| MFA on my IAM user | <span class="chip chip-gap">Not set</span> | <span class="chip chip-good">Virtual MFA</span> |
| CloudTrail trail | <span class="chip chip-gap">None for this project</span> | <span class="chip chip-good">`sam10-trail`, logging</span> |
| EBS default encryption | <span class="chip chip-gap">Off</span> | <span class="chip chip-good">On</span> |
| Budget alert | <span class="chip chip-gap">None</span> | <span class="chip chip-good">Monthly budget with email alerts</span> |

![My IAM user before: the MFA column shows "-"](assets/img/01-iam-users-before-mfa.png)

## Cost before

AskRizza runs in a shared course account, which already had spending before AskRizza existed: **$25.61 month to date** on 16 Nov, with a forecast of $61.94 for November. That's my "before" figure for the [cost comparison](results.html#cost).

![Account spending before the project, in AWS Budgets](assets/img/04-budget.png)
