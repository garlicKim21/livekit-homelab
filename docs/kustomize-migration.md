# Kustomize 전환 가이드

현재 배포는 **envsubst 템플릿**(`k8s/base/**/*.yaml.tpl` + `config/.env` + `scripts/render.sh`)을 사용합니다.
회사 환경에서 GitOps/Kustomize로 전환하기 쉽도록 구조를 미리 정리해 두었습니다.

## 지금 구조가 Kustomize 친화적인 이유

- 리소스가 **컴포넌트별 폴더**(`livekit/`, `redis/`, `egress/`, `app/`, `gateway/`)로 분리되어 있어 그대로 `resources:` 목록이 됩니다.
- 각 템플릿은 **표준 YAML + `${VAR}` 치환**만 사용합니다(커스텀 문법 없음). 변수를 제거하고 고정값/`replacements`로 바꾸기 쉽습니다.
- 시크릿성 값(키, config)은 별도 파일로 격리되어 있어 `secretGenerator`로 옮기기 쉽습니다.

## 전환 절차 (권장)

1. **base 만들기**: `.yaml.tpl`에서 `${VAR}`를 제거하고, 환경 무관한 기본값으로 고정한 순수 YAML을 `k8s/base/`에 둡니다. 각 폴더에 `kustomization.yaml` 추가:
   ```yaml
   # k8s/base/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   namespace: livekit
   resources:
     - namespace.yaml
     - livekit/
     - redis/
     - egress/
     - app/
   ```

2. **환경별 overlay**: `k8s/overlays/homelab/`, `k8s/overlays/company/` 를 만들고 환경 차이만 patch.
   ```yaml
   # k8s/overlays/homelab/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources: [../../base]
   images:
     - name: livekit/livekit-server
       newTag: v1.12.0
   configMapGenerator:
     - name: lk-web-env
       literals: [LIVEKIT_WS_URL=wss://livekit.basphere.dev]
   secretGenerator:
     - name: livekit-config
       files: [config.yaml=secrets/livekit-config.yaml]
   patches:
     - path: patch-node-ip.yaml      # rtc.node_ip = 공인 IP 등 환경값
   ```

3. **변수 매핑**: 현재 `.env` 변수 → Kustomize 처리 방식
   | `.env` 변수 | Kustomize 처리 |
   |-------------|----------------|
   | `*_IMAGE` (태그) | `images:` |
   | `K8S_NAMESPACE` | `namespace:` |
   | `LIVEKIT_HOST`/`APP_HOST` | HTTPRoute patch 또는 `replacements` |
   | `PUBLIC_IP`(node_ip) | config Secret(`secretGenerator`) + patch |
   | `LIVEKIT_API_KEY/SECRET` | `secretGenerator` |
   | `MEDIA_LB_IP` | Service patch |
   | replica/resources | overlay patch |

4. **민감값**: `${LIVEKIT_API_SECRET}` 등은 `secretGenerator` + SOPS/sealed-secrets로 관리(평문 커밋 금지).

## 점진적 접근

전부 한 번에 옮길 필요는 없습니다. 이미지 태그와 네임스페이스처럼 Kustomize가 잘 다루는 항목부터 overlay로 빼고, 도메인/IP 같은 텍스트 치환은 `replacements`로 단계적으로 이전하면 됩니다. 그동안 envsubst 경로(`scripts/render.sh`)는 그대로 동작합니다.
