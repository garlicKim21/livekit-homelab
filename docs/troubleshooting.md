# 트러블슈팅

## 1. 카메라가 안 켜짐 (아이폰 Safari)

- **HTTPS 필수**: `getUserMedia`는 secure context에서만 동작. `https://${APP_HOST}` (유효한 인증서)로 접속했는지 확인. `http://`나 인증서 오류면 카메라가 조용히 실패합니다.
- 권한 거부 시 Safari ▸ 설정 ▸ 웹사이트 ▸ 카메라/마이크 허용.
- iOS는 동시에 카메라 1개만 캡처 가능. 다른 탭/앱이 카메라를 점유 중이면 실패.

## 2. 시그널링 연결 실패 (wss)

```bash
curl -sI https://${LIVEKIT_HOST}                 # 응답 오는지
```
- nginx에 **WebSocket upgrade 헤더**가 있는지 확인(`proxy_set_header Upgrade/Connection`). 없으면 `101 Switching Protocols`로 전환되지 못함 → [opnsense-nginx.md](opnsense-nginx.md).
- Gateway HTTPRoute의 Host 매칭(`${LIVEKIT_HOST}`)과 nginx가 `Host` 헤더를 보존하는지 확인.
- `kubectl logs -n ${K8S_NAMESPACE} deploy/livekit-server` 에서 들어오는 연결 로그 확인.

## 3. 연결은 되는데 영상이 안 보임 (미디어 ICE 실패)

가장 흔한 문제. 미디어 TCP 경로를 점검합니다.

```bash
# 미디어 LB IP 확인
kubectl get svc -n ${K8S_NAMESPACE} lk-media
# 공인 IP:7881 가 외부에서 열려있는지 (외부 네트워크에서)
nc -vz ${PUBLIC_IP} 7881
```

- **ICE 후보 확인**: PC 크롬 `chrome://webrtc-internals` → 활성 candidate pair가 `tcp`이고 원격 후보가 `${PUBLIC_IP}:7881`인지 확인. UDP 후보가 보이면 `port_range_start/end: 0` 설정이 안 먹은 것.
- **node_ip**: livekit config의 `rtc.node_ip`가 실제 공인 IP인지, `use_external_ip: false`인지 확인. 사설 IP가 후보로 광고되면 외부에서 못 붙음.
  ```bash
  kubectl exec -n ${K8S_NAMESPACE} deploy/livekit-server -- sh -c 'cat /etc/livekit/config.yaml'
  ```
- **포트포워딩**: OPNsense `공인IP:7881 → 미디어 LB IP:7881` (TCP) 규칙과 방화벽 허용 확인.
- **클라이언트 소스 IP**: 미디어 LB Service에 `externalTrafficPolicy: Local`이 있어야 클라이언트 IP가 보존됨.

## 4. 내부 PC에서만 영상이 안 보임 (외부는 정상)

- LiveKit는 공인 IP만 ICE 후보로 광고하므로, 내부 PC도 `${PUBLIC_IP}:7881`로 접속을 시도합니다. **NAT reflection(헤어핀 NAT)** 이 꺼져 있으면 실패합니다 → [network.md](network.md) §4.

## 5. BGP / LoadBalancer IP 미할당

```bash
kubectl get svc -n ${K8S_NAMESPACE} lk-media      # EXTERNAL-IP 가 <pending> 이면
kubectl get ciliumloadbalancerippool              # 풀 정의 확인
cilium bgp routes advertised ipv4 unicast         # 광고 여부
```
- `lk-media` 서비스가 `CiliumLoadBalancerIPPool`의 선택 조건(라벨/네임스페이스)에 맞는지 확인. `MEDIA_LB_IP`를 풀 범위 밖으로 지정하면 할당 실패.

## 6. 녹화(Egress) 문제

- **egress 파드 CrashLoop / 작업 안 잡힘**: Redis 연결 확인. server와 egress가 **같은** `${REDIS_ADDRESS}`를 쓰는지, livekit config에 `redis.address`가 있는지 확인.
  ```bash
  kubectl logs -n ${K8S_NAMESPACE} deploy/egress
  kubectl exec -n ${K8S_NAMESPACE} deploy/redis -- redis-cli ping   # PONG
  ```
- **api_key/secret 불일치**: egress의 `api_key/api_secret`이 livekit-server의 `keys`와 일치해야 함.
- **파일이 안 생김**: PVC가 `${RECORDING_PATH}`에 마운트됐는지, 디스크 여유가 있는지 확인.
  ```bash
  kubectl exec -n ${K8S_NAMESPACE} deploy/egress -- df -h ${RECORDING_PATH}
  ```
- **Room Composite 사용 시 멈춤/OOM**: Chrome `/dev/shm` 부족. `EGRESS_SHM_SIZE`(emptyDir Memory) 확인. CPU 6 이상 권장.

## 7. 유용한 명령

```bash
kubectl get pods -n ${K8S_NAMESPACE} -o wide
kubectl logs  -n ${K8S_NAMESPACE} deploy/livekit-server -f
kubectl get httproute -A
kubectl get gateway   -n ${GATEWAY_NAMESPACE}
./scripts/gen-token.sh                 # 디버그용 토큰
lk room list                           # (LIVEKIT_URL/KEY/SECRET 설정 시)
```
