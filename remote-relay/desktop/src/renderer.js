const host = location.hostname || '192.168.0.107';
const WS_URL = `ws://${host}:8080/ws`;
const logEl = document.getElementById('log');
const listEl = document.getElementById('deviceList');
const canvas = document.getElementById('view');
const ctx = canvas.getContext('2d');
const statusEl = document.getElementById('connStatus');

let ws = null;
let devices = {};
let activeId = null;
let checkedIds = new Set();
let currentFrame = null;

function log(msg) {
  const line = `[${new Date().toLocaleTimeString()}] ${msg}`;
  logEl.textContent = line + '\n' + logEl.textContent.slice(0, 2000);
}

function connect() {
  log(`正在连接 ${WS_URL}`);
  ws = new WebSocket(WS_URL);
  ws.onopen = () => {
    statusEl.textContent = '已连接';
    statusEl.className = 'status connected';
    log('WebSocket 已连接');
    send({ type: 'subscribe', ids: [] });
  };
  ws.onclose = () => {
    statusEl.textContent = '已断开，5秒后重连';
    statusEl.className = 'status disconnected';
    log('WebSocket 断开，5秒后重连');
    setTimeout(connect, 5000);
  };
  ws.onerror = (e) => log('WebSocket 错误');
  ws.onmessage = (ev) => {
    let msg;
    try {
      msg = JSON.parse(ev.data);
    } catch (err) {
      log('收到非 JSON 消息: ' + String(ev.data).slice(0, 80));
      return;
    }
    log('收到 ' + msg.type + (msg.id ? ' id=' + msg.id : '') + (msg.list ? ' count=' + msg.list.length : ''));
    if (msg.type === 'devices') handleDevices(msg.list);
    else if (msg.type === 'frame') handleFrame(msg);
    else if (msg.type === 'registered') log(`设备注册成功: ${msg.id}`);
    else if (msg.type === 'error') log('服务器错误: ' + msg.msg);
  };
}

function send(obj) {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
}

function handleDevices(list) {
  devices = {};
  list.forEach(d => devices[d.id] = d);
  // 首次有设备上线且未选中时，自动选中第一个
  if (!activeId && list.length > 0 && checkedIds.size === 0) {
    activeId = list[0].id;
    checkedIds.add(activeId);
  }
  renderList();
  // 自动订阅所有设备
  send({ type: 'subscribe', ids: list.map(d => d.id) });
}

function renderList() {
  listEl.innerHTML = '';
  const list = Object.values(devices);
  if (list.length === 0) {
    listEl.innerHTML = '<div class="empty-tip">暂无在线设备</div>';
    return;
  }
  list.forEach(d => {
    const el = document.createElement('div');
    el.className = 'deviceItem' + (activeId === d.id ? ' active' : '');
    const checked = checkedIds.has(d.id) ? 'checked' : '';
    el.innerHTML = `
      <input type="checkbox" ${checked}>
      <div class="info">
        <div class="name">${d.model}</div>
        <div class="res">${d.width}x${d.height}</div>
      </div>
    `;
    const cb = el.querySelector('input');
    cb.addEventListener('change', (e) => {
      if (e.target.checked) checkedIds.add(d.id);
      else checkedIds.delete(d.id);
      if (checkedIds.size === 1) activeId = Array.from(checkedIds)[0];
      else activeId = null;
      renderList();
    });
    el.addEventListener('click', (e) => {
      if (e.target.tagName === 'INPUT') return;
      activeId = d.id;
      checkedIds.clear();
      checkedIds.add(d.id);
      renderList();
    });
    listEl.appendChild(el);
  });
}

function handleFrame(msg) {
  if (!devices[msg.id]) return;
  currentFrame = msg;
  const img = new Image();
  img.onload = () => {
    canvas.width = msg.w;
    canvas.height = msg.h;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, 0, 0);
  };
  img.src = 'data:image/jpeg;base64,' + msg.img;
}

// 坐标换算
function toDeviceCoords(e) {
  const rect = canvas.getBoundingClientRect();
  const sx = canvas.width / rect.width;
  const sy = canvas.height / rect.height;
  return {
    x: Math.round((e.clientX - rect.left) * sx),
    y: Math.round((e.clientY - rect.top) * sy),
  };
}

function getTargets() {
  if (checkedIds.size > 0) return Array.from(checkedIds);
  if (activeId) return [activeId];
  return [];
}

function sendCommand(actionObj, target) {
  if (!target) target = getTargets().length > 1 ? 'broadcast' : (activeId || getTargets()[0]);
  if (!target) { log('未选择设备，请先点击左侧设备'); return; }
  log('发送 ' + actionObj.action + ' 到 ' + target + ' x=' + actionObj.x + ' y=' + actionObj.y);
  send({ type: 'command', target, action: actionObj });
}

// 鼠标手势 -> touch 序列
let touching = false;
let touchId = 1;
canvas.addEventListener('mousedown', (e) => {
  touching = true;
  const p = toDeviceCoords(e);
  sendCommand({ action: 'touch', phase: 'down', id: touchId, x: p.x, y: p.y });
});
window.addEventListener('mousemove', (e) => {
  if (!touching) return;
  const p = toDeviceCoords(e);
  sendCommand({ action: 'touch', phase: 'move', id: touchId, x: p.x, y: p.y });
});
window.addEventListener('mouseup', (e) => {
  if (!touching) return;
  touching = false;
  const p = toDeviceCoords(e);
  sendCommand({ action: 'touch', phase: 'up', id: touchId, x: p.x, y: p.y });
});

// 快捷按键
document.getElementById('btnHome').onclick = () => sendCommand({ action: 'key', name: 'home' });
document.getElementById('btnBack').onclick = () => sendCommand({ action: 'key', name: 'back' });
document.getElementById('btnRecent').onclick = () => sendCommand({ action: 'key', name: 'recent' });
document.getElementById('btnBroadcast').onclick = () => {
  if (checkedIds.size < 2) { log('群控请先勾选至少两台设备'); return; }
  log('已切换到广播模式，后续操作将同时作用于 ' + Array.from(checkedIds).join(', '));
};

connect();
