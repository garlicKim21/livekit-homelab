#!/usr/bin/env bash
# 웹앱 컨테이너 이미지를 빌드하고 ${APP_IMAGE} 로 푸시한다.
#   docker 또는 nerdctl 사용. multi-arch 가 필요하면 buildx 권장.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/.env}"
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

: "${APP_IMAGE:?APP_IMAGE 를 config/.env 에 설정하세요}"

ENGINE="${ENGINE:-docker}"
echo "▶ 빌드: $APP_IMAGE (engine=$ENGINE)"
"$ENGINE" build -t "$APP_IMAGE" "$ROOT/app"

echo "▶ 푸시: $APP_IMAGE"
"$ENGINE" push "$APP_IMAGE"

echo "✓ 완료. 배포 반영:  kubectl -n ${K8S_NAMESPACE:-livekit} rollout restart deploy/lk-web"
