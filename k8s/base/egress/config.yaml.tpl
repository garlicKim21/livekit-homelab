# Egress config — render.sh 가 envsubst 로 생성, install.sh 가 Secret(egress-config)으로 만든다.
# 스토리지 블록(s3/azure/gcp)이 없으면 출력은 요청에 지정한 로컬 파일 경로(PVC)에 기록된다.
log_level: info
health_port: 8080
prometheus_port: 9090

# livekit-server 와 동일해야 함
api_key: ${LIVEKIT_API_KEY}
api_secret: ${LIVEKIT_API_SECRET}
ws_url: ${LIVEKIT_WS_URL_INTERNAL}
insecure: true            # 클러스터 내부 평문 ws 허용

# livekit-server 와 동일한 Redis
redis:
  address: ${REDIS_ADDRESS}

# 스케줄링 가중치(기본값)
room_composite_cpu_cost: 3.0
web_cpu_cost: 3.0
track_composite_cpu_cost: 2.0
track_cpu_cost: 1.0

# ── 스토리지 ──
# 로컬 PVC 저장이므로 s3/azure/gcp 블록을 두지 않는다.
# 향후 MinIO/S3 전환 시 아래 주석을 해제하고 값을 채운다:
# s3:
#   access_key: ${S3_ACCESS_KEY}
#   secret: ${S3_SECRET}
#   region: ${S3_REGION}
#   endpoint: ${S3_ENDPOINT}      # MinIO 예: http://minio.minio.svc:9000
#   bucket: ${S3_BUCKET}
#   force_path_style: true
