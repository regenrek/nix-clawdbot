#!/usr/bin/env bash
set -euo pipefail

data_dir="${CLAWDBOT_DATA_DIR:-/data}"
config_path="${CLAWDBOT_CONFIG_PATH:-$data_dir/clawdbot.json}"
workspace_dir="${CLAWDBOT_WORKSPACE_DIR:-$data_dir/workspace}"
log_dir="${CLAWDBOT_LOG_DIR:-$data_dir/logs}"
secrets_dir="${CLAWDBOT_SECRETS_DIR:-$data_dir/secrets}"
gateway_port="${CLAWDBOT_GATEWAY_PORT:-18789}"
require_mention="${CLAWDBOT_TELEGRAM_REQUIRE_MENTION:-true}"

bot_token="${CLAWDBOT_TELEGRAM_BOT_TOKEN:-}"
allow_from_raw="${CLAWDBOT_TELEGRAM_ALLOW_FROM:-}"

if [ -z "$bot_token" ] || [ -z "$allow_from_raw" ]; then
  cat <<'EOF2' >&2
Missing required env vars.

Set:
  CLAWDBOT_TELEGRAM_BOT_TOKEN
  CLAWDBOT_TELEGRAM_ALLOW_FROM (comma-separated Telegram user/chat IDs)
EOF2
  exit 1
fi

mkdir -p "$workspace_dir" "$log_dir" "$secrets_dir"

if [ -z "${SSL_CERT_FILE:-}" ]; then
  export SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
fi
if [ -z "${NODE_EXTRA_CA_CERTS:-}" ]; then
  export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-bundle.crt"
fi

token_file="$secrets_dir/telegram-bot-token"
umask 077
printf "%s" "$bot_token" > "$token_file"

raw_allow_from="${allow_from_raw// /,}"
allow_from_json="["
first=1
IFS=',' read -r -a allow_parts <<< "$raw_allow_from"
for part in "${allow_parts[@]}"; do
  part="$(printf "%s" "$part" | tr -d '[:space:]')"
  if [ -z "$part" ]; then
    continue
  fi
  if [ "$first" -eq 0 ]; then
    allow_from_json+=", "
  fi
  allow_from_json+="$part"
  first=0
done
allow_from_json+="]"

cat > "$config_path" <<EOF2
{
  "gateway": { "mode": "local" },
  "agent": { "workspace": "$workspace_dir" },
  "telegram": {
    "enabled": true,
    "tokenFile": "$token_file",
    "allowFrom": $allow_from_json,
    "groups": { "*": { "requireMention": $require_mention } }
  }
}
EOF2

if [ -n "${CLAWDBOT_ANTHROPIC_API_KEY:-}" ]; then
  export ANTHROPIC_API_KEY="$CLAWDBOT_ANTHROPIC_API_KEY"
fi

if [ -n "${CLAWDBOT_TELEGRAM_BOT_TOKEN:-}" ] && [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  export TELEGRAM_BOT_TOKEN="$CLAWDBOT_TELEGRAM_BOT_TOKEN"
fi

export CLAWDBOT_CONFIG_PATH="$config_path"
export CLAWDBOT_STATE_DIR="$data_dir"
export CLAWDIS_CONFIG_PATH="$config_path"
export CLAWDIS_STATE_DIR="$data_dir"

exec /bin/clawdbot gateway --port "$gateway_port"
