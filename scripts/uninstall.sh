#!/usr/bin/env bash
# 배포 리소스를 제거한다. (PVC/녹화 데이터는 기본 보존)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/config/.env}"
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
NS="${K8S_NAMESPACE:-livekit}"

echo "▶ HTTPRoute / Deployment / Service / Secret 제거 (ns=$NS)"
kubectl -n "$NS" delete httproute livekit-signaling lk-web --ignore-not-found
kubectl -n "$NS" delete deploy livekit-server lk-web egress redis --ignore-not-found
kubectl -n "$NS" delete svc livekit lk-media lk-web redis --ignore-not-found
kubectl -n "$NS" delete secret livekit-config egress-config lk-web-secret --ignore-not-found
kubectl -n "$NS" delete configmap lk-web-env --ignore-not-found

if [ "${1:-}" = "--purge" ]; then
  echo "▶ --purge: PVC(녹화 데이터) 와 네임스페이스까지 제거"
  kubectl -n "$NS" delete pvc recordings --ignore-not-found
  kubectl delete namespace "$NS" --ignore-not-found
else
  echo "ℹ PVC(recordings)/네임스페이스는 보존했습니다. 완전 삭제: $0 --purge"
fi
