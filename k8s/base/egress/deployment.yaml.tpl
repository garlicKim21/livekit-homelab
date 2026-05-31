# LiveKit Egress — 녹화 워커. Redis 로 livekit-server 와 통신한다.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: egress
  namespace: ${K8S_NAMESPACE}
  labels: { app: egress }
spec:
  replicas: 1
  selector:
    matchLabels: { app: egress }
  template:
    metadata:
      labels: { app: egress }
    spec:
      enableServiceLinks: false
      # egress 는 uid 1001 로 실행 → PVC(/out, 기본 root:root)에 쓰도록 fsGroup 부여
      securityContext:
        fsGroup: 1001
      # 진행 중인 녹화를 flush 할 시간 확보
      terminationGracePeriodSeconds: 3600
      containers:
        - name: egress
          image: ${EGRESS_IMAGE}
          imagePullPolicy: IfNotPresent
          # 컨테이너 내 Chrome 샌드박스 비활성 (Room Composite/Web 사용 시)
          env:
            - { name: EGRESS_CONFIG_FILE, value: /etc/egress/config.yaml }
          ports:
            - { name: health,  containerPort: 8080 }
            - { name: metrics, containerPort: 9090 }
          securityContext:
            # Chrome 기반 egress 에 필요할 수 있음 (Participant/Track 전용이면 불필요)
            seccompProfile: { type: Unconfined }
          volumeMounts:
            - { name: config,      mountPath: /etc/egress, readOnly: true }
            - { name: recordings,  mountPath: ${RECORDING_PATH} }
            - { name: dshm,        mountPath: /dev/shm }
          resources:
            # request 는 스케줄 기준(노드 allocatable 내에 맞춰야 함), limit 은 버스트 상한
            requests: { cpu: "${EGRESS_CPU_REQUEST}", memory: ${EGRESS_MEM_REQUEST} }
            limits:   { cpu: "${EGRESS_CPU}",         memory: ${EGRESS_MEMORY} }
      volumes:
        - name: config
          secret: { secretName: egress-config }
        - name: recordings
          persistentVolumeClaim: { claimName: recordings }
        - name: dshm
          emptyDir: { medium: Memory, sizeLimit: ${EGRESS_SHM_SIZE} }
