# 네트워크 설정 (Cloudflare / OPNsense / Cilium BGP)

외부의 송출자(핸드폰)와 시청자(PC)가 홈랩 LiveKit에 도달하도록 하는 **DNS, 포트포워딩, BGP** 설정입니다.

> 시나리오: **모든 클라이언트가 외부(인터넷)**. 내부 시청(헤어핀/NAT reflection)이나 폐쇄망 변형은 [design-decisions.md](design-decisions.md) 참고.

> 핵심 원칙: **시그널링(WSS 443)과 미디어(TCP 7881)는 경로가 다릅니다.** 시그널링은 nginx(TLS 종단)→Gateway, 미디어는 OPNsense raw TCP 포트포워딩. WebRTC 미디어는 HTTP/TLS 프록시를 통과할 수 없습니다.

---

## 1. Cloudflare DNS

`basphere.dev` 존에 **DNS-only(grey cloud)** 로 추가합니다. 오렌지 프록시는 미디어 TCP 7881을 막습니다.

| 타입 | 이름 | 값 | 프록시 |
|------|------|----|--------|
| A | `livekit` | `<공인IP>` | DNS only (grey) |
| A | `app` | `<공인IP>` | DNS only (grey) |

`<공인IP>` = OPNsense WAN 공인 IP. 동적 IP면 OPNsense Cloudflare DDNS 사용.

---

## 2. OPNsense 포트포워딩 (미디어 TCP 7881)

미디어는 nginx를 거치지 않고 **방화벽 NAT 포트포워딩**으로 직접 클러스터로 보냅니다.

`Firewall ▸ NAT ▸ Port Forward`:

| 항목 | 값 |
|------|----|
| Interface | WAN |
| Protocol | TCP |
| Destination | WAN address |
| Destination port | `7881` |
| Redirect target IP | `<미디어 LB IP>` (lk-media 의 EXTERNAL-IP, lb-pool=172.16.200.0/24) |
| Redirect target port | `7881` |

```bash
kubectl get svc -n livekit lk-media   # EXTERNAL-IP 확인
```
고정하려면 `config/.env` 의 `MEDIA_LB_IP` 를 172.16.200.0/24 범위로 지정(첫/마지막 IP 제외).

---

## 3. Cilium BGP ⇄ OPNsense

Cilium이 LoadBalancer 서비스 IP(`lb-pool`, 172.16.200.0/24)를 BGP로 OPNsense에 광고합니다.

```bash
# OPNsense(FRR)
vtysh -c "show bgp ipv4 unicast"      # 172.16.200.x 경로 학습 확인
# Cilium
cilium bgp routes advertised ipv4 unicast
kubectl get svc -A | grep LoadBalancer
```

- 미디어 포트포워딩 대상(`<미디어 LB IP>`)과 nginx upstream(Gateway `172.16.200.1`) 모두 BGP로 광고되는 LB IP입니다.
- `lb-pool` 은 셀렉터가 없어 LoadBalancer 서비스에 **자동 할당**됩니다. `lk-media` 는 type:LoadBalancer 만으로 IP를 받습니다.

---

## 4. 시그널링 / 웹앱 경로 (443)

`443`은 OPNsense nginx가 TLS 종단 후 Cilium Gateway(`172.16.200.1:80`)로 프록시합니다 → [opnsense-nginx.md](opnsense-nginx.md).

- `livekit.basphere.dev:443` → nginx → Gateway → `livekit` svc:7880 (WebSocket 시그널링)
- `app.basphere.dev:443` → nginx → Gateway → `lk-web` svc:8080 (웹앱/토큰)
- `80` → ACME (기존 OPNsense ACME, `*.basphere.dev` 갱신)

---

## 포트 요약

| 포트 | 프로토콜 | 외부 | 경로 | 용도 |
|------|----------|------|------|------|
| 443 | TCP | ✅ | nginx→Gateway | 시그널링(WSS) + 웹앱(HTTPS) |
| 80 | TCP | ✅ | OPNsense ACME | 인증서 갱신 |
| **7881** | **TCP** | ✅ | **raw 포트포워딩** | WebRTC 미디어(ICE/TCP) |
| 7880 | TCP | ❌ | Gateway→svc | 시그널링 백엔드 |
| 7882 | UDP | ❌ 미노출 | 내부 | UDP mux (외부 포트포워딩 안 함) |
