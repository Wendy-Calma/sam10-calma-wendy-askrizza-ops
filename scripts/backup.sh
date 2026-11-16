#!/bin/bash
# Hourly MongoDB dump to S3. Alerts via SNS on failure.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$REPO_DIR/deploy/settings.env"; set +a
LOG=/var/log/sam10/automation.log
if [[ "$SNS_TOPIC_ARN" == *CHANGE_ME* ]]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  SNS_TOPIC_ARN="arn:aws:sns:$AWS_REGION:$ACCOUNT_ID:sam10-alerts"
fi
TS=$(date -u +%Y%m%dT%H%M%SZ)
FILE=/tmp/mongo-$TS.archive.gz
KEY="backups/mongo/mongo-$TS.archive.gz"
START=$(date +%s)

fail() {
  echo "{\"ts\":\"$TS\",\"job\":\"backup\",\"result\":\"FAILED\",\"step\":\"$1\"}" >> "$LOG"
  aws sns publish --region "$AWS_REGION" --topic-arn "$SNS_TOPIC_ARN" \
    --subject "AskRizza backup FAILED ($1)" --message "Backup $TS failed at step: $1" >/dev/null || true
  rm -f "$FILE"; exit 1
}

docker exec chat-mongodb mongodump --db LibreChat --archive --gzip --quiet > "$FILE" || fail mongodump
[ -s "$FILE" ] || fail empty-dump
aws s3 cp --region "$AWS_REGION" "$FILE" "s3://$BUCKET/$KEY" --only-show-errors || fail s3-upload
SIZE=$(stat -c %s "$FILE")
rm -f "$FILE"
echo "{\"ts\":\"$TS\",\"job\":\"backup\",\"result\":\"ok\",\"s3_key\":\"$KEY\",\"bytes\":$SIZE,\"seconds\":$(( $(date +%s) - START ))}" >> "$LOG"
