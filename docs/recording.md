# 녹화 (LiveKit Egress)

발행 중인 영상+오디오 스트림을 실시간으로 녹화해 **로컬 PVC**에 `.mp4`로 저장합니다.

## 핵심 사실

- **Egress는 별도 서비스**입니다. livekit-server와 **Redis로만** 통신하므로, 녹화를 켜면 Redis 배포가 **필수**입니다. server/egress가 같은 Redis(`${REDIS_ADDRESS}`)를 바라봐야 합니다.
- **S3는 필수가 아닙니다.** 본 프로젝트는 **로컬 PVC**(`${RECORDING_PATH}`, 기본 `/out`)에 저장합니다. egress 설정에 스토리지 백엔드를 두지 않으면 파일 출력 경로(PVC)에 그대로 기록됩니다.
- 단일 영상+오디오 스트림 녹화는 **Participant Egress** 를 사용합니다 → 헤드리스 Chrome 불필요, 가볍습니다.

## 컴퓨팅 사양 (공식 가이드 기반)

| 방식 | Chrome | CPU/메모리(인스턴스당) | 동시 처리 |
|------|--------|------------------------|-----------|
| **Participant / Track Composite** | ❌ | 베이스라인 ~**4 CPU / 4 GB** | 여러 개 가능 |
| Track (raw, 무변환) | ❌ | 매우 적음 | 수백 개 |
| **Room Composite / Web** | ✅ | **2~6 CPU / 4 GB+**, `/dev/shm` 필요 | 인스턴스당 방 1개 |

- 본 데모(Participant Egress)는 `EGRESS_CPU=4`, `EGRESS_MEMORY=4Gi`(`.env`)로 설정됩니다.
- Room Composite로 바꾸려면 CPU를 6 이상으로 올리고 `/dev/shm`(EGRESS_SHM_SIZE) 메모리가 필요합니다. 인스턴스당 동시 1개 방만 녹화되므로, 여러 방을 동시에 녹화하려면 replica를 늘리거나 오토스케일링이 필요합니다.
- egress 파드는 진행 중 녹화를 완료(flush)하기 위해 `terminationGracePeriodSeconds: 3600` 으로 설정되어 있습니다.

## 로컬 PVC 저장 — 주의사항

- 파일은 **egress 파드의 PVC 내부**(`${RECORDING_PATH}`)에 저장됩니다. 녹화 진행 중 파드가 죽으면 해당 파일은 유실됩니다.
- 기본 접근모드는 `ReadWriteOnce`(`RECORDING_PVC_ACCESS_MODE`). 여러 파드/외부에서 파일을 함께 보려면 `ReadWriteMany`(NFS/Longhorn 등)로 바꾸세요.
- 파일 꺼내기:
  ```bash
  # 녹화된 파일 목록
  kubectl exec -n ${K8S_NAMESPACE} deploy/egress -- ls -lh ${RECORDING_PATH}
  # 로컬로 복사
  kubectl cp ${K8S_NAMESPACE}/<egress-pod>:${RECORDING_PATH}/<file>.mp4 ./<file>.mp4
  ```
- 향후 S3/MinIO로 전환하려면 egress 설정(`k8s/base/egress/secret.yaml.tpl`)에 `s3:` 블록을 추가하고 녹화 요청의 출력 대상을 S3로 바꾸면 됩니다(코드에 주석으로 표시).

## 녹화 시작/중지

웹앱(`lk-web`)의 토큰 서버가 Egress 제어 API를 노출합니다. `view.html` 화면의 **녹화 시작/중지** 버튼으로 호출하거나 직접 호출할 수 있습니다.

```bash
# 시작 — 특정 참가자(identity)를 녹화
curl -X POST https://${APP_HOST}/api/record/start \
  -H 'content-type: application/json' \
  -d '{"room":"demo-room","identity":"phone-user"}'
# → {"egressId":"EG_xxx"}

# 중지
curl -X POST https://${APP_HOST}/api/record/stop \
  -H 'content-type: application/json' \
  -d '{"egressId":"EG_xxx"}'
```

내부적으로 `livekit-server-sdk`의 `EgressClient.startParticipantEgress()`를 호출하며, 출력은 `EncodedFileOutput`(로컬 파일)로 설정됩니다(`app/server.js` 참고).

### lk CLI 로 직접 (디버그)

```bash
# scripts/gen-token.sh 로 토큰 발급 후
lk egress start-participant-egress \
  --room ${DEFAULT_ROOM} --identity phone-user \
  --output-file ${RECORDING_PATH}/{room_name}-{publisher_identity}-{time}.mp4

lk egress list
lk egress stop --id <EGRESS_ID>
```

## 녹화 끄기

`config/.env`에서 `ENABLE_RECORDING=false` 로 두고 `render.sh`/`install.sh`를 다시 실행하면 redis/egress가 제외되고, livekit-server는 Redis 없이 단독 동작합니다.
