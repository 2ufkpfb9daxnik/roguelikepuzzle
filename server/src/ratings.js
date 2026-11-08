// グローバルレーティング＆マッチングキュー管理 Durable Object
import {
  calculateNewRating,
  getPlayerInfo,
  INITIAL_RATING,
} from "./rating.js";

const MATCHMAKING_TIMEOUT_MS = 60_000;
const RATING_RANGE_INITIAL = 200;
const RATING_RANGE_EXPAND_MS = 10_000;

export class Ratings {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.storage = ctx.storage;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "POST" && path === "/matchmake") {
      return this._handleEnqueue(request);
    }
    if (request.method === "POST" && path === "/matchmake/cancel") {
      return this._handleDequeue(request);
    }
    if (request.method === "GET" && path.startsWith("/rating/")) {
      return this._handleGetPlayer(path.slice(8));
    }
    if (request.method === "POST" && path === "/matchmake/result") {
      return this._handleResult(request);
    }
    if (request.method === "GET" && path === "/leaderboard") {
      return this._handleLeaderboard();
    }
    return new Response("Not found", { status: 404 });
  }

  // ── プレイヤー情報取得 ──
  async _handleGetPlayer(playerId) {
    if (!playerId) return new Response("Missing playerId", { status: 400 });
    const data = (await this.storage.get(`player:${playerId}`)) || {
      rating: INITIAL_RATING, gamesPlayed: 0, wins: 0, losses: 0,
    };
    return Response.json(getPlayerInfo(data.rating, data.gamesPlayed, data.wins, data.losses));
  }

  // ── マッチング（エンキュー & ポーリング両用）──
  async _handleEnqueue(request) {
    const body = await request.json();
    const playerId = body.playerId;
    const playerName = body.playerName || playerId;
    if (!playerId) return new Response("Missing playerId", { status: 400 });

    // ① 保留中のマッチがあれば先に返す（相手からのマッチ成立通知）
    const pending = await this.storage.get(`pending_match:${playerId}`);
    if (pending) {
      await this.storage.delete(`pending_match:${playerId}`);
      // キューからも念のため除去
      const queue = (await this.storage.get("matchmaking_queue")) || [];
      const qi = queue.findIndex((e) => e.playerId === playerId);
      if (qi >= 0) queue.splice(qi, 1);
      await this.storage.put("matchmaking_queue", queue);
      return Response.json(pending);
    }

    const playerData = (await this.storage.get(`player:${playerId}`)) || {
      rating: INITIAL_RATING, gamesPlayed: 0, wins: 0, losses: 0,
    };

    const queue = (await this.storage.get("matchmaking_queue")) || [];
    const now = Date.now();

    // ② キュー内の既存エントリを確認（タイムアウト除去含む）
    const existing = queue.find((e) => e.playerId === playerId);
    if (existing) {
      if (now - existing.enqueuedAt > MATCHMAKING_TIMEOUT_MS) {
        const idx = queue.indexOf(existing);
        queue.splice(idx, 1);
      } else {
        // 時間経過で探索幅を広げて相手を探す
        const elapsed = now - existing.enqueuedAt;
        const range = RATING_RANGE_INITIAL + Math.floor(elapsed / RATING_RANGE_EXPAND_MS) * 100;
        const match = this._findMatch(queue, playerId, playerData.rating, range);
        if (match) {
          return this._createMatch(queue, playerId, playerName, playerData, match);
        }
        await this.storage.put("matchmaking_queue", queue);
        return Response.json({
          status: "searching",
          queuePosition: queue.findIndex((e) => e.playerId === playerId) + 1,
          queueSize: queue.length,
          ratingRange: range,
        });
      }
    }

    // ③ 新規登録
    queue.push({ playerId, playerName, rating: playerData.rating, enqueuedAt: now });
    await this.storage.put("matchmaking_queue", queue);

    // ④ 即マッチ試行
    const match = this._findMatch(queue, playerId, playerData.rating, RATING_RANGE_INITIAL);
    if (match) {
      return this._createMatch(queue, playerId, playerName, playerData, match);
    }

    return Response.json({
      status: "searching",
      queuePosition: queue.length,
      queueSize: queue.length,
      ratingRange: RATING_RANGE_INITIAL,
    });
  }

  // ── マッチ成立処理（両者に通知を保存）──
  async _createMatch(queue, playerId, playerName, playerData, opponentEntry) {
    const roomCode = this._generateRoomCode();
    const opponentData = (await this.storage.get(`player:${opponentEntry.playerId}`)) || {
      rating: INITIAL_RATING, gamesPlayed: 0, wins: 0, losses: 0,
    };

    const myMatchInfo = {
      status: "matched",
      roomCode,
      opponent: {
        playerId: opponentEntry.playerId,
        playerName: opponentEntry.playerName,
        rating: opponentData.rating,
        color: getPlayerInfo(opponentData.rating, 0, 0, 0).color,
      },
      yourRating: playerData.rating,
    };
    const oppMatchInfo = {
      status: "matched",
      roomCode,
      opponent: {
        playerId,
        playerName,
        rating: playerData.rating,
        color: getPlayerInfo(playerData.rating, 0, 0, 0).color,
      },
      yourRating: opponentData.rating,
    };

    // キューから両者を削除
    const filtered = queue.filter((e) => e.playerId !== playerId && e.playerId !== opponentEntry.playerId);
    await this.storage.put("matchmaking_queue", filtered);

    // 両者の保留マッチを保存（ポーリング時に取得される）
    await this.storage.put(`pending_match:${playerId}`, myMatchInfo);
    await this.storage.put(`pending_match:${opponentEntry.playerId}`, oppMatchInfo);

    // 今リクエストした側には即返す
    await this.storage.delete(`pending_match:${playerId}`);
    return Response.json(myMatchInfo);
  }

  // ── マッチングキューから脱退 ──
  async _handleDequeue(request) {
    const body = await request.json();
    const playerId = body.playerId;
    if (!playerId) return new Response("Missing playerId", { status: 400 });
    const queue = (await this.storage.get("matchmaking_queue")) || [];
    const idx = queue.findIndex((e) => e.playerId === playerId);
    if (idx >= 0) queue.splice(idx, 1);
    await this.storage.put("matchmaking_queue", queue);
    await this.storage.delete(`pending_match:${playerId}`);
    return Response.json({ status: "removed" });
  }

  // ── 試合結果報告 ──
  async _handleResult(request) {
    const body = await request.json();
    const { winnerId, loserId, draw } = body;
    if (!winnerId || !loserId) return new Response("Missing winnerId or loserId", { status: 400 });

    const winnerData = (await this.storage.get(`player:${winnerId}`)) || {
      rating: INITIAL_RATING, gamesPlayed: 0, wins: 0, losses: 0,
    };
    const loserData = (await this.storage.get(`player:${loserId}`)) || {
      rating: INITIAL_RATING, gamesPlayed: 0, wins: 0, losses: 0,
    };

    const isDraw = draw === true;
    const winnerResult = calculateNewRating(
      winnerData.rating, loserData.rating, !isDraw, winnerData.gamesPlayed
    );
    const loserResult = calculateNewRating(
      loserData.rating, winnerData.rating, isDraw, loserData.gamesPlayed
    );

    if (!isDraw) { winnerData.wins++; loserData.losses++; }
    winnerData.gamesPlayed++;
    loserData.gamesPlayed++;
    winnerData.rating = winnerResult.newRating;
    loserData.rating = loserResult.newRating;

    await this.storage.put(`player:${winnerId}`, winnerData);
    await this.storage.put(`player:${loserId}`, loserData);

    return Response.json({
      winner: getPlayerInfo(winnerData.rating, winnerData.gamesPlayed, winnerData.wins, winnerData.losses),
      loser: getPlayerInfo(loserData.rating, loserData.gamesPlayed, loserData.wins, loserData.losses),
      winnerDelta: winnerResult.delta,
      loserDelta: loserResult.delta,
    });
  }

  // ── リーダーボード ──
  async _handleLeaderboard() {
    const allPlayers = await this.storage.list({ prefix: "player:" });
    const players = [];
    for (const [key, data] of allPlayers) {
      const playerId = key.replace("player:", "");
      players.push({ playerId, ...getPlayerInfo(data.rating, data.gamesPlayed, data.wins, data.losses) });
    }
    players.sort((a, b) => b.rating - a.rating);
    return Response.json({ leaderboard: players.slice(0, 50) });
  }

  // ── マッチ相手を探す ──
  _findMatch(queue, playerId, playerRating, range) {
    let best = null;
    let bestDiff = Infinity;
    for (const entry of queue) {
      if (entry.playerId === playerId) continue;
      const diff = Math.abs(entry.rating - playerRating);
      if (diff <= range && diff < bestDiff) {
        best = entry;
        bestDiff = diff;
      }
    }
    return best;
  }

  _generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }
}
