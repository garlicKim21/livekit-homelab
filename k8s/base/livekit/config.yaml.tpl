# LiveKit server config — render.sh 가 envsubst 로 생성, install.sh 가 Secret(livekit-config)으로 만든다.
# 실행: livekit-server --config /etc/livekit/config.yaml
port: 7880
bind_addresses:
  - ""
rtc:
  # ── TCP-only 미디어 ──
  # LiveKit 은 UDP 를 완전히 끄는 옵션이 없다. TCP-only 는 "TCP 포트만 외부 노출"로 강제한다.
  # tcp_port(7881)만 OPNsense 포트포워딩하고, UDP mux(7882)는 외부 노출하지 않는다.
  # → 외부 클라는 UDP 후보(공인IP:7882)에 도달 못 해 자동으로 TCP(공인IP:7881)를 사용.
  tcp_port: ${MEDIA_TCP_PORT}
  udp_port: 7882               # 단일 UDP mux. 외부 포트포워딩 안 함(내부 전용).
  use_external_ip: false
  node_ip: "${PUBLIC_IP}"      # ICE 후보로 광고할 공인 IP
keys:
  ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}
logging:
  level: info
  json: false
# 녹화(Egress) 활성 시 render.sh 가 아래에 redis 블록을 주입한다.
${REDIS_CONFIG_BLOCK}
