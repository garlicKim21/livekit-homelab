# 네트워크 설정 (Cloudflare / OPNsense / Cilium BGP)

이 문서는 외부 아이폰과 내부 PC가 LiveKit에 도달하도록 하는 **DNS, 포트포워딩, BGP, NAT reflection** 설정을 다룹니다.

> 핵심 원칙: **시그널링(WSS 443)과 미디어(TCP 7881)는 경로가 다릅니다.**
> 시그널링은 nginx(TLS 종단)→Gateway를 거치고, 미디어는 OPNsense에서 raw TCP로 직접 포트포워딩됩니다.
> WebRTC 미디어는 HTTP/TLS 프록시를 통과할 수 없습니다.

---

## 1. Cloudflare DNS

`basphere.dev` 존에 아래 레코드를 추가합니다. **반드시 DNS-only(grey cloud)** 로 설정하세요.
Cloudflare 오렌지 프록시(orange cloud)는 HTTP(S)만 프록시하므로 미디어 TCP 7881이 막히고, 시그널링 WebSocket도 타임아웃/제약이 생길 수 있습니다.

| 타입 | 이름 | 값 | 프록시 |
|------|------|----|--------|
| A | `livekit` | `<공인IP>` | DNS only (grey) |
| A | `app` | `<공인IP>` | DNS only (grey) |

> `<공인IP>` = OPNsense WAN 공인 IP. 동적 IP라면 OPNsense의 Cloudflare DDNS 플러그인 사용.

---

## 2. OPNsense 포트포워딩 (미디어 TCP 7881)

미디어는 nginx를 거치지 않습니다. **방화벽 NAT 포트포워딩**으로 직접 클러스터로 보냅니다.

`Firewall ▸ NAT ▸ Port Forward` 규칙 추가:

| 항목 | 값 |
|------|----|
| Interface | WAN |
| Protocol | TCP |
| Destination | WAN address |
| Destination port | `7881` |
| Redirect target IP | `<미디어 LB IP>` (Cilium BGP가 `lk-media` svc에 할당한 IP) |
| Redirect target port | `7881` |

> `<미디어 LB IP>`는 `kubectl get svc -n livekit lk-media` 의 `EXTERNAL-IP`.
> 고정하려면 `config/.env`의 `MEDIA_LB_IP`를 BGP 풀 범위 내로 지정하고 `media-lb-service.yaml`에 반영.

연동 방화벽 규칙(자동 생성되지 않으면): WAN에서 `<미디어 LB IP>:7881/TCP` 허용.

---

## 3. Cilium BGP ⇄ OPNsense

Cilium이 LoadBalancer 서비스 IP를 BGP로 OPNsense에 광고하면, OPNsense는 해당 IP로 가는 경로를 학습합니다.

- 이미 BGP peering이 되어 있다고 가정합니다(요구사항). 확인:
  ```bash
  # OPNsense (FRR) 측
  vtysh -c "show bgp ipv4 unicast"      # 미디어/Gateway LB IP가 경로에 보여야 함
  # Cilium 측
  cilium bgp routes advertised ipv4 unicast
  kubectl get svc -A | grep LoadBalancer
  ```
- 포트포워딩 redirect target(`<미디어 LB IP>`)과 nginx upstream(Gateway LB IP)은 **모두 BGP로 광고되는 LoadBalancer IP**입니다. OPNsense가 이 IP들로 라우팅 가능해야 합니다.
- LB IP 풀은 Cilium `CiliumLoadBalancerIPPool`로 정의됩니다. `lk-media` 서비스가 풀에서 IP를 받도록 라벨/annotation을 맞추세요(클러스터 설정에 따라 다름).

---

## 4. NAT reflection (내부 PC 시청 필수)

LiveKit는 ICE 후보로 **공인 IP:7881** 만 광고합니다. 따라서 홈랩 **내부** PC가 영상을 수신할 때도 공인 IP:7881로 접속을 시도합니다. 내부→공인IP 접속이 되려면 OPNsense의 **NAT reflection(헤어핀 NAT)** 이 필요합니다.

`Firewall ▸ Settings ▸ Advanced ▸ Network Address Translation`:
- ☑ Reflection for port forwards (`Enable`)
- ☑ Reflection for 1:1
- ☑ Automatic outbound NAT for Reflection

이렇게 하면 내부 PC가 `공인IP:7881`로 보낸 미디어 TCP가 내부 LB IP로 헤어핀됩니다.

> 대안(헤어핀을 피하고 싶다면): split-horizon DNS로 내부에서는 `livekit`/`app`을 내부 IP로 응답하게 하고, LiveKit에 내부 IP도 ICE 후보로 추가하는 구성이 필요합니다. 데모에서는 NAT reflection이 단순합니다.

---

## 5. 시그널링 / 웹앱 경로 (443)

`443`은 OPNsense nginx proxy 플러그인이 TLS를 종단한 뒤 Cilium Gateway의 LB IP로 프록시합니다. 자세한 설정은 [opnsense-nginx.md](opnsense-nginx.md) 참고.

- `livekit.basphere.dev:443` → nginx → Gateway LB IP → `livekit` svc:7880 (WebSocket 시그널링)
- `app.basphere.dev:443` → nginx → Gateway LB IP → `lk-web` svc:8080 (웹앱/토큰)
- `80` → ACME (기존 OPNsense ACME 구성 유지, `*.basphere.dev` 인증서 갱신)

---

## 포트 요약

| 포트 | 프로토콜 | 외부 노출 | 경로 | 용도 |
|------|----------|-----------|------|------|
| 443 | TCP | ✅ | nginx→Gateway | 시그널링(WSS) + 웹앱(HTTPS) |
| 80 | TCP | ✅ | OPNsense ACME | 인증서 갱신 |
| **7881** | **TCP** | ✅ | **raw 포트포워딩** | **WebRTC 미디어 (ICE/TCP)** |
| 7880 | TCP | ❌ (내부) | Gateway→svc | LiveKit API/시그널링 백엔드 |
| 50000-60000 | UDP | ❌ (비활성) | — | UDP 미디어 (TCP-only이므로 끔) |
