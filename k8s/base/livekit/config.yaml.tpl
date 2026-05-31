# LiveKit server config — render.sh 가 envsubst 로 생성, install.sh 가 Secret(livekit-config)으로 만든다.
# 실행: livekit-server --config /etc/livekit/config.yaml
port: 7880
bind_addresses:
  - ""
rtc:
  # ── TCP-only 미디어 ──
  tcp_port: ${MEDIA_TCP_PORT}
  port_range_start: 0          # UDP 후보 비활성
  port_range_end: 0
  use_external_ip: false
  node_ip: "${PUBLIC_IP}"      # ICE 후보로 광고할 공인 IP
keys:
  ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}
logging:
  level: info
  json: false
# 녹화(Egress) 활성 시 render.sh 가 아래에 redis 블록을 주입한다.
${REDIS_CONFIG_BLOCK}
