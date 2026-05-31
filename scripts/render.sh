#!/usr/bin/env bash
# config/.env 값으로 k8s/base/**/*.yaml.tpl 을 rendered/ 로 렌더링한다.
#   - ENABLE_RECORDING != true 면 redis/egress 리소스를 건너뛴다.
#   - livekit/egress 의 config.yaml.tpl 은 Secret 소스로 rendered/secrets/ 에 출력한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/.env}"
OUT="$ROOT/rendered"
BASE="$ROOT/k8s/base"

[ -f "$ENV_FILE" ] || { echo "✗ $ENV_FILE 가 없습니다. 'cp config/.env.example config/.env' 후 값을 채우세요."; exit 1; }

# .env 로드 (중첩 ${VAR} 참조 확장)
set -a; # shellcheck disable=SC1090
source "$ENV_FILE"; set +a

# ── 조건부/계산 변수 ─────────────────────────────────────────────
if [ "${ENABLE_RECORDING:-false}" = "true" ]; then
  export REDIS_CONFIG_BLOCK="redis:
  address: ${REDIS_ADDRESS}"
else
  export REDIS_CONFIG_BLOCK=""
fi

if [ -n "${MEDIA_LB_IP:-}" ]; then
  export MEDIA_LB_ANNOTATION="lbipam.cilium.io/ips: \"${MEDIA_LB_IP}\""
else
  export MEDIA_LB_ANNOTATION="app.kubernetes.io/part-of: livekit-homelab"
fi

if [ -n "${RECORDING_STORAGE_CLASS:-}" ]; then
  export RECORDING_STORAGE_CLASS_LINE="storageClassName: ${RECORDING_STORAGE_CLASS}"
else
  export RECORDING_STORAGE_CLASS_LINE=""
fi

# ── 치환 엔진: envsubst 우선, 없으면 perl 폴백 ───────────────────
# envsubst 는 명시한 변수만 치환(안전). perl 폴백은 환경에 존재하는 ${VAR} 만 치환.
if command -v envsubst >/dev/null 2>&1; then
  VARS="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" | cut -d= -f1 | tr '\n' ' ')"
  VARS="$VARS REDIS_CONFIG_BLOCK MEDIA_LB_ANNOTATION RECORDING_STORAGE_CLASS_LINE"
  SUBST="$(printf '${%s} ' $VARS)"
  subst() { envsubst "$SUBST"; }
elif command -v perl >/dev/null 2>&1; then
  # 환경에 정의된 ${VAR} 만 치환, 미정의는 원문 유지
  subst() { perl -0pe 's/\$\{([A-Za-z_]\w*)\}/exists $ENV{$1} ? $ENV{$1} : $&/ge'; }
else
  echo "✗ envsubst 또는 perl 이 필요합니다 (brew install gettext)."; exit 1
fi

render() { # <src .tpl> <dst>
  mkdir -p "$(dirname "$2")"
  subst < "$1" > "$2"
  echo "  → ${2#$ROOT/}"
}

rm -rf "$OUT"
echo "▶ 렌더링 (ENABLE_RECORDING=${ENABLE_RECORDING:-false})"

# 항상 배포되는 매니페스트
ALWAYS=(
  namespace.yaml
  livekit/deployment.yaml livekit/service.yaml livekit/media-lb-service.yaml
  app/configmap.yaml app/deployment.yaml app/service.yaml
  gateway/httproute-livekit.yaml gateway/httproute-app.yaml
)
for f in "${ALWAYS[@]}"; do render "$BASE/$f.tpl" "$OUT/$f"; done

# 녹화 시에만
if [ "${ENABLE_RECORDING:-false}" = "true" ]; then
  for f in redis/deployment.yaml redis/service.yaml egress/deployment.yaml egress/pvc.yaml; do
    render "$BASE/$f.tpl" "$OUT/$f"
  done
fi

# Secret 소스 (config 파일) — install.sh 가 Secret 으로 만든다 (직접 apply 안 함)
render "$BASE/livekit/config.yaml.tpl" "$OUT/secrets/livekit-config.yaml"
if [ "${ENABLE_RECORDING:-false}" = "true" ]; then
  render "$BASE/egress/config.yaml.tpl" "$OUT/secrets/egress-config.yaml"
fi

# 참고용 Gateway 예시 (apply 안 함)
render "$BASE/gateway/gateway.example.yaml.tpl" "$OUT/gateway/gateway.example.yaml"

echo "✓ 렌더 완료: ${OUT#$ROOT/}/"
