apiVersion: apps/v1
kind: Deployment
metadata:
  name: lk-web
  namespace: ${K8S_NAMESPACE}
  labels: { app: lk-web }
spec:
  replicas: 1
  selector:
    matchLabels: { app: lk-web }
  template:
    metadata:
      labels: { app: lk-web }
    spec:
      enableServiceLinks: false
      containers:
        - name: lk-web
          image: ${APP_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - { name: http, containerPort: 8080 }
          envFrom:
            - configMapRef: { name: lk-web-env }
          env:
            # API 키/시크릿은 livekit 과 동일한 Secret 에서 주입
            - name: LIVEKIT_API_KEY
              valueFrom: { secretKeyRef: { name: lk-web-secret, key: LIVEKIT_API_KEY } }
            - name: LIVEKIT_API_SECRET
              valueFrom: { secretKeyRef: { name: lk-web-secret, key: LIVEKIT_API_SECRET } }
            - name: APP_PASSWORD
              valueFrom: { secretKeyRef: { name: lk-web-secret, key: APP_PASSWORD } }
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 10
          resources:
            requests: { cpu: "50m",  memory: 64Mi }
            limits:   { cpu: "500m", memory: 256Mi }
