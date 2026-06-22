/**
 * 消息路由
 * 处理设备端与浏览器端的消息分发
 */

import {
  getClients,
  setDevice,
  getDeviceWs,
  getAllDeviceIds,
  subscribeBrowser,
  broadcastToBrowsers,
  broadcastDevices,
  unregisterClient,
} from "./device-registry";

let seqCounter = 0;

function nextSeq(): number {
  seqCounter = (seqCounter + 1) % 0x7fffffff;
  return seqCounter;
}

export function handleMessage(ws: any, raw: string) {
  let msg: any;
  try {
    msg = JSON.parse(raw);
  } catch {
    ws.send(JSON.stringify({ type: "error", msg: "invalid json" }));
    return;
  }

  const type = msg?.type;
  if (!type) {
    ws.send(JSON.stringify({ type: "error", msg: "missing type" }));
    return;
  }

  switch (type) {
    case "register":
      handleRegister(ws, msg);
      break;
    case "frame":
      handleFrame(ws, msg);
      break;
    case "subscribe":
      handleSubscribe(ws, msg);
      break;
    case "command":
      handleCommand(ws, msg);
      break;
    case "ack":
      // 可选回执，暂不做处理
      break;
    default:
      ws.send(JSON.stringify({ type: "error", msg: "unknown type: " + type }));
  }
}

function handleRegister(ws: any, msg: any) {
  const { id, brand, model, width, height } = msg;
  if (!id || !width || !height) {
    ws.send(JSON.stringify({ type: "error", msg: "register missing fields" }));
    return;
  }
  setDevice(ws, {
    id,
    brand: brand || "unknown",
    model: model || "unknown",
    width: Number(width),
    height: Number(height),
    connectedAt: Date.now(),
  });
  console.log(`[device] registered: ${id} ${brand}/${model} ${width}x${height}`);
  ws.send(JSON.stringify({ type: "registered", id }));
}

function handleFrame(ws: any, msg: any) {
  const client = getClients().get(ws);
  if (!client || client.role !== "device" || !client.deviceId) return;

  const { img, w, h, ts } = msg;
  broadcastToBrowsers(client.deviceId, {
    type: "frame",
    id: client.deviceId,
    img,
    w: Number(w),
    h: Number(h),
    ts: ts || Date.now(),
  });
}

function handleSubscribe(ws: any, msg: any) {
  const ids = Array.isArray(msg.ids) ? msg.ids : [];
  subscribeBrowser(ws, ids);
  ws.send(JSON.stringify({ type: "subscribed", ids }));
  // 立即推送一次设备列表
  broadcastDevices();
}

function handleCommand(_ws: any, msg: any) {
  const { target, action } = msg;
  if (!action) return;
  console.log(`[command] target=${target} action=${action.action}`);

  const targets =
    target === "broadcast" ? getAllDeviceIds() : [target];

  for (const id of targets) {
    const devWs = getDeviceWs(id);
    if (!devWs) continue;
    devWs.send(
      JSON.stringify({
        type: "cmd",
        seq: nextSeq(),
        action: action.action,
        x: action.x,
        y: action.y,
        x1: action.x1,
        y1: action.y1,
        x2: action.x2,
        y2: action.y2,
        dur: action.dur,
        time: action.time,
        id: action.id,
        phase: action.phase,
        name: action.name,
        text: action.text,
      })
    );
  }
}
