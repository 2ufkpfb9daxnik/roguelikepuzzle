# Roguelike Puzzle Online

Cloudflare Workers + Durable Objects を使った、2人用ターン制対戦サーバーです。

- 1ルーム = 1 Durable Object
- WebSocketでリアルタイム同期
- ターン操作時間: 10秒（時間切れで自動パス）
- レリック選択＋ショップ: 20秒（時間切れで自動終了）
- 5ラウンドごとにショップフェーズ
- 切断時は30秒まで再接続待ち

## セットアップ

```bash
cd server
npm install
npx wrangler login
npx wrangler deploy
```

デプロイ後に表示されるURLを、Godot側の `network_manager.gd` にある `DEFAULT_SERVER_URL` へ設定してください。

```gdscript
const DEFAULT_SERVER_URL: String = "wss://roguelike-puzzle-online.<your-subdomain>.workers.dev"
```

ローカル開発時は次のURLを使います。

```text
ws://localhost:8787
```

`wrangler dev` を実行してから、Godotのオンライン画面でサーバーURLを変更してください。

## 動作確認

```text
GET /health
```

が `ok` を返せばWorkerは動作しています。

WebSocket接続先:

```text
wss://<worker-url>/room/<ROOM_CODE>?name=<PLAYER_NAME>
```

同じルームコードに2人が接続すると対戦できます。

## プロトコル概要

クライアント → サーバー:

- `ready`
- `select_character` `{ character }`
- `move_started`
- `action` `{ payload }`
- `end_turn`
- `stats` `{ payload }`
- `shop_choice` `{ payload }`
- `shop_done`
- `surrender`
- `ping`

サーバー → クライアント:

- `welcome`
- `room_updated`
- `match_start`
- `turn_start`
- `action`
- `phase_updated`
- `stats`
- `shop_start`
- `shop_end`
- `turn_timeout`
- `shop_timeout`
- `match_end`
- `opponent_disconnected`
- `resumed`
- `pong`

## 補足

- Durable Objectsは無料プランではSQLiteバックエンドのみ利用できます。
- WebSocket Hibernation APIを使用しているため、待機中の接続コストを抑えられます。
- ルーム状態はDurable Object Storageに保存されます。
