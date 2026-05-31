#!/usr/bin/env bash
# 웹앱 API 를 통해 녹화를 시작/중지/조회한다.
#   ./scripts/record.sh start <identity> [room]
#   ./scripts/record.sh stop  <egressId>
#   ./scripts/record.sh list
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/.env}"
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

BASE="https://${APP_HOST}/api/record"
cmd="${1:-list}"

case "$cmd" in
  start)
    IDENTITY="${2:?identity 필요}"; ROOM="${3:-${DEFAULT_ROOM:-demo-room}}"
    curl -fsS -X POST "$BASE/start" -H 'content-type: application/json' \
      -d "{\"room\":\"$ROOM\",\"identity\":\"$IDENTITY\"}"; echo ;;
  stop)
    EGRESS_ID="${2:?egressId 필요}"
    curl -fsS -X POST "$BASE/stop" -H 'content-type: application/json' \
      -d "{\"egressId\":\"$EGRESS_ID\"}"; echo ;;
  list)
    curl -fsS "$BASE/list"; echo ;;
  *) echo "사용: $0 {start <identity> [room]|stop <egressId>|list}"; exit 1 ;;
esac
