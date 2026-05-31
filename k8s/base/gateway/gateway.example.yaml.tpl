# ⚠️ 참고용 예시 — 이미 Gateway 가 있다면 적용하지 마세요(HTTPRoute 의 parentRef 만 맞추면 됩니다).
# 기존 Gateway 가 없을 때, 이 데모용 HTTP Gateway 를 참고해 만드세요.
# TLS 는 OPNsense nginx 에서 종단되므로 여기서는 HTTP(80) listener 만 둡니다.
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${GATEWAY_NAMESPACE}
spec:
  gatewayClassName: cilium
  listeners:
    - name: ${GATEWAY_SECTION}
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All        # HTTPRoute 가 ${K8S_NAMESPACE} 에 있으므로 교차 네임스페이스 허용
