# 녹화 파일 저장용 PVC. egress 파드의 ${RECORDING_PATH} 에 마운트된다.
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: recordings
  namespace: ${K8S_NAMESPACE}
  labels: { app: egress }
spec:
  accessModes:
    - ${RECORDING_PVC_ACCESS_MODE}
  resources:
    requests:
      storage: ${RECORDING_PVC_SIZE}
  ${RECORDING_STORAGE_CLASS_LINE}
