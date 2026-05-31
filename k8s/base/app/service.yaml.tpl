apiVersion: v1
kind: Service
metadata:
  name: lk-web
  namespace: ${K8S_NAMESPACE}
  labels: { app: lk-web }
spec:
  type: ClusterIP
  selector: { app: lk-web }
  ports:
    - { name: http, port: 8080, targetPort: 8080, protocol: TCP }
