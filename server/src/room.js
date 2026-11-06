const TURN_MS = 10_000;
const SHOP_MS = 20_000;
const RESOLVE_MS = 20_000;
const DISCONNECT_GRACE_MS = 30_000;
const SHOP_EVERY_ROUNDS = 5;
const MAX_PLAYERS = 2;

const RULES = {
  turnMs: TURN_MS,
  resolveMs: RESOLVE_MS,
  shopMs: SHOP_MS,
  shopEveryRounds: SHOP_EVERY_ROUNDS,
  maxHp: 5000,
  startCoins: 0
};

function randomId(length = 8) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = "";
  for (let i = 0; i < length; i++) out += chars[bytes[i] % chars.length];
  return out;
}

export class Room {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.room = null;

    this.ctx.blockConcurrencyWhile(async () => {
      const saved = await this.ctx.storage.get("room");
      this.room = saved || this._defaultRoom();
    });
  }

  _defaultRoom() {
    return {
      code: "",
      players: [null, null],
      phase: "lobby",
      round: 0,
      turnNumber: 0,
      activePlayer: 0,
      deadline: 0,
      seed: "",
      offerSeed: "",
      shopNextRound: 0,
      shopChoices: {},
      shopDone: { 0: false, 1: false },
      stats: [{}, {}],
      winner: null,
      reason: "",
      lastAction: null,
      moveStarted: false,
      resumePhase: "",
      resumeRemainingMs: 0,
      disconnectDeadline: 0,
      disconnectedPlayer: -1
    };
  }

  async _save() {
    await this.ctx.storage.put("room", this.room);
  }

  _publicPlayer(player) {
    if (!player) return null;
    return {
      name: player.name,
      ready: !!player.ready,
      connected: !!player.connected,
      character: player.character || ""
    };
  }

  _publicRoom() {
    return {
      code: this.room.code,
      players: this.room.players.map((p) => this._publicPlayer(p)),
      phase: this.room.phase,
      round: this.room.round,
      turnNumber: this.room.turnNumber,
      activePlayer: this.room.activePlayer,
      deadline: this.room.deadline,
      seed: this.room.seed,
      shopNextRound: this.room.shopNextRound,
      shopChoices: this.room.shopChoices,
      shopDone: this.room.shopDone,
      stats: this.room.stats,
      winner: this.room.winner,
      reason: this.room.reason,
      resumePhase: this.room.resumePhase,
      disconnectedPlayer: this.room.disconnectedPlayer,
      serverNow: Date.now()
    };
  }

  _send(ws, payload) {
    try {
      ws.send(JSON.stringify(payload));
    } catch (_) {
      // WebSocket already closed; ignore.
    }
  }

  _broadcast(payload, except = null) {
    const full = { ...payload, serverNow: Date.now() };
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except) continue;
      this._send(ws, full);
    }
  }

  _scheduleAlarm(timestamp) {
    const ts = Math.max(Date.now() + 50, Math.floor(timestamp));
    this.ctx.storage.setAlarm(ts);
  }

  async fetch(request) {
    const url = new URL(request.url);
    const roomCode = url.pathname.split("/").pop().toUpperCase();
    const name = (url.searchParams.get("name") || "Player").slice(0, 16);
    const token = (url.searchParams.get("token") || "").trim();

    if (!this.room.code) this.room.code = roomCode;

    let playerIndex = -1;
    if (token) {
      playerIndex = this.room.players.findIndex((p) => p && p.token === token);
    }
    if (playerIndex < 0) {
      playerIndex = this.room.players.findIndex((p) => p === null);
    }
    if (playerIndex < 0) {
      // 名前が一致する切断中プレイヤーがいれば復帰を許可
      playerIndex = this.room.players.findIndex(
        (p) => p && !p.connected && p.name === name
      );
    }
    if (playerIndex < 0) {
      return new Response("Room is full", { status: 409 });
    }

    const existing = this.room.players[playerIndex];
    const playerToken = existing?.token || token || randomId(16);

    // 同じプレイヤーの古い接続が残っている場合は閉じる
    for (const oldWs of this.ctx.getWebSockets()) {
      const att = oldWs.deserializeAttachment();
      if (att && att.player === playerIndex) {
        try { oldWs.close(4001, "replaced"); } catch (_) {}
      }
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ player: playerIndex, token: playerToken });

    this.room.players[playerIndex] = {
      name,
      token: playerToken,
      ready: existing?.ready ?? false,
      connected: true,
      character: existing?.character || ""
    };

    const wasPaused = this.room.phase === "paused";
    const allConnected = this.room.players.every((p) => p && p.connected);

    if (wasPaused && allConnected) {
      this.room.phase = this.room.resumePhase || "turn";
      this.room.deadline = Date.now() + Math.max(1000, this.room.resumeRemainingMs);
      this.room.disconnectDeadline = 0;
      this.room.disconnectedPlayer = -1;
      this.room.resumePhase = "";
      this.room.resumeRemainingMs = 0;
      this._scheduleAlarm(this.room.deadline);
      this._broadcast({
        type: "resumed",
        phase: this.room.phase,
        deadline: this.room.deadline
      });
    }

    this._send(server, {
      type: "welcome",
      player: playerIndex,
      token: playerToken,
      room: this._publicRoom(),
      rules: RULES,
      serverNow: Date.now()
    });

    this._broadcast({ type: "room_updated", room: this._publicRoom() }, server);
    await this._save();

    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    let data;
    try {
      data = JSON.parse(typeof message === "string" ? message : new TextDecoder().decode(message));
    } catch (_) {
      return;
    }

    const att = ws.deserializeAttachment();
    if (!att || typeof att.player !== "number") return;
    const player = att.player;
    const me = this.room.players[player];
    if (!me) return;

    switch (data.type) {
      case "ping":
        this._send(ws, { type: "pong", serverNow: Date.now() });
        return;

      case "ready":
        if (this.room.phase !== "lobby") return;
        me.ready = true;
        this._broadcast({ type: "room_updated", room: this._publicRoom() });
        await this._save();
        if (this.room.players.every((p) => p && p.ready && p.connected)) {
          await this._startMatch();
        }
        return;

      case "select_character":
        if (this.room.phase !== "lobby") return;
        if (typeof data.character !== "string") return;
        me.character = data.character.slice(0, 24);
        this._broadcast({ type: "room_updated", room: this._publicRoom() });
        await this._save();
        return;

      case "action":
        if (this.room.phase !== "turn") return;
        if (this.room.activePlayer !== player) return;
        if (Date.now() > this.room.deadline + 750) return;

        this.room.moveStarted = true;
        this.room.phase = "resolve";
        this.room.deadline = Date.now() + RESOLVE_MS;
        this.room.lastAction = data.payload ?? null;
        this._broadcast({ type: "action", from: player, payload: this.room.lastAction });
        this._broadcast({
          type: "phase_updated",
          phase: this.room.phase,
          deadline: this.room.deadline
        });
        this._scheduleAlarm(this.room.deadline);
        await this._save();
        return;

      case "move_started":
        if (this.room.phase !== "turn") return;
        if (this.room.activePlayer !== player) return;
        if (this.room.moveStarted) return;
        // 操作開始後は連鎖・演出の完了を待つため期限を延長する（入力フェーズは継続）
        this.room.moveStarted = true;
        this.room.deadline = Date.now() + RESOLVE_MS;
        this._broadcast({
          type: "phase_updated",
          phase: "turn",
          deadline: this.room.deadline
        });
        this._scheduleAlarm(this.room.deadline);
        await this._save();
        return;

      case "end_turn":
        if (this.room.phase !== "turn" && this.room.phase !== "resolve") return;
        if (this.room.activePlayer !== player) return;
        await this._advanceTurn();
        return;

      case "stats": {
        const stats = data.payload;
        if (!stats || typeof stats !== "object") return;
        this.room.stats[player] = stats;
        this._broadcast({ type: "stats", from: player, stats });
        await this._save();
        if (Number(stats.hp ?? 0) <= 0 && this.room.phase !== "ended") {
          await this._endMatch(1 - player, "ko");
        }
        return;
      }

      case "shop_choice":
        if (this.room.phase !== "shop") return;
        this.room.shopChoices[player] = data.payload ?? null;
        this._broadcast({
          type: "shop_choice",
          from: player,
          choice: this.room.shopChoices[player]
        });
        await this._save();
        return;

      case "shop_done":
        if (this.room.phase !== "shop") return;
        this.room.shopDone[player] = true;
        this._broadcast({
          type: "shop_done",
          from: player,
          shopDone: this.room.shopDone
        });
        await this._save();
        if (this.room.shopDone[0] && this.room.shopDone[1]) {
          await this._finishShop();
        }
        return;

      case "debug_jump": {
        // デバッグ用: 指定ターンへ強制ジャンプ（押したプレイヤーのターンにする）
        if (this.room.phase === "ended" || this.room.phase === "lobby") return;
        const target = Math.max(1, Math.min(999, Math.floor(Number(data.turnNumber ?? 5))));
        this.room.phase = "turn";
        this.room.turnNumber = target;
        this.room.round = Math.ceil(target / 2);
        this.room.activePlayer = player;
        this.room.deadline = Date.now() + TURN_MS;
        this.room.lastAction = null;
        this.room.moveStarted = false;
        this._broadcast({
          type: "turn_start",
          player: this.room.activePlayer,
          turnNumber: this.room.turnNumber,
          round: this.room.round,
          deadline: this.room.deadline,
          duration: TURN_MS
        });
        this._scheduleAlarm(this.room.deadline);
        await this._save();
        return;
      }

      case "debug_shop": {
        // デバッグ用: 指定ラウンドのショップ（レリック選択）を直接開く
        if (this.room.phase === "ended" || this.room.phase === "lobby") return;
        const round = Math.max(1, Math.min(99, Math.floor(Number(data.round ?? 5))));
        this.room.turnNumber = round * 2;
        this.room.round = round;
        await this._startShop(round + 1);
        return;
      }

      case "surrender":
        if (this.room.phase === "ended") return;
        await this._endMatch(1 - player, "surrender");
        return;

      default:
        return;
    }
  }

  async webSocketClose(ws, code, reason, wasClean) {
    const att = ws.deserializeAttachment();
    if (!att || typeof att.player !== "number") return;
    const player = att.player;
    const me = this.room.players[player];
    if (!me) return;

    // 同じプレイヤーの新しい接続が残っている場合は切断扱いにしない
    const stillConnected = this.ctx.getWebSockets().some((other) => {
      if (other === ws) return false;
      try {
        const otherAtt = other.deserializeAttachment();
        return otherAtt && otherAtt.player === player && other.readyState === 1;
      } catch (_) {
        return false;
      }
    });
    if (stillConnected) return;

    me.connected = false;

    if (this.room.phase !== "lobby" && this.room.phase !== "ended") {
      if (this.room.phase !== "paused") {
        this.room.resumePhase = this.room.phase;
        this.room.resumeRemainingMs = Math.max(0, this.room.deadline - Date.now());
        this.room.phase = "paused";
        this.room.disconnectedPlayer = player;
        this.room.disconnectDeadline = Date.now() + DISCONNECT_GRACE_MS;
        this._scheduleAlarm(this.room.disconnectDeadline);
      }
    }

    this._broadcast({
      type: "opponent_disconnected",
      player,
      room: this._publicRoom()
    });
    await this._save();
  }

  async webSocketError(ws, error) {
    try { ws.close(1011, "socket error"); } catch (_) {}
  }

  async alarm() {
    if (!this.room) return;
    const now = Date.now();

    if (this.room.phase === "paused") {
      if (now >= this.room.disconnectDeadline) {
        const loser = this.room.disconnectedPlayer;
        const winner = loser === 0 ? 1 : 0;
        await this._endMatch(winner, "disconnect");
      } else {
        this._scheduleAlarm(this.room.disconnectDeadline);
      }
      return;
    }

    if (!this.room.deadline || now < this.room.deadline) {
      if (this.room.deadline) this._scheduleAlarm(this.room.deadline);
      return;
    }

    if (this.room.phase === "turn" || this.room.phase === "resolve") {
      this._broadcast({
        type: "turn_timeout",
        player: this.room.activePlayer
      });
      await this._advanceTurn();
      return;
    }

    if (this.room.phase === "shop") {
      this._broadcast({ type: "shop_timeout" });
      await this._finishShop();
      return;
    }
  }

  async _startMatch() {
    this.room.phase = "turn";
    this.room.round = 1;
    this.room.turnNumber = 1;
    this.room.activePlayer = 0;
    this.room.deadline = Date.now() + TURN_MS + 4200;
    this.room.seed = randomId(12);
    this.room.winner = null;
    this.room.reason = "";
    this.room.lastAction = null;
    this.room.moveStarted = false;
    this.room.stats = [
      { hp: RULES.maxHp, maxHp: RULES.maxHp, shield: 0, coins: RULES.startCoins },
      { hp: RULES.maxHp, maxHp: RULES.maxHp, shield: 0, coins: RULES.startCoins }
    ];

    this._broadcast({
      type: "match_start",
      seed: this.room.seed,
      rules: RULES,
      players: this.room.players.map((p) => this._publicPlayer(p))
    });
    this._broadcast({
      type: "turn_start",
      player: this.room.activePlayer,
      turnNumber: this.room.turnNumber,
      round: this.room.round,
      deadline: this.room.deadline,
      duration: TURN_MS + 4200
    });

    this._scheduleAlarm(this.room.deadline);
    await this._save();
  }

  async _advanceTurn() {
    if (this.room.phase === "ended") return;

    const finishedTurn = this.room.turnNumber;
    const finishedPlayer = this.room.activePlayer;
    const completedRound = Math.ceil(finishedTurn / 2);
    const bothActed = finishedTurn % 2 === 0;

    if (bothActed && completedRound % SHOP_EVERY_ROUNDS === 0) {
      await this._startShop(completedRound + 1);
      return;
    }

    this.room.round = bothActed ? completedRound + 1 : this.room.round;
    this.room.turnNumber = finishedTurn + 1;
    this.room.activePlayer = 1 - finishedPlayer;
    this.room.phase = "turn";
    this.room.deadline = Date.now() + TURN_MS;
    this.room.lastAction = null;
    this.room.moveStarted = false;

    this._broadcast({
      type: "turn_start",
      player: this.room.activePlayer,
      turnNumber: this.room.turnNumber,
      round: this.room.round,
      deadline: this.room.deadline,
      duration: TURN_MS
    });

    this._scheduleAlarm(this.room.deadline);
    await this._save();
  }

  async _startShop(nextRound) {
    this.room.phase = "shop";
    this.room.shopNextRound = nextRound;
    this.room.offerSeed = `${this.room.seed}:${nextRound}`;
    this.room.deadline = Date.now() + SHOP_MS;
    this.room.shopChoices = {};
    this.room.shopDone = { 0: false, 1: false };

    this._broadcast({
      type: "shop_start",
      round: nextRound - 1,
      nextRound,
      deadline: this.room.deadline,
      duration: SHOP_MS,
      offerSeed: this.room.offerSeed
    });

    this._scheduleAlarm(this.room.deadline);
    await this._save();
  }

  async _finishShop() {
    this.room.phase = "turn";
    this.room.round = this.room.shopNextRound;
    this.room.turnNumber += 1;
    this.room.activePlayer = 0;
    this.room.deadline = Date.now() + TURN_MS;
    this.room.shopDone = { 0: false, 1: false };
    this.room.moveStarted = false;

    this._broadcast({
      type: "shop_end",
      round: this.room.round,
      shopChoices: this.room.shopChoices
    });
    this._broadcast({
      type: "turn_start",
      player: this.room.activePlayer,
      turnNumber: this.room.turnNumber,
      round: this.room.round,
      deadline: this.room.deadline,
      duration: TURN_MS
    });

    this._scheduleAlarm(this.room.deadline);
    await this._save();
  }

  async _endMatch(winner, reason) {
    this.room.phase = "ended";
    this.room.winner = winner;
    this.room.reason = reason;
    this.room.deadline = 0;
    this.ctx.storage.deleteAlarm();

    this._broadcast({
      type: "match_end",
      winner,
      reason
    });
    await this._save();
  }
}
