// 런타임 설정 로드 + livekit-client SDK 를 CDN 에서 동적 로드 (빌드 단계 없음)
export async function loadConfig() {
  const res = await fetch('/api/config');
  if (!res.ok) throw new Error('config 로드 실패');
  return res.json();
}

export async function loadSdk(version) {
  if (window.LivekitClient) return window.LivekitClient;
  await new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = `https://cdn.jsdelivr.net/npm/livekit-client@${version}/dist/livekit-client.umd.min.js`;
    s.onload = resolve;
    s.onerror = () => reject(new Error('livekit-client SDK 로드 실패'));
    document.head.appendChild(s);
  });
  return window.LivekitClient;
}

export async function getToken({ room, identity, role }) {
  const q = new URLSearchParams({ room, identity, role });
  const res = await fetch(`/api/token?${q}`);
  if (!res.ok) throw new Error('토큰 발급 실패');
  return res.json(); // { token, wsUrl, room, identity }
}

export function logTo(el) {
  return (msg) => {
    const line = typeof msg === 'string' ? msg : JSON.stringify(msg);
    el.textContent = `${new Date().toLocaleTimeString()}  ${line}\n` + el.textContent;
    console.log(msg);
  };
}
