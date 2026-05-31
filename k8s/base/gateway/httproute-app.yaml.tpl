# 웹앱: ${APP_HOST} → lk-web svc:8080
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lk-web
  namespace: ${K8S_NAMESPACE}
spec:
  parentRefs:
    # sectionName 은 생략 (단일 리스너 Gateway. 명시 시 Cilium이 attach 안 하는 사례 있음)
    - name: ${GATEWAY_NAME}
      namespace: ${GATEWAY_NAMESPACE}
  hostnames:
    - "${APP_HOST}"
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: lk-web
          port: 8080
