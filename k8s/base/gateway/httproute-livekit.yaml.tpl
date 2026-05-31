# 시그널링: ${LIVEKIT_HOST} → livekit svc:7880 (WebSocket)
# TLS 는 OPNsense nginx 에서 종단되므로 Gateway 는 HTTP listener 를 사용한다.
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: livekit-signaling
  namespace: ${K8S_NAMESPACE}
spec:
  parentRefs:
    # sectionName 은 생략 (단일 리스너 Gateway. 명시 시 Cilium이 attach 안 하는 사례 있음)
    - name: ${GATEWAY_NAME}
      namespace: ${GATEWAY_NAMESPACE}
  hostnames:
    - "${LIVEKIT_HOST}"
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: livekit
          port: 7880
