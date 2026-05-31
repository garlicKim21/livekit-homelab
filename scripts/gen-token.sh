#!/usr/bin/env bash
# 디버그용 액세스 토큰 발급. lk CLI 가 있으면 사용, 없으면 안내.
#   사용: ./scripts/gen-token.sh [room] [identity] [publisher|viewer]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/.env}"
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

ROOM="${1:-${DEFAULT_ROOM:-demo-room}}"
IDENTITY="${2:-debug-user}"
ROLE="${3:-publisher}"

if ! command -v lk >/dev/null 2>&1; then
  cat <<EOF
✗ lk CLI 가 없습니다. 설치:
    brew install livekit-cli         # macOS
    curl -sSL https://get.livekit.io/cli | bash
또는 웹앱 토큰 엔드포인트를 사용하세요:
    curl "https://${APP_HOST}/api/token?room=${ROOM}&identity=${IDENTITY}&role=${ROLE}"
EOF
  exit 1
fi

PUB="true"; SUB="true"
[ "$ROLE" = "viewer" ] && PUB="false"

lk token create \
  --api-key "$LIVEKIT_API_KEY" --api-secret "$LIVEKIT_API_SECRET" \
  --join --room "$ROOM" --identity "$IDENTITY" \
  --allow-source camera,microphone \
  --valid-for 6h \
  $( [ "$PUB" = "false" ] && echo "--can-publish=false" )
