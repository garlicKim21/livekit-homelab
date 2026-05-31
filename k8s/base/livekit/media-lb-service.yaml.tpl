# 미디어 ICE/TCP 노출. Cilium BGP 가 EXTERNAL-IP 를 광고하고,
# OPNsense 가 공인IP:${MEDIA_TCP_PORT} → 이 IP:${MEDIA_TCP_PORT} 로 포트포워딩한다.
apiVersion: v1
kind: Service
metadata:
  name: lk-media
  namespace: ${K8S_NAMESPACE}
  labels: { app: livekit-server }
  annotations:
    # MEDIA_LB_IP 가 .env 에 지정되면 render.sh 가 아래에 Cilium LB-IPAM 고정 IP 주석을 채운다.
    ${MEDIA_LB_ANNOTATION}
spec:
  type: LoadBalancer
  # 클라이언트 소스 IP 보존 — WebRTC ICE 에 필요
  externalTrafficPolicy: Local
  selector: { app: livekit-server }
  ports:
    - { name: rtc-tcp, port: ${MEDIA_TCP_PORT}, targetPort: ${MEDIA_TCP_PORT}, protocol: TCP }
