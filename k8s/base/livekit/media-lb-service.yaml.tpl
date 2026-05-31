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
  # externalTrafficPolicy:
  #  - Local  : 클라 소스 IP 보존하나, OPNsense BGP(nexthop=파드노드)와 결합 시
  #             응답 경로 비대칭으로 OPNsense에서 "state violation"으로 차단되는 사례 발생.
  #  - Cluster: 노드 내부 SNAT로 응답이 대칭 → OPNsense 통과. ICE/TCP는 연결별 ufrag로
  #             세션을 구분하므로 소스 IP 미보존이어도 기능 문제 없음. (작동하는 gateway와 동일)
  externalTrafficPolicy: Cluster
  selector: { app: livekit-server }
  ports:
    - { name: rtc-tcp, port: ${MEDIA_TCP_PORT}, targetPort: ${MEDIA_TCP_PORT}, protocol: TCP }
