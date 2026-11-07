// グローバルレーティング＆マッチングキュー管理 Durable Object
import {
  calculateNewRating,
  getPlayerInfo,
  INITIAL_RATING,
} from "./rating.js";

const MATCHMAKING_TIMEOUT_MS = 60_000; // キューに居続ける最大時間
const RATING_RANGE_INITIAL = 200;      // 初期のレート探索幅
const RATING_RANGE_EXPAND_MS = 10_000; // 探索幅を広げる間隔

export class Ratings {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.storage = ctx.storage;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "POST" && path === "/enqueue") {
      return this._handleEnqueue(request);
    }
    if (request.method === "POST" && path === "/dequeue") {
      return this._handleDequeue(request);
    }
    if (request.method === "GET" && path.startsWith("/player/")) {
      return this._handleGetPlayer(path.slice(8));
    }
    if (request.method === "POST" && path === "/result") {
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
      rating: INITIAL_RATING,
      gamesPlayed: 0,
      wins: 0,
      losses: 0,
    };
    const info = getPlayerInfo(data.rating, data.gamesPlayed, data.wins, data.losses);
    return Response.json(info);
  }

  // ── マッチングキューに参加 ──
  async _handleEnqueue(request) {
    const body = await request.json();
    const playerId = body.playerId;
    const playerName = body.playerName || playerId;
    if (!playerId) return new Response("Missing playerId", { status: 400 });

    // 現在のレート取得
    const playerData = (await this.storage.get(`player:${playerId}`)) || {
      rating: INITIAL_RATING,
      gamesPlayed: 0,
      wins: 0,
      losses: 0,
    };

    // キュー取得
    const queue = (await this.storage.get("matchmaking_queue")) || [];
    const now = Date.now();

    // 既にキューにいる場合は現在の状態を返す
    const existing = queue.find((e) => e.playerId === playerId);
    if (existing) {
      // タイムアウトチェック
      if (now - existing.enqueuedAt > MATCHMAKING_TIMEOUT_MS) {
        // タイムアウトしたので除外して再登録
        const idx = queue.indexOf(existing);
        queue.splice(idx, 1);
      } else {
        // 探索幅を時間経過で広げ、対戦相手を探す
        const elapsed = now - existing.enqueuedAt;
        const range = RATING_RANGE_INITIAL + Math.floor(elapsed / RATING_RANGE_EXPAND_MS) * 100;
        const match = this._findMatch(queue, playerId, playerData.rating, range);
        if (match) {
          // マッチ成立 → ルームコードを発行して両者に返す
          const roomCode = this._generateRoomCode();
          // キューから両者を削除
          const matchIdx = queue.findIndex((e) => e.playerId === match.playerId);
          const selfIdx = queue.findIndex((e) => e.playerId === playerId);
          if (matchIdx >= 0) queue.splice(matchIdx, 1);
          if (selfIdx >= 0) {
            const si = queue.findIndex((e) => e.playerId === playerId);
            if (si >= 0) queue.splice(si, 1);
          }
          await this.storage.put("matchmaking_queue", queue);
          return Response.json({
            status: "matched",
            roomCode,
            opponent: {
              playerId: match.playerId,
              playerName: match.playerName,
              rating: match.rating,
              color: getPlayerInfo(match.rating, 0, 0, 0).color,
            },
            yourRating: playerData.rating,
          });
        }
        // マッチしなければ現在の状態を返す
        await this.storage.put("matchmaking_queue", queue);
        return Response.json({
          status: "searching",
          queuePosition: queue.findIndex((e) => e.playerId === playerId) + 1,
          queueSize: queue.length,
          ratingRange: range,
        });
      }
    }

    // 新規登録
    queue.push({
      playerId,
      playerName,
      rating: playerData.rating,
      enqueuedAt: now,
    });
    await this.storage.put("matchmaking_queue", queue);

    // 既にキューに相手がいればマッチを試みる
    const match = this._findMatch(queue, playerId, playerData.rating, RATING_RANGE_INITIAL);
    if (match) {
      const roomCode = this._generateRoomCode();
      const matchIdx = queue.findIndex((e) => e.playerId === match.playerId);
      const selfIdx = queue.findIndex((e) => e.playerId === playerId);
      if (matchIdx >= 0) queue.splice(matchIdx, 1);
      if (selfIdx >= 0) {
        const si = queue.findIndex((e) => e.playerId === playerId);
        if (si >= 0) queue.splice(si, 1);
      }
      await this.storage.put("matchmaking_queue", queue);
      return Response.json({
        status: "matched",
        roomCode,
        opponent: {
          playerId: match.playerId,
          playerName: match.playerName,
          rating: match.rating,
          color: getPlayerInfo(match.rating, 0, 0, 0).color,
        },
        yourRating: playerData.rating,
      });
    }

    return Response.json({
      status: "searching",
      queuePosition: queue.length,
      queueSize: queue.length,
      ratingRange: RATING_RANGE_INITIAL,
    });
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
    return Response.json({ status: "removed" });
  }

  // ── 試合結果を報告してレート更新 ──
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
      winnerData.rating, loserData.rating,
      isDraw ? false : true,
      winnerData.gamesPlayed
    );
    const loserResult = calculateNewRating(
      loserData.rating, winnerData.rating,
      isDraw ? true : false,
      loserData.gamesPlayed
    );

    if (!isDraw) {
      winnerData.wins++;
      loserData.losses++;
    }
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

  // ── リーダーボード上位取得 ──
  async _handleLeaderboard() {
    // Durable Object の list() を使って player: プレフィックスの全データを取得
    const allPlayers = await this.storage.list({ prefix: "player:" });
    const players = [];
    for (const [key, data] of allPlayers) {
      const playerId = key.replace("player:", "");
      players.push({
        playerId,
        ...getPlayerInfo(data.rating, data.gamesPlayed, data.wins, data.losses),
      });
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

  // ── ルームコード生成 ──
  _generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }
}
