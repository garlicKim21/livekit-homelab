#!/usr/bin/env bash
# 렌더링 후 클러스터에 배포한다. (kubectl 컨텍스트가 홈랩 클러스터를 가리켜야 함)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/.env}"
OUT="$ROOT/rendered"

# 렌더
"$ROOT/scripts/render.sh"

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
NS="${K8S_NAMESPACE:-livekit}"

echo "▶ 네임스페이스"
kubectl apply -f "$OUT/namespace.yaml"

echo "▶ Secret: livekit-config"
kubectl -n "$NS" create secret generic livekit-config \
  --from-file=config.yaml="$OUT/secrets/livekit-config.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "▶ Secret: lk-web-secret (API key/secret)"
kubectl -n "$NS" create secret generic lk-web-secret \
  --from-literal=LIVEKIT_API_KEY="$LIVEKIT_API_KEY" \
  --from-literal=LIVEKIT_API_SECRET="$LIVEKIT_API_SECRET" \
  --from-literal=APP_PASSWORD="${APP_PASSWORD:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

if [ "${ENABLE_RECORDING:-false}" = "true" ]; then
  echo "▶ Secret: egress-config"
  kubectl -n "$NS" create secret generic egress-config \
    --from-file=config.yaml="$OUT/secrets/egress-config.yaml" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "▶ 매니페스트 적용"
kubectl apply -f "$OUT/livekit/"
kubectl apply -f "$OUT/app/"
# 녹화 리소스
[ -d "$OUT/redis" ]  && kubectl apply -f "$OUT/redis/"
[ -d "$OUT/egress" ] && kubectl apply -f "$OUT/egress/"
# Gateway HTTPRoute (gateway.example.yaml 은 제외)
kubectl apply -f "$OUT/gateway/httproute-livekit.yaml" -f "$OUT/gateway/httproute-app.yaml"

echo "▶ config 변경 반영을 위해 재시작"
kubectl -n "$NS" rollout restart deploy/livekit-server deploy/lk-web 2>/dev/null || true
[ "${ENABLE_RECORDING:-false}" = "true" ] && kubectl -n "$NS" rollout restart deploy/egress 2>/dev/null || true

echo
echo "✓ 배포 완료. 상태 확인:"
echo "    kubectl get pods,svc -n $NS"
echo "    kubectl get svc -n $NS lk-media   # EXTERNAL-IP 를 OPNsense 포트포워딩 대상으로"
echo
echo "다음(수동): docs/network.md, docs/opnsense-nginx.md 의 DNS/포트포워딩/nginx 설정"
