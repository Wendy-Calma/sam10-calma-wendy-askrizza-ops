#!/bin/bash
# Restore MongoDB from S3. Usage: restore.sh [s3 key]  (default: newest)
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$REPO_DIR/deploy/settings.env"; set +a
START=$(date +%s)

KEY="${1:-$(aws s3api list-objects-v2 --region "$AWS_REGION" --bucket "$BUCKET" --prefix backups/mongo/ \
          --query 'sort_by(Contents,&LastModified)[-1].Key' --output text)}"
echo "[restore] $(date -u +%FT%TZ) restoring s3://$BUCKET/$KEY"
aws s3 cp --region "$AWS_REGION" "s3://$BUCKET/$KEY" /tmp/restore.archive.gz --only-show-errors
docker exec -i chat-mongodb mongorestore --archive --gzip --drop --nsInclude 'LibreChat.*' < /tmp/restore.archive.gz
rm -f /tmp/restore.archive.gz

echo "[restore] collection counts after restore:"
docker exec chat-mongodb mongosh --quiet LibreChat --eval \
  'printjson({users: db.users.countDocuments(), conversations: db.conversations.countDocuments(), messages: db.messages.countDocuments()})'
echo "[restore] finished $(date -u +%FT%TZ) in $(( $(date +%s) - START )) seconds"
