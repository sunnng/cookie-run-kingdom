/**
 * 设备注册表
 * 维护所有已连接设备与浏览器客户端的映射关系
 */

export type Role = "device" | "browser";

export interface DeviceInfo {
  id: string;
  brand: string;
  model: string;
  width: number;
  height: number;
  connectedAt: number;
}

export interface Client {
  ws: any; // Bun ServerWebSocket
  role: Role;
  deviceId?: string;
  subscriptions?: Set<string>;
}

const clients = new Map<any, Client>();     // ws -> Client
const devices = new Map<string, DeviceInfo>(); // deviceId -> info

export function getClients() {
  return clients;
}

export function getDevices() {
  return devices;
}

export function registerClient(ws: any, role: Role) {
  clients.set(ws, { ws, role, subscriptions: new Set() });
}

export function unregisterClient(ws: any) {
  const client = clients.get(ws);
  if (!client) return;

  if (client.role === "device" && client.deviceId) {
    devices.delete(client.deviceId);
    broadcastDevices();
  }
  clients.delete(ws);
}

export function setDevice(ws: any, info: DeviceInfo) {
  const client = clients.get(ws);
  if (!client) return;

  client.deviceId = info.id;
  client.role = "device";
  devices.set(info.id, info);
  broadcastDevices();
}

export function getDeviceWs(deviceId: string): any | undefined {
  for (const [, client] of clients) {
    if (client.role === "device" && client.deviceId === deviceId) {
      return client.ws;
    }
  }
  return undefined;
}

export function getAllDeviceIds(): string[] {
  return Array.from(devices.keys());
}

export function subscribeBrowser(ws: any, ids: string[]) {
  const client = clients.get(ws);
  if (!client || client.role !== "browser") return;
  client.subscriptions = new Set(ids);
}

export function broadcastToBrowsers(deviceId: string, payload: object) {
  const text = JSON.stringify(payload);
  for (const [, client] of clients) {
    if (client.role === "browser" && client.subscriptions?.has(deviceId)) {
      client.ws.send(text);
    }
  }
}

export function broadcastDevices() {
  const list = Array.from(devices.values());
  const payload = JSON.stringify({ type: "devices", list });
  for (const [, client] of clients) {
    if (client.role === "browser") {
      client.ws.send(payload);
    }
  }
}

export function getSubscribers(deviceId: string): any[] {
  const result: any[] = [];
  for (const [, client] of clients) {
    if (client.role === "browser" && client.subscriptions?.has(deviceId)) {
      result.push(client.ws);
    }
  }
  return result;
}
