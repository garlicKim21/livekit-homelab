// LiveKit 홈랩 데모 - 토큰 발급 + 녹화(Egress) 제어 + 정적 페이지 서빙
import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  AccessToken,
  EgressClient,
  EncodedFileOutput,
} from 'livekit-server-sdk';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── 환경변수 (k8s configmap/secret 으로 주입) ──
const {
  LIVEKIT_API_KEY,
  LIVEKIT_API_SECRET,
  // 브라우저가 시그널링에 쓸 공개 WSS URL (예: wss://livekit.basphere.dev)
  LIVEKIT_WS_URL,
  // 토큰서버가 Egress API 호출에 쓸 내부 URL (예: http://livekit.livekit.svc:7880)
  LIVEKIT_API_URL_INTERNAL,
  // 프론트엔드가 CDN 에서 불러올 client SDK 버전
  LIVEKIT_CLIENT_VERSION = '2.19.1',
  // 녹화 파일 저장 경로 (egress 파드의 PVC 마운트 경로와 동일)
  RECORDING_PATH = '/out',
  ENABLE_RECORDING = 'true',
  DEFAULT_ROOM = 'demo-room',
  PORT = '8080',
} = process.env;

if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
  console.error('LIVEKIT_API_KEY / LIVEKIT_API_SECRET 가 필요합니다.');
  process.exit(1);
}

const recordingEnabled = ENABLE_RECORDING === 'true';
const egress = recordingEnabled
  ? new EgressClient(LIVEKIT_API_URL_INTERNAL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
  : null;

const app = express();
app.use(express.json());

// 프론트엔드 런타임 설정 노출 (도메인/버전 등을 빌드 없이 주입)
app.get('/api/config', (_req, res) => {
  res.json({
    wsUrl: LIVEKIT_WS_URL,
    clientVersion: LIVEKIT_CLIENT_VERSION,
    defaultRoom: DEFAULT_ROOM,
    recordingEnabled,
  });
});

// 액세스 토큰 발급
//   GET /api/token?room=demo-room&identity=phone-user&role=publisher|viewer
app.get('/api/token', async (req, res) => {
  try {
    const room = String(req.query.room || DEFAULT_ROOM);
    const identity = String(req.query.identity || `user-${Date.now()}`);
    const role = String(req.query.role || 'viewer');
    const canPublish = role === 'publisher';

    const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
      identity,
      ttl: '6h',
    });
    at.addGrant({
      room,
      roomJoin: true,
      canPublish,
      canSubscribe: true,
      canPublishData: true,
      // 녹화 트리거 권한 (viewer 화면의 녹화 버튼용)
      roomRecord: recordingEnabled,
    });
    res.json({ token: await at.toJwt(), wsUrl: LIVEKIT_WS_URL, room, identity });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// 녹화 시작 — 특정 참가자(identity)를 로컬 파일로 저장
//   POST /api/record/start { room, identity }
app.post('/api/record/start', async (req, res) => {
  if (!egress) return res.status(400).json({ error: 'recording disabled' });
  try {
    const { room = DEFAULT_ROOM, identity } = req.body || {};
    if (!identity) return res.status(400).json({ error: 'identity required' });

    // 로컬 파일 출력 (스토리지 백엔드 미설정 → egress PVC 에 기록)
    // S3/MinIO 전환 시: EncodedFileOutput 의 output 에 S3Upload 를 지정하면 됨.
    const fileOutput = new EncodedFileOutput({
      filepath: `${RECORDING_PATH}/{room_name}-{publisher_identity}-{time}.mp4`,
    });

    const info = await egress.startParticipantEgress(room, identity, {
      file: fileOutput,
    });
    res.json({ egressId: info.egressId, status: info.status });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// 녹화 중지
//   POST /api/record/stop { egressId }
app.post('/api/record/stop', async (req, res) => {
  if (!egress) return res.status(400).json({ error: 'recording disabled' });
  try {
    const { egressId } = req.body || {};
    if (!egressId) return res.status(400).json({ error: 'egressId required' });
    const info = await egress.stopEgress(egressId);
    res.json({ egressId: info.egressId, status: info.status });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// 진행 중 녹화 목록
app.get('/api/record/list', async (_req, res) => {
  if (!egress) return res.json({ items: [] });
  try {
    const items = await egress.listEgress({ active: true });
    res.json({ items: items.map((i) => ({ egressId: i.egressId, status: i.status, roomName: i.roomName })) });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

app.get('/healthz', (_req, res) => res.send('ok'));

// 정적 페이지
app.use(express.static(path.join(__dirname, 'public')));

app.listen(Number(PORT), () => {
  console.log(`lk-web listening on :${PORT}  (recording=${recordingEnabled})`);
});
