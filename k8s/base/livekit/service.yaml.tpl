# 시그널링/API (Gateway 백엔드). 내부 ClusterIP.
apiVersion: v1
kind: Service
metadata:
  name: livekit
  namespace: ${K8S_NAMESPACE}
  labels: { app: livekit-server }
spec:
  type: ClusterIP
  selector: { app: livekit-server }
  ports:
    - { name: signaling, port: 7880, targetPort: 7880, protocol: TCP }
