# 트러블슈팅

> 시나리오: 송출자·시청자 모두 외부. 내부 시청/헤어핀 관련 이슈는 [design-decisions.md](design-decisions.md) 참고.

## 1. 카메라가 안 켜짐 (아이폰 Safari)

- **HTTPS 필수**: `getUserMedia`는 secure context에서만 동작. `https://${APP_HOST}`(유효 인증서)로 접속했는지 확인. HTTP/인증서 오류면 카메라가 조용히 실패.
- Safari ▸ 설정 ▸ 웹사이트 ▸ 카메라/마이크 허용.
- iOS는 동시에 카메라 1개만 캡처 가능.

## 2. "비밀번호가 틀렸습니다" (401)

- 페이지의 **접근 비밀번호**가 `config/.env`의 `APP_PASSWORD`와 일치해야 합니다.
- 시크릿 확인: `kubectl -n ${K8S_NAMESPACE} get secret lk-web-secret -o jsonpath='{.data.APP_PASSWORD}' | base64 -d`
- `APP_PASSWORD`를 비워서 배포하면 보호가 꺼집니다(페이지의 비번 입력칸도 숨겨짐).

## 3. 시그널링 연결 실패 (wss)

```bash
curl -sI https://${LIVEKIT_HOST}
```
- nginx **WebSocket upgrade 헤더**(`Upgrade`/`Connection`) 확인 → [opnsense-nginx.md](opnsense-nginx.md).
- HTTPRoute Host 매칭(`${LIVEKIT_HOST}`)과 nginx `Host` 보존 확인.
- `kubectl logs -n ${K8S_NAMESPACE} deploy/livekit-server`.

## 4. 연결은 되는데 영상이 안 보임 (미디어 ICE/TCP)

```bash
kubectl get svc -n ${K8S_NAMESPACE} lk-media     # EXTERNAL-IP
nc -vz ${PUBLIC_IP} 7881                          # 외부망에서
```
- **ICE 후보 확인**: PC 크롬 `chrome://webrtc-internals` → 활성 candidate가 `tcp`이고 원격이 `${PUBLIC_IP}:7881`인지. UDP(7882)는 외부 포트포워딩하지 않으므로 도달 불가 → TCP로 붙어야 정상.
- **node_ip**: config의 `rtc.node_ip`가 공인 IP, `use_external_ip: false`인지.
  ```bash
  kubectl exec -n ${K8S_NAMESPACE} deploy/livekit-server -- cat /etc/livekit/config.yaml
  ```
- **포트포워딩**: OPNsense `공인IP:7881 → 미디어 LB IP:7881`(TCP)과 방화벽 허용.
- **externalTrafficPolicy**: `lk-media`는 `Cluster` 사용(작동하는 gateway와 동일). `Local`은 BGP nexthop이 파드 노드로 고정되며 OPNsense에서 비대칭 라우팅("state violation") 차단을 유발할 수 있어 피한다. ICE/TCP는 ufrag로 세션 구분하므로 소스 IP 미보존이어도 무방.
- **OPNsense 포트포워드 필터**: 7881이 외부에서 안 열리면, NAT 변환 후 필터가 평가되므로 **방화벽 규칙 목적지가 redirect 대상(미디어 LB IP)** 인지 확인. WAN address로 두면 "Default deny"로 막힌다. → 포트포워드의 `Filter rule association = Pass` 권장. [network.md](network.md) §2.

## 5. BGP / LoadBalancer IP 미할당

```bash
kubectl get svc -n ${K8S_NAMESPACE} lk-media      # <pending> 이면
kubectl get ciliumloadbalancerippool lb-pool -o yaml
cilium bgp routes advertised ipv4 unicast
```
- `MEDIA_LB_IP`를 lb-pool(172.16.200.0/24) 범위 밖으로 지정하면 할당 실패.

## 6. 녹화(Egress) 문제

```bash
kubectl logs -n ${K8S_NAMESPACE} deploy/egress
kubectl exec -n ${K8S_NAMESPACE} deploy/redis -- redis-cli ping     # PONG
kubectl exec -n ${K8S_NAMESPACE} deploy/egress -- df -h ${RECORDING_PATH}
```
- server/egress가 같은 `${REDIS_ADDRESS}`를 보는지, api_key/secret이 일치하는지 확인.
- Room Composite(Chrome) 사용 시 `/dev/shm`(EGRESS_SHM_SIZE)·CPU 부족 주의.

## 7. 유용한 명령

```bash
kubectl get pods,svc -n ${K8S_NAMESPACE} -o wide
kubectl logs -n ${K8S_NAMESPACE} deploy/livekit-server -f
kubectl get httproute -A ; kubectl get gateway -n gateway-system
./scripts/gen-token.sh
```
