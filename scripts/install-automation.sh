#!/bin/bash
# Installs the backup cron job (root).
set -euo pipefail
cat > /etc/cron.d/sam10-backup <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
5 * * * * ubuntu /opt/app/askrizza/scripts/backup.sh >> /var/log/sam10/backup-cron.log 2>&1
EOF
chmod 644 /etc/cron.d/sam10-backup
echo "Installed /etc/cron.d/sam10-backup:"; cat /etc/cron.d/sam10-backup
