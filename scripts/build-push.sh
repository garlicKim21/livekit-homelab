#!/usr/bin/env bash
# 웹앱 이미지를 amd64로 빌드해 ${APP_IMAGE} 로 푸시한다.
#
# ▶ 권장: GitHub Actions(.github/workflows/build-web.yml)가 push 시 자동 빌드/푸시.
#         로컬 docker/buildx 불필요, GITHUB_TOKEN 으로 ghcr 권한 자동.
# ▶ 로컬 빌드(이 스크립트): Docker 데몬 실행 + ghcr 로그인 필요.
#     gh auth refresh -s write:packages          # 토큰에 packages 권한 추가
#     gh auth token | docker login ghcr.io -u <github-user> --password-stdin
#   대상 클러스터가 amd64면 PLATFORM=linux/amd64 (Mac ARM 에서도 크로스빌드).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/.env}"
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

: "${APP_IMAGE:?APP_IMAGE 를 config/.env 에 설정하세요}"
PLATFORM="${PLATFORM:-linux/amd64}"

echo "▶ buildx 빌드+푸시: $APP_IMAGE (platform=$PLATFORM)"
docker buildx build --platform "$PLATFORM" -t "$APP_IMAGE" --push "$ROOT/app"

echo "✓ 완료. 배포 반영:  kubectl -n ${K8S_NAMESPACE:-livekit} rollout restart deploy/lk-web"
