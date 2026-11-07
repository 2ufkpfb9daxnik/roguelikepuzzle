import { Room } from "./room.js";
import { Ratings } from "./ratings.js";

export { Room, Ratings };

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function corsJson(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function corsText(text, status = 200) {
  return new Response(text, {
    status,
    headers: { "Content-Type": "text/plain", ...CORS_HEADERS },
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
      return corsText("ok");
    }

    // ── レーティング API ──
    if (path.startsWith("/rating/")) {
      const playerId = path.slice(8);
      const id = env.RATINGS.idFromName("global");
      const stub = env.RATINGS.get(id);
      return stub.fetch(new Request(`https://ratings/player/${playerId}`, request));
    }

    if (path === "/leaderboard") {
      const id = env.RATINGS.idFromName("global");
      const stub = env.RATINGS.get(id);
      return stub.fetch(new Request("https://ratings/leaderboard", request));
    }

    if (path === "/matchmake") {
      const id = env.RATINGS.idFromName("global");
      const stub = env.RATINGS.get(id);
      return stub.fetch(new Request("https://ratings/enqueue", request));
    }

    if (path === "/matchmake/cancel") {
      const id = env.RATINGS.idFromName("global");
      const stub = env.RATINGS.get(id);
      return stub.fetch(new Request("https://ratings/dequeue", request));
    }

    if (path === "/matchmake/result") {
      const id = env.RATINGS.idFromName("global");
      const stub = env.RATINGS.get(id);
      return stub.fetch(new Request("https://ratings/result", request));
    }

    // ── WebSocket ルーム ──
    const match = path.match(/^\/room\/([A-Z0-9]{4,8})$/);
    if (!match) {
      return corsText("Not found", 404);
    }

    if (request.headers.get("Upgrade") !== "websocket") {
      return corsText("Expected WebSocket", 426);
    }

    const roomCode = match[1];
    const id = env.ROOMS.idFromName(roomCode);
    const stub = env.ROOMS.get(id);
    return stub.fetch(request);
  },
};
