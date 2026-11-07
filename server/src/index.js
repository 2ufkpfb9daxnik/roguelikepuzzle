import { Room } from "./room.js";
import { Ratings } from "./ratings.js";

export { Room, Ratings };

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Max-Age": "86400",
};

function withCors(response) {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(CORS_HEADERS)) {
    headers.set(key, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // ── ヘルスチェック ──
    if (path === "/health") {
      return new Response("ok", { status: 200, headers: CORS_HEADERS });
    }

    // ── レーティング / マッチング API → Ratings DO へ転送 ──
    if (
      path.startsWith("/rating/") ||
      path === "/leaderboard" ||
      path === "/matchmake" ||
      path === "/matchmake/cancel" ||
      path === "/matchmake/result"
    ) {
      const id = env.RATINGS.idFromName("global");
      const stub = env.RATINGS.get(id);
      const res = await stub.fetch(request);
      return withCors(res);
    }

    // ── WebSocket ルーム ──
    const match = path.match(/^\/room\/([A-Z0-9]{4,8})$/);
    if (!match) {
      return new Response("Not found", { status: 404, headers: CORS_HEADERS });
    }

    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket", { status: 426, headers: CORS_HEADERS });
    }

    const roomCode = match[1];
    const id = env.ROOMS.idFromName(roomCode);
    const stub = env.ROOMS.get(id);
    return stub.fetch(request);
  },
};
