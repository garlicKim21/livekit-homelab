# Redis — livekit-server ↔ egress 작업 버스. 녹화(ENABLE_RECORDING=true) 시에만 배포된다.
# 메시지 버스 용도이므로 영속성 불필요(ephemeral).
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: ${K8S_NAMESPACE}
  labels: { app: redis }
spec:
  replicas: 1
  selector:
    matchLabels: { app: redis }
  template:
    metadata:
      labels: { app: redis }
    spec:
      containers:
        - name: redis
          image: ${REDIS_IMAGE}
          args: ["--save", "", "--appendonly", "no"]
          ports:
            - { name: redis, containerPort: 6379 }
          readinessProbe:
            exec: { command: ["redis-cli", "ping"] }
            initialDelaySeconds: 3
            periodSeconds: 10
          resources:
            requests: { cpu: "50m",  memory: 64Mi }
            limits:   { cpu: "500m", memory: 256Mi }
