#!/bin/bash
# Ubuntu 24.04 host setup: Docker, AWS CLI, CloudWatch agent, code in /opt/app.
# Usage: sudo bash bootstrap.sh <repo url>
set -euo pipefail
REPO_URL="${1:?usage: sudo bash bootstrap.sh <git url of this repo>}"
LIBRECHAT_URL=https://github.com/danny-avila/LibreChat.git
APP_USER=ubuntu

echo "[bootstrap] packages"
apt-get update -y
apt-get install -y git python3 curl unzip jq
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
usermod -aG docker "$APP_USER"
command -v aws >/dev/null || snap install aws-cli --classic

echo "[bootstrap] CloudWatch agent"
if [ ! -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
  curl -fsSL -o /tmp/cwagent.deb https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  dpkg -i /tmp/cwagent.deb
fi

echo "[bootstrap] code"
mkdir -p /opt/app /var/log/sam10
chown "$APP_USER:$APP_USER" /opt/app /var/log/sam10
[ -d /opt/app/LibreChat ] || sudo -u "$APP_USER" git clone --depth 1 "$LIBRECHAT_URL" /opt/app/LibreChat
[ -d /opt/app/askrizza ] || sudo -u "$APP_USER" git clone "$REPO_URL" /opt/app/askrizza
chmod +x /opt/app/askrizza/deploy/*.sh /opt/app/askrizza/scripts/*.sh

echo "[bootstrap] done"
