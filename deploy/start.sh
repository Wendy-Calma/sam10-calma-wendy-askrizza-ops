#!/bin/bash
# Deploy AskRizza: secrets from SSM, content from S3, then docker compose up.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LC_DIR=/opt/app/LibreChat

set -a
source "$REPO_DIR/deploy/settings.env"
set +a

echo "[start] reading secrets from SSM Parameter Store (/sam10/*)"
for name in CREDS_KEY CREDS_IV JWT_SECRET JWT_REFRESH_SECRET MEILI_MASTER_KEY LLM_API_KEY; do
  value="$(aws ssm get-parameter --region "$AWS_REGION" --name "/sam10/$name" \
           --with-decryption --query Parameter.Value --output text)"
  export "$name=$value"
done

echo "[start] downloading content from s3://$BUCKET/content/knowledge.md"
aws s3 cp --region "$AWS_REGION" "s3://$BUCKET/content/knowledge.md" /tmp/knowledge.md --only-show-errors

echo "[start] rendering config"
python3 "$REPO_DIR/deploy/render.py" "$REPO_DIR/deploy/librechat.template.yaml" /tmp/knowledge.md "$LC_DIR/librechat.yaml"
rm -f /tmp/knowledge.md
cp "$REPO_DIR/deploy/docker-compose.override.yml" "$LC_DIR/docker-compose.override.yml"
cp "$REPO_DIR/deploy/Caddyfile" "$LC_DIR/Caddyfile"
MEILI_DIR="$(grep -o 'meili_data_v[0-9.]*' "$LC_DIR/docker-compose.yml" | head -1)"
mkdir -p "$LC_DIR/branding" "$LC_DIR/logs/caddy" "$LC_DIR/data-node" "$LC_DIR/images" \
         "$LC_DIR/uploads" "$LC_DIR/$MEILI_DIR"
cp "$REPO_DIR/branding/logo.svg" "$LC_DIR/branding/logo.svg"
"$REPO_DIR/deploy/configure-env.sh" "$LC_DIR/.env"

echo "[start] starting containers"
cd "$LC_DIR"
docker compose pull --quiet
docker compose up -d --remove-orphans
docker compose ps
echo "[start] done: https://$SITE_DOMAIN  (version $APP_VERSION)"
