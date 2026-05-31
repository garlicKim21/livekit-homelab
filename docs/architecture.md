# 아키텍처

## 구성 요소

| 구성요소 | 역할 | 노출 |
|----------|------|------|
| **livekit-server** | WebRTC SFU. 시그널링(7880) + 미디어 ICE/TCP(7881) | 시그널링은 nginx→Gateway, 미디어는 raw 포트포워딩 |
| **redis** | livekit-server ↔ egress 작업 버스 (녹화 활성 시 필수) | 내부 전용 |
| **egress** | 녹화. 발행 스트림을 파일로 저장(로컬 PVC) | 내부 전용 |
| **lk-web** | 토큰 발급 + 녹화 제어 API + publish/view 정적 페이지 | nginx→Gateway (HTTPS) |
| **Cilium Gateway** | HTTP(S) L7 라우팅 (Host 기반 분기) | BGP LoadBalancer IP |
| **media LoadBalancer** | 미디어 TCP 7881 노출 (BGP) | BGP LoadBalancer IP → 포트포워딩 대상 |

> 녹화를 끄면(`ENABLE_RECORDING=false`) redis/egress는 배포되지 않고, livekit-server는 Redis 없이 단독 동작합니다.

## 트래픽 흐름

```
                          ┌─────────────────── 인터넷 ───────────────────┐
   [아이폰 Safari]                                                    [홈랩 내부 PC]
        │  publish                                                      │  view
        │                                                               │
        ▼                                                               ▼
   ① 시그널링  wss://livekit.basphere.dev  (443)              ① 시그널링  (443)
   ② 미디어    공인IP:7881  (TCP)                              ② 미디어   공인IP:7881 (헤어핀/NAT reflection)
        │                                                               │
        └───────────────────────────┬───────────────────────────────────┘
                                     ▼
                       [Cloudflare DNS — DNS only(grey)]
                                     │  공인 IP
                                     ▼
                          ┌──────────────────────┐
                          │   OPNsense (WAN)      │
                          │                       │
       443 ──────────────►│ nginx proxy (TLS종단) │──► Cilium Gateway LB IP :80
                          │                       │        ├─ Host: livekit.* → svc livekit:7880  (WS)
       80  ──────────────►│ ACME (cert 갱신)      │        └─ Host: app.*     → svc lk-web:8080
                          │                       │
       7881 ─────────────►│ NAT 포트포워딩(raw TCP)│──► media LB IP :7881
                          └──────────────────────┘            │
                                  BGP peer                     ▼
                          (Cilium ⇄ OPNsense FRR)        [livekit-server pod]
                                                          node_ip=공인IP → ICE/TCP 후보=공인IP:7881
                                                                │  (녹화 시)
                                                                ▼ redis
                                                          [redis] ◄──► [egress pod] ──► PVC(/out/*.mp4)
```

## 시그널링 vs 미디어 — 경로가 다른 이유

WebRTC 미디어는 **DTLS/SRTP로 암호화된 비-HTTP 트래픽**이라 HTTP/TLS 리버스 프록시(nginx)나 Cloudflare 오렌지 프록시를 통과할 수 없습니다.

- **시그널링(WSS)**: 일반 HTTP/WebSocket → nginx가 TLS 종단 후 Gateway로 프록시 가능.
- **미디어(ICE/TCP)**: nginx를 우회해 OPNsense에서 raw TCP로 포트포워딩. LiveKit가 ICE 후보로 `공인IP:7881`을 광고하고, 클라이언트가 그곳으로 직접 TCP 연결.

## TCP-only 동작 원리

LiveKit 미디어 후보 우선순위: ICE/UDP → TURN/UDP → **ICE/TCP** → TURN/TLS.

`config/.env`/렌더된 LiveKit config에서:
- `rtc.port_range_start: 0`, `rtc.port_range_end: 0` → **UDP 후보 비활성**
- `rtc.tcp_port: 7881` → 모든 미디어가 이 단일 TCP 포트로 mux
- `rtc.use_external_ip: false` + `rtc.node_ip: <공인IP>` → ICE 후보로 공인 IP 광고

결과: 클라이언트는 UDP 후보가 없으므로 **ICE/TCP(공인IP:7881)** 로만 연결. TURN 불필요.

## 포트 요약

| 포트 | 프로토콜 | 외부 | 경로 | 용도 |
|------|----------|------|------|------|
| 443 | TCP | ✅ | nginx→Gateway | 시그널링(WSS) + 웹앱(HTTPS) |
| 80 | TCP | ✅ | OPNsense ACME | 인증서 갱신 |
| **7881** | **TCP** | ✅ | **raw 포트포워딩** | WebRTC 미디어(ICE/TCP) |
| 7880 | TCP | ❌ | Gateway→svc | LiveKit API/시그널링 백엔드 |
| 8080 | TCP | ❌ | Gateway→svc | 웹앱/토큰 |
| 6379 | TCP | ❌ | 내부 | Redis (녹화 시) |
| 50000-60000 | UDP | ❌ 비활성 | — | UDP 미디어 (TCP-only로 끔) |

## 배포 토폴로지 (Kubernetes)

```
namespace: ${K8S_NAMESPACE} (기본 livekit)
├── Deployment  livekit-server   (replicas:1)  ─ Secret(config.yaml) 마운트
│     ├── Service livekit          ClusterIP    7880        (시그널링, Gateway 백엔드)
│     └── Service lk-media         LoadBalancer 7881/TCP    externalTrafficPolicy: Local (BGP)
├── Deployment  redis             (녹화 시)     ─ Service redis ClusterIP 6379
├── Deployment  egress            (녹화 시)     ─ Secret(egress.yaml) + PVC(/out)
├── Deployment  lk-web                          ─ Service lk-web ClusterIP 8080
└── (gateway ns) HTTPRoute x2 → livekit / lk-web
```

자세한 네트워크/OPNsense 설정은 [network.md](network.md), [opnsense-nginx.md](opnsense-nginx.md), 녹화는 [recording.md](recording.md) 참고.
