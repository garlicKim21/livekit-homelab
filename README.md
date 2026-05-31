# livekit-homelab

홈랩 Kubernetes에 **LiveKit**(자체호스팅 WebRTC SFU)을 배포하여, 아이폰(인터넷)에서 카메라 영상을 **WebRTC over TCP**로 송출하고 홈랩 내부 PC 브라우저에서 시청하는 테스트 환경입니다.

설정·아키텍처·설치 절차를 모두 코드화했습니다.

## 무엇을 하나

- 📱 **아이폰 Safari** → `https://app.basphere.dev/publish.html` 접속 → 카메라 송출 (publisher)
- 💻 **홈랩 PC 브라우저** → `https://app.basphere.dev/view.html` 접속 → 실시간 시청 (subscriber)
- 🔒 미디어는 **TCP 단일 포트(7881)** 만 사용 (UDP 비활성). 시그널링은 WSS 443.

## 아키텍처 한눈에

```
[아이폰 Safari] ──인터넷──> [Cloudflare DNS] ──> [OPNsense WAN(공인IP)]
                                                   ├─ 443  → nginx(TLS종단) → Cilium Gateway → livekit:7880 (시그널링 WSS)
                                                   │                                         └→ lk-web:8080  (웹앱 HTTPS)
                                                   └─ 7881 → (raw TCP 포트포워딩) → BGP LB IP → livekit pod (미디어 ICE/TCP)

[홈랩 PC] ── 동일 경로 (미디어는 NAT reflection/헤어핀 필요) ──>
```

자세한 내용: [docs/architecture.md](docs/architecture.md)

### 왜 미디어를 따로 노출하나?

WebRTC 미디어(DTLS/SRTP)는 HTTP/TLS 리버스 프록시나 Cloudflare 오렌지 프록시를 통과할 수 없습니다. 따라서 시그널링(WSS 443)은 nginx→Gateway로 가지만, **미디어 TCP 7881은 OPNsense에서 raw로 포트포워딩**해야 합니다. LiveKit는 ICE 후보로 `공인IP:7881`을 광고하고 클라이언트가 그곳으로 직접 TCP 연결합니다.

## 디렉토리 구조

```
.
├── docs/        아키텍처·네트워크·OPNsense nginx·트러블슈팅 문서
├── k8s/
│   ├── livekit/   LiveKit helm values + 미디어 LoadBalancer + secret 예시
│   ├── gateway/   시그널링/웹앱 HTTPRoute (+ Gateway 참고)
│   └── app/       웹앱 Deployment/Service/ConfigMap
├── app/         웹앱 (토큰 발급 서버 + publish/view 정적 페이지)
├── scripts/     install / uninstall / gen-token
└── config/      .env.example (배포 변수 템플릿)
```

## 사전 요구사항

- 홈랩 Kubernetes 클러스터 (Cilium BGP LoadBalancer, Gateway API 설치됨)
- OPNsense (BGP peer, nginx proxy 플러그인으로 `*.basphere.dev` TLS 종단)
- 로컬 도구: `kubectl`, `envsubst`(gettext) **또는** `perl`(템플릿 렌더), 웹앱 이미지 빌드용 `docker`/`nerdctl`, (선택) `lk` LiveKit CLI
  - **Helm 불필요** — 모든 리소스를 raw YAML 템플릿으로 배포합니다.
- Cloudflare DNS: `livekit.basphere.dev`, `app.basphere.dev` → OPNsense 공인 IP (**DNS-only / grey cloud**)

## 빠른 시작

```bash
# 1) 변수 채우기 (도메인/IP/키/버전 등 모두 변수화되어 있음)
cp config/.env.example config/.env
$EDITOR config/.env        # PUBLIC_IP, API key/secret, Gateway 이름, APP_IMAGE 등

# 2) 웹앱 이미지 빌드/푸시 (APP_IMAGE 레지스트리로)
./scripts/build-push.sh

# 3) 렌더 + 배포 (envsubst/perl 로 .tpl 치환 후 kubectl apply)
./scripts/install.sh
#    렌더만 미리 보려면:  ./scripts/render.sh  (→ rendered/ 확인)

# 4) OPNsense 설정 (수동)
#    - DNS: livekit./app.basphere.dev → 공인 IP (grey cloud)
#    - nginx proxy: 443 → Cilium Gateway LB IP  (docs/opnsense-nginx.md)
#    - 포트포워딩: 공인IP:7881 → 미디어 LB IP(kubectl get svc -n livekit lk-media):7881 (raw TCP)
#    - NAT reflection 활성화 (내부 PC 시청용)

# 5) 테스트
#    아이폰 Safari → https://app.basphere.dev/publish.html   (카메라 송출)
#    PC 브라우저  → https://app.basphere.dev/view.html        (시청 + 녹화 버튼)
```

- 변수화/배포 방식: envsubst 템플릿(`k8s/base/**/*.yaml.tpl` + `config/.env`). 향후 Kustomize 전환은 [docs/kustomize-migration.md](docs/kustomize-migration.md).
- 녹화(Egress) 사용/사양: [docs/recording.md](docs/recording.md). 끄려면 `.env` 의 `ENABLE_RECORDING=false`.
- 배포 시 치환할 값과 수동 설정은 [docs/network.md](docs/network.md), [docs/opnsense-nginx.md](docs/opnsense-nginx.md) 참고.

## 문서

| 문서 | 내용 |
|------|------|
| [docs/architecture.md](docs/architecture.md) | 전체 아키텍처, 트래픽 흐름, 포트표 |
| [docs/network.md](docs/network.md) | Cloudflare DNS, OPNsense 포트포워딩/BGP, NAT reflection |
| [docs/opnsense-nginx.md](docs/opnsense-nginx.md) | nginx proxy 플러그인 (WSS upgrade) 설정 |
| [docs/recording.md](docs/recording.md) | 녹화(Egress) 사용법·컴퓨팅 사양·로컬 PVC 저장 |
| [docs/kustomize-migration.md](docs/kustomize-migration.md) | envsubst → Kustomize 전환 가이드 |
| [docs/troubleshooting.md](docs/troubleshooting.md) | ICE 실패, TCP 후보 확인, 디버깅 |

## 라이선스

테스트/학습용. LiveKit은 Apache-2.0.
