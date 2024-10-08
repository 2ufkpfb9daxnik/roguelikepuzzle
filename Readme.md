# ローグライクパズル

-3マッチ
-バフ選択

ノード構成

MainScene (Node2D)                           # ルートノード（インスタンス化なし）
├── GameManager (Node)                       # ゲーム状態や進行を管理（インスタンス化なし）
│   ├── CurrentStage (Stage)                 # 現在のステージを管理するカスタムノード（インスタンス化）
│   │   ├── PuzzleBoard (Node2D)             # パズル盤（インスタンス化）
│   │   │   ├── Cells (GridContainer)         # 駒が配置されるセル（インスタンス化）
│   │   │   │   ├── Cell (Button/Sprite)      # 各マスに対応するノード（ボタンまたはスプライト、インスタンス化）
│   │   │   ├── DroppingPieces (Node)        # 落ちる駒の管理ノード（インスタンス化なし）
│   │   │   └── Effects (Node)                # エフェクトを表示するノード（インスタンス化なし）
│   │   ├── BuffManager (Node)                # バフの選択管理（インスタンス化なし）
│   │   │   ├── BuffSelection (VBoxContainer) # バフ選択用のUI（インスタンス化）
│   │   │   └── Buffs (Node)                  # バフのリスト（インスタンス化なし）
│   │   │       ├── ScoreMultiplierBuff (Buff) # スコア倍率バフ（インスタンス化）
│   │   │       ├── PieceTransformerBuff (Buff) # 駒タイプ変化バフ（インスタンス化）
│   │   │       ├── AdjacentMatchBuff (Buff)  # 隣接しても消えるバフ（インスタンス化）
│   │   │       ├── DiagonalMatchBuff (Buff)  # 斜めでも消えるバフ（インスタンス化）
│   │   │       ├── UniversalMatchBuff (Buff) # 全ての駒と消せるバフ（インスタンス化）
│   │   │       ├── SpecialPieceBuff (Buff)  # 特殊駒を生成するバフ（インスタンス化）
│   │   │       ├── RandomRemovalBuff (Buff)  # 任意の駒を消すバフ（インスタンス化）
│   │   │       ├── ConditionalBuff (Buff)    # 条件付きバフ（インスタンス化）
│   │   │       └── CustomBuff (Buff)         # 他のカスタムバフ（インスタンス化）
│   │   └── ScoreManager (Node)               # スコアの管理（インスタンス化なし）
│   │       ├── CurrentScore (int)            # 現在のスコア（スクリプト内の変数、インスタンス化なし）
│   │       └── HighScore (int)                # ハイスコア（スクリプト内の変数、インスタンス化なし）
│   └── LevelManager (Node)                    # ステージと進行状況を管理するノード（インスタンス化なし）
│       ├── Stages (Array)                     # ステージの情報を持つ配列（スクリプト内の変数、インスタンス化なし）
│       └── NextStageConditions (Node)         # 次のステージに進む条件を管理するノード（インスタンス化なし）
├── UI (CanvasLayer)                          # ユーザーインターフェース全体（インスタンス化なし）
│   ├── ScoreDisplay (Label)                  # スコアを表示するLabelノード（インスタンス化）
│   ├── StageDisplay (Label)                  # 現在のステージ情報を表示するLabelノード（インスタンス化）
│   ├── BuffDisplay (VBoxContainer)           # 選択したバフを表示するコンテナ（インスタンス化）
│   └── GameOverScreen (Control)              # ゲームオーバー画面（インスタンス化）
│       ├── RestartButton (Button)            # 再スタートボタン（インスタンス化）
│       └── QuitButton (Button)               # ゲーム終了ボタン（インスタンス化）
└── AudioManager (Node)                       # サウンドやBGMを管理するノード（インスタンス化なし）
    ├── BackgroundMusic (AudioStreamPlayer)   # 背景音楽プレーヤー（インスタンス化）
    └── SoundEffects (Node)                   # 効果音を管理するノード（インスタンス化なし）
        ├── SoundEffect (AudioStreamPlayer)   # 効果音プレーヤー（インスタンス化）
