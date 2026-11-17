#!/bin/bash
# Writes one JSON line per student question (question, seconds to answer, success,
# model, app version) to /var/log/sam10/requests.log -> CloudWatch /sam10/requests.
# Runs every 5 minutes from cron. Questions are logged once the answer has had
# 2 minutes to finish.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$REPO_DIR/deploy/settings.env"; set +a
LOG=/var/log/sam10/requests.log
STATE=/var/log/sam10/request-log.state

SINCE="$(cat "$STATE" 2>/dev/null || date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)"
UNTIL="$(date -u -d '-2 minutes' +%Y-%m-%dT%H:%M:%SZ)"

docker exec chat-mongodb mongosh --quiet LibreChat --eval "
const since = new Date('$SINCE'), until = new Date('$UNTIL'), version = '$APP_VERSION';
db.messages.find({ isCreatedByUser: true, createdAt: { \$gt: since, \$lte: until } })
  .sort({ createdAt: 1 }).toArray().forEach(q => {
    const r = db.messages.findOne({ parentMessageId: q.messageId, isCreatedByUser: false });
    const done = r ? (r.updatedAt || r.createdAt) : null;
    print(JSON.stringify({
      ts: q.createdAt.toISOString(),
      event: 'question',
      question: (q.text || '').slice(0, 200),
      answered: !!r,
      success: !!(r && !r.error && (r.text || '').trim().length > 0),
      seconds: done ? Math.round((done - q.createdAt) / 100) / 10 : null,
      model: (r && r.model) || q.model || null,
      version: version
    }));
  });
" >> "$LOG"

echo "$UNTIL" > "$STATE"
