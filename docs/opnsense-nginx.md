# OPNsense nginx proxy 설정 (시그널링/웹앱 TLS 종단)

OPNsense nginx proxy 플러그인이 `443`에서 `*.basphere.dev` 와일드카드 인증서로 TLS를 종단하고, 평문 HTTP/WS로 Cilium Gateway(`172.16.200.1:80`)에 프록시합니다. 기존 `grafana/hubble/headlamp/...` vhost가 이미 같은 게이트웨이로 가고 있으므로 **동일 패턴에 호스트만 추가**하면 됩니다.

> ⚠️ 이 nginx는 **시그널링(WSS)·웹앱(HTTPS)** 만 처리합니다. **미디어 TCP 7881은 절대 nginx에 통과시키지 마세요** — raw 포트포워딩만 사용([network.md](network.md)).

치환 변수:
- `${LIVEKIT_HOST}` = `livekit.basphere.dev`
- `${APP_HOST}` = `app.basphere.dev`
- Gateway LB IP = `172.16.200.1` (`kubectl get gateway -n gateway-system shared-gateway`)

---

## GUI 설정 (Nginx 플러그인)

`Services ▸ Nginx`

1. **Upstream**: 서버 `172.16.200.1`, 포트 `80` (기존 grafana용 upstream 재사용 가능)
2. **HTTP Server (vhost)** 추가 — livekit 용 (WebSocket + 긴 timeout 중요):
   - Server Name: `livekit.basphere.dev`
   - TLS Certificate: `*.basphere.dev` (ACME)
   - Upstream: 위 Gateway upstream
   - **WebSocket: 체크** / proxy read timeout 크게(3600s)
3. **HTTP Server (vhost)** 추가 — app 용:
   - Server Name: `app.basphere.dev`, 나머지 동일

---

## 동등한 nginx 설정 (참고 / 검증용)

```nginx
# ─ LiveKit 시그널링 (WSS) ─
server {
    listen 443 ssl;
    server_name livekit.basphere.dev;
    # ssl_certificate ... *.basphere.dev

    location / {
        proxy_pass http://172.16.200.1:80;        # Cilium shared-gateway

        # WebSocket 업그레이드 (시그널링 필수)
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host              $host;     # HTTPRoute 가 Host 로 분기 → 보존 필수
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout  3600s;   # 장수명 WebSocket 유지
        proxy_send_timeout  3600s;
        proxy_buffering     off;     # 실시간
    }
}

# ─ 웹앱 (HTTPS) ─
server {
    listen 443 ssl;
    server_name app.basphere.dev;
    location / {
        proxy_pass http://172.16.200.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host              $host;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

> Gateway HTTPRoute가 `Host`(`livekit.*`/`app.*`)로 백엔드를 분기하므로 nginx가 원본 `Host`를 보존(`proxy_set_header Host $host`)해야 합니다.

---

## 검증

```bash
curl -sI https://livekit.basphere.dev      # TLS OK
curl -sI https://app.basphere.dev          # 200
```

업그레이드 헤더가 빠지면 시그널링이 `101 Switching Protocols`로 전환되지 못해 실패합니다.
