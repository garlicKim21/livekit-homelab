# 웹앱: ${APP_HOST} → lk-web svc:8080
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lk-web
  namespace: ${K8S_NAMESPACE}
spec:
  parentRefs:
    - name: ${GATEWAY_NAME}
      namespace: ${GATEWAY_NAMESPACE}
      sectionName: ${GATEWAY_SECTION}
  hostnames:
    - "${APP_HOST}"
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: lk-web
          port: 8080
