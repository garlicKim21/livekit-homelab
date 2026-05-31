apiVersion: apps/v1
kind: Deployment
metadata:
  name: livekit-server
  namespace: ${K8S_NAMESPACE}
  labels: { app: livekit-server }
spec:
  replicas: 1
  selector:
    matchLabels: { app: livekit-server }
  template:
    metadata:
      labels: { app: livekit-server }
      annotations:
        # config 변경 시 롤아웃되도록 install.sh 가 해시를 패치할 수 있음
        checksum/config: "render-time"
    spec:
      containers:
        - name: livekit-server
          image: ${LIVEKIT_SERVER_IMAGE}
          imagePullPolicy: IfNotPresent
          args: ["--config", "/etc/livekit/config.yaml"]
          ports:
            - { name: signaling, containerPort: 7880, protocol: TCP }
            - { name: rtc-tcp,   containerPort: ${MEDIA_TCP_PORT}, protocol: TCP }
          volumeMounts:
            - { name: config, mountPath: /etc/livekit, readOnly: true }
          readinessProbe:
            httpGet: { path: /, port: 7880 }
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests: { cpu: "250m", memory: 256Mi }
            limits:   { cpu: "2",    memory: 1Gi }
      volumes:
        - name: config
          secret:
            secretName: livekit-config
