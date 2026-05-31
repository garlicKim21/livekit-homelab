# 시그널링: ${LIVEKIT_HOST} → livekit svc:7880 (WebSocket)
# TLS 는 OPNsense nginx 에서 종단되므로 Gateway 는 HTTP listener 를 사용한다.
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: livekit-signaling
  namespace: ${K8S_NAMESPACE}
spec:
  parentRefs:
    - name: ${GATEWAY_NAME}
      namespace: ${GATEWAY_NAMESPACE}
      sectionName: ${GATEWAY_SECTION}
  hostnames:
    - "${LIVEKIT_HOST}"
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: livekit
          port: 7880
