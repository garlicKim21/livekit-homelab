apiVersion: v1
kind: ConfigMap
metadata:
  name: lk-web-env
  namespace: ${K8S_NAMESPACE}
  labels: { app: lk-web }
data:
  # 브라우저가 시그널링에 쓸 공개 WSS URL
  LIVEKIT_WS_URL: "wss://${LIVEKIT_HOST}"
  # 토큰서버가 Egress API 호출에 쓸 내부 URL
  LIVEKIT_API_URL_INTERNAL: "http://livekit.${K8S_NAMESPACE}.svc.cluster.local:7880"
  LIVEKIT_CLIENT_VERSION: "${LIVEKIT_CLIENT_VERSION}"
  RECORDING_PATH: "${RECORDING_PATH}"
  ENABLE_RECORDING: "${ENABLE_RECORDING}"
  DEFAULT_ROOM: "${DEFAULT_ROOM}"
  PORT: "8080"
