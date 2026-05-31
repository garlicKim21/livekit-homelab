# OPNsense nginx proxy 설정 (시그널링/웹앱 TLS 종단)

OPNsense의 **nginx proxy 플러그인**이 `443`에서 `*.basphere.dev` 와일드카드 인증서로 TLS를 종단하고, 평문 HTTP/WS로 Cilium Gateway의 LoadBalancer IP에 프록시합니다.

> ⚠️ 이 nginx는 **시그널링(WSS)과 웹앱(HTTPS)** 만 처리합니다.
> **미디어 TCP 7881은 절대 nginx에 통과시키지 마세요** — raw 포트포워딩만 사용합니다([network.md](network.md)).

치환 변수(배포 시 `config/.env` 값 사용):
- `${LIVEKIT_HOST}` = `livekit.basphere.dev`
- `${APP_HOST}` = `app.basphere.dev`
- `<GATEWAY_LB_IP>` = Cilium Gateway의 LoadBalancer IP (`kubectl get gateway -n ${GATEWAY_NAMESPACE}`)

---

## GUI 설정 (nginx proxy 플러그인)

`Services ▸ Nginx`

### 1. Upstream
두 호스트 모두 동일 Gateway LB IP로 향하므로 Upstream 하나로 공유 가능합니다.

- **Upstream Server**: `<GATEWAY_LB_IP>`, 포트 `80` (Gateway HTTP listener)
- **Upstream**: 위 서버를 멤버로 추가

### 2. Location
WebSocket 업그레이드를 위해 location에 아래를 설정합니다(플러그인의 "Advanced" 또는 커스텀 설정 사용).

### 3. HTTP Server (가상 호스트) — 2개
| 항목 | livekit | app |
|------|---------|-----|
| Server Name | `${LIVEKIT_HOST}` | `${APP_HOST}` |
| HTTPS only | ✅ | ✅ |
| TLS Certificate | `*.basphere.dev` (ACME) | `*.basphere.dev` (ACME) |
| Upstream | 위 Upstream | 위 Upstream |
| WebSocket | ✅ (필수) | 권장 |

플러그인이 노출하지 않는 항목은 아래 커스텀 nginx 설정과 동일한 효과를 내도록 맞추면 됩니다.

---

## 동등한 nginx 설정 (참고 / 커스텀)

플러그인 대신 직접 nginx를 쓰거나 동작을 검증할 때 참고하세요. **WebSocket upgrade 헤더와 긴 read timeout이 핵심**입니다.

```nginx
# ─ LiveKit 시그널링 (WSS) ─
server {
    listen 443 ssl;
    server_name ${LIVEKIT_HOST};

    ssl_certificate     /var/etc/acme-client/.../fullchain.pem;   # *.basphere.dev
    ssl_certificate_key /var/etc/acme-client/.../privkey.pem;

    location / {
        proxy_pass http://<GATEWAY_LB_IP>:80;

        # WebSocket 업그레이드 (LiveKit 시그널링 필수)
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 장수명 WebSocket 유지
        proxy_read_timeout  36000s;
        proxy_send_timeout  36000s;
    }
}

# ─ 웹앱 (HTTPS) ─
server {
    listen 443 ssl;
    server_name ${APP_HOST};

    ssl_certificate     /var/etc/acme-client/.../fullchain.pem;
    ssl_certificate_key /var/etc/acme-client/.../privkey.pem;

    location / {
        proxy_pass http://<GATEWAY_LB_IP>:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;   # 토큰 서버가 WS를 쓰지 않더라도 무해
        proxy_set_header Connection "upgrade";
        proxy_set_header Host              $host;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

> Gateway 측 HTTPRoute가 `Host` 헤더(`${LIVEKIT_HOST}`, `${APP_HOST}`)로 분기하므로, nginx가 원본 `Host`를 보존(`proxy_set_header Host $host`)하는 것이 중요합니다.

---

## 검증

```bash
# TLS + WebSocket 업그레이드 확인
curl -sI https://${LIVEKIT_HOST}            # 200/426, TLS OK
wscat -c wss://${LIVEKIT_HOST}/rtc          # (wscat 설치 시) 연결 시도

# 웹앱
curl -sI https://${APP_HOST}                # 200
```

LiveKit 클라이언트는 시그널링에 `wss://${LIVEKIT_HOST}` 를 사용합니다. 업그레이드 헤더가 빠지면 연결이 `101 Switching Protocols`로 전환되지 못하고 실패합니다.
