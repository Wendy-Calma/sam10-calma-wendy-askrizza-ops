#!/bin/bash
# Writes non-secret values into LibreChat's .env and blanks secret keys (supplied from SSM).
# Usage: configure-env.sh <path to .env>
set -euo pipefail
ENV_FILE="$1"
LC_DIR="$(dirname "$ENV_FILE")"

[ -f "$ENV_FILE" ] || cp "$LC_DIR/.env.example" "$ENV_FILE"

set_kv() {
  local key="$1" value="$2"
  if grep -qE "^#? *${key}=" "$ENV_FILE"; then
    sed -i -E "s|^#? *${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

set_kv UID "$(id -u)"
set_kv GID "$(id -g)"
set_kv APP_TITLE "$APP_TITLE"
set_kv CUSTOM_FOOTER "\"$APP_TITLE $APP_VERSION - fictional Rizza Polytechnic demo. Built on LibreChat (MIT).\""
set_kv DOMAIN_CLIENT "https://$SITE_DOMAIN"
set_kv DOMAIN_SERVER "https://$SITE_DOMAIN"
set_kv ENDPOINTS custom
set_kv DEBUG_LOGGING true
set_kv ALLOW_REGISTRATION "${ALLOW_REGISTRATION:-true}"
set_kv ALLOW_SOCIAL_LOGIN false

for k in CREDS_KEY CREDS_IV JWT_SECRET JWT_REFRESH_SECRET MEILI_MASTER_KEY LLM_API_KEY GROQ_API_KEY GOOGLE_KEY OPENAI_API_KEY; do
  set_kv "$k" ""
done
chmod 600 "$ENV_FILE"
echo "[configure-env] $ENV_FILE updated (no secrets written)"
