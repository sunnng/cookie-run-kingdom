/**
 * Bun WebSocket 中转服务器
 * 端口 8080
 * 路径 /ws -> WebSocket 升级
 * 其他路径 -> 返回前端单文件 index.html
 */

import { handleMessage } from "./router";
import {
  registerClient,
  unregisterClient,
  broadcastDevices,
} from "./device-registry";

const PORT = Number(Bun.env.RELAY_PORT || 8080);
const HOST = Bun.env.RELAY_HOST || "0.0.0.0";

const server = Bun.serve({
  port: PORT,
  hostname: HOST,
  fetch(req, server) {
    const url = new URL(req.url);
    if (url.pathname === "/ws") {
      const upgraded = server.upgrade(req);
      if (upgraded) return undefined as any;
    }

    // 默认返回前端页面
    const htmlPath = new URL("./web/index.html", import.meta.url);
    return new Response(Bun.file(htmlPath), {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  },
  websocket: {
    open(ws) {
      console.log(`[ws] client connected: ${ws.remoteAddress || "unknown"}`);
      // 等首条消息再区分 role
      registerClient(ws, "browser");
    },
    message(ws, msg) {
      if (typeof msg !== "string") return;
      handleMessage(ws, msg);
    },
    close(ws, code, reason) {
      console.log(`[ws] client disconnected: ${code || 0} ${reason || ""}`);
      unregisterClient(ws);
    },
  },
});

console.log(`Remote relay listening on ws://${HOST}:${PORT}/ws`);
console.log(`Open http://${HOST}:${PORT} in browser`);
