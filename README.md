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
| `scripts/monitoring-setup.py` | CloudWatch metric filters, dashboard and alarms. Run in CloudShell |
| `scripts/compare-windows.py` | Compares key metrics over two equal time windows (for before/after results). Run in CloudShell |
| `scripts/request-log.sh` | Logs each student question (question, seconds to answer, success, model, version) to CloudWatch `/sam10/requests`, every 5 min |
| `scripts/pii-check.sh` | Scans user messages for emails and phone numbers before they reach the model provider |
| `lambda/healthcheck.py` | Automation 2: external health + answer check every 15 min (EventBridge to Lambda) |
| `monitoring/cwagent.json` | CloudWatch agent: memory/disk metrics and log shipping |
| `iam/*.json` | Least-privilege inline policies for the EC2 role and the Lambda role |
| `docs/` | Project website (GitHub Pages) |

## How to deploy (from nothing)

1. **AWS setup** (CloudShell, us-east-1): edit `deploy/settings.env`, then run `bash scripts/aws-setup.sh <alert-email>` and confirm the SNS email.
2. **IAM role** `sam10-ec2-role`: attach `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy`, and an inline policy from `iam/ec2-role-inline-policy.json` (replace ACCOUNT_ID and BUCKET).
3. **EC2**: Ubuntu 24.04, c7i-flex.large (the smallest type with 4 GiB allowed on the account's Free plan), 30 GB gp3 encrypted, role above, security group allowing only TCP 80 and 443 inbound, plus an Elastic IP. Point the DuckDNS name at the Elastic IP.
4. **On the instance** (Session Manager):
   ```bash
   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Wendy-Calma/sam10-calma-wendy-askrizza-ops/main/deploy/bootstrap.sh)" _ https://github.com/Wendy-Calma/sam10-calma-wendy-askrizza-ops.git
   sudo su - ubuntu
   /opt/app/askrizza/deploy/start.sh
   sudo /opt/app/askrizza/scripts/install-automation.sh
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/app/askrizza/monitoring/cwagent.json
   ```
5. **Lambda** `wendy-sam10-healthcheck` (Python 3.12, handler `lambda_function.handler`, 30 s timeout) from `lambda/healthcheck.py`, with the inline policy from `iam/lambda-inline-policy.json` and the environment variables `SITE_URL`, `CHECK_ANSWER=true`, `LLM_BASE_URL` and `LLM_MODEL`. Trigger: EventBridge rule `rate(15 minutes)`.
6. **Monitoring** (CloudShell): `python3 scripts/monitoring-setup.py` creates the metric filters, the `AskRizza` dashboard, the seven alarms and the database log retention.

To change the assistant's knowledge, edit `content/knowledge.md`, upload it to `s3://BUCKET/content/`, and run `deploy/start.sh`.

## Work log

Solo project. All work below is mine.

| Date (2026) | Work |
|---|---|
| 16 Nov | Chose LibreChat and Gemini; ran stock LibreChat locally; set up the AWS account guardrails (MFA, budget, CloudTrail, EBS encryption) |
| 16 Nov | Deployed AskRizza to EC2 with HTTPS; reskin and campus content; secrets in Parameter Store |
| 16 Nov | Fixed the Meilisearch permission incident; set up backups, the health-check Lambda, the CloudWatch dashboard and alarms |
| 16 Nov | Outage drill, restore test, 14 test questions, gym content fix, secret scan, personal-data check |
| 17 Nov | Equal-window comparison and cost; database and per-question request logs; project website |

## AI assistance declaration

I used Claude (Anthropic) as an assistant to plan the deployment and draft scripts and configuration in this repository. I reviewed every file, ran every command myself against my own deployment, and checked the behaviour against the AWS and LibreChat documentation. All evidence on the website comes from my real system.
