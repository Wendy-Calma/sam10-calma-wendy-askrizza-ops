# AskRizza: SAM10 Final Project

AskRizza is a campus facilities helpdesk assistant for **Rizza Polytechnic, a fictional college**. It is a reskin of LibreChat, deployed and operated on AWS for the SAM10 (Systems Administration and Maintenance) final project.

> All content (people, places, numbers) is invented. The assistant gives information only and never makes decisions about individual people.

## Credits (base system)

| | |
|---|---|
| Base system | **LibreChat** |
| Source | https://github.com/danny-avila/LibreChat |
| Author | Danny Avila and LibreChat contributors |
| Licence | MIT. See https://github.com/danny-avila/LibreChat/blob/main/LICENSE. LibreChat's copyright notice is kept in the deployed copy. |
| AI model | Google Gemini API (free tier) through its OpenAI-compatible endpoint; provider and model set in `deploy/settings.env`. Terms: https://ai.google.dev/gemini-api/terms |

This repository contains **only my own deployment, configuration, content and operations code**. LibreChat itself is cloned unmodified onto the server by `deploy/bootstrap.sh`, and all customisation happens through its supported config files and volume mounts.

## Repository layout

| Path | What it is |
|---|---|
| `deploy/settings.env` | Non-secret settings (region, bucket, domain, model). **No secrets.** |
| `deploy/bootstrap.sh` | One-time setup of a fresh Ubuntu 24.04 EC2 instance |
| `deploy/start.sh` | Deploy/redeploy: reads secrets from SSM Parameter Store, content from S3, renders config, starts Docker Compose |
| `deploy/configure-env.sh` | Writes LibreChat's `.env` with non-secret values only |
| `deploy/librechat.template.yaml` + `render.py` | Reskin: theme colours, welcome text, model, system prompt + knowledge from S3 |
| `deploy/docker-compose.override.yml`, `deploy/Caddyfile` | Secrets via environment, logo mount, Caddy HTTPS reverse proxy |
| `content/knowledge.md` | The invented facts the assistant answers from (uploaded to S3) |
| `branding/logo.svg` | AskRizza logo |
| `scripts/aws-setup.sh` | One-time AWS setup (S3, SNS, SSM secrets). Run in CloudShell |
| `scripts/backup.sh`, `scripts/install-automation.sh` | Automation 1: hourly MongoDB dump to S3 (cron) |
| `scripts/restore.sh` | Restore MongoDB from S3 (prints timings for RTO) |
| `lambda/healthcheck.py` | Automation 2: external health + answer check every 15 min (EventBridge to Lambda) |
| `monitoring/cwagent.json` | CloudWatch agent: memory/disk metrics and log shipping |
| `iam/*.json` | Least-privilege inline policies for the EC2 role and the Lambda role |
| `docs/` | Project website (GitHub Pages) |

## How to deploy (from nothing)

1. **AWS setup** (CloudShell, us-east-1): edit `deploy/settings.env`, then run `bash scripts/aws-setup.sh <alert-email>` and confirm the SNS email.
2. **IAM role** `sam10-ec2-role`: attach `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy`, and an inline policy from `iam/ec2-role-inline-policy.json` (replace ACCOUNT_ID and BUCKET).
3. **EC2**: Ubuntu 24.04, t3.medium, 30 GB gp3 encrypted, role above, security group allowing only TCP 80 and 443 inbound, plus an Elastic IP. Point the DuckDNS name at the Elastic IP.
4. **On the instance** (Session Manager):
   ```bash
   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Wendy-Calma/sam10-calma-wendy-askrizza-ops/main/deploy/bootstrap.sh)" _ https://github.com/Wendy-Calma/sam10-calma-wendy-askrizza-ops.git
   sudo su - ubuntu
   /opt/app/askrizza/deploy/start.sh
   sudo /opt/app/askrizza/scripts/install-automation.sh
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/app/askrizza/monitoring/cwagent.json
   ```
5. **Lambda** `sam10-healthcheck` (Python 3.12) from `lambda/healthcheck.py`, scheduled every 15 minutes with EventBridge Scheduler.

To change the assistant's knowledge, edit `content/knowledge.md`, upload it to `s3://BUCKET/content/`, and run `deploy/start.sh`.

## Contribution log

Solo project. Every entry is written at the time the work was done.

| Date / time (local) | What I did |
|---|---|
| 2026-11-16 | Read the brief. Chose LibreChat + Gemini, domain "campus facilities helpdesk", region us-east-1. Wrote deployment, backup and health-check code. |

## AI assistance declaration

I used Claude (Anthropic) as an assistant to plan the deployment and draft scripts and configuration in this repository. I reviewed every file, ran every command myself against my own deployment, and checked the behaviour against the AWS and LibreChat documentation. All evidence on the website comes from my real system.
