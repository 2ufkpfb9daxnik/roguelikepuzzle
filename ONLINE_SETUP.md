# オンライン対戦 セットアップ

## 構成

```text
Godot Webビルド
  └ Cloudflare Pages（静的配信）
        ↓ WebSocket
Cloudflare Worker + Durable Object（ルーム・ターン・タイマー）
```

## 1. サーバーをデプロイ

```bash
cd server
npm install
npx wrangler login
npx wrangler deploy
```

`wrangler.toml` の `name` は自分のプロジェクト名に変更してください。

デプロイ後に表示されるURLの例:

```text
https://roguelike-puzzle-online.<your-subdomain>.workers.dev
```

## 2. Godot側の接続先を設定

`network_manager.gd`:

```gdscript
const DEFAULT_SERVER_URL: String = "wss://roguelike-puzzle-online.<your-subdomain>.workers.dev"
```

または、ゲーム内の「オンライン対戦」画面のサーバーURL欄に直接入力します。

## 3. Webビルドを作成してCloudflare Pagesへ配置

Godotエディタで **エクスポートテンプレート（4.4.stable）** をインストールしてから、`Web` プリセットで `build/web/index.html` にエクスポートします。

```powershell
godot --headless --path . --export-release "Web" build/web/index.html
python deploy/prepare_web_for_pages.py
```

`prepare_web_for_pages.py` が以下を行います。

- PCKを20MBずつに分割（Cloudflare Pagesの25MiB制限対策）
- WASMを20MBずつに分割し、Blob URL経由で読み込むよう `index.js` を調整
- 分割ファイルを読み込むカスタムローダーを `index.html` に組み込み
- `_headers` を配置

その後、Pagesへデプロイします。

```powershell
cd server
npx wrangler pages deploy ../build/web --project-name roguelike-puzzle
```

`wrangler pages deploy` は `npx wrangler login` と同じCloudflareアカウントを使用します。

> PCKは約280MBあるため、初回ロードには時間がかかります。
> 不要なWAV/JPGはエクスポートから除外済みです。

## デプロイ済みURL

- ゲーム: https://roguelike-puzzle.pages.dev
- 通信サーバー: wss://roguelike-puzzle-online.roguelikepuzzle1120.workers.dev

## 4. 遊び方

1. タイトル画面の「🌐 オンライン対戦」を選択
2. プレイヤー名を入力
3. ホストは「部屋を作る」、ゲストはルームコードを入力して「コードで参加」
4. 2人そろったら「準備完了」
5. 10秒ターン／5ラウンドごとに20秒のレリック・ショップフェーズ

## 5. Cloudflare Pagesへゲームを配置

Godotエディタで **エクスポートテンプレート（4.4.stable）** をインストールしてから、`Web` プリセットで `build/web/index.html` にエクスポートします。

```powershell
# エクスポート後
Copy-Item deploy/cloudflare_pages/_headers build/web/_headers
cd server
npx wrangler pages deploy ../build/web --project-name roguelike-puzzle
```

`wrangler pages deploy` は `npx wrangler login` と同じCloudflareアカウントを使用します。

## 6. ローカルで2人対戦を確認する

サーバー:

```bash
cd server
npx wrangler dev --port 8787
```

Godotのオンライン画面でサーバーURLを `ws://127.0.0.1:8787` にして、2つのゲームウィンドウから同じルームコードで接続します。

確認済みの通信フロー:

- ルーム作成・参加
- 準備完了から対戦開始
- 10秒ターンと自動パス
- 攻撃・HP・シールドの同期
- 5ラウンドごとのショップ
- レリック選択とショップ購入
- 切断時の再接続


## 現在の実装範囲

実装済み:

- ルーム作成・参加
- WebSocket同期
- 10秒ターンタイマー（時間切れ自動パス）
- 5ラウンドごとの20秒ショップフェーズ
- レリック候補の同期と実際のレリック取得
- ショップ購入（最大HP・攻撃・シールドなどの強化）
- 既存パズル盤面での対戦
- 盤面で貯めた攻撃・回復・シールドの相手への同期
- 切断時の30秒待機と再接続

未実装:

- 公開マッチング・ランキング
- サーバー側での戦闘結果検証
- 観戦機能

