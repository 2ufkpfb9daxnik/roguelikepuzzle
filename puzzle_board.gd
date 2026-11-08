extends Node2D
const ElementDataScript = preload("res://element_data.gd")
var combat_ui_manager: Node2D

signal combat_event(event_data: Dictionary)
signal tutorial_swap_completed(from_cell: Vector2i, to_cell: Vector2i)
signal tutorial_items_scored()
signal tutorial_attack_landed()
signal tutorial_enemy_acted()
signal tutorial_special_detonated(sp_type: int)
signal pvp_turn_resolved(payload: Dictionary)
signal pvp_turn_completed()
signal pvp_move_started()

# チュートリアル制限・一時停止用
var tutorial_allowed_swap: Array[Vector2i] = []
var is_tutorial_paused: bool = false
var has_emitted_items_scored: bool = false

func set_tutorial_allowed_swap(c1: Vector2i, c2: Vector2i) -> void:
	tutorial_allowed_swap = [c1, c2]
	if swap_guide_overlay:
		swap_guide_overlay.queue_redraw()

func clear_tutorial_allowed_swap() -> void:
	tutorial_allowed_swap.clear()
	if swap_guide_overlay:
		swap_guide_overlay.queue_redraw()

func pause_tutorial_turn() -> void:
	is_tutorial_paused = true

func resume_tutorial_turn() -> void:
	is_tutorial_paused = false

## チュートリアル用：戦闘ターン演出シーケンスが進行中かどうか
func is_turn_sequence_running() -> bool:
	return current_state == BoardState.TURN_SEQUENCE

func setup_tutorial_stage2_board() -> void:
	if grid_n.size() < GRID_ROWS or grid_i.size() < GRID_ROWS:
		return
	# 4つのポーションが横一列に並ぶよう、(1, 4)と(2, 4)の入れ替えで(2, 3..6)がポーション4連になる盤面を準備
	grid_n[2][3] = PieceType.POTION
	grid_n[2][4] = PieceType.SHIELD
	grid_n[2][5] = PieceType.POTION
	grid_n[2][6] = PieceType.POTION
	grid_n[1][4] = PieceType.POTION

	# スプライトのテクスチャも即座に同期
	var p_23 = grid_i[2][3]; if p_23 >= 0 and p_23 < piece.size() and piece[p_23]: piece[p_23].texture = PIECE_TEXTURES[PieceType.POTION]
	var p_24 = grid_i[2][4]; if p_24 >= 0 and p_24 < piece.size() and piece[p_24]: piece[p_24].texture = PIECE_TEXTURES[PieceType.SHIELD]
	var p_25 = grid_i[2][5]; if p_25 >= 0 and p_25 < piece.size() and piece[p_25]: piece[p_25].texture = PIECE_TEXTURES[PieceType.POTION]
	var p_26 = grid_i[2][6]; if p_26 >= 0 and p_26 < piece.size() and piece[p_26]: piece[p_26].texture = PIECE_TEXTURES[PieceType.POTION]
	var p_14 = grid_i[1][4]; if p_14 >= 0 and p_14 < piece.size() and piece[p_14]: piece[p_14].texture = PIECE_TEXTURES[PieceType.POTION]

	set_tutorial_allowed_swap(Vector2i(1, 4), Vector2i(2, 4))

func setup_tutorial_move2_board() -> void:
	if grid_n.size() < GRID_ROWS or grid_i.size() < GRID_ROWS:
		return
	grid_n[0][9] = PieceType.SWORD
	grid_n[0][10] = PieceType.COIN
	grid_n[1][10] = PieceType.SWORD
	grid_n[2][10] = PieceType.SWORD

	for p_pos in [Vector2i(0, 9), Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10)]:
		var idx = grid_i[p_pos.x][p_pos.y]
		if idx >= 0 and idx < piece.size() and piece[idx]:
			piece[idx].texture = PIECE_TEXTURES[grid_n[p_pos.x][p_pos.y]]

	set_tutorial_allowed_swap(Vector2i(0, 9), Vector2i(0, 10))

var turn_skill_log: Array = []
const DEBUG_COMBAT_EVENTS = true

# --- 通信対戦（PvP）用 ---
var pvp_mode: bool = false
var pvp_my_turn: bool = false
var pvp_my_player_index: int = -1 # 共有盤面モード: 自分のプレイヤーindex（スキル駒所有権チェック用）
var pvp_pending_damage: float = 0.0
var pvp_divscore_snapshot: Array = []
var pvp_start_enemy_hp: float = 0.0
var pvp_is_attack: int = 0
var pvp_is_block: int = 0
var pvp_used_skills: Array = []
# ターン内に展開したシールドの合計値（複数回展開しても加算される）
var pvp_turn_shield_deployed: float = 0.0
# このターンでシールド展開演出を実際に流したか（展開前にターン終了判定しない）
var pvp_shield_spawned: bool = false


func _emit_combat_event(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false, effectiveness: String = "normal", extra: Dictionary = {}) -> void:
	var t_node = target
	if typeof(target) == TYPE_STRING and target == "enemy":
		var sm = _get_stage_manager()
		if sm and "active_enemies" in sm and sm.active_enemies.size() > 0:
			var f_idx = sm.get_focused_enemy_index() if sm.has_method("get_focused_enemy_index") else 0
			if f_idx >= 0 and f_idx < sm.active_enemies.size():
				t_node = sm.active_enemies[f_idx].get("sprite", null) if sm.active_enemies[f_idx] is Dictionary else null
			else:
				t_node = sm.active_enemies[0].get("sprite", null) if sm.active_enemies[0] is Dictionary else null
			
	var event = {
		"type": type,
		"source": source,
		"target": t_node,
		"amount": amount,
		"element": element,
		"is_critical": is_critical,
		"effectiveness": effectiveness
	}
	for k in extra:
		event[k] = extra[k]
	emit_signal("combat_event", event)
	if pvp_mode and type == "damage" and source == "ally":
		pvp_pending_damage += maxf(0.0, amount)
	if DEBUG_COMBAT_EVENTS:
		if OS.is_debug_build(): print("[CombatEvent] ", event)

const SkillVFXNode = preload("res://skill_vfx_node.gd")

## パズル盤面、連続的重力落下・消滅アニメーション、および戦闘演出（発射物・攻撃）を管理するクラス

# 駒の属性
enum PieceType {
	SHIELD = 0,
	SWORD = 1,
	COIN = 2,
	POTION = 3,
	FOOD = 4,
}

# パズルの状態機械 (State Machine)
enum BoardState {
	IDLE,            # プレイヤー入力待ち
	SWAPPING,        # 駒のスワップ移動中
	MATCH_HIGHLIGHT, # マッチした駒の強調演出中
	BREAKING,        # マッチした駒の縮小・消滅演出中
	FALLING,         # 重力による連続的な落下アニメーション中
	CASCADE_CHECK,   # 落下後の連鎖判定中
	TURN_SEQUENCE,   # 戦闘・エフェクト演出ターン
}

# --- 盤面設定・定数 ---
const GRID_COLUMNS: int = 13
const GRID_ROWS: int = 13
const CELL_KINDS: int = 5
const CELL_PITCH: float = 700.0
const MAX_COMBO_GUIDES: int = 12

# --- 共通シード・乱数生成器 (チュートリアル固定シード / 通常プレイ時ランダムシード) ---
const TUTORIAL_SEED: int = 12345678
var board_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var board_seed: int = 0

func set_board_seed(new_seed: int) -> void:
	board_seed = new_seed
	if board_rng == null:
		board_rng = RandomNumberGenerator.new()
	board_rng.seed = new_seed

func _ensure_board_rng_initialized() -> void:
	if board_seed == 0:
		var sm = _get_settings_manager()
		if (sm and "is_tutorial_mode" in sm and sm.is_tutorial_mode) or is_tutorial_mode:
			set_board_seed(TUTORIAL_SEED)
		elif sm and "game_seed" in sm and sm.game_seed != 0:
			set_board_seed(sm.game_seed)
		else:
			set_board_seed(randi())

func _board_randi() -> int:
	_ensure_board_rng_initialized()
	return board_rng.randi()

func _board_randf() -> float:
	_ensure_board_rng_initialized()
	return board_rng.randf()

const BOARD_LEFT: float = 2550.0
const BOARD_TOP: float = 220.0
const BOARD_WIDTH: float = 9100.0   # 13 * 700
const BOARD_HEIGHT: float = 9100.0  # 13 * 700
const BOARD_RIGHT: float = BOARD_LEFT + BOARD_WIDTH
const BOARD_BOTTOM: float = BOARD_TOP + BOARD_HEIGHT
const OFFSET_X: float = BOARD_LEFT
const OFFSET_Y: float = BOARD_TOP

# 落下物理パラメータ
const GRAVITY: float = 45000.0        # 落下加速度
const MAX_FALL_SPEED: float = 14000.0 # 最大落下速度

# 駒テクスチャ定数配列（インデックス 0..4 と PieceType を厳密に完全固定対応）
const PIECE_TEXTURES: Array[Texture2D] = [
	preload("res://Texture/shield/shield_cut.png"), # PieceType.SHIELD = 0 (盾)
	preload("res://Texture/sword/sword_cut.png"),   # PieceType.SWORD = 1  (剣・攻撃)
	preload("res://Texture/coin/coin_cut.png"),     # PieceType.COIN = 2   (コイン・金)
	preload("res://Texture/potion/potion_cut.png"), # PieceType.POTION = 3 (ポーション)
	preload("res://Texture/food/bread_cut.png"),    # PieceType.FOOD = 4   (パン・回復)
]

# スコア欄ラベルの初期座標とピッチ定数（ScoreManager内の敵画面左端配置に厳密に完全固定）
const SCORE_LABEL_BASE_X: float = 1276.0
const SCORE_LABEL_BASE_Y: float = 560.0
const SCORE_LABEL_PITCH: float = 79.2
const SCORE_LABEL_BASE_SCALE: Vector2 = Vector2(0.50, 0.50)

# 事前ロード済みオーディオ（実行時ディスクI/Oフリーズ完全排除）
const SWORD_HIT_SE: AudioStream = preload("res://Sound/剣で斬る3.mp3")
const BLOCK_SE: AudioStream = preload("res://Sound/block.mp3")
const BUFF1_SE: AudioStream = preload("res://Sound/se/buff/buff.mp3")
const BUFF2_SE: AudioStream = preload("res://Sound/se/buff/buff2.mp3")
const ACCEL_SE: AudioStream = preload("res://Sound/se/patinko/acceleration_15_demo.mp3")
const UTU2_SE: AudioStream = preload("res://Sound/se/teki/utu-2.mp3")
const GAGE_HEAL_SE: AudioStream = preload("res://Sound/ゲージ回復2.mp3")
const ENEMY_ATTACK_SE: AudioStream = preload("res://Sound/se/teki/kougeki.mp3")

# スコア欄の上下運動（放物線バウンド）パラメータ (36フレーム x 3回 = 108フレーム)
const BOUNCE_CYCLE_FRAMES: int = 36  # 1回の跳ね上がり周期 (36フレーム)
const BOUNCE_CYCLES: int = 3        # 跳ねる回数 (3回)
const BOUNCE_TOTAL_FRAMES: int = BOUNCE_CYCLE_FRAMES * BOUNCE_CYCLES # 108フレーム (約1.8秒)
const BOUNCE_HEIGHT: float = 33.0   # 上下運動の跳ね上がり高さ (px)

# 攻撃フェーズで生成する剣・盾・食料・ポーションの最大上限数（描画負荷・ノード生成最適化。ダメージ・回復等は100%保持）
const MAX_COMBAT_PROJECTILES: int = 24
const ENEMY_ATTACK_MOTION_DURATION: float = 0.4
const ENEMY_ATTACK_EFFECT_TIMING: float = 0.75

# 外部ノードから参照されるプロパティ
var grid_column: int = GRID_COLUMNS
var grid_row: int = GRID_ROWS
var dx: float = OFFSET_X
var dy: float = OFFSET_Y
var cellkinds: int = CELL_KINDS

enum SpecialItemType {
	NONE = 0,
	BOMB = 1,              # フレイムボム (炎: Lv1=3x3, Lv2=5x5, Lv3=7x7)
	CROSS_BOMB = 2,        # クロスブレイズ (炎: Lv1=5x5, Lv2=9x9, Lv3=全貫通十字)
	DISCO_BALL = 3,        # スターオーブ (星: 同色全画面消滅)
	COLOR_CONVERTER = 4,   # フローラスプレー (地: 同色染め上げ)
	LIGHTNING = 5,         # ライトニング (雷: Lv1=3発, Lv2=5発, Lv3=8発追撃 + 水感電)
	BLACK_HOLE = 6,        # ブラックホール (闇: 重力吸引大消滅)
	TORNADO = 7,           # つむじ風/竜巻 (風: 一方向直進巻き上げ, Lv1=幅1, Lv2=幅3, Lv3=幅5)
	AQUA_SPLASH = 8,       # アクアスプラッシュ (水: 周囲水浸し展開, Lv1=3x3, Lv2=5x5, Lv3=広域)
	TREE_SPROUT = 9,       # 生命の苗木 (地: 水を吸って3x3大木へ進化, 毎ターン回復, 雷耐久, 火延焼)
	HOLY_LIGHT = 10,       # 聖光星・ホーリースター (光: 聖なる光を全方位へ放ち敵に光属性ダメージ+浄化)
	MAGNET = 10,           # 互換用エイリアス
	CHARGE_BOMB = 11,      # チャージボム (互換用)
	GEMINI_BOMB = 12,      # ジェミニボム (互換用)
	ICE_SHIELD = 13,       # 氷盾・氷晶 (氷: 氷結マス展開・効果進行停止)
	POISON_MIST = 14       # 薬毒瓶・ポイズンミスト (毒: 免疫薬毒マス展開)
}

# 落下時の特殊アイテム出現ウェイト（強すぎるアイテムは極小に設定）
const SPECIAL_DROP_WEIGHTS: Dictionary = {
	SpecialItemType.BOMB: 35.0,            # フレイムボム (基本炎爆破)
	SpecialItemType.TORNADO: 25.0,         # つむじ風/竜巻 (風直進巻き上げ)
	SpecialItemType.AQUA_SPLASH: 22.0,     # アクアスプラッシュ (水浸し展開)
	SpecialItemType.TREE_SPROUT: 20.0,     # 生命の苗木 (吸水・大木進化)
	SpecialItemType.LIGHTNING: 15.0,       # ライトニング (雷追撃・感電)
	SpecialItemType.CROSS_BOMB: 12.0,      # クロスブレイズ (十字炎)
	SpecialItemType.COLOR_CONVERTER: 8.0,  # フローラスプレー (同色染め)
	SpecialItemType.BLACK_HOLE: 2.0,       # ブラックホール (大消滅)
	SpecialItemType.DISCO_BALL: 1.0,       # スターオーブ (全画面消滅・極小)
	SpecialItemType.ICE_SHIELD: 20.0,      # 氷盾 (氷結展開)
	SpecialItemType.POISON_MIST: 20.0      # 薬毒 (免疫薬毒展開)
}

# 特殊アイテム駒 → 表示に使う属性（現在選択中の進化アイコンを反映）
const SPECIAL_ITEM_ELEMENT: Dictionary = {
	SpecialItemType.BOMB: "fire",
	SpecialItemType.CROSS_BOMB: "fire",
	SpecialItemType.GEMINI_BOMB: "fire",
	SpecialItemType.CHARGE_BOMB: "fire",
	SpecialItemType.LIGHTNING: "thunder",
	SpecialItemType.TORNADO: "wind",
	SpecialItemType.AQUA_SPLASH: "water",
	SpecialItemType.TREE_SPROUT: "wood",
	SpecialItemType.COLOR_CONVERTER: "wood",
	SpecialItemType.ICE_SHIELD: "ice",
	SpecialItemType.POISON_MIST: "poison",
	SpecialItemType.HOLY_LIGHT: "light",
	SpecialItemType.DISCO_BALL: "light",
	SpecialItemType.BLACK_HOLE: "dark"
}



# バフ倍率
var shieldt: float = 1.0
var swordt: float = 1.0
var coint: float = 1.0
var potiont: float = 1.0
var foodt: float = 1.0
var fever_bonus_multiplier: float = 0.0
var bomb_level: int = 0:
	get:
		return special_levels.get(SpecialItemType.BOMB, 0)
	set(val):
		special_levels[SpecialItemType.BOMB] = val
var is_bomb: Array = [] # [row][col] -> bool (後方互換用)
var special_item: Array = []   # [row][col] -> SpecialItemType (int)
var special_charge: Array = [] # [row][col] -> int (チャージ段階 1..3)
var grid_skill_owner: Array = [] # [row][col] -> int (スキル駒の所有プレイヤーindex, -1=なし/共有)
var grid_water: Array = []     # [row][col] -> bool (水浸しマス・スワップ禁止・雷感電)
var grid_ice: Array = []       # [row][col] -> int (氷漬けマス・耐久値・スワップ禁止・落雷除去不可)
const DEFAULT_FIRE_LIFETIME: int = 3 # 火の基本寿命（ターン数）
const MAX_ELECTRIFIED_TILES: int = 169 # 帯電マスの同時上限（13×13=169、全マス帯電可能）
var grid_fire: Array = []      # [row][col] -> int (0:なし, 1..N:火の残り寿命ターン数, 2:木燃焼中)
var grid_electrified: Array = [] # [row][col] -> bool (帯電コマ・触れる/マッチで反動ダメージ)

## 現在の帯電マス数を返す（上限チェック用）
func _count_electrified_tiles() -> int:
	var count: int = 0
	if grid_electrified.size() != GRID_ROWS:
		return 0
	for r in range(GRID_ROWS):
		var row: Array = grid_electrified[r]
		for c in range(GRID_COLUMNS):
			if row[c]:
				count += 1
	return count
var grid_stones: Array = []    # [row][col] -> int (石・耐久値 1)
var grid_fog: Array[Dictionary] = [] # [{"rect": Rect2i, "turns": int, "enemy_owned": bool}] (黒い霧)
var grid_cursed: Array = []    # [row][col] -> bool (呪いコマ・消すと反動ダメージ)
var grid_poison: Array = []    # [row][col] -> bool (猛毒沼マス・毎ターン毒ダメージ・マッチで解毒)
var poison_spread_done_this_turn: bool = false # 毒の侵攻（伝染）が当ターンで反映済みかフラグ
var hazard_spread_turn_counter: int = 0 # 火と毒の侵攻（伝染）ターンカウンター（2ターンに1度侵攻）
var grid_gold_statue: Array = [] # [row][col] -> int (黄金像スカコマ・耐久値 3)
var active_wind_tornadoes: Array[Dictionary] = [] # [{"col": int, "y": float, "speed": float, "active": bool, "ally": bool}]

# 自分(true) vs 他人/敵(false) のエフェクト所有者管理グリッド
var grid_water_ally: Array = []
var grid_afterburn: Array = [] # [r][c] -> bool (火種残り火トラップ)
var has_light_dazzle_this_turn: bool = false
var has_light_sanctuary_this_turn: bool = false
var has_light_tenrin_triggered_this_turn: bool = false
var turn_damage_taken: float = 0.0
var has_dark_teleport_swap: bool = false

# --- 全10属性・新進化システム状態変数 ---
var player_status_bar: RichTextLabel = null # 自軍ステータス／バフバー
var _last_player_status_text: String = "" # ???????????
var player_shock_stacks: int = 0            # ⚡ 雷B: 自軍感電スタック (最大5)
var enemy_shock_stacks: int = 0             # ⚡ 雷B: 敵軍感電スタック (最大5)
var player_blight_stacks: int = 0           # 🧪 毒B2: 自軍蝕みスタック (被毒ダメ+10%/個)
var enemy_blight_stacks: int = 0            # 🧪 毒B2: 敵軍蝕みスタック (被毒ダメ+10%/個)
var wind_ward_columns: Dictionary = {}      # 🌪️ 風C1: 風の守り {col: int -> turns: int}
var poison_seed_used_this_turn: bool = false# 🧪 毒C2: 毒の種 ターン1回制限フラグ
var free_swap_turns: int = 0                # 🌙 闇A: 重力場・特異点 自由スワップ可能ターン数
var dark_accumulated_damage: float = 0.0    # 🌙 闇C: 混沌 蓄積被ダメージ (最大5000)
var storm_zones: Dictionary = {}            # 🌪️ 風B1: 暴風圏 {col: int -> turns: int}
var delayed_explosions: Array[Dictionary] = [] # 🔥 火A2: 二段爆発 [{r, c, radius, stone_dmg, delay}]
var last_shrapnel_cleared_cells: Array[Vector2i] = [] # 🔥 火C: 破片・榴弾によって消去された駒セルリスト
var stone_turn_counts: Dictionary = {}      # 🪨 地B2: 金剛石 {Vector2i -> turns: int}
var diamond_stones: Dictionary = {}         # 🪨 地B2: ダイヤモンド化した石 {Vector2i -> bool}
var grid_poison_stage: Array = []           # 🧪 毒: 毒段階 [row][col] -> int (1..3)
var grid_ice_ally: Array = []
var grid_fire_ally: Array = []
var grid_electrified_ally: Array = []
var grid_stones_ally: Array = []
var grid_cursed_ally: Array = []
var grid_poison_ally: Array = []
var grid_gold_ally: Array = []

# プレイヤー自身の10属性スキル発動ゲージ＆UI
var player_skill_energy: float = 100.0
var player_skill_max_energy: float = 100.0
var player_skill_cost: float = 50.0
var player_skill_ui_panel: Control = null
var player_skill_energy_bar: ColorRect = null
var player_skill_energy_lbl: RichTextLabel = null
var player_skill_title_label: Label = null
var player_skill_energy_label: Label = null
var player_skill_buttons: Dictionary = {}
var enemy_skill_banner: RichTextLabel = null
var enemy_turn_skip_count: int = 0
var plant_entities: Array[Dictionary] = [] # [{"origin": Vector2i, "stage": int(0:苗,1:若木,2:大木3x3), "absorbed_water": int, "thunder_hp": int, "enemy_planted": bool, "drain_amount": int}]
var special_levels: Dictionary = {
	SpecialItemType.BOMB: 0,
	SpecialItemType.CROSS_BOMB: 0,
	SpecialItemType.DISCO_BALL: 0,
	SpecialItemType.COLOR_CONVERTER: 0,
	SpecialItemType.LIGHTNING: 0,
	SpecialItemType.BLACK_HOLE: 0,
	SpecialItemType.TORNADO: 0,
	SpecialItemType.AQUA_SPLASH: 0,
	SpecialItemType.TREE_SPROUT: 0,
	SpecialItemType.MAGNET: 0,
	SpecialItemType.CHARGE_BOMB: 0,
	SpecialItemType.GEMINI_BOMB: 0,
	SpecialItemType.ICE_SHIELD: 0,
	SpecialItemType.POISON_MIST: 0
}

var last_swap_cells: Array = []
var pending_special_spawns: Dictionary = {} # Vector2i -> int (SpecialItemType)
var poison_mist_detonated_cells: Dictionary = {}
var steady_spark_triggered_this_turn: bool = false
var current_clear_source: String = "ally" # "ally" または "enemy" (PvP前提の便益帰属管理)

# 演出用状態
var encolor: float = 1.0
var isattack: int = 0
var isblock: int = 0
var has_enemy_attacked: bool = false
var has_enemy_skilled: bool = false
var isswap: bool = false
var isbreak: bool = false
var endbreak: bool = false
var canfall: bool = false
var isgameover: bool = false

# 内部変数
var current_state: BoardState = BoardState.IDLE
var _last_hovered_cell: Vector2i = Vector2i(-1, -1)

var cellsize: Vector2 = Vector2(1.4, 1.4)
var piece: Array = []        # Sprite2Dの1次元配列
var piececollid: Array = []  # CollisionShape2D等の1次元配列

var grid_n: Array = []       # [row][col] -> 駒の種類 (0..4)
var grid_i: Array = []       # [row][col] -> piece配列内のインデックス
var grid_att: Array = []     # [row][col] -> 属性 (PieceType)
var grid_element: Array = []
var ismatched: Array = []    # [row][col] -> マッチフラグ

# 操作用（ドラッグ＆ドロップ、および2クリック選択の両対応）
var selected_cell: Vector2i = Vector2i(-1, -1)
var selected_piece_idx: int = -1
var is_holding: bool = false
var press_start_cell: Vector2i = Vector2i(-1, -1)
var hovered_swap_cell: Vector2i = Vector2i(-1, -1)
var swap_guide_overlay: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var _current_local_mouse: Vector2 = Vector2.ZERO

# 落下アニメーション管理
var falling_pieces: Array[Dictionary] = [] # {"sprite": Sprite2D, "target_y": float, "velocity_y": float, "landed": bool}
var matched_cells_list: Array[Vector2i] = [] # 現在マッチしているセルの座標リスト
var cells_cleared_by_special: Dictionary = {} # Vector2i -> bool (特殊アイテム・ボム爆発等による安全消去セル)

# タイマー・フレーム管理
var interval: int = 0
var msisvalid: bool = false
var mshisvalid: bool = false

# --- 演出用オブジェクト管理 ---
var flying_cells: Array[Dictionary] = []    # マッチしてスコア欄へ飛ぶ駒
var flying_swords: Array[Dictionary] = []   # 剣
var active_shields: Array[Dictionary] = []  # 展開シールド
var current_total_shields: int = 0
var current_shield_pools: Dictionary = {}          # 生成総数（1000個制限後も被ダメージ軽減計算に使用）
var flying_foods: Array[Dictionary] = []    # 食料
var flying_potions: Array[Dictionary] = []  # ポーション

var scratch_effect: AnimatedSprite2D = null
var is_casting_skill_turn: bool = false
var _last_spark_msec: int = 0
var _last_shockwave_msec: int = 0
var _sword_hit_sound_timer: float = 0.0
const SWORD_HIT_SOUND_INTERVAL: float = 0.11  # 剣衝突音（SE）再生の最小インターバル（約0.11秒）

# ノード参照
var score_manager: Node2D = null
@onready var board_bg = get_node_or_null("BoardBackground")
var mark_overlay: Node2D = null
var board_overlay: Node2D = null

# パフォーマンス最適化用フラグ（毎フレームの全マス走査・無駄な再描画を完全に抑止）
var has_special_items: bool = false
var has_board_hazards: bool = false
# 脈動・揺らめき等の常時アニメーションを持つ障害物があるか（石のみの場合は false → 定期再描画不要）
var has_animated_board_hazards: bool = false
# 常時アニメーションする効果マスの概算数（描画間引きの判定用）
var animated_hazard_count: int = 0
var has_ice: bool = false
var has_stones: bool = false
var has_gold_statue: bool = false
var has_electrified: bool = false
var has_cursed: bool = false
var has_water: bool = false
var has_poison: bool = false
var has_fire: bool = false
var special_item_coords: Array[Vector2i] = []
var _special_icon_cache: Dictionary = {}

func _update_board_element_flags() -> void:
	var old_has_special = has_special_items
	var new_coords: Array[Vector2i] = []
	var new_coord_set: Dictionary = {}
	# 残骸掃除用の配列サイズ判定（関数スコープで保持）
	var st_arr_ok: bool = grid_stones.size() == GRID_ROWS
	var ps_arr_ok: bool = grid_poison.size() == GRID_ROWS
	has_special_items = false

	if is_bomb.size() == GRID_ROWS and special_item.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if is_bomb[r][c] or special_item[r][c] != SpecialItemType.NONE:
					var coord = Vector2i(r, c)
					new_coords.append(coord)
					new_coord_set[coord] = true
					has_special_items = true

	if old_has_special:
		for coord in special_item_coords:
			if not new_coord_set.has(coord):
				var p_idx = grid_i[coord.x][coord.y] if grid_i.size() == GRID_ROWS else -1
				if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null and is_instance_valid(piece[p_idx]):
					piece[p_idx].modulate = Color.WHITE
	special_item_coords = new_coords

	has_board_hazards = false
	has_animated_board_hazards = false
	animated_hazard_count = active_wind_tornadoes.size() * 6 + plant_entities.size() * 4 + grid_fog.size() * 9
	has_ice = false
	has_stones = false
	has_gold_statue = false
	has_electrified = false
	has_cursed = false
	has_water = false
	has_poison = false
	has_fire = false

	if not active_wind_tornadoes.is_empty() or not plant_entities.is_empty() or not grid_fog.is_empty():
		has_board_hazards = true
		has_animated_board_hazards = true

	if grid_ice.size() == GRID_ROWS:
		var w_ok: bool = grid_water.size() == GRID_ROWS
		var ps_ok: bool = grid_poison.size() == GRID_ROWS
		var el_ok: bool = grid_electrified.size() == GRID_ROWS
		var cu_ok: bool = grid_cursed.size() == GRID_ROWS
		var gd_ok: bool = grid_gold_statue.size() == GRID_ROWS
		var fr_ok: bool = grid_fire.size() == GRID_ROWS
		var ps_st_ok: bool = grid_poison_stage.size() == GRID_ROWS
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				var is_w: bool = w_ok and grid_water[r][c]
				var is_st: bool = st_arr_ok and grid_stones[r][c] > 0
				var is_ps: bool = ps_ok and grid_poison[r][c]
				var is_el: bool = el_ok and grid_electrified[r][c]
				var is_cu: bool = cu_ok and grid_cursed[r][c]
				var is_ic: bool = (grid_ice[r][c] > 0)
				var is_gd: bool = gd_ok and grid_gold_statue[r][c] > 0
				var is_fr: bool = fr_ok and grid_fire[r][c] > 0

				if is_w: has_water = true
				if is_st: has_stones = true
				if is_ps: has_poison = true
				if is_el: has_electrified = true
				if is_cu: has_cursed = true
				if is_ic: has_ice = true
				if is_gd: has_gold_statue = true
				if is_fr: has_fire = true

				if is_st or is_el or is_cu or is_ic or is_gd or is_fr or is_w or is_ps:
					has_board_hazards = true
				if is_el or is_cu or is_ic or is_gd or is_fr or is_w:
					has_animated_board_hazards = true
					# 帯電・氷・黄金像は描画コストが高いため重み付けして間引きを早める
					animated_hazard_count += 2 if (is_el or is_ic or is_gd) else 1

				# 消えた効果マスの残骸（毒段階・石カウント）をここで掃除して
				# バックグラウンドに状態が残り続けないようにする
				if ps_st_ok and not is_ps and grid_poison_stage[r][c] != 1:
					grid_poison_stage[r][c] = 1

	# 消えた石のカウント辞書を掃除して辞書が増え続けないようにする
	if not stone_turn_counts.is_empty() or not diamond_stones.is_empty():
		for st_pos in stone_turn_counts.keys():
			if not (st_arr_ok and grid_stones[st_pos.x][st_pos.y] > 0):
				stone_turn_counts.erase(st_pos)
		for d_pos in diamond_stones.keys():
			if not (st_arr_ok and grid_stones[d_pos.x][d_pos.y] > 0):
				diamond_stones.erase(d_pos)
	# 消えた毒マスの起爆記録を掃除
	if not poison_mist_detonated_cells.is_empty():
		for pm_pos in poison_mist_detonated_cells.keys():
			if not (ps_arr_ok and grid_poison[pm_pos.x][pm_pos.y]):
				poison_mist_detonated_cells.erase(pm_pos)


## 盤面描画の一括更新（盤面状態の変化時に呼ばれる＝イベント駆動の即時再描画）
## ※ queue_redraw() は同一フレーム内で何度呼んでも Godot 側で1回に集約される
func _redraw_board_effects() -> void:
	_update_board_element_flags()
	# board_bg は静的な盤面装飾と選択ハイライトのみを描画する。
	# 効果マスの変化では再描画不要なため、ここでは要求しない（毎回の重い背景再描画を回避）。
	# 効果マスが全て消えた場合も必ず再描画し、消えた描画が盤面に残り続けないようにする
	if board_overlay and board_overlay.has_method("queue_redraw_throttled"):
		board_overlay.queue_redraw_throttled()
	elif board_overlay:
		board_overlay.queue_redraw()
	# 特殊アイテムが消滅した時も必ず再描画し、消えたアイコンが盤面に残り続けないようにする
	if mark_overlay: mark_overlay.queue_redraw()

# 特殊アイテム演出（明滅・マーク脈動）の更新間隔（秒）。時間ベースの演出なので速度は変わらない
const SPECIAL_FX_UPDATE_INTERVAL: float = 1.0 / 30.0
var _special_fx_elapsed: float = 0.0

# 戦闘演出・発射物シミュレーションの速度累積変数
var _turn_sim_accumulator: float = 0.0

# --- 放置デモ再生用 ---
var _demo_idle_timer: float = 0.0

## あるマスと、その上下左右をつないだ3つ以上の同種コマができるか判定
func _demo_would_match(r: int, c: int) -> bool:
	var t = grid_n[r][c]
	if t == -1:
		return false
	var cnt: int = 1
	var cc: int = c - 1
	while cc >= 0 and grid_n[r][cc] == t:
		cnt += 1; cc -= 1
	cc = c + 1
	while cc < GRID_COLUMNS and grid_n[r][cc] == t:
		cnt += 1; cc += 1
	if cnt >= 3:
		return true
	cnt = 1
	var rr: int = r - 1
	while rr >= 0 and grid_n[rr][c] == t:
		cnt += 1; rr -= 1
	rr = r + 1
	while rr < GRID_ROWS and grid_n[rr][c] == t:
		cnt += 1; rr += 1
	return cnt >= 3

## 盤面から「マッチが発生する入れ替え」を1つ探す（デモ再生用）
func _find_valid_demo_swap() -> Array[Vector2i]:
	if grid_n.size() != GRID_ROWS:
		return []
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_n[r][c] == -1:
				continue
			for d in dirs:
				var r2: int = r + d.x
				var c2: int = c + d.y
				if r2 < 0 or r2 >= GRID_ROWS or c2 < 0 or c2 >= GRID_COLUMNS:
					continue
				if grid_n[r2][c2] == -1 or grid_n[r2][c2] == grid_n[r][c]:
					continue
				var t1 = grid_n[r][c]
				var t2 = grid_n[r2][c2]
				grid_n[r][c] = t2
				grid_n[r2][c2] = t1
				var ok: bool = _demo_would_match(r, c) or _demo_would_match(r2, c2)
				grid_n[r][c] = t1
				grid_n[r2][c2] = t2
				if ok:
					return [Vector2i(r, c), Vector2i(r2, c2)]
	return []

## 放置デモ中は「マッチが発生する手」を選んで駒を入れ替える
func _demo_auto_swap() -> void:
	if current_state != BoardState.IDLE or is_enemy_turn_in_progress:
		return
	var move: Array[Vector2i] = _find_valid_demo_swap()
	if move.size() == 2:
		_execute_swap(move[0].x, move[0].y, move[1].x, move[1].y)
		return
	# 有効手が無い場合はランダムに入れ替えて盤面を動かす
	var r: int = _board_randi() % GRID_ROWS
	var c: int = _board_randi() % GRID_COLUMNS
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	var d: Vector2i = dirs[_board_randi() % 2]
	var r2: int = r + d.x
	var c2: int = c + d.y
	if r2 >= 0 and r2 < GRID_ROWS and c2 >= 0 and c2 < GRID_COLUMNS:
		_execute_swap(r, c, r2, c2)

var _cached_stage_manager: Node2D = null

## 現在のゲーム設定速度を取得（SettingsManager優先、FallbackはEngine.time_scale）
func _get_game_speed() -> float:
	var sm = _get_settings_manager()
	if sm and "game_speed" in sm:
		return sm.game_speed
	return Engine.time_scale

func _get_stage_manager() -> Node2D:
	if _cached_stage_manager == null or not is_instance_valid(_cached_stage_manager):
		var p = get_parent()
		_cached_stage_manager = p.get_node_or_null("StageManager") if p else null
	return _cached_stage_manager

func _get_score_manager() -> Node2D:
	if score_manager == null:
		var p = get_parent()
		if p:
			score_manager = p.get_node_or_null("ScoreManager")
	return score_manager

## セルのローカル座標を取得
func get_cell_position(r: int, c: int) -> Vector2:
	return Vector2(BOARD_LEFT + (float(c) + 0.5) * CELL_PITCH, BOARD_TOP + (float(r) + 0.5) * CELL_PITCH)

## スコア欄ラベルをゲーム開始時の初期位置に厳密に復帰
func _restore_score_label_positions() -> void:
	var sm = _get_score_manager()
	if sm:
		for i in range(5):
			var lbl = sm.get_node_or_null("score" + str(i))
			if lbl:
				lbl.position.x = SCORE_LABEL_BASE_X
				lbl.position.y = SCORE_LABEL_BASE_Y + SCORE_LABEL_PITCH * i
				lbl.scale = SCORE_LABEL_BASE_SCALE
				lbl.modulate = Color.WHITE
			var icn = sm.get_node_or_null("score_icon" + str(i))
			if icn:
				icn.position.x = 1204.0
				icn.position.y = 546.0 + 79.2 * float(i) + 16.6



# --- POOLING ---
const SE_POOL_SIZE = 8
var _se_pool: Array[AudioStreamPlayer] = []

const SPRITE_POOL_SIZE = 64
var _sprite_pool: Array[Sprite2D] = []

func _init_pools() -> void:
	for i in range(SE_POOL_SIZE):
		var asp = AudioStreamPlayer.new()
		Profiler.add_child_count += 1; add_child(asp)
		_se_pool.append(asp)
	for i in range(SPRITE_POOL_SIZE):
		var sp = Sprite2D.new()
		sp.visible = false
		Profiler.add_child_count += 1; add_child(sp)
		_sprite_pool.append(sp)

func _play_pooled_se(stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null: return
	for asp in _se_pool:
		if not asp.playing:
			asp.stream = stream
			asp.volume_db = vol_db
			asp.pitch_scale = pitch
			asp.play()
			return
	var fallback = _se_pool[0]
	fallback.stream = stream
	fallback.volume_db = vol_db
	fallback.pitch_scale = pitch
	fallback.play()

func _get_sprite_from_pool() -> Sprite2D:
	for s in _sprite_pool:
		if not s.visible:
			s.visible = true
			s.modulate = Color.WHITE
			s.rotation = 0.0
			s.scale = Vector2.ONE
			s.z_index = 0
			s.texture = null
			return s
	var new_s = Sprite2D.new()
	Profiler.add_child_count += 1; add_child(new_s)
	_sprite_pool.append(new_s)
	return new_s

func _return_sprite_to_pool(s: Sprite2D) -> void:
	if is_instance_valid(s):
		s.visible = false
		s.position = Vector2(-1e9, -1e9)
		if s.get_parent() == null:
			Profiler.add_child_count += 1; add_child(s)

# --- POOLING END ---
func _ready() -> void:
	var CombatUIManager = load("res://combat_ui_manager.gd")
	if CombatUIManager:
		combat_ui_manager = CombatUIManager.new()
		combat_ui_manager.name = "CombatUIManager"
		add_child(combat_ui_manager)
		combat_event.connect(combat_ui_manager._on_combat_event)
	_init_pools()
	score_manager = _get_score_manager()
	if board_bg:
		board_bg.board = self
		board_bg.queue_redraw()

	# 属性妨害エフェクト・障害物のオーバーレイ (z_index = 8)
	var overlay_script = preload("res://board_overlay.gd")
	board_overlay = overlay_script.new()
	board_overlay.name = "BoardOverlay"
	board_overlay.board = self
	Profiler.add_child_count += 1; add_child(board_overlay)
	
	# 特殊アイテムのシンプルシンボルマーク（雷マーク⚡等）を描画する最前面レイヤー
	var ov = SpecialMarkOverlayNode.new()
	ov.name = "SpecialMarkOverlay"
	ov.board = self
	ov.z_index = 15
	mark_overlay = ov
	Profiler.add_child_count += 1; add_child(mark_overlay)

	# 隣接移動方向の強調表示レイヤー (z_index = 11、通常コマの上、ドラッグ中コマと同等)
	var sg_ov = SwapGuideOverlayNode.new()
	sg_ov.name = "SwapGuideOverlay"
	sg_ov.board = self
	sg_ov.z_index = 11
	swap_guide_overlay = sg_ov
	Profiler.add_child_count += 1; add_child(swap_guide_overlay)
	
	var rensa_se = get_node_or_null("1rensa")
	if rensa_se:
		rensa_se.pitch_scale = 0.92

	var sword_se = get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	if sword_se:
		sword_se.max_polyphony = 1
		sword_se.volume_db = -7.5

	# 敵攻撃用SEプレイヤーの事前インスタンス化
	var enemy_atk_se = AudioStreamPlayer.new()
	enemy_atk_se.name = "enemy_attack_se"
	Profiler.add_child_count += 1; add_child(enemy_atk_se)

	var enemy_hit_se = AudioStreamPlayer.new()
	enemy_hit_se.name = "enemy_hit_se"
	Profiler.add_child_count += 1; add_child(enemy_hit_se)

	# シーン上のテンプレートスプライトを画面外に退避して非表示化
	for i in range(5):
		var t_sprite = get_node_or_null("Sprite2D" + str(i))
		if t_sprite:
			t_sprite.position = Vector2(-1000000.0, -1000000.0)
			t_sprite.visible = false

	var collid_template: Node = null
	var area_node = get_node_or_null("Area2D")
	if area_node and area_node.get_child_count() > 0:
		collid_template = area_node.get_child(0)

	_initialize_board(collid_template)
	_restore_score_label_positions()
	_ensure_player_status_bar()
	_update_status_ailments()

## 盤面の初期化（初期状態で3マッチが発生しないよう配置・定数テクスチャによる確実な属性紐付け）
## ScoreManagerのスキルツリーで解放されたスキルレベルを盤面に同期
func sync_special_levels_from_score_manager() -> void:
	var sm = _get_score_manager()
	if sm and "skill_tree_items" in sm:
		for s_item in sm.skill_tree_items:
			var lvl: int = int(s_item.get("level", 0))
			var sp_type: int = int(s_item.get("sp_type", -1))
			if sp_type > 0:
				special_levels[sp_type] = lvl

func _initialize_board(collid_template: Node) -> void:
	is_tutorial_paused = false
	selected_cell = Vector2i(-1, -1)
	selected_piece_idx = -1
	is_holding = false
	drag_offset = Vector2.ZERO
	press_start_cell = Vector2i(-1, -1)
	hovered_swap_cell = Vector2i(-1, -1)
	has_emitted_items_scored = false
	enemy_shock_stacks = 0
	player_shock_stacks = 0
	enemy_turn_skip_count = 0
	_ensure_board_rng_initialized()
	sync_special_levels_from_score_manager()
	_clear_all_combat_projectiles()
	grid_n.clear()
	grid_i.clear()
	ismatched.clear()
	grid_att.clear()
	piece.clear()
	piececollid.clear()
	is_bomb.clear()
	special_item.clear()
	special_charge.clear()
	grid_water.clear()
	grid_ice.clear()
	grid_fire.clear()
	grid_electrified.clear()
	grid_stones.clear()
	grid_fog.clear()
	grid_cursed.clear()
	grid_poison.clear()
	grid_gold_statue.clear()
	plant_entities.clear()
	stone_turn_counts.clear()
	diamond_stones.clear()
	active_wind_tornadoes.clear()
	storm_zones.clear()
	wind_ward_columns.clear()
	delayed_explosions.clear()
	last_shrapnel_cleared_cells.clear()
	_init_ally_grids()

	var area_node = get_node_or_null("Area2D")

	for i in range(GRID_ROWS):
		var row_n: Array[int] = []
		var row_i: Array[int] = []
		var row_matched: Array[bool] = []
		var row_att: Array[int] = []
		var row_bomb: Array[bool] = []
		var row_special: Array[int] = []
		var row_charge: Array[int] = []
		var row_water: Array[bool] = []
		var row_ice: Array = []
		var row_fire: Array[int] = []
		var row_electrified: Array[bool] = []
		var row_stones: Array[int] = []
		var row_cursed: Array[bool] = []
		var row_poison: Array[bool] = []
		var row_gold_statue: Array[int] = []
		var row_skill_owner: Array[int] = []
		var row_element: Array[int] = []

		row_poison.resize(GRID_COLUMNS)
		row_poison.fill(false)

		for j in range(GRID_COLUMNS):
			var can_set: Array[bool] = []
			can_set.resize(CELL_KINDS)
			can_set.fill(true)

			if i >= 2 and grid_n[i - 1][j] == grid_n[i - 2][j]:
				can_set[grid_n[i - 1][j]] = false
			if j >= 2 and row_n[j - 1] == row_n[j - 2]:
				can_set[row_n[j - 1]] = false

			var available_kinds: Array[int] = []
			for k in range(CELL_KINDS):
				if can_set[k]:
					available_kinds.append(k)

			var chosen_kind: int = available_kinds[_board_randi() % available_kinds.size()]
			var piece_idx: int = i * GRID_COLUMNS + j

			row_n.append(chosen_kind)
			row_i.append(piece_idx)
			row_matched.append(false)
			row_att.append(chosen_kind % 5)
			row_element.append(ElementDataScript.Element.NONE)
			row_bomb.append(false)
			row_special.append(SpecialItemType.NONE)
			row_charge.append(0)
			row_water.append(false)
			row_ice.append(0)
			row_fire.append(0)
			row_electrified.append(false)
			row_stones.append(0)
			row_cursed.append(false)
			row_gold_statue.append(0)
			row_skill_owner.append(-1)

			var pos = get_cell_position(i, j)

			# 定数テクスチャ配列から確実に正しい絵柄のスプライトを生成
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = PIECE_TEXTURES[chosen_kind]
			sprite.position = pos
			sprite.scale = cellsize
			sprite.modulate = Color.WHITE
			_add_element_mark_to_sprite(sprite)
			Profiler.add_child_count += 1; add_child(sprite)
			piece.append(sprite)
			piececollid.append(null)

		grid_n.append(row_n)
		grid_i.append(row_i)
		ismatched.append(row_matched)
		grid_att.append(row_att)
		grid_element.append(row_element)
		is_bomb.append(row_bomb)
		special_item.append(row_special)
		special_charge.append(row_charge)
		grid_water.append(row_water)
		grid_ice.append(row_ice)
		grid_fire.append(row_fire)
		grid_electrified.append(row_electrified)
		grid_stones.append(row_stones)
		grid_cursed.append(row_cursed)
		grid_poison.append(row_poison)
		grid_gold_statue.append(row_gold_statue)
		grid_skill_owner.append(row_skill_owner)

	current_state = BoardState.IDLE
	var rm = _get_relic_manager()
	if rm: rm.on_turn_start()
	_spawn_turn_specials()
	_setup_player_skill_ui()
	if board_bg: board_bg.queue_redraw()
	_redraw_board_effects()

func _init_ally_grids() -> void:
	grid_water_ally.clear()
	grid_ice_ally.clear()
	grid_fire_ally.clear()
	grid_electrified_ally.clear()
	grid_stones_ally.clear()
	grid_cursed_ally.clear()
	grid_poison_ally.clear()
	grid_gold_ally.clear()
	grid_poison_stage.clear()
	for _r in range(GRID_ROWS):
		var p_stage_row: Array[int] = []
		p_stage_row.resize(GRID_COLUMNS)
		p_stage_row.fill(1)
		grid_poison_stage.append(p_stage_row)
	grid_afterburn.clear()
	for _r in range(GRID_ROWS):
		var ab_row: Array[bool] = []; ab_row.resize(GRID_COLUMNS); ab_row.fill(false); grid_afterburn.append(ab_row)
	for _r in range(GRID_ROWS):
		var rw: Array[bool] = []; rw.resize(GRID_COLUMNS); rw.fill(false); grid_water_ally.append(rw)
		var ri: Array[bool] = []; ri.resize(GRID_COLUMNS); ri.fill(false); grid_ice_ally.append(ri)
		var rf: Array[bool] = []; rf.resize(GRID_COLUMNS); rf.fill(false); grid_fire_ally.append(rf)
		var re: Array[bool] = []; re.resize(GRID_COLUMNS); re.fill(false); grid_electrified_ally.append(re)
		var rs: Array[bool] = []; rs.resize(GRID_COLUMNS); rs.fill(false); grid_stones_ally.append(rs)
		var rc: Array[bool] = []; rc.resize(GRID_COLUMNS); rc.fill(false); grid_cursed_ally.append(rc)
		var rp: Array[bool] = []; rp.resize(GRID_COLUMNS); rp.fill(false); grid_poison_ally.append(rp)
		var rg: Array[bool] = []; rg.resize(GRID_COLUMNS); rg.fill(false); grid_gold_ally.append(rg)

func _ensure_ally_grids() -> void:
	if grid_water_ally.size() != GRID_ROWS:
		_init_ally_grids()

func _get_ally_flag(arr: Array, r: int, c: int) -> bool:
	if arr.size() == GRID_ROWS and r >= 0 and r < GRID_ROWS and c >= 0 and c < arr[r].size():
		return bool(arr[r][c])
	return false

func _set_ally_flag(arr: Array, r: int, c: int, val: bool) -> void:
	_ensure_ally_grids()
	if arr.size() == GRID_ROWS and r >= 0 and r < GRID_ROWS and c >= 0 and c < arr[r].size():
		arr[r][c] = val

func is_ally_water(r: int, c: int) -> bool: return _get_ally_flag(grid_water_ally, r, c)
func is_ally_ice(r: int, c: int) -> bool: return _get_ally_flag(grid_ice_ally, r, c)
func is_ally_fire(r: int, c: int) -> bool: return _get_ally_flag(grid_fire_ally, r, c)
func is_ally_electrified(r: int, c: int) -> bool: return _get_ally_flag(grid_electrified_ally, r, c)
func is_ally_stone(r: int, c: int) -> bool: return _get_ally_flag(grid_stones_ally, r, c)
func is_ally_cursed(r: int, c: int) -> bool: return _get_ally_flag(grid_cursed_ally, r, c)
func is_ally_poison(r: int, c: int) -> bool: return _get_ally_flag(grid_poison_ally, r, c)
func is_ally_gold(r: int, c: int) -> bool: return _get_ally_flag(grid_gold_ally, r, c)

func is_ally_plant(plant: Dictionary) -> bool:
	return not plant.get("enemy_planted", false)

func _trait_matches(evo_data, trait_id: String) -> bool:
	if evo_data is String:
		return evo_data == trait_id
	elif evo_data is Array:
		return trait_id in evo_data
	elif evo_data is Dictionary:
		if evo_data.has(trait_id): return true
		for v in evo_data.values():
			if _trait_matches(v, trait_id): return true
	return false

## 自軍(is_ally=true)または敵軍(is_ally=false)が指定の属性・進化スキルを所持しているか判定
func has_actor_skill_trait(is_ally: bool, element: String, trait_id: String, enemy_dict: Dictionary = {}) -> bool:
	if is_ally:
		var sm = _get_score_manager()
		if sm and sm.has_method("has_skill_trait"):
			var sk_id = element + "_1" if not element.ends_with("_1") else element
			return sm.has_skill_trait(sk_id, trait_id)
		return false
	else:
		if not enemy_dict.is_empty():
			var evos = enemy_dict.get("evolutions", null)
			if _trait_matches(evos, trait_id): return true
			var el_evo = enemy_dict.get(element + "_evolutions", null)
			if _trait_matches(el_evo, trait_id): return true
			return false
		var st_mgr = _get_stage_manager()
		if st_mgr and ("active_enemies" in st_mgr):
			for e in st_mgr.active_enemies:
				if e is Dictionary:
					var evos = e.get("evolutions", null)
					if _trait_matches(evos, trait_id): return true
					var el_evo = e.get(element + "_evolutions", null)
					if _trait_matches(el_evo, trait_id): return true
		return false

## プレイヤー用状態異常・バフバーの遅延初期化
func _ensure_player_status_bar() -> void:
	if player_status_bar != null and is_instance_valid(player_status_bar):
		return
	var sm = _get_stage_manager()
	player_status_bar = RichTextLabel.new()
	player_status_bar.name = "PlayerStatusBar"
	player_status_bar.bbcode_enabled = true
	player_status_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	player_status_bar.fit_content = true
	player_status_bar.scroll_active = false
	player_status_bar.autowrap_mode = TextServer.AUTOWRAP_OFF
	player_status_bar.add_theme_constant_override("outline_size", 4)
	player_status_bar.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	player_status_bar.add_theme_font_override("normal_font", _get_skill_ui_font())
	player_status_bar.add_theme_font_override("bold_font", _get_skill_ui_font())
	player_status_bar.add_theme_font_size_override("normal_font_size", 13)
	player_status_bar.size = Vector2(725, 24)
	player_status_bar.position = Vector2(1190, 440)
	player_status_bar.z_index = 12
	if sm and is_instance_valid(sm):
		sm.add_child(player_status_bar)
	else:
		add_child(player_status_bar)

## プレイヤー及び敵頭上の状態異常・バフ表示の同期更新（完全対称設計）
func _update_status_ailments() -> void:
	_ensure_player_status_bar()
	var sm = _get_stage_manager()

	# 盤面上のオブジェクト・ハザード集計
	var ally_poi_cnt = 0
	var enemy_poi_cnt = 0
	if grid_poison.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_poison[r][c]:
					if is_ally_poison(r, c): ally_poi_cnt += 1
					else: enemy_poi_cnt += 1

	var ally_fire_cnt = 0
	var enemy_fire_cnt = 0
	if grid_fire.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_fire[r][c] > 0:
					if is_ally_fire(r, c): ally_fire_cnt += 1
					else: enemy_fire_cnt += 1

	var ally_ice_cnt = 0
	var enemy_ice_cnt = 0
	if grid_ice.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if int(grid_ice[r][c]) > 0:
					if is_ally_ice(r, c): ally_ice_cnt += 1
					else: enemy_ice_cnt += 1

	var ally_plant_cnt = 0
	var enemy_plant_cnt = 0
	for pl in plant_entities:
		if is_ally_plant(pl): ally_plant_cnt += 1
		else: enemy_plant_cnt += 1

	var ally_st_cnt = 0
	var enemy_st_cnt = 0
	if grid_stones.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_stones[r][c] > 0:
					if is_ally_stone(r, c): ally_st_cnt += 1
					else: enemy_st_cnt += 1

	# --- プレイヤー用バフ／デバフ文字列構築 ---
	var p_tags: Array[String] = []
	# 毒 vs 免疫（相手の毒があれば毒、自分の毒があれば免疫）
	if enemy_poi_cnt > 0:
		p_tags.append("[color=#CC44FF]☠️毒(%d)[/color]" % enemy_poi_cnt)
	if ally_poi_cnt > 0:
		var imm_pct = mini(40, ally_poi_cnt * 5)
		p_tags.append("[color=#44FF88]🛡️免疫(%d%%)[/color]" % imm_pct)
	if enemy_fire_cnt > 0:
		p_tags.append("[color=#FF5533]🔥火傷(%d)[/color]" % enemy_fire_cnt)
	if player_shock_stacks > 0:
		p_tags.append("[color=#FFE044]⚡感電(x%d)[/color]" % player_shock_stacks)
	if player_blight_stacks > 0:
		p_tags.append("[color=#AA22AA]🧪蝕み(x%d)[/color]" % player_blight_stacks)
	if ally_plant_cnt > 0 and has_actor_skill_trait(true, "wood", "wood_final_b1"):
		p_tags.append("[color=#66DD66]🌱森の加護(-%d%%)[/color]" % mini(40, ally_plant_cnt * 5))
	if ally_st_cnt > 0 and has_actor_skill_trait(true, "earth", "earth_final_a1"):
		p_tags.append("[color=#DDAA66]🪨城壁(-%d%%)[/color]" % mini(40, ally_st_cnt * 5))
	if enemy_ice_cnt > 0 and has_actor_skill_trait(false, "ice", "ice_final_c1"):
		p_tags.append("[color=#88DDFF]❄️寒気(-%d%%)[/color]" % mini(30, enemy_ice_cnt * 3))
	if enemy_poi_cnt > 0 and has_actor_skill_trait(false, "poison", "poison_mid_c"):
		p_tags.append("[color=#AA66DD]🧪弱体(-%d%%)[/color]" % mini(30, enemy_poi_cnt * 3))
	if current_total_shields > 0:
		p_tags.append("[color=#66CCFF]🛡️シールド(%d)[/color]" % current_total_shields)

	if player_status_bar != null and is_instance_valid(player_status_bar):
		var new_p_text: String = " ".join(p_tags)
		# 文字列が変わっていない場合は RichTextLabel の再レイアウトを避ける
		if new_p_text != _last_player_status_text:
			_last_player_status_text = new_p_text
			player_status_bar.text = new_p_text

	# --- 各敵頭上ステータスバー更新（プレイヤーと真逆） ---
	if sm and ("active_enemies" in sm):
		for e in sm.active_enemies:
			if not (e is Dictionary): continue
			var e_bar = e.get("status_bar", null)
			if e_bar == null or not is_instance_valid(e_bar): continue

			var e_tags: Array[String] = []
			# 敵スキルのレベル・進化度合い（ステージに応じて上昇）を明示
			var evo_d: Dictionary = e.get("evolutions", {})
			var evo_lv: int = 0
			var evo_txt: String = "未進化"
			for evo_k in evo_d.keys():
				var evo_v = evo_d[evo_k]
				if evo_v is Dictionary:
					evo_lv = maxi(evo_lv, int(evo_v.get("level", 0)))
					if str(evo_v.get("final", "")) != "":
						evo_txt = "最終進化"
					elif str(evo_v.get("mid", "")) != "" and evo_txt != "最終進化":
						evo_txt = "中間進化"
			if evo_lv <= 0:
				var s_idx: int = clampi(int(sm.get("stage")) if (sm and "stage" in sm) else 1, 1, 5)
				var b_idx: int = clampi(int(sm.get("stage_enemy")) if (sm and "stage_enemy" in sm) else 1, 1, 5)
				evo_lv = clampi((s_idx - 1) * 5 + b_idx, 1, 20)
			e_tags.append("[color=#FFD54F]⭐ スキルLv%d %s[/color]" % [evo_lv, evo_txt])
			# 敵の毒 vs 免疫（味方の毒があれば毒、敵自身の毒があれば免疫）
			if ally_poi_cnt > 0:
				e_tags.append("[color=#CC44FF]☠️毒(%d)[/color]" % ally_poi_cnt)
			if enemy_poi_cnt > 0:
				var imm_pct = mini(40, enemy_poi_cnt * 5)
				e_tags.append("[color=#44FF88]🛡️免疫(%d%%)[/color]" % imm_pct)
			if ally_fire_cnt > 0:
				e_tags.append("[color=#FF5533]🔥火傷(%d)[/color]" % ally_fire_cnt)
			if enemy_shock_stacks > 0:
				e_tags.append("[color=#FFE044]⚡感電(x%d)[/color]" % enemy_shock_stacks)
			if enemy_blight_stacks > 0:
				e_tags.append("[color=#AA22AA]🧪蝕み(x%d)[/color]" % enemy_blight_stacks)
			if enemy_plant_cnt > 0 and has_actor_skill_trait(false, "wood", "wood_final_b1", e):
				e_tags.append("[color=#66DD66]🌱森の加護(-%d%%)[/color]" % mini(40, enemy_plant_cnt * 5))
			if enemy_st_cnt > 0 and has_actor_skill_trait(false, "earth", "earth_final_a1", e):
				e_tags.append("[color=#DDAA66]🪨城壁(-%d%%)[/color]" % mini(40, enemy_st_cnt * 5))
			if ally_ice_cnt > 0 and has_actor_skill_trait(true, "ice", "ice_final_c1"):
				e_tags.append("[color=#88DDFF]❄️寒気(-%d%%)[/color]" % mini(30, ally_ice_cnt * 3))
			if ally_poi_cnt > 0 and has_actor_skill_trait(true, "poison", "poison_mid_c"):
				e_tags.append("[color=#AA66DD]🧪弱体(-%d%%)[/color]" % mini(30, ally_poi_cnt * 3))
			var cur_sh = int(e.get("shield", 0.0))
			if cur_sh > 0:
				e_tags.append("[color=#66CCFF]🛡️シールド(%d)[/color]" % cur_sh)

			var last_e_text: String = str(e.get("last_status_text", ""))
			var new_e_text: String = " ".join(e_tags)
			# 文字列が変わっていない場合は RichTextLabel の再レイアウトを避ける
			if new_e_text != last_e_text:
				e["last_status_text"] = new_e_text
				e_bar.text = new_e_text

func _update_turn_combat_status_tags(_sm: Node2D = null) -> void:
	_update_status_ailments()

## 盤面が完全に停止・安定した「定常状態」にあるかを判定
func is_steady_state() -> bool:
	if current_state != BoardState.IDLE:
		return false
	if not falling_pieces.is_empty():
		return false
	if not flying_cells.is_empty():
		return false
	if not flying_swords.is_empty() or not flying_foods.is_empty() or not flying_potions.is_empty() or (not pvp_mode and not active_shields.is_empty()):
		return false
	if is_enemy_turn_in_progress or isswap or isbreak:
		return false
	if selected_cell.x != -1:
		return false
	return true

# --- マウス入力とスワップ処理 ---

func _get_mouse_local(event: InputEvent = null) -> Vector2:
	if event is InputEventMouse:
		return to_local(event.position)
	if is_inside_tree():
		return get_local_mouse_position()
	elif get_viewport() != null:
		return to_local(get_viewport().get_mouse_position())
	return Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# フィーバータイムの突入文字が表示されている間は盤面操作を完全に遮断する
	var fever_sm = _get_stage_manager()
	if fever_sm and fever_sm.isfevertime and not pvp_mode and (fever_sm.is_waiting_for_fever_se or fever_sm.appeartime < 15):
		if selected_cell.x != -1:
			_deselect_piece()
		is_holding = false
		_hide_cell_hover_tooltip()
		return

	if event is InputEventMouseMotion:
		_current_local_mouse = _get_mouse_local(event)
		if selected_cell.x != -1 and current_state == BoardState.IDLE:
			if is_holding and selected_piece_idx >= 0 and selected_piece_idx < piece.size() and piece[selected_piece_idx] != null:
				var clamped_pos = _current_local_mouse + drag_offset
				clamped_pos.x = clampf(clamped_pos.x, BOARD_LEFT, BOARD_RIGHT)
				clamped_pos.y = clampf(clamped_pos.y, BOARD_TOP, BOARD_BOTTOM)
				piece[selected_piece_idx].position = clamped_pos
			_update_hovered_swap_direction(_current_local_mouse)
			if swap_guide_overlay:
				swap_guide_overlay.queue_redraw()
			_hide_cell_hover_tooltip()
		else:
			_update_cell_hover_tooltip(event.position)
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_event = event as InputEventMouseButton
	_hide_cell_hover_tooltip()
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var sm = _get_stage_manager()

	# ゲームオーバー判定：体力が0またはゲームオーバー時はすべての盤面入力を遮断
	if isgameover or (sm and sm.myhpmax > 0 and sm.myhp <= 0):
		if selected_cell.x != -1:
			_deselect_piece()
		is_holding = false
		return

	if sm and (sm.isstageclear or sm.isdeadf or (not pvp_mode and sm.interval < 105)):
		if selected_cell.x != -1:
			_deselect_piece()
		return

	if pvp_mode and not pvp_my_turn:
		if selected_cell.x != -1:
			_deselect_piece()
		is_holding = false
		return

	if current_state != BoardState.IDLE:
		return

	var local_pos = _get_mouse_local(event)
	_current_local_mouse = local_pos
	var col_idx = int(floor((local_pos.x - BOARD_LEFT) / CELL_PITCH))
	var row_idx = int(floor((local_pos.y - BOARD_TOP) / CELL_PITCH))
	var is_in_bounds: bool = (row_idx >= 0 and row_idx < GRID_ROWS and col_idx >= 0 and col_idx < GRID_COLUMNS)

	if mouse_event.pressed:
		is_holding = true
		press_start_cell = Vector2i(row_idx, col_idx) if is_in_bounds else Vector2i(-1, -1)

		# チュートリアル中の操作マス制限（指示された2マス間の入れ替え、またはスキル駒等の特殊駒タップ起爆を許可）
		if _is_tutorial_mode():
			if tutorial_allowed_swap.size() == 2 and is_in_bounds:
				var cur_c = Vector2i(row_idx, col_idx)
				var c1 = tutorial_allowed_swap[0]
				var c2 = tutorial_allowed_swap[1]
				if cur_c != c1 and cur_c != c2:
					if selected_cell.x != -1:
						_deselect_piece()
					return
			elif is_in_bounds:
				var is_sp_cell = (special_item.size() == GRID_ROWS and special_item[row_idx][col_idx] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[row_idx][col_idx])
				if not is_sp_cell:
					if selected_cell.x != -1:
						_deselect_piece()
					return
				else:
					# チュートリアル中のスキル駒タップ起爆：即座に起爆を実行
					_deselect_piece()
					_detonate_special_by_click(row_idx, col_idx)
					return
			else:
				if selected_cell.x != -1:
					_deselect_piece()
				return

		# 植物（木・苗）のマスは駒が存在せずクリック・スワップ不可
		if is_in_bounds and _is_plant_cell(row_idx, col_idx):
			if selected_cell.x != -1:
				_deselect_piece()
			return

		# 水浸しマスは滑って動かせない（スワップ・選択禁止 ※自分の清流マスは操作可能）
		if is_in_bounds and grid_water.size() == GRID_ROWS and grid_water[row_idx][col_idx] and not is_ally_water(row_idx, col_idx):
			if selected_cell.x != -1:
				_deselect_piece()
			_splash_water_jiggle(row_idx, col_idx)
			return

		# 氷漬けマスは凍りついて動かせない（スワップ・選択禁止 ※自分の氷盾マスは操作可能）
		if is_in_bounds and grid_ice.size() == GRID_ROWS and grid_ice[row_idx][col_idx] and not is_ally_ice(row_idx, col_idx):
			if selected_cell.x != -1:
				_deselect_piece()
			_shake_ice_jiggle(row_idx, col_idx)
			return

		# 石マスは動かせない障害物（スワップ・選択禁止 ※自分の輝石マスは操作可能）
		if is_in_bounds and grid_stones.size() == GRID_ROWS and grid_stones[row_idx][col_idx] > 0 and not is_ally_stone(row_idx, col_idx):
			if selected_cell.x != -1:
				_deselect_piece()
			_shake_stone_jiggle(row_idx, col_idx)
			return

		# 黄金石像マスは動かせないスカコマ（スワップ・選択禁止 ※自分の聖像マスは操作可能）
		if is_in_bounds and grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[row_idx][col_idx] > 0 and not is_ally_gold(row_idx, col_idx):
			if selected_cell.x != -1:
				_deselect_piece()
			_shake_gold_jiggle(row_idx, col_idx)
			return

		# 帯電コマに触れた場合の感電放電・反動ダメージ（※自分の過充電コマ、または特殊アイテム起爆クリック時は無害）
		var is_sp_click = (special_item.size() == GRID_ROWS and special_item[row_idx][col_idx] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[row_idx][col_idx])
		if is_in_bounds and grid_electrified.size() == GRID_ROWS and grid_electrified[row_idx][col_idx] and not is_ally_electrified(row_idx, col_idx):
			grid_electrified[row_idx][col_idx] = false
			if not is_sp_click and sm:
				var shock_dmg = (minf(sm.myhpmax * 0.08, 500.0) if sm.myhpmax > 0 else 500.0) * _get_difficulty_skill_mult()
				sm.last_damage_cause = "帯電マスの接触ダメージ"
				sm.calchp(0.0, shock_dmg)
				var rm_br = _get_relic_manager()
				if rm_br: rm_br.on_backlash_damage("electrified", shock_dmg)
				player_shock_stacks = mini(5, player_shock_stacks + 1)
				_spawn_floating_text(get_cell_position(row_idx, col_idx), "⚡ 感電スタック付与 (%d/5)！" % player_shock_stacks, Color(1.0, 0.4, 0.4))
				_spawn_status_damage_banner("⚡ 感電ダメージ -%d" % int(shock_dmg), Color(1.0, 0.85, 0.25))
				_trigger_screen_shake(10.0)
				if sm.myhp <= 0:
					_trigger_gameover(sm)
					return
			_spawn_shock_zap_effect(get_cell_position(row_idx, col_idx))
			_redraw_board_effects()

		# すでに選択中の場合で、隣接マス（特殊アイテム含む）をクリックしたならスワップ成立
		if selected_cell.x != -1:
			var can_teleport = (has_dark_teleport_swap or free_swap_turns > 0)
			if is_in_bounds and ((abs(row_idx - selected_cell.x) + abs(col_idx - selected_cell.y) == 1) or (can_teleport and (row_idx != selected_cell.x or col_idx != selected_cell.y))):
				var r1 = selected_cell.x
				var c1 = selected_cell.y
				_execute_swap(r1, c1, row_idx, col_idx)
				return
			elif is_in_bounds and row_idx == selected_cell.x and col_idx == selected_cell.y:
				# 特殊アイテムをその場で再タップした場合は即時起爆
				var is_sp = (special_item.size() == GRID_ROWS and special_item[row_idx][col_idx] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[row_idx][col_idx])
				if is_sp:
					_deselect_piece()
					_detonate_special_by_click(row_idx, col_idx)
					return
				drag_offset = piece[selected_piece_idx].position - local_pos
				return
			else:
				_deselect_piece()

		if selected_cell.x == -1:
			# 未選択時: クリックしたマスを選択
			if is_in_bounds:
				var p_idx = grid_i[row_idx][col_idx]
				if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
					selected_cell = Vector2i(row_idx, col_idx)
					selected_piece_idx = p_idx
					drag_offset = piece[p_idx].position - local_pos
					piece[p_idx].z_index = 10
					piece[p_idx].scale = cellsize * 1.2
					_update_hovered_swap_direction(local_pos)
					if board_bg: board_bg.queue_redraw()
					if swap_guide_overlay: swap_guide_overlay.queue_redraw()
					var se2 = get_node_or_null("AudioStreamPlayer2")
					if se2: se2.play()
		else:
			# すでに選択中: 今回クリックしたマスとの位置関係でスワップまたは解除
			var can_teleport_c = (has_dark_teleport_swap or free_swap_turns > 0)
			if is_in_bounds and ((abs(row_idx - selected_cell.x) + abs(col_idx - selected_cell.y) == 1) or (can_teleport_c and (row_idx != selected_cell.x or col_idx != selected_cell.y))):
				var r1 = selected_cell.x
				var c1 = selected_cell.y
				_execute_swap(r1, c1, row_idx, col_idx)
			elif is_in_bounds and row_idx == selected_cell.x and col_idx == selected_cell.y:
				# 同じコマを再クリックした場合はドラッグ再開
				drag_offset = piece[selected_piece_idx].position - local_pos
			else:
				_deselect_piece()
	else:
		# マウスボタン解放
		is_holding = false
		if selected_cell.x != -1:
			var rel_pos = _get_mouse_local(event)
			var rel_col = int(floor((rel_pos.x - BOARD_LEFT) / CELL_PITCH))
			var rel_row = int(floor((rel_pos.y - BOARD_TOP) / CELL_PITCH))
			var rel_in_bounds: bool = (rel_row >= 0 and rel_row < GRID_ROWS and rel_col >= 0 and rel_col < GRID_COLUMNS)
			
			var can_teleport_d = (has_dark_teleport_swap or free_swap_turns > 0)
			if rel_in_bounds and ((abs(rel_row - selected_cell.x) + abs(rel_col - selected_cell.y) == 1) or (can_teleport_d and (rel_row != selected_cell.x or rel_col != selected_cell.y))):
				# 隣接マスまたは空間転移で離した (ドラッグ&ドロップ成立)
				_execute_swap(selected_cell.x, selected_cell.y, rel_row, rel_col)
			elif hovered_swap_cell.x != -1 and press_start_cell == selected_cell:
				# 移動先として強調表示されていた隣接マスで離した (補正スワップ成立)
				_execute_swap(selected_cell.x, selected_cell.y, hovered_swap_cell.x, hovered_swap_cell.y)
			elif not rel_in_bounds or (press_start_cell != Vector2i(rel_row, rel_col) and not can_teleport_d and (abs(rel_row - selected_cell.x) + abs(rel_col - selected_cell.y) > 1)):
				# 盤面外や2マス以上離れた場所で離した (ドラッグ失敗・キャンセル)
				_deselect_piece()
			else:
				# 同じマスで離した（タップ/クリック操作）
				var is_sp = (special_item.size() == GRID_ROWS and special_item[selected_cell.x][selected_cell.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[selected_cell.x][selected_cell.y])
				if is_sp and press_start_cell == selected_cell:
					var sc = selected_cell
					_deselect_piece()
					_detonate_special_by_click(sc.x, sc.y)
				else:
					if selected_piece_idx >= 0 and selected_piece_idx < piece.size() and piece[selected_piece_idx] != null:
						var orig_pos = get_cell_position(selected_cell.x, selected_cell.y)
						var tw = create_tween()
						tw.tween_property(piece[selected_piece_idx], "position", orig_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					_update_hovered_swap_direction(_current_local_mouse)
					if swap_guide_overlay: swap_guide_overlay.queue_redraw()

func _on_area_2d_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	# _unhandled_input で確実に処理するためシグナル側はパス
	pass

## 選択中の駒を元の位置に戻して選択解除
func _deselect_piece() -> void:
	if selected_piece_idx >= 0 and selected_piece_idx < piece.size() and piece[selected_piece_idx] != null:
		var p = piece[selected_piece_idx]
		p.z_index = 0
		p.scale = cellsize
		if selected_cell.x >= 0 and selected_cell.y >= 0:
			var orig_pos = get_cell_position(selected_cell.x, selected_cell.y)
			var tween = create_tween()
			tween.tween_property(p, "position", orig_pos, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	selected_cell = Vector2i(-1, -1)
	selected_piece_idx = -1
	is_holding = false
	drag_offset = Vector2.ZERO
	press_start_cell = Vector2i(-1, -1)
	hovered_swap_cell = Vector2i(-1, -1)
	if board_bg: board_bg.queue_redraw()
	if swap_guide_overlay: swap_guide_overlay.queue_redraw()

## 水浸しマスのプルプル揺れ演出（動かせないフィードバック）
func _splash_water_jiggle(r: int, c: int) -> void:
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS:
		return
	var p_idx = grid_i[r][c]
	if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
		var sp = piece[p_idx]
		var orig_pos = get_cell_position(r, c)
		var tw = create_tween()
		tw.tween_property(sp, "position:x", orig_pos.x - 20.0, 0.04)
		tw.tween_property(sp, "position:x", orig_pos.x + 20.0, 0.04)
		tw.tween_property(sp, "position:x", orig_pos.x - 10.0, 0.04)
		tw.tween_property(sp, "position:x", orig_pos.x, 0.04)

	var center = get_cell_position(r, c)
	for i in range(4):
		var drop = ColorRect.new()
		drop.size = Vector2(16.0, 16.0)
		drop.position = center - drop.size / 2.0
		drop.color = Color(0.2, 0.7, 1.0, 0.8)
		drop.z_index = 25
		Profiler.add_child_count += 1; add_child(drop)
		var a = randf() * TAU
		var tw_d = create_tween().set_parallel(true)
		tw_d.tween_property(drop, "position", center + Vector2(cos(a), sin(a)) * 80.0, 0.25).set_ease(Tween.EASE_OUT)
		tw_d.tween_property(drop, "modulate:a", 0.0, 0.25)
		tw_d.chain().tween_callback(drop.queue_free)

## 2つの駒をTweenで滑らかにスワップ
func _execute_swap(r1: int, c1: int, r2: int, c2: int) -> void:
	if _is_tutorial_mode():
		if tutorial_allowed_swap.size() == 2:
			var a1 = tutorial_allowed_swap[0]
			var a2 = tutorial_allowed_swap[1]
			var sw1 = Vector2i(r1, c1)
			var sw2 = Vector2i(r2, c2)
			if not ((sw1 == a1 and sw2 == a2) or (sw1 == a2 and sw2 == a1)):
				_deselect_piece()
				return
			tutorial_allowed_swap.clear()
		else:
			_deselect_piece()
			return
	if _is_tutorial_mode():
		emit_signal("tutorial_swap_completed", Vector2i(r1, c1), Vector2i(r2, c2))

	if pvp_mode and not _is_plant_cell(r1, c1) and not _is_plant_cell(r2, c2):
		emit_signal("pvp_move_started")

	if _is_plant_cell(r1, c1) or _is_plant_cell(r2, c2):
		_deselect_piece()
		return

	var enemy_w1 = grid_water.size() == GRID_ROWS and grid_water[r1][c1] and not is_ally_water(r1, c1)
	var enemy_w2 = grid_water.size() == GRID_ROWS and grid_water[r2][c2] and not is_ally_water(r2, c2)
	if enemy_w1 or enemy_w2:
		_deselect_piece()
		if enemy_w1: _splash_water_jiggle(r1, c1)
		if enemy_w2: _splash_water_jiggle(r2, c2)
		return

	var enemy_i1 = grid_ice.size() == GRID_ROWS and grid_ice[r1][c1] and not is_ally_ice(r1, c1)
	var enemy_i2 = grid_ice.size() == GRID_ROWS and grid_ice[r2][c2] and not is_ally_ice(r2, c2)
	var enemy_s1 = grid_stones.size() == GRID_ROWS and grid_stones[r1][c1] > 0 and not is_ally_stone(r1, c1)
	var enemy_s2 = grid_stones.size() == GRID_ROWS and grid_stones[r2][c2] > 0 and not is_ally_stone(r2, c2)
	var enemy_g1 = grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r1][c1] > 0 and not is_ally_gold(r1, c1)
	var enemy_g2 = grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r2][c2] > 0 and not is_ally_gold(r2, c2)

	if enemy_i1 or enemy_i2 or enemy_s1 or enemy_s2 or enemy_g1 or enemy_g2:
		_deselect_piece()
		if enemy_i1: _shake_ice_jiggle(r1, c1)
		if enemy_i2: _shake_ice_jiggle(r2, c2)
		if enemy_s1: _shake_stone_jiggle(r1, c1)
		if enemy_s2: _shake_stone_jiggle(r2, c2)
		if enemy_g1: _shake_gold_jiggle(r1, c1)
		if enemy_g2: _shake_gold_jiggle(r2, c2)
		return

	current_state = BoardState.SWAPPING
	last_swap_cells = [Vector2i(r1, c1), Vector2i(r2, c2)]
	steady_spark_triggered_this_turn = false
	poison_spread_done_this_turn = false

	var idx1 = grid_i[r1][c1]
	var idx2 = grid_i[r2][c2]
	var pos1 = get_cell_position(r1, c1)
	var pos2 = get_cell_position(r2, c2)

	var p1 = piece[idx1] if idx1 >= 0 and idx1 < piece.size() else null
	var p2 = piece[idx2] if idx2 >= 0 and idx2 < piece.size() else null

	if p1:
		p1.z_index = 0
		p1.scale = cellsize
	if p2:
		p2.z_index = 0
		p2.scale = cellsize

	selected_cell = Vector2i(-1, -1)
	selected_piece_idx = -1
	is_holding = false
	drag_offset = Vector2.ZERO
	press_start_cell = Vector2i(-1, -1)
	hovered_swap_cell = Vector2i(-1, -1)
	if board_bg: board_bg.queue_redraw()
	if swap_guide_overlay: swap_guide_overlay.queue_redraw()

	# 盤面データを仮交換
	_swap_grid_data(r1, c1, r2, c2)

	var se2 = get_node_or_null("AudioStreamPlayer2")
	if se2: se2.play()

	var tween = create_tween().set_parallel(true)
	if p1: tween.tween_property(p1, "position", pos2, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if p2: tween.tween_property(p2, "position", pos1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var _t_aw_tween_finished = Time.get_ticks_usec()
	await tween.finished
	if OS.is_debug_build(): print("[AWAIT] tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_tween_finished) / 1000.0))

	# スワップ後にマッチが存在するか、または特殊アイテムがスワップされたか判定
	var has_match = _check_matches_exist()
	var sp1 = (special_item.size() == GRID_ROWS and special_item[r1][c1] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[r1][c1])
	var sp2 = (special_item.size() == GRID_ROWS and special_item[r2][c2] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[r2][c2])

	var can_free_swap = (free_swap_turns > 0 or has_dark_teleport_swap)
	if has_match or sp1 or sp2 or can_free_swap:
		var detonates: Array[Vector2i] = []
		if sp1: detonates.append(Vector2i(r1, c1))
		if sp2: detonates.append(Vector2i(r2, c2))
		if detonates.size() > 0:
			var sm = _get_stage_manager()
			if sm and sm.isfevertime:
				sm.fevercount -= 1
				if sm.fevercount <= 0:
					sm.notfevertime()
			_detonate_specials(detonates)
		if has_match:
			_detect_and_spawn_special_from_matches()

		_start_match_highlight()
	else:
		last_swap_cells.clear()
		# マッチ不成立：元に戻すアニメーション
		var revert_tween = create_tween().set_parallel(true)
		if p1: revert_tween.tween_property(p1, "position", pos1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if p2: revert_tween.tween_property(p2, "position", pos2, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_swap_grid_data(r1, c1, r2, c2)
		var _t_aw_revert_tween_finished = Time.get_ticks_usec()
		await revert_tween.finished
		if OS.is_debug_build(): print("[AWAIT] revert_tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_revert_tween_finished) / 1000.0))
		current_state = BoardState.IDLE

## グリッドデータのスワップ
func _swap_grid_data(r1: int, c1: int, r2: int, c2: int) -> void:
	var tmp_i = grid_i[r1][c1]
	grid_i[r1][c1] = grid_i[r2][c2]
	grid_i[r2][c2] = tmp_i

	var tmp_n = grid_n[r1][c1]
	grid_n[r1][c1] = grid_n[r2][c2]
	grid_n[r2][c2] = tmp_n
	if grid_element.size() == GRID_ROWS:
		var tmp_el = grid_element[r1][c1]
		grid_element[r1][c1] = grid_element[r2][c2]
		grid_element[r2][c2] = tmp_el


	var tmp_att = grid_att[r1][c1]
	grid_att[r1][c1] = grid_att[r2][c2]
	grid_att[r2][c2] = tmp_att

	if is_bomb.size() == GRID_ROWS:
		var tmp_b = is_bomb[r1][c1]
		is_bomb[r1][c1] = is_bomb[r2][c2]
		is_bomb[r2][c2] = tmp_b

	if special_item.size() == GRID_ROWS:
		var tmp_sp = special_item[r1][c1]
		special_item[r1][c1] = special_item[r2][c2]
		special_item[r2][c2] = tmp_sp

	if special_charge.size() == GRID_ROWS:
		var tmp_ch = special_charge[r1][c1]
		special_charge[r1][c1] = special_charge[r2][c2]
		special_charge[r2][c2] = tmp_ch

	if grid_electrified.size() == GRID_ROWS:
		var tmp_el = grid_electrified[r1][c1]
		grid_electrified[r1][c1] = grid_electrified[r2][c2]
		grid_electrified[r2][c2] = tmp_el
		if grid_electrified_ally.size() == GRID_ROWS:
			var tmp_ela = grid_electrified_ally[r1][c1]
			grid_electrified_ally[r1][c1] = grid_electrified_ally[r2][c2]
			grid_electrified_ally[r2][c2] = tmp_ela

	if grid_cursed.size() == GRID_ROWS:
		var tmp_cu = grid_cursed[r1][c1]
		grid_cursed[r1][c1] = grid_cursed[r2][c2]
		grid_cursed[r2][c2] = tmp_cu
		if grid_cursed_ally.size() == GRID_ROWS:
			var tmp_cua = grid_cursed_ally[r1][c1]
			grid_cursed_ally[r1][c1] = grid_cursed_ally[r2][c2]
			grid_cursed_ally[r2][c2] = tmp_cua

	if grid_poison.size() == GRID_ROWS:
		var tmp_po = grid_poison[r1][c1]
		grid_poison[r1][c1] = grid_poison[r2][c2]
		grid_poison[r2][c2] = tmp_po
		if grid_poison_ally.size() == GRID_ROWS:
			var tmp_poa = grid_poison_ally[r1][c1]
			grid_poison_ally[r1][c1] = grid_poison_ally[r2][c2]
			grid_poison_ally[r2][c2] = tmp_poa

	if grid_stones.size() == GRID_ROWS:
		var tmp_st = grid_stones[r1][c1]
		grid_stones[r1][c1] = grid_stones[r2][c2]
		grid_stones[r2][c2] = tmp_st
		if grid_stones_ally.size() == GRID_ROWS:
			var tmp_sta = grid_stones_ally[r1][c1]
			grid_stones_ally[r1][c1] = grid_stones_ally[r2][c2]
			grid_stones_ally[r2][c2] = tmp_sta

	if grid_fire.size() == GRID_ROWS:
		var tmp_f = grid_fire[r1][c1]
		grid_fire[r1][c1] = grid_fire[r2][c2]
		grid_fire[r2][c2] = tmp_f
		if grid_fire_ally.size() == GRID_ROWS:
			var tmp_fa = grid_fire_ally[r1][c1]
			grid_fire_ally[r1][c1] = grid_fire_ally[r2][c2]
			grid_fire_ally[r2][c2] = tmp_fa

	if tmp_i >= 0 and tmp_i < piececollid.size() and piececollid[tmp_i]:
		piececollid[tmp_i].position = get_cell_position(r2, c2)
	var other_i = grid_i[r1][c1]
	if other_i >= 0 and other_i < piececollid.size() and piececollid[other_i]:
		piececollid[other_i].position = get_cell_position(r1, c1)

# --- 3マッチ判定 ---

func _check_matches_exist(changed_rows: Array = [], changed_cols: Array = []) -> bool:
	var _prof = Profiler.begin("puzzle_board::_check_matches_exist")
	# 安全のため、常に全セルを走査し ismatched を更新する
	for i in range(GRID_ROWS):
		for j in range(GRID_COLUMNS):
			ismatched[i][j] = false

	var found = false

	# 水平走査
	for i in range(GRID_ROWS):
		var j: int = 0
		while j < GRID_COLUMNS:
			var is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[i][j] > 0 and not is_ally_stone(i, j))
			var is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[i][j] > 0 and not is_ally_gold(i, j))
			var is_sp: bool = (special_item.size() == GRID_ROWS and special_item[i][j] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[i][j])
			var kind: int = grid_n[i][j]
			if kind < 0 or is_stone or is_gold or is_sp or _is_plant_cell(i, j):
				j += 1
				continue
			var match_len: int = 1
			while j + match_len < GRID_COLUMNS:
				var next_c: int = j + match_len
				var next_is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[i][next_c] > 0 and not is_ally_stone(i, next_c))
				var next_is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[i][next_c] > 0 and not is_ally_gold(i, next_c))
				var next_is_sp: bool = (special_item.size() == GRID_ROWS and special_item[i][next_c] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[i][next_c])
				if next_is_stone or next_is_gold or next_is_sp or _is_plant_cell(i, next_c) or grid_n[i][next_c] != kind:
					break
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(j, j + match_len):
					ismatched[i][k] = true
			j += match_len

	# 垂直走査
	for j in range(GRID_COLUMNS):
		var i: int = 0
		while i < GRID_ROWS:
			var is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[i][j] > 0 and not is_ally_stone(i, j))
			var is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[i][j] > 0 and not is_ally_gold(i, j))
			var is_sp: bool = (special_item.size() == GRID_ROWS and special_item[i][j] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[i][j])
			var kind: int = grid_n[i][j]
			if kind < 0 or is_stone or is_gold or is_sp or _is_plant_cell(i, j):
				i += 1
				continue
			var match_len: int = 1
			while i + match_len < GRID_ROWS:
				var next_r: int = i + match_len
				var next_is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[next_r][j] > 0 and not is_ally_stone(next_r, j))
				var next_is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[next_r][j] > 0 and not is_ally_gold(next_r, j))
				var next_is_sp: bool = (special_item.size() == GRID_ROWS and special_item[next_r][j] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[next_r][j])
				if next_is_stone or next_is_gold or next_is_sp or _is_plant_cell(next_r, j) or grid_n[next_r][j] != kind:
					break
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(i, i + match_len):
					ismatched[k][j] = true
			i += match_len

	return found
# --- 特殊アイテムシステム（爆弾・クロスボム・ディスコ・ペンキ・雷・ブラックホール・磁石・時限・分裂） ---

## 最多属性の取得ヘルパー
func _get_dominant_attribute() -> int:
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var att = grid_att[r][c]
			if att >= 0 and att < 5:
				counts[att] += 1
	var max_att: int = 0
	for i in range(1, 5):
		if counts[i] > counts[max_att]:
			max_att = i
	return max_att

## 2番目に多い属性の取得ヘルパー
func _get_second_dominant_attribute(exclude_att: int) -> int:
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var a = grid_att[r][c]
			if a >= 0 and a < 5 and a != exclude_att:
				counts[a] += 1
	var max_c = -1
	var best_a = -1
	for a in range(5):
		if a != exclude_att and counts[a] > max_c and counts[a] > 0:
			max_c = counts[a]
			best_a = a
	return best_a

## 同色コマのn個消し（4消し、5個直線、交差、6個、7個以上）によるスキルコマ手動生成解析
## マッチ条件と選択カテゴリ・解放状況に応じた特殊スキル駒の選定
func _select_special_for_match(kind: int, total_count: int, max_line: int, has_cross: bool) -> int:
	var rm = _get_relic_manager()
	var cat: String = rm.get_chosen_element_category() if (rm and rm.has_method("get_chosen_element_category")) else ""
	if cat == "":
		return SpecialItemType.NONE

	# 1. カテゴリが Nature の場合 (水・氷・木・風)
	if cat == "nature":
		match kind:
			PieceType.POTION: # 水
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.AQUA_SPLASH, 0) > 0:
					return SpecialItemType.AQUA_SPLASH
				if max_line >= 5 and special_levels.get(SpecialItemType.AQUA_SPLASH, 0) > 0:
					return SpecialItemType.AQUA_SPLASH
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.AQUA_SPLASH, 0) > 0:
					return SpecialItemType.AQUA_SPLASH
			PieceType.SHIELD: # 氷
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.ICE_SHIELD, 0) > 0:
					return SpecialItemType.ICE_SHIELD
				if max_line >= 5 and special_levels.get(SpecialItemType.ICE_SHIELD, 0) > 0:
					return SpecialItemType.ICE_SHIELD
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.ICE_SHIELD, 0) > 0:
					return SpecialItemType.ICE_SHIELD
			PieceType.FOOD: # 木
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.TREE_SPROUT, 0) > 0:
					return SpecialItemType.TREE_SPROUT
				if max_line >= 5 and special_levels.get(SpecialItemType.COLOR_CONVERTER, 0) > 0:
					return SpecialItemType.COLOR_CONVERTER
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.TREE_SPROUT, 0) > 0:
					return SpecialItemType.TREE_SPROUT
			PieceType.COIN: # 風
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.TORNADO, 0) > 0:
					return SpecialItemType.TORNADO
				if max_line >= 5 and special_levels.get(SpecialItemType.TORNADO, 0) > 0:
					return SpecialItemType.TORNADO
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.TORNADO, 0) > 0:
					return SpecialItemType.TORNADO

	# 2. カテゴリが Force の場合 (火・雷・土)
	elif cat == "force":
		match kind:
			PieceType.SWORD: # 火
				if (total_count >= 6 or total_count >= 7) and special_levels.get(SpecialItemType.GEMINI_BOMB, 0) > 0:
					return SpecialItemType.GEMINI_BOMB
				if has_cross and special_levels.get(SpecialItemType.CROSS_BOMB, 0) > 0:
					return SpecialItemType.CROSS_BOMB
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.BOMB, 0) > 0:
					return SpecialItemType.BOMB
			PieceType.COIN: # 雷
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.LIGHTNING, 0) > 0:
					return SpecialItemType.LIGHTNING
				if max_line >= 5 and special_levels.get(SpecialItemType.GEMINI_BOMB, 0) > 0:
					return SpecialItemType.GEMINI_BOMB
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.LIGHTNING, 0) > 0:
					return SpecialItemType.LIGHTNING
			PieceType.SHIELD: # 土
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.CHARGE_BOMB, 0) > 0:
					return SpecialItemType.CHARGE_BOMB
				if max_line >= 5 and special_levels.get(SpecialItemType.COLOR_CONVERTER, 0) > 0:
					return SpecialItemType.COLOR_CONVERTER
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.CHARGE_BOMB, 0) > 0:
					return SpecialItemType.CHARGE_BOMB

	# 3. カテゴリが Mystic の場合 (毒・光・闇)
	elif cat == "mystic":
		match kind:
			PieceType.POTION: # 毒
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.POISON_MIST, 0) > 0:
					return SpecialItemType.POISON_MIST
				if max_line >= 5 and special_levels.get(SpecialItemType.POISON_MIST, 0) > 0:
					return SpecialItemType.POISON_MIST
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.POISON_MIST, 0) > 0:
					return SpecialItemType.POISON_MIST
			PieceType.COIN: # 光
				if total_count >= 7 and special_levels.get(SpecialItemType.DISCO_BALL, 0) > 0:
					return SpecialItemType.DISCO_BALL
				if (has_cross or total_count >= 6 or max_line >= 5) and special_levels.get(SpecialItemType.HOLY_LIGHT, 0) > 0:
					return SpecialItemType.HOLY_LIGHT
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.HOLY_LIGHT, 0) > 0:
					return SpecialItemType.HOLY_LIGHT
			PieceType.SWORD: # 闇
				if (has_cross or total_count >= 6) and special_levels.get(SpecialItemType.BLACK_HOLE, 0) > 0:
					return SpecialItemType.BLACK_HOLE
				if max_line >= 5 and special_levels.get(SpecialItemType.BLACK_HOLE, 0) > 0:
					return SpecialItemType.BLACK_HOLE
				if (total_count >= 4 or max_line >= 4) and special_levels.get(SpecialItemType.BLACK_HOLE, 0) > 0:
					return SpecialItemType.BLACK_HOLE

	# 4. カテゴリ未選択（または未該当時のフォールバック判定）
	if total_count >= 7 and special_levels.get(SpecialItemType.DISCO_BALL, 0) > 0:
		return SpecialItemType.DISCO_BALL
	if total_count >= 6 and special_levels.get(SpecialItemType.GEMINI_BOMB, 0) > 0:
		return SpecialItemType.GEMINI_BOMB
	if has_cross and special_levels.get(SpecialItemType.CROSS_BOMB, 0) > 0:
		return SpecialItemType.CROSS_BOMB

	if max_line >= 5:
		match kind:
			PieceType.SWORD:
				if special_levels.get(SpecialItemType.LIGHTNING, 0) > 0: return SpecialItemType.LIGHTNING
				if special_levels.get(SpecialItemType.BLACK_HOLE, 0) > 0: return SpecialItemType.BLACK_HOLE
				if special_levels.get(SpecialItemType.BOMB, 0) > 0: return SpecialItemType.BOMB
			PieceType.SHIELD:
				if special_levels.get(SpecialItemType.ICE_SHIELD, 0) > 0: return SpecialItemType.ICE_SHIELD
				if special_levels.get(SpecialItemType.COLOR_CONVERTER, 0) > 0: return SpecialItemType.COLOR_CONVERTER
				if special_levels.get(SpecialItemType.CHARGE_BOMB, 0) > 0: return SpecialItemType.CHARGE_BOMB
			PieceType.COIN:
				if special_levels.get(SpecialItemType.HOLY_LIGHT, 0) > 0: return SpecialItemType.HOLY_LIGHT
				if special_levels.get(SpecialItemType.LIGHTNING, 0) > 0: return SpecialItemType.LIGHTNING
				if special_levels.get(SpecialItemType.TORNADO, 0) > 0: return SpecialItemType.TORNADO
			PieceType.POTION:
				if special_levels.get(SpecialItemType.POISON_MIST, 0) > 0: return SpecialItemType.POISON_MIST
				if special_levels.get(SpecialItemType.BLACK_HOLE, 0) > 0: return SpecialItemType.BLACK_HOLE
				if special_levels.get(SpecialItemType.AQUA_SPLASH, 0) > 0: return SpecialItemType.AQUA_SPLASH
			PieceType.FOOD:
				if special_levels.get(SpecialItemType.COLOR_CONVERTER, 0) > 0: return SpecialItemType.COLOR_CONVERTER
				if special_levels.get(SpecialItemType.TREE_SPROUT, 0) > 0: return SpecialItemType.TREE_SPROUT

	if total_count >= 4 or max_line >= 4 or has_cross:
		match kind:
			PieceType.SWORD:
				if special_levels.get(SpecialItemType.BOMB, 0) > 0: return SpecialItemType.BOMB
				if special_levels.get(SpecialItemType.BLACK_HOLE, 0) > 0: return SpecialItemType.BLACK_HOLE
			PieceType.SHIELD:
				if special_levels.get(SpecialItemType.ICE_SHIELD, 0) > 0: return SpecialItemType.ICE_SHIELD
				if special_levels.get(SpecialItemType.CHARGE_BOMB, 0) > 0: return SpecialItemType.CHARGE_BOMB
			PieceType.COIN:
				if special_levels.get(SpecialItemType.TORNADO, 0) > 0: return SpecialItemType.TORNADO
				if special_levels.get(SpecialItemType.LIGHTNING, 0) > 0: return SpecialItemType.LIGHTNING
				if special_levels.get(SpecialItemType.DISCO_BALL, 0) > 0: return SpecialItemType.DISCO_BALL
			PieceType.POTION:
				if special_levels.get(SpecialItemType.AQUA_SPLASH, 0) > 0: return SpecialItemType.AQUA_SPLASH
				if special_levels.get(SpecialItemType.POISON_MIST, 0) > 0: return SpecialItemType.POISON_MIST
			PieceType.FOOD:
				if special_levels.get(SpecialItemType.TREE_SPROUT, 0) > 0: return SpecialItemType.TREE_SPROUT

	return SpecialItemType.NONE

func _detect_and_spawn_special_from_matches() -> void:
	pending_special_spawns.clear()

	# 水平マッチセグメントと垂直マッチセグメントの収集
	var segments: Array[Dictionary] = []

	# 1. 水平セグメント
	for r in range(GRID_ROWS):
		var c = 0
		while c < GRID_COLUMNS:
			var is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0 and not is_ally_stone(r, c))
			var is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0 and not is_ally_gold(r, c))
			var is_sp: bool = (special_item.size() == GRID_ROWS and special_item[r][c] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[r][c])
			var kind = grid_n[r][c]
			if kind < 0 or is_stone or is_gold or is_sp or _is_plant_cell(r, c):
				c += 1
				continue
			var match_len = 1
			while c + match_len < GRID_COLUMNS:
				var next_c = c + match_len
				var next_is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[r][next_c] > 0 and not is_ally_stone(r, next_c))
				var next_is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][next_c] > 0 and not is_ally_gold(r, next_c))
				var next_is_sp: bool = (special_item.size() == GRID_ROWS and special_item[r][next_c] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[r][next_c])
				if next_is_stone or next_is_gold or next_is_sp or _is_plant_cell(r, next_c) or grid_n[r][next_c] != kind:
					break
				match_len += 1
			if match_len >= 3:
				var c_list: Array[Vector2i] = []
				for k in range(c, c + match_len):
					c_list.append(Vector2i(r, k))
				segments.append({
					"kind": kind,
					"dir": "H",
					"len": match_len,
					"cells": c_list
				})
			c += match_len

	# 2. 垂直セグメント
	for c in range(GRID_COLUMNS):
		var r = 0
		while r < GRID_ROWS:
			var is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0 and not is_ally_stone(r, c))
			var is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0 and not is_ally_gold(r, c))
			var is_sp: bool = (special_item.size() == GRID_ROWS and special_item[r][c] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[r][c])
			var kind = grid_n[r][c]
			if kind < 0 or is_stone or is_gold or is_sp or _is_plant_cell(r, c):
				r += 1
				continue
			var match_len = 1
			while r + match_len < GRID_ROWS:
				var next_r = r + match_len
				var next_is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[next_r][c] > 0 and not is_ally_stone(next_r, c))
				var next_is_gold: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[next_r][c] > 0 and not is_ally_gold(next_r, c))
				var next_is_sp: bool = (special_item.size() == GRID_ROWS and special_item[next_r][c] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[next_r][c])
				if next_is_stone or next_is_gold or next_is_sp or _is_plant_cell(next_r, c) or grid_n[next_r][c] != kind:
					break
				match_len += 1
			if match_len >= 3:
				var c_list: Array[Vector2i] = []
				for k in range(r, r + match_len):
					c_list.append(Vector2i(k, c))
				segments.append({
					"kind": kind,
					"dir": "V",
					"len": match_len,
					"cells": c_list
				})
			r += match_len

	if segments.is_empty():
		return

	# 3. 同色セグメント同士の連結グループ化 (Connected Components)
	var num_segs = segments.size()
	var parent_arr: Array[int] = []
	for i in range(num_segs):
		parent_arr.append(i)

	var find_root = func(x: int, f_ref: Callable) -> int:
		if parent_arr[x] == x:
			return x
		parent_arr[x] = f_ref.call(parent_arr[x], f_ref)
		return parent_arr[x]

	for i in range(num_segs):
		for j in range(i + 1, num_segs):
			if segments[i]["kind"] == segments[j]["kind"]:
				var shares = false
				for cell_i in segments[i]["cells"]:
					if segments[j]["cells"].has(cell_i):
						shares = true
						break
				if shares:
					var root_i = find_root.call(i, find_root)
					var root_j = find_root.call(j, find_root)
					if root_i != root_j:
						parent_arr[root_i] = root_j

	var groups: Dictionary = {}
	for i in range(num_segs):
		var r_idx = find_root.call(i, find_root)
		if not groups.has(r_idx):
			groups[r_idx] = []
		groups[r_idx].append(segments[i])

	# 4. 各グループごとにスキル判定
	for g_root in groups:
		var g_segs: Array = groups[g_root]
		var kind: int = g_segs[0]["kind"]
		var all_cells_dict: Dictionary = {}
		var intersections: Array[Vector2i] = []
		var max_h: int = 0
		var max_v: int = 0
		var longest_seg_cells: Array[Vector2i] = []

		for s in g_segs:
			if s["dir"] == "H":
				if s["len"] > max_h:
					max_h = s["len"]
					if s["len"] > longest_seg_cells.size():
						longest_seg_cells = s["cells"]
			else:
				if s["len"] > max_v:
					max_v = s["len"]
					if s["len"] > longest_seg_cells.size():
						longest_seg_cells = s["cells"]
			for cell in s["cells"]:
				if all_cells_dict.has(cell):
					if not intersections.has(cell):
						intersections.append(cell)
				else:
					all_cells_dict[cell] = true

		var unique_cells: Array[Vector2i] = []
		for c_pos in all_cells_dict:
			unique_cells.append(c_pos)
		var total_count = unique_cells.size()
		var max_line = maxi(max_h, max_v)

		# スキルレシピの選定（優先順位: 7消し > 6消し > 交差 > 5個直線 > 4個消し）
		var target_sp: int = _select_special_for_match(kind, total_count, max_line, intersections.size() > 0)

		# スキル未解放ならコマは生成しない
		if target_sp == SpecialItemType.NONE:
			continue

		# ピボットセル（生成位置）の選定
		var pivot: Vector2i = Vector2i(-1, -1)
		if intersections.size() > 0:
			pivot = intersections[0]
		else:
			for swap_pos in last_swap_cells:
				if unique_cells.has(swap_pos):
					pivot = swap_pos
					break
			if pivot == Vector2i(-1, -1):
				if longest_seg_cells.size() > 0:
					pivot = longest_seg_cells[longest_seg_cells.size() / 2]
				else:
					pivot = unique_cells[unique_cells.size() / 2]

		if pivot != Vector2i(-1, -1):
			# 仕様変更(I3): スキル駒生成は1マッチにつき常に1個固定（強化は範囲・威力・効果でスケーリング）
			pending_special_spawns[pivot] = target_sp

## 落下時の特殊アイテム抽選（仕様刷新：スキルコマは同じコマのn個消しのみで生成され、自動落下・自動湧きは完全廃止）
func _roll_falling_special() -> int:
	return SpecialItemType.NONE

## 毎ターン開始時の特殊アイテム処理（仕様刷新：自動湧き廃止、植物処理と既存蓄電のみ進行）
func _spawn_turn_specials() -> void:
	if special_item.size() != GRID_ROWS:
		return

	# 0. 植物の毎ターン処理（吸水・自動回復）
	_process_turn_plants()

	# 1. 既存のチャージボムの成長
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if special_item[r][c] == SpecialItemType.CHARGE_BOMB:
				special_charge[r][c] = mini(3, special_charge[r][c] + 1)

	_redraw_board_effects()

func _spawn_turn_bombs() -> void:
	_spawn_turn_specials()

## クリックによる即時起爆（1手消費）
func _detonate_special_by_click(r: int, c: int) -> void:
	# 共有盤面モード: 相手が作ったスキル駒は起動できない
	if pvp_mode and pvp_my_player_index >= 0 and grid_skill_owner.size() == GRID_ROWS:
		var owner: int = grid_skill_owner[r][c]
		if owner >= 0 and owner != pvp_my_player_index:
			_spawn_floating_text(get_cell_position(r, c), "相手のスキル駒！", Color(1.0, 0.4, 0.4))
			return
	steady_spark_triggered_this_turn = false
	poison_spread_done_this_turn = false
	last_swap_cells.clear()
	if pvp_mode and pvp_my_turn:
		emit_signal("pvp_move_started")
	var sm = _get_stage_manager()
	if sm and sm.isfevertime:
		sm.fevercount -= 1
		if sm.fevercount <= 0:
			sm.notfevertime()

	for i in range(GRID_ROWS):
		for j in range(GRID_COLUMNS):
			ismatched[i][j] = false

	_detonate_specials([Vector2i(r, c)])
	_start_match_highlight()

func _detonate_bomb_by_click(r: int, c: int) -> void:
	_detonate_special_by_click(r, c)

## マッチした駒に隣接する特殊アイテムの連鎖誘爆判定
func _check_and_trigger_special_reactions() -> void:
	# 仕様変更(I1): マッチ隣接による自動起爆経路を廃止（スキル駒の起爆は操作または爆風誘爆のみ）
	return

func _check_and_trigger_bomb_reactions() -> void:
	# 仕様変更(I1): マッチ隣接による自動起爆経路を廃止
	return

## 特殊アイテムの連鎖起爆キュー処理
func _detonate_specials(start_items: Array) -> void:
	var queue: Array = start_items.duplicate()
	var exploded_items: Dictionary = {}

	while queue.size() > 0:
		var b = queue.pop_front()
		if b in exploded_items:
			continue
		# 共有盤面モード: 相手のスキル駒は連鎖誘爆でも起動しない
		if pvp_mode and pvp_my_player_index >= 0 and grid_skill_owner.size() == GRID_ROWS:
			var owner: int = grid_skill_owner[b.x][b.y]
			if owner >= 0 and owner != pvp_my_player_index:
				continue
		exploded_items[b] = true
		cells_cleared_by_special[b] = true

		var item_type: int = SpecialItemType.BOMB
		if special_item.size() == GRID_ROWS:
			item_type = special_item[b.x][b.y]
			if item_type == SpecialItemType.NONE and is_bomb.size() == GRID_ROWS and is_bomb[b.x][b.y]:
				item_type = SpecialItemType.BOMB
			special_item[b.x][b.y] = SpecialItemType.NONE
		if is_bomb.size() == GRID_ROWS:
			is_bomb[b.x][b.y] = false

		if _is_tutorial_mode():
			emit_signal("tutorial_special_detonated", item_type)

		var rm_sp = _get_relic_manager()
		if rm_sp: rm_sp.on_special_detonated(item_type)

		var pos = get_cell_position(b.x, b.y)

		var s_name = ""
		var s_elem = ""
		match item_type:
			SpecialItemType.BOMB, SpecialItemType.CHARGE_BOMB, SpecialItemType.GEMINI_BOMB, SpecialItemType.CROSS_BOMB:
				s_name = "bomb"
				s_elem = "fire"
			SpecialItemType.TORNADO:
				s_name = "tornado"
				s_elem = "wind"
			SpecialItemType.TREE_SPROUT:
				s_name = "tree_sprout"
				s_elem = "wood"
			SpecialItemType.LIGHTNING:
				s_name = "lightning"
				s_elem = "thunder"
			SpecialItemType.HOLY_LIGHT:
				s_name = "holy_star"
				s_elem = "player_skill_light"
			SpecialItemType.AQUA_SPLASH:
				s_name = "aqua_splash"
				s_elem = "water"
			SpecialItemType.DISCO_BALL, SpecialItemType.COLOR_CONVERTER:
				s_name = "disco_ball"
				s_elem = "light"
			SpecialItemType.BLACK_HOLE:
				s_name = "black_hole"
				s_elem = "dark"
			SpecialItemType.ICE_SHIELD:
				s_name = "ice_shield"
				s_elem = "ice"
			SpecialItemType.POISON_MIST:
				s_name = "poison_mist"
				s_elem = "poison"
		var e_enum = ElementDataScript.get_element_from_name(s_elem)
		if s_name != "":
			var sm_for_log = _get_score_manager()
			if sm_for_log and sm_for_log.has_method("add_turn_element"):
				if e_enum != ElementDataScript.Element.NONE:
					sm_for_log.add_turn_element(e_enum, 1)
			turn_skill_log.append({
				"name": s_name,
				"element": s_elem,
				"source": Vector2(b.x, b.y),
				"target": "all"
			})
		var pre_matched = ismatched.duplicate(true)
		match item_type:
			SpecialItemType.BOMB:
				_trigger_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.CROSS_BOMB:
				_trigger_cross_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.TORNADO:
				_trigger_tornado(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.LIGHTNING:
				_trigger_lightning(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.AQUA_SPLASH:
				_trigger_aqua_splash(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.TREE_SPROUT:
				_trigger_tree_sprout(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.DISCO_BALL:
				_trigger_disco_ball(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.COLOR_CONVERTER:
				_trigger_color_converter(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.BLACK_HOLE:
				_trigger_black_hole(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.HOLY_LIGHT:
				_trigger_holy_light(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.CHARGE_BOMB:
				_trigger_charge_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.GEMINI_BOMB:
				_trigger_gemini_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.ICE_SHIELD:
				_trigger_ice_shield(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.POISON_MIST:
				_trigger_poison_mist(b.x, b.y, pos, queue, exploded_items)
			_:
				_trigger_bomb(b.x, b.y, pos, queue, exploded_items)

		for nr in range(GRID_ROWS):
			for nc in range(GRID_COLUMNS):
				if ismatched[nr][nc] and not pre_matched[nr][nc]:
					cells_cleared_by_special[Vector2i(nr, nc)] = true
					if e_enum != ElementDataScript.Element.NONE and grid_element.size() == GRID_ROWS:
						if grid_i[nr][nc] != -1:
							grid_element[nr][nc] = e_enum



func _detonate_bombs(start_bombs: Array) -> void:
	_detonate_specials(start_bombs)

## 水蒸気エフェクト（火炎が水に触れたときの蒸発演出）
func _spawn_steam_effect(pos: Vector2) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null:
		effects_parent = self

	for i in range(5):
		var puff = Polygon2D.new()
		var pts: PackedVector2Array = []
		var r = randf_range(16.0, 32.0)
		for a in range(8):
			var th = a * TAU / 8.0
			pts.append(Vector2(cos(th), sin(th)) * r)
		puff.polygon = pts
		puff.color = Color(0.85, 0.95, 1.0, 0.65)
		puff.position = pos + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
		Profiler.add_child_count += 1; effects_parent.add_child(puff)

		var tw = create_tween().set_parallel(true)
		var rise_y = randf_range(60.0, 120.0)
		tw.tween_property(puff, "position:y", puff.position.y - rise_y, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "position:x", puff.position.x + randf_range(-20.0, 20.0), 0.45)
		tw.tween_property(puff, "scale", Vector2(1.8, 1.8), 0.45)
		tw.tween_property(puff, "color:a", 0.0, 0.45)
		tw.chain().tween_callback(puff.queue_free)

## 水マス設置処理（燃えた盤面に水がかぶさると消火される）
func _apply_water_to_cell(r: int, c: int, is_ally: bool = false) -> void:
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS:
		return
	if grid_fire.size() == GRID_ROWS and grid_fire[r][c] > 0:
		grid_fire[r][c] = 0
		_set_ally_flag(grid_fire_ally, r, c, false)
		_spawn_steam_effect(get_cell_position(r, c))
		_spawn_floating_text(get_cell_position(r, c), "消火", Color(0.4, 0.8, 1.0))
	if grid_water.size() == GRID_ROWS:
		grid_water[r][c] = true
		_set_ally_flag(grid_water_ally, r, c, is_ally)

## 毒マス設置処理
func _apply_poison_to_cell(r: int, c: int, is_ally: bool = false) -> void:
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS:
		return
	if grid_poison.size() == GRID_ROWS:
		grid_poison[r][c] = true
		_set_ally_flag(grid_poison_ally, r, c, is_ally)

## 水×火の隣接シナジー：水マスと火マスの両方に共通して隣接しているマスのみを消去し、水と火自体は消火（消滅）する
func _check_and_trigger_water_fire_synergy(in_match_phase: bool = false, queue: Array = [], exploded_items: Dictionary = {}) -> int:
	if grid_water.size() != GRID_ROWS or grid_fire.size() != GRID_ROWS:
		return 0

	var reacting_waters: Dictionary = {}
	var reacting_fires: Dictionary = {}
	var pairs: Array[Array] = []

	for r1 in range(GRID_ROWS):
		for c1 in range(GRID_COLUMNS):
			if not grid_water[r1][c1]:
				continue
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					if dr == 0 and dc == 0:
						continue
					var r2 = r1 + dr
					var c2 = c1 + dc
					if r2 >= 0 and r2 < GRID_ROWS and c2 >= 0 and c2 < GRID_COLUMNS:
						if int(grid_fire[r2][c2]) > 0:
							reacting_waters[Vector2i(r1, c1)] = true
							reacting_fires[Vector2i(r2, c2)] = true
							pairs.append([Vector2i(r1, c1), Vector2i(r2, c2)])

	if pairs.is_empty():
		return 0

	var common_cells: Dictionary = {}
	for pair in pairs:
		var w_pos: Vector2i = pair[0]
		var f_pos: Vector2i = pair[1]
		for nr in range(maxi(0, mini(w_pos.x, f_pos.x) - 1), mini(GRID_ROWS, maxi(w_pos.x, f_pos.x) + 2)):
			for nc in range(maxi(0, mini(w_pos.y, f_pos.y) - 1), mini(GRID_COLUMNS, maxi(w_pos.y, f_pos.y) + 2)):
				var cand = Vector2i(nr, nc)
				if cand == w_pos or cand == f_pos:
					continue
				if reacting_waters.has(cand) or reacting_fires.has(cand):
					continue
				var dist_w = maxi(abs(nr - w_pos.x), abs(nc - w_pos.y))
				var dist_f = maxi(abs(nr - f_pos.x), abs(nc - f_pos.y))
				if dist_w == 1 and dist_f == 1:
					common_cells[cand] = true

	# 🔥 B1 蒸気爆発: 自陣の火マスと水マスが接触した瞬間、周囲3×3の駒を消去して相手に大ダメージ
	if has_actor_skill_trait(true, "fire", "fire_final_b1"):
		for pair in pairs:
			for base_pos in pair:
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						var nr = base_pos.x + dr; var nc = base_pos.y + dc
						if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
							var cand = Vector2i(nr, nc)
							if not reacting_waters.has(cand) and not reacting_fires.has(cand):
								common_cells[cand] = true

	# 水と火自体は消火（消滅）する（その上のコマ自体は消さない）
	for w_cell in reacting_waters.keys():
		grid_water[w_cell.x][w_cell.y] = false
		_set_ally_flag(grid_water_ally, w_cell.x, w_cell.y, false)
		_spawn_steam_effect(get_cell_position(w_cell.x, w_cell.y))
	for f_cell in reacting_fires.keys():
		grid_fire[f_cell.x][f_cell.y] = 0
		_set_ally_flag(grid_fire_ally, f_cell.x, f_cell.y, false)
		_spawn_steam_effect(get_cell_position(f_cell.x, f_cell.y))

	# 共通して隣接しているマスのみを消去
	var cleared_count: int = 0
	var sm = _get_stage_manager()
	var stage_scale: float = pow(10.0, max(0, (sm.stage - 1) if sm else 0))

	for c_cell in common_cells.keys():
		var cr = c_cell.x
		var cc = c_cell.y
		var c_pos = get_cell_position(cr, cc)
		_spawn_steam_effect(c_pos)
		_spawn_floating_text(c_pos, "💨 水蒸気消去！", Color(0.5, 0.95, 1.0))

		if grid_stones.size() == GRID_ROWS and grid_stones[cr][cc] > 0:
			_damage_stone_at(cr, cc, 1)
		if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[cr][cc] > 0:
			grid_gold_statue[cr][cc] = maxi(0, grid_gold_statue[cr][cc] - 1)
		if grid_ice.size() == GRID_ROWS and int(grid_ice[cr][cc]) > 0:
			grid_ice[cr][cc] = maxi(0, int(grid_ice[cr][cc]) - 1)
		if grid_poison.size() == GRID_ROWS and grid_poison[cr][cc]:
			grid_poison[cr][cc] = false
			_set_ally_flag(grid_poison_ally, cr, cc, false)
		if grid_cursed.size() == GRID_ROWS and grid_cursed[cr][cc]:
			grid_cursed[cr][cc] = false
			_set_ally_flag(grid_cursed_ally, cr, cc, false)

		if ismatched.size() == GRID_ROWS:
			ismatched[cr][cc] = true
		cleared_count += 1

		var has_sp = (special_item.size() == GRID_ROWS and special_item[cr][cc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[cr][cc])
		if has_sp and not (c_cell in exploded_items):
			queue.append(c_cell)

		if not in_match_phase and grid_i.size() == GRID_ROWS and grid_i[cr][cc] >= 0:
			var p_idx = grid_i[cr][cc]
			if p_idx < piece.size() and piece[p_idx] != null:
				var new_k = _board_randi() % CELL_KINDS
				grid_n[cr][cc] = new_k
				grid_att[cr][cc] = new_k % 5
				piece[p_idx].texture = PIECE_TEXTURES[new_k]
				var tw = create_tween()
				piece[p_idx].scale = cellsize * 1.4
				tw.tween_property(piece[p_idx], "scale", cellsize, 0.22)

	if cleared_count > 0 and sm and not in_match_phase:
		var syn_dmg = float(cleared_count) * 180.0 * stage_scale
		var rm_wf = _get_relic_manager()
		if rm_wf and rm_wf.has_relic("flowing_water_charm"):
			syn_dmg *= (1.0 + float(rm_wf.get_param("flowing_water_charm", "synergy_bonus", 0.25)))
		sm.calchp(syn_dmg, 0.0, sm.get_focused_enemy_index() if sm.has_method("get_focused_enemy_index") else -1)
		_emit_combat_event("damage", "ally", "enemy", syn_dmg, "steam_synergy")

	_redraw_board_effects()
	return cleared_count


## 氷による隣接効果停止判定（氷がある間、隣接マスにある効果マスは進行・拡散が停止する）
func _is_cell_ice_locked(r: int, c: int) -> bool:
	if grid_ice.size() != GRID_ROWS:
		return false
	if int(grid_ice[r][c]) > 0:
		return true
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nr = r + offset.x
		var nc = c + offset.y
		if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
			if int(grid_ice[nr][nc]) > 0:
				return true
	return false

## 炎×氷の熱力学変化（氷→水→消える）：炎が氷に隣接すると、氷は水に融解し、炎は消火される
func _check_and_trigger_ice_fire_melting() -> int:
	if grid_fire.size() != GRID_ROWS or grid_ice.size() != GRID_ROWS:
		return 0

	var melting_ice: Dictionary = {}
	var consumed_fire: Dictionary = {}

	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if int(grid_fire[r][c]) <= 0:
				continue
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nr = r + offset.x
				var nc = c + offset.y
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					if int(grid_ice[nr][nc]) > 0:
						melting_ice[Vector2i(nr, nc)] = true
						consumed_fire[Vector2i(r, c)] = true

	if melting_ice.is_empty():
		return 0

	# 氷を水に融解（氷→水）
	for i_pos in melting_ice.keys():
		var was_ally = is_ally_ice(i_pos.x, i_pos.y)
		grid_ice[i_pos.x][i_pos.y] = 0
		_set_ally_flag(grid_ice_ally, i_pos.x, i_pos.y, false)
		if grid_water.size() == GRID_ROWS:
			grid_water[i_pos.x][i_pos.y] = true
			_set_ally_flag(grid_water_ally, i_pos.x, i_pos.y, was_ally)
		_spawn_ice_break_effect(get_cell_position(i_pos.x, i_pos.y))
		_spawn_steam_effect(get_cell_position(i_pos.x, i_pos.y))
		_spawn_floating_text(get_cell_position(i_pos.x, i_pos.y), "融解 (氷→水)！", Color(0.4, 0.85, 1.0))

	# 冷却により接触した炎を消火
	for f_pos in consumed_fire.keys():
		grid_fire[f_pos.x][f_pos.y] = 0
		_set_ally_flag(grid_fire_ally, f_pos.x, f_pos.y, false)
		_spawn_steam_effect(get_cell_position(f_pos.x, f_pos.y))

	_redraw_board_effects()
	return melting_ice.size()

## 氷×雷 / 石×雷 シナジー：凍結マスや岩石に雷が当たると破片が飛び散り周囲1マス（3x3）のコマも巻き込んで消去
func _trigger_thunder_shatter_synergy(r: int, c: int, in_match_phase: bool = false, queue: Array = [], exploded_items: Dictionary = {}) -> int:
	var has_ice: bool = (grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) > 0)
	var has_stone: bool = (grid_stones.size() == GRID_ROWS and int(grid_stones[r][c]) > 0)
	if not has_ice and not has_stone:
		return 0

	var center_pos = get_cell_position(r, c)
	if has_ice:
		grid_ice[r][c] = 0
		_set_ally_flag(grid_ice_ally, r, c, false)
		_spawn_ice_break_effect(center_pos)
		_spawn_floating_text(center_pos, "⚡❄ 氷雷砕破！", Color(0.55, 0.98, 1.0))
	if has_stone:
		grid_stones[r][c] = 0
		_set_ally_flag(grid_stones_ally, r, c, false)
		_spawn_stone_break_effect(center_pos)
		_spawn_floating_text(center_pos, "⚡🪨 岩雷砕破！", Color(1.0, 0.88, 0.45))

	var cleared: int = 0
	var sm = _get_stage_manager()
	var stage_scale: float = pow(10.0, max(0, (sm.stage - 1) if sm else 0))

	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			var nr = r + dr
			var nc = c + dc
			if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLUMNS:
				continue
			if _is_plant_cell(nr, nc):
				continue
			var n_pos = get_cell_position(nr, nc)
			if not (dr == 0 and dc == 0):
				if has_ice:
					_spawn_ice_break_effect(n_pos)
				else:
					_spawn_stone_break_effect(n_pos)
			if ismatched.size() == GRID_ROWS:
				ismatched[nr][nc] = true
			cleared += 1

			var n_cell = Vector2i(nr, nc)
			var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
			if has_sp and not (n_cell in exploded_items):
				queue.append(n_cell)

			if not in_match_phase and grid_i.size() == GRID_ROWS and grid_i[nr][nc] >= 0:
				var p_idx = grid_i[nr][nc]
				if p_idx < piece.size() and piece[p_idx] != null:
					var new_k = _board_randi() % CELL_KINDS
					grid_n[nr][nc] = new_k
					grid_att[nr][nc] = new_k % 5
					piece[p_idx].texture = PIECE_TEXTURES[new_k]

	if cleared > 0 and sm and not in_match_phase:
		var syn_dmg = float(cleared) * 160.0 * stage_scale
		var rm_sh = _get_relic_manager()
		if rm_sh and has_ice and rm_sh.has_relic("ice_crystal_crown"):
			syn_dmg *= (1.0 + float(rm_sh.get_param("ice_crystal_crown", "shatter_bonus", 1.00)))
		sm.calchp(syn_dmg, 0.0, sm.get_focused_enemy_index() if sm.has_method("get_focused_enemy_index") else -1)
		_emit_combat_event("damage", "ally", "enemy", syn_dmg, "shatter_synergy")

	_redraw_board_effects()
	return cleared

## 石マスへの被ダメージ処理（耐久値減少・0で粉砕破壊）
func _damage_stone_at(r: int, c: int, dmg: int = 1) -> bool:
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS:
		return false
	if grid_stones.size() != GRID_ROWS or grid_stones[r][c] <= 0:
		return false

	var prev_dur = grid_stones[r][c]
	grid_stones[r][c] -= dmg
	var pos = get_cell_position(r, c)
	if grid_stones[r][c] <= 0:
		grid_stones[r][c] = 0
		stone_turn_counts.erase(Vector2i(r, c))
		diamond_stones.erase(Vector2i(r, c))
		var broken_dur = maxi(1, prev_dur)
		var rm_h = _get_relic_manager()
		if rm_h:
			rm_h.on_hazard_destroyed("stone", 1)
		_spawn_stone_break_effect(pos)
		_spawn_floating_text(pos, "石粉砕", Color(0.8, 0.8, 0.7))

		var score_mgr_st = _get_score_manager()
		var sm_st = _get_stage_manager()
		var st_scale = pow(10, max(0, (sm_st.stage - 1) if sm_st else 0))
		var sk_lvl_st = maxi(1, score_mgr_st.get_skill_level("earth_1")) if score_mgr_st and score_mgr_st.has_method("get_skill_level") else 1

		# 🪨 地A2: 飛礫 (石破壊時、耐久値1の小石2個を空きマスに生成)
		if score_mgr_st and score_mgr_st.has_method("has_skill_trait") and score_mgr_st.has_skill_trait("earth_1", "earth_final_a2"):
			var candidates_st: Array[Vector2i] = []
			for cr in range(GRID_ROWS):
				for cc in range(GRID_COLUMNS):
					if grid_stones[cr][cc] == 0 and not _is_plant_cell(cr, cc) and grid_i[cr][cc] != -1:
						candidates_st.append(Vector2i(cr, cc))
			candidates_st.shuffle()
			var count_pebbles = mini(2, candidates_st.size())
			for pi in range(count_pebbles):
				var p_cell = candidates_st[pi]
				grid_stones[p_cell.x][p_cell.y] = 1 # 飛礫は耐久値1
				_set_ally_flag(grid_stones_ally, p_cell.x, p_cell.y, true)
				_spawn_floating_text(get_cell_position(p_cell.x, p_cell.y), "🪨 飛礫！", Color(0.85, 0.75, 0.6))

		# 🪨 地B2: 金剛石 (ダイヤモンド化した石の破壊時シールド1500＆コイン1000)
		var st_v2 = Vector2i(r, c)
		if diamond_stones.get(st_v2, false):
			diamond_stones.erase(st_v2)
			_apply_skill_shield(1500.0 * st_scale)
			if score_mgr_st and "divscore" in score_mgr_st:
				score_mgr_st.divscore[PieceType.COIN] = score_mgr_st.divscore.get(PieceType.COIN, 0) + 1000
			_spawn_floating_text(pos, "💎 ダイヤモンド粉砕！防+1500＆金+1000！", Color(0.3, 0.95, 1.0))

		# 🪨 地C: 落石・連鎖崩落・地割れ
		if score_mgr_st and score_mgr_st.has_method("has_skill_trait"):
			var base_rock_dmg = (150.0 + float(broken_dur) * 50.0) * st_scale
			if score_mgr_st.has_skill_trait("earth_1", "earth_final_c2"):
				# 地割れ: 石破壊時、周囲8マスの敵妨害マス（火・毒・氷・暗雲）を除去
				var cleared_hazards = 0
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0: continue
						var nr = r + dr; var nc = c + dc
						if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
							if grid_fire.size() == GRID_ROWS and grid_fire[nr][nc] > 0 and not is_ally_fire(nr, nc):
								grid_fire[nr][nc] = 0; cleared_hazards += 1
							if grid_poison.size() == GRID_ROWS and grid_poison[nr][nc] and not is_ally_poison(nr, nc):
								grid_poison[nr][nc] = false; cleared_hazards += 1
							if grid_ice.size() == GRID_ROWS and int(grid_ice[nr][nc]) > 0 and not is_ally_ice(nr, nc):
								grid_ice[nr][nc] = 0; cleared_hazards += 1
				var f_idx = grid_fog.size() - 1
				while f_idx >= 0:
					var fog = grid_fog[f_idx]
					if fog.get("enemy_owned", true):
						var f_rect: Rect2i = fog.get("rect", Rect2i(0, 0, 0, 0))
						if f_rect.has_point(Vector2i(r, c)):
							grid_fog.remove_at(f_idx)
							cleared_hazards += 1
					f_idx -= 1
				_spawn_floating_text(pos, "🪨 地割れ！周囲敵ハザード除去(%d)！" % cleared_hazards, Color(0.8, 0.6, 0.3))
			elif score_mgr_st.has_skill_trait("earth_1", "earth_final_c1"):
				# 連鎖崩落: 隣接する石も連鎖して壊れダメージ合算
				var chain_dmg = base_rock_dmg
				for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
					var ar = r + offset.x; var ac = c + offset.y
					if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS and grid_stones.size() == GRID_ROWS and grid_stones[ar][ac] > 0:
						var adj_dur = maxi(1, grid_stones[ar][ac])
						grid_stones[ar][ac] = 0
						chain_dmg += (150.0 + float(adj_dur) * 50.0) * st_scale
						_spawn_stone_break_effect(get_cell_position(ar, ac))
				if sm_st and sm_st.ehp > 0 and not sm_st.isdeadf:
					sm_st.calchp(chain_dmg, 0.0)
					_emit_combat_event("damage", "ally", "enemy", chain_dmg, "earth_chain_collapse")
					_spawn_floating_text(pos, "🪨 連鎖崩落 -%d!" % int(chain_dmg), Color(0.85, 0.65, 0.3))
			elif score_mgr_st.has_skill_trait("earth_1", "earth_mid_c"):
				if sm_st and sm_st.ehp > 0 and not sm_st.isdeadf:
					sm_st.calchp(base_rock_dmg, 0.0)
					_emit_combat_event("damage", "ally", "enemy", base_rock_dmg, "earth_falling_rocks")
					_spawn_floating_text(pos, "🪨 砕石破片(耐久%d) -%d!" % [broken_dur, int(base_rock_dmg)], Color(0.8, 0.7, 0.3))

		# 🔥 火C: 破砕熱・火砕流 (石破壊時破片飛散、着弾地点火マス化＆敵ダメージ)
		if score_mgr_st and score_mgr_st.has_method("has_skill_trait"):
			if score_mgr_st.has_skill_trait("fire_1", "fire_mid_c") or score_mgr_st.has_skill_trait("fire_1", "fire_final_c1"):
				var sk_lvl_f = maxi(1, score_mgr_st.get_skill_level("fire_1"))
				for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
					var fr = r + offset.x; var fc = c + offset.y
					if fr >= 0 and fr < GRID_ROWS and fc >= 0 and fc < GRID_COLUMNS:
						if grid_i.size() == GRID_ROWS and grid_i[fr][fc] != -1:
							ismatched[fr][fc] = true
						if score_mgr_st.has_skill_trait("fire_1", "fire_final_c1"):
							grid_fire[fr][fc] = maxi(int(grid_fire[fr][fc]), 1)
							_set_ally_flag(grid_fire_ally, fr, fc, true)
						_spawn_shrapnel_fragment_vfx(pos, get_cell_position(fr, fc), score_mgr_st.has_skill_trait("fire_1", "fire_final_c1"), true)
				if score_mgr_st.has_skill_trait("fire_1", "fire_final_c1"):
					var pyro_dmg = (120.0 + sk_lvl_f * 25.0) * st_scale
					if sm_st and sm_st.ehp > 0 and not sm_st.isdeadf:
						sm_st.calchp(pyro_dmg, 0.0)
						_emit_combat_event("damage", "ally", "enemy", pyro_dmg, "fire_pyroclastic")
						_spawn_floating_text(pos, "🔥 火砕流 -%d!" % int(pyro_dmg), Color(1.0, 0.4, 0.1))
	else:
		_spawn_stone_break_effect(pos)
		_spawn_floating_text(pos, "耐久-%d" % dmg, Color(0.7, 0.7, 0.6))

	_redraw_board_effects()
	return true

# --- 各アイテムの個別アクション処理 ---

func _trigger_ice_shield(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.ICE_SHIELD, 1))
	var tier: int = 1
	if lvl >= 10: tier = 3
	elif lvl >= 5: tier = 2
	# 起爆した氷スキル駒自体は確実にマッチ消去対象とし、特殊アイテム・爆弾属性を解除
	ismatched[r][c] = true
	if special_item.size() == GRID_ROWS:
		special_item[r][c] = SpecialItemType.NONE
	if is_bomb.size() == GRID_ROWS:
		is_bomb[r][c] = false
	# 氷スキル基本形: 周囲駒は消さず、ランダムな複数マスを氷マスに変換する
	cast_player_skill("ice", true, tier, true, pos)

func _trigger_poison_mist(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.POISON_MIST, 1))

	# 起爆した毒スキル駒自体は確実にマッチ消去対象とし、特殊アイテム・爆弾属性を解除
	ismatched[r][c] = true
	if special_item.size() == GRID_ROWS:
		special_item[r][c] = SpecialItemType.NONE
	if is_bomb.size() == GRID_ROWS:
		is_bomb[r][c] = false
	poison_mist_detonated_cells[Vector2i(r, c)] = true

	_spawn_poison_bubble_burst_effect(pos)

	var sm = _get_stage_manager()
	var stage_scale: float = pow(10.0, max(0, (sm.stage - 1) if sm else 0))
	var poison_dmg: float = (90.0 + float(lvl) * 20.0) * stage_scale
	if sm:
		sm.calchp(poison_dmg, 0.0, sm.get_focused_enemy_index() if sm.has_method("get_focused_enemy_index") else -1)
		_emit_combat_event("damage", "ally", "enemy", poison_dmg, "player_skill_poison")

	_ensure_ally_grids()

	# 火・氷・光スキルと同様に、盤面全体からランダムに対象を選んで毒マスを展開する
	# （周囲マスを優先するのではなく、完全ランダム配置）
	var candidates: Array[Vector2i] = []
	for ar in range(GRID_ROWS):
		for ac in range(GRID_COLUMNS):
			if not _is_plant_cell(ar, ac):
				candidates.append(Vector2i(ar, ac))
	candidates.shuffle()

	var base_count: int = 3 + int((lvl - 1) / 2)
	var actual_count: int = mini(base_count, candidates.size())
	var init_stage: int = 3 if has_actor_skill_trait(true, "poison", "poison_mid_a") else 2
	var rm_p = _get_relic_manager()
	if rm_p and rm_p.has_relic("venom_crown"):
		init_stage += int(rm_p.get_param("venom_crown", "stage_bonus", 1))

	var poisoned_cells: Array[Vector2i] = []
	for i in range(actual_count):
		var cell = candidates[i]
		grid_poison[cell.x][cell.y] = true
		_set_ally_flag(grid_poison_ally, cell.x, cell.y, true)
		if grid_poison_stage.size() == GRID_ROWS:
			grid_poison_stage[cell.x][cell.y] = init_stage
		poisoned_cells.append(cell)
		if cell != Vector2i(r, c):
			_spawn_poison_bubble_burst_effect(get_cell_position(cell.x, cell.y))

		var has_sp = (special_item.size() == GRID_ROWS and special_item[cell.x][cell.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[cell.x][cell.y])
		if has_sp and not (cell in exploded_items):
			queue.append(cell)

	# 毒マス上の駒を消去して落下させる（火スキルと同じ挙動）
	if poisoned_cells.size() > 0:
		_clear_pieces_in_cells(poisoned_cells, "ally")
	ismatched[r][c] = true

	_play_poison_expansion(poisoned_cells, pos, true)
	_spawn_floating_text(pos, "🧪 劇毒散布！", Color(0.2, 1.0, 0.6))
	_redraw_board_effects()


## 爆発巻き込み駒の破片飛散演出（ブレイズブラスト・爆弾の破片＆榴弾進化）
func _spawn_shrapnel_fragment_vfx(start_pos: Vector2, target_pos: Vector2, is_howitzer: bool = false, is_ally: bool = true) -> void:
	var effects_parent = _get_effects_parent()
	if effects_parent == null:
		return

	# 飛散破片本体（燃え盛る多角形の破片）
	var shard = Polygon2D.new()
	var shard_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-14, 0), Vector2(-4, -18), Vector2(16, -6),
		Vector2(20, 8), Vector2(2, 18), Vector2(-10, 10)
	])
	shard.polygon = shard_pts
	if is_howitzer:
		shard.color = Color(1.0, 0.35, 0.1, 0.95) if is_ally else Color(1.0, 0.15, 0.2, 0.95)
	else:
		shard.color = Color(1.0, 0.85, 0.25, 0.95) if is_ally else Color(1.0, 0.45, 0.15, 0.95)
	shard.position = start_pos
	shard.scale = Vector2(0.85, 0.85)
	shard.z_index = 45
	Profiler.add_child_count += 1
	effects_parent.add_child(shard)

	# 破片の火花コア
	var core = Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(0, -8), Vector2(8, 0), Vector2(0, 8)
	])
	core.color = Color(1.0, 1.0, 1.0, 0.98)
	shard.add_child(core)

	# 発射・飛翔・着弾アニメーション（高速アーク軌道で目標地点へ突入）
	var duration: float = 0.22
	var tw = shard.create_tween()
	var mid_pos = (start_pos + target_pos) * 0.5 + Vector2(randf_range(-25, 25), -60.0)

	tw.tween_method(func(t: float):
		if is_instance_valid(shard):
			var p0 = start_pos
			var p1 = mid_pos
			var p2 = target_pos
			var cur_p = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
			shard.position = cur_p
			shard.rotation += 0.40
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(func():
		if is_instance_valid(shard):
			_spawn_fire_ignition_effect(target_pos, is_ally)
			_spawn_floating_text(target_pos, "🔥 榴弾着火!" if is_howitzer else "破片消去!", Color(1.0, 0.4, 0.1) if is_howitzer else Color(1.0, 0.85, 0.2))
			shard.queue_free()
	)

## 火属性進化C【破片 / 榴弾】の破片飛散＆隣接駒消去処理
func _trigger_fire_shrapnel_evolution(exploded_cells: Array[Vector2i], is_ally: bool = true, queue: Array = [], exploded_items: Dictionary = {}) -> void:
	var has_shrapnel = has_actor_skill_trait(is_ally, "fire", "fire_mid_c")
	var has_howitzer = has_actor_skill_trait(is_ally, "fire", "fire_final_c1")
	if not has_shrapnel and not has_howitzer:
		return
	if exploded_cells.is_empty():
		return

	var sm = _get_stage_manager()
	var score_mgr = _get_score_manager()
	var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
	var sk_lvl: int = 1
	if score_mgr and score_mgr.has_method("get_skill_level"):
		sk_lvl = maxi(1, score_mgr.get_skill_level("fire_1"))
	var st_idx: int = _get_stage_index()

	# 巻き込まれた駒から隣接する未消去の駒を探索
	var candidate_pairs: Array[Dictionary] = []
	var targeted_cells: Dictionary = {}

	for ec in exploded_cells:
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr == 0 and dc == 0: continue
				var nr = ec.x + dr; var nc = ec.y + dc
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					var target_v = Vector2i(nr, nc)
					if not target_v in exploded_cells and not targeted_cells.has(target_v):
						if grid_i[nr][nc] != -1 and not _is_plant_cell(nr, nc):
							candidate_pairs.append({"src": ec, "dst": target_v})
							targeted_cells[target_v] = true

	if candidate_pairs.is_empty():
		return

	candidate_pairs.shuffle()
	var max_shards = mini(candidate_pairs.size(), maxi(2, mini(6, exploded_cells.size() * 2)))
	var cleared_cells: Array[Vector2i] = []

	for i in range(max_shards):
		var pair = candidate_pairs[i]
		var src_cell: Vector2i = pair["src"]
		var dst_cell: Vector2i = pair["dst"]
		var start_p = get_cell_position(src_cell.x, src_cell.y)
		var target_p = get_cell_position(dst_cell.x, dst_cell.y)

		ismatched[dst_cell.x][dst_cell.y] = true
		cleared_cells.append(dst_cell)

		# 榴弾 (fire_final_c1): 着弾マス炎上 ＆ ダメージ
		if has_howitzer:
			grid_fire[dst_cell.x][dst_cell.y] = 1
			_set_ally_flag(grid_fire_ally, dst_cell.x, dst_cell.y, is_ally)
			if is_ally:
				var h_dmg = (50.0 + sk_lvl * 15.0) * stage_scale
				if sm and sm.ehp > 0:
					sm.calchp(h_dmg, 0.0)
					_emit_combat_event("damage", "ally", "enemy", h_dmg, "fire_howitzer")
			else:
				var e_h_dmg = (25.0 + st_idx * 10.0) * stage_scale
				if sm:
					sm.last_damage_cause = "敵の榴弾爆破"
					sm.calchp(0.0, e_h_dmg)
					_emit_combat_event("damage", "enemy", "ally", e_h_dmg, "fire_howitzer")

		# 特殊アイテム連鎖起爆
		var has_sp = (special_item.size() == GRID_ROWS and special_item[dst_cell.x][dst_cell.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[dst_cell.x][dst_cell.y])
		if has_sp and not (dst_cell in exploded_items):
			queue.append(dst_cell)

		_spawn_shrapnel_fragment_vfx(start_p, target_p, has_howitzer, is_ally)

	last_shrapnel_cleared_cells = cleared_cells.duplicate()

	# 敵発動時かつマッチフェーズ外の場合はその場で駒を消去・落下開始
	if not is_ally and current_state == BoardState.IDLE and cleared_cells.size() > 0:
		current_clear_source = "enemy"
		_clear_pieces_in_cells(cleared_cells, "enemy")
		_start_continuous_falling()
		current_clear_source = "ally"

func _trigger_bomb(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	# 仕様変更(I7): 火スキル駒（フレイムボム → ブレイズブラスト）の味方版換装
	var lvl: int = max(1, special_levels.get(SpecialItemType.BOMB, 1))
	var fire_lifetime: int = DEFAULT_FIRE_LIFETIME + int((lvl - 1) / 3)
	var base_count: int = 3 + int((lvl - 1) / 2)
	var rm_b = _get_relic_manager()
	if rm_b:
		if rm_b.has_relic("demolition_book"):
			base_count += int(rm_b.get_param("demolition_book", "blast_range", 1))
		if rm_b.has_relic("blazing_fire_orb"):
			base_count += int(rm_b.get_param("blazing_fire_orb", "range_bonus", 2))
	var count: int = mini(base_count, GRID_ROWS * GRID_COLUMNS)

	var sm = _get_stage_manager()
	var score_mgr = _get_score_manager()
	var stage_scale: float = pow(10.0, max(0, (sm.stage - 1) if sm else 0))

	# 起爆した火スキル駒自身は必ず消去対象にする
	ismatched[r][c] = true
	if special_item.size() == GRID_ROWS:
		special_item[r][c] = SpecialItemType.NONE
	if is_bomb.size() == GRID_ROWS:
		is_bomb[r][c] = false
	_spawn_fire_ignition_effect(pos, true)
	_spawn_floating_text(pos, "🔥 蒼炎！", Color(1.0, 0.45, 0.1))

	# 毒スキルと同様に、盤面全体からランダムに炎マスを選ぶ（周囲優先はしない）
	var candidates: Array[Vector2i] = []
	var empty_candidates: Array[Vector2i] = []
	for ar in range(GRID_ROWS):
		for ac in range(GRID_COLUMNS):
			if _is_plant_cell(ar, ac) or int(grid_fire[ar][ac]) != 0:
				continue
			if grid_i.size() == GRID_ROWS and grid_i[ar][ac] != -1:
				candidates.append(Vector2i(ar, ac))
			else:
				empty_candidates.append(Vector2i(ar, ac))
	candidates.shuffle()
	empty_candidates.shuffle()
	candidates.append_array(empty_candidates)
	if candidates.is_empty():
		for ar in range(GRID_ROWS):
			for ac in range(GRID_COLUMNS):
				if not _is_plant_cell(ar, ac):
					candidates.append(Vector2i(ar, ac))
		candidates.shuffle()

	var actual_count: int = mini(count, candidates.size())

	# 🔥 C2 十字炎: 爆発が十字方向に盤端まで延伸
	if has_actor_skill_trait(true, "fire", "fire_final_c2"):
		_spawn_cross_effect(pos, 3)
		_spawn_floating_text(pos, "🔥 十字炎！", Color(1.0, 0.45, 0.1))
		for cr in range(GRID_ROWS):
			var cp = Vector2i(cr, c)
			if not candidates.has(cp) and not _is_plant_cell(cr, c):
				candidates.insert(0, cp)
		for cc in range(GRID_COLUMNS):
			var cp = Vector2i(r, cc)
			if not candidates.has(cp) and not _is_plant_cell(r, cc):
				candidates.insert(0, cp)
		actual_count = mini(actual_count + GRID_ROWS + GRID_COLUMNS, candidates.size())

	var ignited_cells: Array[Vector2i] = []
	_ensure_ally_grids()

	for i in range(actual_count):
		var cell = candidates[i]
		ignited_cells.append(cell)
		grid_fire[cell.x][cell.y] = maxi(int(grid_fire[cell.x][cell.y]), fire_lifetime)
		_set_ally_flag(grid_fire_ally, cell.x, cell.y, true)
		var c_pos = get_cell_position(cell.x, cell.y)
		_spawn_fire_ignition_effect(c_pos, true)
		_spawn_floating_text(c_pos, "🔥 ブレイズブラスト！", Color(1.0, 0.45, 0.1))

		var has_sp = (special_item.size() == GRID_ROWS and special_item[cell.x][cell.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[cell.x][cell.y])
		if has_sp and not (cell in exploded_items):
			queue.append(cell)

	# 敵への火属性ダメージ
	var blast_dmg: float = (80.0 + lvl * 20.0) * stage_scale
	if sm and sm.ehp > 0 and not sm.isdeadf:
		sm.calchp(blast_dmg, 0.0)
		_emit_combat_event("damage", "ally", "enemy", blast_dmg, "player_skill_fire")

	# 火マス上の駒を消去
	if ignited_cells.size() > 0:
		_clear_pieces_in_cells(ignited_cells, "ally")

	# 破片・榴弾進化 (fire_mid_c, fire_final_c1)
	if has_actor_skill_trait(true, "fire", "fire_mid_c") or has_actor_skill_trait(true, "fire", "fire_final_c1"):
		_trigger_fire_shrapnel_evolution(ignited_cells, true, queue, exploded_items)

	# 延焼進化 (fire_mid_b)
	if has_actor_skill_trait(true, "fire", "fire_mid_b"):
		_process_fire_spread()

	_check_and_trigger_ice_fire_melting()
	_check_and_trigger_water_fire_synergy(true, queue, exploded_items)
	_redraw_board_effects()

func _trigger_cross_bomb(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.CROSS_BOMB, 1))
	_spawn_cross_effect(pos, lvl)

	var r_reach: int = 2 # Lv1: 縦5マス (上下2マス+中心)
	var c_reach: int = 2 # Lv1: 横5マス (左右2マス+中心)
	if lvl == 2:
		r_reach = 4 # Lv2: 縦9マス
		c_reach = 4 # Lv2: 横9マス
	elif lvl >= 3:
		r_reach = GRID_ROWS # Lv3: 全画面十字
		c_reach = GRID_COLUMNS

	var stone_dmg: int = 1 + int((lvl - 1) / 4)
	var cross_width: int = 1 if lvl >= 12 else 0
	var exploded_cells: Array[Vector2i] = []

	# 縦方向
	for dr in range(-r_reach, r_reach + 1):
		for dw in range(-cross_width, cross_width + 1):
			var nr = r + dr
			var nc = c + dw
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
					_damage_stone_at(nr, nc, stone_dmg)
					if grid_stones[nr][nc] == 0 and grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						if not Vector2i(nr, nc) in exploded_cells: exploded_cells.append(Vector2i(nr, nc))
					continue

				var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][nc])
				if is_water:
					grid_water[nr][nc] = false
					_spawn_steam_effect(get_cell_position(nr, nc))
				else:
					if grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						if not Vector2i(nr, nc) in exploded_cells: exploded_cells.append(Vector2i(nr, nc))
						var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
						if has_sp and not (Vector2i(nr, nc) in exploded_items):
							queue.append(Vector2i(nr, nc))

	# 横方向
	for dc in range(-c_reach, c_reach + 1):
		for dw in range(-cross_width, cross_width + 1):
			var nr = r + dw
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
					_damage_stone_at(nr, nc, stone_dmg)
					if grid_stones[nr][nc] == 0 and grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						if not Vector2i(nr, nc) in exploded_cells: exploded_cells.append(Vector2i(nr, nc))
					continue

				var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][nc])
				if is_water:
					grid_water[nr][nc] = false
					_spawn_steam_effect(get_cell_position(nr, nc))
				else:
					if grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						if not Vector2i(nr, nc) in exploded_cells: exploded_cells.append(Vector2i(nr, nc))
						var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
						if has_sp and not (Vector2i(nr, nc) in exploded_items):
							queue.append(Vector2i(nr, nc))

	_check_burn_plants_in_rect(r - r_reach, r + r_reach, c - cross_width, c + cross_width, queue, exploded_items)
	_check_burn_plants_in_rect(r - cross_width, r + cross_width, c - c_reach, c + c_reach, queue, exploded_items)
	_trigger_fire_shrapnel_evolution(exploded_cells, true, queue, exploded_items)


func _trigger_tornado(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.TORNADO, 1))
	var half_w: int = 0 # Lv1: 幅1マス (つむじ風)
	if lvl >= 7:
		half_w = 2 # Lv7+: 幅5マス (天災大竜巻)
	elif lvl >= 2:
		half_w = 1 # Lv2: 幅3マス (疾風竜巻)

	var score_mgr = _get_score_manager()
	var has_wi_wide = score_mgr and score_mgr.has_method("has_skill_trait") and (score_mgr.has_skill_trait("wind_1", "wind_mid_a") or score_mgr.has_skill_trait("wind_1", "wind_final_b1"))
	var has_wi_sweep = score_mgr and score_mgr.has_method("has_skill_trait") and score_mgr.has_skill_trait("wind_1", "wind_mid_b")

	# 仕様変更(I6): 進化特性(wind_mid_a/wind_final_b1)で隣接列へ竜巻拡大（幅+1）
	if has_wi_wide:
		half_w = mini(GRID_COLUMNS / 2, half_w + 1)

	_spawn_tornado_effect(pos, lvl, half_w)

	var hit_plants: Array = []
	var tornado_dmg: int = 1 + int((lvl - 1) / 4)
	var swept_normal_pieces: int = 0

	# 起爆したトルネード駒自体は確実に消費・消去対象とする
	ismatched[r][c] = true
	if special_item.size() == GRID_ROWS:
		special_item[r][c] = SpecialItemType.NONE
	if is_bomb.size() == GRID_ROWS:
		is_bomb[r][c] = false

	# 仕様: 列全体（全行 0 〜 GRID_ROWS - 1）の直線状の床効果・ハザードを一掃消去
	# 【重要】進化前（wind_mid_b 未所持）は通常駒は消去せず、直線状の効果（水・炎・毒・石・植物等）のみを消去する。
	# 進化「突風」(wind_mid_b) 所持時のみ、通常駒も巻き込んで消去する。
	var row_range: Array[int] = []
	for nr in range(GRID_ROWS):
		row_range.append(nr)

	for nr in row_range:
		for dc in range(-half_w, half_w + 1):
			var nc = c + dc
			if nc >= 0 and nc < GRID_COLUMNS:
				if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
					_damage_stone_at(nr, nc, tornado_dmg)
					if grid_stones[nr][nc] == 0 and has_wi_sweep and grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
					continue

				if grid_water.size() == GRID_ROWS:
					grid_water[nr][nc] = false
				if grid_fire.size() == GRID_ROWS and not is_ally_fire(nr, nc):
					grid_fire[nr][nc] = 0
				if grid_poison.size() == GRID_ROWS and not is_ally_poison(nr, nc):
					grid_poison[nr][nc] = false
				if grid_cursed.size() == GRID_ROWS and not is_ally_cursed(nr, nc):
					grid_cursed[nr][nc] = false
				if grid_electrified.size() == GRID_ROWS and not is_ally_electrified(nr, nc):
					grid_electrified[nr][nc] = false

				if grid_i[nr][nc] != -1:
					var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
					if has_sp:
						ismatched[nr][nc] = true
						if not (Vector2i(nr, nc) in exploded_items):
							queue.append(Vector2i(nr, nc))
					elif has_wi_sweep:
						swept_normal_pieces += 1
						ismatched[nr][nc] = true

				var plant = _get_plant_at(nr, nc)
				if not plant.is_empty() and not (plant in hit_plants):
					hit_plants.append(plant)

	for p in hit_plants:
		_damage_plant(p, tornado_dmg, "tornado")

	# 自陣の通常駒削除追撃ダメージ
	if has_wi_sweep and swept_normal_pieces > 0:
		var sm = _get_stage_manager()
		var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
		var sweep_extra_dmg: float = float(swept_normal_pieces) * (25.0 + lvl * 6.0) * stage_scale
		if sm and sm.ehp > 0 and not sm.isdeadf:
			sm.calchp(sweep_extra_dmg, 0.0)
			_emit_combat_event("damage", "ally", "enemy", sweep_extra_dmg, "wind_sweep")
			_spawn_floating_text(pos, "🌪️ 暴風一掃 (駒%d個削除追撃 -%d)！" % [swept_normal_pieces, int(sweep_extra_dmg)], Color(0.2, 1.0, 0.7))

func _trigger_lightning(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.LIGHTNING, 1))
	var target_count: int = mini(GRID_ROWS * GRID_COLUMNS, 3 + int(lvl * 1.1))
	var stone_dmg: int = 2 + int((lvl - 1) / 3)

	ismatched[r][c] = true

	var candidates: Array[Vector2i] = []
	for nr in range(GRID_ROWS):
		for nc in range(GRID_COLUMNS):
			if grid_i[nr][nc] != -1 and not (nr == r and nc == c):
				candidates.append(Vector2i(nr, nc))
	candidates.shuffle()

	var targets: Array[Vector2] = []
	var water_hits: Array[Vector2i] = []
	var hit_plants: Array = []

	if grid_water.size() == GRID_ROWS and grid_water[r][c]:
		water_hits.append(Vector2i(r, c))

	var center_plant = _get_plant_at(r, c)
	if not center_plant.is_empty() and not (center_plant in hit_plants):
		hit_plants.append(center_plant)

	var score_mgr_th = _get_score_manager()
	var has_th_reflection = score_mgr_th and score_mgr_th.has_method("has_skill_trait") and (score_mgr_th.has_skill_trait("thunder_1", "thunder_mid_a") or score_mgr_th.has_skill_trait("thunder_1", "thunder_final_a1") or score_mgr_th.has_skill_trait("thunder_1", "thunder_final_a2"))

	# 発動位置 (r, c) 自体にオブジェクトが存在する場合の即時反射
	var origin_is_object = (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0) or 						   (grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) > 0) or 						   (not _get_plant_at(r, c).is_empty()) or 						   (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0) or 						   (special_item.size() == GRID_ROWS and special_item[r][c] != SpecialItemType.NONE) or 						   (is_bomb.size() == GRID_ROWS and is_bomb[r][c])
	if has_th_reflection and origin_is_object:
		var origin_bounces = [
			Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)
		]
		origin_bounces.shuffle()
		var o_bounced = 0
		for bo in origin_bounces:
			var obr = r + bo.x; var obc = c + bo.y
			if obr >= 0 and obr < GRID_ROWS and obc >= 0 and obc < GRID_COLUMNS:
				var ob_pos = get_cell_position(obr, obc)
				targets.append(ob_pos)
				_spawn_shock_zap_effect(ob_pos)
				if (grid_stones.size() == GRID_ROWS and grid_stones[obr][obc] > 0) or (grid_ice.size() == GRID_ROWS and int(grid_ice[obr][obc]) > 0):
					_trigger_thunder_shatter_synergy(obr, obc, true, queue, exploded_items)
				elif grid_i.size() == GRID_ROWS and grid_i[obr][obc] != -1:
					ismatched[obr][obc] = true
				o_bounced += 1
				if o_bounced >= 2: break
		_spawn_floating_text(pos, "⚡ 雷光反射！", Color(1.0, 1.0, 0.3))

	for k in range(mini(target_count, candidates.size())):
		var cp = candidates[k]
		targets.append(get_cell_position(cp.x, cp.y))

		var is_object = (grid_stones.size() == GRID_ROWS and grid_stones[cp.x][cp.y] > 0) or 						(grid_ice.size() == GRID_ROWS and int(grid_ice[cp.x][cp.y]) > 0) or 						(not _get_plant_at(cp.x, cp.y).is_empty()) or 						(grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[cp.x][cp.y] > 0) or 						(special_item.size() == GRID_ROWS and special_item[cp.x][cp.y] != SpecialItemType.NONE) or 						(is_bomb.size() == GRID_ROWS and is_bomb[cp.x][cp.y])

		# 雷の進化：オブジェクトに当たったときに反射する
		if has_th_reflection and is_object:
			var bounce_offsets = [
				Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
				Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)
			]
			bounce_offsets.shuffle()
			var bounced_cnt = 0
			for bo in bounce_offsets:
				var br = cp.x + bo.x; var bc = cp.y + bo.y
				if br >= 0 and br < GRID_ROWS and bc >= 0 and bc < GRID_COLUMNS:
					var b_pos = get_cell_position(br, bc)
					targets.append(b_pos)
					_spawn_shock_zap_effect(b_pos)
					if (grid_stones.size() == GRID_ROWS and grid_stones[br][bc] > 0) or (grid_ice.size() == GRID_ROWS and int(grid_ice[br][bc]) > 0):
						_trigger_thunder_shatter_synergy(br, bc, true, queue, exploded_items)
					elif grid_i.size() == GRID_ROWS and grid_i[br][bc] != -1:
						ismatched[br][bc] = true
					bounced_cnt += 1
					if bounced_cnt >= 2:
						break
			_spawn_floating_text(get_cell_position(cp.x, cp.y), "⚡ 雷光反射！", Color(1.0, 1.0, 0.3))

		if (grid_stones.size() == GRID_ROWS and grid_stones[cp.x][cp.y] > 0) or (grid_ice.size() == GRID_ROWS and int(grid_ice[cp.x][cp.y]) > 0):
			_trigger_thunder_shatter_synergy(cp.x, cp.y, true, queue, exploded_items)
			continue

		ismatched[cp.x][cp.y] = true
		var has_sp = (special_item.size() == GRID_ROWS and special_item[cp.x][cp.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[cp.x][cp.y])
		if has_sp and not (cp in exploded_items):
			queue.append(cp)

		if grid_water.size() == GRID_ROWS and grid_water[cp.x][cp.y]:
			water_hits.append(cp)

		var plant = _get_plant_at(cp.x, cp.y)
		if not plant.is_empty() and not (plant in hit_plants):
			hit_plants.append(plant)

	_spawn_lightning_effect(pos, targets)

	# 木に雷ダメージ（耐久値-1）
	for p in hit_plants:
		_damage_plant(p, 1, "lightning")

	# 水浸しマスへの感電拡散
	if not water_hits.is_empty():
		_trigger_water_conduction(water_hits, queue, exploded_items)

func _trigger_aqua_splash(r: int, c: int, pos: Vector2, _queue: Array, _exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.AQUA_SPLASH, 1))
	var radius: int = 1 # Lv1: 3x3
	if lvl >= 14:
		radius = 5 # 画面ほぼ全域
	elif lvl >= 8:
		radius = 3 # 7x7
	elif lvl >= 3:
		radius = 2 # 5x5

	ismatched[r][c] = true
	_spawn_aqua_splash_effect(pos, radius)

	for dr in range(-radius, radius + 1):
		for dc in range(-radius, radius + 1):
			# 仕様変更(I4): 起爆点からのユークリッド距離 <= radius のマスのみ円状展開
			if float(dr * dr + dc * dc) > float(radius * radius):
				continue
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				_apply_water_to_cell(nr, nc, true)
				if ismatched.size() == GRID_ROWS:
					ismatched[nr][nc] = true

	_check_and_trigger_water_fire_synergy(true, _queue, _exploded_items)

	# 周囲の植物による即時吸水
	for plant in plant_entities.duplicate():
		_process_plant_water_absorption(plant)


func _trigger_tree_sprout(r: int, c: int, pos: Vector2, _queue: Array, _exploded_items: Dictionary) -> void:
	ismatched[r][c] = true
	_spawn_sprout_effect(pos)
	var lvl: int = max(1, special_levels.get(SpecialItemType.TREE_SPROUT, 1))
	if _get_plant_at(r, c).is_empty():
		var init_stage = 0
		if lvl >= 12:
			init_stage = 2 # 直接3x3世界樹として出現
		elif lvl >= 5:
			init_stage = 1 # 最初から若木として出現
		var new_plant: Dictionary = {
			"origin": Vector2i(r, c),
			"stage": init_stage,
			"absorbed_water": 0,
			"thunder_hp": 1 + int((lvl - 1) / 3)
		}
		plant_entities.append(new_plant)
		_process_plant_water_absorption(new_plant)

func _trigger_disco_ball(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	_trigger_holy_light(r, c, pos, queue, exploded_items)

func _trigger_color_converter(r: int, c: int, pos: Vector2, _queue: Array, _exploded_items: Dictionary) -> void:
	var dom_att: int = _get_dominant_attribute()
	var lvl: int = max(1, special_levels.get(SpecialItemType.COLOR_CONVERTER, 1))
	_spawn_paint_effect(pos)
	ismatched[r][c] = true

	var paint_radius: int = 1
	if lvl >= 14:
		paint_radius = 4
	elif lvl >= 8:
		paint_radius = 3
	elif lvl >= 3:
		paint_radius = 2

	for dr in range(-paint_radius, paint_radius + 1):
		for dc in range(-paint_radius, paint_radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				if lvl >= 4 and grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
					grid_stones[nr][nc] = 0
					_spawn_stone_break_effect(get_cell_position(nr, nc))
				var p_idx = grid_i[nr][nc]
				if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
					grid_att[nr][nc] = dom_att
					grid_n[nr][nc] = dom_att
					piece[p_idx].texture = PIECE_TEXTURES[dom_att]
					var tw = create_tween()
					piece[p_idx].scale = cellsize * 1.35
					tw.tween_property(piece[p_idx], "scale", cellsize, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _trigger_black_hole(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.BLACK_HOLE, 1))
	var radius: int = 1
	if lvl >= 13:
		radius = 4
	elif lvl >= 7:
		radius = 3
	elif lvl >= 2:
		radius = 2

	var score_mgr_d = _get_score_manager()
	var sm = _get_stage_manager()
	var stage_scale = pow(10.0, max(0, (sm.stage - 1) if sm else 0))

	# 起爆したブラックホール駒自体を確実にマッチ消去対象とし、特殊アイテム・ボム属性を解除
	ismatched[r][c] = true
	if special_item.size() == GRID_ROWS:
		special_item[r][c] = SpecialItemType.NONE
	if is_bomb.size() == GRID_ROWS:
		is_bomb[r][c] = false

	# 🌙 闇B: 代償 (HP8%消費で吸引範囲拡大 3x3->5x5 つまり radius 1 -> 2)
	if has_actor_skill_trait(true, "dark", "dark_mid_b"):
		radius = maxi(radius, 2)
		if sm and sm.myhp > 0:
			var hp_cost = sm.myhp * 0.08
			sm.calchp(0.0, hp_cost)
			_spawn_floating_text(pos, "🌑 代償(HP-8%)！ブラックホール拡大！", Color(0.7, 0.2, 0.9))

	var rm_bh = _get_relic_manager()
	if rm_bh and rm_bh.has_relic("void_ring"):
		radius = maxi(radius, int(rm_bh.get_param("void_ring", "pull_radius", 2)))

	_spawn_black_hole_effect(pos, radius)
	var stone_dmg: int = 1 + int((lvl - 1) / 3)

	var has_d_devour = has_actor_skill_trait(true, "dark", "dark_final_b1")
	var has_d_horizon = has_actor_skill_trait(true, "dark", "dark_final_b2")
	var sucked_count: int = 0

	for dr in range(-radius, radius + 1):
		for dc in range(-radius, radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				# 闇最終: 妨害オブジェクト吸引 (敵石・黄金像・敵植物を完全消滅)
				if has_d_devour:
					if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[nr][nc] > 0 and not is_ally_gold(nr, nc):
						grid_gold_statue[nr][nc] = 0
						sucked_count += 1
						_spawn_floating_text(get_cell_position(nr, nc), "🌑 黄金像吸引消滅！", Color(0.7, 0.3, 0.9))
					if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0 and not is_ally_stone(nr, nc):
						grid_stones[nr][nc] = 0
						sucked_count += 1
						_spawn_floating_text(get_cell_position(nr, nc), "🌑 敵石吸引消滅！", Color(0.7, 0.3, 0.9))
					var p_ent = _get_plant_at(nr, nc)
					if not p_ent.is_empty() and p_ent.get("enemy_planted", false):
						_damage_plant(p_ent, 999, "dark_devour")
						sucked_count += 1

				if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
					_damage_stone_at(nr, nc, stone_dmg)
					sucked_count += 1
					if grid_stones[nr][nc] == 0 and grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
					continue

				if grid_i[nr][nc] != -1:
					if not ismatched[nr][nc]:
						sucked_count += 1
					ismatched[nr][nc] = true
					var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
					if has_sp and not (Vector2i(nr, nc) in exploded_items):
						queue.append(Vector2i(nr, nc))

	# 🌙 闇B2: 事象の地平 (吸い込み数比例の闇属性ダメージ)
	if has_d_horizon and sucked_count > 0:
		var sk_lvl: int = maxi(1, score_mgr_d.get_skill_level("dark_1") if (score_mgr_d and score_mgr_d.has_method("get_skill_level")) else 1)
		var horizon_dmg = float(sucked_count) * (70.0 + sk_lvl * 18.0) * stage_scale
		if sm: sm.calchp(horizon_dmg, 0.0)
		_emit_combat_event("damage", "ally", "enemy", horizon_dmg, "dark_event_horizon")
		_spawn_floating_text(pos, "🌑 事象の地平！+%dダメ(吸込%d)" % [int(horizon_dmg), sucked_count], Color(0.8, 0.2, 1.0))

	# 🌙 闇A: 空間転移 / 歪曲 (自由スワップ獲得)
	if has_actor_skill_trait(true, "dark", "dark_final_a2"):
		free_swap_turns = max(free_swap_turns, 3)
		has_dark_teleport_swap = true
		_spawn_floating_text(Vector2(640, 360), "🌙 空間転移！3ターン自由スワップ！", Color(0.8, 0.4, 1.0))
	elif has_actor_skill_trait(true, "dark", "dark_mid_a"):
		free_swap_turns = max(free_swap_turns, 1)
		has_dark_teleport_swap = true
		_spawn_floating_text(Vector2(640, 360), "🌙 重力場！1ターン自由スワップ！", Color(0.7, 0.3, 1.0))

	if rm_bh and rm_bh.has_relic("nether_pact"):
		var extra_sw = int(rm_bh.get_param("nether_pact", "extra_swap_turns", 1))
		free_swap_turns += extra_sw
		has_dark_teleport_swap = true

	# 🌙 闇A1: 重力崩壊 (中心から斜め✕字衝撃波消去)
	if has_actor_skill_trait(true, "dark", "dark_final_a1"):
		for d in range(1, maxi(GRID_ROWS, GRID_COLUMNS)):
			for diag in [Vector2i(-d, -d), Vector2i(-d, d), Vector2i(d, -d), Vector2i(d, d)]:
				var dr_x = r + diag.x; var dc_x = c + diag.y
				if dr_x >= 0 and dr_x < GRID_ROWS and dc_x >= 0 and dc_x < GRID_COLUMNS:
					if grid_i[dr_x][dc_x] != -1:
						ismatched[dr_x][dc_x] = true
						var has_sp_x = (special_item.size() == GRID_ROWS and special_item[dr_x][dc_x] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[dr_x][dc_x])
						if has_sp_x and not (Vector2i(dr_x, dc_x) in exploded_items):
							queue.append(Vector2i(dr_x, dc_x))
		_spawn_floating_text(pos, "🌑 重力崩壊！斜め✕字衝撃波！", Color(0.85, 0.3, 1.0))

	# 🌙 闇C: 混沌・反動放出 (被ダメージ蓄積の解放)
	if has_actor_skill_trait(true, "dark", "dark_mid_c") and dark_accumulated_damage > 0.0:
		var release_dmg = dark_accumulated_damage
		dark_accumulated_damage = 0.0
		if has_actor_skill_trait(true, "dark", "dark_final_c1"): # 復讐 / 暗黒の解放 (+50%)
			release_dmg *= 1.50
		if has_actor_skill_trait(true, "dark", "dark_final_c2"): # 逆流 / 吸命 (35%回復)
			var heal_amt = release_dmg * 0.35
			if sm: sm.calchp(0.0, -heal_amt)
			_emit_combat_event("heal", "ally", "ally", heal_amt)
		if sm and release_dmg > 0.0:
			sm.calchp(release_dmg, 0.0)
			_emit_combat_event("damage", "ally", "enemy", release_dmg, "dark_release")
		_spawn_floating_text(pos, "🌙 混沌解放 -%d!" % int(release_dmg), Color(0.8, 0.2, 0.95))

	# 🌙 闇スキル効果：影護マス（加護）を盤面に展開
	_ensure_ally_grids()
	var shadow_count = mini(2 + int(lvl / 2), GRID_ROWS * GRID_COLUMNS)
	var shadow_candidates: Array[Vector2i] = []
	# 優先度1: 敵の妨害マス（敵呪い、敵毒、敵炎）を優先して安全に上書き・影護化
	for ar in range(GRID_ROWS):
		for ac in range(GRID_COLUMNS):
			if not (ar == r and ac == c) and not _is_plant_cell(ar, ac) and not is_ally_cursed(ar, ac):
				var is_enemy_hazard = (grid_cursed.size() == GRID_ROWS and grid_cursed[ar][ac] and not is_ally_cursed(ar, ac)) or \
									  (grid_poison.size() == GRID_ROWS and grid_poison[ar][ac] and not is_ally_poison(ar, ac)) or \
									  (grid_fire.size() == GRID_ROWS and grid_fire[ar][ac] > 0 and not is_ally_fire(ar, ac))
				if is_enemy_hazard:
					shadow_candidates.append(Vector2i(ar, ac))
	shadow_candidates.shuffle()

	# 優先度2: 通常マス
	var normal_cands: Array[Vector2i] = []
	for ar in range(GRID_ROWS):
		for ac in range(GRID_COLUMNS):
			var cp = Vector2i(ar, ac)
			if not (ar == r and ac == c) and not shadow_candidates.has(cp) and not _is_plant_cell(ar, ac) and not is_ally_cursed(ar, ac):
				normal_cands.append(cp)
	normal_cands.shuffle()
	shadow_candidates.append_array(normal_cands)

	var actual_shadow_cnt = mini(shadow_count, shadow_candidates.size())
	var shadow_vfx_targets: Array[Vector2] = []
	for i in range(actual_shadow_cnt):
		var scell = shadow_candidates[i]
		grid_cursed[scell.x][scell.y] = true
		_set_ally_flag(grid_cursed_ally, scell.x, scell.y, true)
		if grid_poison.size() == GRID_ROWS: grid_poison[scell.x][scell.y] = false
		if grid_fire.size() == GRID_ROWS: grid_fire[scell.x][scell.y] = 0
		var cpos = get_cell_position(scell.x, scell.y)
		shadow_vfx_targets.append(cpos)
		_spawn_floating_text(cpos, "🌙 影護マス！", Color(0.65, 0.45, 1.0))

	# 視覚演出: ブラックホール起爆位置から影護マスへ属性魔力弾演出
	if not shadow_vfx_targets.is_empty():
		_spawn_player_skill_beams(pos, shadow_vfx_targets, "dark")

func _trigger_holy_light(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.HOLY_LIGHT, 1))
	var sm = _get_stage_manager()
	var stage_scale = pow(10.0, max(0, (sm.stage - 1) if sm else 0))
	ismatched[r][c] = true

	# 1. 聖像（味方の黄金像）を盤面のランダムなマスに降臨させる (アイテムLv強化で増加)
	var statue_count = mini(2 + int((lvl - 1) / 3), GRID_ROWS * GRID_COLUMNS)

	var candidates: Array[Vector2i] = []
	for nr in range(GRID_ROWS):
		for nc in range(GRID_COLUMNS):
			if not (nr == r and nc == c) and not _is_plant_cell(nr, nc):
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[nr][nc] == 0:
					candidates.append(Vector2i(nr, nc))
	candidates.shuffle()

	var placed_statues: Array[Vector2i] = []
	for k in range(mini(statue_count, candidates.size())):
		var cp = candidates[k]
		grid_gold_statue[cp.x][cp.y] = 2
		_set_ally_flag(grid_gold_ally, cp.x, cp.y, true)
		placed_statues.append(cp)
		_spawn_floating_text(get_cell_position(cp.x, cp.y), "✨ 聖像降臨！", Color(1.0, 0.95, 0.3))

	_play_light_expansion(placed_statues, pos, true)

	# 2. 聖域浄化 (敵の毒・火・呪い・敵氷などの妨害マスを一掃浄化)
	var purify_targets: Array[Vector2] = []
	for nr in range(GRID_ROWS):
		for nc in range(GRID_COLUMNS):
			var is_bad = (grid_poison.size() == GRID_ROWS and grid_poison[nr][nc] and not is_ally_poison(nr, nc)) or \
						 (grid_fire.size() == GRID_ROWS and grid_fire[nr][nc] > 0 and not is_ally_fire(nr, nc)) or \
						 (grid_cursed.size() == GRID_ROWS and grid_cursed[nr][nc] and not is_ally_cursed(nr, nc)) or \
						 (grid_ice.size() == GRID_ROWS and int(grid_ice[nr][nc]) > 0 and not is_ally_ice(nr, nc))
			if is_bad:
				if grid_poison.size() == GRID_ROWS: grid_poison[nr][nc] = false
				if grid_fire.size() == GRID_ROWS: grid_fire[nr][nc] = 0
				if grid_cursed.size() == GRID_ROWS: grid_cursed[nr][nc] = false
				if grid_ice.size() == GRID_ROWS: grid_ice[nr][nc] = 0
				purify_targets.append(get_cell_position(nr, nc))
				_spawn_floating_text(get_cell_position(nr, nc), "✨ 聖域浄化！", Color(1.0, 0.95, 0.5))

	# 3. 聖域 (light_mid_b): 発動ターン被ダメージ25%軽減
	if has_actor_skill_trait(true, "light", "light_mid_b"):
		has_light_sanctuary_this_turn = true
		_spawn_floating_text(pos, "✨ 聖域展開！(被ダメ-25%)", Color(1.0, 0.95, 0.4))

	# 4. 聖光ダメージ
	var base_dmg = (70.0 + lvl * 15.0) * stage_scale
	_emit_combat_event("damage", "ally", "enemy", base_dmg, "player_skill_light")
	if sm and sm.has_method("calchp"):
		sm.calchp(int(base_dmg), 0)

	# 5. 聖像共振 (light_final_a2): 盤面全聖像から光線一斉照射
	if has_actor_skill_trait(true, "light", "light_final_a2"):
		var ally_st_cnt = 0
		for ar in range(GRID_ROWS):
			for ac in range(GRID_COLUMNS):
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[ar][ac] > 0 and is_ally_gold(ar, ac):
					ally_st_cnt += 1
		if ally_st_cnt > 0:
			var res_dmg = float(ally_st_cnt) * (50.0 + lvl * 10.0) * stage_scale
			if sm and sm.has_method("calchp"): sm.calchp(int(res_dmg), 0)
			_emit_combat_event("damage", "ally", "enemy", res_dmg, "holy_statue_resonance")
			_spawn_floating_text(pos, "✨ 聖像共振レーザー！", Color(1.0, 1.0, 0.5))

	# 周囲の特殊アイテム誘爆チェック (半径1マス)
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var ar = r + dr
			var ac = c + dc
			if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS:
				if special_item.size() == GRID_ROWS and special_item[ar][ac] != SpecialItemType.NONE:
					if not (Vector2i(ar, ac) in exploded_items):
						queue.append(Vector2i(ar, ac))

	var vfx_pts: Array[Vector2] = []
	for p_st in placed_statues:
		vfx_pts.append(get_cell_position(p_st.x, p_st.y))
	vfx_pts.append_array(purify_targets)
	if vfx_pts.is_empty():
		vfx_pts.append(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2))
	_spawn_holy_light_effect(pos, vfx_pts)

func _trigger_magnet(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	_trigger_holy_light(r, c, pos, queue, exploded_items)

func _trigger_charge_bomb(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.CHARGE_BOMB, 1))
	var ch: int = 1
	if special_charge.size() == GRID_ROWS:
		ch = max(1, special_charge[r][c])
	_spawn_mega_explosion_effect(pos, ch)

	var radius: int = ch + int((lvl - 1) / 5)
	var stone_dmg: int = ch + int((lvl - 1) / 3)
	for dr in range(-radius, radius + 1):
		for dc in range(-radius, radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
					_damage_stone_at(nr, nc, stone_dmg)
					if grid_stones[nr][nc] == 0 and grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						cells_cleared_by_special[Vector2i(nr, nc)] = true
					continue

				var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][nc])
				if is_water:
					grid_water[nr][nc] = false
					_spawn_steam_effect(get_cell_position(nr, nc))
				else:
					if grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						cells_cleared_by_special[Vector2i(nr, nc)] = true
						var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
						if has_sp and not (Vector2i(nr, nc) in exploded_items):
							queue.append(Vector2i(nr, nc))

	# チャージボムによる敵への特大爆破ダメージ
	var sm = _get_stage_manager()
	var stage_scale: float = pow(10.0, max(0, (sm.stage - 1) if sm else 0))
	var base_dmg: float = (150.0 + lvl * 35.0) * float(ch) * stage_scale
	if sm and sm.has_method("calchp") and sm.ehp > 0 and not sm.isdeadf:
		sm.calchp(base_dmg, 0.0, sm.get_focused_enemy_index() if sm.has_method("get_focused_enemy_index") else -1)
		_emit_combat_event("damage", "ally", "enemy", base_dmg, "charge_bomb")
		_spawn_floating_text(Vector2(640, 360), "💣 チャージボム超爆破 %d!" % int(base_dmg), Color(1.0, 0.5, 0.1))
	isattack = 1

func _trigger_gemini_bomb(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.GEMINI_BOMB, 1))
	var stone_dmg: int = 1 + int((lvl - 1) / 4)
	_spawn_explosion_effect(pos)
	var exploded_cells: Array[Vector2i] = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
					_damage_stone_at(nr, nc, stone_dmg)
					if grid_stones[nr][nc] == 0 and grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						if not Vector2i(nr, nc) in exploded_cells: exploded_cells.append(Vector2i(nr, nc))
					continue

				var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][nc])
				if is_water:
					grid_water[nr][nc] = false
					_spawn_steam_effect(get_cell_position(nr, nc))
				else:
					if grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						if not Vector2i(nr, nc) in exploded_cells: exploded_cells.append(Vector2i(nr, nc))
						var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
						if has_sp and not (Vector2i(nr, nc) in exploded_items):
							queue.append(Vector2i(nr, nc))

	var split_count: int = mini(8, 2 + int(lvl / 3))
	var targets: Array[Vector2] = []
	var cands: Array[Vector2i] = []
	for ar in range(GRID_ROWS):
		for ac in range(GRID_COLUMNS):
			if grid_i[ar][ac] != -1 and (abs(ar - r) > 1 or abs(ac - c) > 1):
				cands.append(Vector2i(ar, ac))
	cands.shuffle()

	for k in range(mini(split_count, cands.size())):
		var tp = cands[k]
		targets.append(get_cell_position(tp.x, tp.y))
		ismatched[tp.x][tp.y] = true
		if not tp in exploded_cells: exploded_cells.append(tp)
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var cr = tp.x + dr
				var cc = tp.y + dc
				if cr >= 0 and cr < GRID_ROWS and cc >= 0 and cc < GRID_COLUMNS:
					if grid_stones.size() == GRID_ROWS and grid_stones[cr][cc] > 0:
						_damage_stone_at(cr, cc, stone_dmg)
						if grid_stones[cr][cc] == 0 and grid_i[cr][cc] != -1:
							ismatched[cr][cc] = true
							if not Vector2i(cr, cc) in exploded_cells: exploded_cells.append(Vector2i(cr, cc))
						continue
					if grid_i[cr][cc] != -1:
						ismatched[cr][cc] = true
						if not Vector2i(cr, cc) in exploded_cells: exploded_cells.append(Vector2i(cr, cc))

	_spawn_gemini_effect(pos, targets)
	_trigger_fire_shrapnel_evolution(exploded_cells, true, queue, exploded_items)

# --- 元素ケミストリー＆植物管理システム ---

## 水伝導（感電拡散 BFS）: 雷が水に当たると連続した水たまり全体へ感電拡散
func _trigger_water_conduction(start_cells: Array[Vector2i], queue: Array, exploded_items: Dictionary) -> void:
	if grid_water.size() != GRID_ROWS:
		return

	var visited: Dictionary = {}
	var bfs_queue: Array[Vector2i] = []
	for cell in start_cells:
		visited[cell] = true
		bfs_queue.append(cell)

	var shock_cells: Array[Vector2i] = []
	var hit_plants: Array = []

	while not bfs_queue.is_empty():
		var curr = bfs_queue.pop_front()
		shock_cells.append(curr)

		grid_water[curr.x][curr.y] = false
		ismatched[curr.x][curr.y] = true

		var has_sp = (special_item.size() == GRID_ROWS and special_item[curr.x][curr.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[curr.x][curr.y])
		if has_sp and not (curr in exploded_items):
			queue.append(curr)

		var plant = _get_plant_at(curr.x, curr.y)
		if not plant.is_empty() and not (plant in hit_plants):
			hit_plants.append(plant)

		# 8方向隣接の水たまりマスへ感電拡散
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr == 0 and dc == 0:
					continue
				var nr = curr.x + dr
				var nc = curr.y + dc
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					var neighbor = Vector2i(nr, nc)
					if grid_water[nr][nc] and not visited.has(neighbor):
						visited[neighbor] = true
						bfs_queue.append(neighbor)

	_spawn_water_electric_effect(shock_cells)

	# 水たまりに触れていた植物へ雷ダメージ（耐久値-1）
	for p in hit_plants:
		_damage_plant(p, 1, "lightning_water")


## 植物が占有するマス一覧を取得（苗・若木は1マス、3x3大木は9マス）
func _get_plant_occupied_cells(plant: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var org: Vector2i = plant.get("origin", Vector2i(-1, -1))
	var st: int = plant.get("stage", 0)
	if st == 2:
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var nr = org.x + dr
				var nc = org.y + dc
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					cells.append(Vector2i(nr, nc))
	else:
		if org.x >= 0 and org.x < GRID_ROWS and org.y >= 0 and org.y < GRID_COLUMNS:
			cells.append(org)
	return cells

## 指定マスに植物が存在するか判定
func _is_plant_cell(r: int, c: int) -> bool:
	return not _get_plant_at(r, c).is_empty()

## 駒消去による便益処理（PvP前提：消去の出所 source に応じて帰属を分岐）
func _process_piece_cleared_benefits(cleared_kinds: Array[int], source: String = "ally") -> void:
	if cleared_kinds.is_empty():
		return
	var sm = _get_stage_manager()
	var stage_scale: float = pow(10.0, max(0, (sm.stage - 1) if sm else 0))

	if source == "enemy":
		# 敵の消去による敵への便益（プレイヤーへのスコア・divscore・属性・遺物トリガーは一切加算しない）
		for k in cleared_kinds:
			match k:
				PieceType.SWORD:
					var dmg = 8.0 * stage_scale
					if sm:
						sm.last_damage_cause = "敵による剣駒の消去奪取"
						sm.calchp(0.0, dmg)
					_emit_combat_event("damage", "enemy", "ally", dmg, "enemy_piece_clear_sword")
				PieceType.SHIELD:
					var shield_amt = 10.0 * stage_scale
					_emit_combat_event("shield", "enemy", "enemy", shield_amt, "enemy_piece_clear_shield")
				PieceType.POTION:
					var heal_amt = 12.0 * stage_scale
					if sm and sm.ehp > 0:
						sm.calchp(-heal_amt, 0.0)
					_emit_combat_event("heal", "enemy", "enemy", heal_amt, "enemy_piece_clear_potion")
				PieceType.COIN:
					_emit_combat_event("coin", "enemy", "enemy", 1.0, "enemy_piece_clear_coin")
				_:
					pass
	else:
		# 味方による消去（通常マッチは sm.calcscore 経由で集計）
		pass

## 指定マスの駒を盤面から完全に消去（植物占有時・スキル着火時等）
func _clear_pieces_in_cells(cells: Array, source: String = "ally") -> void:
	_apply_electrified_and_cursed_effects(cells)
	var cleared_kinds: Array[int] = []
	for cell in cells:
		if cell.x < 0 or cell.x >= GRID_ROWS or cell.y < 0 or cell.y >= GRID_COLUMNS:
			continue
		if grid_n.size() == GRID_ROWS and grid_n[cell.x][cell.y] != -1:
			cleared_kinds.append(grid_n[cell.x][cell.y])
	_process_piece_cleared_benefits(cleared_kinds, source)
	for cell in cells:
		if cell.x < 0 or cell.x >= GRID_ROWS or cell.y < 0 or cell.y >= GRID_COLUMNS:
			continue
		if grid_i.size() == GRID_ROWS:
			var idx = grid_i[cell.x][cell.y]
			if idx >= 0 and idx < piece.size() and piece[idx] != null:
				piece[idx].queue_free(); Profiler.queue_free_count += 1
				piece[idx] = null
			if idx >= 0 and idx < piececollid.size() and piececollid[idx] != null:
				piececollid[idx].queue_free(); Profiler.queue_free_count += 1
				piececollid[idx] = null
			grid_i[cell.x][cell.y] = -1
		if grid_n.size() == GRID_ROWS:
			grid_n[cell.x][cell.y] = -1
		if grid_att.size() == GRID_ROWS:
			grid_att[cell.x][cell.y] = -1
		if ismatched.size() == GRID_ROWS:
			ismatched[cell.x][cell.y] = false
		if is_bomb.size() == GRID_ROWS:
			is_bomb[cell.x][cell.y] = false
		if special_item.size() == GRID_ROWS:
			special_item[cell.x][cell.y] = SpecialItemType.NONE
		if special_charge.size() == GRID_ROWS:
			special_charge[cell.x][cell.y] = 0
	if piece.size() > 0:
		_compact_piece_arrays()

## 指定マスに存在する植物エンティティを取得
func _get_plant_at(r: int, c: int) -> Dictionary:
	for plant in plant_entities:
		var cells = _get_plant_occupied_cells(plant)
		if Vector2i(r, c) in cells:
			return plant
	return {}

## 指定マスに苗木を植樹
func _plant_sprout_at(r: int, c: int) -> bool:
	if not _get_plant_at(r, c).is_empty():
		return false

	var new_plant: Dictionary = {
		"origin": Vector2i(r, c),
		"stage": 0, # 0: 苗木, 1: 若木, 2: 3x3大木
		"absorbed_water": 0,
		"thunder_hp": 1 # 苗木は1回耐える
	}
	plant_entities.append(new_plant)
	_clear_pieces_in_cells([Vector2i(r, c)])
	_process_plant_water_absorption(new_plant)
	_update_status_ailments()
	_redraw_board_effects()
	return true

## 盤面の空きマスに苗木を1本植樹（ショップ購入時等）
func _plant_sprout_on_board() -> bool:
	var candidates: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if _get_plant_at(r, c).is_empty() and grid_i[r][c] != -1:
				candidates.append(Vector2i(r, c))
	if candidates.is_empty():
		return false
	var chosen = candidates[randi() % candidates.size()]
	return _plant_sprout_at(chosen.x, chosen.y)

## 植物へのダメージ処理（雷・風による耐久値減算）
func _damage_plant(plant: Dictionary, dmg: int, _reason: String = "") -> void:
	if not (plant in plant_entities):
		return
	var is_ally = is_ally_plant(plant)
	var org: Vector2i = plant.get("origin", Vector2i(7, 7))
	var p_pos = get_cell_position(org.x, org.y)

	plant["thunder_hp"] = plant.get("thunder_hp", 1) - dmg
	_spawn_plant_damage_effect(p_pos, plant.get("thunder_hp", 0) <= 0)

	if plant["thunder_hp"] <= 0:
		# 🌱 木A2: 深い根 (植物へのダメージ時、成長段階が1低下する。苗木 stage 0 のみ破壊)
		if has_actor_skill_trait(is_ally, "wood", "wood_final_a2") and plant.get("stage", 0) > 0:
			plant["stage"] = plant.get("stage", 1) - 1
			plant["thunder_hp"] = 1
			_spawn_floating_text(p_pos, "🌱 深い根！段階低下で耐えた(段階%d)！" % plant["stage"], Color(0.4, 1.0, 0.4))
			_update_status_ailments()
			return

		var score_mgr_pl = _get_score_manager()
		var sm_pl = _get_stage_manager()
		var sk_lvl_wd = maxi(1, score_mgr_pl.get_skill_level("wood_1")) if score_mgr_pl and score_mgr_pl.has_method("get_skill_level") else 1
		var st_scale_pl = pow(10, max(0, (sm_pl.stage - 1) if sm_pl else 0))

		# 🌱 木C1: 豊穣 (植物消去時、周囲のポーション駒が一斉に効果発動)
		if score_mgr_pl and score_mgr_pl.has_method("has_skill_trait") and score_mgr_pl.has_skill_trait("wood_1", "wood_final_c1"):
			var occ = _get_plant_occupied_cells(plant)
			var total_pot_heal = 0.0
			for occ_cell in occ:
				for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
					var nr = occ_cell.x + offset.x; var nc = occ_cell.y + offset.y
					if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
						if grid_n.size() == GRID_ROWS and grid_n[nr][nc] == PieceType.POTION:
							grid_n[nr][nc] = _board_randi() % 5
							if ismatched.size() == GRID_ROWS: ismatched[nr][nc] = true
							total_pot_heal += (150.0 + sk_lvl_wd * 30.0) * st_scale_pl
							_spawn_floating_text(get_cell_position(nr, nc), "🌱 豊穣発動！", Color(0.3, 1.0, 0.5))
			if total_pot_heal > 0.0 and sm_pl:
				sm_pl.calchp(0.0, -total_pot_heal)
				_emit_combat_event("heal", "ally", "ally", total_pot_heal)

		plant_entities.erase(plant)
		_update_status_ailments()

## 火炎が植物に接触した時の大延焼爆発
func _burn_plant(plant: Dictionary, queue: Array = [], exploded_items: Dictionary = {}) -> void:
	if not (plant in plant_entities):
		return
	var occ = _get_plant_occupied_cells(plant)
	var org: Vector2i = plant.get("origin", Vector2i(7, 7))
	var center_pos = get_cell_position(org.x, org.y)

	var burn_cells: Dictionary = {}
	for cell in occ:
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var nr = cell.x + dr
				var nc = cell.y + dc
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					burn_cells[Vector2i(nr, nc)] = true

	plant_entities.erase(plant)

	for bc in burn_cells.keys():
		var is_water = (grid_water.size() == GRID_ROWS and grid_water[bc.x][bc.y])
		if is_water:
			grid_water[bc.x][bc.y] = false
			_spawn_steam_effect(get_cell_position(bc.x, bc.y))
		else:
			if ismatched.size() == GRID_ROWS:
				ismatched[bc.x][bc.y] = true
			if grid_i.size() == GRID_ROWS and grid_i[bc.x][bc.y] != -1:
				var has_sp = (special_item.size() == GRID_ROWS and special_item[bc.x][bc.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[bc.x][bc.y])
				if has_sp and not (bc in exploded_items):
					queue.append(bc)


	_spawn_mega_explosion_effect(center_pos, 3)

## 指定矩形範囲に接触している植物を延焼
func _check_burn_plants_in_rect(min_r: int, max_r: int, min_c: int, max_c: int, queue: Array = [], exploded_items: Dictionary = {}) -> void:
	var to_burn: Array = []
	for plant in plant_entities:
		var occ = _get_plant_occupied_cells(plant)
		var touches: bool = false
		for cell in occ:
			if cell.x >= min_r and cell.x <= max_r and cell.y >= min_c and cell.y <= max_c:
				touches = true
				break
		if touches:
			to_burn.append(plant)

	for p in to_burn:
		_burn_plant(p, queue, exploded_items)

## 植物が隣接する水を吸水して成長
func _process_plant_water_absorption(plant: Dictionary) -> bool:
	if not (plant in plant_entities) or grid_water.size() != GRID_ROWS:
		return false

	var occ = _get_plant_occupied_cells(plant)
	var absorbed_any: bool = false

	var check_cells: Dictionary = {}
	for cell in occ:
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var nr = cell.x + dr
				var nc = cell.y + dc
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					check_cells[Vector2i(nr, nc)] = true

	for bc in check_cells.keys():
		if grid_water[bc.x][bc.y]:
			grid_water[bc.x][bc.y] = false
			absorbed_any = true
			plant["absorbed_water"] = plant.get("absorbed_water", 0) + 1

	if absorbed_any:
		var current_stage: int = plant.get("stage", 0)
		var total_water: int = plant.get("absorbed_water", 0)
		var org: Vector2i = plant.get("origin", Vector2i(7, 7))
		var pos = get_cell_position(org.x, org.y)

		# 苗木 (stage 0) -> 1回以上吸水で 若木 (stage 1)
		if current_stage == 0 and total_water >= 1:
			plant["stage"] = 1
			plant["thunder_hp"] = 2 # 若木の耐久値: 2
			_spawn_growth_effect(pos, 1)

		# 若木 (stage 1) -> 通算3回以上吸水で 3x3大木 (stage 2)
		elif current_stage == 1 and total_water >= 3:
			plant["origin"] = Vector2i(clampi(org.x, 1, GRID_ROWS - 2), clampi(org.y, 1, GRID_COLUMNS - 2))
			plant["stage"] = 2
			plant["thunder_hp"] = 3 # 大木の耐久値: 3
			_clear_pieces_in_cells(_get_plant_occupied_cells(plant))
			_spawn_growth_effect(get_cell_position(plant["origin"].x, plant["origin"].y), 2)


	return absorbed_any

## 毎ターンの植物処理（吸水 ＆ マイルド自動回復）
## ユグドラシル最終進化：大木隣接マスをランダムなスキルアイテムに変化
func _spawn_yggdrasil_skills(plant: Dictionary) -> void:
	var occ_cells = _get_plant_occupied_cells(plant)
	var adjacent_cands: Array[Vector2i] = []
	for occ in occ_cells:
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr == 0 and dc == 0: continue
				var nr = occ.x + dr; var nc = occ.y + dc
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					if Vector2i(nr, nc) in occ_cells: continue
					if grid_i.size() == GRID_ROWS and grid_i[nr][nc] != -1:
						if special_item.size() == GRID_ROWS and special_item[nr][nc] == SpecialItemType.NONE:
							if is_bomb.size() == GRID_ROWS and not is_bomb[nr][nc]:
								if not Vector2i(nr, nc) in adjacent_cands:
									adjacent_cands.append(Vector2i(nr, nc))
	if adjacent_cands.is_empty():
		return
	adjacent_cands.shuffle()
	var spawn_cnt = mini(adjacent_cands.size(), 2)
	var skill_pool = [
		SpecialItemType.BOMB,
		SpecialItemType.TORNADO,
		SpecialItemType.AQUA_SPLASH,
		SpecialItemType.LIGHTNING,
		SpecialItemType.ICE_SHIELD
	]
	for i in range(spawn_cnt):
		var c_pos = adjacent_cands[i]
		var sp_type = skill_pool[randi() % skill_pool.size()]
		special_item[c_pos.x][c_pos.y] = sp_type
		if grid_skill_owner.size() == GRID_ROWS:
			grid_skill_owner[c_pos.x][c_pos.y] = pvp_my_player_index if pvp_mode else -1
		if is_bomb.size() == GRID_ROWS:
			is_bomb[c_pos.x][c_pos.y] = true
		var idx = grid_i[c_pos.x][c_pos.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			piece[idx].texture = null
			_spawn_special_sparkle_effect(piece[idx].position)
			_spawn_floating_text(piece[idx].position, "🍎 大木結実！", Color(0.3, 1.0, 0.5))

func _process_turn_plants() -> void:
	if plant_entities.is_empty():
		return

	var sm = _get_stage_manager()
	var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))

	# 1. 各植物の吸水成長（氷隣接時は凍結して吸水停止）
	for plant in plant_entities.duplicate():
		var occ_cells = _get_plant_occupied_cells(plant)
		var plant_frozen = false
		for occ in occ_cells:
			if _is_cell_ice_locked(occ.x, occ.y):
				plant_frozen = true
				break
		if not plant_frozen:
			_process_plant_water_absorption(plant)

	# 2. 木属性：相手からの体力吸収（ドレイン回復：他回復より控えめ）＆ 最終進化大木隣接スキル生成
	var total_heal: float = 0.0
	var ally_drain_dmg: float = 0.0
	var enemy_drain_plants: Array[Dictionary] = []

	var score_mgr = _get_score_manager()
	var has_wd_yggdrasil = score_mgr and score_mgr.has_method("has_skill_trait") and score_mgr.has_skill_trait("wood_1", "wood_final_c2")

	for plant in plant_entities:
		var st: int = plant.get("stage", 0)
		var org: Vector2i = plant.get("origin", Vector2i(7, 7))
		var occ_cells = _get_plant_occupied_cells(plant)
		var plant_frozen = false
		for occ in occ_cells:
			if _is_cell_ice_locked(occ.x, occ.y):
				plant_frozen = true
				break
		if plant_frozen:
			_spawn_floating_text(get_cell_position(org.x, org.y), "❄️ 凍結停止！", Color(0.4, 0.9, 1.0))
			continue

		if plant.get("enemy_planted", false):
			enemy_drain_plants.append(plant)
		else:
			# 木属性の基本仕様: 相手からの体力吸収。他の回復スキル(水等)よりは弱く設定
			var base_dmg: float = 80.0
			var base_heal: float = 30.0
			if st == 1:
				base_dmg = 160.0
				base_heal = 60.0
			elif st >= 2:
				base_dmg = 280.0
				base_heal = 100.0

			var cur_dmg = base_dmg * stage_scale
			var cur_heal = base_heal * stage_scale
			ally_drain_dmg += cur_dmg
			total_heal += cur_heal
			_spawn_heal_number_effect(get_cell_position(org.x, org.y), int(cur_heal))
			_spawn_floating_text(get_cell_position(org.x, org.y) + Vector2(0, -30), "🌿 吸収 -%d / +%d" % [int(cur_dmg), int(cur_heal)], Color(0.3, 0.95, 0.4))

			# 最終進化で大木なら、毎ターン隣接したマスをランダムなスキルにする
			if has_wd_yggdrasil and st >= 2:
				_spawn_yggdrasil_skills(plant)

	if sm:
		if ally_drain_dmg > 0.0 and sm.ehp > 0 and not sm.isdeadf:
			sm.calchp(ally_drain_dmg, 0.0)
			_emit_combat_event("damage", "ally", "enemy", ally_drain_dmg, "wood_drain")
		if total_heal > 0.0:
			sm.calchp(0.0, -total_heal)
			_emit_combat_event("heal", "ally", "ally", total_heal)
			var p = get_parent()
			var se = p.get_node_or_null("kaihuku") if p else null
			if se: se.play()

		if not enemy_drain_plants.is_empty():
			_execute_wood_hp_drain(sm, enemy_drain_plants, stage_scale)

	_redraw_board_effects()

## 木属性植物によるプレイヤー体力吸収処理 ＆ 専用エフェクト・SE
func _execute_wood_hp_drain(sm: Node2D, drain_plants: Array[Dictionary], stage_scale: float) -> void:
	if sm == null or drain_plants.is_empty():
		return

	var total_drain: float = 0.0
	var plant_local_positions: Array[Vector2] = []

	for plant in drain_plants:
		var st: int = plant.get("stage", 0)
		var org: Vector2i = plant.get("origin", Vector2i(7, 7))
		var drain_base: float = plant.get("drain_amount", 100.0)
		if st == 1: drain_base *= 1.5
		elif st == 2: drain_base *= 2.5
		var cur_drain = drain_base * stage_scale
		total_drain += cur_drain

		var plant_pos = get_cell_position(org.x, org.y)
		plant_local_positions.append(plant_pos)
		var plant_global_p = to_global(plant_pos)

		# ① 各植物マスの吸血ダメージポップアップ（「吸血 -〇〇〇」）
		_spawn_drain_number_effect(plant_global_p, int(cur_drain))

		# ② 各植物マスの周囲に広がる棘エナジー衝撃波リング
		_spawn_shockwave_ring(plant_pos, Color(0.2, 1.0, 0.4, 0.85), 450.0, 0.4)

		# ③ 各植物マスへ吸い込まれる収束オーラ
		_spawn_plant_absorption_particles(plant_global_p)

	if total_drain <= 0.0:
		return

	# ④ プレイヤーから植物・敵への魔力吸収ストリーム（SkillVFXNode / 流入オーブ）
	_spawn_wood_drain_siphon_vfx(sm, plant_local_positions)

	# ⑤ 画面・プレイヤーHPバーの被ドレイン警告フラッシュ ＆ 数値
	_spawn_screen_flash(Color(0.8, 0.1, 0.2, 0.3), 0.25)
	_spawn_player_drain_label(int(total_drain))

	# ⑥ 敵への体力還元（敵のHPが減っていれば回復、上限は最大HP）
	var heal_enemy_amount: float = 0.0
	if sm.ehp < sm.ehpmax:
		heal_enemy_amount = minf(total_drain, sm.ehpmax - sm.ehp)

	sm.last_damage_cause = "寄生植物の生命吸収"
	sm.calchp(-heal_enemy_amount, total_drain)
	_emit_combat_event("damage", "enemy", "ally", total_drain, "drain")
	if heal_enemy_amount > 0.0:
		_emit_combat_event("heal", "enemy", "enemy", heal_enemy_amount, "drain")

	if sm.myhp <= 0:
		_trigger_gameover(sm)

	if heal_enemy_amount > 0.0:
		_spawn_enemy_heal_effect(sm, int(heal_enemy_amount))

	# ⑦ 吸収専用効果音の再生
	_play_wood_drain_se()

## 木属性生命吸収専用効果音の再生
func _play_wood_drain_se() -> void:
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	var vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0)) if (sm_autoload and "se_volume" in sm_autoload) else 0.0
	
	if UTU2_SE: _play_pooled_se(UTU2_SE, vol, 1.0)
	if GAGE_HEAL_SE: _play_pooled_se(GAGE_HEAL_SE, vol, 0.95)

func _spawn_drain_number_effect(global_pos: Vector2, amount: int) -> void:
	var p = get_parent()
	var target_parent = p if p != null else self

	var custom_font = preload("res://font/g_comickoin_freeR.ttf")
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.fit_content = false
	rtl.scroll_active = false
	rtl.add_theme_font_override("normal_font", custom_font)
	rtl.add_theme_font_override("bold_font", custom_font)
	rtl.add_theme_constant_override("outline_size", 6)
	rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	rtl.add_theme_font_size_override("normal_font_size", 22)
	rtl.add_theme_font_size_override("bold_font_size", 22)
	rtl.text = "[center][b][color=#FF1744]吸血[/color] [color=#69F0AE]-%d[/color][/b][/center]" % amount
	rtl.size = Vector2(160.0, 36.0)
	rtl.position = global_pos - Vector2(80.0, 32.0)
	rtl.z_index = 45
	Profiler.add_child_count += 1; target_parent.add_child(rtl)

	var orig_p = rtl.position
	rtl.scale = Vector2(0.6, 0.6)
	rtl.pivot_offset = rtl.size * 0.5

	var tw = create_tween()
	tw.tween_property(rtl, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rtl, "scale", Vector2(1.0, 1.0), 0.10)
	tw.parallel().tween_property(rtl, "position:y", orig_p.y - 35.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rtl, "modulate:a", 0.0, 0.25).set_delay(0.2)
	tw.chain().tween_callback(rtl.queue_free)

## 植物マスの収束エナジー粒子（吸い込まれる緑の光球）
func _spawn_plant_absorption_particles(global_pos: Vector2) -> void:
	var p = get_parent()
	var target_parent = p if p != null else self

	for i in range(8):
		var ang = i * (TAU / 8.0) + randf_range(-0.2, 0.2)
		var dist = randf_range(30.0, 50.0)
		var start_p = global_pos + Vector2(cos(ang), sin(ang)) * dist

		var dot = Polygon2D.new()
		dot.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)
		])
		dot.color = Color(0.3, 1.0, 0.5, 0.95)
		dot.position = start_p
		dot.z_index = 44
		Profiler.add_child_count += 1; target_parent.add_child(dot)

		var tw = create_tween()
		var delay = i * 0.03
		tw.tween_interval(delay)
		tw.tween_property(dot, "position", global_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(dot, "scale", Vector2(0.2, 0.2), 0.35)
		tw.chain().tween_callback(dot.queue_free)

## プレイヤーから各植物・敵への生命力吸収ストリーム演出
func _spawn_wood_drain_siphon_vfx(sm: Node2D, plant_local_positions: Array[Vector2]) -> void:
	var p = get_parent()
	var root_node = p if p != null else self

	# プレイヤーHPバー付近のグローバル座標
	var player_pos = Vector2(1550, 415)
	# 敵スプライトのグローバル座標
	var enemy_pos = sm.enemy.global_position if (sm and sm.enemy) else Vector2(1550, 250)

	var drain_col = Color(0.2, 1.0, 0.45) # 鮮やかなエメラルドグリーン

	for i in range(plant_local_positions.size()):
		var local_p = plant_local_positions[i]
		var plant_global_p = to_global(local_p)
		var delay = i * 0.06

		# ① プレイヤーから植物へ生命力が吸い出されるストリーム
		var tw_p2plant = create_tween()
		tw_p2plant.tween_interval(delay)
		tw_p2plant.tween_callback(func():
			if not is_instance_valid(root_node): return
			var stream1 = SkillVFXNode.new(SkillVFXNode.VFXMode.DRAIN_STREAM, drain_col, 0.45)
			stream1.start_pos = player_pos
			stream1.target_pos = plant_global_p
			stream1.arc_height = randf_range(40.0, 80.0)
			Profiler.add_child_count += 1; root_node.add_child(stream1)
		)

		# ② 植物から敵へと生命力が注ぎ込まれるストリーム
		var tw_plant2enemy = create_tween()
		tw_plant2enemy.tween_interval(delay + 0.25)
		tw_plant2enemy.tween_callback(func():
			if not is_instance_valid(root_node): return
			var stream2 = SkillVFXNode.new(SkillVFXNode.VFXMode.DRAIN_STREAM, Color(0.35, 1.0, 0.6), 0.40)
			stream2.start_pos = plant_global_p
			stream2.target_pos = enemy_pos
			stream2.arc_height = randf_range(-60.0, -30.0)
			Profiler.add_child_count += 1; root_node.add_child(stream2)
		)

## プレイヤーHPバー上部の被ドレイン数値表示
func _spawn_player_drain_label(total_drain: int) -> void:
	var p = get_parent()
	var target_parent = p if p != null else self

	var custom_font = preload("res://font/g_comickoin_freeR.ttf")
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.fit_content = false
	rtl.scroll_active = false
	rtl.add_theme_font_override("normal_font", custom_font)
	rtl.add_theme_font_override("bold_font", custom_font)
	rtl.add_theme_constant_override("outline_size", 8)
	rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	rtl.text = "[center][b][color=#FF1744]生命強奪[/color] [color=#FF5252]-%d[/color][/b][/center]" % total_drain
	rtl.size = Vector2(300.0, 48.0)
	rtl.position = Vector2(1550.0 - 150.0, 360.0)
	rtl.z_index = 45
	Profiler.add_child_count += 1; target_parent.add_child(rtl)

	var orig_y = rtl.position.y
	var tw = create_tween()
	tw.tween_property(rtl, "position:y", orig_y - 45.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rtl, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.chain().tween_callback(rtl.queue_free)

## 敵が体力を吸収回復した時のポップアップ ＆ 発光演出
func _spawn_enemy_heal_effect(sm: Node2D, heal_amount: int) -> void:
	if sm == null or sm.enemy == null: return
	var p = get_parent()
	var target_parent = p if p != null else self

	var enemy_sp = sm.enemy
	var orig_scale: Vector2 = enemy_sp.scale

	# 敵の緑色生命力パルス発光（スケールを破壊せず元のサイズを正確に保持）
	var tw_pulse = create_tween()
	tw_pulse.tween_property(enemy_sp, "modulate", Color(0.4, 2.2, 0.8, 1.0), 0.18)
	tw_pulse.parallel().tween_property(enemy_sp, "scale", orig_scale * 1.06, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_pulse.tween_property(enemy_sp, "modulate", Color.WHITE, 0.3)
	tw_pulse.parallel().tween_property(enemy_sp, "scale", orig_scale, 0.3)

	# 敵HP回復ポップアップ
	var custom_font = preload("res://font/g_comickoin_freeR.ttf")
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.fit_content = false
	rtl.scroll_active = false
	rtl.add_theme_font_override("normal_font", custom_font)
	rtl.add_theme_font_override("bold_font", custom_font)
	rtl.add_theme_constant_override("outline_size", 8)
	rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	rtl.text = "[center][b][color=#69F0AE]+%d 吸収回復[/color][/b][/center]" % heal_amount
	rtl.size = Vector2(300.0, 48.0)
	rtl.position = enemy_sp.global_position + Vector2(-150.0, 25.0)
	rtl.z_index = 45
	Profiler.add_child_count += 1; target_parent.add_child(rtl)

	var orig_y = rtl.position.y
	var tw_lbl = create_tween()
	tw_lbl.tween_property(rtl, "position:y", orig_y - 50.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_lbl.parallel().tween_property(rtl, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw_lbl.chain().tween_callback(rtl.queue_free)

	# 回復スパーク粒子
	for k in range(8):
		var spark = Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(0, -8), Vector2(3, -3), Vector2(8, 0), Vector2(3, 3), Vector2(0, 8), Vector2(-3, 3), Vector2(-8, 0), Vector2(-3, -3)])
		spark.color = Color(0.4, 1.0, 0.6, 0.9)
		spark.position = enemy_sp.global_position + Vector2(randf_range(-80, 80), randf_range(-40, 80))
		spark.z_index = 44
		Profiler.add_child_count += 1; target_parent.add_child(spark)

		var tw_s = create_tween()
		tw_s.tween_property(spark, "position:y", spark.position.y - randf_range(60, 110), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_s.parallel().tween_property(spark, "scale", Vector2.ZERO, 0.6)
		tw_s.chain().tween_callback(spark.queue_free)

var _cached_effects_node: Node = null
var _combo_guide_texture: Texture2D = null
var _active_combo_guide_root: Node2D = null
var _active_combo_guide_tween: Tween = null
func _get_effects_parent() -> Node:
	if _cached_effects_node == null or not is_instance_valid(_cached_effects_node):
		_cached_effects_node = get_node_or_null("Effects")
		if _cached_effects_node == null:
			_cached_effects_node = self
	return _cached_effects_node

## 汎用ショックウェーブリング（衝撃波リング演出）
func _spawn_shockwave_ring(pos: Vector2, color: Color, max_radius: float, duration: float = 0.3) -> void:
	var effects_parent = _get_effects_parent()
	var ring = Line2D.new()
	ring.width = 16.0
	ring.default_color = color
	ring.z_index = 32
	var n_pts = 24
	var pts: PackedVector2Array = []
	for i in range(n_pts + 1):
		var a = i * TAU / float(n_pts)
		pts.append(Vector2(cos(a), sin(a)) * 10.0)
	ring.points = pts
	ring.position = pos
	Profiler.add_child_count += 1; effects_parent.add_child(ring)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(max_radius / 10.0, max_radius / 10.0), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "width", 3.0, duration)
	tw.chain().tween_callback(ring.queue_free)

## 汎用全画面フラッシュ（急な点滅を避け、短いフェードイン→長めのフェードアウトで柔らかく表示）
func _spawn_screen_flash(color: Color, duration: float = 0.08) -> void:
	var effects_parent = _get_effects_parent()
	var flash = ColorRect.new()
	flash.size = Vector2(40000.0, 40000.0)
	flash.position = Vector2(-20000.0, -20000.0)
	flash.color = Color(color.r, color.g, color.b, 1.0)
	flash.modulate.a = 0.0
	flash.z_index = 40
	Profiler.add_child_count += 1; effects_parent.add_child(flash)

	var peak: float = minf(color.a, 0.30)
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", peak, 0.06)
	tw.tween_property(flash, "modulate:a", 0.0, maxf(duration, 0.30))
	tw.tween_callback(flash.queue_free)

## フラクタル稲妻ライン生成ヘルパー（中腹で揺れが最大化する自然な放電経路）
func _generate_lightning_bolt_points(start_p: Vector2, end_p: Vector2, segs: int = 12, max_jitter: float = 80.0) -> PackedVector2Array:
	var pts: PackedVector2Array = [start_p]
	var dir = end_p - start_p
	var perp = dir.orthogonal().normalized()
	for s in range(1, segs):
		var frac = float(s) / float(segs)
		var taper = sin(frac * PI)
		var pt = start_p.lerp(end_p, frac) + perp * randf_range(-max_jitter, max_jitter) * taper
		pts.append(pt)
	pts.append(end_p)
	return pts

## 多層電撃ボルト生成ヘルパー（外層発光オーラ ＋ 電撃本体 ＋ 純白コア）
func _create_multi_layer_bolt(parent: Node, pts: PackedVector2Array, glow_color: Color, bolt_color: Color, core_color: Color, glow_w: float, bolt_w: float, core_w: float, z: int) -> Array[Line2D]:
	var glow = Line2D.new()
	glow.points = pts
	glow.width = glow_w
	glow.default_color = glow_color
	glow.joint_mode = Line2D.LINE_JOINT_BEVEL
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.z_index = z
	Profiler.add_child_count += 1; parent.add_child(glow)

	var bolt = Line2D.new()
	bolt.points = pts
	bolt.width = bolt_w
	bolt.default_color = bolt_color
	bolt.joint_mode = Line2D.LINE_JOINT_BEVEL
	bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.z_index = z + 1
	Profiler.add_child_count += 1; parent.add_child(bolt)

	var core = Line2D.new()
	core.points = pts
	core.width = core_w
	core.default_color = core_color
	core.joint_mode = Line2D.LINE_JOINT_BEVEL
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	core.z_index = z + 2
	Profiler.add_child_count += 1; parent.add_child(core)

	return [glow, bolt, core]

## 剣命中時の斬撃十字スパーク演出（高密度過負荷を防ぐため時間間引き）
func _spawn_hit_spark(hit_pos: Vector2) -> void:
	var now = Time.get_ticks_msec()
	if now - _last_spark_msec < 40:
		return
	_last_spark_msec = now

	var effects_parent = _get_effects_parent()

	for slash_dir in [-1.0, 1.0]:
		var slash = Line2D.new()
		slash.width = 14.0
		slash.default_color = Color(1.0, 0.95, 0.4, 0.98)
		slash.z_index = 35
		var p1 = hit_pos + Vector2(-140.0 * slash_dir, -140.0)
		var p2 = hit_pos + Vector2(140.0 * slash_dir, 140.0)
		slash.points = PackedVector2Array([p1, p2])
		Profiler.add_child_count += 1; effects_parent.add_child(slash)

		var tw_sl = create_tween().set_parallel(true)
		tw_sl.tween_property(slash, "width", 0.0, 0.14)
		tw_sl.tween_property(slash, "modulate:a", 0.0, 0.14)
		tw_sl.chain().tween_callback(slash.queue_free)

	if now - _last_shockwave_msec >= 100:
		_last_shockwave_msec = now
		_spawn_shockwave_ring(hit_pos, Color(1.0, 0.85, 0.2, 0.9), 180.0, 0.16)

## 爆発演出（白熱スターフラッシュ、二重火炎球、火炎衝撃波リング、飛散火の粉パーティクル）
func _spawn_explosion_effect(pos: Vector2) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(45.0)

	var boom_se = get_node_or_null("AudioStreamPlayer")
	if boom_se:
		boom_se.play()
		boom_se.pitch_scale = randf_range(0.70, 0.90)

	# 1. 中心白熱スターフラッシュ
	var star = Polygon2D.new()
	var star_pts: PackedVector2Array = []
	for i in range(16):
		var a = i * TAU / 16.0
		var r = 260.0 if i % 2 == 0 else 90.0
		star_pts.append(Vector2(cos(a), sin(a)) * r)
	star.polygon = star_pts
	star.color = Color(1.0, 1.0, 1.0, 0.98)
	star.position = pos
	star.scale = Vector2(0.2, 0.2)
	star.z_index = 32
	Profiler.add_child_count += 1; effects_parent.add_child(star)

	var tw_star = create_tween().set_parallel(true)
	tw_star.tween_property(star, "scale", Vector2(1.6, 1.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_star.tween_property(star, "modulate:a", 0.0, 0.14)
	tw_star.chain().tween_callback(star.queue_free)

	# 2. 多層火炎球（外層バーニングレッド ＋ 内層ブレイズオレンジ）
	for layer in range(2):
		var flame = Polygon2D.new()
		var n_pts = 20
		var f_pts: PackedVector2Array = []
		var base_r = 280.0 if layer == 0 else 200.0
		for i in range(n_pts):
			var a = i * TAU / float(n_pts)
			var r = base_r + randf_range(-30.0, 30.0)
			f_pts.append(Vector2(cos(a), sin(a)) * r)
		flame.polygon = f_pts
		flame.color = Color(1.0, 0.25, 0.05, 0.85) if layer == 0 else Color(1.0, 0.85, 0.2, 0.92)
		flame.position = pos
		flame.scale = Vector2(0.15, 0.15)
		flame.z_index = 30 + layer
		Profiler.add_child_count += 1; effects_parent.add_child(flame)

		var tw_f = create_tween().set_parallel(true)
		var max_s = 2.4 if layer == 0 else 1.8
		tw_f.tween_property(flame, "scale", Vector2(max_s, max_s), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_f.tween_property(flame, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_f.chain().tween_callback(flame.queue_free)

	# 3. 火炎衝撃波リング
	_spawn_shockwave_ring(pos, Color(1.0, 0.55, 0.1, 0.9), 450.0, 0.28)

	# 4. 飛散する発光火の粉パーティクル（20個）
	for i in range(20):
		var ember = Polygon2D.new()
		var sz = randf_range(14.0, 26.0)
		ember.polygon = PackedVector2Array([
			Vector2(0, -sz), Vector2(sz * 0.7, 0), Vector2(0, sz), Vector2(-sz * 0.7, 0)
		])
		ember.color = Color(1.0, randf_range(0.4, 0.9), 0.1, 0.95)
		ember.position = pos
		ember.z_index = 33
		Profiler.add_child_count += 1; effects_parent.add_child(ember)

		var a = randf() * TAU
		var spd = randf_range(350.0, 850.0)
		var dest = pos + Vector2(cos(a), sin(a)) * (spd * 0.35)
		var dur = randf_range(0.25, 0.38)

		var tw_e = create_tween().set_parallel(true)
		tw_e.tween_property(ember, "position", dest, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_e.tween_property(ember, "rotation", randf_range(-PI * 3.0, PI * 3.0), dur)
		tw_e.tween_property(ember, "scale", Vector2.ZERO, dur)
		tw_e.tween_property(ember, "modulate:a", 0.0, dur)
		tw_e.chain().tween_callback(ember.queue_free)

func _spawn_fire_ignition_effect(pos: Vector2, is_ally: bool = true, power: float = 1.0) -> void:
	var effects_parent = _get_effects_parent()
	var core_col = Color(0.55, 0.95, 1.0, 0.95) if is_ally else Color(1.0, 0.55, 0.15, 0.95)
	var outer_col = Color(0.10, 0.65, 1.0, 0.55) if is_ally else Color(1.0, 0.20, 0.05, 0.55)

	for layer in range(3):
		var flame = Polygon2D.new()
		var h = (130.0 - layer * 20.0) * power
		var w = (44.0 - layer * 8.0) * power
		flame.polygon = PackedVector2Array([
			Vector2(0, -h),
			Vector2(w * 0.55, -h * 0.45),
			Vector2(w, 18.0 * power),
			Vector2(w * 0.45, 8.0 * power),
			Vector2(0, 30.0 * power),
			Vector2(-w * 0.45, 8.0 * power),
			Vector2(-w, 18.0 * power),
			Vector2(-w * 0.55, -h * 0.45)
		])
		flame.color = outer_col.lerp(core_col, float(layer) / 2.0)
		flame.position = pos + Vector2(randf_range(-8.0, 8.0), 0.0)
		flame.scale = Vector2(0.25, 0.08)
		flame.z_index = 30 + layer
		Profiler.add_child_count += 1
		effects_parent.add_child(flame)

		var tw = create_tween().set_parallel(true)
		tw.tween_property(flame, "scale", Vector2(randf_range(0.85, 1.15), randf_range(0.90, 1.20)), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(flame, "rotation", randf_range(-0.12, 0.12), 0.28)
		tw.tween_property(flame, "modulate:a", 0.0, 0.42).set_delay(0.10)
		tw.chain().tween_callback(flame.queue_free)

	for i in range(8):
		var ember = Polygon2D.new()
		var sz = randf_range(4.0, 9.0) * power
		ember.polygon = PackedVector2Array([
			Vector2(0, -sz), Vector2(sz * 0.6, 0), Vector2(0, sz), Vector2(-sz * 0.6, 0)
		])
		ember.color = Color(core_col.r, core_col.g, core_col.b, 0.9)
		ember.position = pos + Vector2(randf_range(-35.0, 35.0), randf_range(5.0, 35.0))
		ember.z_index = 33
		Profiler.add_child_count += 1
		effects_parent.add_child(ember)

		var tw_e = create_tween().set_parallel(true)
		tw_e.tween_property(ember, "position", ember.position + Vector2(randf_range(-28.0, 28.0), randf_range(-120.0, -60.0) * power), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_e.tween_property(ember, "rotation", randf_range(-PI, PI), 0.5)
		tw_e.tween_property(ember, "scale", Vector2.ZERO, 0.5)
		tw_e.tween_property(ember, "modulate:a", 0.0, 0.5)
		tw_e.chain().tween_callback(ember.queue_free)

## 十字クロス爆砕エフェクト（高エネルギーレーザービーム ＆ スターフレア）
func _spawn_cross_effect(pos: Vector2, _lvl: int) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(42.0)

	var boom_se = get_node_or_null("AudioStreamPlayer")
	if boom_se:
		boom_se.pitch_scale = 1.35
		boom_se.play()

	# 1. 中心クロススターフレア
	var star = Polygon2D.new()
	var s_pts: PackedVector2Array = []
	for i in range(8):
		var a = i * TAU / 8.0
		var r = 320.0 if i % 2 == 0 else 60.0
		s_pts.append(Vector2(cos(a), sin(a)) * r)
	star.polygon = s_pts
	star.color = Color(1.0, 1.0, 1.0, 0.98)
	star.position = pos
	star.z_index = 33
	Profiler.add_child_count += 1; effects_parent.add_child(star)

	var tw_s = create_tween().set_parallel(true)
	tw_s.tween_property(star, "scale", Vector2(1.8, 1.8), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(star, "modulate:a", 0.0, 0.20)
	tw_s.chain().tween_callback(star.queue_free)

	# 2. 縦横の二重光線レーザー（外層エネルギーオーラ ＋ 純白コアビーム）
	for is_horizontal in [false, true]:
		var beam_aura = ColorRect.new()
		if is_horizontal:
			beam_aura.size = Vector2(8000.0, 90.0)
			beam_aura.pivot_offset = Vector2(4000.0, 45.0)
		else:
			beam_aura.size = Vector2(90.0, 8000.0)
			beam_aura.pivot_offset = Vector2(45.0, 4000.0)
		beam_aura.position = pos - beam_aura.pivot_offset
		beam_aura.color = Color(0.1, 0.65, 1.0, 0.60)
		beam_aura.z_index = 28
		Profiler.add_child_count += 1; effects_parent.add_child(beam_aura)

		var beam_core = ColorRect.new()
		if is_horizontal:
			beam_core.size = Vector2(8000.0, 24.0)
			beam_core.pivot_offset = Vector2(4000.0, 12.0)
		else:
			beam_core.size = Vector2(24.0, 8000.0)
			beam_core.pivot_offset = Vector2(12.0, 4000.0)
		beam_core.position = pos - beam_core.pivot_offset
		beam_core.color = Color(1.0, 1.0, 1.0, 0.98)
		beam_core.z_index = 29
		Profiler.add_child_count += 1; effects_parent.add_child(beam_core)

		var tw_b = create_tween().set_parallel(true)
		var scale_prop = "scale:y" if is_horizontal else "scale:x"
		tw_b.tween_property(beam_aura, scale_prop, 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_b.tween_property(beam_core, scale_prop, 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_b.tween_property(beam_aura, "modulate:a", 0.0, 0.24)
		tw_b.tween_property(beam_core, "modulate:a", 0.0, 0.20)
		tw_b.chain().tween_callback(beam_aura.queue_free)
		tw_b.chain().tween_callback(beam_core.queue_free)

	_spawn_shockwave_ring(pos, Color(0.3, 0.9, 1.0, 0.85), 300.0, 0.24)

## ディスコボール全滅エフェクト（虹色の全画面フラッシュと回転プリズム光芒）
func _spawn_disco_effect(pos: Vector2) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(50.0)

	var boom_se = get_node_or_null("AudioStreamPlayer")
	if boom_se:
		boom_se.pitch_scale = 1.5
		boom_se.play()

	_spawn_screen_flash(Color(1.0, 0.85, 1.0, 0.50), 0.35)
	_spawn_shockwave_ring(pos, Color(1.0, 0.4, 0.9, 0.9), 600.0, 0.40)
	_spawn_shockwave_ring(pos, Color(0.4, 1.0, 0.8, 0.9), 400.0, 0.32)

	# 放射状レインボー光芒（12本）
	for i in range(12):
		var ray = Line2D.new()
		ray.width = 16.0
		var a = i * TAU / 12.0
		var c_hue = Color.from_hsv(float(i) / 12.0, 0.8, 1.0, 0.9)
		ray.default_color = c_hue
		ray.points = PackedVector2Array([pos, pos + Vector2(cos(a), sin(a)) * 1200.0])
		ray.z_index = 32
		Profiler.add_child_count += 1; effects_parent.add_child(ray)

		var tw_r = create_tween().set_parallel(true)
		tw_r.tween_property(ray, "width", 0.0, 0.38)
		tw_r.tween_property(ray, "modulate:a", 0.0, 0.38)
		tw_r.chain().tween_callback(ray.queue_free)

	for i in range(25):
		_spawn_burst_particles(pos, randi() % 5)

## ペンキ同色染め上げエフェクト（広がるインクスプラッシュ波紋）
func _spawn_paint_effect(pos: Vector2) -> void:
	var effects_parent = _get_effects_parent()

	_spawn_shockwave_ring(pos, Color(0.1, 1.0, 0.4, 0.9), 350.0, 0.35)

	var wave = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(20):
		var a = i * TAU / 20.0
		var r = 120.0 + (30.0 if i % 2 == 0 else -15.0)
		pts.append(Vector2(cos(a), sin(a)) * r)
	wave.polygon = pts
	wave.color = Color(0.15, 1.0, 0.45, 0.85)
	wave.position = pos
	wave.z_index = 28
	Profiler.add_child_count += 1; effects_parent.add_child(wave)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(wave, "scale", Vector2(3.5, 3.5), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "rotation", TAU * 0.3, 0.35)
	tw.tween_property(wave, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(wave.queue_free)

## 単発の天からの垂直落雷（ランダムなマスに上空から直撃 ＆ 黄色の雷電 ＆ 十分な表示時間で視認性向上）
func _spawn_vertical_lightning_bolt(impact_pos: Vector2, delay_sec: float) -> void:
	if delay_sec <= 0.0:
		_execute_vertical_lightning_bolt(impact_pos)
	else:
		var tw_delay = create_tween()
		tw_delay.tween_interval(delay_sec)
		tw_delay.tween_callback(func(): _execute_vertical_lightning_bolt(impact_pos))

func _execute_vertical_lightning_bolt(impact_pos: Vector2) -> void:
	var effects_parent = _get_effects_parent()

	_trigger_screen_shake(25.0)
	var boom_se = get_node_or_null("AudioStreamPlayer")
	if boom_se:
		boom_se.pitch_scale = randf_range(1.3, 1.6)
		boom_se.play()

	# 1. 天空（画面上空 Y=-600）から目標マスへの垂直直撃落雷ボルト
	var sky_start = Vector2(impact_pos.x + randf_range(-35.0, 35.0), -600.0)
	var main_pts = _generate_lightning_bolt_points(sky_start, impact_pos, 14, 60.0)
	
	# 黄色ベースの多層電撃（外層ゴールデンアンバー ＋ 中層エレクトリックイエロー ＋ 内層ウォームホワイト）
	var bolt_lines = _create_multi_layer_bolt(
		effects_parent, main_pts,
		Color(1.0, 0.72, 0.05, 0.65), Color(1.0, 0.95, 0.15, 0.98), Color(1.0, 1.0, 0.85, 1.0),
		34.0, 16.0, 6.0, 32
	)

	# 2. 空中へ走る枝分かれ稲妻（1〜2本）
	for f in range(2):
		var f_idx = randi_range(3, main_pts.size() - 4)
		var f_start = main_pts[f_idx]
		var f_dir = (Vector2(randf_range(-1.0, 1.0), randf_range(0.4, 1.0))).normalized()
		var f_end = f_start + f_dir * randf_range(200.0, 350.0)
		var f_pts = _generate_lightning_bolt_points(f_start, f_end, 6, 35.0)
		var f_lines = _create_multi_layer_bolt(
			effects_parent, f_pts,
			Color(1.0, 0.70, 0.05, 0.50), Color(1.0, 0.92, 0.18, 0.90), Color(1.0, 1.0, 0.90, 0.95),
			18.0, 8.0, 3.0, 31
		)
		for l in f_lines:
			var tw_fl = create_tween()
			tw_fl.tween_interval(0.25)
			tw_fl.tween_property(l, "modulate:a", 0.0, 0.25)
			tw_fl.tween_callback(l.queue_free)

	# 3. 着弾地点の黄色の地表プラズマ衝撃波リング（十分に視認できる時間保持）
	_spawn_shockwave_ring(impact_pos, Color(1.0, 0.88, 0.15, 0.9), 260.0, 0.45)

	# 4. 地表を走る黄色い放射状放電スパーク（6本）
	for s in range(6):
		var s_a = s * TAU / 6.0 + randf_range(-0.25, 0.25)
		var s_end = impact_pos + Vector2(cos(s_a), sin(s_a)) * randf_range(120.0, 220.0)
		var s_pts = _generate_lightning_bolt_points(impact_pos, s_end, 4, 20.0)
		var s_line = Line2D.new()
		s_line.points = s_pts
		s_line.width = 6.0
		s_line.default_color = Color(1.0, 0.95, 0.3, 0.95)
		s_line.z_index = 33
		Profiler.add_child_count += 1; effects_parent.add_child(s_line)
		var tw_s = create_tween()
		tw_s.tween_interval(0.20)
		tw_s.tween_property(s_line, "modulate:a", 0.0, 0.30)
		tw_s.tween_callback(s_line.queue_free)

	# 5. 落雷ボルトの表示持続（チカチカさせず、しっかり視認できる約0.55秒の持続＆滑らかなフェード消散）
	for l in bolt_lines:
		var tw_b = create_tween()
		tw_b.tween_interval(0.28) # 0.28秒間しっかり維持して状況を把握可能に
		tw_b.tween_property(l, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_b.tween_callback(l.queue_free)

## 天からの落雷シーケンス（起点マスおよびランダムな対象マスすべてに上空から垂直直撃）
func _spawn_lightning_effect(start_pos: Vector2, targets: Array[Vector2]) -> void:
	# 起点マスへの垂直直撃落雷
	_spawn_vertical_lightning_bolt(start_pos, 0.0)

	# 各ランダム対象マスへの時間差連続直撃（0.07秒ずつ順次落雷）
	for i in range(targets.size()):
		_spawn_vertical_lightning_bolt(targets[i], 0.07 * (i + 1))

## ブラックホールエフェクト（漆黒の特異点事象の地平線 ＆ 高速回転降着円盤 ＆ 対数螺旋粒子吸引）
func _spawn_black_hole_effect(pos: Vector2, lvl: int) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(50.0 + lvl * 10.0)

	var boom_se = get_node_or_null("AudioStreamPlayer")
	if boom_se:
		boom_se.pitch_scale = 0.55
		boom_se.play()

	# 1. 降着円盤（外側のアクレッションディスク）
	var disk = Polygon2D.new()
	var n_pts = 24
	var d_pts: PackedVector2Array = []
	for i in range(n_pts):
		var a = i * TAU / float(n_pts)
		var r = 160.0 + (30.0 if i % 2 == 0 else -20.0)
		d_pts.append(Vector2(cos(a), sin(a)) * r)
	disk.polygon = d_pts
	disk.color = Color(0.65, 0.15, 1.0, 0.85)
	disk.position = pos
	disk.z_index = 28
	Profiler.add_child_count += 1; effects_parent.add_child(disk)

	# 2. 事象の地平線（漆黒のコア特異点）
	var void_core = Polygon2D.new()
	var c_pts: PackedVector2Array = []
	for i in range(20):
		var a = i * TAU / 20.0
		c_pts.append(Vector2(cos(a), sin(a)) * 100.0)
	void_core.polygon = c_pts
	void_core.color = Color(0.01, 0.0, 0.03, 1.0)
	void_core.position = pos
	void_core.z_index = 29
	Profiler.add_child_count += 1; effects_parent.add_child(void_core)

	var tw = create_tween().set_parallel(true)
	var max_scale = Vector2(4.0 * lvl, 4.0 * lvl)
	tw.tween_property(disk, "scale", max_scale, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(void_core, "scale", max_scale * 0.7, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(disk, "rotation", TAU * 3.0, 0.50)
	tw.tween_property(void_core, "rotation", -TAU * 1.5, 0.50)

	# 3. 中心へ吸い込まれる螺旋光粒子群（20個）
	for i in range(20):
		var part = Polygon2D.new()
		part.polygon = PackedVector2Array([
			Vector2(0, -8), Vector2(6, 0), Vector2(0, 8), Vector2(-6, 0)
		])
		part.color = Color(0.8, 0.3, 1.0, 0.9) if i % 2 == 0 else Color(0.2, 0.8, 1.0, 0.9)
		var init_a = randf() * TAU
		var init_dist = randf_range(300.0, 700.0)
		part.position = pos + Vector2(cos(init_a), sin(init_a)) * init_dist
		part.z_index = 30
		Profiler.add_child_count += 1; effects_parent.add_child(part)

		var tw_p = create_tween().set_parallel(true)
		tw_p.tween_property(part, "position", pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_p.tween_property(part, "scale", Vector2.ZERO, 0.42)
		tw_p.chain().tween_callback(part.queue_free)

	tw.chain().tween_property(disk, "scale", Vector2.ZERO, 0.12)
	tw.parallel().tween_property(void_core, "scale", Vector2.ZERO, 0.12)
	tw.chain().tween_callback(disk.queue_free)
	tw.parallel().tween_callback(void_core.queue_free)

## 聖光星エフェクト（眩い黄金・聖光線の全方位放射と衝撃波）
func _spawn_holy_light_effect(center_pos: Vector2, targets: Array[Vector2]) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(25.0)
	_spawn_screen_flash(Color(1.0, 0.98, 0.7, 0.35), 0.15)
	_spawn_shockwave_ring(center_pos, Color(1.0, 0.95, 0.4, 0.9), 350.0, 0.25)

	for t_pos in targets:
		var line = Line2D.new()
		line.default_color = Color(1.0, 0.95, 0.45, 0.95)
		line.width = 12.0
		line.z_index = 28
		line.add_point(center_pos)
		line.add_point(t_pos)
		Profiler.add_child_count += 1; effects_parent.add_child(line)

		var tw = create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.22)
		tw.tween_callback(line.queue_free)

func _spawn_magnet_effect(center_pos: Vector2, targets: Array[Vector2]) -> void:
	_spawn_holy_light_effect(center_pos, targets)

## 超巨大爆弾エフェクト（チャージ段階に応じた破格の大爆破）
func _spawn_mega_explosion_effect(pos: Vector2, ch: int) -> void:
	_trigger_screen_shake(45.0 + ch * 20.0)
	var boom_se = get_node_or_null("AudioStreamPlayer")
	if boom_se:
		boom_se.pitch_scale = clampf(1.0 - ch * 0.15, 0.4, 1.0)
		boom_se.play()

	_spawn_screen_flash(Color(1.0, 0.6, 0.2, 0.45), 0.12)
	_spawn_explosion_effect(pos)
	_spawn_shockwave_ring(pos, Color(1.0, 0.8, 0.2, 0.95), 600.0 + ch * 100.0, 0.35)

	for i in range(ch * 8):
		_spawn_burst_particles(pos, randi() % 5)

## ジェミニ分裂エフェクト（火炎迫撃弾の山なり放物線）
func _spawn_gemini_effect(start_pos: Vector2, targets: Array[Vector2]) -> void:
	var effects_parent = _get_effects_parent()

	for t_pos in targets:
		var spark = Polygon2D.new()
		spark.polygon = PackedVector2Array([
			Vector2(0, -22), Vector2(16, 0), Vector2(0, 22), Vector2(-16, 0)
		])
		spark.color = Color(1.0, 0.6, 0.1, 1.0)
		spark.position = start_pos
		spark.z_index = 32
		Profiler.add_child_count += 1; effects_parent.add_child(spark)

		var tw = create_tween()
		tw.tween_property(spark, "position", t_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			_spawn_explosion_effect(t_pos)
			spark.queue_free(); Profiler.queue_free_count += 1
		)

## 本格立体サイクロン竜巻・つむじ風ノード（高速回転スパイラルファンネル ＆ 旋回風刃 ＆ 渦巻き木の葉）
class TornadoVortexNode extends Node2D:
	var life_time: float = 0.0
	var duration: float = 0.70
	var start_pos: Vector2 = Vector2.ZERO
	var target_top_y: float = 0.0
	var width_px: float = 500.0
	var lvl: int = 1
	var leaves: Array[Dictionary] = []

	func _init(p_pos: Vector2, p_target_top_y: float, p_width: float, p_lvl: int) -> void:
		start_pos = p_pos
		target_top_y = p_target_top_y
		width_px = p_width
		lvl = p_lvl
		position = p_pos
		z_index = 32

		# 渦に巻き上げられる木の葉・風切片の初期化（28個）
		for i in range(28):
			leaves.append({
				"init_angle": randf() * TAU,
				"speed": randf_range(16.0, 26.0) * (1.0 if randf() > 0.1 else -1.0),
				"init_r": randf_range(40.0, width_px * 0.48),
				"rise_speed": randf_range(1200.0, 2400.0),
				"size": randf_range(10.0, 18.0),
				"color": Color(0.2, randf_range(0.75, 1.0), randf_range(0.4, 0.8), 0.95),
				"seed_y": randf_range(-50.0, 100.0)
			})

	func _process(delta: float) -> void:
		var _prof = Profiler.begin("puzzle_board::_process")
		life_time += delta
		if life_time >= duration:
			queue_free(); Profiler.queue_free_count += 1
			return

		var p: float = clampf(life_time / duration, 0.0, 1.0)
		# 上昇移動 (イーズアウト)
		var rise_t: float = 1.0 - pow(1.0 - p, 2.2)
		position.y = lerpf(start_pos.y, target_top_y, rise_t)
		queue_redraw()

	func _draw() -> void:
		var _prof = Profiler.begin("puzzle_board::_draw")
		var p: float = clampf(life_time / duration, 0.0, 1.0)
		var fade_alpha: float = (1.0 - p) if p > 0.6 else 1.0

		# 1. 地上・基底部の高速回転スパイラル渦紋 (Ground Vortex)
		var g_spin = life_time * 18.0
		for g in range(3):
			var g_r = (50.0 + g * 35.0) * (1.0 + p * 0.5)
			var g_col = Color(0.3, 1.0, 0.8, 0.55 * fade_alpha * (1.0 - g * 0.2))
			draw_arc(Vector2.ZERO, g_r, g_spin + g * 1.5, g_spin + g * 1.5 + PI * 1.3, 20, g_col, (10.0 - g * 2.0))

		# 2. 立体らせんサイクロン風流リボン (Helical Funnel Vortex)
		var num_streams: int = 8 + lvl * 2
		var funnel_height: float = absf(start_pos.y - target_top_y) * 0.65 + 400.0
		var spin_angle: float = life_time * 22.0

		for s_idx in range(num_streams):
			var s_pts: PackedVector2Array = []
			var s_offset = s_idx * (TAU / float(num_streams))
			var segs = 16

			for seg in range(segs):
				var frac = float(seg) / float(segs)
				var cur_y = -frac * funnel_height
				# すり鉢状ファンネルの半径（上に行くほど広がる）
				var cur_r = (0.22 + frac * 0.85) * (width_px * 0.52)
				# 高速らせん角度
				var theta = spin_angle + s_offset + frac * TAU * 3.2
				var cur_x = cos(theta) * cur_r
				s_pts.append(Vector2(cur_x, cur_y))

			var is_front = sin(spin_angle + s_offset) > 0.0
			var stream_col: Color
			var stream_w: float
			if s_idx % 2 == 0:
				stream_col = Color(0.85, 1.0, 0.95, 0.90 * fade_alpha) if is_front else Color(0.2, 0.8, 0.6, 0.45 * fade_alpha)
				stream_w = 16.0 if is_front else 10.0
			else:
				stream_col = Color(0.25, 0.95, 0.85, 0.85 * fade_alpha) if is_front else Color(0.15, 0.6, 0.7, 0.40 * fade_alpha)
				stream_w = 14.0 if is_front else 8.0

			draw_polyline(s_pts, stream_col, stream_w)

		# 3. 周回する真空の風刃（ウインドカッター・クレセントブレード）
		var num_blades: int = 6
		for b in range(num_blades):
			var b_ang = life_time * 26.0 + b * (TAU / float(num_blades))
			var b_height_ratio = fposmod(life_time * 1.6 + b * 0.17, 1.0)
			var b_y = -b_height_ratio * funnel_height
			var b_r = (0.3 + b_height_ratio * 0.8) * (width_px * 0.55)

			# 弧状の刃
			var blade_pts: PackedVector2Array = []
			for bp in range(6):
				var arc_a = b_ang - bp * 0.12
				blade_pts.append(Vector2(cos(arc_a) * b_r, b_y + sin(arc_a) * b_r * 0.18))
			draw_polyline(blade_pts, Color(1.0, 1.0, 1.0, 0.95 * fade_alpha), 10.0)
			draw_polyline(blade_pts, Color(0.2, 1.0, 0.8, 0.70 * fade_alpha), 16.0)

		# 4. 円筒らせん軌道で猛烈に渦巻く木の葉・風切片
		for leaf in leaves:
			var leaf_t = life_time
			var cur_angle = leaf["init_angle"] + leaf_t * leaf["speed"]
			var cur_r = leaf["init_r"] * (1.0 + p * 0.8)
			var cur_y = -leaf_t * leaf["rise_speed"] + leaf["seed_y"]

			# 3D風のパース（楕円軌道）
			var l_pos = Vector2(cos(cur_angle) * cur_r, cur_y + sin(cur_angle) * cur_r * 0.28)
			var l_size = leaf["size"]
			var l_poly = PackedVector2Array([
				l_pos + Vector2(0, -l_size),
				l_pos + Vector2(l_size * 0.6, 0),
				l_pos + Vector2(0, l_size),
				l_pos + Vector2(-l_size * 0.6, 0)
			])
			var l_col: Color = leaf["color"]
			l_col.a *= fade_alpha
			draw_colored_polygon(l_poly, l_col)

## 竜巻・つむじ風エフェクト
## 仕様変更: 敵「ダウンバースト」と同じアニメーションで、起爆駒の列（+進化幅）を上端から下端へ風が横断する
func _spawn_tornado_effect(pos: Vector2, lvl: int, half_w: int) -> void:
	_trigger_screen_shake(35.0 + lvl * 10.0)

	var sound = get_node_or_null("AudioStreamPlayer")
	if sound:
		sound.pitch_scale = 1.45
		sound.play()

	# 起爆駒の列を特定（セル中心は (c+0.5)*CELL_PITCH なので小数部を切り捨てて正しい列にする）
	var center_col: int = int(floor((pos.x - BOARD_LEFT) / CELL_PITCH))
	# 敵ダウンオールと同じ active_wind_tornadoes 方式で上→下に横断
	for dc in range(-half_w, half_w + 1):
		var col: int = center_col + dc
		if col >= 0 and col < GRID_COLUMNS:
			active_wind_tornadoes.append({
				"col": col,
				"y": BOARD_TOP,
				"speed": 5500.0,
				"active": true,
				"ally": true
			})
	_redraw_board_effects()

## 敵キャラクター専用の竜巻エフェクト（敵画面枠 X:1190..1915, Y:10..410 を決して越えず内部に美しく収束）
func _spawn_enemy_tornado_effect(pos: Vector2, size: int) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(8.0 + float(size) * 3.0)

	var sound = get_node_or_null("AudioStreamPlayer")
	if sound:
		sound.pitch_scale = 1.45
		sound.play()

	# 敵画面サイズ（幅725px、高さ400px = ローカル幅7250、高さ4000）内に完全に収まる幅・高さ
	var clamped_size = clampi(size, 1, 5)
	var width_px = 850.0 + float(clamped_size) * 220.0 # グローバルで約85px〜195px (敵1体の幅に完璧に適合)
	var target_top_y = maxf(200.0, pos.y - (650.0 + float(clamped_size) * 160.0)) # 敵画面上端（ローカル200）を絶対超えない

	var vortex = TornadoVortexNode.new(pos, target_top_y, width_px, clampi(clamped_size, 1, 3))
	Profiler.add_child_count += 1; effects_parent.add_child(vortex)

## 水しぶき・アクアスプラッシュ演出（同心円波紋 ＆ 重力水滴放物線スプラッシュ ＆ ミスト）
func _spawn_aqua_splash_effect(pos: Vector2, radius: int) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(22.0 + radius * 5.0)

	var splash_radius = (radius + 0.5) * CELL_PITCH

	# 1. 二重同心円の滑らかな水面リップルリング
	_spawn_shockwave_ring(pos, Color(0.2, 0.8, 1.0, 0.85), splash_radius, 0.35)
	_spawn_shockwave_ring(pos, Color(0.5, 0.95, 1.0, 0.65), splash_radius * 0.6, 0.28)

	# 2. 重力で放物線を描いて弾ける水滴パーティクル（24個）
	for i in range(24):
		var drop = Polygon2D.new()
		var d_sz = randf_range(12.0, 24.0)
		drop.polygon = PackedVector2Array([
			Vector2(0, -d_sz), Vector2(d_sz * 0.6, 0), Vector2(0, d_sz * 0.6), Vector2(-d_sz * 0.6, 0)
		])
		drop.color = Color(0.3, randf_range(0.8, 1.0), 1.0, 0.9)
		drop.position = pos
		drop.z_index = 29
		Profiler.add_child_count += 1; effects_parent.add_child(drop)

		var a = randf() * TAU
		var spd = randf_range(300.0, 950.0)
		var dest = pos + Vector2(cos(a), sin(a)) * (spd * 0.35)
		var dur = randf_range(0.26, 0.40)

		var tw_d = create_tween().set_parallel(true)
		tw_d.tween_property(drop, "position", dest, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_d.tween_property(drop, "scale", Vector2.ZERO, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_d.tween_property(drop, "modulate:a", 0.0, dur)
		tw_d.chain().tween_callback(drop.queue_free)

	# 3. 立ち上る水蒸気ミスト
	_spawn_steam_effect(pos)

## 苗木の芽吹き演出（神聖召喚サークル ＆ 翠緑の若葉オーラ）
func _spawn_sprout_effect(pos: Vector2) -> void:
	var effects_parent = _get_effects_parent()

	_spawn_shockwave_ring(pos, Color(0.2, 1.0, 0.4, 0.9), 240.0, 0.36)

	var mandala = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(12):
		var a = i * TAU / 12.0
		var r = 180.0 if i % 2 == 0 else 100.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	mandala.polygon = pts
	mandala.color = Color(0.4, 1.0, 0.5, 0.8)
	mandala.position = pos
	mandala.scale = Vector2(0.1, 0.1)
	mandala.z_index = 28
	Profiler.add_child_count += 1; effects_parent.add_child(mandala)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(mandala, "scale", Vector2(1.4, 1.4), 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mandala, "rotation", TAU * 0.5, 0.36)
	tw.tween_property(mandala, "modulate:a", 0.0, 0.36)
	tw.chain().tween_callback(mandala.queue_free)

## 水たまり電撃伝導演出（感電水路ネットワーク）
func _spawn_water_electric_effect(cells: Array[Vector2i]) -> void:
	if cells.is_empty(): return
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(35.0)

	# 1. 各水たまりセルの黄色いプラズマ発光と放電スパーク
	for c in cells:
		var c_pos = get_cell_position(c.x, c.y)
		var aura = Polygon2D.new()
		var half_p = CELL_PITCH / 2.0 - 20.0
		aura.polygon = PackedVector2Array([
			Vector2(-half_p, -half_p), Vector2(half_p, -half_p),
			Vector2(half_p, half_p), Vector2(-half_p, half_p)
		])
		aura.color = Color(1.0, 0.85, 0.15, 0.50)
		aura.position = c_pos
		aura.z_index = 28
		Profiler.add_child_count += 1; effects_parent.add_child(aura)

		var tw_a = create_tween()
		tw_a.tween_interval(0.20)
		tw_a.tween_property(aura, "color:a", 0.0, 0.28)
		tw_a.tween_callback(aura.queue_free)

		for s in range(3):
			var sp_start = c_pos + Vector2(randf_range(-half_p, half_p), randf_range(-half_p, half_p))
			var sp_end = c_pos + Vector2(randf_range(-half_p, half_p), randf_range(-half_p, half_p))
			var sp_pts = _generate_lightning_bolt_points(sp_start, sp_end, 4, 18.0)
			var sp_line = Line2D.new()
			sp_line.points = sp_pts
			sp_line.width = 6.0
			sp_line.default_color = Color(1.0, 0.95, 0.3, 0.95)
			sp_line.z_index = 29
			Profiler.add_child_count += 1; effects_parent.add_child(sp_line)
			var tw_sp = create_tween()
			tw_sp.tween_interval(0.20)
			tw_sp.tween_property(sp_line, "modulate:a", 0.0, 0.28)
			tw_sp.tween_callback(sp_line.queue_free)

	# 2. 隣接する水たまり同士を繋ぐ黄色い電撃アーク網
	for i in range(cells.size()):
		var c1 = cells[i]
		var p1 = get_cell_position(c1.x, c1.y)
		for j in range(i + 1, cells.size()):
			var c2 = cells[j]
			if abs(c1.x - c2.x) + abs(c1.y - c2.y) == 1:
				var p2 = get_cell_position(c2.x, c2.y)
				var arc_pts = _generate_lightning_bolt_points(p1, p2, 6, 25.0)
				var arc_line = Line2D.new()
				arc_line.points = arc_pts
				arc_line.width = 10.0
				arc_line.default_color = Color(1.0, 0.92, 0.2, 0.95)
				arc_line.z_index = 30
				Profiler.add_child_count += 1; effects_parent.add_child(arc_line)
				var tw_arc = create_tween()
				tw_arc.tween_interval(0.20)
				tw_arc.tween_property(arc_line, "modulate:a", 0.0, 0.28)
				tw_arc.tween_callback(arc_line.queue_free)

## 植物の成長進化演出（天空を貫く神聖エメラルド光柱 ＆ 螺旋光粒子）
func _spawn_growth_effect(pos: Vector2, _stage: int) -> void:
	var effects_parent = _get_effects_parent()
	_trigger_screen_shake(32.0)

	# 1. 天空光柱（純白コア ＋ エメラルドオーラ）
	var pillar_aura = ColorRect.new()
	pillar_aura.size = Vector2(280.0, 2500.0)
	pillar_aura.pivot_offset = Vector2(140.0, 2500.0)
	pillar_aura.position = pos - pillar_aura.pivot_offset
	pillar_aura.color = Color(0.2, 1.0, 0.5, 0.70)
	pillar_aura.z_index = 32
	Profiler.add_child_count += 1; effects_parent.add_child(pillar_aura)

	var pillar_core = ColorRect.new()
	pillar_core.size = Vector2(80.0, 2500.0)
	pillar_core.pivot_offset = Vector2(40.0, 2500.0)
	pillar_core.position = pos - pillar_core.pivot_offset
	pillar_core.color = Color(1.0, 1.0, 0.8, 0.95)
	pillar_core.z_index = 33
	Profiler.add_child_count += 1; effects_parent.add_child(pillar_core)

	var tw_p = create_tween().set_parallel(true)
	tw_p.tween_property(pillar_aura, "scale:x", 2.2, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_p.tween_property(pillar_core, "scale:x", 1.8, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_p.tween_property(pillar_aura, "modulate:a", 0.0, 0.42)
	tw_p.tween_property(pillar_core, "modulate:a", 0.0, 0.35)
	tw_p.chain().tween_callback(pillar_aura.queue_free)
	tw_p.chain().tween_callback(pillar_core.queue_free)

	# 2. 地面ショックウェーブ
	_spawn_shockwave_ring(pos, Color(0.4, 1.0, 0.6, 0.9), 350.0, 0.38)

	# 3. 螺旋状に舞い上がる黄金光粒子と若葉
	for i in range(16):
		var star = Polygon2D.new()
		star.polygon = PackedVector2Array([
			Vector2(0, -12), Vector2(8, 0), Vector2(0, 12), Vector2(-8, 0)
		])
		star.color = Color(1.0, 0.9, 0.3, 0.95) if i % 2 == 0 else Color(0.3, 1.0, 0.6, 0.95)
		star.position = pos + Vector2(randf_range(-80.0, 80.0), 0.0)
		star.z_index = 34
		Profiler.add_child_count += 1; effects_parent.add_child(star)

		var tw_s = create_tween().set_parallel(true)
		var rise_y = -randf_range(400.0, 1000.0)
		var drift_x = randf_range(-150.0, 150.0)
		var dur = randf_range(0.35, 0.52)
		tw_s.tween_property(star, "position:y", pos.y + rise_y, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_s.tween_property(star, "position:x", star.position.x + drift_x, dur)
		tw_s.tween_property(star, "rotation", randf_range(-PI * 3.0, PI * 3.0), dur)
		tw_s.tween_property(star, "scale", Vector2.ZERO, dur)
		tw_s.tween_property(star, "modulate:a", 0.0, dur)
		tw_s.chain().tween_callback(star.queue_free)

## 植物ダメージ演出
func _spawn_plant_damage_effect(pos: Vector2, _is_dead: bool) -> void:
	var effects_parent = _get_effects_parent()

	for i in range(12):
		var leaf = Polygon2D.new()
		leaf.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(10, 0), Vector2(0, 16), Vector2(-10, 0)
		])
		leaf.color = Color(0.2, randf_range(0.7, 0.9), 0.3, 0.95)
		leaf.position = pos
		leaf.z_index = 31
		Profiler.add_child_count += 1; effects_parent.add_child(leaf)

		var angle = randf() * TAU
		var dist = randf_range(180.0, 400.0)
		var l_tw = create_tween().set_parallel(true)
		l_tw.tween_property(leaf, "position", pos + Vector2(cos(angle), sin(angle)) * dist, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		l_tw.tween_property(leaf, "rotation", randf_range(-PI * 2.0, PI * 2.0), 0.35)
		l_tw.tween_property(leaf, "scale", Vector2.ZERO, 0.35)
		l_tw.tween_property(leaf, "modulate:a", 0.0, 0.35)
		l_tw.chain().tween_callback(leaf.queue_free)

## 植物回復ポップアップ数値演出（緑の「+〇〇〇」）

## 状態異常ダメージを画面中央に大きく表示（毒・呪いなどの被ダメージを明確化）
func _spawn_status_damage_banner(text: String, color: Color) -> void:
	var effects_parent = _get_effects_parent()
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.10, 1.0))
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(360, 300)
	lbl.size = Vector2(560, 120)
	lbl.z_index = 60
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Profiler.add_child_count += 1
	effects_parent.add_child(lbl)
	lbl.pivot_offset = lbl.size / 2.0
	lbl.scale = Vector2(0.5, 0.5)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.75)
	tw.chain().tween_callback(lbl.queue_free)

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var effects_parent = _get_effects_parent()

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 45)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 1.0))
	lbl.add_theme_constant_override("outline_size", 6)
	
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	lbl.position = pos - Vector2(100.0, 50.0)
	lbl.custom_minimum_size = Vector2(200.0, 100.0)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	Profiler.add_child_count += 1; effects_parent.add_child(lbl)

	var tw = create_tween().set_parallel(true)
	lbl.scale = Vector2(0.5, 0.5)
	lbl.pivot_offset = lbl.custom_minimum_size / 2.0
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", pos.y - 150.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)

func _spawn_heal_number_effect(pos: Vector2, amount: int) -> void:
	var effects_parent = _get_effects_parent()

	var lbl = Label.new()
	lbl.text = "+%d" % amount
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.position = pos - Vector2(100.0, 60.0)
	lbl.z_index = 35
	Profiler.add_child_count += 1; effects_parent.add_child(lbl)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 160.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

## マッチした駒の破砕クリスタルシャード演出（属性別宝石カット多角形 ＆ スパークル光芒）
func _spawn_burst_particles(origin: Vector2, kind: int) -> void:
	var effects_parent = _get_effects_parent()

	var colors = [
		Color(0.2, 0.9, 1.0),   # SHIELD: サファイアクリスタルシアン
		Color(1.0, 0.25, 0.25),  # SWORD: ルビーバーニングレッド
		Color(1.0, 0.88, 0.15),  # COIN: トパーズゴールド
		Color(1.0, 0.3, 0.9),    # POTION: アメジストネオンマゼンタ
		Color(0.45, 1.0, 0.2)    # FOOD: エメラルドエナジーライム
	]
	var base_color = colors[clampi(kind % 5, 0, 4)]
	var shard_count = 4

	for k in range(shard_count):
		var shard = Polygon2D.new()
		var sz = randf_range(16.0, 32.0)
		shard.polygon = PackedVector2Array([
			Vector2(0, -sz), Vector2(sz * 0.65, -sz * 0.15),
			Vector2(sz * 0.4, sz * 0.85), Vector2(0, sz),
			Vector2(-sz * 0.4, sz * 0.85), Vector2(-sz * 0.65, -sz * 0.15)
		])
		shard.color = base_color.lightened(randf_range(0.05, 0.45))
		shard.position = origin
		shard.z_index = 26
		Profiler.add_child_count += 1; effects_parent.add_child(shard)

		var angle = randf_range(0.0, TAU)
		var distance = randf_range(300.0, 750.0)
		var target_pos = origin + Vector2(cos(angle), sin(angle)) * distance
		var target_rot = randf_range(-PI * 3.0, PI * 3.0)
		var duration = randf_range(0.26, 0.38)

		var p_tween = create_tween().set_parallel(true)
		p_tween.tween_property(shard, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tween.tween_property(shard, "rotation", target_rot, duration)
		p_tween.tween_property(shard, "scale", Vector2.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		p_tween.tween_property(shard, "modulate:a", 0.0, duration)
		p_tween.chain().tween_callback(shard.queue_free)

## 盤面のインパクト微細シェイク演出
func _trigger_screen_shake(intensity: float = 30.0) -> void:
	var s_tween = create_tween()
	var offset1 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	var offset2 = Vector2(randf_range(-intensity * 0.5, intensity * 0.5), randf_range(-intensity * 0.5, intensity * 0.5))
	s_tween.tween_property(self, "position", offset1, 0.03).set_trans(Tween.TRANS_SINE)
	s_tween.tween_property(self, "position", offset2, 0.04).set_trans(Tween.TRANS_SINE)
	s_tween.tween_property(self, "position", Vector2.ZERO, 0.04).set_trans(Tween.TRANS_SINE)

## マッチした駒の強調演出 (Squash & 発光)
func _start_match_highlight() -> void:
	current_state = BoardState.MATCH_HIGHLIGHT
	matched_cells_list.clear()

	var sm = _get_score_manager()
	if sm:
		sm.combocount += 1
		sm.iscombo = true
		sm.interval = 0
		var rm = _get_relic_manager()
		if rm: rm.on_cascade(sm.combocount)

	var rensa_se = get_node_or_null("1rensa")
	if rensa_se:
		var combo_num: int = sm.combocount if sm else 1
		var base_pitch: float = 0.92 + minf(1.08, float(maxi(0, combo_num - 1)) * 0.08)
		var spd: float = 1.0
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "game_speed" in sm_autoload:
			spd = sm_autoload.game_speed
		rensa_se.pitch_scale = base_pitch * spd
		rensa_se.play()



	var has_highlights: bool = false
	var tween = create_tween().set_parallel(true)

	for i in range(GRID_ROWS):
		for j in range(GRID_COLUMNS):
			if ismatched[i][j]:
				matched_cells_list.append(Vector2i(i, j))
				var idx = grid_i[i][j]
				if idx >= 0 and idx < piece.size() and piece[idx] != null:
					has_highlights = true
					var p = piece[idx]
					# Squash & Stretch (横につぶれてから弾む) ＋ 控えめな強調発光（眩しさを抑えチカチカを防止）
					p.scale = Vector2(cellsize.x * 1.25, cellsize.y * 0.85)
					p.modulate = Color(1.15, 1.15, 1.15, 1.0)
					tween.tween_property(p, "scale", cellsize * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tween.tween_property(p, "modulate", Color.WHITE, 0.14)

	if not matched_cells_list.is_empty():
		_spawn_combo_guide(matched_cells_list)

	if has_highlights:
			var _t_aw_tween_finished = Time.get_ticks_usec()
			await tween.finished
			if OS.is_debug_build(): print("[AWAIT] tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_tween_finished) / 1000.0))
	else:
		tween.kill()
	_start_breaking_animation()

## コンボ発生位置の周囲に案内役を円形に並べ、矢印でその駒を指差す演出
## 連鎖数（コンボ数）に応じて案内役の数が増える
func _spawn_combo_guide(matched_cells: Array) -> void:
	if matched_cells.is_empty():
		return
	var settings = get_node_or_null("/root/SettingsManager")
	if settings and "is_tutorial_mode" in settings and settings.is_tutorial_mode:
		return
	if _combo_guide_texture == null and ResourceLoader.exists("res://Texture/instructor.png"):
		_combo_guide_texture = load("res://Texture/instructor.png") as Texture2D
	if _combo_guide_texture == null:
		return

	if _active_combo_guide_tween != null and _active_combo_guide_tween.is_valid():
		_active_combo_guide_tween.kill()
	if _active_combo_guide_root != null and is_instance_valid(_active_combo_guide_root):
		_active_combo_guide_root.queue_free()
	_active_combo_guide_root = null

	# コンボの中心に最も近い駒を指差し対象にする
	var center = Vector2.ZERO
	for cell in matched_cells:
		center += Vector2(cell.x, cell.y)
	center /= float(matched_cells.size())
	var target_cell: Vector2i = matched_cells[0]
	var best_dist: float = INF
	for cell in matched_cells:
		var d: float = Vector2(cell.x, cell.y).distance_squared_to(center)
		if d < best_dist:
			best_dist = d
			target_cell = cell
	var target_pos = get_cell_position(target_cell.x, target_cell.y)

	var tex = _combo_guide_texture
	var guide_h: float = CELL_PITCH * 1.55
	var guide_scale: float = guide_h / float(tex.get_height())
	var guide_w: float = float(tex.get_width()) * guide_scale

	var score_mgr = _get_score_manager()
	var combo_num: int = int(score_mgr.combocount) if score_mgr and "combocount" in score_mgr else 1
	# 連鎖数と同じ人数の案内役を出す（描画負荷対策として上限あり）
	var guide_count: int = clampi(maxi(1, combo_num), 1, MAX_COMBO_GUIDES)

	var root = Node2D.new()
	root.name = "ComboGuide"
	root.z_index = 55
	root.modulate = Color(1, 1, 1, 0)
	Profiler.add_child_count += 1; _get_effects_parent().add_child(root)
	_active_combo_guide_root = root

	# 案内役同士が重ならないよう、人数に応じて円の半径を広げる
	var guide_dist: float = maxf(CELL_PITCH * 0.95, guide_w * float(guide_count) * 1.25 / TAU)
	# 円が盤面の外へはみ出しにくい開始角度を選ぶ
	var base_angle: float = 0.0
	if target_pos.x + guide_dist > BOARD_RIGHT - guide_w * 0.5:
		base_angle = PI

	var sprites: Array[Sprite2D] = []
	for i in range(guide_count):
		var angle: float = base_angle + TAU * float(i) / float(guide_count)
		var guide_pos: Vector2 = target_pos + Vector2(cos(angle), sin(angle)) * guide_dist
		guide_pos.x = clampf(guide_pos.x, BOARD_LEFT + guide_w * 0.5, BOARD_RIGHT - guide_w * 0.5)
		guide_pos.y = clampf(guide_pos.y, BOARD_TOP + guide_h * 0.5, BOARD_BOTTOM - guide_h * 0.5)

		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.position = guide_pos
		sprite.scale = Vector2(guide_scale, guide_scale) * 0.75
		sprite.flip_h = guide_pos.x > target_pos.x
		sprite.z_index = 1
		Profiler.add_child_count += 1; root.add_child(sprite)
		sprites.append(sprite)

		var to_target: Vector2 = target_pos - guide_pos
		var dist_to_target: float = to_target.length()
		var dir: Vector2 = to_target / maxf(dist_to_target, 0.001)
		if dist_to_target < 1.0:
			dir = Vector2(cos(angle + PI), sin(angle + PI))
		var start_offset: float = minf(guide_w * 0.42, dist_to_target * 0.30)
		var end_offset: float = minf(CELL_PITCH * 0.42, dist_to_target * 0.30)
		var arrow_start: Vector2 = guide_pos + dir * start_offset
		var arrow_end: Vector2 = target_pos - dir * end_offset
		var line = Line2D.new()
		line.points = PackedVector2Array([arrow_start, arrow_end])
		line.width = 18.0
		line.default_color = Color(1.0, 0.86, 0.22, 0.95)
		line.z_index = 2
		Profiler.add_child_count += 1; root.add_child(line)

		var perp = Vector2(-dir.y, dir.x)
		var head = Polygon2D.new()
		head.polygon = PackedVector2Array([
			arrow_end,
			arrow_end - dir * 70.0 + perp * 34.0,
			arrow_end - dir * 70.0 - perp * 34.0
		])
		head.color = line.default_color
		head.z_index = 2
		Profiler.add_child_count += 1; root.add_child(head)

	var combo_lbl = Label.new()
	combo_lbl.name = "ComboLabel"
	combo_lbl.text = "COMBO %d!" % maxi(1, combo_num)
	combo_lbl.position = Vector2(
		clampf(target_pos.x - 420.0, BOARD_LEFT + 10.0, BOARD_RIGHT - 850.0),
		clampf(target_pos.y - CELL_PITCH * 1.15, BOARD_TOP + 20.0, BOARD_BOTTOM - 140.0)
	)
	combo_lbl.size = Vector2(840.0, 100.0)
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_lbl.add_theme_font_override("font", _get_skill_ui_font())
	combo_lbl.add_theme_font_size_override("font_size", 54)
	combo_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.30))
	combo_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_lbl.add_theme_constant_override("outline_size", 10)
	combo_lbl.z_index = 3
	Profiler.add_child_count += 1; root.add_child(combo_lbl)
	combo_lbl.pivot_offset = combo_lbl.size / 2.0
	combo_lbl.scale = Vector2(0.65, 0.65)

	var tw = create_tween()
	_active_combo_guide_tween = tw
	tw.tween_property(root, "modulate:a", 1.0, 0.12)
	for s in sprites:
		tw.parallel().tween_property(s, "scale", Vector2(guide_scale, guide_scale), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(combo_lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.65)
	tw.tween_property(root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(root.queue_free)

## 帯電・呪い・聖像・氷・石・霧等のマッチ時波及効果を処理
func _apply_electrified_and_cursed_effects(cells_list: Array) -> void:
	var stage_mgr = _get_stage_manager()
	var sm = _get_score_manager()
	var stage_scale_b: float = pow(10.0, max(0, (stage_mgr.stage - 1) if stage_mgr else 0))
	for cell in cells_list:
		if grid_electrified.size() == GRID_ROWS and grid_electrified[cell.x][cell.y]:
			var was_ally_el = is_ally_electrified(cell.x, cell.y)
			grid_electrified[cell.x][cell.y] = false
			_set_ally_flag(grid_electrified_ally, cell.x, cell.y, false)
			if was_ally_el:
				if stage_mgr:
					var bonus_el_dmg = 220.0 * stage_scale_b
					stage_mgr.calchp(bonus_el_dmg, 0.0, stage_mgr.get_focused_enemy_index() if stage_mgr.has_method("get_focused_enemy_index") else -1)
					_emit_combat_event("damage", "ally", "enemy", bonus_el_dmg, "ally_electrified")
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "⚡ 充電追撃！", Color(0.35, 1.0, 0.85))
				if sm and sm.has_method("has_skill_trait") and (sm.has_skill_trait("thunder_1", "thunder_mid_b") or sm.has_skill_trait("thunder_1", "thunder_mid_c")):
					enemy_shock_stacks = mini(5, enemy_shock_stacks + 1)
					_spawn_floating_text(get_cell_position(cell.x, cell.y), "⚡ 感電スタック付与 (%d/5)！" % enemy_shock_stacks, Color(1.0, 0.9, 0.2))
					# ⚡ C1 解放: 5スタック到達時一斉解放大ダメージ
					if enemy_shock_stacks >= 5 and sm.has_skill_trait("thunder_1", "thunder_final_c1"):
						enemy_shock_stacks = 0
						var sk_lvl_th = maxi(1, sm.get_skill_level("thunder_1"))
						var discharge_dmg = (350.0 + sk_lvl_th * 75.0) * stage_scale_b
						if stage_mgr and stage_mgr.ehp > 0 and not stage_mgr.isdeadf:
							stage_mgr.calchp(discharge_dmg, 0.0)
							_emit_combat_event("damage", "ally", "enemy", discharge_dmg, "thunder_shock_discharge")
						_spawn_screen_flash(Color(1.0, 1.0, 0.4, 0.4), 0.25)
						_spawn_floating_text(Vector2(640, 360), "⚡ 感電5スタック解放！特大放電 -%d!" % int(discharge_dmg), Color(1.0, 0.95, 0.2))
			elif cells_cleared_by_special.has(cell):
				# 特殊アイテム・ボム爆発等による消去時はプレイヤーへの反動ダメージを安全に無効化（浄化・破壊）
				_spawn_shock_zap_effect(get_cell_position(cell.x, cell.y))
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "⚡ 帯電消滅！", Color(1.0, 0.95, 0.4))
			else:
				if stage_mgr:
					stage_mgr.last_damage_cause = "帯電マスの消去バックラッシュ"
					var shock_dmg = minf(stage_mgr.myhpmax * 0.08, 500.0) if stage_mgr.myhpmax > 0 else 500.0
					stage_mgr.calchp(0.0, shock_dmg)
					var rm_br = _get_relic_manager()
					if rm_br: rm_br.on_backlash_damage("electrified", shock_dmg)
					player_shock_stacks = mini(5, player_shock_stacks + 1)
					_spawn_floating_text(get_cell_position(cell.x, cell.y), "⚡ 感電スタック付与 (%d/5)！" % player_shock_stacks, Color(1.0, 0.4, 0.4))
					_spawn_status_damage_banner("⚡ 感電ダメージ -%d" % int(shock_dmg), Color(1.0, 0.85, 0.25))
					_trigger_screen_shake(10.0)
					if stage_mgr.myhp <= 0:
						_trigger_gameover(stage_mgr)
						return
				_spawn_shock_zap_effect(get_cell_position(cell.x, cell.y))

		if grid_cursed.size() == GRID_ROWS and grid_cursed[cell.x][cell.y]:
			var was_ally_cu = is_ally_cursed(cell.x, cell.y)
			grid_cursed[cell.x][cell.y] = false
			_set_ally_flag(grid_cursed_ally, cell.x, cell.y, false)
			if was_ally_cu:
				if stage_mgr:
					var drain_v = 150.0 * stage_scale_b
					stage_mgr.calchp(drain_v, -drain_v, stage_mgr.get_focused_enemy_index() if stage_mgr.has_method("get_focused_enemy_index") else -1)
					_emit_combat_event("damage", "ally", "enemy", drain_v, "ally_drain")
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "🌙 影護吸収！", Color(0.45, 1.0, 0.95))
			elif cells_cleared_by_special.has(cell):
				# 特殊アイテム・ボム爆発等による消去時は呪詛反動を安全に無効化
				_spawn_curse_burst_effect(get_cell_position(cell.x, cell.y))
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "🌙 呪い浄化！", Color(0.7, 0.9, 1.0))
			else:
				var st_idx = _get_stage_index()
				var curse_pct = 0.04 + st_idx * 0.01
				var curse_dmg = (minf(stage_mgr.myhpmax * curse_pct, 100.0 + st_idx * 100.0) if stage_mgr and stage_mgr.myhpmax > 0 else 50.0) * _get_difficulty_skill_mult()
				if stage_mgr:
					stage_mgr.last_damage_cause = "呪いマスの消去バックラッシュ"
					stage_mgr.calchp(0.0, curse_dmg)
					var rm_br = _get_relic_manager()
					if rm_br: rm_br.on_backlash_damage("cursed", curse_dmg)
					_spawn_status_damage_banner("🌙 呪詛反動 -%d" % int(curse_dmg), Color(0.9, 0.45, 1.0))
					if stage_mgr.myhp <= 0:
						_trigger_gameover(stage_mgr)
						return
				_spawn_curse_burst_effect(get_cell_position(cell.x, cell.y))
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "呪詛反動 -%d" % int(curse_dmg), Color(0.95, 0.2, 0.4))

		if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[cell.x][cell.y] > 0:
			var was_ally_g = is_ally_gold(cell.x, cell.y)
			grid_gold_statue[cell.x][cell.y] -= 1
			if grid_gold_statue[cell.x][cell.y] <= 0:
				grid_gold_statue[cell.x][cell.y] = 0
				_set_ally_flag(grid_gold_ally, cell.x, cell.y, false)
				var rm_h = _get_relic_manager()
				if rm_h: rm_h.on_hazard_destroyed("gold_statue", 1)
				_spawn_gold_shatter_effect(get_cell_position(cell.x, cell.y))
				var gold_reward = 1000 if (was_ally_g and has_actor_skill_trait(true, "light", "light_final_a1")) else 500
				_spawn_floating_text(get_cell_position(cell.x, cell.y), ("聖像解放！+%dG" % gold_reward) if was_ally_g else "黄金像粉砕！+500G", Color(1.0, 0.85, 0.2))
				if stage_mgr and "totalScore" in stage_mgr:
					stage_mgr.totalScore += gold_reward
				if sm and "totalScore" in sm:
					sm.totalScore += gold_reward
				if was_ally_g:
					var holy_dmg = 150.0 * stage_scale_b
					if has_actor_skill_trait(true, "light", "light_final_a1"):
						holy_dmg *= 2.5
						_spawn_floating_text(get_cell_position(cell.x, cell.y), "✨ 黄金郷・聖光超特大追撃！", Color(1.0, 0.95, 0.3))
					if stage_mgr and stage_mgr.has_method("calchp"):
						stage_mgr.calchp(holy_dmg, 0.0)
						_emit_combat_event("damage", "ally", "enemy", holy_dmg, "holy_statue_blast")
						var en_pos_blast = stage_mgr.enemy.position if (stage_mgr and stage_mgr.enemy) else Vector2(1550, 250)
						_spawn_statue_strike_effect(get_cell_position(cell.x, cell.y), en_pos_blast, holy_dmg)
					if has_actor_skill_trait(true, "light", "light_mid_c"):
						var resonance_shield2: float = 200.0 * stage_scale_b
						_apply_skill_shield(resonance_shield2)
						_spawn_floating_text(get_cell_position(cell.x, cell.y), "⚡ 共鳴の像・シールド+%d！" % int(resonance_shield2), Color(1.0, 0.9, 0.2))
					if has_actor_skill_trait(true, "light", "light_final_c1"):
						_spawn_floating_text(get_cell_position(cell.x, cell.y), "💥 起爆の像・聖光爆発！", Color(1.0, 0.9, 0.4))
						for dr in range(-1, 2):
							for dc in range(-1, 2):
								var br = cell.x + dr
								var bc = cell.y + dc
								if br >= 0 and br < GRID_ROWS and bc >= 0 and bc < GRID_COLUMNS:
									if grid_i[br][bc] != -1: ismatched[br][bc] = true
					if has_actor_skill_trait(true, "light", "light_final_c2"):
						pending_special_spawns[Vector2i(cell.x, cell.y)] = SpecialItemType.DISCO_BALL
						_spawn_floating_text(get_cell_position(cell.x, cell.y), "✨ 昇天の像・スターオーブ誕生！", Color(1.0, 0.8, 1.0))
			else:
				_spawn_gold_shatter_effect(get_cell_position(cell.x, cell.y))
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "耐久-1", Color(1.0, 0.85, 0.2))

	# 2. 隣接マッチによる氷割れ・石破壊・黄金像耐久減算・呪い浄化・黒い霧解除
	var adj_dirs = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var damaged_stones: Dictionary = {}
	for cell in matched_cells_list:
		# 炎上マス上で水コマ(POTION)が消去された場合、消火
		if grid_att.size() == GRID_ROWS and grid_att[cell.x][cell.y] == PieceType.POTION:
			if grid_fire.size() == GRID_ROWS and grid_fire[cell.x][cell.y] > 0:
				grid_fire[cell.x][cell.y] = 0
				_set_ally_flag(grid_fire_ally, cell.x, cell.y, false)
				_spawn_steam_effect(get_cell_position(cell.x, cell.y))
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "消火", Color(0.4, 0.8, 1.0))

		# 猛毒沼マス上でコマがマッチ消去された場合、毒マスは耐久値（段階）を1つ失う
		# 即解毒ではなく段階を減らすことで、毒マスが意味を持って盤面に残り続けるようにする
		if grid_poison.size() == GRID_ROWS and grid_poison[cell.x][cell.y] and not poison_mist_detonated_cells.has(cell):
			var was_ally_po = is_ally_poison(cell.x, cell.y)
			var cur_ps: int = 1
			if grid_poison_stage.size() == GRID_ROWS and cell.x < grid_poison_stage.size() and cell.y < grid_poison_stage[cell.x].size():
				cur_ps = maxi(1, int(grid_poison_stage[cell.x][cell.y]))
			if cur_ps > 1:
				grid_poison_stage[cell.x][cell.y] = cur_ps - 1
				_spawn_poison_bubble_burst_effect(get_cell_position(cell.x, cell.y))
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "🧪 毒耐久 -1（残り%d）" % (cur_ps - 1), Color(0.65, 1.0, 0.75))
			else:
				grid_poison[cell.x][cell.y] = false
				_set_ally_flag(grid_poison_ally, cell.x, cell.y, false)
				if was_ally_po and stage_mgr:
					var pb_dmg = 200.0 * stage_scale_b
					stage_mgr.calchp(pb_dmg, 0.0, stage_mgr.get_focused_enemy_index() if stage_mgr.has_method("get_focused_enemy_index") else -1)
					_emit_combat_event("damage", "ally", "enemy", pb_dmg, "ally_poison_blade")
					_spawn_floating_text(get_cell_position(cell.x, cell.y), "🧪 毒刃追撃！", Color(0.35, 1.0, 0.65))
				else:
					_spawn_floating_text(get_cell_position(cell.x, cell.y), "✨ 解毒！", Color(0.65, 1.0, 0.75))

		for d in adj_dirs:
			var ar = cell.x + d.x
			var ac = cell.y + d.y
			if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS:
				if grid_ice.size() == GRID_ROWS and int(grid_ice[ar][ac]) > 0:
					grid_ice[ar][ac] = int(grid_ice[ar][ac]) - 1
					if int(grid_ice[ar][ac]) <= 0:
						var rm_h = _get_relic_manager()
						if rm_h: rm_h.on_hazard_destroyed("ice", 1)
					_spawn_ice_break_effect(get_cell_position(ar, ac))
				if grid_stones.size() == GRID_ROWS and grid_stones[ar][ac] > 0:
					var stone_pos = Vector2i(ar, ac)
					if not damaged_stones.has(stone_pos):
						damaged_stones[stone_pos] = true
						_damage_stone_at(ar, ac, 1)
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[ar][ac] > 0:
					var was_ally_g = is_ally_gold(ar, ac)
					grid_gold_statue[ar][ac] -= 1
					if grid_gold_statue[ar][ac] <= 0:
						grid_gold_statue[ar][ac] = 0
						_set_ally_flag(grid_gold_ally, ar, ac, false)
						var rm_h = _get_relic_manager()
						if rm_h: rm_h.on_hazard_destroyed("gold_statue", 1)
						_spawn_gold_shatter_effect(get_cell_position(ar, ac))
						var gold_reward = 1000 if (was_ally_g and has_actor_skill_trait(true, "light", "light_final_a1")) else 500
						_spawn_floating_text(get_cell_position(ar, ac), ("聖像解放！+%dG" % gold_reward) if was_ally_g else "黄金像粉砕！+500G", Color(1.0, 0.85, 0.2))
						if sm and "totalScore" in sm:
							sm.totalScore += gold_reward
						if stage_mgr and "totalScore" in stage_mgr:
							stage_mgr.totalScore += gold_reward
						if was_ally_g:
							var holy_dmg = 150.0 * stage_scale_b
							if has_actor_skill_trait(true, "light", "light_final_a1"):
								holy_dmg *= 2.5
								_spawn_floating_text(get_cell_position(ar, ac), "✨ 黄金郷・聖光超特大追撃！", Color(1.0, 0.95, 0.3))
							if stage_mgr and stage_mgr.has_method("calchp"):
								stage_mgr.calchp(holy_dmg, 0.0)
								_emit_combat_event("damage", "ally", "enemy", holy_dmg, "holy_statue_blast")
								var en_pos_blast2 = stage_mgr.enemy.position if (stage_mgr and stage_mgr.enemy) else Vector2(1550, 250)
								_spawn_statue_strike_effect(get_cell_position(ar, ac), en_pos_blast2, holy_dmg)
							if has_actor_skill_trait(true, "light", "light_mid_c"):
								var resonance_shield: float = 200.0 * stage_scale_b
								_apply_skill_shield(resonance_shield)
								_spawn_floating_text(get_cell_position(ar, ac), "⚡ 共鳴の像・シールド+%d！" % int(resonance_shield), Color(1.0, 0.9, 0.2))
							if has_actor_skill_trait(true, "light", "light_final_c1"):
								_spawn_floating_text(get_cell_position(ar, ac), "💥 起爆の像・聖光爆発！", Color(1.0, 0.9, 0.4))
								for dr in range(-1, 2):
									for dc in range(-1, 2):
										var br = ar + dr
										var bc = ac + dc
										if br >= 0 and br < GRID_ROWS and bc >= 0 and bc < GRID_COLUMNS:
											if grid_i[br][bc] != -1: ismatched[br][bc] = true
							if has_actor_skill_trait(true, "light", "light_final_c2"):
								pending_special_spawns[Vector2i(ar, ac)] = SpecialItemType.DISCO_BALL
								_spawn_floating_text(get_cell_position(ar, ac), "✨ 昇天の像・スターオーブ誕生！", Color(1.0, 0.8, 1.0))
					else:
						_spawn_gold_shatter_effect(get_cell_position(ar, ac))
						_spawn_floating_text(get_cell_position(ar, ac), "耐久-1", Color(1.0, 0.85, 0.2))
				if grid_cursed.size() == GRID_ROWS and grid_cursed[ar][ac]:
					grid_cursed[ar][ac] = false
					_spawn_floating_text(get_cell_position(ar, ac), "✨ 呪い浄化！", Color(0.5, 1.0, 0.6))

		# 黒い霧内のマッチによる霧晴れ判定
		var f_idx = grid_fog.size() - 1
		while f_idx >= 0:
			var f_rect: Rect2i = grid_fog[f_idx].get("rect", Rect2i(-1, -1, 0, 0))
			if f_rect.has_point(cell):
				grid_fog[f_idx]["turns"] -= 1
				_spawn_floating_text(get_cell_position(cell.x, cell.y), "霧払い！", Color(0.7, 0.9, 1.0))
				if grid_fog[f_idx]["turns"] <= 0:
					grid_fog.remove_at(f_idx)
					_spawn_floating_text(get_cell_position(cell.x, cell.y), "暗雲消滅！", Color(0.6, 1.0, 0.8))
			f_idx -= 1

## マッチした駒の破砕バースト・フェード消滅演出（すべて消えるまで待機）
func _start_breaking_animation() -> void:
	current_state = BoardState.BREAKING

	# スコア計算（PvP前提：current_clear_source に応じて帰属を分岐）
	var sm = _get_score_manager()
	if sm and sm.has_method("calcscore"):
		sm.calcscore(ismatched, grid_att, grid_element, current_clear_source)

	# 画面微細シェイクを発生（適度な振動に抑える）
	if matched_cells_list.size() > 0:
		_trigger_screen_shake(10.0 + minf(float(matched_cells_list.size()) * 1.0, 15.0))
		player_skill_energy = minf(player_skill_max_energy, player_skill_energy + float(matched_cells_list.size()) * 5.0)
		_update_player_skill_ui()

	_apply_electrified_and_cursed_effects(matched_cells_list)

	var has_breaking: bool = false
	var tween = create_tween().set_parallel(true)

	for cell in matched_cells_list:
		var idx = grid_i[cell.x][cell.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			has_breaking = true
			var p = piece[idx]
			var kind = grid_n[cell.x][cell.y]

			# --- マッチ時進化効果群 ---
			var score_mgr_m = _get_score_manager()
			var sm_m = _get_stage_manager()
			var st_scale_m = pow(10, max(0, (sm_m.stage - 1) if sm_m else 0))

			# 💧 水マス上マッチ
			if grid_water.size() == GRID_ROWS and grid_water[cell.x][cell.y] and is_ally_water(cell.x, cell.y):
				if score_mgr_m and score_mgr_m.has_method("has_skill_trait"):
					var sk_lvl_w = maxi(1, score_mgr_m.get_skill_level("water_1"))
					if score_mgr_m.has_skill_trait("water_1", "water_final_a1"):
						# 💧 A1 癒しの雨: 即時HP回復
						var heal_amt = (30.0 + sk_lvl_w * 5.0) * st_scale_m
						if sm_m:
							sm_m.calchp(0.0, -heal_amt)
							_emit_combat_event("heal", "ally", "ally", heal_amt)
						_spawn_floating_text(p.position, "💧 癒しの雨 +%d!" % int(heal_amt), Color(0.3, 1.0, 0.6))
					elif score_mgr_m.has_skill_trait("water_1", "water_final_b1"):
						# 💧 B1 水鏡: 追加シールド
						var s_amt = (40.0 + sk_lvl_w * 8.0) * st_scale_m
						_apply_skill_shield(s_amt)
						_spawn_floating_text(p.position, "🛡️ 水鏡 +%d!" % int(s_amt), Color(0.4, 0.9, 1.0))
					elif score_mgr_m.has_skill_trait("water_1", "water_final_c1"):
						# 💧 C1 水撃: マッチ時に水撃スプラッシュダメージ
						var splash_dmg = (40.0 + sk_lvl_w * 10.0) * st_scale_m
						if sm_m and sm_m.ehp > 0 and not sm_m.isdeadf:
							sm_m.calchp(splash_dmg, 0.0)
							_emit_combat_event("damage", "ally", "enemy", splash_dmg, "water_splash")
						_spawn_floating_text(p.position, "💧 水撃 -%d!" % int(splash_dmg), Color(0.2, 0.7, 1.0))

			# ❄️ 氷マス上マッチ: 耐久値減算・砕氷・破砕起爆・霜の連鎖
			if grid_ice.size() == GRID_ROWS and int(grid_ice[cell.x][cell.y]) > 0:
				var score_mgr_ice = _get_score_manager()
				grid_ice[cell.x][cell.y] = maxi(0, int(grid_ice[cell.x][cell.y]) - 1)
				if grid_ice[cell.x][cell.y] == 0:
					_set_ally_flag(grid_ice_ally, cell.x, cell.y, false)
					if score_mgr_ice and score_mgr_ice.has_method("has_skill_trait"):
						if score_mgr_ice.has_skill_trait("ice_1", "ice_final_b1"):
							# B1 破砕起爆: 3x3破壊＆石破壊
							for dr in [-1, 0, 1]:
								for dc in [-1, 0, 1]:
									var nir = cell.x + dr; var nic = cell.y + dc
									if nir >= 0 and nir < GRID_ROWS and nic >= 0 and nic < GRID_COLUMNS:
										if grid_i.size() == GRID_ROWS and grid_i[nir][nic] != -1: ismatched[nir][nic] = true
										if grid_stones.size() == GRID_ROWS and grid_stones[nir][nic] > 0:
											_damage_stone_at(nir, nic, 2)
							_spawn_floating_text(p.position, "❄️ 破砕起爆！", Color(0.4, 0.9, 1.0))
						elif score_mgr_ice.has_skill_trait("ice_1", "ice_mid_b"):
							# B 砕氷: 隣接駒1個消去
							var cleared_adj = false
							for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
								if cleared_adj: break
								var ar = cell.x + offset.x; var ac = cell.y + offset.y
								if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS:
									if grid_i.size() == GRID_ROWS and grid_i[ar][ac] != -1 and not ismatched[ar][ac]:
										ismatched[ar][ac] = true
										cleared_adj = true
							_spawn_floating_text(p.position, "❄️ 砕氷！", Color(0.5, 0.9, 1.0))

						if score_mgr_ice.has_skill_trait("ice_1", "ice_final_b2"):
							# B2 霜の連鎖: 隣接2マスが新しい氷マスになる (初期耐久3)
							var created_cnt = 0
							for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
								if created_cnt >= 2: break
								var ar = cell.x + offset.x; var ac = cell.y + offset.y
								if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS:
									if int(grid_ice[ar][ac]) == 0 and not _is_plant_cell(ar, ac):
										grid_ice[ar][ac] = 3
										_set_ally_flag(grid_ice_ally, ar, ac, true)
										created_cnt += 1
							_spawn_floating_text(p.position, "❄️ 霜の連鎖！", Color(0.3, 0.85, 1.0))
				else:
					_spawn_floating_text(p.position, "❄️ 氷耐久 %d" % grid_ice[cell.x][cell.y], Color(0.6, 0.9, 1.0))

			# 🧪 毒マス上マッチ: 破裂・毒の種
			if grid_poison.size() == GRID_ROWS and grid_poison[cell.x][cell.y] and is_ally_poison(cell.x, cell.y):
				var score_mgr_poi = _get_score_manager()
				if score_mgr_poi and score_mgr_poi.has_method("has_skill_trait"):
					var p_st = grid_poison_stage[cell.x][cell.y] if (grid_poison_stage.size() == GRID_ROWS and cell.x < grid_poison_stage.size() and cell.y < grid_poison_stage[cell.x].size()) else 1
					if score_mgr_poi.has_skill_trait("poison_1", "poison_final_a1") and p_st >= 3:
						# A1 破裂: 第3段階の毒マスを消去すると周囲4マスに第1段階の毒を撒き散らす
						var scattered = 0
						for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
							var pr = cell.x + offset.x; var pc = cell.y + offset.y
							if pr >= 0 and pr < GRID_ROWS and pc >= 0 and pc < GRID_COLUMNS:
								if not grid_poison[pr][pc] and not _is_plant_cell(pr, pc):
									grid_poison[pr][pc] = true
									_set_ally_flag(grid_poison_ally, pr, pc, true)
									if grid_poison_stage.size() == GRID_ROWS:
										grid_poison_stage[pr][pc] = 1
									scattered += 1
									_spawn_poison_bubble_burst_effect(get_cell_position(pr, pc))
						_spawn_floating_text(p.position, "🧪 毒素破裂！周囲に毒撒き散らし(%d)！" % scattered, Color(0.6, 1.0, 0.4))
					if score_mgr_poi.has_skill_trait("poison_1", "poison_final_c2") and not poison_seed_used_this_turn:
						# C2 毒の種: 毒マス上でマッチすると毒スキルピース生成（ターン1回）
						poison_seed_used_this_turn = true
						grid_n[cell.x][cell.y] = PieceType.POTION
						grid_att[cell.x][cell.y] = PieceType.POTION % 5
						if p != null:
							p.texture = PIECE_TEXTURES[PieceType.POTION]
						_spawn_floating_text(p.position, "🧪 毒の種！スキルピース生成！", Color(0.2, 1.0, 0.8))

			# 🪨 地B: 鉱山 (石の隣でマッチするたびコイン+2枚)
			if score_mgr_m and score_mgr_m.has_method("has_skill_trait") and score_mgr_m.has_skill_trait("earth_1", "earth_mid_b"):
				for offset in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
					var ar = cell.x + offset.x; var ac = cell.y + offset.y
					if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS:
						if grid_stones.size() == GRID_ROWS and grid_stones[ar][ac] > 0 and is_ally_stone(ar, ac):
							if score_mgr_m and "divscore" in score_mgr_m:
								score_mgr_m.divscore[PieceType.COIN] = score_mgr_m.divscore.get(PieceType.COIN, 0) + 200 # +2コイン
							_spawn_floating_text(get_cell_position(cell.x, cell.y), "🪙 鉱山採掘 +2コイン！", Color(1.0, 0.85, 0.2))
							break

			# 🌱 木A: 共生 (植物の隣でマッチするたびに植物が1段階成長)
			if score_mgr_m and score_mgr_m.has_method("has_skill_trait") and score_mgr_m.has_skill_trait("wood_1", "wood_mid_a"):
				for plant in plant_entities:
					if not is_ally_plant(plant): continue
					var occ = _get_plant_occupied_cells(plant)
					var is_adj = false
					for occ_cell in occ:
						if abs(occ_cell.x - cell.x) + abs(occ_cell.y - cell.y) == 1:
							is_adj = true; break
					if is_adj:
						var cur_st = plant.get("stage", 0)
						if cur_st < 3:
							plant["stage"] = cur_st + 1
							_spawn_floating_text(get_cell_position(cell.x, cell.y), "🌱 共生成長！段階%d" % plant["stage"], Color(0.3, 1.0, 0.4))
							# A1 株分け: 成長段階が最大(3)に達した時、別の空きマスに苗木を1本植樹
							if plant["stage"] == 3 and score_mgr_m.has_skill_trait("wood_1", "wood_final_a1"):
								_plant_sprout_on_board()
								_spawn_floating_text(get_cell_position(cell.x, cell.y), "🌱 株分け！新苗木植樹！", Color(0.4, 1.0, 0.6))
							# C 実り: 成長段階3で隣の駒1個がポーション駒に変わる
							if plant["stage"] == 3 and score_mgr_m.has_skill_trait("wood_1", "wood_mid_c"):
								for p_occ in occ:
									for off in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
										var pr = p_occ.x + off.x; var pc = p_occ.y + off.y
										if pr >= 0 and pr < GRID_ROWS and pc >= 0 and pc < GRID_COLUMNS:
											if grid_i.size() == GRID_ROWS and grid_i[pr][pc] != -1 and grid_n[pr][pc] != PieceType.POTION:
												grid_n[pr][pc] = PieceType.POTION
												grid_att[pr][pc] = PieceType.POTION % 5
												var sp_idx = grid_i[pr][pc]
												if sp_idx < piece.size() and piece[sp_idx] != null:
													piece[sp_idx].texture = PIECE_TEXTURES[PieceType.POTION]
												_spawn_floating_text(get_cell_position(pr, pc), "🌱 実りポーション！", Color(0.2, 1.0, 0.5))
												break

			# ⚡ 雷B: 感電 (帯電コインをマッチ消去すると敵に感電スタック付与、最大5)
			if grid_electrified.size() == GRID_ROWS and grid_electrified[cell.x][cell.y] and is_ally_electrified(cell.x, cell.y):
				grid_electrified[cell.x][cell.y] = false
				_set_ally_flag(grid_electrified_ally, cell.x, cell.y, false)
				if score_mgr_m and score_mgr_m.has_method("has_skill_trait") and (score_mgr_m.has_skill_trait("thunder_1", "thunder_mid_b") or score_mgr_m.has_skill_trait("thunder_1", "thunder_mid_c")):
					enemy_shock_stacks = mini(5, enemy_shock_stacks + 1)
					_spawn_floating_text(p.position, "⚡ 感電スタック付与 (%d/5)！" % enemy_shock_stacks, Color(1.0, 0.9, 0.2))
					# ⚡ C1 解放: 5スタック到達時一斉解放大ダメージ
					if enemy_shock_stacks >= 5 and score_mgr_m.has_skill_trait("thunder_1", "thunder_final_c1"):
						enemy_shock_stacks = 0
						var sk_lvl_th = maxi(1, score_mgr_m.get_skill_level("thunder_1"))
						var discharge_dmg = (350.0 + sk_lvl_th * 75.0) * st_scale_m
						if sm_m and sm_m.ehp > 0 and not sm_m.isdeadf:
							sm_m.calchp(discharge_dmg, 0.0)
							_emit_combat_event("damage", "ally", "enemy", discharge_dmg, "thunder_shock_discharge")
						_spawn_screen_flash(Color(1.0, 1.0, 0.4, 0.4), 0.25)
						_spawn_floating_text(Vector2(640, 360), "⚡ 感電5スタック解放！特大放電 -%d!" % int(discharge_dmg), Color(1.0, 0.95, 0.2))

			# 🌪️ 風B2: 暴風圏 (竜巻が通った列でマッチするたび敵へダメージ)
			if storm_zones.get(cell.y, 0) > 0 and score_mgr_m and score_mgr_m.has_method("has_skill_trait") and score_mgr_m.has_skill_trait("wind_1", "wind_final_b2"):
				var sk_lvl_wi = maxi(1, score_mgr_m.get_skill_level("wind_1"))
				var st_dmg = (80.0 + sk_lvl_wi * 20.0) * st_scale_m
				if sm_m and sm_m.ehp > 0 and not sm_m.isdeadf:
					sm_m.calchp(st_dmg, 0.0)
					_emit_combat_event("damage", "ally", "enemy", st_dmg, "wind_storm_zone")
					_spawn_floating_text(p.position, "🌪️ 暴風圏追撃 -%d!" % int(st_dmg), Color(0.5, 0.9, 0.8))

			if pending_special_spawns.has(cell):
				# ピボットセル: 破壊消滅させず、特殊アイテムへの変身・残留アニメーション
				var sp_type = pending_special_spawns[cell]
				special_item[cell.x][cell.y] = sp_type
				if grid_skill_owner.size() == GRID_ROWS:
					grid_skill_owner[cell.x][cell.y] = pvp_my_player_index if pvp_mode else -1
				grid_n[cell.x][cell.y] = -1
				grid_att[cell.x][cell.y] = -1
				if grid_element.size() == GRID_ROWS:
					grid_element[cell.x][cell.y] = ElementDataScript.Element.NONE
				if is_bomb.size() == GRID_ROWS:
					is_bomb[cell.x][cell.y] = true
				if sp_type == SpecialItemType.CHARGE_BOMB:
					special_charge[cell.x][cell.y] = 1
				ismatched[cell.x][cell.y] = false
				p.texture = null

				# ポップ＆弾む変身アニメーション
				tween.tween_property(p, "scale", cellsize * 1.35, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.chain().tween_property(p, "scale", cellsize, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_spawn_floating_text(p.position, "SKILL CREATED!", Color(1.0, 0.9, 0.3))
				_spawn_special_sparkle_effect(p.position)
			else:
				# 放射状破片パーティクルを生成
				_spawn_burst_particles(p.position, kind)

				# コマ自体のポップ＆バースト消滅
				var rand_rot = randf_range(-0.4, 0.4)
				tween.tween_property(p, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tween.tween_property(p, "rotation", rand_rot, 0.18)
				tween.tween_property(p, "modulate:a", 0.0, 0.18)

			# 右側のステータス枠に向かって飛ぶエフェクト（確実に属性に対応したテクスチャを使用）
			var fly_sprite: Sprite2D = _get_sprite_from_pool()
			fly_sprite.texture = PIECE_TEXTURES[clampi(kind % 5, 0, 4)]
			fly_sprite.position = p.position
			fly_sprite.scale = cellsize
			fly_sprite.rotation = 0.0
			fly_sprite.modulate = Color.WHITE
			flying_cells.append({
				"node": fly_sprite,
				"kind": kind
			})

	# 「すべてが消えるまで待つ」
	if has_breaking:
		var _t_aw_tween_finished = Time.get_ticks_usec()
		await tween.finished
		if OS.is_debug_build(): print("[AWAIT] tween_finished took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_tween_finished) / 1000.0))
	else:
		tween.kill()

	# スプライトを破棄し、マスを空にする
	for cell in matched_cells_list:
		if pending_special_spawns.has(cell):
			# 生成されたスキルコマは破棄せずそのまま盤面に残留
			ismatched[cell.x][cell.y] = false
			continue

		var idx = grid_i[cell.x][cell.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			piece[idx].queue_free(); Profiler.queue_free_count += 1
			piece[idx] = null
		if idx >= 0 and idx < piececollid.size() and piececollid[idx] != null:
			piececollid[idx].queue_free(); Profiler.queue_free_count += 1
			piececollid[idx] = null
		grid_i[cell.x][cell.y] = -1
		grid_n[cell.x][cell.y] = -1
		grid_att[cell.x][cell.y] = -1
		ismatched[cell.x][cell.y] = false
		if is_bomb.size() == GRID_ROWS:
			is_bomb[cell.x][cell.y] = false
		if special_item.size() == GRID_ROWS:
			special_item[cell.x][cell.y] = SpecialItemType.NONE
		if special_charge.size() == GRID_ROWS:
			special_charge[cell.x][cell.y] = 0
		if grid_electrified.size() == GRID_ROWS:
			grid_electrified[cell.x][cell.y] = false
			_set_ally_flag(grid_electrified_ally, cell.x, cell.y, false)
		if grid_cursed.size() == GRID_ROWS:
			grid_cursed[cell.x][cell.y] = false
			_set_ally_flag(grid_cursed_ally, cell.x, cell.y, false)
		if grid_poison.size() == GRID_ROWS:
			if not poison_mist_detonated_cells.has(cell):
				grid_poison[cell.x][cell.y] = false
				_set_ally_flag(grid_poison_ally, cell.x, cell.y, false)
			else:
				grid_poison[cell.x][cell.y] = true
				_set_ally_flag(grid_poison_ally, cell.x, cell.y, true)

	# 全マスについて ismatched 残留を確実にクリア＆未回収の破砕マスを消去（I2対策）
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if ismatched[r][c]:
				if pending_special_spawns.has(Vector2i(r, c)):
					ismatched[r][c] = false
					continue
				var idx = grid_i[r][c]
				if idx >= 0 and idx < piece.size() and piece[idx] != null:
					piece[idx].queue_free(); Profiler.queue_free_count += 1
					piece[idx] = null
				if idx >= 0 and idx < piececollid.size() and piececollid[idx] != null:
					piececollid[idx].queue_free(); Profiler.queue_free_count += 1
					piececollid[idx] = null
				grid_i[r][c] = -1
				grid_n[r][c] = -1
				grid_att[r][c] = -1
				ismatched[r][c] = false
				if is_bomb.size() == GRID_ROWS:
					is_bomb[r][c] = false
				if special_item.size() == GRID_ROWS:
					special_item[r][c] = SpecialItemType.NONE
				if special_charge.size() == GRID_ROWS:
					special_charge[r][c] = 0

	pending_special_spawns.clear()
	poison_mist_detonated_cells.clear()
	_redraw_board_effects()
	_compact_piece_arrays()
	_start_continuous_falling()

## 空のシミュレーションセルを生成
func _make_empty_sim_cell(r: int, c: int) -> Dictionary:
	return {
		"p_idx": -1,
		"kind": -1,
		"att": -1,
		"sp_item": 0,
		"sp_charge": 0,
		"is_bomb": false,
		"is_water_locked": false,
		"is_locked": false,
		"is_obstacle": _is_plant_cell(r, c) or (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0 and not is_ally_stone(r, c)) or (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0 and not is_ally_gold(r, c)),
		"is_electrified": false,
		"is_electrified_ally": false,
		"is_cursed": false,
		"is_cursed_ally": false,
		"is_poison": false,
		"is_poison_ally": false,
		"fire": 0,
		"fire_ally": false,
		"is_tree": _is_plant_cell(r, c),
		"is_new": false,
		"horizontal_moved": false,
		"start_pos": Vector2.ZERO,
		"waypoints": []
	}

## 直上が遮蔽物（木・水固定・石・氷）で塞がれているか判定
func _is_drop_blocked_above(sim_grid: Array, r: int, c: int) -> bool:
	if r <= 0:
		return false
	if _is_plant_cell(r - 1, c) or sim_grid[r - 1][c].get("is_obstacle", false) or sim_grid[r - 1][c].get("is_locked", false):
		return true
	if sim_grid[r - 1][c].p_idx != -1 and not sim_grid[r - 1][c].get("is_locked", false) and not sim_grid[r - 1][c].get("is_obstacle", false):
		return false
	for up_r in range(r - 1, -1, -1):
		if _is_plant_cell(up_r, c) or sim_grid[up_r][c].get("is_obstacle", false) or sim_grid[up_r][c].get("is_locked", false):
			return true
		if sim_grid[up_r][c].p_idx != -1 and not sim_grid[up_r][c].get("is_locked", false) and not sim_grid[up_r][c].get("is_obstacle", false):
			return false
	return false

## 3x3大木などの平坦な遮蔽物の真下にあるか判定
func _is_under_flat_obstacle(sim_grid: Array, r: int, c: int) -> bool:
	if r <= 0:
		return false
	var above_blocked = _is_plant_cell(r - 1, c) or sim_grid[r - 1][c].get("is_obstacle", false)
	if not above_blocked:
		return false
	var left_blocked = (c - 1 < 0 or _is_plant_cell(r - 1, c - 1) or sim_grid[r - 1][c - 1].get("is_obstacle", false))
	var right_blocked = (c + 1 >= GRID_COLUMNS or _is_plant_cell(r - 1, c + 1) or sim_grid[r - 1][c + 1].get("is_obstacle", false))
	return left_blocked and right_blocked

## 遮蔽物（木・水固定駒・石・氷）を迂回する斜め落下カスケードの開始
func _start_continuous_falling() -> void:
	var _prof = Profiler.begin("puzzle_board::_start_continuous_falling")
	current_state = BoardState.FALLING
	falling_pieces.clear()

	var collid_template: Node = null
	var area_node = get_node_or_null("Area2D")
	if area_node and area_node.get_child_count() > 0:
		collid_template = area_node.get_child(0)

	# 1. シミュレーション用グリッドの構築
	var sim_grid: Array = []
	for r in range(GRID_ROWS):
		var row_sim: Array = []
		for c in range(GRID_COLUMNS):
			var p_idx: int = grid_i[r][c]
			var is_water: bool = (grid_water.size() == GRID_ROWS and grid_water[r][c] and not is_ally_water(r, c))
			var is_ice: bool = (grid_ice.size() == GRID_ROWS and grid_ice[r][c] and not is_ally_ice(r, c))
			var is_tree: bool = _is_plant_cell(r, c)
			var is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0 and not is_ally_stone(r, c))
			var is_gold_statue: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0 and not is_ally_gold(r, c))
			var is_electrified: bool = (grid_electrified.size() == GRID_ROWS and grid_electrified[r][c])
			var is_cursed: bool = (grid_cursed.size() == GRID_ROWS and grid_cursed[r][c])
			var is_poison: bool = (grid_poison.size() == GRID_ROWS and grid_poison[r][c])

			var is_locked: bool = (is_water and p_idx != -1) or (is_ice and p_idx != -1)
			var is_obstacle: bool = is_tree or is_stone or is_gold_statue

			row_sim.append({
				"p_idx": p_idx,
				"kind": (grid_n[r][c] if grid_n.size() == GRID_ROWS else 0) if p_idx != -1 else -1,
				"att": (grid_att[r][c] if grid_att.size() == GRID_ROWS else 0) if p_idx != -1 else -1,
					"element": grid_element[r][c] if grid_element.size() == GRID_ROWS and p_idx != -1 else ElementDataScript.Element.NONE,
				"sp_item": special_item[r][c] if special_item.size() == GRID_ROWS and p_idx != -1 else 0,
				"sp_charge": special_charge[r][c] if special_charge.size() == GRID_ROWS and p_idx != -1 else 0,
				"is_bomb": is_bomb[r][c] if is_bomb.size() == GRID_ROWS and p_idx != -1 else false,
				"is_water_locked": (is_water and p_idx != -1),
				"is_locked": is_locked,
				"is_obstacle": is_obstacle,
				"is_electrified": is_electrified,
				"is_electrified_ally": is_ally_electrified(r, c),
				"is_cursed": is_cursed,
				"is_cursed_ally": is_ally_cursed(r, c),
				"is_poison": is_poison,
				"is_poison_ally": is_ally_poison(r, c),
				"fire": (grid_fire[r][c] if grid_fire.size() == GRID_ROWS else 0),
				"fire_ally": is_ally_fire(r, c),
				"is_tree": is_tree,
				"is_new": false,
				"horizontal_moved": false,
				"start_pos": get_cell_position(r, c) if p_idx != -1 else Vector2.ZERO,
				"waypoints": []
			})
		sim_grid.append(row_sim)

	# 2. 落下・斜めスライド・上空スポーンのシミュレーション
	var spawn_counts_per_col: Array[int] = []
	spawn_counts_per_col.resize(GRID_COLUMNS)
	spawn_counts_per_col.fill(0)

	var newly_spawned_items: Array = []
	var max_sim_steps = 90

	for sim_step in range(max_sim_steps):
		var any_movement: bool = false

		# A. 直下落下 (Straight Fall Pass) - 下から上へ
		for r in range(GRID_ROWS - 2, -1, -1):
			for c in range(GRID_COLUMNS):
				var cell = sim_grid[r][c]
				if cell.p_idx != -1 and not cell.get("is_obstacle", false) and not cell.get("is_locked", false):
					var below = sim_grid[r + 1][c]
					if below.p_idx == -1 and not below.get("is_obstacle", false):
						if below.get("fire", 0) > 0 and cell.get("fire", 0) == 0:
							cell["fire"] = below["fire"]
							cell["fire_ally"] = below["fire_ally"]
						sim_grid[r + 1][c] = cell
						sim_grid[r][c] = _make_empty_sim_cell(r, c)
						any_movement = true

		# B. 上空からの新規生成 (Top Spawn Pass)
		for c in range(GRID_COLUMNS):
			var cell = sim_grid[0][c]
			if cell.p_idx == -1 and not cell.get("is_obstacle", false):
				var nval: int = _board_randi() % CELL_KINDS
				var spawned_sp: int = _roll_falling_special()
				var sp_ch: int = 1 if spawned_sp == SpecialItemType.CHARGE_BOMB else 0
				var is_b: bool = (spawned_sp != SpecialItemType.NONE)
				var spawn_count = spawn_counts_per_col[c]
				spawn_counts_per_col[c] += 1

				var init_fire = cell.get("fire", 0)
				var init_fire_ally = cell.get("fire_ally", false)

				var spawn_item = {
					"p_idx": -2, # 新規フラグ
					"kind": nval,
					"att": nval % 5,
					"element": ElementDataScript.Element.NONE,
					"sp_item": spawned_sp,
					"sp_charge": sp_ch,
					"is_bomb": is_b,
					"is_water_locked": false,
					"is_locked": false,
					"is_obstacle": false,
					"is_electrified": false,
					"is_cursed": false,
					"fire": init_fire,
					"fire_ally": init_fire_ally,
					"is_tree": false,
					"is_new": true,
					"horizontal_moved": false,
					"start_pos": Vector2(get_cell_position(0, c).x, get_cell_position(0, c).y - (spawn_count + 1) * CELL_PITCH),
					"waypoints": []
				}
				sim_grid[0][c] = spawn_item
				newly_spawned_items.append(spawn_item)
				any_movement = true

		# C. 直下が塞がれている場合の斜めスライド（遮蔽物の迂回）
		if not any_movement:
			for r in range(GRID_ROWS - 1, 0, -1):
				for c in range(GRID_COLUMNS):
					var target_cell = sim_grid[r][c]
					if target_cell.p_idx == -1 and not target_cell.get("is_obstacle", false):
						if _is_drop_blocked_above(sim_grid, r, c):
							# 左右の斜め上 (r-1, c-1), (r-1, c+1) からスライド
							var candidates: Array[int] = []
							for dc in [-1, 1]:
								var sc = c + dc
								if sc >= 0 and sc < GRID_COLUMNS:
									var src_cell = sim_grid[r - 1][sc]
									if src_cell.p_idx != -1 and not src_cell.get("is_obstacle", false) and not src_cell.get("is_locked", false):
										candidates.append(sc)

							if not candidates.is_empty():
								var chosen_sc = candidates[0]
								if candidates.size() > 1 and (r + c + sim_step) % 2 == 1:
									chosen_sc = candidates[1]

								var moving_cell = sim_grid[r - 1][chosen_sc]
								if target_cell.get("fire", 0) > 0 and moving_cell.get("fire", 0) == 0:
									moving_cell["fire"] = target_cell["fire"]
									moving_cell["fire_ally"] = target_cell["fire_ally"]
								moving_cell.waypoints.append(get_cell_position(r - 1, chosen_sc))
								moving_cell.waypoints.append(get_cell_position(r, c))

								sim_grid[r][c] = moving_cell
								sim_grid[r - 1][chosen_sc] = _make_empty_sim_cell(r - 1, chosen_sc)
								any_movement = true
								break

							elif _is_under_flat_obstacle(sim_grid, r, c):
								# 3x3大木の下など、横スライドによる充填（往復ループ完全防止：水平移動は1回のみ、逆流禁止）
								var h_cands: Array[int] = []
								for dc in [-1, 1]:
									var sc = c + dc
									if sc >= 0 and sc < GRID_COLUMNS:
										var src_cell = sim_grid[r][sc]
										if src_cell.p_idx != -1 and not src_cell.get("is_obstacle", false) and not src_cell.get("is_locked", false) and not src_cell.get("horizontal_moved", false):
											h_cands.append(sc)

								if not h_cands.is_empty():
									# 上方が開いている外側の列からの引き込みを優先
									var chosen_sc = h_cands[0]
									if h_cands.size() > 1:
										var sc0_blocked = _is_drop_blocked_above(sim_grid, r, h_cands[0])
										var sc1_blocked = _is_drop_blocked_above(sim_grid, r, h_cands[1])
										if sc0_blocked and not sc1_blocked:
											chosen_sc = h_cands[1]
										elif not sc0_blocked and sc1_blocked:
											chosen_sc = h_cands[0]
										elif (r + c + sim_step) % 2 == 1:
											chosen_sc = h_cands[1]

									var moving_cell = sim_grid[r][chosen_sc]
									if target_cell.get("fire", 0) > 0 and moving_cell.get("fire", 0) == 0:
										moving_cell["fire"] = target_cell["fire"]
										moving_cell["fire_ally"] = target_cell["fire_ally"]
									moving_cell["horizontal_moved"] = true
									moving_cell.waypoints.append(get_cell_position(r, chosen_sc))
									moving_cell.waypoints.append(get_cell_position(r, c))

									sim_grid[r][c] = moving_cell
									sim_grid[r][chosen_sc] = _make_empty_sim_cell(r, chosen_sc)
									any_movement = true
									break

		if not any_movement:
			break

	# 3. 新規スポーン駒の Sprite2D と CollisionShape の実体化
	for spawn_item in newly_spawned_items:
		var nval: int = spawn_item.kind
		var p_idx: int = piece.size()
		spawn_item.p_idx = p_idx

		var new_sprite: Sprite2D = Sprite2D.new()
		new_sprite.texture = PIECE_TEXTURES[nval]
		new_sprite.position = spawn_item.start_pos
		new_sprite.scale = cellsize
		new_sprite.modulate = Color.WHITE
		_add_element_mark_to_sprite(new_sprite)
		Profiler.add_child_count += 1; add_child(new_sprite)
		piece.append(new_sprite)

		piececollid.append(null)

	# 4. 盤面本番配列への確定反映 ＆ アニメーションリスト生成
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var final_cell = sim_grid[r][c]
			var is_obs = final_cell.is_tree
			if is_obs:
				if grid_i.size() == GRID_ROWS: grid_i[r][c] = -1
				if grid_n.size() == GRID_ROWS: grid_n[r][c] = -1
				if grid_att.size() == GRID_ROWS: grid_att[r][c] = -1
				if is_bomb.size() == GRID_ROWS: is_bomb[r][c] = false
				if special_item.size() == GRID_ROWS: special_item[r][c] = SpecialItemType.NONE
				if special_charge.size() == GRID_ROWS: special_charge[r][c] = 0
				if grid_electrified.size() == GRID_ROWS: grid_electrified[r][c] = false
				if grid_cursed.size() == GRID_ROWS: grid_cursed[r][c] = false
				if grid_poison.size() == GRID_ROWS: grid_poison[r][c] = false
				_set_ally_flag(grid_electrified_ally, r, c, false)
				_set_ally_flag(grid_cursed_ally, r, c, false)
				_set_ally_flag(grid_poison_ally, r, c, false)
				continue

			var p_idx: int = final_cell.p_idx
			if grid_i.size() == GRID_ROWS: grid_i[r][c] = p_idx
			if grid_n.size() == GRID_ROWS: grid_n[r][c] = final_cell.kind
			if grid_att.size() == GRID_ROWS: grid_att[r][c] = final_cell.att
			if grid_element.size() == GRID_ROWS: grid_element[r][c] = final_cell.get("element", ElementDataScript.Element.NONE)
			if is_bomb.size() == GRID_ROWS:
				is_bomb[r][c] = final_cell.is_bomb
			if special_item.size() == GRID_ROWS:
				special_item[r][c] = final_cell.sp_item
			if special_charge.size() == GRID_ROWS:
				special_charge[r][c] = final_cell.sp_charge
			if grid_electrified.size() == GRID_ROWS:
				grid_electrified[r][c] = final_cell.get("is_electrified", false)
				_set_ally_flag(grid_electrified_ally, r, c, final_cell.get("is_electrified_ally", false))
			if grid_cursed.size() == GRID_ROWS:
				grid_cursed[r][c] = final_cell.get("is_cursed", false)
				_set_ally_flag(grid_cursed_ally, r, c, final_cell.get("is_cursed_ally", false))
			if grid_poison.size() == GRID_ROWS:
				grid_poison[r][c] = final_cell.get("is_poison", false)
				_set_ally_flag(grid_poison_ally, r, c, final_cell.get("is_poison_ally", false))
			if grid_fire.size() == GRID_ROWS:
				grid_fire[r][c] = final_cell.get("fire", 0)
				_set_ally_flag(grid_fire_ally, r, c, final_cell.get("fire_ally", false))


			if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
				var sprite = piece[p_idx]
				var dest_pos = get_cell_position(r, c)
				var wps: Array = final_cell.waypoints

				if p_idx < piececollid.size() and piececollid[p_idx] != null:
					piececollid[p_idx].position = dest_pos

				var clean_wps: Array[Vector2] = []
				for wp in wps:
					if clean_wps.is_empty() or clean_wps[clean_wps.size() - 1].distance_to(wp) > 5.0:
						clean_wps.append(wp)
				if clean_wps.is_empty() or clean_wps[clean_wps.size() - 1].distance_to(dest_pos) > 5.0:
					clean_wps.append(dest_pos)

				var did_move = (final_cell.is_new or final_cell.start_pos.distance_to(dest_pos) > 5.0 or clean_wps.size() > 1)
				if did_move:
					falling_pieces.append({
						"sprite": sprite,
						"waypoints": clean_wps,
						"wp_idx": 0,
						"current_start_pos": sprite.position,
						"velocity_y": 0.0,
						"landed": false
					})
				else:
					sprite.position = dest_pos

	if falling_pieces.size() == 0:
		_ensure_board_pieces_consistency()
		_check_cascade()

## 落下中の重力・斜めスライド物理更新 (毎フレーム)
func _update_falling_physics(delta: float) -> void:
	var _prof = Profiler.begin("puzzle_board::_update_falling_physics")
	var all_landed: bool = true

	for item in falling_pieces:
		if item["landed"]:
			continue

		all_landed = false
		var s: Sprite2D = item["sprite"]
		var waypoints: Array[Vector2] = item["waypoints"]
		var wp_idx: int = item["wp_idx"]
		var target_pos: Vector2 = waypoints[wp_idx]

		# なめらかにターゲットへ向かって直進させる
		item["velocity_y"] = minf(item["velocity_y"] + GRAVITY * delta, MAX_FALL_SPEED)
		var current_speed = item["velocity_y"]
		
		var dist = s.position.distance_to(target_pos)
		var step = current_speed * delta

		if dist <= step:
			s.position = target_pos
			item["wp_idx"] += 1
			if item["wp_idx"] < waypoints.size():
				item["current_start_pos"] = target_pos
				# 曲がるときに速度を少し落とすとなめらかに見える
				item["velocity_y"] = maxf(8000.0, item["velocity_y"] * 0.8)
			else:
				item["landed"] = true
				var bounce_tween = create_tween()
				bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
				bounce_tween.tween_property(s, "scale", cellsize, 0.08)
		else:
			s.position = s.position.move_toward(target_pos, step)

	if all_landed:
		falling_pieces.clear()
		_ensure_board_pieces_consistency()
		_redraw_board_effects()
		_check_cascade()


## 落下後の連鎖判定
func _check_cascade() -> void:
	var _prof = Profiler.begin("puzzle_board::_check_cascade")
	current_state = BoardState.CASCADE_CHECK

	var has_match = _check_matches_exist()
	if has_match:
		_detect_and_spawn_special_from_matches()
		_start_match_highlight()
	else:
		# 定常状態（マッチ連鎖終了）：定常状態レリック（共鳴の点火石）の起爆判定
		if not steady_spark_triggered_this_turn:
			steady_spark_triggered_this_turn = true
			var rm = _get_relic_manager()
			if rm and rm.trigger_steady_state_relics(self):
				return
		# 盤面が安定した際の毒侵攻フラグ管理（火・毒の侵攻は2ターンに1度、ターンリセット時に実行）
		poison_spread_done_this_turn = true

		# 盤面が安定したらターン演出へ（敵ターン中の落下ならプレイヤー攻撃ターンを誤開始しない）
		_ensure_board_pieces_consistency()
		if is_enemy_turn_in_progress:
			current_state = BoardState.IDLE
		else:
			current_state = BoardState.TURN_SEQUENCE
			endbreak = true
			interval = 0

## 共鳴の点火石レリック：定常状態突入時の自動起爆
func trigger_random_specials_for_spark(det_count: int) -> bool:
	if special_item.size() != GRID_ROWS:
		return false
	var specials: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_i[r][c] != -1:
				var sp = special_item[r][c]
				var b = is_bomb[r][c] if is_bomb.size() == GRID_ROWS else false
				if sp != SpecialItemType.NONE or b:
					specials.append(Vector2i(r, c))
	if specials.is_empty():
		return false
	specials.shuffle()
	var to_detonate: Array = []
	for i in range(mini(det_count, specials.size())):
		var pos = specials[i]
		to_detonate.append(pos)
		_spawn_floating_text(get_cell_position(pos.x, pos.y), "共鳴起爆！", Color(1.0, 0.65, 0.15))
	_detonate_specials(to_detonate)
	_start_match_highlight()
	return true

## 暴食の聖杯レリック：毎ターン開始時の障害物（石・氷・呪い）生成
func spawn_random_hazard_for_curse() -> void:
	if grid_i.size() != GRID_ROWS:
		return
	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_i[r][c] != -1 and not _is_plant_cell(r, c):
				var has_stone = (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0)
				var has_ice = (grid_ice.size() == GRID_ROWS and grid_ice[r][c] > 0)
				var has_statue = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0)
				if not has_stone and not has_ice and not has_statue:
					cands.append(Vector2i(r, c))
	if cands.is_empty():
		return
	cands.shuffle()
	var p = cands[0]
	var r_type = randi() % 3
	if r_type == 0 and grid_stones.size() == GRID_ROWS:
		grid_stones[p.x][p.y] = 2
		_spawn_floating_text(get_cell_position(p.x, p.y), "呪石", Color(0.6, 0.4, 0.7))
		_spawn_stone_break_effect(get_cell_position(p.x, p.y))
	elif r_type == 1 and grid_ice.size() == GRID_ROWS:
		grid_ice[p.x][p.y] = 2
		_spawn_floating_text(get_cell_position(p.x, p.y), "呪氷", Color(0.4, 0.7, 0.9))
		_spawn_ice_break_effect(get_cell_position(p.x, p.y))
	else:
		if grid_cursed.size() == GRID_ROWS:
			grid_cursed[p.x][p.y] = true
			_spawn_floating_text(get_cell_position(p.x, p.y), "呪禍", Color(0.8, 0.2, 0.4))
			_spawn_curse_burst_effect(get_cell_position(p.x, p.y))
	_redraw_board_effects()

## スキルコマ生成時のキラキラ輝き演出
func _spawn_special_sparkle_effect(pos: Vector2) -> void:
	var effects_parent = get_node_or_null("Effects")
	if not effects_parent: effects_parent = self
	var p = CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.4
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 280.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 14.0
	p.color = Color(1.2, 1.1, 0.4, 1.0)
	effects_parent.add_child(p)
	if get_tree():
		get_tree().create_timer(0.45).timeout.connect(p.queue_free)
	else:
		p.queue_free()
	var se2 = get_node_or_null("AudioStreamPlayer2")
	if se2:
		se2.pitch_scale = 1.4
		se2.play()

## piece 配列の null 詰め
func _compact_piece_arrays() -> void:
	var remaining_pieces: Array = []
	var remaining_collids: Array = []
	var old_to_new: Dictionary = {}

	for idx in range(piece.size()):
		if piece[idx] != null:
			old_to_new[idx] = remaining_pieces.size()
			remaining_pieces.append(piece[idx])
			if idx < piececollid.size() and piececollid[idx] != null:
				remaining_collids.append(piececollid[idx])
			else:
				remaining_collids.append(null)

	for i in range(GRID_ROWS):
		for j in range(GRID_COLUMNS):
			if grid_i[i][j] != -1:
				if grid_i[i][j] in old_to_new:
					grid_i[i][j] = old_to_new[grid_i[i][j]]
				else:
					grid_i[i][j] = -1

	piece = remaining_pieces
	piececollid = remaining_collids

## 盤面論理グリッドと駒スプライトの1:1整合性保証（駒の重複・残留・位置ズレの解消 I2対策）
func _ensure_board_pieces_consistency() -> void:
	if grid_i.size() != GRID_ROWS or grid_n.size() != GRID_ROWS:
		return

	# 1. grid_i の重複参照チェック＆無効インデックスのクリア
	var seen_indices: Dictionary = {}
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var idx = grid_i[r][c]
			if idx != -1:
				if idx < 0 or idx >= piece.size() or piece[idx] == null:
					grid_i[r][c] = -1
				elif seen_indices.has(idx):
					# 重複参照を解消：新しいスプライトを生成して割り当てる
					var kind = grid_n[r][c]
					if kind >= 0 and kind < PIECE_TEXTURES.size():
						var new_sp = Sprite2D.new()
						new_sp.texture = PIECE_TEXTURES[kind]
						new_sp.position = get_cell_position(r, c)
						new_sp.scale = cellsize
						new_sp.modulate = Color.WHITE
						_add_element_mark_to_sprite(new_sp)
						Profiler.add_child_count += 1; add_child(new_sp)
						piece.append(new_sp)
						piececollid.append(null)
						grid_i[r][c] = piece.size() - 1
						seen_indices[grid_i[r][c]] = Vector2i(r, c)
					else:
						grid_i[r][c] = -1
				else:
					seen_indices[idx] = Vector2i(r, c)

	# 2. piece 配列内の浮遊スプライト（どのマスにも所属していないスプライト）の回収
	var has_orphans: bool = false
	for p_idx in range(piece.size()):
		if piece[p_idx] != null and not seen_indices.has(p_idx):
			piece[p_idx].queue_free(); Profiler.queue_free_count += 1
			piece[p_idx] = null
			if p_idx < piececollid.size() and piececollid[p_idx] != null:
				piececollid[p_idx].queue_free(); Profiler.queue_free_count += 1
				piececollid[p_idx] = null
			has_orphans = true

	if has_orphans:
		_compact_piece_arrays()

	# 3. 各マスのスプライト位置とテクスチャ、状態フラグの同期
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var idx = grid_i[r][c]
			if idx != -1 and idx < piece.size() and piece[idx] != null:
				var target_pos = get_cell_position(r, c)
				var is_currently_falling = false
				for fp in falling_pieces:
					if fp.get("sprite") == piece[idx] and not fp.get("landed", false):
						is_currently_falling = true
						break
				if not is_currently_falling:
					piece[idx].position = target_pos
					piece[idx].visible = true
					if idx < piececollid.size() and piececollid[idx] != null:
						piececollid[idx].position = target_pos
				var sp = special_item[r][c] if special_item.size() == GRID_ROWS else SpecialItemType.NONE
				if sp == SpecialItemType.NONE:
					var kind = grid_n[r][c]
					if kind >= 0 and kind < PIECE_TEXTURES.size():
						piece[idx].texture = PIECE_TEXTURES[kind]
			else:
				if not _is_plant_cell(r, c):
					grid_n[r][c] = -1

# --- 戦闘・エフェクト処理群 (バグ修正済み) ---

func _process(delta: float) -> void:
	var _prof = Profiler.begin("puzzle_board::_process")
	Profiler.tick(delta)
	if delta > 0.03:
		var sp_cnt = 0
		for child in get_children():
			if child is Sprite2D: sp_cnt += 1
		var st_str = str(current_state)
		if "BoardState" in self and current_state >= 0 and current_state < BoardState.size():
			st_str = BoardState.keys()[current_state]
		if OS.is_debug_build(): print("[SLOW FRAME] delta: %.1fms | State: %s | Add: %d | Free: %d | Falling: %d | Sprites: %d" % [
			delta * 1000.0, st_str, Profiler.add_child_count, Profiler.queue_free_count, falling_pieces.size(), sp_cnt
		])
	var sm = _get_stage_manager()
	var score_mgr = _get_score_manager()

	# ゲームオーバー時の更新処理（最優先で実行し、盤面処理をスキップ）
	if sm and not isgameover and sm.myhpmax > 0.0 and sm.myhp <= 0.0:
		_trigger_gameover(sm)

	if isgameover:
		# PvPではオフラインのゲームオーバー演出を行わず、PvPの勝敗表示に任せる
		if not pvp_mode:
			_handle_gameover_sequence(sm)
		return

	# 落下アニメーション中の物理更新
	if current_state == BoardState.FALLING:
		_update_falling_physics(delta)

	# マウス操作中の追従および移動方向強調のリアルタイム更新
	if selected_cell.x != -1 and current_state == BoardState.IDLE:
		var local_mouse = _get_mouse_local()
		_current_local_mouse = local_mouse
		if is_holding and selected_piece_idx >= 0 and selected_piece_idx < piece.size() and piece[selected_piece_idx] != null:
			var clamped_mouse = local_mouse + drag_offset
			clamped_mouse.x = clampf(clamped_mouse.x, BOARD_LEFT, BOARD_RIGHT)
			clamped_mouse.y = clampf(clamped_mouse.y, BOARD_TOP, BOARD_BOTTOM)
			piece[selected_piece_idx].position = clamped_mouse
		_update_hovered_swap_direction(local_mouse)
		if swap_guide_overlay:
			swap_guide_overlay.queue_redraw()
	else:
		if hovered_swap_cell.x != -1:
			hovered_swap_cell = Vector2i(-1, -1)
			if swap_guide_overlay:
				swap_guide_overlay.queue_redraw()

	if tutorial_allowed_swap.size() == 2 and swap_guide_overlay:
		swap_guide_overlay.queue_redraw()

	# 戦闘演出ターンおよび発射物シミュレーションのゲーム速度連動
	var spd: float = maxf(0.1, _get_game_speed())
	if _sword_hit_sound_timer > 0.0:
		_sword_hit_sound_timer = maxf(0.0, _sword_hit_sound_timer - delta * spd)

	# 放置デモ再生中は自動で駒を入れ替えて盤面を進める
	var sm_demo = _get_settings_manager()
	var is_demo: bool = sm_demo != null and "demo_mode" in sm_demo and bool(sm_demo.demo_mode)
	if is_demo and current_state == BoardState.IDLE and not is_enemy_turn_in_progress and not isgameover:
		_demo_idle_timer += delta
		if _demo_idle_timer >= 1.2:
			_demo_idle_timer = 0.0
			_demo_auto_swap()
	else:
		_demo_idle_timer = 0.0

	_turn_sim_accumulator += spd * minf(2.5, delta * 60.0)
	var sim_steps: int = 0
	while _turn_sim_accumulator >= 1.0 and sim_steps < 16:
		_turn_sim_accumulator -= 1.0
		sim_steps += 1

		# ステージクリア時または敵死亡時の演出停止
		# ※落下中・消去中・連鎖判定中・入替中は盤面演出を中断せず、定常状態に落ち着くまで物理・連鎖を完了させる
		if sm and (sm.isstageclear or sm.isdeadf):
			if current_state == BoardState.TURN_SEQUENCE or current_state == BoardState.IDLE:
				_clear_all_combat_projectiles()
				isattack = 0
				isblock = 0
				has_enemy_attacked = false
				isswap = false
				endbreak = false
				isbreak = false
				interval = 0
				current_state = BoardState.IDLE
				if score_mgr: score_mgr.combocount = 0
				var rensa_se = get_node_or_null("1rensa")
				if rensa_se:
					rensa_se.pitch_scale = 0.92 * spd
				_restore_score_label_positions()
				continue

		# 戦闘演出ターンの処理
		if current_state == BoardState.TURN_SEQUENCE and flying_cells.size() == 0:
			_handle_turn_sequence(sm, score_mgr)

		_update_all_projectiles()

	if sim_steps >= 16:
		_turn_sim_accumulator = 0.0

	# 敵の色戻し
	if flying_swords.size() == 0 and sm and sm.enemy != null and msisvalid:
		sm.enemy.modulate.r = encolor
		msisvalid = false

	# 特殊アイテム演出（特殊アイテムが無い時はこのブロック全体をスキップ）
	if has_special_items:
		_special_fx_elapsed += delta
		var fx_tick: bool = _special_fx_elapsed >= SPECIAL_FX_UPDATE_INTERVAL
		if fx_tick:
			_special_fx_elapsed = fmod(_special_fx_elapsed, SPECIAL_FX_UPDATE_INTERVAL)

		# マークは駒の現在位置に描かれるため、駒が動く状態（IDLE以外：入替・落下・消去演出等）では毎フレーム追従。
		# 静止中（IDLE、ドラッグ中含む※特殊アイテムはドラッグ不可）は脈動更新の間隔でのみ再描画。
		if mark_overlay and (fx_tick or current_state != BoardState.IDLE):
			mark_overlay.queue_redraw()

		# 特殊アイテムマスの点滅・脈動演出（時間ベースなので間引いても点滅速度は不変）
		if fx_tick and not special_item_coords.is_empty():
			var time_pulse = 0.80 + 0.30 * sin(Time.get_ticks_msec() * 0.008)
			for coord in special_item_coords:
				var r = coord.x
				var c = coord.y
				var p_idx = grid_i[r][c]
				if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
					var sp_type = special_item[r][c] if special_item.size() == GRID_ROWS else SpecialItemType.NONE
					var is_b = is_bomb[r][c] if is_bomb.size() == GRID_ROWS else false

					if sp_type != SpecialItemType.NONE or is_b:
						var glow_color = Color(1.8, 0.4, 0.2, 1.0) # デフォルト爆弾
						match sp_type:
							SpecialItemType.CROSS_BOMB: glow_color = Color(0.2, 1.4, 1.8, 1.0)
							SpecialItemType.DISCO_BALL: glow_color = Color(1.8, 0.3, 1.8, 1.0)
							SpecialItemType.COLOR_CONVERTER: glow_color = Color(0.2, 1.8, 0.6, 1.0)
							SpecialItemType.LIGHTNING: glow_color = Color(1.8, 1.8, 0.2, 1.0)
							SpecialItemType.BLACK_HOLE: glow_color = Color(0.8, 0.2, 1.8, 1.0)
							SpecialItemType.HOLY_LIGHT: glow_color = Color(2.0, 1.9, 0.8, 1.0)
							SpecialItemType.CHARGE_BOMB: glow_color = Color(2.0, 0.3, 0.1, 1.0)
							SpecialItemType.GEMINI_BOMB: glow_color = Color(1.8, 0.8, 0.2, 1.0)
							SpecialItemType.ICE_SHIELD: glow_color = Color(0.2, 1.4, 2.0, 1.0)
							SpecialItemType.POISON_MIST: glow_color = Color(0.2, 1.8, 0.5, 1.0)
						piece[p_idx].modulate = glow_color * time_pulse

class SpecialMarkOverlayNode extends Node2D:
	var board: Node2D = null

	func _draw() -> void:
		var _prof = Profiler.begin("puzzle_board::_draw")
		if board != null and is_instance_valid(board):
			board._draw_special_item_marks_on_overlay(self)

## 特殊アイテムのシンプルシンボルマーク（雷マーク⚡・爆弾マーク💣・苗木マーク🌱等）の一括描画
func _draw_special_item_marks_on_overlay(overlay: Node2D) -> void:
	if overlay == null or grid_i.size() != GRID_ROWS:
		return

	var time_pulse = 0.95 + 0.05 * sin(Time.get_ticks_msec() * 0.007)

	for coord in special_item_coords:
		var r = coord.x
		var c = coord.y
		var sp_type = special_item[r][c] if special_item.size() == GRID_ROWS else SpecialItemType.NONE
		var is_b = is_bomb[r][c] if is_bomb.size() == GRID_ROWS else false
		if sp_type == SpecialItemType.NONE and is_b:
			sp_type = SpecialItemType.BOMB

		if sp_type == SpecialItemType.NONE:
			continue

		var p_idx = grid_i[r][c]
		if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
			var p = piece[p_idx]
			var center = p.position
			var s_factor = (p.scale.x / cellsize.x) if cellsize.x > 0 else 1.0
			if s_factor <= 0.05:
				continue
			var alpha = p.modulate.a
			_draw_single_special_mark(overlay, center, sp_type, s_factor * time_pulse * 2.2, alpha, r, c)

## 特殊アイテム駒に対応する属性の、現在選択中の進化アイコンを返す。
func _get_special_item_icon_texture(sp_type: int) -> Texture2D:
	var element: String = str(SPECIAL_ITEM_ELEMENT.get(sp_type, ""))
	if element.is_empty():
		return null
	var score_mgr = _get_score_manager()
	if score_mgr == null or not score_mgr.has_method("get_skill_display_icon_path"):
		return null
	var icon_path: String = score_mgr.get_skill_display_icon_path(element + "_1")
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	if _special_icon_cache.has(icon_path):
		return _special_icon_cache[icon_path] as Texture2D
	var tex = load(icon_path) as Texture2D
	_special_icon_cache[icon_path] = tex
	return tex

## 個別のシンプルシンボルマーク描画（複雑にせず単純で直感的にわかりやすい幾何学マーク）
func _draw_single_special_mark(overlay: Node2D, center: Vector2, sp_type: int, s: float, alpha: float, r: int, c: int) -> void:
	if overlay == null or s <= 0.05 or alpha <= 0.01:
		return

	var badge_r: float = 95.0 * s

	# 1. 視認性を保証する背面の半透明ダークサークルプレート
	overlay.draw_circle(center, badge_r + 16.0 * s, Color(0.05, 0.07, 0.12, 0.90 * alpha))
	overlay.draw_circle(center, badge_r, Color(0.08, 0.10, 0.16, 0.95 * alpha))

	# 属性と現在の進化に対応するアイコンがあれば、それを駒の中央に描画する
	var icon_tex = _get_special_item_icon_texture(sp_type)
	if icon_tex != null:
		var icon_size: float = badge_r * 1.62
		var icon_rect = Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
		overlay.draw_texture_rect(icon_tex, icon_rect, false, Color(1, 1, 1, alpha))
		return

	match sp_type:
		SpecialItemType.LIGHTNING: # 5: 雷（⚡黄色ジグザグ稲妻マーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(1.0, 0.92, 0.12, alpha), 9.0 * s)
			var bolt = PackedVector2Array([
				center + Vector2(10.0, -60.0) * s,
				center + Vector2(-30.0, -2.0) * s,
				center + Vector2(4.0, -2.0) * s,
				center + Vector2(-14.0, 60.0) * s,
				center + Vector2(30.0, 6.0) * s,
				center + Vector2(2.0, 6.0) * s
			])
			overlay.draw_colored_polygon(bolt, Color(1.0, 0.94, 0.12, alpha))
			var bolt_outline = bolt.duplicate()
			bolt_outline.append(bolt[0])
			overlay.draw_polyline(bolt_outline, Color(0.12, 0.1, 0.02, 0.9 * alpha), 6.0 * s)
			var inner_bolt = PackedVector2Array([
				center + Vector2(4.0, -44.0) * s,
				center + Vector2(-14.0, -2.0) * s,
				center + Vector2(2.0, -2.0) * s,
				center + Vector2(-6.0, 44.0) * s
			])
			overlay.draw_polyline(inner_bolt, Color(1.0, 1.0, 0.85, 0.95 * alpha), 4.0 * s)

		SpecialItemType.BOMB: # 1: フレイムボム（💣導火線付き黒丸爆弾マーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(1.0, 0.38, 0.1, alpha), 9.0 * s)
			var b_c = center + Vector2(0.0, 10.0) * s
			overlay.draw_circle(b_c, 44.0 * s, Color(0.18, 0.18, 0.22, alpha))
			overlay.draw_arc(b_c + Vector2(-10, -8) * s, 22.0 * s, PI * 0.9, PI * 1.45, 12, Color(1, 1, 1, 0.6 * alpha), 5.0 * s)
			overlay.draw_rect(Rect2(center.x - 12.0 * s, center.y - 40.0 * s, 24.0 * s, 12.0 * s), Color(0.5, 0.5, 0.55, alpha))
			var fuse_pts = PackedVector2Array([
				center + Vector2(0.0, -38.0) * s,
				center + Vector2(16.0, -50.0) * s,
				center + Vector2(24.0, -60.0) * s
			])
			overlay.draw_polyline(fuse_pts, Color(0.85, 0.75, 0.55, alpha), 5.0 * s)
			var sp_pt = center + Vector2(26.0, -62.0) * s
			overlay.draw_circle(sp_pt, 8.0 * s, Color(1.0, 0.85, 0.1, alpha))
			overlay.draw_line(sp_pt - Vector2(12, 0) * s, sp_pt + Vector2(12, 0) * s, Color(1.0, 0.4, 0.1, alpha), 4.0 * s)
			overlay.draw_line(sp_pt - Vector2(0, 12) * s, sp_pt + Vector2(0, 12) * s, Color(1.0, 0.4, 0.1, alpha), 4.0 * s)

		SpecialItemType.CROSS_BOMB: # 2: クロスブレイズ（✚ネオン十字マーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.1, 0.95, 1.0, alpha), 9.0 * s)
			var b_len = 52.0 * s
			var b_w = 22.0 * s
			overlay.draw_line(center - Vector2(b_len, 0), center + Vector2(b_len, 0), Color(0.05, 0.1, 0.15, alpha), b_w + 6.0 * s)
			overlay.draw_line(center - Vector2(b_len, 0), center + Vector2(b_len, 0), Color(0.1, 0.92, 1.0, alpha), b_w)
			overlay.draw_line(center - Vector2(b_len, 0), center + Vector2(b_len, 0), Color.WHITE, b_w * 0.45)
			overlay.draw_line(center - Vector2(0, b_len), center + Vector2(0, b_len), Color(0.05, 0.1, 0.15, alpha), b_w + 6.0 * s)
			overlay.draw_line(center - Vector2(0, b_len), center + Vector2(0, b_len), Color(0.1, 0.92, 1.0, alpha), b_w)
			overlay.draw_line(center - Vector2(0, b_len), center + Vector2(0, b_len), Color.WHITE, b_w * 0.45)
			overlay.draw_circle(center, 12.0 * s, Color.WHITE)

		SpecialItemType.TORNADO: # 7: 竜巻/つむじ風（🌀渦巻きスパイラルマーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.2, 1.0, 0.8, alpha), 9.0 * s)
			overlay.draw_arc(center + Vector2(0, -22.0) * s, 36.0 * s, PI * 0.1, PI * 1.25, 16, Color(0.2, 1.0, 0.8, alpha), 8.0 * s)
			overlay.draw_arc(center, 24.0 * s, PI * 0.6, PI * 1.85, 14, Color(0.55, 1.0, 0.9, alpha), 7.0 * s)
			overlay.draw_arc(center + Vector2(0, 20.0) * s, 14.0 * s, PI * 1.1, PI * 2.35, 12, Color(0.85, 1.0, 0.95, alpha), 6.0 * s)
			overlay.draw_circle(center + Vector2(4, 30.0) * s, 5.0 * s, Color.WHITE)

		SpecialItemType.AQUA_SPLASH: # 8: 水（💧水滴マーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.2, 0.75, 1.0, alpha), 9.0 * s)
			var drop_pts = PackedVector2Array([
				center + Vector2(0.0, -54.0) * s,
				center + Vector2(22.0, -20.0) * s,
				center + Vector2(34.0, 8.0) * s,
				center + Vector2(24.0, 36.0) * s,
				center + Vector2(0.0, 46.0) * s,
				center + Vector2(-24.0, 36.0) * s,
				center + Vector2(-34.0, 8.0) * s,
				center + Vector2(-22.0, -20.0) * s
			])
			overlay.draw_colored_polygon(drop_pts, Color(0.12, 0.65, 1.0, alpha))
			var drop_out = drop_pts.duplicate(); drop_out.append(drop_pts[0])
			overlay.draw_polyline(drop_out, Color(0.05, 0.25, 0.5, alpha), 4.0 * s)
			overlay.draw_arc(center + Vector2(-10.0, 8.0) * s, 16.0 * s, PI * 0.8, PI * 1.5, 10, Color(1, 1, 1, 0.75 * alpha), 5.0 * s)

		SpecialItemType.TREE_SPROUT: # 9: 生命の苗木（🌱双葉スプラウトマーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.3, 1.0, 0.4, alpha), 9.0 * s)
			var stem_pts = PackedVector2Array([
				center + Vector2(0.0, 44.0) * s,
				center + Vector2(0.0, 8.0) * s,
				center + Vector2(-2.0, -10.0) * s
			])
			overlay.draw_polyline(stem_pts, Color(0.4, 0.85, 0.3, alpha), 8.0 * s)
			var leaf_l = PackedVector2Array([
				center + Vector2(0.0, 0.0) * s,
				center + Vector2(-20.0, -12.0) * s,
				center + Vector2(-44.0, -16.0) * s,
				center + Vector2(-34.0, 4.0) * s,
				center + Vector2(-12.0, 8.0) * s
			])
			overlay.draw_colored_polygon(leaf_l, Color(0.28, 0.95, 0.38, alpha))
			var leaf_r = PackedVector2Array([
				center + Vector2(0.0, -4.0) * s,
				center + Vector2(20.0, -16.0) * s,
				center + Vector2(44.0, -20.0) * s,
				center + Vector2(34.0, 0.0) * s,
				center + Vector2(12.0, 4.0) * s
			])
			overlay.draw_colored_polygon(leaf_r, Color(0.42, 1.0, 0.52, alpha))

		SpecialItemType.DISCO_BALL: # 3: スターオーブ（⭐ゴールドスター星マーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(1.0, 0.85, 0.2, alpha), 9.0 * s)
			var star_pts: PackedVector2Array = []
			for k in range(10):
				var r_pt = (48.0 if (k % 2 == 0) else 22.0) * s
				var ang = k * PI / 5.0 - PI * 0.5
				star_pts.append(center + Vector2(cos(ang), sin(ang)) * r_pt)
			overlay.draw_colored_polygon(star_pts, Color(1.0, 0.88, 0.15, alpha))
			var star_out = star_pts.duplicate(); star_out.append(star_pts[0])
			overlay.draw_polyline(star_out, Color(0.5, 0.3, 0.05, alpha), 4.0 * s)
			overlay.draw_circle(center, 12.0 * s, Color.WHITE)

		SpecialItemType.BLACK_HOLE: # 6: ブラックホール（🕳漆黒特異点＆紫スパイラル）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.75, 0.2, 1.0, alpha), 9.0 * s)
			overlay.draw_circle(center, 38.0 * s, Color(0.04, 0.0, 0.08, alpha))
			overlay.draw_arc(center, 50.0 * s, 0, TAU, 28, Color(0.8, 0.2, 1.0, 0.85 * alpha), 7.0 * s)
			overlay.draw_arc(center, 32.0 * s, PI * 0.4, PI * 1.8, 20, Color(0.95, 0.5, 1.0, alpha), 5.0 * s)

		SpecialItemType.COLOR_CONVERTER: # 4: フローラスプレー（🎨赤・青・緑3色ドロップ）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.2, 1.0, 0.6, alpha), 9.0 * s)
			overlay.draw_circle(center + Vector2(-18, -14) * s, 16.0 * s, Color(1.0, 0.25, 0.3, alpha))
			overlay.draw_circle(center + Vector2(18, -14) * s, 16.0 * s, Color(0.2, 0.6, 1.0, alpha))
			overlay.draw_circle(center + Vector2(0, 20) * s, 16.0 * s, Color(0.2, 0.95, 0.4, alpha))

		SpecialItemType.HOLY_LIGHT: # 10: 聖光星・ホーリースター（✨ 黄金・聖光8方位星）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(1.0, 0.92, 0.35, alpha), 8.0 * s)
			var star_pts_v = PackedVector2Array([
				center + Vector2(0, -36) * s,
				center + Vector2(10, 0) * s,
				center + Vector2(0, 36) * s,
				center + Vector2(-10, 0) * s
			])
			var star_pts_h = PackedVector2Array([
				center + Vector2(-36, 0) * s,
				center + Vector2(0, 10) * s,
				center + Vector2(36, 0) * s,
				center + Vector2(0, -10) * s
			])
			overlay.draw_colored_polygon(star_pts_v, Color(1.0, 1.0, 0.9, alpha))
			overlay.draw_colored_polygon(star_pts_h, Color(1.0, 1.0, 0.9, alpha))
			var star_pts_d1 = PackedVector2Array([
				center + Vector2(-22, -22) * s,
				center + Vector2(6, -6) * s,
				center + Vector2(22, 22) * s,
				center + Vector2(-6, 6) * s
			])
			var star_pts_d2 = PackedVector2Array([
				center + Vector2(22, -22) * s,
				center + Vector2(6, 6) * s,
				center + Vector2(-22, 22) * s,
				center + Vector2(-6, -6) * s
			])
			overlay.draw_colored_polygon(star_pts_d1, Color(1.0, 0.88, 0.35, alpha * 0.9))
			overlay.draw_colored_polygon(star_pts_d2, Color(1.0, 0.88, 0.35, alpha * 0.9))
			overlay.draw_circle(center, 10.0 * s, Color(1.0, 0.82, 0.1, alpha))
			overlay.draw_circle(center, 5.0 * s, Color(1.0, 1.0, 1.0, alpha))

		SpecialItemType.CHARGE_BOMB: # 11: チャージボム（ボム＋段階ピップ）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(1.0, 0.2, 0.4, alpha), 9.0 * s)
			var b_c = center + Vector2(0.0, 6.0) * s
			overlay.draw_circle(b_c, 38.0 * s, Color(0.22, 0.16, 0.22, alpha))
			var ch = special_charge[r][c] if special_charge.size() == GRID_ROWS else 1
			for k in range(ch):
				var px = center.x + (k - (ch - 1) * 0.5) * 24.0 * s
				overlay.draw_circle(Vector2(px, center.y + 44.0 * s), 6.0 * s, Color(1.0, 0.9, 0.1, alpha))

		SpecialItemType.GEMINI_BOMB: # 12: ジェミニボム（2連ボム）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(1.0, 0.75, 0.15, alpha), 9.0 * s)
			overlay.draw_circle(center + Vector2(-22, 0) * s, 26.0 * s, Color(1.0, 0.3, 0.1, alpha))
			overlay.draw_circle(center + Vector2(22, 0) * s, 26.0 * s, Color(1.0, 0.8, 0.1, alpha))

		SpecialItemType.ICE_SHIELD: # 13: 氷（❄️シアン六角氷晶マーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.3, 0.9, 1.0, alpha), 9.0 * s)
			var arm_len = 46.0 * s
			for k in range(6):
				var ang = k * PI / 3.0
				var dir = Vector2(cos(ang), sin(ang))
				overlay.draw_line(center, center + dir * arm_len, Color(0.7, 0.95, 1.0, alpha), 5.0 * s)
				var branch_pos = center + dir * (arm_len * 0.6)
				var b_dir1 = Vector2(cos(ang + PI / 4.0), sin(ang + PI / 4.0)) * (14.0 * s)
				var b_dir2 = Vector2(cos(ang - PI / 4.0), sin(ang - PI / 4.0)) * (14.0 * s)
				overlay.draw_line(branch_pos, branch_pos + b_dir1, Color(0.85, 1.0, 1.0, alpha), 3.5 * s)
				overlay.draw_line(branch_pos, branch_pos + b_dir2, Color(0.85, 1.0, 1.0, alpha), 3.5 * s)
			overlay.draw_circle(center, 9.0 * s, Color.WHITE)

		SpecialItemType.POISON_MIST: # 14: 毒（🧪エメラルド薬毒フラスコマーク）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(0.2, 1.0, 0.6, alpha), 9.0 * s)
			var f_neck = PackedVector2Array([
				center + Vector2(-10.0, -45.0) * s,
				center + Vector2(10.0, -45.0) * s,
				center + Vector2(10.0, -20.0) * s,
				center + Vector2(30.0, 30.0) * s,
				center + Vector2(-30.0, 30.0) * s,
				center + Vector2(-10.0, -20.0) * s
			])
			overlay.draw_colored_polygon(f_neck, Color(0.1, 0.85, 0.45, 0.85 * alpha))
			var f_out = f_neck.duplicate(); f_out.append(f_neck[0])
			overlay.draw_polyline(f_out, Color(0.05, 0.35, 0.15, alpha), 4.0 * s)
			overlay.draw_circle(center + Vector2(0.0, 15.0) * s, 10.0 * s, Color(0.5, 1.0, 0.7, alpha))
			overlay.draw_circle(center + Vector2(12.0, 4.0) * s, 6.0 * s, Color(0.7, 1.0, 0.85, alpha))

		_:
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color.WHITE, 8.0 * s)
			overlay.draw_circle(center, 30.0 * s, Color.WHITE)


## 剣の発射物アニメーション（着弾時即座に消去・敵撃破時は残存弾を速やかに全消去）
func moveswords() -> void:
	if flying_swords.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var sm = _get_stage_manager()
	var is_enemy_dead = (sm == null or sm.isdeadf or (sm.enemy == null and sm.ehp <= 0))

	for item in flying_swords:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		
		# 敵がすでに撃破されている場合は、無駄な飛翔を続けず即座に消去
		if is_enemy_dead:
			_return_sprite_to_pool(s)
			continue

		if t >= 0:
			# 目標の敵がすでに撃破されている場合、現在生存している別の敵へ自動リターゲット
			var target_spr = item.get("target_sprite")
			var target_e = item.get("target_enemy")
			var active_en_check = sm.active_enemies if (sm and "active_enemies" in sm) else []
			var is_target_alive = false
			if is_instance_valid(target_spr) and target_e != null:
				for e_chk in active_en_check:
					if e_chk == target_e and float(e_chk.get("hp", 0.0)) > 0:
						is_target_alive = true
						break
			if not is_target_alive and not active_en_check.is_empty():
				var next_e = active_en_check[0]
				item["target_enemy"] = next_e
				var next_spr = next_e.get("sprite")
				if is_instance_valid(next_spr):
					item["target_sprite"] = next_spr
					item["target_pos"] = self.to_local(next_spr.global_position)

			var progress = t / 50.0
			var ease_p = progress
			var sp = item.get("start_pos", Vector2(12200, 6648))
			var tp = item.get("target_pos", Vector2(12300, 2700))
			var cp = item.get("control_pos", Vector2((sp.x + tp.x)/2.0, sp.y - 2000.0))
			
			var q0 = sp.lerp(cp, ease_p)
			var q1 = cp.lerp(tp, ease_p)
			s.position = q0.lerp(q1, ease_p)
			
			var next_q0 = sp.lerp(cp, ease_p + 0.05)
			var next_q1 = cp.lerp(tp, ease_p + 0.05)
			var next_pos = next_q0.lerp(next_q1, ease_p + 0.05)
			s.rotation = (next_pos - s.position).angle() + PI/2.0
			
			if progress >= 1.0 and not item.get("has_hit", false):
				item["has_hit"] = true
				if sm:
					var base_dmg: float = item.get("damage", 100.0 * swordt)
					var atk_el = item.get("element", 0)
					target_spr = item.get("target_sprite")
					var active_en = sm.active_enemies if "active_enemies" in sm else []
					
					# 狙っていた敵が撃破されていた場合は、現在生存しているフォーカス敵（または0番目）にフォールバック
					var is_target_spr_active = false
					if is_instance_valid(target_spr):
						for e_chk in active_en:
							if e_chk.get("sprite") == target_spr and float(e_chk.get("hp", 0.0)) > 0:
								is_target_spr_active = true
								break
					if not is_target_spr_active and not active_en.is_empty():
						var f_idx = sm.get_focused_enemy_index() if sm.has_method("get_focused_enemy_index") else 0
						if f_idx >= 0 and f_idx < active_en.size():
							target_spr = active_en[f_idx].get("sprite")
						else:
							target_spr = active_en[0].get("sprite")
							
					var def_el = 0
					var jp_el = ""
					if sm.has_method("get_enemy_element"):
						jp_el = sm.get_enemy_element(target_spr)
						def_el = ElementDataScript.get_element_from_enemy_string(jp_el)
					elif sm.has_method("get_current_enemy_element"):
						jp_el = sm.get_current_enemy_element()
						def_el = ElementDataScript.get_element_from_enemy_string(jp_el)
						
					var mult = ElementDataScript.get_damage_multiplier(atk_el, def_el)
					var rm = _get_relic_manager()
					var relic_dmg = rm.modify_damage_dealt(base_dmg, {"element": atk_el, "enemy_element": jp_el}) if rm else base_dmg
					var final_dmg = relic_dmg * mult
					
					# 実際に着弾した特定の敵にダメージを適用
					sm.calchp(final_dmg, 0, target_spr)
					if _is_tutorial_mode():
						emit_signal("tutorial_attack_landed")
					
					var eff_str = "normal"
					if mult >= 1.2: eff_str = "weak"
					elif mult <= 0.8: eff_str = "resist"
					
					var el_str = ElementDataScript.get_element_name(atk_el)
					# ダメージポップアップを、着弾した敵スプライトの位置に直接表示！
					var hit_target_node = target_spr if is_instance_valid(target_spr) else "enemy"
					_emit_combat_event("damage", "ally", hit_target_node, final_dmg, el_str, false, eff_str)
				_spawn_hit_spark(s.position)
				if _sword_hit_sound_timer <= 0.0:
					_play_sword_hit_sound()
					_sword_hit_sound_timer = SWORD_HIT_SOUND_INTERVAL


		item["t"] = t + 1.0

		# 画面外まで飛翔した時点で消去
		if s.position.y <= -300.0:
			s.position.y = -300.0
			s.visible = false
			_return_sprite_to_pool(s)
		else:
			remaining.append(item)

	flying_swords = remaining

## 剣が敵にぶつかる時の衝突・斬撃SE再生（単一ボイス再生・音の重複と音量肥大化を完全防止）
func _play_sword_hit_sound() -> void:
	var se = get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	if se == null:
		se = AudioStreamPlayer.new()
		se.name = "AudioStreamPlayer"
		se.stream = SWORD_HIT_SE
		se.volume_db = -7.5
		se.max_polyphony = 1
		Profiler.add_child_count += 1; add_child(se)
	else:
		se.max_polyphony = 1
		se.volume_db = -7.5
		if se.stream == null:
			se.stream = SWORD_HIT_SE
	se.play(0.0)

## 展開シールドのアニメーション
func moveshields() -> void:
	if active_shields.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for item in active_shields:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		var target_p: Vector2 = item["target_p"]
		var v: Vector2 = item["v"]

		if t >= 0:
			s.position.x = min(target_p.x, 12200.0 + v.x * t * 10.0)
			s.position.y = max(target_p.y, 5856.0 - v.y * t * 10.0)

		if s.position.distance_to(target_p) < 20.0 and not item["has_arrived"]:
			item["has_arrived"] = true
			s.position = target_p
			_spawn_shockwave_ring(target_p, Color(0.3, 0.9, 1.0, 0.8), 80.0, 0.22)
			var se = get_node_or_null("shieldmove")
			if se and not se.playing: se.play()

		item["t"] = t + 1.0
		remaining.append(item)
	active_shields = remaining

## 食料のアニメーション
func movefoods() -> void:
	if flying_foods.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var sm = _get_stage_manager()

	for item in flying_foods:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		
		if t >= 0:
			s.position.x += 10.0 + item.get("rnd", 0.0)
			s.position.y = -pow(t, 2) + 9024.0

		item["t"] = t + 1.0

		if s.position.y <= 5000.0:
			if sm:
				var heal_val: float = item.get("heal", 100.0)
				var rm = _get_relic_manager()
				if rm: heal_val = rm.on_heal(heal_val)
				sm.calchp(0, -heal_val)
				_emit_combat_event("heal", "ally", "ally", heal_val)
			var p = get_parent()
			var se = p.get_node_or_null("kaihuku") if p else null
			if se and not se.playing: se.play()
			_return_sprite_to_pool(s)
		else:
			remaining.append(item)

	flying_foods = remaining

## ポーションのアニメーション
func movepotions() -> void:
	if flying_potions.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var sm = _get_stage_manager()

	for item in flying_potions:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		
		if t >= 0:
			s.position.x += 10.0 + item.get("rnd", 0.0)
			s.position.y = -pow(t, 2) + 8232.0

		item["t"] = t + 1.0

		if s.position.y <= 5000.0:
			if sm:
				var gage_val: float = item.get("gage", 100.0)
				sm.calcgage(gage_val)
			var p = get_parent()
			var se = p.get_node_or_null("potion") if p else null
			if se and not se.playing: se.play()
			_return_sprite_to_pool(s)
		else:
			remaining.append(item)

	flying_potions = remaining

## 消滅した駒が右側のステータス枠へ吸い込まれるアニメーション（高速・キビキビ吸入）
func movecell() -> void:
	if flying_cells.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var target_ys = [5856.0, 6648.0, 7440.0, 8232.0, 9024.0]

	for item in flying_cells:
		var s: Sprite2D = item["node"]
		var kind: int = clampi(item["kind"] % 5, 0, 4)
		var dest_y: float = target_ys[kind]

		var dist_x: float = 12200.0 - s.position.x
		var speed_x: float = maxf(450.0, dist_x * 0.28)
		s.position.x += minf(speed_x, dist_x)

		var dist_y: float = absf(dest_y - s.position.y)
		var speed_y: float = maxf(160.0, dist_y * 0.28)
		s.position.y = move_toward(s.position.y, dest_y, speed_y)

		if s.position.x >= 12200.0 and absf(s.position.y - dest_y) < 25.0:
			_return_sprite_to_pool(s)
		else:
			remaining.append(item)

	flying_cells = remaining

func _update_all_projectiles() -> void:
	if not flying_cells.is_empty(): movecell()
	if not flying_swords.is_empty(): moveswords()
	if not active_shields.is_empty(): moveshields()
	if not flying_foods.is_empty(): movefoods()
	if not flying_potions.is_empty(): movepotions()

## PvPモードの開始・自分のターン切り替え
func set_pvp_mode(enabled: bool) -> void:
	pvp_mode = enabled
	_reset_sync_state()

## PvP用：敵ターン中に敵の攻撃をシールドが受け止めた際の演出・軽減処理
func play_pvp_shield_block(absorbed: int, hp_damage: int, remaining_shield: int) -> void:
	var se = get_node_or_null("shieldmove")
	if se: se.play()

	# シールド位置で衝撃波＆防御リアクション
	for item in active_shields:
		if is_instance_valid(item.get("node")):
			var s: Sprite2D = item["node"]
			_spawn_shockwave_ring(s.position, Color(0.3, 0.9, 1.0, 0.85), 100.0, 0.22)
			var tw = create_tween()
			var orig_pos = s.position
			tw.tween_property(s, "position:x", orig_pos.x + randf_range(-120.0, 120.0), 0.05)
			tw.tween_property(s, "position:x", orig_pos.x, 0.08)

	_spawn_screen_flash(Color(0.3, 0.85, 1.0, 0.22), 0.2)

	# シールド耐久値が尽きた場合は割れるエフェクトとともにシールドを消去
	if remaining_shield <= 0:
		for item in active_shields:
			if is_instance_valid(item.get("node")):
				var s: Sprite2D = item["node"]
				_spawn_explosion_effect(s.position)
				_return_sprite_to_pool(s)
		active_shields.clear()
		current_total_shields = 0

## PvP用：敵のターンが終了したタイミングで、前行動時に展開されたシールドを消去・回収
func clear_pvp_shields() -> void:
	for item in active_shields:
		if is_instance_valid(item.get("node")):
			_return_sprite_to_pool(item["node"])
	active_shields.clear()
	current_total_shields = 0
	pvp_turn_shield_deployed = 0.0

## PvP用：相手が使ったスキルの影響マスを、自陣の同じマスにミラー反映する
## 毒・氷・石・火・水・光・木は同マスへ効果付与／闇はオフラインの敵闇攻撃と同様の挙動
func apply_pvp_mirror_skill(skill_key: String, tier: int, cells: Array) -> void:
	_ensure_ally_grids()
	var placed: int = 0
	for cell in cells:
		if not (cell is Array) or cell.size() < 2:
			continue
		var r: int = int(cell[0])
		var c: int = int(cell[1])
		if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS:
			continue
		var pos: Vector2 = get_cell_position(r, c)
		match skill_key:
			"poison":
				if grid_poison.size() == GRID_ROWS and not grid_poison[r][c]:
					grid_poison[r][c] = true
					_set_ally_flag(grid_poison_ally, r, c, false)
					if grid_poison_stage.size() == GRID_ROWS:
						grid_poison_stage[r][c] = 1
					_spawn_poison_bubble_burst_effect(pos)
					placed += 1
			"ice":
				if grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) <= 0:
					grid_ice[r][c] = maxi(1, tier)
					_set_ally_flag(grid_ice_ally, r, c, false)
					_spawn_ice_break_effect(pos)
					placed += 1
			"fire":
				if grid_fire.size() == GRID_ROWS and grid_fire[r][c] <= 0:
					grid_fire[r][c] = maxi(1, tier)
					_set_ally_flag(grid_fire_ally, r, c, false)
					_spawn_fire_ignition_effect(pos, false)
					placed += 1
			"water":
				if grid_water.size() == GRID_ROWS and not grid_water[r][c]:
					_apply_water_to_cell(r, c, false)
					placed += 1
			"earth", "stone":
				if grid_stones.size() == GRID_ROWS and grid_stones[r][c] <= 0:
					grid_stones[r][c] = maxi(1, tier)
					_set_ally_flag(grid_stones_ally, r, c, false)
					_spawn_stone_break_effect(pos)
					placed += 1
			"light":
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] <= 0:
					grid_gold_statue[r][c] = 3
					_set_ally_flag(grid_gold_ally, r, c, false)
					_spawn_gold_shatter_effect(pos)
					placed += 1
			"wood":
				if _get_plant_at(r, c).is_empty():
					if _plant_sprout_at(r, c):
						# 相手が植えた植物として扱う
						var planted = _get_plant_at(r, c)
						if not planted.is_empty():
							planted["enemy_planted"] = true
						placed += 1
	# 闇はオフラインの敵が使う闇攻撃と同じ挙動で作用させる
	if skill_key == "dark":
		_cast_enemy_dark_skill(false, false)
		placed += 1
	if placed > 0:
		_redraw_board_effects()
		_update_status_ailments()

func set_pvp_my_turn(enabled: bool) -> void:
	pvp_my_turn = enabled
	if enabled:
		pvp_pending_damage = 0.0
		pvp_used_skills.clear()
		pvp_turn_shield_deployed = 0.0
		pvp_shield_spawned = false
		var stage_mgr = _get_stage_manager()
		pvp_start_enemy_hp = stage_mgr.ehp if stage_mgr and "ehp" in stage_mgr else 0.0
		pvp_is_attack = 0
		pvp_is_block = 0
		var score_mgr = _get_score_manager()
		if score_mgr and "divscore" in score_mgr:
			pvp_divscore_snapshot = score_mgr.divscore.duplicate()
		else:
			pvp_divscore_snapshot = []
		# 新しい自分のターン開始時は、前ターンの演出状態が残っていても必ず入力可能状態へ戻す
		current_state = BoardState.IDLE
		interval = 0
		is_enemy_turn_in_progress = false
		is_holding = false
		drag_offset = Vector2.ZERO
	elif current_state == BoardState.IDLE:
		current_state = BoardState.TURN_SEQUENCE
		interval = 0

## 盤面全体の状態をシリアライズする（共有盤面モード用）
func _serialize_board_state() -> Dictionary:
	var state := {}
	# 駒の種類・スキル駒・チャージ・所有者
	state["n"] = _flatten_grid(grid_n)
	state["si"] = _flatten_grid(special_item)
	state["sc"] = _flatten_grid(special_charge)
	state["so"] = _flatten_grid(grid_skill_owner)
	state["ib"] = _flatten_grid_bool(is_bomb)
	# 属性・エレメント
	state["ga"] = _flatten_grid(grid_att)
	state["ge"] = _flatten_grid(grid_element)
	# 効果マス
	state["we"] = _flatten_grid_bool(grid_water)
	state["ic"] = _flatten_grid(grid_ice)
	state["fi"] = _flatten_grid(grid_fire)
	state["el"] = _flatten_grid_bool(grid_electrified)
	state["st"] = _flatten_grid(grid_stones)
	state["cu"] = _flatten_grid_bool(grid_cursed)
	state["po"] = _flatten_grid_bool(grid_poison)
	state["ps"] = _flatten_grid(grid_poison_stage)
	state["gs"] = _flatten_grid(grid_gold_statue)
	state["ab"] = _flatten_grid_bool(grid_afterburn)
	return state

## 前回同期時からの差分のみをシリアライズする（通信量削減用）
var _last_synced_state: Dictionary = {}

func _serialize_board_delta() -> Dictionary:
	var current := _serialize_board_state()
	var delta := {}
	for key in current.keys():
		var cur: Array = current[key]
		var prev: Array = _last_synced_state.get(key, [])
		var changes: Array = []
		for idx in range(cur.size()):
			var prev_val = prev[idx] if idx < prev.size() else null
			if prev_val == null or cur[idx] != prev_val:
				changes.append([idx, cur[idx]])
		if not changes.is_empty():
			delta[key] = changes
	# 現在の状態を保存（次回の差分計算用）
	_last_synced_state = current
	return delta

## デルタを盤面に適用する（共有盤面モード用）
func _apply_board_delta(delta: Dictionary) -> void:
	if delta.is_empty():
		return
	var grids := {
		"n": grid_n, "si": special_item, "sc": special_charge,
		"so": grid_skill_owner, "ib": is_bomb,
		"ga": grid_att, "ge": grid_element,
		"we": grid_water, "ic": grid_ice, "fi": grid_fire,
		"el": grid_electrified, "st": grid_stones,
		"cu": grid_cursed, "po": grid_poison,
		"ps": grid_poison_stage, "gs": grid_gold_statue, "ab": grid_afterburn
	}
	var bool_keys := {"ib": true, "we": true, "el": true, "cu": true, "po": true, "ab": true}
	var int_keys := {"n": true, "si": true, "sc": true, "so": true, "ga": true, "ge": true,
		"ic": true, "fi": true, "st": true, "ps": true, "gs": true}
	for key in delta.keys():
		if not grids.has(key):
			continue
		var grid: Array = grids[key]
		if grid.size() != GRID_ROWS:
			continue
		var changes: Array = delta[key]
		for change in changes:
			var idx: int = int(change[0])
			var r: int = idx / GRID_COLUMNS
			var c: int = idx % GRID_COLUMNS
			var val = change[1]
			if bool_keys.has(key):
				grid[r][c] = int(val) != 0
			elif int_keys.has(key):
				grid[r][c] = int(val)
			else:
				grid[r][c] = val
	# スプライトテクスチャを盤面データに同期（grid_n 変更時）
	_sync_piece_sprites()
	_update_board_element_flags()
	_redraw_board_effects()
	queue_redraw()
	# 受信側も同期状態を更新（自分の変更を再送しないため）
	_last_synced_state = _serialize_board_state()

## grid_n に合わせてスプライトのテクスチャを更新する
func _sync_piece_sprites() -> void:
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			# 固定マッピング: piece[r * GRID_COLUMNS + c] がセル(r,c)の位置にある
			var idx: int = r * GRID_COLUMNS + c
			if idx >= piece.size() or piece[idx] == null:
				continue
			# grid_i もデフォルトにリセット
			if grid_i.size() == GRID_ROWS:
				grid_i[r][c] = idx
			var kind: int = grid_n[r][c]
			if kind >= 0 and kind < PIECE_TEXTURES.size() and PIECE_TEXTURES[kind] != null:
				if piece[idx].texture != PIECE_TEXTURES[kind]:
					piece[idx].texture = PIECE_TEXTURES[kind]
				piece[idx].position = get_cell_position(r, c)
				piece[idx].visible = true
			else:
				piece[idx].visible = false

## 同期状態をリセットする（マッチ開始時）
func _reset_sync_state() -> void:
	_last_synced_state = {}

## 相手のスワップを適用してカスケード解決する（シード同期方式）
func _apply_pvp_swap(swap: Array) -> void:
	if swap.size() < 2:
		return
	var a = swap[0]
	var b = swap[1]
	var r1: int = int(a[0]); var c1: int = int(a[1])
	var r2: int = int(b[0]); var c2: int = int(b[1])
	if r1 < 0 or r1 >= GRID_ROWS or c1 < 0 or c1 >= GRID_COLUMNS:
		return
	if r2 < 0 or r2 >= GRID_ROWS or c2 < 0 or c2 >= GRID_COLUMNS:
		return
	# 全グリッドの該当セルをスワップ
	var all_grids := [grid_n, grid_att, grid_element, is_bomb,
		special_item, special_charge, grid_skill_owner,
		grid_water, grid_ice, grid_fire, grid_electrified,
		grid_stones, grid_cursed, grid_poison, grid_poison_stage,
		grid_gold_statue, grid_afterburn]
	for grid in all_grids:
		if grid.size() == GRID_ROWS:
			var tmp = grid[r1][c1]
			grid[r1][c1] = grid[r2][c2]
			grid[r2][c2] = tmp
	# スプライトを同期
	_sync_piece_sprites()
	_update_board_element_flags()
	_redraw_board_effects()
	queue_redraw()
	# カスケード解決を開始（マッチ検出→消去→落下→連鎖）
	last_swap_cells = [Vector2i(r1, c1), Vector2i(r2, c2)]
	_start_match_highlight()

## 盤面全体の状態をシリアライズする（互換用・フル状態が必要な場合）
func _serialize_board_state_full() -> Dictionary:
	return _serialize_board_state()

## シリアライズされた盤面状態を適用する（共有盤面モード用）
func _apply_board_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_unflatten_grid(grid_n, state.get("n", []))
	_unflatten_grid(special_item, state.get("si", []))
	_unflatten_grid(special_charge, state.get("sc", []))
	_unflatten_grid(grid_skill_owner, state.get("so", []))
	_unflatten_grid_bool(is_bomb, state.get("ib", []))
	_unflatten_grid(grid_att, state.get("ga", []))
	_unflatten_grid(grid_element, state.get("ge", []))
	_unflatten_grid_bool(grid_water, state.get("we", []))
	_unflatten_grid(grid_ice, state.get("ic", []))
	_unflatten_grid(grid_fire, state.get("fi", []))
	_unflatten_grid_bool(grid_electrified, state.get("el", []))
	_unflatten_grid(grid_stones, state.get("st", []))
	_unflatten_grid_bool(grid_cursed, state.get("cu", []))
	_unflatten_grid_bool(grid_poison, state.get("po", []))
	_unflatten_grid(grid_poison_stage, state.get("ps", []))
	_unflatten_grid(grid_gold_statue, state.get("gs", []))
	_unflatten_grid_bool(grid_afterburn, state.get("ab", []))
	_update_board_element_flags()
	_redraw_board_effects()
	queue_redraw()

## 2次元グリッドを1次元配列に平坦化
func _flatten_grid(grid: Array) -> Array:
	var flat: Array = []
	if grid.size() != GRID_ROWS:
		return flat
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			flat.append(grid[r][c])
	return flat

func _flatten_grid_bool(grid: Array) -> Array:
	var flat: Array = []
	if grid.size() != GRID_ROWS:
		return flat
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			flat.append(1 if grid[r][c] else 0)
	return flat

## 1次元配列を2次元グリッドに復元
func _unflatten_grid(grid: Array, flat: Array) -> void:
	if grid.size() != GRID_ROWS or flat.size() < GRID_ROWS * GRID_COLUMNS:
		return
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			grid[r][c] = flat[r * GRID_COLUMNS + c]

func _unflatten_grid_bool(grid: Array, flat: Array) -> void:
	if grid.size() != GRID_ROWS or flat.size() < GRID_ROWS * GRID_COLUMNS:
		return
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			grid[r][c] = flat[r * GRID_COLUMNS + c] != 0

func _build_pvp_turn_payload(sm: Node2D, score_mgr: Node2D, damage: float, shield_gain: float, used_skills: Array) -> Dictionary:
	var coins: int = 0
	if score_mgr and "divscore" in score_mgr and score_mgr.divscore.size() > PieceType.COIN:
		coins = int(score_mgr.divscore[PieceType.COIN])
	var hp: float = sm.myhp if sm else 0.0
	var max_hp: float = sm.myhpmax if sm else 5000.0
	var skill_name: String = ""
	var skill_element: String = ""
	if not used_skills.is_empty():
		var last_skill = used_skills[used_skills.size() - 1]
		if last_skill is Dictionary:
			skill_name = str(last_skill.get("name", ""))
			skill_element = str(last_skill.get("element", ""))
	# このターンの「剣の値」と「各属性値」を送る（相手画面のアクション演出の駆動に使用）
	var sword_val: int = 0
	if score_mgr and "divscore" in score_mgr and score_mgr.divscore.size() > PieceType.SWORD:
		sword_val = int(score_mgr.divscore[PieceType.SWORD])
	var element_values: Dictionary = {}
	if score_mgr and "turn_element_counts" in score_mgr:
		var el_map: Dictionary = {1: "fire", 2: "water", 3: "wind", 4: "thunder", 5: "light", 6: "dark", 7: "poison", 8: "ice", 9: "wood", 10: "earth"}
		for el in score_mgr.turn_element_counts.keys():
			var el_key: String = str(el_map.get(int(el), ""))
			var el_val: int = int(score_mgr.turn_element_counts[el])
			if el_key != "" and el_val > 0:
				element_values[el_key] = el_val
	# このターンに使ったスキル（最大4つ）と、各スキルが影響を与えたマスを相手へ送る
	# 起点シードも送ることで、相手側でも同じ乱数列から演出を再現できる
	var skill_list: Array = []
	for sk in used_skills:
		if skill_list.size() >= 4:
			break
		if sk is Dictionary:
			skill_list.append({
				"key": str(sk.get("element", "")),
				"tier": int(sk.get("tier", 1)),
				"cells": sk.get("cells", [])
			})
	return {
		"damage": int(round(maxf(0.0, damage))),
		"heal": 0,
		"shield": int(round(maxf(0.0, shield_gain))),
		"coins": coins,
		"hp": int(round(hp)),
		"maxHp": int(round(max_hp)),
		"skillName": skill_name,
		"skillElement": skill_element,
		"skills": skill_list,
		"sword": sword_val,
		"elements": element_values,
		"seed": int(board_seed),
		"swap": last_swap_cells.map(func(v): return [v.x, v.y])
	}

func _finish_pvp_turn(sm: Node2D, score_mgr: Node2D) -> void:
	var used_skills: Array = pvp_used_skills.duplicate(true)
	# 行動中に展開したシールドを合算して、敵のターン中も残る盾として引き渡す
	var shield_gain: float = pvp_turn_shield_deployed if pvp_mode else float(current_total_shields) * 100.0 * shieldt
	# ターン終了時の毒・火などの継続効果を反映
	_reset_turn(sm, score_mgr)
	var end_hp: float = sm.ehp if sm and "ehp" in sm else 0.0
	var damage: float = maxf(0.0, pvp_start_enemy_hp - end_hp)
	var payload: Dictionary = _build_pvp_turn_payload(sm, score_mgr, damage, shield_gain, used_skills)
	pvp_pending_damage = 0.0
	current_state = BoardState.TURN_SEQUENCE
	interval = 0
	pvp_my_turn = false
	pvp_turn_resolved.emit(payload)
	pvp_turn_completed.emit()

func _handle_pvp_turn_sequence(sm: Node2D, score_mgr: Node2D) -> void:
	if not pvp_my_turn:
		return

	if interval == 0:
		pvp_is_attack = 0
		pvp_is_block = 0
		pvp_shield_spawned = false
		pvp_used_skills = turn_skill_log.duplicate(true)
		if score_mgr:
			var s_cnt = min(int((sm.ehp if sm else 0) / swordt), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))
			var food_heal_unit: float = maxf(1.0, foodt * 100.0)
			var needed_heal: float = maxf(0.0, (sm.myhpmax - sm.myhp) if sm else 0.0)
			var max_heal: int = int(ceil(needed_heal / food_heal_unit))
			var f_cnt = min(max_heal, int(score_mgr.divscore[PieceType.FOOD] / food_heal_unit))
			var max_gage = 0 if (sm and sm.isfevertime) else maxi(0, 70 - int((sm.fevergage if sm else 0) / (100.0 * potiont)))
			var p_cnt = min(max_gage, int(score_mgr.divscore[PieceType.POTION] / (potiont * 100.0)))
			if s_cnt > 0 or (f_cnt > 0 and sm and sm.myhp < sm.myhpmax) or (p_cnt > 0 and sm and not sm.isfevertime and sm.fevergage < 7000.0) or turn_skill_log.size() > 0:
				pvp_is_attack = 1
			var sh_cnt = int(score_mgr.divscore[PieceType.SHIELD] / (shieldt * 100.0))
			if sh_cnt > 0:
				pvp_is_block = 1

	if pvp_is_attack == 0 and pvp_is_block == 0:
		if interval < 12:
			interval += 1
			return
		_finish_pvp_turn(sm, score_mgr)
		return

	# オフラインと同じアイテム値の上下振動
	if interval <= 36:
		var t_in_cycle: float = float(interval % 36)
		var hop_y: float = (t_in_cycle - 18.0) * (t_in_cycle - 18.0) / 10.0 - 32.4
		if score_mgr:
			for i in range(5):
				var lbl = score_mgr.get_node_or_null("score" + str(i))
				if lbl:
					lbl.position.x = SCORE_LABEL_BASE_X
					lbl.position.y = SCORE_LABEL_BASE_Y + SCORE_LABEL_PITCH * i + hop_y
					lbl.scale = SCORE_LABEL_BASE_SCALE
					lbl.modulate = Color.WHITE
				var icn = score_mgr.get_node_or_null("score_icon" + str(i))
				if icn:
					icn.position.x = 1204.0
					icn.position.y = 546.0 + 79.2 * float(i) + 16.6 + hop_y
		interval += 1
		return

	_restore_score_label_positions()
	var base_time: int = 36
	if interval == base_time + 1 and pvp_is_attack:
		_spawn_attack_projectiles(sm, score_mgr)
		_play_ally_attack_phase_effects(sm)
	elif interval == base_time + 1 + 144 * pvp_is_attack and pvp_is_block:
		_spawn_shield_projectiles(score_mgr)
		pvp_shield_spawned = true

	if interval > base_time:
		var attack_done: bool = flying_swords.is_empty() and flying_foods.is_empty() and flying_potions.is_empty()
		# 盾は攻撃の後に展開されるため、展開前は「完了」とみなさない（展開されないままターンが終わるのを防ぐ）
		var shield_done: bool = (not pvp_is_block) or pvp_shield_spawned
		for it in active_shields:
			if not it.get("has_arrived", false):
				shield_done = false
				break
		var max_wait: int = base_time + 144 * pvp_is_attack + 160 * pvp_is_block + 90
		if (attack_done and shield_done) or interval > max_wait:
			_finish_pvp_turn(sm, score_mgr)
			return
	interval += 1

## ターン進行の演出シーケンス
func _handle_turn_sequence(sm: Node2D, score_mgr: Node2D) -> void:
	if pvp_mode:
		_handle_pvp_turn_sequence(sm, score_mgr)
		return

	if isgameover:
		# PvPではオフラインのゲームオーバー演出を行わず、PvPの勝敗表示に任せる
		if not pvp_mode:
			_handle_gameover_sequence(sm)
		return

	if is_tutorial_paused:
		return

	# ターン開始時（interval == 0）に、実際に発射物・アクションが発生するかを厳密に判定
	if interval == 0:
		has_enemy_attacked = false
		isattack = 0
		isblock = 0
		if _is_tutorial_mode() and not has_emitted_items_scored:
			has_emitted_items_scored = true
			emit_signal("tutorial_items_scored")
			if is_tutorial_paused:
				_restore_score_label_positions()
				return

		# ⚡ 自軍感電5スタック超過時の過負荷放電
		if player_shock_stacks >= 5:
			player_shock_stacks = 0
			var ol_dmg = (minf(sm.myhpmax * 0.12, 600.0) if (sm and sm.myhpmax > 0) else 600.0) * _get_difficulty_skill_mult()
			if sm:
				sm.last_damage_cause = "感電スタック過負荷放電"
				sm.calchp(0.0, ol_dmg)
			_spawn_screen_flash(Color(1.0, 0.9, 0.2, 0.4), 0.25)
			_spawn_floating_text(Vector2(640, 500), "⚡ 感電過負荷放電 -%d!" % int(ol_dmg), Color(1.0, 0.4, 0.3))
		if score_mgr:
			var s_cnt = min(int((sm.ehp if sm else 0) / swordt), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))
			var food_heal_unit: float = maxf(1.0, foodt * 100.0)
			var needed_heal: float = maxf(0.0, (sm.myhpmax - sm.myhp) if sm else 0.0)
			var max_heal: int = int(ceil(needed_heal / food_heal_unit))
			var f_cnt = min(max_heal, int(score_mgr.divscore[PieceType.FOOD] / food_heal_unit))
			var max_gage = 0 if (sm and sm.isfevertime) else maxi(0, 70 - int((sm.fevergage if sm else 0) / (100.0 * potiont)))
			var p_cnt = min(max_gage, int(score_mgr.divscore[PieceType.POTION] / (potiont * 100.0)))
			if s_cnt > 0 or (f_cnt > 0 and sm and sm.myhp < sm.myhpmax) or (p_cnt > 0 and sm and not sm.isfevertime and sm.fevergage < 7000.0) or turn_skill_log.size() > 0:
				isattack = 1
			var sh_cnt = int(score_mgr.divscore[PieceType.SHIELD] / (shieldt * 100.0))
			if sh_cnt > 0:
				isblock = 1

	# 行動が一切発生しない場合（剣・盾・回復・ポーションいずれも出ない）：
	# ユーザー要望「盾などがたまらずに行動しないと、待ち時間が体感長くなるので、何も行動が起きなかったらすぐに敵が攻撃してくるようにしてほしい。つまり、行動が起きなかったら、その待機時間を消す。」
	if isattack == 0 and isblock == 0:
		_restore_score_label_positions()

		# 敵が存在しない、またはすでに倒れている場合は即座に次ターンへ
		if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
			_reset_turn(sm, score_mgr)
			current_state = BoardState.IDLE
			return

		# 待機時間を一切挟まず、即座に敵が攻撃（スキル発動時やスプライトシート再生時は演出確認のため待機時間を確保）
		var has_custom_atk = sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")
		if interval == 0:
			if _enemy_turn_actions.is_empty():
				is_casting_skill_turn = _decide_enemy_actions(sm)
			else:
				is_casting_skill_turn = false
				for act in _enemy_turn_actions:
					if act.get("action", "") in ["skill", "summon"]:
						is_casting_skill_turn = true
						break
			has_enemy_attacked = false
			has_enemy_skilled = false
			var anten = get_node_or_null("anten")
			if anten: anten.play()
		
		# 敵全員がアクションを実行し終えるまでの十分な待機時間を計算（敵の数×アクション種別）
		var end_wait_fast = 4 + _calc_enemy_turn_duration(sm, is_casting_skill_turn)
			
		if interval == 4:
			_execute_enemy_turn_actions(sm)
			
		elif interval > 4:
			var is_anim = is_enemy_turn_in_progress or (_enemy_turn_tween != null and _enemy_turn_tween.is_valid()) or (sm and sm.is_enemy_animating())
			# アニメーションが完了したら直ちにターン終了（長大な無駄待機を完全カット）
			if not is_anim or interval >= end_wait_fast + 30:
				if sm and not sm.isfevertime and interval >= end_wait_fast:
					sm.fevertime()
				if is_anim and sm and sm.has_method("stop_enemy_animation"):
					sm.stop_enemy_animation()
				is_enemy_turn_in_progress = false
				if _is_tutorial_mode():
					emit_signal("tutorial_enemy_acted")
				_reset_turn(sm, score_mgr)
				current_state = BoardState.IDLE
				return
		interval += 1
		return

	# --- 行動が発生する場合の通常のタイムライン ---
	# スコア欄ラベルの上下運動（放物線バウンド）演出 (36フレーム = 0.6秒でスピーディに完了)
	if interval <= 36:
		if interval == 0:
			var anten = get_node_or_null("anten")
			if anten: anten.play()

		var t_in_cycle: float = float(interval % 36)
		# 放物線: t=0で0, t=18で-32.4, t=36で0 (元の計算式: (t-18)^2 / 10 - 32.4)
		var hop_y: float = (t_in_cycle - 18.0) * (t_in_cycle - 18.0) / 10.0 - 32.4

		if score_mgr:
			for i in range(5):
				var lbl = score_mgr.get_node_or_null("score" + str(i))
				if lbl:
					lbl.position.x = SCORE_LABEL_BASE_X
					lbl.position.y = SCORE_LABEL_BASE_Y + SCORE_LABEL_PITCH * i + hop_y
					lbl.scale = SCORE_LABEL_BASE_SCALE
					lbl.modulate = Color.WHITE
				var icn = score_mgr.get_node_or_null("score_icon" + str(i))
				if icn:
					icn.position.x = 1204.0
					icn.position.y = 546.0 + 79.2 * float(i) + 16.6 + hop_y
	else:
		# バウンド終了後および攻撃フェーズ中は、初期位置・通常スケール・白色に復帰固定
		_restore_score_label_positions()

	# 攻撃・防御・敵ターンのタイムライン（36フレームのバウンド終了後から開始）
	var base_time: int = 36

	if interval == base_time + 1 and isattack:
		_spawn_attack_projectiles(sm, score_mgr)
		_play_ally_attack_phase_effects(sm)

	elif interval <= base_time + 144 and isattack:
		# 敵が撃破された場合、残存発射物を即座に全消去してターン終了（死んだ敵への攻撃や無駄な待機を完全カット）
		if sm and (sm.isdeadf or (sm.enemy == null and sm.ehp <= 0)):
			_clear_all_combat_projectiles()
			_reset_turn(sm, score_mgr)
			current_state = BoardState.IDLE
			return
		# 攻撃発射物が全数着地済みなら、長すぎる144フレームの空き時間をスキップして速やかに次フェーズへ
		if interval >= base_time + 8 and flying_swords.is_empty() and flying_foods.is_empty() and flying_potions.is_empty():
			interval = base_time + 144

	elif interval == base_time + 1 + 144 * isattack and isblock:
		_spawn_shield_projectiles(score_mgr)

	elif interval <= base_time + 56 + 144 * isattack and isblock:
		pass

	elif interval < base_time + 1 + 144 * isattack + 128 * isblock:
		# シールド展開が完了していれば、長すぎる空き時間をスキップして速やかに敵ターンへ
		if interval > base_time + 12 + 144 * isattack and isblock:
			var all_arrived: bool = true
			for it in active_shields:
				if not it.get("has_arrived", false):
					all_arrived = false
					break
			if all_arrived:
				interval = base_time + 144 * isattack + 128 * isblock

	elif interval == base_time + 1 + 144 * isattack + 128 * isblock:
		if _enemy_turn_actions.is_empty():
			is_casting_skill_turn = _decide_enemy_actions(sm)
		else:
			is_casting_skill_turn = false
			for act in _enemy_turn_actions:
				if act.get("action", "") in ["skill", "summon"]:
					is_casting_skill_turn = true
					break
		has_enemy_attacked = false
		has_enemy_skilled = false

	elif interval == base_time + 8 + 144 * isattack + 128 * isblock:
		_execute_enemy_turn_actions(sm)

	elif interval > base_time + 8 + 144 * isattack + 128 * isblock:
		var max_wait = base_time + 8 + _calc_enemy_turn_duration(sm, is_casting_skill_turn) + 144 * isattack + 128 * isblock
		var is_anim = is_enemy_turn_in_progress or (_enemy_turn_tween != null and _enemy_turn_tween.is_valid()) or (sm and sm.is_enemy_animating())
		# 敵アクション完了判定：アニメーション終了次第、待機ゼロで即座にターン終了
		if not is_anim or interval >= max_wait + 30:
			if sm and not sm.isfevertime and interval >= max_wait:
				sm.fevertime()
			if is_anim and sm and sm.has_method("stop_enemy_animation"):
				sm.stop_enemy_animation()
			is_enemy_turn_in_progress = false
			if _is_tutorial_mode():
				emit_signal("tutorial_enemy_acted")
			_reset_turn(sm, score_mgr)
			current_state = BoardState.IDLE
			return

	interval += 1

## プレイヤー攻撃・回復・ゲージ発射物の生成
func _spawn_attack_projectiles(sm: Node2D, score_mgr: Node2D) -> void:
	if not score_mgr: return

	# 剣（フリーズ対策・描画負荷最適化のため生成数を最大300個に制限。総ダメージは100%保持）
	var original_sword_score = score_mgr.divscore[PieceType.SWORD]
	var sword_element_pool = []
	if "turn_element_gain" in score_mgr and score_mgr.turn_element_gain.has(PieceType.SWORD):
		var total_allocated = 0
		if original_sword_score > 0:
			for el in score_mgr.turn_element_gain[PieceType.SWORD]:
				var el_score = score_mgr.turn_element_gain[PieceType.SWORD][el]
				var expected_cnt = min(int(sm.ehp / swordt), int(el_score / (swordt * 100.0))) if sm else 0
				# Approximate proportion for visually spawning
				var count = int(round(float(min(int(original_sword_score / (swordt * 100.0)), MAX_COMBAT_PROJECTILES)) * (float(el_score) / float(original_sword_score))))
				for j in range(count):
					sword_element_pool.append(el)
				total_allocated += count
	
	var raw_sword_cnt: int = min(int((sm.ehp if sm else 0) / swordt), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))
	score_mgr.divscore[PieceType.SWORD] -= int(raw_sword_cnt * swordt * 100.0)
	var spawn_sword_cnt: int = clampi(raw_sword_cnt, 0, MAX_COMBAT_PROJECTILES)
	var dmg_per_sword: float = (float(raw_sword_cnt) / float(max(1, spawn_sword_cnt))) * 100.0 * swordt

	var active_en = sm.active_enemies if sm and "active_enemies" in sm else []
	var sim_enemy_hp: Array[float] = []
	for e_item in active_en:
		sim_enemy_hp.append(float(e_item.get("hp", 0.0)))

	for i in range(spawn_sword_cnt):
		var s: Sprite2D = _get_sprite_from_pool()
		s.texture = PIECE_TEXTURES[PieceType.SWORD]
		var target_pos = Vector2(12300.0 + float(randi() % 2000 - 1000), 2700.0)
		var target_e = null
		var target_spr = null
		if not active_en.is_empty():
			var focus_idx = sm.get_focused_enemy_index() if sm.has_method("get_focused_enemy_index") else -1
			var chosen_idx = -1
			if focus_idx >= 0 and focus_idx < active_en.size():
				# ターゲット指定あり：指定敵のHPが残っている間は集中、HP超過分は生存している他敵へ配分
				if sim_enemy_hp[focus_idx] > 0.0:
					chosen_idx = focus_idx
				else:
					for o_idx in range(active_en.size()):
						var cand_idx = (focus_idx + 1 + o_idx) % active_en.size()
						if sim_enemy_hp[cand_idx] > 0.0:
							chosen_idx = cand_idx
							break
					if chosen_idx == -1:
						chosen_idx = (i - focus_idx) % active_en.size()
			else:
				# ターゲットなし：生存している敵全体へ均等に分散
				for o_idx in range(active_en.size()):
					var check_idx = (i + o_idx) % active_en.size()
					if sim_enemy_hp[check_idx] > 0.0:
						chosen_idx = check_idx
						break
				if chosen_idx == -1:
					chosen_idx = i % active_en.size()

			if chosen_idx >= 0 and chosen_idx < active_en.size():
				target_e = active_en[chosen_idx]
				sim_enemy_hp[chosen_idx] -= dmg_per_sword

			if target_e:
				var spr = target_e.get("sprite")
				if is_instance_valid(spr):
					target_spr = spr
					target_pos = self.to_local(spr.global_position)
		
		var start_x = 12200.0
		var start_y = 6648.0
		var start_p = Vector2(start_x, start_y)
		var mid_x = (start_p.x + target_pos.x) / 2.0
		var mid_y = (start_p.y + target_pos.y) / 2.0
		var bow_distance = 1500.0 + float(randi() % 4000)
		var cp = Vector2(mid_x, mid_y + bow_distance)
		var cp_x = cp.x
		var cp_y = cp.y
		
		s.position = Vector2(start_x, start_y)
		s.scale = Vector2(2.0, 2.0)
		s.z_index = 10
		s.visible = true
		flying_swords.append({
			"node": s,
			"t": -float(i * 70) / float(max(1, spawn_sword_cnt)),
			"start_pos": Vector2(start_x, start_y),
			"target_pos": target_pos,
			"control_pos": Vector2(cp_x, cp_y),
			"has_hit": false,
			"damage": dmg_per_sword,
			"element": sword_element_pool[i] if i < sword_element_pool.size() else 0,
			"target_sprite": target_spr,
			"target_enemy": target_e
		})
		msisvalid = true

	# 食料（生成数最大24個制限・回復量100%保持）
	var food_heal_unit: float = maxf(1.0, foodt * 100.0)
	var needed_heal_cap: float = maxf(0.0, (sm.myhpmax - sm.myhp) if sm else 0.0)
	var max_heal_cap: int = int(ceil(needed_heal_cap / food_heal_unit))
	var raw_food_cnt: int = min(max_heal_cap, int(score_mgr.divscore[PieceType.FOOD] / food_heal_unit))
	score_mgr.divscore[PieceType.FOOD] -= int(raw_food_cnt * food_heal_unit)
	var food_cnt: int = clampi(raw_food_cnt, 0, MAX_COMBAT_PROJECTILES)
	var heal_per_food: float = (float(raw_food_cnt) / float(max(1, food_cnt))) * 100.0
	for i in range(food_cnt):
		var s: Sprite2D = _get_sprite_from_pool()
		s.texture = PIECE_TEXTURES[PieceType.FOOD]
		s.position = Vector2(12200, 9024)
		s.scale = Vector2(2.0, 2.0)
		s.visible = true
		flying_foods.append({
			"node": s,
			"t": -float(i * 70) / float(max(1, food_cnt)),
			"rnd": float(randi() % 120),
			"heal": heal_per_food
		})

	# ポーション（生成数最大24個制限・ゲージ量100%保持、余剰ポーションはスキルツリー用に保持）
	var max_gage_cap: int = 0 if (sm and sm.isfevertime) else maxi(0, 70 - int((sm.fevergage if sm else 0) / (100.0 * potiont)))
	var raw_potion_cnt: int = min(max_gage_cap, int(score_mgr.divscore[PieceType.POTION] / (potiont * 100.0)))
	var consume_potion_score: int = int(raw_potion_cnt * potiont * 50.0)
	score_mgr.divscore[PieceType.POTION] = maxi(0, score_mgr.divscore[PieceType.POTION] - consume_potion_score)
	var potion_cnt: int = clampi(raw_potion_cnt, 0, MAX_COMBAT_PROJECTILES)
	var gage_per_potion: float = (float(raw_potion_cnt) / float(max(1, potion_cnt))) * 100.0
	for i in range(potion_cnt):
		var s: Sprite2D = _get_sprite_from_pool()
		s.texture = PIECE_TEXTURES[PieceType.POTION]
		s.position = Vector2(12200, 8232)
		s.scale = Vector2(2.0, 2.0)
		s.visible = true
		flying_potions.append({
			"node": s,
			"t": -float(i * 70) / float(max(1, potion_cnt)),
			"rnd": float(randi() % 120),
			"gage": gage_per_potion
		})

## シールド生成（描画負荷最適化のため生成数を最大24個に制限。防御力は全数保持）
func _spawn_shield_projectiles(score_mgr: Node2D) -> void:
	if not score_mgr: return
	var original_shield_score = score_mgr.divscore[PieceType.SHIELD]
	current_shield_pools.clear()
	
	if "turn_element_gain" in score_mgr and score_mgr.turn_element_gain.has(PieceType.SHIELD):
		var total_allocated = 0
		if original_shield_score > 0:
			for el in score_mgr.turn_element_gain[PieceType.SHIELD]:
				var el_score = score_mgr.turn_element_gain[PieceType.SHIELD][el]
				var count = float(el_score) / (shieldt * 100.0)
				current_shield_pools[el] = current_shield_pools.get(el, 0.0) + count
				total_allocated += el_score
		var remaining_score = max(0, original_shield_score - total_allocated)
		if remaining_score > 0:
			var r_count = float(remaining_score) / (shieldt * 100.0)
			current_shield_pools[0] = current_shield_pools.get(0, 0.0) + r_count
	else:
		var count = float(original_shield_score) / (shieldt * 100.0)
		current_shield_pools[0] = count
		
	var raw_shield_cnt: int = int(score_mgr.divscore[PieceType.SHIELD] / (shieldt * 100.0))
	score_mgr.divscore[PieceType.SHIELD] -= int(raw_shield_cnt * shieldt * 100.0)
	current_total_shields = raw_shield_cnt
	# PvP: このターンに展開したシールド量を累積する（複数回展開しても合算される）
	if pvp_mode:
		pvp_turn_shield_deployed += float(raw_shield_cnt) * shieldt * 100.0
	var spawn_shield_cnt: int = clampi(raw_shield_cnt, 0, MAX_COMBAT_PROJECTILES)

	for i in range(spawn_shield_cnt):
		var s: Sprite2D = _get_sprite_from_pool()
		s.texture = PIECE_TEXTURES[PieceType.SHIELD]
		s.position = Vector2(12200, 5856)
		s.scale = Vector2(2.0, 2.0)
		s.z_index = 25  # 敵の突進・攻撃モーション（z_index=5）よりも前面に盾を描画して防御壁として正しく機能させる
		s.visible = true

		var target_p = Vector2(
			7200.0 * (float(i) + 0.5) / float(max(1, spawn_shield_cnt)) + 12300.0,
			-1000.0 / float(max(1, spawn_shield_cnt * 2)) * (randi() % max(1, spawn_shield_cnt * 2)) + 3800.0
		)
		var v = Vector2(abs(s.position.x - target_p.x) / 108.0, abs(s.position.y - target_p.y) / 108.0)

		active_shields.append({
			"node": s,
			"t": -float(i * 70) / float(max(1, spawn_shield_cnt)),
			"target_p": target_p,
			"v": v,
			"has_arrived": false
		})
		mshisvalid = true

## 敵の攻撃モーション（安全なbase_scale絶対指定 ＆ スプライトシート対応）
func _set_enemy_attack_motion(sm: Node2D, forward: bool) -> void:
	if sm == null or sm.enemy == null:
		return
	if forward:
		if sm.has_method("play_enemy_animation") and sm.has_enemy_animation("attack"):
			sm.play_enemy_animation("attack")
		else:
			var base_s: Vector2 = sm.enemy.get_meta("base_scale", Vector2(0.5, 0.5))
			sm.enemy.scale = base_s * 1.35
	else:
		if sm.has_method("is_playing_custom_animation") and sm.is_playing_custom_animation:
			pass
		elif sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack"):
			pass
		else:
			var base_s: Vector2 = sm.enemy.get_meta("base_scale", Vector2(0.5, 0.5))
			sm.enemy.scale = base_s

## 敵が属性スキルを発動するかどうかの判定（発動頻度は全ステージ共通で維持：ボス確定100%、通常敵50%）
func _should_cast_enemy_elemental_skill(sm: Node2D) -> bool:
	if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
		return false
	var elem = sm.get_current_enemy_element() if sm.has_method("get_current_enemy_element") else "無属性"
	if elem == "無属性" or elem == "":
		return false
	var is_boss: bool = sm.is_boss_monster() if sm.has_method("is_boss_monster") else (sm.is_current_boss or sm.stage_enemy == 5)
	# ボスは確定発動、通常敵は50%の確率でスキル発動（発動頻度は固定）
	if not is_boss and randf() > 0.5:
		return false
	return true

## 敵の攻撃処理（物理攻撃・爪斬撃演出・ダメージ計算）
var _enemy_turn_actions: Array = []
var is_enemy_turn_in_progress: bool = false
var _enemy_turn_tween: Tween = null

func _is_5th_boss_enemy(sm: Node2D, e: Dictionary) -> bool:
	if sm == null: return false
	var e_key = e.get("key", "")
	var e_name = e.get("name", "")
	if e_key == "enemy18" or e_name == "冥王デモニアス":
		return true
	if sm.stage == 5 and sm.stage_enemy == 5:
		if sm.active_enemies.size() > 0 and e == sm.active_enemies[0]:
			return true
	if sm.get("islastboss") == true:
		if sm.active_enemies.size() > 0 and e == sm.active_enemies[0]:
			return true
	return false

func _calc_enemy_turn_duration(sm: Node2D, is_skill_turn: bool) -> int:
	if sm == null or not ("active_enemies" in sm) or sm.active_enemies.is_empty():
		return 60
	
	var total_seconds = 0.0
	if not _enemy_turn_actions.is_empty():
		for act_info in _enemy_turn_actions:
			var action = ""
			var spr = null
			var e_data = {}
			if typeof(act_info) == TYPE_DICTIONARY:
				action = act_info.get("action", "attack")
				e_data = act_info.get("enemy_data", {})
				spr = e_data.get("sprite", null)
			elif typeof(act_info) == TYPE_STRING:
				action = act_info
			
			if e_data.get("just_summoned", false) == true:
				continue
			
			if action == "skill":
				var sk_dur = sm.get_enemy_animation_duration(spr, "skill") if sm.has_method("get_enemy_animation_duration") else 1.2
				total_seconds += maxf(sk_dur, 1.2) + 0.3
			elif action == "summon":
				var sk_dur = sm.get_enemy_animation_duration(spr, "skill") if sm.has_method("get_enemy_animation_duration") else 1.2
				total_seconds += maxf(sk_dur, 1.2) + 0.3
			else:
				var atk_dur = sm.get_enemy_animation_duration(spr, "attack") if sm.has_method("get_enemy_animation_duration") else 0.5
				total_seconds += maxf(atk_dur, 0.5) + 0.25
	else:
		for i in range(sm.active_enemies.size()):
			var e = sm.active_enemies[i]
			if e.get("just_summoned", false) == true:
				continue
			var spr = e.get("sprite")
			if is_skill_turn:
				var sk_dur = sm.get_enemy_animation_duration(spr, "skill") if sm.has_method("get_enemy_animation_duration") else 1.2
				total_seconds += maxf(sk_dur, 1.2) + 0.3
			else:
				var atk_dur = sm.get_enemy_animation_duration(spr, "attack") if sm.has_method("get_enemy_animation_duration") else 0.5
				total_seconds += maxf(atk_dur, 0.5) + 0.25
			
	# 秒数からフレーム数(60fps)に換算し、全体の余韻マージンとして +15フレーム を付加
	return int(ceil(total_seconds * 60.0)) + 15

## 敵がステージ1〜4のボス（確定スキル発動・複数スキル全発動対象）であるかを判定
func _is_stage_1_to_4_boss(sm: Node2D, e: Dictionary) -> bool:
	if sm == null: return false
	if _is_5th_boss_enemy(sm, e): return false
	
	var is_boss: bool = false
	if sm.has_method("is_boss_monster"):
		is_boss = sm.is_boss_monster()
	elif "is_current_boss" in sm:
		is_boss = sm.is_current_boss
	elif "is_boss" in e:
		is_boss = e.get("is_boss", false)
	
	if not is_boss:
		return false
	
	var stage_num: int = sm.stage if ("stage" in sm) else 1
	return stage_num >= 1 and stage_num <= 4

## 敵キャラクターの所持する全スキル（属性名）リストを取得
func _get_enemy_all_skills(e: Dictionary, sm: Node2D) -> Array[String]:
	var key = e.get("key", "slime")
	var sp_data = e.get("sp_data", {})
	if sp_data.is_empty() and sm and "ENEMY_SPECIES" in sm:
		sp_data = sm.ENEMY_SPECIES.get(key, {})
	
	var skills_pool: Array = []
	if sp_data.has("skills") and typeof(sp_data["skills"]) == TYPE_ARRAY and not sp_data["skills"].is_empty():
		skills_pool = sp_data["skills"]
	elif sp_data.has("elements") and typeof(sp_data["elements"]) == TYPE_ARRAY and not sp_data["elements"].is_empty():
		skills_pool = sp_data["elements"]
	elif typeof(sp_data.get("element")) == TYPE_ARRAY:
		skills_pool = sp_data.get("element")
	
	var result: Array[String] = []
	if not skills_pool.is_empty():
		for sk in skills_pool:
			result.append(str(sk))
	else:
		var elem = str(sp_data.get("element", sp_data.get("race", "無属性")))
		result.append(elem)
	return result

## 敵キャラクターの所持スキルから今回の発動スキル（単一または複数候補からランダム）を選出
func _select_enemy_skill(e: Dictionary, sm: Node2D) -> String:
	var key = e.get("key", "slime")
	var sp_data = e.get("sp_data", {})
	if sp_data.is_empty() and sm and "ENEMY_SPECIES" in sm:
		sp_data = sm.ENEMY_SPECIES.get(key, {})
	
	var skills_pool: Array = []
	if sp_data.has("skills") and typeof(sp_data["skills"]) == TYPE_ARRAY and not sp_data["skills"].is_empty():
		skills_pool = sp_data["skills"]
	elif sp_data.has("elements") and typeof(sp_data["elements"]) == TYPE_ARRAY and not sp_data["elements"].is_empty():
		skills_pool = sp_data["elements"]
	elif typeof(sp_data.get("element")) == TYPE_ARRAY:
		skills_pool = sp_data.get("element")
	
	if not skills_pool.is_empty():
		return str(skills_pool[randi() % skills_pool.size()])
	
	return str(sp_data.get("element", sp_data.get("race", "無属性")))

var _cached_settings_manager: Node = null

func _get_settings_manager() -> Node:
	if _cached_settings_manager and is_instance_valid(_cached_settings_manager):
		return _cached_settings_manager
	if is_inside_tree():
		var sm_direct = get_node_or_null("/root/SettingsManager")
		if sm_direct:
			_cached_settings_manager = sm_direct
			return _cached_settings_manager
	var root_node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	elif is_instance_valid(Engine.get_main_loop()) and Engine.get_main_loop().has_method("get_root"):
		root_node = Engine.get_main_loop().get_root()
	if root_node == null:
		var st = Engine.get_main_loop()
		if st and "root" in st:
			root_node = st.root
	if root_node:
		var sm_autoload = root_node.get_node_or_null("SettingsManager")
		if sm_autoload == null:
			sm_autoload = root_node.find_child("SettingsManager", true, false)
		if sm_autoload:
			_cached_settings_manager = sm_autoload
			return _cached_settings_manager
	var p = get_parent()
	while p:
		if p.has_node("SettingsManager"):
			_cached_settings_manager = p.get_node("SettingsManager")
			return _cached_settings_manager
		p = p.get_parent()
	return null

var is_tutorial_mode: bool = false

func _is_tutorial_mode(sm_node: Node = null) -> bool:
	if is_tutorial_mode:
		return true
	if sm_node and sm_node.has_method("_is_tutorial_mode") and sm_node._is_tutorial_mode():
		return true
	if sm_node and "is_tutorial_mode" in sm_node and sm_node.is_tutorial_mode:
		return true
	var sm = _get_settings_manager()
	return (sm != null and "is_tutorial_mode" in sm and sm.is_tutorial_mode)

## 難易度に応じた敵スキル強度倍率を取得 (EASY: 0.70, NORMAL: 1.0, HARD: 1.35)
func _get_difficulty_skill_mult() -> float:
	var sm = _get_settings_manager()
	if sm and sm.has_method("get_difficulty_skill_mult"):
		return sm.get_difficulty_skill_mult()
	return 1.0

func _decide_enemy_actions(sm: Node2D) -> bool:
	_enemy_turn_actions.clear()
	var has_skill = false
	if sm and "active_enemies" in sm:
		var sim_enemy_count = sm.active_enemies.size()
		for i in range(sm.active_enemies.size()):
			var e = sm.active_enemies[i]
			# 召喚されたモンスターは召喚されたターンに行動してはいけない
			if e.get("just_summoned", false) == true:
				continue
			var is_5th = _is_5th_boss_enemy(sm, e)
			if is_5th:
				# 5番目のボスは2回行動（ランダムに攻撃、スキル、使徒召喚）
				for _act_step in range(2):
					var pool: Array[String] = ["attack", "skill"]
					if sim_enemy_count < 3:
						pool.append("summon")
					var chosen_action: String = pool[randi() % pool.size()]
					if chosen_action == "summon":
						sim_enemy_count += 1
					if chosen_action == "skill" or chosen_action == "summon":
						has_skill = true
					var chosen_skill = ""
					if chosen_action == "skill":
						chosen_skill = _select_enemy_skill(e, sm)
					_enemy_turn_actions.append({"enemy_index": i, "enemy_data": e, "action": chosen_action, "chosen_skill": chosen_skill})
			elif _is_stage_1_to_4_boss(sm, e):
				# 1〜4のボス：各ターンスキルを発動し、複数のスキルを持っている場合はすべてのスキルを発動する
				var all_skills = _get_enemy_all_skills(e, sm)
				has_skill = true
				if all_skills.size() > 1:
					for sk in all_skills:
						_enemy_turn_actions.append({"enemy_index": i, "enemy_data": e, "action": "skill", "chosen_skill": sk})
				else:
					var chosen_skill = all_skills[0] if not all_skills.is_empty() else _select_enemy_skill(e, sm)
					_enemy_turn_actions.append({"enemy_index": i, "enemy_data": e, "action": "skill", "chosen_skill": chosen_skill})
			else:
				var is_boss = false
				if sm.has_method("is_boss_monster"): is_boss = sm.is_boss_monster()
				else: is_boss = sm.is_current_boss if "is_current_boss" in sm else false
				
				var action = "attack"
				var chosen_skill = ""
				var is_tut: bool = _is_tutorial_mode(sm)
				var skill_chance = 0.50 * _get_difficulty_skill_mult()
				if is_tut:
					if sm.stage <= 1:
						action = "attack"
					else:
						action = "skill"
						has_skill = true
						chosen_skill = _select_enemy_skill(e, sm)
				elif is_boss or randf() < skill_chance:
					action = "skill"
					has_skill = true
					chosen_skill = _select_enemy_skill(e, sm)
				_enemy_turn_actions.append({"enemy_index": i, "enemy_data": e, "action": action, "chosen_skill": chosen_skill})
	if sm and sm.has_method("update_enemy_intents"):
		sm.update_enemy_intents(_enemy_turn_actions)
	return has_skill

class SlashEffectNode extends Node2D:
	var life_time: float = 0.0
	func _process(delta: float) -> void:
		var _prof = Profiler.begin("puzzle_board::_process")
		life_time += delta
		if life_time > 0.25:
			set_process(false)
			queue_free()
			Profiler.queue_free_count += 1
			return
		queue_redraw()
	func _draw() -> void:
		var _prof = Profiler.begin("puzzle_board::_draw")
		var p = clampf(1.0 - (life_time / 0.25), 0.0, 1.0)
		var col = Color(1.0, 1.0, 1.0, p)
		draw_line(Vector2(-60, -60), Vector2(60, 60), col, 12.0 * p)
		draw_line(Vector2(-60, 60), Vector2(60, -60), col, 6.0 * p)

func _spawn_slash_effect(pos: Vector2) -> void:
	var root_node = get_parent() if get_parent() != null else self
	var node = SlashEffectNode.new()
	node.position = pos
	Profiler.add_child_count += 1
	root_node.add_child(node)

func _execute_enemy_turn_actions(sm: Node2D, synchronous: bool = false) -> void:
	if enemy_turn_skip_count > 0:
		enemy_turn_skip_count -= 1
		has_enemy_attacked = true
		is_enemy_turn_in_progress = false
		_show_enemy_skill_banner("❄️ 絶対零度・時間停止", "#80D8FF", false, "【絶対零度】極限の冷気により敵の行動が完全スキップされた！")
		_spawn_floating_text(Vector2(640, 360), "❄️ 敵は凍結して行動不能！", Color(0.4, 0.9, 1.0))
		return
	if has_enemy_attacked: return
	has_enemy_attacked = true
	if sm == null or sm.isdeadf or sm.ehp <= 0: return

	var se_vol: float = 1.0
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	if sm_autoload and "se_volume" in sm_autoload:
		se_vol = clampf(sm_autoload.se_volume, 0.001, 1.0)

	if not ("active_enemies" in sm) or sm.active_enemies.size() == 0:
		is_enemy_turn_in_progress = false
		return

	if _enemy_turn_actions.is_empty():
		_decide_enemy_actions(sm)

	is_enemy_turn_in_progress = true
	if _enemy_turn_tween and _enemy_turn_tween.is_valid():
		_enemy_turn_tween.kill()

	var seq_tw: Tween = null
	if not synchronous and is_inside_tree() and get_tree() != null:
		seq_tw = create_tween()
		_enemy_turn_tween = seq_tw
	
	for act_idx in range(_enemy_turn_actions.size()):
		var act_info = _enemy_turn_actions[act_idx]
		var action = "attack"
		var e = {}
		var e_idx = 0
		if typeof(act_info) == TYPE_DICTIONARY:
			action = act_info.get("action", "attack")
			e = act_info.get("enemy_data", {})
			e_idx = act_info.get("enemy_index", 0)
		elif typeof(act_info) == TYPE_STRING:
			action = act_info
			if act_idx < sm.active_enemies.size():
				e = sm.active_enemies[act_idx]
				e_idx = act_idx
		
		if e.is_empty() and e_idx < sm.active_enemies.size():
			e = sm.active_enemies[e_idx]
		
		# 召喚されたモンスターは召喚されたターンに行動してはいけない
		if e.get("just_summoned", false) == true:
			continue
		
		var spr = e.get("sprite", null)
		var atk = e.get("atk", 10.0)
		
		# 行動する敵へズームイン演出（敵画面内限定）
		if sm and sm.has_method("zoom_on_attacking_enemy"):
			if seq_tw != null:
				seq_tw.tween_callback(func():
					if is_instance_valid(sm):
						sm.zoom_on_attacking_enemy(e_idx)
				)
			elif is_instance_valid(sm):
				sm.zoom_on_attacking_enemy(e_idx)
		
		if action == "attack":
			var anim_dur = sm.get_enemy_animation_duration(spr, "attack") if (sm and sm.has_method("get_enemy_animation_duration")) else ENEMY_ATTACK_MOTION_DURATION
			anim_dur = maxf(anim_dur, 0.45)
			var effect_delay = minf(0.24, anim_dur * 0.4)
			var after_delay = maxf(0.15, anim_dur - effect_delay + 0.1)

			var anim_cb = func():
				if not is_instance_valid(spr) or sm == null or sm.isdeadf or sm.ehp <= 0: return
				
				# 5番目のボス（冥王デモニアス等）の2回行動時、攻撃アクションの発生を明確に告知
				var is_5th = _is_5th_boss_enemy(sm, e)
				if is_5th:
					_show_enemy_skill_banner("冥王の強撃", "#FF1744", true, "【冥王の追撃】強烈な一撃を繰り出す！")
				
				var has_anim = false
				if sm.has_method("play_single_enemy_animation"):
					has_anim = sm.play_single_enemy_animation(spr, "attack")
					
				if not has_anim and is_inside_tree() and get_tree() != null:
					var orig_pos = spr.position
					var atk_tw = create_tween()
					if atk_tw != null:
						atk_tw.bind_node(spr)
						spr.set_meta("rush_tween", atk_tw)
						atk_tw.tween_property(spr, "position", orig_pos + Vector2(-80, 0), anim_dur * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						atk_tw.tween_property(spr, "position", orig_pos, anim_dur * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
						atk_tw.tween_callback(func(): if is_instance_valid(spr): spr.position = orig_pos)

			var dmg_cb = func():
				if not is_instance_valid(spr) or sm == null or sm.isdeadf or sm.ehp <= 0: return
				
				_play_pooled_se(ENEMY_ATTACK_SE, linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5)), 1.0)
				_spawn_slash_effect(spr.global_position + Vector2(-80, 0))
				
				var effective_shield_cnt: float = 0.0
				for el in current_shield_pools:
					effective_shield_cnt += current_shield_pools[el]
			
				effective_shield_cnt = maxf(effective_shield_cnt, float(active_shields.size()))
			
				var e_name = e.get("key", e.get("name", "slime"))
				var atk_el = 0
				if sm: atk_el = ElementDataScript.get_element_from_enemy_name(e_name, sm)
			
				# 🧪 毒C1 麻痺毒: 毒マス数に応じた敵攻撃不発判定 (最大30%)
				var ally_poi_cnt = 0
				if grid_poison.size() == GRID_ROWS:
					for pr in range(GRID_ROWS):
						for pc in range(GRID_COLUMNS):
							if grid_poison[pr][pc] and is_ally_poison(pr, pc):
								ally_poi_cnt += 1
				if ally_poi_cnt > 0 and has_actor_skill_trait(true, "poison", "poison_final_c1"):
					var paralyze_chance = minf(0.30, float(ally_poi_cnt) * 0.03)
					if randf() < paralyze_chance:
						_spawn_floating_text(spr.position, "🧪 麻痺毒！敵攻撃不発！", Color(0.7, 0.2, 0.9))
						return

				# ⚡ 雷C2 静電気: 感電スタックを持つ相手が攻撃行動を行うたびスタック比例自傷
				if enemy_shock_stacks > 0 and has_actor_skill_trait(true, "thunder", "thunder_final_c2"):
					var sc_m = _get_score_manager()
					var sk_lvl_th = maxi(1, sc_m.get_skill_level("thunder_1")) if (sc_m and sc_m.has_method("get_skill_level")) else 1
					var static_dmg = float(enemy_shock_stacks) * (60.0 + sk_lvl_th * 15.0) * pow(10.0, max(0, (sm.stage - 1) if sm else 0))
					sm.calchp(static_dmg, 0.0)
					_emit_combat_event("damage", "ally", "enemy", static_dmg, "thunder_static_shock")
					_spawn_floating_text(spr.position if is_instance_valid(spr) else Vector2(640, 360), "⚡ 静電気自傷 -%d! (スタック%d)" % [int(static_dmg), enemy_shock_stacks], Color(1.0, 0.9, 0.2))
					enemy_shock_stacks = maxi(0, enemy_shock_stacks - 1)

				# ❄️ 寒気 (ice_final_c1) & 🧪 弱体 (poison_mid_c): 敵攻撃力低下デバフ
				var debuff_rate = 0.0
				if has_actor_skill_trait(true, "ice", "ice_final_c1"):
					var ally_ice_cnt = 0
					if grid_ice.size() == GRID_ROWS:
						for ir in range(GRID_ROWS):
							for ic in range(GRID_COLUMNS):
								if int(grid_ice[ir][ic]) > 0 and is_ally_ice(ir, ic):
									ally_ice_cnt += 1
					debuff_rate += minf(0.30, float(ally_ice_cnt) * 0.03)
				if has_actor_skill_trait(true, "poison", "poison_mid_c"):
					debuff_rate += minf(0.30, float(ally_poi_cnt) * 0.03)

				var base_atk_val = float(atk) * maxf(0.40, 1.0 - debuff_rate)
				var total_blocked = 0.0
				var remaining_atk = base_atk_val

				if effective_shield_cnt > 0.0:
					var blocked_per_shield = (base_atk_val - (base_atk_val / (effective_shield_cnt + 1.0))) / effective_shield_cnt

					var shield_list = []
					for el in current_shield_pools:
						var count = current_shield_pools[el]
						if count <= 0.0: continue
						var mult = 1.0
						if el != 0 and atk_el != 0:
							mult = ElementDataScript.get_damage_multiplier(atk_el, el)
						shield_list.append({"el": el, "count": count, "mult": mult})

					shield_list.sort_custom(func(a, b): return a["mult"] < b["mult"])

					for s_data in shield_list:
						var el = s_data["el"]
						var count = s_data["count"]
						var mult = s_data["mult"]

						var capacity = count * blocked_per_shield / mult
						var block_amount = min(remaining_atk, capacity)

						total_blocked += block_amount
						remaining_atk -= block_amount

						if remaining_atk <= 0.0:
							break

				# ❄️ 氷A2: 氷柱反撃 (シールド防御分を敵へ反射)
				if total_blocked > 0.0 and has_actor_skill_trait(true, "ice", "ice_final_a2"):
					sm.calchp(total_blocked, 0.0)
					_spawn_floating_text(Vector2(640, 360), "❄️ 氷柱反撃！シールド防御分を反射 -%d!" % int(total_blocked), Color(0.5, 0.85, 1.0))

				var incoming_damage = maxf(0.0, remaining_atk)
				var pre_mitigation_damage = incoming_damage
				var rm = _get_relic_manager()
				if rm:
					incoming_damage = rm.modify_damage_taken(incoming_damage, {"element": atk_el})

				# 🌱 木B1: 森の加護 (-5%/本, 最大40%) & 🪨 地A1: 城壁 (-5%/個, 最大40%)
				if has_actor_skill_trait(true, "wood", "wood_final_b1"):
					var a_pl_cnt = 0
					for pl in plant_entities:
						if is_ally_plant(pl): a_pl_cnt += 1
					incoming_damage *= (1.0 - minf(0.40, float(a_pl_cnt) * 0.05))
				if has_actor_skill_trait(true, "earth", "earth_final_a1"):
					var a_st_cnt = 0
					if grid_stones.size() == GRID_ROWS:
						for sr in range(GRID_ROWS):
							for sc in range(GRID_COLUMNS):
								if grid_stones[sr][sc] > 0 and is_ally_stone(sr, sc):
									a_st_cnt += 1
					incoming_damage *= (1.0 - minf(0.40, float(a_st_cnt) * 0.05))

				# 🌱 木B: 茨 (植物の数に応じた反撃ダメージ)
				if incoming_damage > 0.0 and has_actor_skill_trait(true, "wood", "wood_mid_b") and not plant_entities.is_empty():
					var score_mgr_def = _get_score_manager()
					var stage_scale_def = pow(10, max(0, (sm.stage - 1) if sm else 0))
					var sk_lvl_wd = maxi(1, score_mgr_def.get_skill_level("wood_1")) if score_mgr_def else 1
					var thorn_dmg = float(plant_entities.size()) * (50.0 + sk_lvl_wd * 15.0) * stage_scale_def
					sm.calchp(thorn_dmg, 0.0)
					_emit_combat_event("damage", "ally", "enemy", thorn_dmg, "wood_thorns")
					_spawn_floating_text(sm.enemy.position if sm.enemy else Vector2(1550, 250), "🌱 茨反射 -%d!" % int(thorn_dmg), Color(0.4, 0.9, 0.3))

				# ✨ 光B: 聖域 (発動ターン被ダメージ25%減)
				if has_light_dazzle_this_turn or has_light_sanctuary_this_turn:
					incoming_damage *= 0.75
					_spawn_floating_text(Vector2(640, 360), "✨ 聖域結界！被ダメージ-25%", Color(1.0, 0.95, 0.5))

				# 🛡️ 防御スタック合計キャップ（最大75%カット、最低25%保障）
				if pre_mitigation_damage > 0.0:
					var min_dmg = pre_mitigation_damage * 0.25
					if incoming_damage < min_dmg:
						incoming_damage = min_dmg

				if rm and sm:
					incoming_damage = rm.check_fatal_damage(sm.myhp, incoming_damage)

				# 🌙 闇C: 混沌・反動 (戦闘で受けたダメージを蓄積、最大5000)
				if incoming_damage > 0.0 and has_actor_skill_trait(true, "dark", "dark_mid_c"):
					dark_accumulated_damage = minf(5000.0, dark_accumulated_damage + incoming_damage * 0.50)

				turn_damage_taken += incoming_damage
				var event_payload = {"blocked_amount": total_blocked}

				if incoming_damage > 0.0:
					_play_pooled_se(UTU2_SE, linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5)), 1.0)
					_spawn_screen_flash(Color(0.8, 0.1, 0.1, 0.35), 0.3)
					_trigger_screen_shake(20.0 + minf(incoming_damage * 0.05, 30.0))

				if sm:
					var en_name_str = e.get("name", "モンスター")
					var is_5th_atk = _is_5th_boss_enemy(sm, e)
					if is_5th_atk:
						sm.last_damage_cause = "【%s】の強撃" % en_name_str
					else:
						sm.last_damage_cause = "【%s】の攻撃" % en_name_str
				sm.calchp(0, incoming_damage)
				_emit_combat_event("damage", "enemy", "ally", incoming_damage, "", false, "normal", event_payload)
				if sm.myhp <= 0:
					_trigger_gameover(sm)

			if seq_tw != null:
				seq_tw.tween_callback(anim_cb)
				seq_tw.tween_interval(effect_delay)
				seq_tw.tween_callback(dmg_cb)
				seq_tw.tween_interval(after_delay)
			else:
				anim_cb.call()
				dmg_cb.call()

		elif action == "summon":
			var sk_anim_dur = sm.get_enemy_animation_duration(spr, "skill") if (sm and sm.has_method("get_enemy_animation_duration")) else 1.2
			sk_anim_dur = maxf(sk_anim_dur, 1.2)
			var chant_delay = 0.75
			var after_summon_delay = maxf(0.5, sk_anim_dur - chant_delay + 0.1)

			var chant_cb = func():
				if not is_instance_valid(spr) or sm == null or sm.isdeadf or sm.ehp <= 0: return
				_play_enemy_skill_se(true)
				_show_enemy_skill_banner("冥府の号令・使徒召喚", "#D500F9", true, "【使徒召喚】冥界より下僕を召喚する！")
				
				var has_anim = false
				if sm.has_method("play_single_enemy_animation"):
					has_anim = sm.play_single_enemy_animation(spr, "skill")
				
				if not has_anim and is_instance_valid(spr) and is_inside_tree() and get_tree() != null:
					var orig_s = spr.get_meta("anim_orig_scale", spr.scale)
					var sk_tw = create_tween()
					if sk_tw != null:
						sk_tw.bind_node(spr)
						spr.set_meta("rush_tween", sk_tw)
						sk_tw.tween_property(spr, "scale", orig_s * 1.3, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						sk_tw.tween_property(spr, "scale", orig_s, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					
				_spawn_enemy_skill_chant_vfx(sm, spr, "#D500F9", true)

			var summon_cb = func():
				if sm == null or sm.isdeadf or sm.ehp <= 0: return
				if sm.has_method("summon_boss_minion"):
					var res = sm.summon_boss_minion()
					if not res.is_empty():
						_spawn_floating_text(Vector2(BOARD_LEFT + BOARD_WIDTH * 0.5, BOARD_TOP + 80), "使徒召喚！", Color(0.9, 0.4, 1.0))

			if seq_tw != null:
				seq_tw.tween_callback(chant_cb)
				seq_tw.tween_interval(chant_delay)
				seq_tw.tween_callback(summon_cb)
				seq_tw.tween_interval(after_summon_delay)
			else:
				chant_cb.call()
				summon_cb.call()

		else:
			var is_boss = false
			if sm.has_method("is_boss_monster"): is_boss = sm.is_boss_monster()
			else: is_boss = sm.is_current_boss if "is_current_boss" in sm else false
			
			var elem = ""
			if typeof(act_info) == TYPE_DICTIONARY and act_info.has("chosen_skill") and not str(act_info["chosen_skill"]).is_empty():
				elem = str(act_info["chosen_skill"])
			else:
				elem = _select_enemy_skill(e, sm)
			var s_info = _get_enemy_skill_info(elem, is_boss)
			var s_name = s_info["name"]
			var elem_color = s_info["color"]
			
			var sk_anim_dur = sm.get_enemy_animation_duration(spr, "skill") if (sm and sm.has_method("get_enemy_animation_duration")) else 1.2
			sk_anim_dur = maxf(sk_anim_dur, 1.2)
			var chant_delay = 0.8
			var after_skill_delay = maxf(0.5, sk_anim_dur - chant_delay + 0.1)

			var skill_chant_cb = func():
				if not is_instance_valid(spr) or sm == null or sm.isdeadf or sm.ehp <= 0: return
				_play_enemy_skill_se(is_boss)
				_show_enemy_skill_banner(s_name, elem_color, is_boss)
				
				var has_anim = false
				if sm.has_method("play_single_enemy_animation"):
					has_anim = sm.play_single_enemy_animation(spr, "skill")
				
				if not has_anim and is_instance_valid(spr) and is_inside_tree() and get_tree() != null:
					var orig_s = spr.get_meta("anim_orig_scale", spr.scale)
					var sk_tw = create_tween()
					if sk_tw != null:
						sk_tw.bind_node(spr)
						spr.set_meta("rush_tween", sk_tw)
						sk_tw.tween_property(spr, "scale", orig_s * 1.25, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						sk_tw.tween_property(spr, "scale", orig_s, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					
				_spawn_enemy_skill_chant_vfx(sm, spr, elem_color, is_boss)

			var skill_exec_cb = func():
				if sm == null or sm.isdeadf or sm.ehp <= 0: return
				var tgs = _apply_enemy_elemental_skill_effect(elem, is_boss)
				_spawn_enemy_skill_beam_and_burst(sm, spr, elem_color, is_boss, tgs)

			if seq_tw != null:
				seq_tw.tween_callback(skill_chant_cb)
				seq_tw.tween_interval(chant_delay)
				seq_tw.tween_callback(skill_exec_cb)
				seq_tw.tween_interval(after_skill_delay)
			else:
				skill_chant_cb.call()
				skill_exec_cb.call()

	var cleanup_cb = func():
		is_enemy_turn_in_progress = false
		if sm and sm.has_method("reset_enemy_zoom"):
			sm.reset_enemy_zoom()
		for item in active_shields:
			if is_instance_valid(item["node"]): _return_sprite_to_pool(item["node"])
		active_shields.clear()
		current_shield_pools.clear()
		current_total_shields = 0
		if sm and "active_enemies" in sm:
			for en_data in sm.active_enemies:
				en_data["just_summoned"] = false
		if sm and sm.myhp <= 0:
			_trigger_gameover(sm)

	if seq_tw != null:
		seq_tw.tween_callback(cleanup_cb)
	else:
		cleanup_cb.call()
func _execute_enemy_attack(sm: Node2D) -> void:
	if has_enemy_attacked: return
	has_enemy_attacked = true
	if sm == null or sm.isdeadf or sm.ehp <= 0: return

	var se_vol: float = 1.0
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	if sm_autoload and "se_volume" in sm_autoload:
		se_vol = clampf(sm_autoload.se_volume, 0.001, 1.0)



	if not ("active_enemies" in sm) or sm.active_enemies.size() == 0:
		return

	var seq_tw = create_tween()
	for e in sm.active_enemies:
		var spr = e["sprite"]
		var atk = e["atk"]
		seq_tw.tween_callback(func():
			if not is_instance_valid(spr): return
			
			var orig_pos = spr.position
			var atk_tw = create_tween()
			atk_tw.tween_property(spr, "position", orig_pos + Vector2(-60, 0), 0.1)
			atk_tw.tween_property(spr, "position", orig_pos, 0.2).set_delay(0.1)
			
			_play_pooled_se(ENEMY_ATTACK_SE, linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5)), 1.0)
				
			var effective_shield_cnt: float = 0.0
			for el in current_shield_pools:
				effective_shield_cnt += current_shield_pools[el]
			
			effective_shield_cnt = maxf(effective_shield_cnt, float(active_shields.size()))
			
			var e_name = e.get("key", e.get("name", "slime"))
			var atk_el = 0
			if sm: atk_el = ElementDataScript.get_element_from_enemy_name(e_name, sm)
			
			var total_blocked = 0.0
			var remaining_atk = float(atk)
			
			if effective_shield_cnt > 0.0:
				var blocked_per_shield = (float(atk) - (float(atk) / (effective_shield_cnt + 1.0))) / effective_shield_cnt
				
				var shield_list = []
				for el in current_shield_pools:
					var count = current_shield_pools[el]
					if count <= 0.0: continue
					var mult = 1.0
					if el != 0 and atk_el != 0:
						mult = ElementDataScript.get_damage_multiplier(atk_el, el)
					shield_list.append({"el": el, "count": count, "mult": mult})
				
				shield_list.sort_custom(func(a, b): return a["mult"] < b["mult"])
				
				for s_data in shield_list:
					var el = s_data["el"]
					var count = s_data["count"]
					var mult = s_data["mult"]
					
					var capacity = count * blocked_per_shield / mult
					var block_amount = min(remaining_atk, capacity)
					
					total_blocked += block_amount
					remaining_atk -= block_amount
					
					if remaining_atk <= 0.0:
						break
			
			var incoming_damage = maxf(0.0, remaining_atk)
			var rm = _get_relic_manager()
			if rm:
				incoming_damage = rm.modify_damage_taken(incoming_damage, {"element": atk_el})
				if sm: incoming_damage = rm.check_fatal_damage(sm.myhp, incoming_damage)
			var event_payload = {"blocked_amount": total_blocked}
			
			if incoming_damage > 0.0:
				_play_pooled_se(UTU2_SE, linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5)), 1.0)
				_spawn_screen_flash(Color(0.8, 0.1, 0.1, 0.35), 0.3)
				_trigger_screen_shake(20.0 + minf(incoming_damage * 0.05, 30.0))
			
				if sm:
					var en_name_str = e.get("name", "モンスター")
					sm.last_damage_cause = "【%s】の攻撃" % en_name_str
				sm.calchp(0, incoming_damage)
				_emit_combat_event("damage", "enemy", "ally", incoming_damage, "", false, "normal", event_payload)
		)
		seq_tw.tween_interval(0.3)
		
	# すべての敵の攻撃が終わった後にシールドを消去し、ゲームオーバー判定を行う
	seq_tw.tween_callback(func():
		for item in active_shields:
			if is_instance_valid(item["node"]): _return_sprite_to_pool(item["node"])
		active_shields.clear()
		current_total_shields = 0
		
		if sm and sm.myhp <= 0:
			_trigger_gameover(sm)
	)
## 各属性スキルの情報（スキル名・演出カラー）の取得
func _get_enemy_skill_info(elem: String, is_boss: bool) -> Dictionary:
	match elem:
		"水属性":
			return {"name": "怒涛・タイダルウェイブ" if is_boss else "アクアサージ", "color": "#00E5FF"}
		"氷属性":
			return {"name": "絶対零度・ブリザード" if is_boss else "フロストロック", "color": "#80DEEA"}
		"風属性":
			return {"name": "滅神風・テンペスト" if is_boss else "ダウンバースト", "color": "#64FFDA"}
		"木属性":
			return {"name": "樹縛・ユグドラシル" if is_boss else "ヴァインソーン", "color": "#76FF03"}
		"地属性":
			return {"name": "大地激震・ガイアクエイク" if is_boss else "ロックフォール", "color": "#BCAAA4"}
		"雷属性":
			return {"name": "神鳴・トールハンマー" if is_boss else "ライトニングボルト", "color": "#FFD600"}
		"闇属性":
			var sm_info = _get_stage_manager()
			var is_5th_boss_info: bool = is_boss and sm_info != null and (
				sm_info.stage == 5 or _get_stage_index() >= 4 or
				(sm_info.has_method("is_boss_battle") and sm_info.is_boss_battle() and sm_info.stage == 5) or
				(sm_info.get("islastboss") == true) or
				(sm_info.get("current_enemy_key") == "enemy18")
			)
			var s_name_d = ("冥府降臨・アビスディメンション" if is_5th_boss_info else "終焉の夜・アビスディメンション") if is_boss else "シャドウベール＆カース"
			return {"name": s_name_d, "color": "#E040FB"}
		"光属性":
			return {"name": "極光・ホーリージャッジ" if is_boss else "シャイニングレイ", "color": "#FFF59D"}
		"火属性":
			return {"name": "紅蓮・ヘルフレイム" if is_boss else "ブレイズブラスト", "color": "#FF3D00"}
		"毒属性":
			return {"name": "猛毒瘴気・デッドリーヴェノム" if is_boss else "ポイズンバースト", "color": "#AB47BC"}
		_:
			return {"name": "アースクエイク", "color": "#BCAAA4"}

## 属性スキル発動演出
func _execute_enemy_elemental_skill(sm: Node2D) -> void:
	if has_enemy_skilled:
		return
	has_enemy_skilled = true

	if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
		return

	if sm.get("active_enemies") and sm.active_enemies.size() > 0:
		var seq_tw = create_tween()
		for e in sm.active_enemies:
			var key = e.get("key", "slime")
			var is_boss = false
			if sm.has_method("is_boss_monster"):
				is_boss = sm.is_boss_monster()
			else:
				is_boss = sm.is_current_boss if "is_current_boss" in sm else false
				
			var sp_data = {}
			if "ENEMY_SPECIES" in sm:
				sp_data = sm.ENEMY_SPECIES.get(key, {})
				
			var elem = sp_data.get("element", sp_data.get("race", "???"))
			if typeof(elem) == TYPE_ARRAY:
				elem = elem[randi() % elem.size()]
				
			var s_info = _get_enemy_skill_info(elem, is_boss)
			var s_name = s_info["name"]
			var elem_color = s_info["color"]
			var spr = e.get("sprite")
			
			seq_tw.tween_callback(func():
				_play_enemy_skill_se(is_boss)
				_show_enemy_skill_banner(s_name, elem_color, is_boss)
				_spawn_enemy_skill_chant_vfx(sm, sm.enemy, elem_color, is_boss)
				if is_instance_valid(spr):
					# 簡単なアニメーション
					var tw = create_tween()
					tw.tween_property(spr, "scale", spr.scale * 1.1, 0.2)
					tw.tween_property(spr, "scale", spr.scale, 0.2)
			)
			seq_tw.tween_interval(0.70)
			seq_tw.tween_callback(func():
				if sm == null or sm.isdeadf or sm.ehp <= 0:
					return
				var targets = _apply_enemy_elemental_skill_effect(elem, is_boss)
				_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, elem_color, is_boss, targets)
			)
			seq_tw.tween_interval(0.5)
	else:
		var is_boss: bool = sm.is_boss_monster() if sm.has_method("is_boss_monster") else (sm.is_current_boss or sm.stage_enemy == 5)
		var elem = sm.get_current_enemy_element() if sm.has_method("get_current_enemy_element") else "???"
		var s_info = _get_enemy_skill_info(elem, is_boss)
		var s_name: String = s_info["name"]
		var elem_color: String = s_info["color"]

		_play_enemy_skill_se(is_boss)
		_show_enemy_skill_banner(s_name, elem_color, is_boss)
		if sm.has_method("play_enemy_animation") and sm.has_enemy_animation("skill"):
			sm.play_enemy_animation("skill")
		_spawn_enemy_skill_chant_vfx(sm, sm.enemy, elem_color, is_boss)

		var tw_cast = create_tween()
		tw_cast.tween_interval(0.70)
		tw_cast.tween_callback(func():
			if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
				return
			var targets = _apply_enemy_elemental_skill_effect(elem, is_boss)
			_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, elem_color, is_boss, targets)
		)
## 現在のステージ進行度に応じた難易度インデックスを取得 (0: Stage 1, 1: Stage 2, ...)
func _get_stage_index() -> int:
	var sm = _get_stage_manager()
	return clampi((sm.stage - 1) if sm else 0, 0, 10)

## 盤面への各属性妨害効果の適用
func _apply_enemy_elemental_skill_effect(elem: String, is_boss: bool) -> Array[Vector2]:
	# ✨ 後光の像 (light_final_b1) は _check_and_block_enemy_hazard 内で
	#    聖像の周囲4マス（上下左右）の妨害マス設置のみを遮断する（敵スキル全体は無効化しない）
	match elem:
		"水属性":
			return _cast_enemy_water_skill(is_boss, false)
		"氷属性":
			return _cast_enemy_ice_skill(is_boss, false)
		"風属性":
			return _cast_enemy_wind_skill(is_boss, false)
		"木属性":
			return _cast_enemy_wood_skill(is_boss, false)
		"地属性":
			return _cast_enemy_earth_skill(is_boss, false)
		"雷属性":
			return _cast_enemy_lightning_skill(is_boss, false)
		"闇属性":
			return _cast_enemy_dark_skill(is_boss, false)
		"光属性":
			return _cast_enemy_light_skill(is_boss, false)
		"火属性":
			return _cast_enemy_fire_skill(is_boss, false)
		"毒属性":
			return _cast_enemy_poison_skill(is_boss, false)
		_:
			return _cast_enemy_earth_skill(is_boss, false)

## 敵スキル専用効果音の再生（魔法スキル発動SE）
func _play_enemy_skill_se(is_boss: bool) -> void:
	var se_stream = BUFF2_SE if is_boss else BUFF1_SE
	if se_stream:
		var vol = 0.0
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		_play_pooled_se(se_stream, vol, 1.0)

## スペルビーム飛翔効果音の再生
func _play_spell_beam_se() -> void:
	if ACCEL_SE:
		var vol = 0.0
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		_play_pooled_se(ACCEL_SE, vol, 1.0)

## 敵エリアの詠唱演出（敵発光・巨大化・咆哮シェイク・足元魔法陣展開）
func _spawn_enemy_skill_chant_vfx(sm: Node2D, enemy_sp: Sprite2D, elem_color_hex: String, is_boss: bool) -> void:
	if sm == null or enemy_sp == null:
		return

	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var p = get_parent()
	var root_node = p if p != null else self

	var has_custom_anim = sm.has_method("has_enemy_animation") and sm.has_enemy_animation("skill")
	if not has_custom_anim:
		var base_scale: Vector2 = enemy_sp.get_meta("base_scale", Vector2(0.5, 0.5))
		var orig_mod = Color.WHITE
		var orig_pos = enemy_sp.position

		if enemy_sp.has_meta("active_skill_tween"):
			var old_tw = enemy_sp.get_meta("active_skill_tween")
			if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
				old_tw.kill()
		enemy_sp.scale = base_scale
		enemy_sp.position = orig_pos

		var tw_enemy = create_tween()
		tw_enemy.bind_node(enemy_sp)
		enemy_sp.set_meta("active_skill_tween", tw_enemy)
		tw_enemy.set_parallel(true)
		tw_enemy.tween_property(enemy_sp, "modulate", Color(elem_col.r * 2.0, elem_col.g * 2.0, elem_col.b * 2.0, 1.0), 0.15)
		var boost_scale = base_scale * (1.38 if is_boss else 1.28)
		tw_enemy.tween_property(enemy_sp, "scale", boost_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		for s_i in range(8):
			var offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
			tw_enemy.chain().tween_property(enemy_sp, "position", orig_pos + offset, 0.04)

		tw_enemy.chain().set_parallel(true)
		tw_enemy.tween_property(enemy_sp, "position", orig_pos, 0.2)
		tw_enemy.tween_property(enemy_sp, "scale", base_scale, 0.2)
		tw_enemy.tween_property(enemy_sp, "modulate", orig_mod, 0.25)
		tw_enemy.chain().tween_callback(func():
			if is_instance_valid(enemy_sp):
				enemy_sp.scale = base_scale
				enemy_sp.modulate = orig_mod
				enemy_sp.position = orig_pos
		)

	var chant_node = SkillVFXNode.new(SkillVFXNode.VFXMode.CHANT_CIRCLE, elem_col, 0.95)
	chant_node.position = enemy_sp.global_position
	var vc = root_node.get_node_or_null("VFXContainer")
	if vc: Profiler.add_child_count += 1; vc.add_child(chant_node)
	else: Profiler.add_child_count += 1; root_node.add_child(chant_node)
## 敵から盤面への属性スペルビーム疾走 ＆ 盤面着弾バースト演出
func _spawn_enemy_skill_beam_and_burst(sm: Node2D, enemy_sp: Sprite2D, elem_color_hex: String, is_boss: bool, targets: Array[Vector2] = []) -> void:
	if sm == null or enemy_sp == null:
		return

	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var p = get_parent()
	var root_node = p if p != null else self

	if targets.is_empty():
		targets.append(Vector2(BOARD_LEFT + BOARD_WIDTH * 0.5, BOARD_TOP + BOARD_HEIGHT * 0.5))

	_play_spell_beam_se()
	
	# 敵位置からの衝撃波で「スキル起点」を視覚的に明示
	_spawn_shockwave_ring(enemy_sp.global_position, elem_col.lightened(0.25), 150.0, 0.30)

	# To prevent massive lag if a skill affects 25 cells, we can cap the number of visual beams to 8
	var visual_targets = targets.duplicate()
	visual_targets.shuffle()
	var max_beams = mini(8, visual_targets.size())
	
	for i in range(max_beams):
		var target_local = visual_targets[i]
		var target_global = to_global(target_local)
		var target_root_local = root_node.to_local(target_global)
		
		var beam_node = SkillVFXNode.new(SkillVFXNode.VFXMode.SPELL_BEAM, elem_col, 0.35)
		beam_node.start_pos = enemy_sp.global_position
		beam_node.target_pos = target_global
		print("[DEBUG] Enemy global: ", enemy_sp.global_position, " Target local: ", target_local, " Target global: ", target_global, " Target root local: ", target_root_local)
		var vc = root_node.get_node_or_null("VFXContainer")
		if vc: Profiler.add_child_count += 1; vc.add_child(beam_node)
		else: Profiler.add_child_count += 1; root_node.add_child(beam_node)

	var tw_burst = create_tween()
	tw_burst.tween_interval(0.30)
	tw_burst.tween_callback(func():
		if not is_instance_valid(root_node): return
		for i in range(max_beams):
			var target_local = visual_targets[i]
			var target_global = to_global(target_local)
			var target_root_local = root_node.to_local(target_global)
			var burst_node = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, elem_col, 0.40)
			burst_node.position = target_root_local
			burst_node.max_radius = 180.0 if is_boss else 140.0
			var vc = root_node.get_node_or_null("VFXContainer")
			if vc: Profiler.add_child_count += 1; vc.add_child(burst_node)
			else: Profiler.add_child_count += 1; root_node.add_child(burst_node)
	)

## プレイヤースキル発動時の属性魔力弾（スペルビーム／彗星弾頭）演出
## 敵の _spawn_enemy_skill_beam_and_burst と同一の SkillVFXNode SPELL_BEAM + BURST_RING を使用
func _spawn_player_skill_beams(origin_pos: Vector2, targets: Array[Vector2], skill_key: String) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if targets.is_empty():
		return

	# スキル属性に応じた属性色を決定
	var elem_col: Color
	match skill_key:
		"fire": elem_col = Color(1.0, 0.4, 0.2)
		"water": elem_col = Color(0.3, 0.6, 1.0)
		"wind": elem_col = Color(0.4, 0.9, 0.4)
		"thunder": elem_col = Color(0.9, 0.9, 0.2)
		"light": elem_col = Color(1.0, 0.9, 0.6)
		"dark": elem_col = Color(0.7, 0.3, 0.9)
		"poison": elem_col = Color(0.67, 0.28, 0.74)
		"ice": elem_col = Color(0.5, 0.85, 1.0)
		"wood": elem_col = Color(0.3, 0.85, 0.4)
		"earth": elem_col = Color(0.85, 0.65, 0.35)
		_: elem_col = Color(0.45, 0.98, 1.0)

	var p = get_parent()
	var root_node = p if p != null else self
	var origin_global = to_global(origin_pos)

	_play_spell_beam_se()

	# 発射元の衝撃波で「スキル起点」を視覚的に明示
	_spawn_shockwave_ring(origin_pos, elem_col.lightened(0.25), 150.0, 0.30)

	# レグレーション: 大量ターゲットでのラグ防止のためビーム最大16本に制限
	# 起点から近い順に描画して、影響範囲が直感的に分かるようにする
	var visual_targets = targets.duplicate()
	visual_targets.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(origin_pos) < b.distance_squared_to(origin_pos)
	)
	var max_beams = mini(16, visual_targets.size())

	for i in range(max_beams):
		var target_global = to_global(visual_targets[i])
		var beam_node = SkillVFXNode.new(SkillVFXNode.VFXMode.SPELL_BEAM, elem_col, 0.35)
		beam_node.start_pos = origin_global
		beam_node.target_pos = target_global
		var vc = root_node.get_node_or_null("VFXContainer")
		if vc: Profiler.add_child_count += 1; vc.add_child(beam_node)
		else: Profiler.add_child_count += 1; root_node.add_child(beam_node)

	# ビーム着弾後にバーストリングを展開
	var tw_burst = create_tween()
	tw_burst.tween_interval(0.30)
	tw_burst.tween_callback(func():
		if not is_instance_valid(root_node): return
		for i in range(max_beams):
			var target_root_local = root_node.to_local(to_global(visual_targets[i]))
			var burst_node = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, elem_col, 0.40)
			burst_node.position = target_root_local
			burst_node.max_radius = 140.0
			var vc = root_node.get_node_or_null("VFXContainer")
			if vc: Profiler.add_child_count += 1; vc.add_child(burst_node)
			else: Profiler.add_child_count += 1; root_node.add_child(burst_node)
	)

## 敵エリアのスキル発動カットインビジュアル演出（互換用）
func _show_enemy_skill_banner(skill_name: String, elem_color_hex: String, is_boss: bool, effect_desc: String = "") -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var custom_font = preload("res://font/g_comickoin_freeR.ttf")
	var p = get_parent()
	var target_parent = p if p != null else self

	# 既存のスキルバナーがあれば直ちに破棄（複数スキル連続発動時に重ならないようにする）
	for child in target_parent.get_children():
		if child is Control and child.name.begins_with("EnemySkillBanner"):
			child.queue_free()

	# スタイル付きバナーパネル
	var panel = Panel.new()
	panel.name = "EnemySkillBanner"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 40

	var has_desc = not effect_desc.is_empty()
	var panel_w = 740.0
	var panel_h = 108.0 if has_desc else 86.0
	panel.size = Vector2(panel_w, panel_h)
	panel.custom_minimum_size = panel.size

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.94)
	style.border_color = Color.from_string(elem_color_hex, Color.GOLD)
	style.set_border_width_all(4 if is_boss else 3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

	# バナー内テキスト
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.fit_content = false
	label.scroll_active = false
	label.add_theme_font_override("normal_font", custom_font)
	label.add_theme_font_override("bold_font", custom_font)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size = Vector2(panel_w, panel_h)
	label.position = Vector2(0, 6)

	var boss_tag = "[color=#FF3D00]☠ BOSS SKILL ☠[/color]" if is_boss else "[color=#FFD700]⚡ 敵スキル発動 ⚡[/color]"
	if has_desc:
		label.text = "[center][font_size=16]%s[/font_size]\n[b][color=%s][font_size=28]『%s』[/font_size][/color][/b]\n[font_size=15][color=#ECEFF1]%s[/color][/font_size][/center]" % [boss_tag, elem_color_hex, skill_name, effect_desc]
	else:
		label.text = "[center][font_size=18]%s[/font_size]\n[b][color=%s][font_size=32]『%s』[/font_size][/color][/b][/center]" % [boss_tag, elem_color_hex, skill_name]
	Profiler.add_child_count += 1; panel.add_child(label)

	if target_parent == p:
		panel.position = Vector2(800.0 - panel_w * 0.5, 30.0)
	else:
		panel.position = Vector2(8000.0 - panel_w * 5.0, 300.0)
		panel.scale = Vector2(10.0, 10.0)

	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	var orig_scale = panel.scale
	panel.scale = orig_scale * 0.8
	Profiler.add_child_count += 1; target_parent.add_child(panel)

	var tw = create_tween()
	# ① フェードイン ＆ ポップ拡大（0.2秒）
	tw.tween_property(panel, "modulate:a", 1.0, 0.20)
	tw.parallel().tween_property(panel, "scale", orig_scale * (1.12 if is_boss else 1.05), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# ② 定常スケールに戻す（0.1秒）
	tw.tween_property(panel, "scale", orig_scale, 0.10)
	# ③ スキル名とバナーをじっくり読ませる表示維持時間（1.6秒）
	tw.tween_interval(1.60)
	# ④ フェードアウト ＆ 上方スライド消去（0.3秒）
	tw.tween_property(panel, "modulate:a", 0.0, 0.30)
	tw.parallel().tween_property(panel, "position:y", panel.position.y - 25.0, 0.30)
	tw.tween_callback(panel.queue_free)

## 敵ハザード設置阻止判定（風の守り・要塞防壁）
func _check_and_block_enemy_hazard(r: int, c: int) -> bool:
	if wind_ward_columns.get(c, 0) > 0:
		var pos = get_cell_position(r, c)
		_spawn_floating_text(pos, "🌪️ 風の守り！妨害阻止！", Color(0.4, 1.0, 0.8))
		return true

	# 🪨 地A 要塞: 味方石の周囲8マスへの敵妨害設置を阻止し、阻止のたび石耐久-1
	if has_actor_skill_trait(true, "earth", "earth_mid_a"):
		if grid_stones.size() == GRID_ROWS:
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					if dr == 0 and dc == 0: continue
					var nr = r + dr; var nc = c + dc
					if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
						if grid_stones[nr][nc] > 0 and is_ally_stone(nr, nc):
							_damage_stone_at(nr, nc, 1)
							var pos = get_cell_position(r, c)
							_spawn_floating_text(pos, "🪨 要塞防壁！妨害阻止！", Color(0.9, 0.7, 0.4))
							return true

	# 🌙 闇 影護: 影護マスの加護により敵妨害（呪い・毒・火・氷・石等）の設置を遮断・防御
	if is_ally_cursed(r, c):
		var pos = get_cell_position(r, c)
		_spawn_floating_text(pos, "🌙 影護！妨害阻止！", Color(0.6, 0.4, 0.95))
		return true

	# ✨ 光 後光の像: 聖像の周囲4マス（上下左右）は敵スキルの妨害マス設置を無効化
	#    敵スキル全体は無効化しない（聖像は消費しない）
	if has_actor_skill_trait(true, "light", "light_final_b1"):
		if grid_gold_statue.size() == GRID_ROWS:
			for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var sr: int = r + off.x
				var sc: int = c + off.y
				if sr < 0 or sr >= GRID_ROWS or sc < 0 or sc >= GRID_COLUMNS:
					continue
				if grid_gold_statue[sr][sc] > 0 and is_ally_gold(sr, sc):
					_spawn_shockwave_ring(get_cell_position(sr, sc), Color(1.0, 0.95, 0.5, 0.85), 150.0, 0.28)
					_spawn_shockwave_ring(get_cell_position(r, c), Color(1.0, 0.9, 0.35, 0.7), 90.0, 0.22)
					_spawn_floating_text(get_cell_position(r, c), "✨ 聖像の加護！妨害無効化", Color(1.0, 1.0, 0.6))
					return true

	return false

## 1. 水属性スキル: 水浸しで操作困難（通常1〜2マス、ボスは初期5〜6マスから緩やかに増加）
func _cast_enemy_water_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "怒涛・タイダルウェイブ" if is_boss else "アクアサージ"
	var s_desc = "【水没】盤面を水浸しにして操作を妨害！"
	if show_banner: _show_enemy_skill_banner(s_name, "#00E5FF", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(5 + st_idx, 6 + st_idx) if is_boss else randi_range(1 + int(st_idx * 1.5), 2 + int(st_idx * 1.5))
	count = maxi(1, int(round(float(count) * diff_m)))

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_water.size() == GRID_ROWS and not grid_water[r][c]:
					cands.append(Vector2i(r, c))
	cands.shuffle()

	var num = mini(count, cands.size())
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		_apply_water_to_cell(p.x, p.y, false)
		_spawn_floating_text(get_cell_position(p.x, p.y), "水没", Color(0.2, 0.8, 1.0))
		_spawn_aqua_splash_effect(get_cell_position(p.x, p.y), 1)
		_targets.append(get_cell_position(p.x, p.y))

	_check_and_trigger_water_fire_synergy(false)
	_redraw_board_effects()
	return _targets

## 水マスに氷が接触した際、連結する水の塊全体を一括で凍結（Flood Fill BFS）
func _freeze_connected_water(start_cell: Vector2i, ice_dur: int, is_ally: bool = false) -> void:
	if grid_water.size() != GRID_ROWS or grid_ice.size() != GRID_ROWS:
		return
	if not grid_water[start_cell.x][start_cell.y]:
		return

	var queue: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {start_cell: true}

	while not queue.is_empty():
		var curr = queue.pop_front()
		# 水マスを解除し、氷漬けにする
		grid_water[curr.x][curr.y] = false
		_set_ally_flag(grid_water_ally, curr.x, curr.y, false)
		grid_ice[curr.x][curr.y] = maxi(int(grid_ice[curr.x][curr.y]), ice_dur)
		_set_ally_flag(grid_ice_ally, curr.x, curr.y, is_ally)
		_spawn_ice_break_effect(get_cell_position(curr.x, curr.y))

		# 上下左右の隣接水マスを探索
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var next_c = curr + offset
			if next_c.x >= 0 and next_c.x < GRID_ROWS and next_c.y >= 0 and next_c.y < GRID_COLUMNS:
				if not visited.has(next_c) and grid_water[next_c.x][next_c.y]:
					visited[next_c] = true
					queue.append(next_c)

## 2. 氷属性スキル: 氷漬けで操作困難（通常1〜2マス・耐久1、ボスは初期4〜5マス・耐久2から緩やかに増加）
func _cast_enemy_ice_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "絶対零度・ブリザード" if is_boss else "フロストロック"
	var s_desc = "【氷結】コマを凍結させて移動不能にする！"
	if show_banner: _show_enemy_skill_banner(s_name, "#80DEEA", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(4 + int(st_idx * 0.75), 5 + int(st_idx * 0.75)) if is_boss else randi_range(1 + int(st_idx * 0.8), 2 + int(st_idx * 0.8))
	count = maxi(1, int(round(float(count) * diff_m)))

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) == 0:
					cands.append(Vector2i(r, c))
	cands.shuffle()

	var num = mini(count, cands.size())
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		var ice_dur = 1
		if is_boss:
			ice_dur = 2 + (1 if (st_idx >= 3 and i < 3) else 0)
		elif st_idx >= 3:
			ice_dur = 2

		# 氷のブレス/スキルが水マスに当たった場合、水の塊ごと全体を一括凍結！
		var cell_p = get_cell_position(p.x, p.y)
		var is_water = (grid_water.size() == GRID_ROWS and grid_water[p.x][p.y] and not is_ally_water(p.x, p.y))
		if is_water:
			_freeze_connected_water(p, ice_dur, false)
			_targets.append(cell_p)
		else:
			grid_ice[p.x][p.y] = ice_dur
			_set_ally_flag(grid_ice_ally, p.x, p.y, false)
			_spawn_floating_text(cell_p, "氷結", Color(0.7, 0.9, 1.0))
			_targets.append(cell_p)

		# 敵位置から対象凍結マスへ氷晶弾を飛翔（視覚的な飛翔軌跡）
		var sm_enemy_ice = _get_stage_manager()
		var enemy_pos = Vector2(BOARD_LEFT + BOARD_WIDTH * 0.5, 200.0)
		if sm_enemy_ice and is_instance_valid(sm_enemy_ice.enemy):
			enemy_pos = sm_enemy_ice.enemy.global_position
		_spawn_ice_shard_projectile(enemy_pos, cell_p, float(i) * 0.08)

	_redraw_board_effects()
	return _targets

## 3. 風属性スキル: 縦1直線の竜巻が非コマオブジェクトを一掃（通常1列、ボスは初期2列から緩やかに増加）
func _cast_enemy_wind_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "滅神風・テンペスト" if is_boss else "ダウンバースト"
	var s_desc = "【突風】縦列の全オブジェクトを一掃消滅！"
	if show_banner: _show_enemy_skill_banner(s_name, "#64FFDA", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var base_min = mini(GRID_COLUMNS - 1, 2 + int(st_idx / 3)) if is_boss else mini(GRID_COLUMNS - 1, 1 + (1 if st_idx >= 3 else 0))
	var base_max = mini(GRID_COLUMNS, 2 + int((st_idx + 1) / 2)) if is_boss else mini(GRID_COLUMNS - 1, 1 + (1 if st_idx >= 3 else 0))
	var num_cols = randi_range(base_min, base_max)
	num_cols = maxi(1, int(round(float(num_cols) * _get_difficulty_skill_mult())))

	var cols: Array[int] = []
	var col_pool: Array[int] = []
	for c in range(GRID_COLUMNS): col_pool.append(c)
	col_pool.shuffle()
	for i in range(mini(num_cols, col_pool.size())):
		cols.append(col_pool[i])

	for col in cols:
		active_wind_tornadoes.append({
			"col": col,
			"y": BOARD_TOP,
			"speed": 5500.0,
			"active": true,
			"ally": false
		})
		_targets.append(get_cell_position(GRID_ROWS / 2, col))

		# 敵にとって不利益なマス（プレイヤーの木・特殊アイテム・プレイヤー有利マス・星影の霧）を吹き飛ばす
		for plant in plant_entities.duplicate():
			var occ = _get_plant_occupied_cells(plant)
			var hit = false
			for pcell in occ:
				if pcell.y == col:
					hit = true
					break
			if hit and not plant.get("enemy_planted", false):
				_damage_plant(plant, 999, "wind_tornado")

		for r in range(GRID_ROWS):
			if special_item.size() == GRID_ROWS:
				special_item[r][col] = SpecialItemType.NONE
			if is_bomb.size() == GRID_ROWS:
				is_bomb[r][col] = false
			if special_charge.size() == GRID_ROWS:
				special_charge[r][col] = 0
			# プレイヤー側の有利マス（味方属性マス）のみ吹き飛ばす（敵自身の障害物は保持）
			if grid_stones.size() == GRID_ROWS and is_ally_stone(r, col):
				grid_stones[r][col] = 0
				_set_ally_flag(grid_stones_ally, r, col, false)
			if grid_water.size() == GRID_ROWS and is_ally_water(r, col):
				grid_water[r][col] = false
				_set_ally_flag(grid_water_ally, r, col, false)
			if grid_ice.size() == GRID_ROWS and is_ally_ice(r, col):
				grid_ice[r][col] = 0
				_set_ally_flag(grid_ice_ally, r, col, false)
			if grid_cursed.size() == GRID_ROWS and is_ally_cursed(r, col):
				grid_cursed[r][col] = false
				_set_ally_flag(grid_cursed_ally, r, col, false)
			if grid_poison.size() == GRID_ROWS and is_ally_poison(r, col):
				grid_poison[r][col] = false
				_set_ally_flag(grid_poison_ally, r, col, false)
			if grid_electrified.size() == GRID_ROWS and is_ally_electrified(r, col):
				grid_electrified[r][col] = false
				_set_ally_flag(grid_electrified_ally, r, col, false)
			if grid_gold_statue.size() == GRID_ROWS and is_ally_gold(r, col):
				grid_gold_statue[r][col] = 0
				_set_ally_flag(grid_gold_ally, r, col, false)
			if grid_fire.size() == GRID_ROWS and is_ally_fire(r, col):
				grid_fire[r][col] = 0
				_set_ally_flag(grid_fire_ally, r, col, false)

		# プレイヤー側の星影の霧が竜巻列にかかっていたら解除
		var fog_idx = grid_fog.size() - 1
		while fog_idx >= 0:
			var fog_d = grid_fog[fog_idx]
			if not fog_d.get("enemy_owned", true):
				var f_rect: Rect2i = fog_d.get("rect", Rect2i(0, 0, 0, 0))
				if col >= f_rect.position.y and col < f_rect.position.y + f_rect.size.y:
					grid_fog.remove_at(fog_idx)
			fog_idx -= 1

	var rensa_se = get_node_or_null("1rensa")
	if rensa_se: rensa_se.play()

	_redraw_board_effects()
	return _targets

## 4. 木属性スキル: 苗木を植えて毎ターンドレイン（通常1本・15HP、ボスは初期3本・80HPから緩やかに増加）
func _cast_enemy_wood_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "生命強奪・フォレストカース" if is_boss else "ソーンシード"
	var s_desc = "【吸血苗木】毎ターン生命力を吸収する苗木を植え付ける！"
	if show_banner: _show_enemy_skill_banner(s_name, "#69F0AE", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(3 + int(st_idx / 3), 3 + int((st_idx + 1) / 2)) if is_boss else (1 + int(st_idx / 3))
	count = maxi(1, int(round(float(count) * diff_m)))
	var drain_hp = int(round(float((80 + st_idx * 15) if is_boss else (15 + st_idx * 15)) * diff_m))

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0: continue
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0: continue
				cands.append(Vector2i(r, c))
	cands.shuffle()

	var newly_planted: Array[Dictionary] = []
	var num = mini(count, cands.size())
	var num_saplings = (1 + int(st_idx / 2)) if is_boss else (1 if st_idx >= 3 else 0)
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		var idx = grid_i[p.x][p.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			piece[idx].queue_free(); Profiler.queue_free_count += 1
			piece[idx] = null
		grid_i[p.x][p.y] = -1
		grid_n[p.x][p.y] = -1
		grid_att[p.x][p.y] = -1

		var st_val = 1 if i < num_saplings else 0
		var th_hp = 1
		if is_boss:
			th_hp = 1 + int((st_idx + 1) / 2)
		elif st_idx >= 3:
			th_hp = 2

		var plant_data = {
			"origin": p,
			"stage": st_val,
			"absorbed_water": 0,
			"thunder_hp": th_hp,
			"enemy_planted": true,
			"drain_amount": drain_hp
		}
		plant_entities.append(plant_data)
		newly_planted.append(plant_data)
		_spawn_growth_effect(get_cell_position(p.x, p.y), st_val)
		_targets.append(get_cell_position(p.x, p.y))

	_compact_piece_arrays()
	_redraw_board_effects()

	# 初動生命力吸収（植えられた直後にプレイヤーから生命力を吸引）
	var sm = _get_stage_manager()
	if sm and not newly_planted.is_empty():
		var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
		_execute_wood_hp_drain(sm, newly_planted, stage_scale)
	return _targets

## 5. 地属性スキル: 石を配置（通常1〜2個・耐久1、ボスは初期4〜5個・耐久2から緩やかに増加）
func _cast_enemy_earth_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "天変地異・グランドカタストロフ" if is_boss else "ロックフォール"
	var s_desc = "【石化】動かせない障害物の岩石を配置！"
	if show_banner: _show_enemy_skill_banner(s_name, "#FFB74D", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(4 + int(st_idx * 0.75), 5 + int(st_idx * 0.75)) if is_boss else randi_range(1 + int(st_idx * 0.5), 2 + int(st_idx * 0.5))
	count = maxi(1, int(round(float(count) * diff_m)))

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c):
				if grid_stones.size() == GRID_ROWS and grid_stones[r][c] == 0:
					if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] == 0:
						cands.append(Vector2i(r, c))
	cands.shuffle()

	var num = mini(count, cands.size())
	var base_dur = (2 + (1 if st_idx >= 3 else 0)) if is_boss else (1 + (1 if st_idx >= 3 else 0))
	var heavy_stones = (1 + int(st_idx / 2)) if is_boss else 0
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		var stone_dur = (base_dur + 1) if i < heavy_stones else base_dur
		grid_stones[p.x][p.y] = stone_dur
		_set_ally_flag(grid_stones_ally, p.x, p.y, false)
		_spawn_floating_text(get_cell_position(p.x, p.y), "石化", Color(0.7, 0.7, 0.6))
		_spawn_stone_break_effect(get_cell_position(p.x, p.y))
		_targets.append(get_cell_position(p.x, p.y))

	_trigger_screen_shake(12.0)
	var block_se = get_node_or_null("block")
	if block_se: block_se.play()

	_redraw_board_effects()
	return _targets

## 6. 雷属性スキル: 落雷（通常1〜2発、ボスは初期5〜6発から緩やかに増加）
func _cast_enemy_lightning_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "神罰・ジャッジメントサンダー" if is_boss else "ギガスパーク"
	var s_desc = "【神罰落雷】広範囲のコマを帯電！さらに直接雷撃ダメージ！" if is_boss else "【落雷】帯電したコマを動かすと感電反動ダメージ！"
	if show_banner: _show_enemy_skill_banner(s_name, "#FFD700", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(7 + int(st_idx * 0.8), 9 + int(st_idx * 0.8)) if is_boss else randi_range(1 + int(st_idx * 0.6), 2 + int(st_idx * 0.6))
	count = maxi(1, int(round(float(count) * diff_m)))

	if is_boss:
		var sm_bolt = _get_stage_manager()
		if sm_bolt and sm_bolt.myhp > 0:
			var direct_dmg = 500.0 * pow(10.0, max(0, sm_bolt.stage - 1)) * diff_m
			var total_shield_pool: float = 0.0
			for el in current_shield_pools:
				total_shield_pool += current_shield_pools[el]
			total_shield_pool = maxf(total_shield_pool, float(active_shields.size()))
			var blocked = minf(total_shield_pool * (100.0 * pow(10.0, max(0, sm_bolt.stage - 1))), direct_dmg * 0.5)
			var actual_dmg = maxf(0.0, direct_dmg - blocked)
			if actual_dmg > 0.0:
				sm_bolt.last_damage_cause = "ボスの雷撃魔法 (落雷)"
				sm_bolt.calchp(0.0, actual_dmg)
				_emit_combat_event("damage", "enemy", "ally", actual_dmg, "thunder", false, "normal")
				_spawn_screen_flash(Color(1.0, 0.9, 0.2, 0.35), 0.2)
				_trigger_screen_shake(15.0)

	# 帯電マスはマス単位のフラグなので同じマスに重なることはないが、
	# 既に帯電したマスを再度狙うと数が増え続けるため、未帯電マスを優先して狙う
	var elec_candidates: Array[Vector2i] = []
	for tr in range(GRID_ROWS):
		for tc in range(GRID_COLUMNS):
			if not grid_electrified[tr][tc]:
				elec_candidates.append(Vector2i(tr, tc))
	elec_candidates.shuffle()
	for i in range(count):
		var r: int = randi() % GRID_ROWS
		var c: int = randi() % GRID_COLUMNS
		if not elec_candidates.is_empty():
			var picked_cell: Vector2i = elec_candidates.pop_back()
			r = picked_cell.x
			c = picked_cell.y
		var pos = get_cell_position(r, c)
		var delay = i * 0.06
		_spawn_vertical_lightning_bolt(pos, delay)
		_targets.append(pos)

		# 落雷ヒット時の処理
		var tw_hit = create_tween()
		tw_hit.tween_interval(delay)
		tw_hit.tween_callback(func():
			# ① 水マスに当たると水たまりのみ蒸発
			if grid_water.size() == GRID_ROWS and grid_water[r][c]:
				grid_water[r][c] = false
				_set_ally_flag(grid_water_ally, r, c, false)
				_spawn_screen_flash(Color(0.2, 0.8, 1.0, 0.4), 0.08)

			# ② 木に当たると耐久値-1
			var plant = _get_plant_at(r, c)
			if not plant.is_empty():
				_damage_plant(plant, 1, "lightning")

			# ③ 石または氷に当たると「石×雷 / 氷×雷」シナジーで破片が飛び散り周囲1マスを巻き込んで消去
			if (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0) or (grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) > 0):
				_trigger_thunder_shatter_synergy(r, c, false)

			# ④ 黄金像に当たると耐久-1
			if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0:
				grid_gold_statue[r][c] -= 1
				if grid_gold_statue[r][c] <= 0:
					_set_ally_flag(grid_gold_ally, r, c, false)
					_spawn_gold_shatter_effect(pos)

			# ⑤ 通常コマに当たると純粋な雷オブジェクトコマ化（触れる/動かす/マッチで反動）
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if (grid_stones.size() == GRID_ROWS and grid_stones[r][c] == 0) and \
				   (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] == 0):
					if not _check_and_block_enemy_hazard(r, c):
						# 帯電マスの総数に上限を設け、盤面が帯電だらけになって描画負荷が増え続けないようにする
						if _count_electrified_tiles() < MAX_ELECTRIFIED_TILES:
							grid_electrified[r][c] = true
							_set_ally_flag(grid_electrified_ally, r, c, false)
							_spawn_floating_text(get_cell_position(r, c), "帯電", Color(0.9, 1.0, 0.2))

			_redraw_board_effects()
		)
	return _targets

## 7. 闇属性スキル: 暗雲＆呪いコマ（通常2x2・呪い1〜2個、ボスは初期3x3・呪い4〜5個から緩やかに増加）
func _cast_enemy_dark_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var sm = _get_stage_manager()
	var is_5th_boss: bool = is_boss and sm != null and (
		sm.stage == 5 or _get_stage_index() >= 4 or
		(sm.has_method("is_boss_battle") and sm.is_boss_battle() and sm.stage == 5) or
		(sm.get("islastboss") == true) or
		(sm.get("current_enemy_key") == "enemy18")
	)

	var s_name = ("冥府降臨・アビスディメンション" if is_5th_boss else "終焉の夜・アビスディメンション") if is_boss else "シャドウベール＆カース"
	var s_desc = "【暗雲＆呪詛】毎ターン瘴気ダメージ！呪いコマ消去で反動！"
	if show_banner: _show_enemy_skill_banner(s_name, "#E040FB", is_boss, s_desc)
	var st_idx = _get_stage_index()

	# 黒い霧（Stage 1: Bossは3x3・2ターン、通常は2x2・1ターン）
	var fog_size = mini(GRID_ROWS, (3 + (1 if st_idx >= 3 else 0)) if is_boss else (2 + (1 if st_idx >= 3 else 0)))
	var fog_turns = (2 + (1 if st_idx >= 2 else 0)) if is_boss else (1 + (1 if st_idx >= 3 else 0))
	var top_r = clampi(randi() % (GRID_ROWS - fog_size + 1), 0, GRID_ROWS - fog_size)
	var left_c = clampi(randi() % (GRID_COLUMNS - fog_size + 1), 0, GRID_COLUMNS - fog_size)
	grid_fog.append({
		"rect": Rect2i(top_r, left_c, fog_size, fog_size),
		"turns": fog_turns,
		"enemy_owned": true
	})

	# 呪いコマ生成（盾やパンを優先的に呪う）
	var diff_m = _get_difficulty_skill_mult()
	var curse_count = randi_range(4 + int(st_idx * 0.75), 5 + int(st_idx * 0.75)) if is_boss else randi_range(1 + int(st_idx * 0.5), 2 + int(st_idx * 0.5))
	curse_count = maxi(1, int(round(float(curse_count) * diff_m)))
	var cands: Array[Vector2i] = []
	var other_cands: Array[Vector2i] = []

	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_n[r][c] == PieceType.SHIELD or grid_n[r][c] == PieceType.FOOD:
					cands.append(Vector2i(r, c))
				else:
					other_cands.append(Vector2i(r, c))

	cands.shuffle()
	other_cands.shuffle()
	cands.append_array(other_cands)

	var num = mini(curse_count, cands.size())
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		grid_cursed[p.x][p.y] = true
		_set_ally_flag(grid_cursed_ally, p.x, p.y, false)
		_spawn_floating_text(get_cell_position(p.x, p.y), "【呪い】消去で反動！", Color(0.9, 0.4, 1.0))
		_targets.append(get_cell_position(p.x, p.y))

	var anten_se = get_node_or_null("anten")
	if anten_se: anten_se.play()

	_redraw_board_effects()
	return _targets

## 盤面の状態異常ハザード（暗雲・呪い・炎上・帯電・石・凍結・水たまり等）を一括消去
func clear_board_hazards() -> void:
	hazard_spread_turn_counter = 0
	grid_fog.clear()
	plant_entities.clear()
	stone_turn_counts.clear()
	diamond_stones.clear()
	active_wind_tornadoes.clear()
	storm_zones.clear()
	wind_ward_columns.clear()
	delayed_explosions.clear()
	last_shrapnel_cleared_cells.clear()
	poison_mist_detonated_cells.clear()
	pending_special_spawns.clear()
	steady_spark_triggered_this_turn = false
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_cursed.size() == GRID_ROWS: grid_cursed[r][c] = false
			if grid_fire.size() == GRID_ROWS: grid_fire[r][c] = 0
			if grid_electrified.size() == GRID_ROWS: grid_electrified[r][c] = false
			if grid_stones.size() == GRID_ROWS: grid_stones[r][c] = 0
			if grid_gold_statue.size() == GRID_ROWS: grid_gold_statue[r][c] = 0
			if grid_water.size() == GRID_ROWS: grid_water[r][c] = false
			if grid_ice.size() == GRID_ROWS: grid_ice[r][c] = 0
			if grid_poison.size() == GRID_ROWS: grid_poison[r][c] = false
	_init_ally_grids()
	_redraw_board_effects()

## 8. 光属性スキル: 重要アイテム（盾/剣）を黄金石像スカコマ化（通常1体・耐久1、ボスは初期3〜4体・耐久2から緩やかに増加）
func _cast_enemy_light_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "太陽神の審判・ソーラープリズム" if is_boss else "ミダスグレイス"
	var s_desc = "【黄金化】重要コマを黄金像に変化！隣接消去で破壊せよ！"
	if show_banner: _show_enemy_skill_banner(s_name, "#FFD700", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(3 + int(st_idx * 0.75), 4 + int(st_idx * 0.75)) if is_boss else (1 + int(st_idx / 2))
	count = maxi(1, int(round(float(count) * diff_m)))

	var sm = _get_stage_manager()
	# ランダムなマスに効果を与える（火・氷と同様に盤面のランダムなマスを黄金像化）
	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] == 0:
					cands.append(Vector2i(r, c))
	cands.shuffle()

	var statue_dur = (2 + (1 if st_idx >= 3 else 0)) if is_boss else (1 + (1 if st_idx >= 3 else 0))

	var num = mini(count, cands.size())
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		# 独立お邪魔ブロック化: 既存の通常駒を完全消去し、セルそのものを独立した黄金像ブロックに置き換え
		var idx = grid_i[p.x][p.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			piece[idx].queue_free()
			Profiler.queue_free_count += 1
			piece[idx] = null
		grid_i[p.x][p.y] = -1
		grid_n[p.x][p.y] = -1
		grid_att[p.x][p.y] = -1
		if special_item.size() == GRID_ROWS: special_item[p.x][p.y] = SpecialItemType.NONE
		if is_bomb.size() == GRID_ROWS: is_bomb[p.x][p.y] = false
		if special_charge.size() == GRID_ROWS: special_charge[p.x][p.y] = 0
		grid_gold_statue[p.x][p.y] = statue_dur
		_set_ally_flag(grid_gold_ally, p.x, p.y, false)
		var cell_pos_lgt = get_cell_position(p.x, p.y)
		_spawn_floating_text(cell_pos_lgt, "黄金像ブロック", Color(1.0, 0.9, 0.2))
		_targets.append(cell_pos_lgt)

		# 敵位置から対象黄金像マスへ聖光弾を飛翔（視覚的な飛翔軌跡）
		var sm_enemy_lgt = _get_stage_manager()
		var enemy_pos = Vector2(BOARD_LEFT + BOARD_WIDTH * 0.5, 200.0)
		if sm_enemy_lgt and is_instance_valid(sm_enemy_lgt.enemy):
			enemy_pos = sm_enemy_lgt.enemy.global_position
		_spawn_holy_light_projectile(enemy_pos, cell_pos_lgt, float(i) * 0.08)

	# ボス時はさらにランダムな通常コマも追加で独立した黄金像ブロック化（Stage 2以上から）
	if is_boss and st_idx >= 1:
		var extra_cands: Array[Vector2i] = []
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
					if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] == 0:
						extra_cands.append(Vector2i(r, c))
		extra_cands.shuffle()
		var extra_num = mini(randi_range(1, 2) + int(st_idx * 0.5), extra_cands.size())
		for j in range(extra_num):
			var p2 = extra_cands[j]
			if _check_and_block_enemy_hazard(p2.x, p2.y):
				continue
			var idx2 = grid_i[p2.x][p2.y]
			if idx2 >= 0 and idx2 < piece.size() and piece[idx2] != null:
				piece[idx2].queue_free()
				Profiler.queue_free_count += 1
				piece[idx2] = null
			grid_i[p2.x][p2.y] = -1
			grid_n[p2.x][p2.y] = -1
			grid_att[p2.x][p2.y] = -1
			if special_item.size() == GRID_ROWS: special_item[p2.x][p2.y] = SpecialItemType.NONE
			if is_bomb.size() == GRID_ROWS: is_bomb[p2.x][p2.y] = false
			if special_charge.size() == GRID_ROWS: special_charge[p2.x][p2.y] = 0
			grid_gold_statue[p2.x][p2.y] = statue_dur
			_set_ally_flag(grid_gold_ally, p2.x, p2.y, false)
			_spawn_floating_text(get_cell_position(p2.x, p2.y), "黄金像ブロック", Color(1.0, 0.9, 0.2))
			_targets.append(get_cell_position(p2.x, p2.y))

	_trigger_screen_shake(10.0)
	var block_se = get_node_or_null("block")
	if block_se: block_se.play()

	_redraw_board_effects()
	return _targets

## 9. 火属性スキル: 盤面炎上＆直撃爆炎（プレイヤーへの直撃ダメージ＋盤面炎上。爆弾生成によるプレイヤー有利化を廃止）
func _cast_enemy_fire_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "獄炎焦土・ヘルフレイム" if is_boss else "ブレイズブラスト"
	var s_desc = "【爆炎】盤面を炎上延焼させ、プレイヤーに直撃火傷ダメージ！"
	if show_banner: _show_enemy_skill_banner(s_name, "#FF1744", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(4 + int(st_idx * 0.75), 5 + int(st_idx * 0.75)) if is_boss else randi_range(2 + int(st_idx * 0.6), 3 + int(st_idx * 0.6))
	count = maxi(1, int(round(float(count) * diff_m)))

	# プレイヤーへの直撃ダメージ（盾で一部軽減可能）
	var sm_fire = _get_stage_manager()
	if sm_fire:
		var stage_scale: float = pow(10.0, max(0, sm_fire.stage - 1))
		var base_dmg: float = ((80.0 + st_idx * 30.0) if is_boss else (30.0 + st_idx * 15.0)) * diff_m
		var direct_dmg: float = base_dmg * stage_scale
		var total_shield_pool: float = 0.0
		if sm_fire.has_method("get_total_shields"):
			total_shield_pool = float(sm_fire.get_total_shields())
		elif "active_shields" in sm_fire and sm_fire.active_shields != null:
			total_shield_pool = float(sm_fire.active_shields.size())
		total_shield_pool = maxf(total_shield_pool, float(active_shields.size()))
		var blocked = minf(total_shield_pool * (100.0 * stage_scale), direct_dmg * 0.5)
		var actual_dmg = maxf(0.0, direct_dmg - blocked)
		if actual_dmg > 0.0:
			sm_fire.last_damage_cause = "火炎魔法の熱波ダメージ"
			sm_fire.calchp(0.0, actual_dmg)
			_emit_combat_event("damage", "enemy", "ally", actual_dmg, "fire", false, "normal")
			_spawn_screen_flash(Color(1.0, 0.3, 0.1, 0.35), 0.2)
			_trigger_screen_shake(12.0)

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_fire.size() == GRID_ROWS and grid_fire[r][c] == 0:
					cands.append(Vector2i(r, c))
	cands.shuffle()

	var num = mini(count, cands.size())
	var ignited_cells: Array[Vector2i] = []
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		ignited_cells.append(p)
		grid_fire[p.x][p.y] = DEFAULT_FIRE_LIFETIME
		_set_ally_flag(grid_fire_ally, p.x, p.y, false)
		var cell_p = get_cell_position(p.x, p.y)
		_spawn_floating_text(cell_p, "炎上！", Color(1.0, 0.4, 0.1))
		_spawn_fire_ignition_effect(cell_p, false)
		_targets.append(cell_p)

	# 敵スキルでは盤面炎上床設置と直接ダメージのみ（駒の消去や落下は行わない。ターンループ防止）
	# 敵の火属性進化（破片・榴弾）発動：ブレイズブラストの破片が飛び散って隣接炎上
	if has_actor_skill_trait(false, "fire", "fire_mid_c") or has_actor_skill_trait(false, "fire", "fire_final_c1"):
		_trigger_fire_shrapnel_evolution(ignited_cells, false)

	_check_and_trigger_water_fire_synergy(false)
	_redraw_board_effects()
	return _targets

## 10. 毒属性スキル: 盤面に猛毒沼を生成（通常2〜3マス、ボスは初期5〜6マスから緩やかに増加、毎ターン毒ダメージ・マッチで解毒）
func _cast_enemy_poison_skill(is_boss: bool, show_banner: bool = true) -> Array[Vector2]:
	var _targets: Array[Vector2] = []
	var s_name = "猛毒瘴気・デッドリーヴェノム" if is_boss else "ポイズンバースト"
	var s_desc = "【猛毒】盤面に猛毒を放つ！毎ターン隣接マスへ伝染（水マスは2倍速で伝染）！"
	if show_banner: _show_enemy_skill_banner(s_name, "#AB47BC", is_boss, s_desc)
	var st_idx = _get_stage_index()
	var diff_m = _get_difficulty_skill_mult()
	var count = randi_range(5 + st_idx, 6 + st_idx) if is_boss else randi_range(2 + int(st_idx * 0.5), 3 + int(st_idx * 0.5))
	count = maxi(1, int(round(float(count) * diff_m)))

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_poison.size() == GRID_ROWS and not grid_poison[r][c]:
					cands.append(Vector2i(r, c))
	cands.shuffle()

	var num = mini(count, cands.size())
	for i in range(num):
		var p = cands[i]
		if _check_and_block_enemy_hazard(p.x, p.y):
			continue
		if grid_poison.size() == GRID_ROWS:
			grid_poison[p.x][p.y] = true
			_set_ally_flag(grid_poison_ally, p.x, p.y, false)
		var cell_p = get_cell_position(p.x, p.y)
		_spawn_floating_text(cell_p, "毒沼！", Color(0.85, 0.35, 0.95))
		_targets.append(cell_p)

		# 敵位置から対象毒マスへ毒胞子弾を飛翔（視覚的な飛翔軌跡）
		var sm_enemy_psn = _get_stage_manager()
		var enemy_pos = Vector2(BOARD_LEFT + BOARD_WIDTH * 0.5, 200.0)
		if sm_enemy_psn and is_instance_valid(sm_enemy_psn.enemy):
			enemy_pos = sm_enemy_psn.enemy.global_position
		_spawn_poison_bubble_projectile(enemy_pos, cell_p, float(i) * 0.08)

	_redraw_board_effects()
	return _targets

## 炎の毎ターン延焼処理（延焼進化所持時のみ1ターンごとに隣接マスの1つへ延焼、上限12マス）
func _process_fire_spread() -> void:
	if grid_fire.size() != GRID_ROWS:
		return
	_ensure_ally_grids()

	var ally_fire_cnt = 0
	var enemy_fire_cnt = 0
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_fire[r][c] > 0:
				if is_ally_fire(r, c): ally_fire_cnt += 1
				else: enemy_fire_cnt += 1

	if ally_fire_cnt == 0 and enemy_fire_cnt == 0:
		return

	# 🔥 火B: 延焼を所持していない側は一切延焼しない (上限12マス)
	var ally_can_spread = (ally_fire_cnt < 12 and has_actor_skill_trait(true, "fire", "fire_mid_b"))
	var enemy_can_spread = (enemy_fire_cnt < 12 and has_actor_skill_trait(false, "fire", "fire_mid_b"))
	if not ally_can_spread and not enemy_can_spread:
		return

	var next_fire: Array = []
	var next_fire_ally: Array = []
	for r in range(GRID_ROWS):
		var row: Array[int] = []
		var row_ally: Array[bool] = []
		for c in range(GRID_COLUMNS):
			row.append(grid_fire[r][c])
			row_ally.append(is_ally_fire(r, c))
		next_fire.append(row)
		next_fire_ally.append(row_ally)

	var ally_added: int = 0
	var enemy_added: int = 0

	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var f_state = grid_fire[r][c]
			var is_src_ally: bool = is_ally_fire(r, c)
			if is_src_ally and not ally_can_spread: continue
			if not is_src_ally and not enemy_can_spread: continue
			if is_src_ally and ally_fire_cnt + ally_added >= 12: continue
			if not is_src_ally and enemy_fire_cnt + enemy_added >= 12: continue
			# 既に他火源の消火処理で鎮火したマスからは延焼しない
			if next_fire[r][c] <= 0: continue

			var can_burn_hazards = has_actor_skill_trait(is_src_ally, "fire", "fire_final_b2")

			if not _is_plant_cell(r, c) and f_state > 0:
				# 通常の炎：1ターンごとに隣接するマスの1つへ延焼
				var empty_candidates: Array[Vector2i] = []
				var occupied_candidates: Array[Vector2i] = []
				for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nr = r + offset.x
					var nc = c + offset.y
					if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLUMNS:
						continue

					# 1. 延焼先が水マスの場合は水×火シナジーに委ねる、または水の結界で保護
					if grid_water.size() == GRID_ROWS and grid_water[nr][nc]:
						continue

					# 氷の隣接効果停止: 氷マスおよびその隣接マスへは延焼しない
					if _is_cell_ice_locked(nr, nc):
						continue

					# 影護マスによる敵炎上延焼防御
					if not is_src_ally and is_ally_cursed(nr, nc):
						continue

					# 2. 味方の炎は味方の木を燃やさない、敵の炎は敵の木を燃やさない
					var p_at = _get_plant_at(nr, nc)
					if not p_at.is_empty():
						var p_ally = is_ally_plant(p_at)
						if (is_src_ally and p_ally) or (not is_src_ally and not p_ally):
							continue

					# 3. 既に炎上しているマスは除外
					if grid_fire[nr][nc] > 0 or next_fire[nr][nc] > 0:
						continue

					# 4. 石・敵ハザードへの延焼判定（B2 焼き払い 所持時のみ敵石やハザードを上書き可能）
					if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
						if not can_burn_hazards or (is_src_ally and is_ally_stone(nr, nc)) or (not is_src_ally and not is_ally_stone(nr, nc)):
							continue

					# 空きマスを優先し、空きが無い場合のみ駒マスへ延焼する
					if grid_i.size() == GRID_ROWS and grid_i[nr][nc] == -1:
						empty_candidates.append(Vector2i(nr, nc))
					else:
						occupied_candidates.append(Vector2i(nr, nc))

				var candidates: Array[Vector2i] = empty_candidates if not empty_candidates.is_empty() else occupied_candidates
				if not candidates.is_empty():
					var chosen_cell: Vector2i = candidates[randi() % candidates.size()]
					var nr = chosen_cell.x
					var nc = chosen_cell.y

					# B2 焼き払い: 相手の石やハザードを焼き払う
					if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
						grid_stones[nr][nc] = 0
						_spawn_stone_break_effect(get_cell_position(nr, nc))
					if grid_poison.size() == GRID_ROWS and grid_poison[nr][nc]:
						grid_poison[nr][nc] = false
					if grid_cursed.size() == GRID_ROWS and grid_cursed[nr][nc]:
						grid_cursed[nr][nc] = false

					# 氷マスの場合：熱力学変化（氷→水→消える）：氷は水に融解し、炎は消火される
					if grid_ice.size() == GRID_ROWS and int(grid_ice[nr][nc]) > 0:
						var was_ally_ice = is_ally_ice(nr, nc)
						grid_ice[nr][nc] = 0
						_set_ally_flag(grid_ice_ally, nr, nc, false)
						if grid_water.size() == GRID_ROWS:
							grid_water[nr][nc] = true
							_set_ally_flag(grid_water_ally, nr, nc, was_ally_ice)
						_spawn_ice_break_effect(get_cell_position(nr, nc))
						_spawn_steam_effect(get_cell_position(nr, nc))
						_spawn_floating_text(get_cell_position(nr, nc), "融解 (氷→水)！", Color(0.4, 0.85, 1.0))
						next_fire[r][c] = 0
						next_fire_ally[r][c] = false
					elif _is_plant_cell(nr, nc):
						next_fire[nr][nc] = 2
						next_fire_ally[nr][nc] = is_src_ally
						if is_src_ally: ally_added += 1
						else: enemy_added += 1
						_spawn_fire_ignition_effect(get_cell_position(nr, nc), is_src_ally)
					else:
						next_fire[nr][nc] = DEFAULT_FIRE_LIFETIME
						next_fire_ally[nr][nc] = is_src_ally
						if is_src_ally: ally_added += 1
						else: enemy_added += 1
						_spawn_fire_ignition_effect(get_cell_position(nr, nc), is_src_ally)

			elif _is_plant_cell(r, c) and f_state >= 2:
				# 前ターンに木に火が移ったマス：このターンで木を燃焼し、隣接マスの1つへ延焼
				var plant = _get_plant_at(r, c)
				if not plant.is_empty():
					_burn_plant(plant)

				next_fire[r][c] = DEFAULT_FIRE_LIFETIME
				next_fire_ally[r][c] = is_src_ally
				_spawn_fire_ignition_effect(get_cell_position(r, c), is_src_ally, 1.4)

				var candidates_f2: Array[Vector2i] = []
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0: continue
						var nr = r + dr
						var nc = c + dc
						if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLUMNS:
							continue
						if grid_water.size() == GRID_ROWS and grid_water[nr][nc]:
							continue
						var p_at2 = _get_plant_at(nr, nc)
						if not p_at2.is_empty():
							var p_ally2 = is_ally_plant(p_at2)
							if (is_src_ally and p_ally2) or (not is_src_ally and not p_ally2):
								continue
						if grid_fire[nr][nc] > 0 or next_fire[nr][nc] > 0:
							continue
						candidates_f2.append(Vector2i(nr, nc))

				var at_cap = (ally_fire_cnt + ally_added >= 12) if is_src_ally else (enemy_fire_cnt + enemy_added >= 12)
				if not at_cap and not candidates_f2.is_empty():
					var chosen_cell2: Vector2i = candidates_f2[randi() % candidates_f2.size()]
					var nr2 = chosen_cell2.x
					var nc2 = chosen_cell2.y
					if grid_ice.size() == GRID_ROWS and int(grid_ice[nr2][nc2]) > 0:
						var was_ally_ice2 = is_ally_ice(nr2, nc2)
						grid_ice[nr2][nc2] = 0
						_set_ally_flag(grid_ice_ally, nr2, nc2, false)
						if grid_water.size() == GRID_ROWS:
							grid_water[nr2][nc2] = true
							_set_ally_flag(grid_water_ally, nr2, nc2, was_ally_ice2)
						_spawn_ice_break_effect(get_cell_position(nr2, nc2))
						_spawn_steam_effect(get_cell_position(nr2, nc2))
						_spawn_floating_text(get_cell_position(nr2, nc2), "融解 (氷→水)！", Color(0.4, 0.85, 1.0))
					elif _is_plant_cell(nr2, nc2):
						next_fire[nr2][nc2] = 2
						next_fire_ally[nr2][nc2] = is_src_ally
						if is_src_ally: ally_added += 1
						else: enemy_added += 1
						_spawn_fire_ignition_effect(get_cell_position(nr2, nc2), is_src_ally)
					else:
						next_fire[nr2][nc2] = DEFAULT_FIRE_LIFETIME
						next_fire_ally[nr2][nc2] = is_src_ally
						if is_src_ally: ally_added += 1
						else: enemy_added += 1
						_spawn_fire_ignition_effect(get_cell_position(nr2, nc2), is_src_ally)

	grid_fire = next_fire
	grid_fire_ally = next_fire_ally
	_check_and_trigger_ice_fire_melting()
	_check_and_trigger_water_fire_synergy(false)
	_update_status_ailments()
	_redraw_board_effects()

## 飛び火進化: 火が燃え尽きるときに、周囲48マス（7×7）のランダムなマスを燃やす
func _trigger_tobibi(origin_r: int, origin_c: int, is_ally: bool) -> Array[Vector2i]:
	var cands: Array[Vector2i] = []
	# 周囲48マス = 7x7 (dr in -3..3, dc in -3..3) except (0, 0)
	for dr in range(-3, 4):
		for dc in range(-3, 4):
			if dr == 0 and dc == 0:
				continue
			var nr = origin_r + dr
			var nc = origin_c + dc
			if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLUMNS:
				continue
			if _is_plant_cell(nr, nc):
				continue
			if grid_fire.size() == GRID_ROWS and grid_fire[nr][nc] > 0:
				continue
			if grid_water.size() == GRID_ROWS and grid_water[nr][nc]:
				continue
			if grid_ice.size() == GRID_ROWS and int(grid_ice[nr][nc]) > 0:
				continue
			if grid_stones.size() == GRID_ROWS and int(grid_stones[nr][nc]) > 0:
				continue
			if grid_gold_statue.size() == GRID_ROWS and int(grid_gold_statue[nr][nc]) > 0:
				continue
			cands.append(Vector2i(nr, nc))
	if cands.is_empty():
		return []

	cands.shuffle()
	var tobibi_ignited: Array[Vector2i] = []
	var count = 2 if has_actor_skill_trait(is_ally, "fire", "fire_final_a1") else 1
	var num = mini(count, cands.size())
	var lifetime = DEFAULT_FIRE_LIFETIME + (1 if has_actor_skill_trait(is_ally, "fire", "fire_final_a2") else 0)
	for i in range(num):
		var target = cands[i]
		tobibi_ignited.append(target)
		if grid_fire.size() == GRID_ROWS:
			grid_fire[target.x][target.y] = lifetime
			_set_ally_flag(grid_fire_ally, target.x, target.y, is_ally)
		var t_pos = get_cell_position(target.x, target.y)
		_spawn_fire_ignition_effect(t_pos, is_ally)
		_spawn_floating_text(t_pos, "🔥 飛び火！", Color(0.3, 0.9, 1.0) if is_ally else Color(1.0, 0.45, 0.1))
	return tobibi_ignited

## 毒の毎ターン伝染処理（伝染進化所持時のみ1ターンごとに隣接マスの1つへ伝染、上限12マス）
func _process_poison_spread() -> void:
	if grid_poison.size() != GRID_ROWS:
		return
	_ensure_ally_grids()

	var ally_p_cnt = 0
	var enemy_p_cnt = 0
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_poison[r][c]:
				if is_ally_poison(r, c): ally_p_cnt += 1
				else: enemy_p_cnt += 1

	if ally_p_cnt == 0 and enemy_p_cnt == 0:
		return

	# 🧪 毒B: 伝染を所持していない側は空きマスへの伝染を行わない (上限12マス)
	var ally_can_spread = (ally_p_cnt < 12 and has_actor_skill_trait(true, "poison", "poison_mid_b"))
	var enemy_can_spread = (enemy_p_cnt < 12 and has_actor_skill_trait(false, "poison", "poison_mid_b"))

	var next_poison: Array = []
	var next_poison_ally: Array = []
	for r in range(GRID_ROWS):
		var row: Array[bool] = []
		var row_ally: Array[bool] = []
		for c in range(GRID_COLUMNS):
			row.append(grid_poison[r][c])
			row_ally.append(is_ally_poison(r, c))
		next_poison.append(row)
		next_poison_ally.append(row_ally)

	# 侵攻圧力マップの構築
	var ally_pressure: Array = []
	var enemy_pressure: Array = []
	for r in range(GRID_ROWS):
		var row_ap: Array[int] = []; row_ap.resize(GRID_COLUMNS); row_ap.fill(0)
		var row_ep: Array[int] = []; row_ep.resize(GRID_COLUMNS); row_ep.fill(0)
		ally_pressure.append(row_ap)
		enemy_pressure.append(row_ep)

	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not grid_poison[r][c]:
				continue
			if _is_cell_ice_locked(r, c):
				continue

			var is_src_ally: bool = is_ally_poison(r, c)
			var base_weight: int = 2 if (grid_water.size() == GRID_ROWS and grid_water[r][c]) else 1 # 水マス上では2倍速伝染（圧力2）

			# 1. 既存の敵対毒マスへの相互侵攻圧力
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nr = r + offset.x
				var nc = c + offset.y
				if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLUMNS:
					continue
				if _is_plant_cell(nr, nc) or grid_i[nr][nc] == -1 or _is_cell_ice_locked(nr, nc):
					continue
				if grid_poison[nr][nc]:
					if is_src_ally: ally_pressure[nr][nc] += base_weight
					else: enemy_pressure[nr][nc] += base_weight

			# 2. 空きマスへの伝染：伝染進化（poison_mid_b）所持時のみ実行
			var can_spread_to_empty = ally_can_spread if is_src_ally else enemy_can_spread
			if can_spread_to_empty:
				var empty_candidates: Array[Vector2i] = []
				for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nr = r + offset.x
					var nc = c + offset.y
					if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLUMNS:
						continue
					if _is_plant_cell(nr, nc) or grid_i[nr][nc] == -1 or _is_cell_ice_locked(nr, nc):
						continue
					# 水の結界保護
					if grid_water.size() == GRID_ROWS and grid_water[nr][nc]:
						var water_ally = is_ally_water(nr, nc)
						if has_actor_skill_trait(water_ally, "water", "water_final_b2"):
							continue
					if not grid_poison[nr][nc]:
						empty_candidates.append(Vector2i(nr, nc))

				if not empty_candidates.is_empty():
					var chosen: Vector2i = empty_candidates[randi() % empty_candidates.size()]
					if is_src_ally:
						ally_pressure[chosen.x][chosen.y] += base_weight
					else:
						if not _check_and_block_enemy_hazard(chosen.x, chosen.y):
							enemy_pressure[chosen.x][chosen.y] += base_weight

	var newly_infected: Array[Vector2i] = []
	var invaded_ally_cells: Array[Vector2i] = []
	var invaded_enemy_cells: Array[Vector2i] = []

	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if _is_plant_cell(r, c) or grid_i[r][c] == -1 or _is_cell_ice_locked(r, c):
				continue

			var ap = ally_pressure[r][c]
			var ep = enemy_pressure[r][c]

			if not grid_poison[r][c]:
				if ap > 0 or ep > 0:
					next_poison[r][c] = true
					if ap > ep:
						next_poison_ally[r][c] = true
						if has_actor_skill_trait(true, "poison", "poison_final_b2"):
							enemy_blight_stacks = mini(10, enemy_blight_stacks + 1)
					elif ep > ap:
						next_poison_ally[r][c] = false
						if has_actor_skill_trait(false, "poison", "poison_final_b2"):
							player_blight_stacks = mini(10, player_blight_stacks + 1)
					else:
						var r_ally = (randf() < 0.5)
						next_poison_ally[r][c] = r_ally
						if r_ally and has_actor_skill_trait(true, "poison", "poison_final_b2"):
							enemy_blight_stacks = mini(10, enemy_blight_stacks + 1)
						elif not r_ally and has_actor_skill_trait(false, "poison", "poison_final_b2"):
							player_blight_stacks = mini(10, player_blight_stacks + 1)
					if grid_poison_stage.size() == GRID_ROWS:
						grid_poison_stage[r][c] = 1
					newly_infected.append(Vector2i(r, c))
			else:
				var is_curr_ally = is_ally_poison(r, c)
				if is_curr_ally:
					var ally_def = ap + 1
					if ep > ally_def or (ep >= ally_def and randf() < 0.5):
						next_poison_ally[r][c] = false
						if has_actor_skill_trait(false, "poison", "poison_final_b2"):
							player_blight_stacks = mini(10, player_blight_stacks + 1)
						invaded_enemy_cells.append(Vector2i(r, c))
				else:
					var enemy_def = ep + 1
					if ap > enemy_def or (ap >= enemy_def and randf() < 0.5):
						next_poison_ally[r][c] = true
						if has_actor_skill_trait(true, "poison", "poison_final_b2"):
							enemy_blight_stacks = mini(10, enemy_blight_stacks + 1)
						invaded_ally_cells.append(Vector2i(r, c))

	grid_poison = next_poison
	grid_poison_ally = next_poison_ally

	# 演出
	if not invaded_ally_cells.is_empty():
		for p in invaded_ally_cells.slice(0, 3):
			_spawn_poison_bubble_burst_effect(get_cell_position(p.x, p.y))
		var first_pos = get_cell_position(invaded_ally_cells[0].x, invaded_ally_cells[0].y)
		_spawn_floating_text(first_pos, "🧪 薬毒浄化侵攻！", Color(0.25, 1.0, 0.75))

	if not invaded_enemy_cells.is_empty():
		for p in invaded_enemy_cells.slice(0, 3):
			_spawn_poison_bubble_burst_effect(get_cell_position(p.x, p.y))
		var first_pos = get_cell_position(invaded_enemy_cells[0].x, invaded_enemy_cells[0].y)
		_spawn_floating_text(first_pos, "☠ 猛毒侵蝕！", Color(0.85, 0.25, 0.95))

	if not newly_infected.is_empty():
		for p in newly_infected.slice(0, 3):
			_spawn_poison_bubble_burst_effect(get_cell_position(p.x, p.y))
		var first_pos = get_cell_position(newly_infected[0].x, newly_infected[0].y)
		_spawn_floating_text(first_pos, "☠ 猛毒伝染！", Color(0.85, 0.35, 0.95))

	_update_status_ailments()
	_redraw_board_effects()

## ジグルフィードバック演出（操作不可・拒否時の揺れ演出）
func _shake_ice_jiggle(r: int, c: int) -> void:
	_jiggle_cell_piece(r, c, Color(0.6, 0.9, 1.0, 0.8))

func _shake_stone_jiggle(r: int, c: int) -> void:
	_jiggle_cell_piece(r, c, Color(0.5, 0.4, 0.3, 0.8))

func _shake_gold_jiggle(r: int, c: int) -> void:
	_jiggle_cell_piece(r, c, Color(1.0, 0.85, 0.2, 0.8))

func _jiggle_cell_piece(r: int, c: int, color: Color) -> void:
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS: return
	var p_idx = grid_i[r][c]
	if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
		var sp = piece[p_idx]
		var orig_pos = get_cell_position(r, c)
		var tw = create_tween()
		tw.tween_property(sp, "position:x", orig_pos.x - 15.0, 0.04)
		tw.tween_property(sp, "position:x", orig_pos.x + 15.0, 0.04)
		tw.tween_property(sp, "position:x", orig_pos.x - 8.0, 0.04)
		tw.tween_property(sp, "position:x", orig_pos.x, 0.04)

	var center = get_cell_position(r, c)
	for i in range(4):
		var p = ColorRect.new()
		p.size = Vector2(14.0, 14.0)
		p.position = center - p.size / 2.0
		p.color = color
		p.z_index = 25
		Profiler.add_child_count += 1; add_child(p)
		var a = randf() * TAU
		var tw_p = create_tween().set_parallel(true)
		tw_p.tween_property(p, "position", center + Vector2(cos(a), sin(a)) * 70.0, 0.22).set_ease(Tween.EASE_OUT)
		tw_p.tween_property(p, "modulate:a", 0.0, 0.22)
		tw_p.chain().tween_callback(p.queue_free)

## ❄️ 氷晶弾エフェクト: 起点（起爆位置や敵位置）から各凍結マスへ氷晶を飛翔させ、着弾時に氷結演出を展開
func _spawn_ice_shard_projectile(from_pos: Vector2, to_pos: Vector2, delay: float = 0.0, on_reach: Callable = Callable()) -> void:
	if not is_inside_tree() or get_tree() == null:
		if on_reach.is_valid():
			on_reach.call()
		return

	var p = get_parent()
	var root_node = p if p != null else self

	var shard_holder = Node2D.new()
	shard_holder.position = from_pos
	shard_holder.z_index = 45

	var shard_visual = Node2D.new()
	shard_visual.draw.connect(func():
		var c_main = Color(0.4, 0.9, 1.0, 0.95)
		var c_core = Color(1.0, 1.0, 1.0, 1.0)
		shard_visual.draw_circle(Vector2.ZERO, 8.0, c_main)
		shard_visual.draw_circle(Vector2.ZERO, 4.0, c_core)
		for i in range(6):
			var a = float(i) * (PI / 3.0)
			var p_out = Vector2(cos(a), sin(a)) * 14.0
			shard_visual.draw_line(Vector2.ZERO, p_out, c_core, 2.5)
	)
	shard_holder.add_child(shard_visual)
	Profiler.add_child_count += 1
	root_node.add_child(shard_holder)

	var tw = create_tween()
	if delay > 0.0:
		shard_holder.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func():
			if is_instance_valid(shard_holder):
				shard_holder.visible = true
		)

	var fly_time = 0.22
	tw.tween_property(shard_holder, "position", to_pos, fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shard_visual, "rotation", TAU * 2.0, fly_time)
	tw.tween_callback(func():
		if is_instance_valid(shard_holder):
			shard_holder.queue_free()
			Profiler.queue_free_count += 1
		_spawn_ice_break_effect(to_pos)
		_spawn_shockwave_ring(to_pos, Color(0.5, 0.95, 1.0, 0.8), 50.0, 0.2)
		if on_reach.is_valid():
			on_reach.call()
	)

## ❄️ 氷スキル発動の展開過程アニメーション（I5: 中心・起点から順に凍結が広がる過程を描画）
func _play_ice_freeze_expansion(cells: Array[Vector2i], origin_pos: Vector2 = Vector2.ZERO, animate: bool = true) -> void:
	if cells.is_empty():
		return
	if origin_pos == Vector2.ZERO:
		origin_pos = get_cell_position(cells[0].x, cells[0].y)

	# 起点からのユークリッド距離でソート（中心から外側へ順に展開）
	var sorted_cells = cells.duplicate()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a = get_cell_position(a.x, a.y)
		var pos_b = get_cell_position(b.x, b.y)
		return pos_a.distance_squared_to(origin_pos) < pos_b.distance_squared_to(origin_pos)
	)

	if animate and is_inside_tree() and get_tree() != null:
		_spawn_shockwave_ring(origin_pos, Color(0.4, 0.9, 1.0, 0.9), 110.0, 0.3)
		for i in range(sorted_cells.size()):
			var c = sorted_cells[i]
			var c_pos = get_cell_position(c.x, c.y)
			var delay = float(i) * 0.06
			_spawn_ice_shard_projectile(origin_pos, c_pos, delay)
	else:
		for c in sorted_cells:
			var c_pos = get_cell_position(c.x, c.y)
			_spawn_ice_break_effect(c_pos)


## 🧪 毒スキルプロジェクタイル演出（起点から対象マスへ毒泡・胞子弾が飛翔）
func _spawn_poison_bubble_projectile(from_pos: Vector2, to_pos: Vector2, delay: float = 0.0, on_reach: Callable = Callable()) -> void:
	if not is_inside_tree() or get_tree() == null:
		if on_reach.is_valid():
			on_reach.call()
		return

	var p = get_parent()
	var root_node = p if p != null else self

	var bubble_holder = Node2D.new()
	bubble_holder.position = from_pos
	bubble_holder.z_index = 45

	var bubble_visual = Node2D.new()
	bubble_visual.draw.connect(func():
		var c_main = Color(0.72, 0.22, 0.92, 0.92)
		var c_core = Color(0.28, 0.96, 0.45, 0.95)
		bubble_visual.draw_circle(Vector2.ZERO, 9.0, c_main)
		bubble_visual.draw_circle(Vector2.ZERO, 5.0, c_core)
		for i in range(4):
			var a = float(i) * (PI / 2.0)
			var p_out = Vector2(cos(a), sin(a)) * 11.0
			bubble_visual.draw_circle(p_out, 3.0, c_core)
	)
	bubble_holder.add_child(bubble_visual)
	Profiler.add_child_count += 1
	root_node.add_child(bubble_holder)

	var tw = create_tween()
	if delay > 0.0:
		bubble_holder.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func():
			if is_instance_valid(bubble_holder):
				bubble_holder.visible = true
		)

	var fly_time = 0.22
	tw.tween_property(bubble_holder, "position", to_pos, fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bubble_visual, "rotation", TAU * 1.5, fly_time)
	tw.tween_callback(func():
		if is_instance_valid(bubble_holder):
			bubble_holder.queue_free()
			Profiler.queue_free_count += 1
		_spawn_poison_bubble_burst_effect(to_pos)
		_spawn_shockwave_ring(to_pos, Color(0.68, 0.28, 0.95, 0.8), 50.0, 0.2)
		if on_reach.is_valid():
			on_reach.call()
	)

## 🧪 毒スキル発動の展開アニメーション（ランダム対象マスへ起点から毒泡が飛翔）
func _play_poison_expansion(cells: Array[Vector2i], origin_pos: Vector2 = Vector2.ZERO, animate: bool = true) -> void:
	if cells.is_empty():
		return
	if origin_pos == Vector2.ZERO:
		origin_pos = get_cell_position(cells[0].x, cells[0].y)

	var sorted_cells = cells.duplicate()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a = get_cell_position(a.x, a.y)
		var pos_b = get_cell_position(b.x, b.y)
		return pos_a.distance_squared_to(origin_pos) < pos_b.distance_squared_to(origin_pos)
	)

	if animate and is_inside_tree() and get_tree() != null:
		_spawn_shockwave_ring(origin_pos, Color(0.65, 0.25, 0.95, 0.9), 110.0, 0.3)
		for i in range(sorted_cells.size()):
			var c = sorted_cells[i]
			var c_pos = get_cell_position(c.x, c.y)
			var delay = float(i) * 0.06
			_spawn_poison_bubble_projectile(origin_pos, c_pos, delay)
	else:
		for c in sorted_cells:
			var c_pos = get_cell_position(c.x, c.y)
			_spawn_poison_bubble_burst_effect(c_pos)


## ✨ 聖光スキルプロジェクタイル演出（起点から対象マスへ聖光弾・光星が飛翔）
func _spawn_holy_light_projectile(from_pos: Vector2, to_pos: Vector2, delay: float = 0.0, on_reach: Callable = Callable()) -> void:
	if not is_inside_tree() or get_tree() == null:
		if on_reach.is_valid():
			on_reach.call()
		return

	var p = get_parent()
	var root_node = p if p != null else self

	var light_holder = Node2D.new()
	light_holder.position = from_pos
	light_holder.z_index = 45

	var light_visual = Node2D.new()
	light_visual.draw.connect(func():
		var c_main = Color(1.0, 0.88, 0.32, 0.95)
		var c_core = Color(1.0, 1.0, 0.95, 1.0)
		light_visual.draw_circle(Vector2.ZERO, 8.5, c_main)
		light_visual.draw_circle(Vector2.ZERO, 4.5, c_core)
		light_visual.draw_line(Vector2(-14, 0), Vector2(14, 0), c_core, 2.2)
		light_visual.draw_line(Vector2(0, -14), Vector2(0, 14), c_core, 2.2)
	)
	light_holder.add_child(light_visual)
	Profiler.add_child_count += 1
	root_node.add_child(light_holder)

	var tw = create_tween()
	if delay > 0.0:
		light_holder.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func():
			if is_instance_valid(light_holder):
				light_holder.visible = true
		)

	var fly_time = 0.22
	tw.tween_property(light_holder, "position", to_pos, fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(light_visual, "rotation", TAU * 2.0, fly_time)
	tw.tween_callback(func():
		if is_instance_valid(light_holder):
			light_holder.queue_free()
			Profiler.queue_free_count += 1
		_spawn_gold_shatter_effect(to_pos)
		_spawn_shockwave_ring(to_pos, Color(1.0, 0.95, 0.4, 0.8), 55.0, 0.2)
		if on_reach.is_valid():
			on_reach.call()
	)

## ✨ 聖像から敵への攻撃ビームを表示（自動斉射・聖像破壊追撃の共通演出）
func _spawn_statue_strike_effect(from_pos: Vector2, target_pos: Vector2, damage: float, delay: float = 0.0) -> void:
	_spawn_holy_light_projectile(from_pos, target_pos, delay, func():
		_spawn_holy_light_effect(target_pos, [target_pos])
		_spawn_shockwave_ring(target_pos, Color(1.0, 0.95, 0.45, 0.9), 260.0, 0.3)
		_spawn_floating_text(target_pos, "✨ 聖像攻撃 -%d" % int(damage), Color(1.0, 0.95, 0.4))
	)

## ✨ 光スキル発動の展開アニメーション（ランダム対象マスへ起点から聖光弾が飛翔）
func _play_light_expansion(cells: Array[Vector2i], origin_pos: Vector2 = Vector2.ZERO, animate: bool = true) -> void:
	if cells.is_empty():
		return
	if origin_pos == Vector2.ZERO:
		origin_pos = get_cell_position(cells[0].x, cells[0].y)

	var sorted_cells = cells.duplicate()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a = get_cell_position(a.x, a.y)
		var pos_b = get_cell_position(b.x, b.y)
		return pos_a.distance_squared_to(origin_pos) < pos_b.distance_squared_to(origin_pos)
	)

	if animate and is_inside_tree() and get_tree() != null:
		_spawn_shockwave_ring(origin_pos, Color(1.0, 0.95, 0.4, 0.9), 110.0, 0.3)
		for i in range(sorted_cells.size()):
			var c = sorted_cells[i]
			var c_pos = get_cell_position(c.x, c.y)
			var delay = float(i) * 0.06
			_spawn_holy_light_projectile(origin_pos, c_pos, delay)
	else:
		for c in sorted_cells:
			var c_pos = get_cell_position(c.x, c.y)
			_spawn_gold_shatter_effect(c_pos)


## エフェクト演出（氷割れ・石粉砕・黄金像破壊・感電・呪い）
func _spawn_ice_break_effect(pos: Vector2) -> void:
	_spawn_shockwave_ring(pos, Color(0.7, 0.95, 1.0), 90.0, 0.25)
	for i in range(8):
		var a = randf() * TAU
		var dist = randf_range(50.0, 120.0)
		var shard = Line2D.new()
		shard.width = 6.0
		shard.default_color = Color(0.8, 0.95, 1.0, 0.95)
		shard.points = PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * 25.0])
		shard.position = pos
		shard.z_index = 28
		Profiler.add_child_count += 1; add_child(shard)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(shard, "position", pos + Vector2(cos(a), sin(a)) * dist, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(shard, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(shard.queue_free)

func _spawn_stone_break_effect(pos: Vector2) -> void:
	_spawn_shockwave_ring(pos, Color(0.6, 0.5, 0.4), 80.0, 0.22)
	for i in range(8):
		var a = randf() * TAU
		var dist = randf_range(40.0, 100.0)
		var dust = ColorRect.new()
		dust.size = Vector2(16.0, 16.0)
		dust.position = pos - dust.size / 2.0
		dust.color = Color(0.45, 0.38, 0.32, 0.9)
		dust.z_index = 28
		Profiler.add_child_count += 1; add_child(dust)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(dust, "position", pos + Vector2(cos(a), sin(a)) * dist, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(dust, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(dust.queue_free)

func _spawn_gold_shatter_effect(pos: Vector2) -> void:
	_spawn_shockwave_ring(pos, Color(1.0, 0.88, 0.3), 110.0, 0.3)
	for i in range(12):
		var a = randf() * TAU
		var dist = randf_range(60.0, 150.0)
		var coin = ColorRect.new()
		coin.size = Vector2(18.0, 18.0)
		coin.position = pos - coin.size / 2.0
		coin.color = Color(1.0, 0.90, 0.2, 0.95)
		coin.z_index = 28
		Profiler.add_child_count += 1; add_child(coin)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(coin, "position", pos + Vector2(cos(a), sin(a)) * dist, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(coin.queue_free)

func _spawn_shock_zap_effect(pos: Vector2) -> void:
	_spawn_shockwave_ring(pos, Color(1.0, 0.95, 0.2), 100.0, 0.2)
	for i in range(6):
		var a = randf() * TAU
		var sp = Line2D.new()
		sp.width = 8.0
		sp.default_color = Color(1.0, 1.0, 0.4, 0.95)
		var pts = _generate_lightning_bolt_points(pos, pos + Vector2(cos(a), sin(a)) * 80.0, 4, 20.0)
		sp.points = pts
		sp.z_index = 30
		Profiler.add_child_count += 1; add_child(sp)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(sp, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(sp.queue_free)

func _spawn_curse_burst_effect(pos: Vector2) -> void:
	_spawn_shockwave_ring(pos, Color(0.7, 0.1, 0.9), 110.0, 0.3)
	for i in range(8):
		var a = randf() * TAU
		var dist = randf_range(50.0, 120.0)
		var orb = ColorRect.new()
		orb.size = Vector2(20.0, 20.0)
		orb.position = pos - orb.size / 2.0
		orb.color = Color(0.4, 0.05, 0.6, 0.85)
		orb.z_index = 30
		Profiler.add_child_count += 1; add_child(orb)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(orb, "position", pos + Vector2(cos(a), sin(a)) * dist, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(orb, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(orb.queue_free)

func _spawn_poison_bubble_burst_effect(pos: Vector2) -> void:
	_spawn_shockwave_ring(pos, Color(0.68, 0.15, 0.90), 105.0, 0.28)
	for i in range(7):
		var a = randf() * TAU
		var dist = randf_range(40.0, 110.0)
		var orb = ColorRect.new()
		var s_dim = randf_range(16.0, 24.0)
		orb.size = Vector2(s_dim, s_dim)
		orb.position = pos - orb.size / 2.0
		orb.color = Color(0.60, 0.10, 0.85, 0.85)
		orb.z_index = 30
		Profiler.add_child_count += 1; add_child(orb)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(orb, "position", pos + Vector2(cos(a), sin(a)) * dist + Vector2(0, -25), 0.32).set_ease(Tween.EASE_OUT)
		tw.tween_property(orb, "modulate:a", 0.0, 0.32)
		tw.chain().tween_callback(orb.queue_free)

## 戦闘発射物・シールド・攻撃エフェクトの全消去（蓄積・メモリリーク・重さの完全根絶）
func _clear_all_combat_projectiles(preserve_shields: bool = false) -> void:
	for item in flying_swords:
		if is_instance_valid(item.get("node")):
			_return_sprite_to_pool(item["node"])
	flying_swords.clear()

	if not preserve_shields:
		for item in active_shields:
			if is_instance_valid(item.get("node")):
				_return_sprite_to_pool(item["node"])
		active_shields.clear()
		current_total_shields = 0
		current_shield_pools.clear()

	for item in flying_foods:
		if is_instance_valid(item.get("node")):
			_return_sprite_to_pool(item["node"])
	flying_foods.clear()
	
	for item in flying_potions:
		if is_instance_valid(item.get("node")):
			_return_sprite_to_pool(item["node"])
	flying_potions.clear()
	
	for item in flying_cells:
		if is_instance_valid(item.get("node")):
			_return_sprite_to_pool(item["node"])
	flying_cells.clear()
## ターン終了時リセット
func _reset_turn(sm: Node2D, score_mgr: Node2D) -> void:
	has_emitted_items_scored = false
	if player_shock_stacks > 0:
		player_shock_stacks = maxi(0, player_shock_stacks - 1)
	is_enemy_turn_in_progress = false
	if _enemy_turn_tween and _enemy_turn_tween.is_valid():
		_enemy_turn_tween.kill()
		_enemy_turn_tween = null
	turn_skill_log.clear()
	cells_cleared_by_special.clear()
	var _sm_for_reset = _get_score_manager()
	if _sm_for_reset and _sm_for_reset.has_method("reset_turn_elements"):
		_sm_for_reset.reset_turn_elements()
	if sm and sm.has_method("stop_enemy_animation"):
		sm.stop_enemy_animation()
	if sm and sm.has_method("reset_enemy_zoom"):
		sm.reset_enemy_zoom(0.0)
	if sm and "active_enemies" in sm:
		for en_data in sm.active_enemies:
			en_data["just_summoned"] = false

	# 敵スキル演出ノードを安全に消去
	if get_tree():
		var p = get_parent()
		if p != null:
			var vc = p.get_node_or_null("VFXContainer")
			if vc:
				for child in vc.get_children():
					child.queue_free(); Profiler.queue_free_count += 1

	if score_mgr:
		self.score_manager = score_mgr
	var has_ice_preservation = score_mgr and score_mgr.has_method("has_skill_trait") and score_mgr.has_skill_trait("ice_1", "ice_mid_a")
	var preserve_shields: bool = has_ice_preservation or (pvp_mode and not active_shields.is_empty())
	# 残存発射物・シールド・エフェクトを確実に全消去してメモリと処理負荷をリセット
	_clear_all_combat_projectiles(preserve_shields)

	isattack = 0
	isblock = 0
	has_enemy_attacked = false
	has_enemy_skilled = false
	is_casting_skill_turn = false
	isswap = false
	endbreak = false
	isbreak = false
	interval = 0

	# 氷中間進化: 氷甲の残留（シールド持ち越し）、またはPvPでの敵ターン終了までのシールド維持
	if not preserve_shields:
		current_total_shields = 0
		if sm and "guard" in sm:
			sm.guard = 0.0
	_restore_score_label_positions()
	if sm and "active_enemies" in sm and not sm.active_enemies.is_empty() and not sm.isdeadf and sm.ehp > 0:
		_decide_enemy_actions(sm)

	if sm and not sm.isfevertime and sm.fevergage >= 7000.0:
		sm.fevertime()
	elif sm and sm.isfevertime:
		sm.fevercount -= 1
		if sm.fevercount <= 0:
			sm.notfevertime()

	if score_mgr and "combocount" in score_mgr: score_mgr.combocount = 0
	var rensa_se = get_node_or_null("1rensa")
	if rensa_se:
		var spd: float = 1.0
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "game_speed" in sm_autoload:
			spd = sm_autoload.game_speed
		rensa_se.pitch_scale = 0.92 * spd

	# 黒い霧（瘴気 / 星影の霧）による持続ダメージ & ターン進行
	var f_idx = grid_fog.size() - 1
	var total_fog_dmg: float = 0.0
	var total_ally_fog_dmg: float = 0.0
	while f_idx >= 0:
		var fog_data = grid_fog[f_idx]
		var f_rect: Rect2i = fog_data.get("rect", Rect2i(0, 0, 0, 0))
		var is_enemy_fog: bool = fog_data.get("enemy_owned", true)
		var center_r = f_rect.position.x + f_rect.size.x / 2.0
		var center_c = f_rect.position.y + f_rect.size.y / 2.0
		var fog_center_pos = get_cell_position(int(center_r), int(center_c))

		var st_idx = _get_stage_index()
		var is_boss_enemy: bool = false
		if sm:
			if sm.has_method("is_boss_battle"):
				is_boss_enemy = sm.is_boss_battle()
			elif "is_current_boss" in sm:
				is_boss_enemy = sm.is_current_boss
		var base_fog_dmg: float = (50.0 + st_idx * 20.0) if is_boss_enemy else (20.0 + st_idx * 10.0)
		var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
		var cur_fog_dmg: float = base_fog_dmg * stage_scale * _get_difficulty_skill_mult()
		if is_enemy_fog:
			total_fog_dmg += cur_fog_dmg
			_spawn_floating_text(fog_center_pos, "瘴気ダメージ -%d" % int(cur_fog_dmg), Color(0.85, 0.3, 0.95))
		else:
			total_ally_fog_dmg += cur_fog_dmg
			_spawn_floating_text(fog_center_pos, "🌙 星影追撃 %d!" % int(cur_fog_dmg), Color(0.55, 0.90, 1.0))
		_spawn_curse_burst_effect(fog_center_pos)

		fog_data["turns"] -= 1
		if fog_data["turns"] <= 0:
			grid_fog.remove_at(f_idx)
			_spawn_floating_text(fog_center_pos, "暗雲消滅！" if is_enemy_fog else "星影の霧終了", Color(0.7, 0.9, 1.0))
		f_idx -= 1

	if sm and total_ally_fog_dmg > 0.0:
		sm.calchp(total_ally_fog_dmg, 0.0)
		_emit_combat_event("damage", "ally", "enemy", total_ally_fog_dmg, "ally_dark_fog")

	if sm and total_fog_dmg > 0.0:
		_spawn_screen_flash(Color(0.5, 0.1, 0.7, 0.25), 0.15)
		sm.last_damage_cause = "暗雲・黒霧の浸食ダメージ"
		sm.calchp(0.0, total_fog_dmg)
		_emit_combat_event("damage", "enemy", "ally", total_fog_dmg, "dark_fog")
		var rm_fog = _get_relic_manager()
		if rm_fog: rm_fog.on_backlash_damage("fog", total_fog_dmg)
		if sm.myhp <= 0:
			_trigger_gameover(sm)

	# 猛毒沼 / 薬毒（grid_poison）による持続ダメージ（段階倍率・蝕み・毒素免疫の対称適用）
	var enemy_poison_tiles: Array[Vector2i] = []
	var ally_poison_tiles: Array[Vector2i] = []
	if grid_poison.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_poison[r][c]:
					if is_ally_poison(r, c):
						ally_poison_tiles.append(Vector2i(r, c))
					else:
						enemy_poison_tiles.append(Vector2i(r, c))

	var stage_scale_p: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
	var st_idx_p = _get_stage_index()

	# 味方毒による敵へのダメージ
	if not ally_poison_tiles.is_empty():
		var total_ally_p_dmg: float = 0.0
		for pt in ally_poison_tiles:
			var st = grid_poison_stage[pt.x][pt.y] if (grid_poison_stage.size() == GRID_ROWS and pt.x < grid_poison_stage.size() and pt.y < grid_poison_stage[pt.x].size()) else 1
			var mult = 1.0 if st == 1 else (1.6 if st == 2 else 2.2)
			var base_d = (20.0 + st_idx_p * 10.0) * mult * stage_scale_p
			total_ally_p_dmg += base_d

		# 敵側の毒素抗体免疫 (-5%/個, 最大40%)
		var enemy_imm_rate = clampf(float(enemy_poison_tiles.size()) * 0.05, 0.0, 0.40)
		total_ally_p_dmg *= (1.0 - enemy_imm_rate)
		# 敵側の蝕みスタック (+10%/スタック)
		if enemy_blight_stacks > 0:
			total_ally_p_dmg *= (1.0 + float(enemy_blight_stacks) * 0.10)

		var center_apt = ally_poison_tiles[ally_poison_tiles.size() / 2]
		_spawn_floating_text(get_cell_position(center_apt.x, center_apt.y), "🧪 薬毒追撃 %d!" % int(total_ally_p_dmg), Color(0.25, 1.0, 0.75))
		if sm:
			sm.calchp(total_ally_p_dmg, 0.0)
			_emit_combat_event("damage", "ally", "enemy", total_ally_p_dmg, "ally_poison")

	# 敵毒によるプレイヤーへのダメージ
	if not enemy_poison_tiles.is_empty():
		var is_boss_enemy: bool = false
		if sm:
			if sm.has_method("is_boss_battle"): is_boss_enemy = sm.is_boss_battle()
			elif "is_current_boss" in sm: is_boss_enemy = sm.is_current_boss

		var total_poison_dmg: float = 0.0
		for pt in enemy_poison_tiles:
			var st = grid_poison_stage[pt.x][pt.y] if (grid_poison_stage.size() == GRID_ROWS and pt.x < grid_poison_stage.size() and pt.y < grid_poison_stage[pt.x].size()) else 1
			var mult = 1.0 if st == 1 else (1.6 if st == 2 else 2.2)
			var base_d = ((25.0 + st_idx_p * 12.0) if is_boss_enemy else (12.0 + st_idx_p * 6.0)) * mult * stage_scale_p * _get_difficulty_skill_mult()
			total_poison_dmg += base_d

		# プレイヤー側の毒素抗体免疫 (-5%/個, 最大40%)
		var player_imm_rate = clampf(float(ally_poison_tiles.size()) * 0.05, 0.0, 0.40)
		total_poison_dmg *= (1.0 - player_imm_rate)
		# プレイヤー側の蝕みスタック (+10%/スタック)
		if player_blight_stacks > 0:
			total_poison_dmg *= (1.0 + float(player_blight_stacks) * 0.10)

		for pt in enemy_poison_tiles.slice(0, 8):
			_spawn_poison_bubble_burst_effect(get_cell_position(pt.x, pt.y))

		var center_pt = enemy_poison_tiles[enemy_poison_tiles.size() / 2]
		_spawn_floating_text(get_cell_position(center_pt.x, center_pt.y), "猛毒ダメージ -%d" % int(total_poison_dmg), Color(0.85, 0.35, 0.95))
		_spawn_status_damage_banner("☠ 猛毒ダメージ -%d" % int(total_poison_dmg), Color(0.95, 0.4, 1.0))

		if sm:
			_trigger_screen_shake(9.0)
			sm.last_damage_cause = "猛毒マスの侵食ダメージ"
			sm.calchp(0.0, total_poison_dmg)
			_emit_combat_event("damage", "enemy", "ally", total_poison_dmg, "poison")
			var rm_poi = _get_relic_manager()
			if rm_poi: rm_poi.on_backlash_damage("poison", total_poison_dmg)
			if sm.myhp <= 0:
				_trigger_gameover(sm)
				return

	# 🧪 毒A2: 熟毒 (ターン終了時に毒段階が1上昇、最大3)
	if has_actor_skill_trait(true, "poison", "poison_final_a2"):
		for pt in ally_poison_tiles:
			if grid_poison_stage.size() == GRID_ROWS:
				grid_poison_stage[pt.x][pt.y] = mini(3, grid_poison_stage[pt.x][pt.y] + 1)
	if has_actor_skill_trait(false, "poison", "poison_final_a2"):
		for pt in enemy_poison_tiles:
			if grid_poison_stage.size() == GRID_ROWS:
				grid_poison_stage[pt.x][pt.y] = mini(3, grid_poison_stage[pt.x][pt.y] + 1)

	# 🧪 毒B1: 腐食 (自陣毒マス上の敵石・敵黄金像の耐久を毎ターン-1)
	if has_actor_skill_trait(true, "poison", "poison_final_b1"):
		for pt in ally_poison_tiles:
			var pr = pt.x; var pc = pt.y
			if grid_stones.size() == GRID_ROWS and grid_stones[pr][pc] > 0 and not is_ally_stone(pr, pc):
				_damage_stone_at(pr, pc, 1)
				_spawn_floating_text(get_cell_position(pr, pc), "🧪 毒腐食！敵石耐久-1", Color(0.6, 0.9, 0.2))
			if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[pr][pc] > 0 and not is_ally_gold(pr, pc):
				grid_gold_statue[pr][pc] = maxi(0, grid_gold_statue[pr][pc] - 1)
				if grid_gold_statue[pr][pc] == 0:
					_spawn_gold_shatter_effect(get_cell_position(pr, pc))
				_spawn_floating_text(get_cell_position(pr, pc), "🧪 毒腐食！敵像耐久-1", Color(0.6, 0.9, 0.2))

	# 炎マス / 蒼炎（grid_fire）による持続ダメージ（自分による蒼炎は敵へダメージ！）
	var enemy_fire_tiles: Array[Vector2i] = []
	var ally_fire_tiles: Array[Vector2i] = []
	if grid_fire.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_fire[r][c] > 0:
					if is_ally_fire(r, c):
						ally_fire_tiles.append(Vector2i(r, c))
					else:
						enemy_fire_tiles.append(Vector2i(r, c))
	if not ally_fire_tiles.is_empty():
		var st_idx = _get_stage_index()
		var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
		var base_af_dmg: float = 25.0 + st_idx * 12.0
		var total_ally_fire_dmg: float = base_af_dmg * stage_scale * float(ally_fire_tiles.size())
		var center_aft = ally_fire_tiles[ally_fire_tiles.size() / 2]
		_spawn_floating_text(get_cell_position(center_aft.x, center_aft.y), "🔥 蒼炎追撃 %d!" % int(total_ally_fire_dmg), Color(0.30, 0.92, 1.0))
		if sm:
			sm.calchp(total_ally_fire_dmg, 0.0)
			_emit_combat_event("damage", "ally", "enemy", total_ally_fire_dmg, "ally_fire")
	if not enemy_fire_tiles.is_empty():
		var st_idx = _get_stage_index()
		var is_boss_enemy: bool = false
		if sm:
			if sm.has_method("is_boss_battle"): is_boss_enemy = sm.is_boss_battle()
			elif "is_current_boss" in sm: is_boss_enemy = sm.is_current_boss
		var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
		var base_f_dmg: float = (30.0 + st_idx * 15.0) if is_boss_enemy else (15.0 + st_idx * 8.0)
		var total_fire_dmg: float = base_f_dmg * stage_scale * float(enemy_fire_tiles.size()) * _get_difficulty_skill_mult()
		for ft in enemy_fire_tiles.slice(0, 3):
			var ft_pos = get_cell_position(ft.x, ft.y)
			_spawn_fire_ignition_effect(ft_pos, false)
		var center_ft = enemy_fire_tiles[enemy_fire_tiles.size() / 2]
		_spawn_floating_text(get_cell_position(center_ft.x, center_ft.y), "火傷ダメージ -%d" % int(total_fire_dmg), Color(1.0, 0.45, 0.1))
		if sm:
			_spawn_screen_flash(Color(0.8, 0.2, 0.1, 0.22), 0.15)
			sm.last_damage_cause = "火炎マスの延焼ダメージ"
			sm.calchp(0.0, total_fire_dmg)
			_emit_combat_event("damage", "enemy", "ally", total_fire_dmg, "fire")
			var rm_f = _get_relic_manager()
			if rm_f: rm_f.on_backlash_damage("fire", total_fire_dmg)
			if sm.myhp <= 0:
				_trigger_gameover(sm)

	# --- 全10属性・ターン終了時進化パッシブ処理 ---
	var stage_scale_evo = pow(10, max(0, (sm.stage - 1) if sm else 0))

	# ❄️ 氷のターン経過耐久値減少（永久凍土所持者は耐久減少なし）
	if grid_ice.size() == GRID_ROWS:
		for ir in range(GRID_ROWS):
			for ic in range(GRID_COLUMNS):
				if int(grid_ice[ir][ic]) > 0:
					var is_a = is_ally_ice(ir, ic)
					var has_permafrost = has_actor_skill_trait(is_a, "ice", "ice_mid_c")
					if not has_permafrost:
						grid_ice[ir][ic] = int(grid_ice[ir][ic]) - 1
						if int(grid_ice[ir][ic]) <= 0:
							grid_ice[ir][ic] = 0
							_set_ally_flag(grid_ice_ally, ir, ic, false)

	# ❄️ 氷C2: 氷原 (自軍氷が10マス未満なら毎ターン終了時に氷マス1個生成)
	if has_actor_skill_trait(true, "ice", "ice_final_c2"):
		var cur_ice_c = 0
		for ir in range(GRID_ROWS):
			for ic in range(GRID_COLUMNS):
				if int(grid_ice[ir][ic]) > 0 and is_ally_ice(ir, ic): cur_ice_c += 1
		if cur_ice_c < 10:
			var cands_ice: Array[Vector2i] = []
			for ir in range(GRID_ROWS):
				for ic in range(GRID_COLUMNS):
					if int(grid_ice[ir][ic]) == 0 and not _is_plant_cell(ir, ic) and grid_i[ir][ic] != -1:
						cands_ice.append(Vector2i(ir, ic))
			if not cands_ice.is_empty():
				var ch = cands_ice[randi() % cands_ice.size()]
				grid_ice[ch.x][ch.y] = 3
				_set_ally_flag(grid_ice_ally, ch.x, ch.y, true)
				_spawn_floating_text(get_cell_position(ch.x, ch.y), "❄️ 氷原自然凍結！", Color(0.4, 0.9, 1.0))

	# ❄️ 氷A1: 氷塊 (持ち越したシールド500ごとに氷マス生成、最大8マス)
	if has_actor_skill_trait(true, "ice", "ice_final_a1") and current_total_shields > 0:
		var target_ice = mini(8, int(current_total_shields / 500.0))
		var spawned_ice = 0
		if grid_ice.size() == GRID_ROWS:
			for ir in range(GRID_ROWS):
				if spawned_ice >= target_ice: break
				for ic in range(GRID_COLUMNS):
					if spawned_ice >= target_ice: break
					if int(grid_ice[ir][ic]) == 0 and not _is_plant_cell(ir, ic) and grid_i[ir][ic] != -1:
						grid_ice[ir][ic] = 3
						_set_ally_flag(grid_ice_ally, ir, ic, true)
						spawned_ice += 1
						_spawn_floating_text(get_cell_position(ir, ic), "❄️ 氷塊結成！", Color(0.4, 0.9, 1.0))

	# 💧 水マス進化 (A: 生命の清流 / B: 水華の防壁 / C: 激流の怒涛)
	var ally_water_cnt: int = 0
	var sample_water_pos: Vector2 = Vector2.ZERO
	if grid_water.size() == GRID_ROWS:
		for wr in range(GRID_ROWS):
			for wc in range(GRID_COLUMNS):
				if grid_water[wr][wc] and is_ally_water(wr, wc):
					ally_water_cnt += 1
					if sample_water_pos == Vector2.ZERO:
						sample_water_pos = get_cell_position(wr, wc)

	if ally_water_cnt > 0:
		var score_mgr_w = _get_score_manager()
		var sk_lvl_w = maxi(1, score_mgr_w.get_skill_level("water_1")) if score_mgr_w else 1

		# C 激流の怒涛: 水マス追撃
		if has_actor_skill_trait(true, "water", "water_mid_c"):
			var surge_dmg = (50.0 + sk_lvl_w * 12.0) * stage_scale_evo * float(ally_water_cnt)
			if sm and sm.ehp > 0 and not sm.isdeadf:
				sm.calchp(surge_dmg, 0.0)
				_emit_combat_event("damage", "ally", "enemy", surge_dmg, "water_surge")
				_spawn_floating_text(sample_water_pos, "🌊 激流水撃 %d! (水%dマス)" % [int(surge_dmg), ally_water_cnt], Color(0.2, 0.7, 1.0))

		# C2 渦潮: 最も水マスが多い列を消去して落下誘発＆ダメージ（水マスは消費しない）
		if has_actor_skill_trait(true, "water", "water_final_c2"):
			var best_col = -1
			var max_w = 0
			for c in range(GRID_COLUMNS):
				var col_w = 0
				for r in range(GRID_ROWS):
					if grid_water[r][c] and is_ally_water(r, c): col_w += 1
				if col_w > max_w:
					max_w = col_w
					best_col = c
			if best_col != -1 and max_w > 0:
				for r in range(GRID_ROWS):
					if grid_i[r][best_col] != -1: ismatched[r][best_col] = true
				var vortex_dmg = float(max_w) * (200.0 + sk_lvl_w * 40.0) * stage_scale_evo
				if sm and sm.ehp > 0 and not sm.isdeadf:
					sm.calchp(vortex_dmg, 0.0)
					_emit_combat_event("damage", "ally", "enemy", vortex_dmg, "water_vortex")
					_spawn_floating_text(get_cell_position(0, best_col), "🌊 渦潮！列消去＆大ダメージ -%d!" % int(vortex_dmg), Color(0.1, 0.7, 1.0))

		# A 生命の清流: HP回復（溢れる泉で超過回復はシールド化）
		if has_actor_skill_trait(true, "water", "water_mid_a"):
			var heal_amt = (20.0 + sk_lvl_w * 5.0) * stage_scale_evo * float(ally_water_cnt)
			if sm:
				var new_hp = sm.myhp + heal_amt
				if new_hp > sm.myhpmax and has_actor_skill_trait(true, "water", "water_final_a2"):
					var overflow = new_hp - sm.myhpmax
					_apply_skill_shield(overflow)
					sm.calchp(0.0, -(sm.myhpmax - sm.myhp))
					_spawn_floating_text(sample_water_pos, "💧 溢れる泉！超過回復シールド化 +%d!" % int(overflow), Color(0.4, 0.9, 1.0))
				else:
					sm.calchp(0.0, -heal_amt)
				_emit_combat_event("heal", "ally", "ally", heal_amt)
			_spawn_floating_text(sample_water_pos, "💧 清流治癒 +%d (水%dマス)" % [int(heal_amt), ally_water_cnt], Color(0.2, 0.9, 0.4))

		# B 水華の防壁: シールド獲得
		if has_actor_skill_trait(true, "water", "water_mid_b"):
			var shield_amt = (30.0 + sk_lvl_w * 8.0) * stage_scale_evo * float(ally_water_cnt)
			_apply_skill_shield(shield_amt)
			_spawn_floating_text(sample_water_pos, "🛡️ 水華防壁 +%d (水%dマス)" % [int(shield_amt), ally_water_cnt], Color(0.3, 0.8, 1.0))

	# 🌱 木B2: 毒棘 (ターン終了時、ランダムな植物の周囲1マスに味方毒配置)
	if has_actor_skill_trait(true, "wood", "wood_final_b2"):
		var ally_plants: Array[Dictionary] = []
		for pl in plant_entities:
			if is_ally_plant(pl): ally_plants.append(pl)
		if not ally_plants.is_empty():
			var pl_target = ally_plants[randi() % ally_plants.size()]
			var occ = _get_plant_occupied_cells(pl_target)
			var adj_cells: Array[Vector2i] = []
			for o_cell in occ:
				for off in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
					var nr = o_cell.x + off.x; var nc = o_cell.y + off.y
					if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
						if not grid_poison[nr][nc] and not _is_plant_cell(nr, nc):
							adj_cells.append(Vector2i(nr, nc))
			if not adj_cells.is_empty():
				var ch = adj_cells[randi() % adj_cells.size()]
				grid_poison[ch.x][ch.y] = true
				_set_ally_flag(grid_poison_ally, ch.x, ch.y, true)
				if grid_poison_stage.size() == GRID_ROWS:
					grid_poison_stage[ch.x][ch.y] = 1
				_spawn_floating_text(get_cell_position(ch.x, ch.y), "🌱 毒棘！薬毒配置！", Color(0.3, 1.0, 0.4))

	# ⚡ 雷B1: 放電 (帯電コイン枚数に応じた追加放電ダメージ)
	if has_actor_skill_trait(true, "thunder", "thunder_final_b1"):
		var charged_coins = 0
		if grid_electrified.size() == GRID_ROWS:
			for er in range(GRID_ROWS):
				for ec in range(GRID_COLUMNS):
					if grid_electrified[er][ec] and is_ally_electrified(er, ec):
						charged_coins += 1
		if charged_coins > 0:
			var score_mgr_th = _get_score_manager()
			var sk_lvl_th = maxi(1, score_mgr_th.get_skill_level("thunder_1")) if score_mgr_th else 1
			var discharge_dmg = float(charged_coins) * (60.0 + sk_lvl_th * 15.0) * stage_scale_evo
			if sm and sm.ehp > 0 and not sm.isdeadf:
				sm.calchp(discharge_dmg, 0.0)
				_emit_combat_event("damage", "ally", "enemy", discharge_dmg, "thunder_discharge")
				_spawn_floating_text(Vector2(640, 360), "⚡ 放電！帯電コイン蓄積ダメージ -%d!" % int(discharge_dmg), Color(1.0, 0.95, 0.3))

	# ⚡ 雷B2: 雷雨 (ターン開始時に駒2個に落雷して帯電)
	if has_actor_skill_trait(true, "thunder", "thunder_final_b2"):
		var cands_th: Array[Vector2i] = []
		for er in range(GRID_ROWS):
			for ec in range(GRID_COLUMNS):
				if not grid_electrified[er][ec] and not _is_plant_cell(er, ec) and grid_i[er][ec] != -1:
					cands_th.append(Vector2i(er, ec))
		cands_th.shuffle()
		var count_th = mini(2, cands_th.size())
		for ti in range(count_th):
			var tc = cands_th[ti]
			if _count_electrified_tiles() < MAX_ELECTRIFIED_TILES:
				grid_electrified[tc.x][tc.y] = true
				_set_ally_flag(grid_electrified_ally, tc.x, tc.y, true)
				_spawn_floating_text(get_cell_position(tc.x, tc.y), "⚡ 雷雨落雷！", Color(1.0, 0.9, 0.2))

	# 🔥 火A2: 二段爆発処理
	if not delayed_explosions.is_empty():
		var pending_d: Array[Dictionary] = []
		for exp_info in delayed_explosions:
			exp_info["delay"] -= 1
			if exp_info["delay"] <= 0:
				var er = exp_info["r"]; var ec = exp_info["c"]
				var rad = exp_info["radius"]
				_spawn_explosion_effect(get_cell_position(er, ec))
				for dr in range(-rad, rad + 1):
					for dc in range(-rad, rad + 1):
						var nr = er + dr; var nc = ec + dc
						if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
							if grid_i.size() == GRID_ROWS and grid_i[nr][nc] != -1: ismatched[nr][nc] = true
							if grid_stones.size() == GRID_ROWS and grid_stones[nr][nc] > 0:
								_damage_stone_at(nr, nc, exp_info.get("stone_dmg", 1))
				_spawn_floating_text(get_cell_position(er, ec), "🔥 二段爆発！", Color(1.0, 0.5, 0.1))
			else:
				pending_d.append(exp_info)
		delayed_explosions = pending_d

	# 🪨 地B1: 黄金化 (ターン終了時、石1個を黄金像に変化) & B2 金剛石 (2ターン生存でダイヤモンド)
	if grid_stones.size() == GRID_ROWS:
		# 破壊済みの石のカウントを掃除して辞書が増え続けないようにする
		for st_pos in stone_turn_counts.keys():
			if grid_stones[st_pos.x][st_pos.y] <= 0:
				stone_turn_counts.erase(st_pos)
		for d_pos in diamond_stones.keys():
			if grid_stones[d_pos.x][d_pos.y] <= 0:
				diamond_stones.erase(d_pos)
		var ally_st_list: Array[Vector2i] = []
		for str_r in range(GRID_ROWS):
			for str_c in range(GRID_COLUMNS):
				if grid_stones[str_r][str_c] > 0 and is_ally_stone(str_r, str_c):
					var st_pos = Vector2i(str_r, str_c)
					ally_st_list.append(st_pos)
					stone_turn_counts[st_pos] = stone_turn_counts.get(st_pos, 0) + 1
					if stone_turn_counts[st_pos] >= 2 and has_actor_skill_trait(true, "earth", "earth_final_b2"):
						diamond_stones[st_pos] = true
						grid_stones[str_r][str_c] = maxi(grid_stones[str_r][str_c], 5) # 耐久値+3
						_spawn_floating_text(get_cell_position(str_r, str_c), "💎 金剛石変異！", Color(0.3, 0.95, 1.0))
		if has_actor_skill_trait(true, "earth", "earth_final_b1") and not ally_st_list.is_empty():
			var chosen_st = ally_st_list[randi() % ally_st_list.size()]
			grid_stones[chosen_st.x][chosen_st.y] = 0
			stone_turn_counts.erase(chosen_st)
			diamond_stones.erase(chosen_st)
			grid_gold_statue[chosen_st.x][chosen_st.y] = 3
			_set_ally_flag(grid_gold_ally, chosen_st.x, chosen_st.y, true)
			_spawn_floating_text(get_cell_position(chosen_st.x, chosen_st.y), "🪨 黄金化！黄金像変異！", Color(1.0, 0.85, 0.2))

	# 🌪️ 風B1: 暴風圏ターン減算 & 風C1: 風の守りターン減算
	for c_idx in storm_zones.keys():
		storm_zones[c_idx] -= 1
		if storm_zones[c_idx] <= 0: storm_zones.erase(c_idx)
	for w_col in wind_ward_columns.keys():
		wind_ward_columns[w_col] -= 1
		if wind_ward_columns[w_col] <= 0: wind_ward_columns.erase(w_col)

	# 🌙 闇A: 自由スワップターン減算
	if free_swap_turns > 0:
		free_swap_turns -= 1
		if free_swap_turns == 0:
			has_dark_teleport_swap = false

	# ✨ 光A: 光輝の像 (毎ターン終了時、自陣全聖像から敵へ聖光弾自動斉射)
	if has_actor_skill_trait(true, "light", "light_mid_a"):
		var a_st_cnt = 0
		var statue_cells: Array[Vector2i] = []
		for st_r in range(GRID_ROWS):
			for st_c in range(GRID_COLUMNS):
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[st_r][st_c] > 0 and is_ally_gold(st_r, st_c):
					a_st_cnt += 1
					statue_cells.append(Vector2i(st_r, st_c))
		if a_st_cnt > 0 and sm and sm.has_method("calchp") and not sm.isdeadf and sm.ehp > 0:
			var sc_mgr_l = _get_score_manager()
			var sk_lvl_l = maxi(1, sc_mgr_l.get_skill_level("light_1")) if sc_mgr_l else 1
			var st_scale_l = pow(10, max(0, (sm.stage - 1) if sm else 0))
			var auto_shot_dmg = float(a_st_cnt) * (80.0 + sk_lvl_l * 15.0) * st_scale_l
			sm.calchp(auto_shot_dmg, 0.0)
			_emit_combat_event("damage", "ally", "enemy", auto_shot_dmg, "holy_statue_auto_shot")
			var en_pos = sm.enemy.position if (sm and sm.enemy) else Vector2(1550, 250)
			# 各聖像から敵へ聖光ビームを飛ばし、聖像由来のダメージであることを明示
			for i in range(statue_cells.size()):
				_spawn_statue_strike_effect(get_cell_position(statue_cells[i].x, statue_cells[i].y), en_pos, auto_shot_dmg / float(a_st_cnt), float(i) * 0.07)
			_spawn_floating_text(en_pos, "✨ 光輝の像・自動斉射 -%d!" % int(auto_shot_dmg), Color(1.0, 0.95, 0.4))

	# ✨ 光B2: 加護の像 (自陣の聖像が存在する限り、ターン終了時HP回復: 聖像数 × 120 HP)
	if has_actor_skill_trait(true, "light", "light_final_b2"):
		var ally_st_cnt = 0
		for st_r in range(GRID_ROWS):
			for st_c in range(GRID_COLUMNS):
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[st_r][st_c] > 0 and is_ally_gold(st_r, st_c):
					ally_st_cnt += 1
		if ally_st_cnt > 0 and sm and sm.has_method("calchp"):
			var heal_amt = float(ally_st_cnt) * 120.0
			sm.calchp(0.0, -heal_amt)
			_emit_combat_event("heal", "ally", "ally", heal_amt, "light_final_b2")
			_spawn_heal_number_effect(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2), int(heal_amt))
			_spawn_shockwave_ring(Vector2(140, 430), Color(0.5, 1.0, 0.65, 0.85), 260.0, 0.4)
			_spawn_floating_text(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2), "✨ 加護の像 +%d HP回復！" % int(heal_amt), Color(0.4, 1.0, 0.7))

	# ターンごとの1回制限フラグリセット
	poison_seed_used_this_turn = false
	turn_damage_taken = 0.0
	has_light_dazzle_this_turn = false
	has_light_sanctuary_this_turn = false
	has_light_tenrin_triggered_this_turn = false
	_update_status_ailments()
	_spawn_turn_bombs()
	# ターン開始時に存在した炎マスを記録（延焼で新しく発生したマスを即時減衰させないため）
	var fires_to_decay: Array[Vector2i] = []
	if grid_fire.size() == GRID_ROWS:
		for fr in range(GRID_ROWS):
			for fc in range(GRID_COLUMNS):
				if grid_fire[fr][fc] > 0 and not _is_plant_cell(fr, fc):
					fires_to_decay.append(Vector2i(fr, fc))

	# 火と毒の侵攻：1ターンごとに隣接マスの1つへ伝播
	hazard_spread_turn_counter += 1
	_process_fire_spread()
	_process_poison_spread()
	poison_spread_done_this_turn = false

	# 🔥 火のターン経過寿命減少＆燃え尽き時の駒消去＆飛び火進化
	var fire_burnout_cleared: Array[Vector2i] = []
	for pos in fires_to_decay:
		var fr = pos.x
		var fc = pos.y
		if grid_fire.size() == GRID_ROWS and grid_fire[fr][fc] > 0:
			grid_fire[fr][fc] -= 1
			if grid_fire[fr][fc] <= 0:
				grid_fire[fr][fc] = 0
				var was_ally = is_ally_fire(fr, fc)
				_set_ally_flag(grid_fire_ally, fr, fc, false)
				# 消えるときは、そこにある駒も同時に消す
				if grid_i.size() == GRID_ROWS and grid_i[fr][fc] != -1:
					fire_burnout_cleared.append(Vector2i(fr, fc))
					_spawn_floating_text(get_cell_position(fr, fc), "灰燼（駒消去）", Color(0.3, 0.9, 1.0) if was_ally else Color(1.0, 0.45, 0.1))
				else:
					_spawn_floating_text(get_cell_position(fr, fc), "鎮火", Color(0.6, 0.6, 0.6))
				
				# 飛び火(燃え尽きるときに、周囲48マスのランダムなマスを燃やす)
				if has_actor_skill_trait(was_ally, "fire", "fire_mid_a"):
					var tobibi_cleared = _trigger_tobibi(fr, fc, was_ally)
					for tc in tobibi_cleared:
						if not (tc in fire_burnout_cleared):
							fire_burnout_cleared.append(tc)

	if fire_burnout_cleared.size() > 0:
		_clear_pieces_in_cells(fire_burnout_cleared)
		_start_continuous_falling()
	player_skill_energy = minf(player_skill_max_energy, player_skill_energy + 25.0)
	_update_player_skill_ui()
	_redraw_board_effects()
	var rm = _get_relic_manager()
	if rm: rm.on_turn_start()

func _trigger_gameover(sm: Node2D) -> void:
	if isgameover: return
	isgameover = true
	interval = 0
	current_state = BoardState.TURN_SEQUENCE
	is_enemy_turn_in_progress = false
	if selected_cell.x != -1:
		_deselect_piece()
	is_holding = false
	if _enemy_turn_tween and _enemy_turn_tween.is_valid():
		_enemy_turn_tween.kill()
		_enemy_turn_tween = null
	# PvPではオフラインのゲームオーバー画面を出さない（match_end と勝敗演出で表示する）
	if pvp_mode:
		return
	# 放置デモ再生中は、ゲームオーバーでタイトルへ戻す
	var sm_set = _get_settings_manager()
	if sm_set != null and "demo_mode" in sm_set and bool(sm_set.demo_mode):
		sm_set.demo_mode = false
		var tree = get_tree()
		if tree:
			tree.change_scene_to_file("res://title_screen.tscn")
		return
	if sm:
		var go_node = sm.get_node_or_null("gameover")
		if go_node:
			go_node.visible = true
			go_node.offset_left = 0
			go_node.offset_top = 0
			go_node.offset_right = 1920
			go_node.offset_bottom = 1080
			go_node.position = Vector2.ZERO

## ゲームオーバー演出
func _handle_gameover_sequence(sm: Node2D) -> void:
	if interval == 0:
		var rm = _get_relic_manager()
		if rm: rm.reset_run()
		if sm:
			var f_bgm = sm.get_node_or_null("feverbgm")
			var fl_bgm = sm.get_node_or_null("fieldbgm")
			if f_bgm: f_bgm.stop()
			if fl_bgm: fl_bgm.stop()
		var p = get_parent()
		var haiboku_se = p.get_node_or_null("haiboku") if p else null
		if haiboku_se: haiboku_se.play()

		if sm:
			var go_node = sm.get_node_or_null("gameover")
			if go_node:
				go_node.visible = true
				go_node.offset_left = 0
				go_node.offset_top = 0
				go_node.offset_right = 1920
				go_node.offset_bottom = 1080
				go_node.position = Vector2.ZERO
			var go_lbl = sm.get_node_or_null("GameOver")
			if go_lbl:
				go_lbl.visible = true
				go_lbl.offset_left = 0
				go_lbl.offset_right = 1920
				go_lbl.offset_top = 0
				go_lbl.offset_bottom = 350
				go_lbl.position = Vector2(0, -350)
				go_lbl.bbcode_enabled = true
				var custom_font = preload("res://font/g_comickoin_freeR.ttf")
				go_lbl.add_theme_font_override("normal_font", custom_font)
				go_lbl.add_theme_font_override("bold_font", custom_font)
				go_lbl.add_theme_font_size_override("normal_font_size", 140)
				go_lbl.add_theme_font_size_override("bold_font_size", 140)
				go_lbl.add_theme_constant_override("outline_size", 16)
				go_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
				go_lbl.text = "[center][b][color=#FF1744]GAME OVER[/color][/b][/center]"
			
			var cause_panel = sm.get_node_or_null("GameOverCausePanel")
			if cause_panel == null:
				cause_panel = PanelContainer.new()
				cause_panel.name = "GameOverCausePanel"
				var cp_style = StyleBoxFlat.new()
				cp_style.bg_color = Color(0.01, 0.01, 0.02, 0.70)
				cp_style.border_color = Color(0.85, 0.22, 0.28, 0.95)
				cp_style.set_border_width_all(2)
				cp_style.set_corner_radius_all(14)
				cp_style.content_margin_left = 20
				cp_style.content_margin_right = 20
				cp_style.content_margin_top = 12
				cp_style.content_margin_bottom = 12
				cp_style.shadow_color = Color(0, 0, 0, 0.6)
				cp_style.shadow_size = 12
				cause_panel.add_theme_stylebox_override("panel", cp_style)
				cause_panel.size = Vector2(860, 130)
				cause_panel.position = Vector2(530, 450)
				cause_panel.z_index = 20
				sm.add_child(cause_panel)

				var cause_lbl = RichTextLabel.new()
				cause_lbl.name = "CauseLabel"
				cause_lbl.bbcode_enabled = true
				cause_lbl.scroll_active = false
				cause_lbl.fit_content = true
				cause_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				var custom_font = preload("res://font/g_comickoin_freeR.ttf")
				if custom_font:
					cause_lbl.add_theme_font_override("normal_font", custom_font)
					cause_lbl.add_theme_font_override("bold_font", custom_font)
				cause_panel.add_child(cause_lbl)

			var cause_text = sm.last_damage_cause if ("last_damage_cause" in sm and sm.last_damage_cause != "") else "力尽きた"
			var dmg_val = int(sm.last_damage_amount) if ("last_damage_amount" in sm) else 0
			var cause_lbl_node = cause_panel.get_node_or_null("CauseLabel")
			if cause_lbl_node:
				cause_lbl_node.text = "[center][b][color=#FF5252][font_size=20]☠ 死因 (CAUSE OF DEATH) ☠[/font_size][/color][/b]\n[color=#FFFFFF][font_size=24]%s[/font_size][/color]\n[color=#B0BEC5][font_size=16]Stage %d - 致命傷ダメージ: [color=#FF8A80]%d HP[/color][/font_size][/color][/center]" % [cause_text, sm.stage, dmg_val]
			cause_panel.visible = false

		if p:
			var ret_btn = p.get_node_or_null("returntitle")
			if ret_btn:
				ret_btn.visible = false
				ret_btn.z_index = 15

	elif interval < 50:
		if sm:
			var go_lbl = sm.get_node_or_null("GameOver")
			if go_lbl:
				var t = clampf(float(interval) / 45.0, 0.0, 1.0)
				var ease_t = 1.0 - pow(1.0 - t, 3.0)
				go_lbl.position.y = lerpf(-350.0, 260.0, ease_t)

	elif interval >= 50:
		if sm:
			var go_lbl = sm.get_node_or_null("GameOver")
			if go_lbl:
				go_lbl.position.y = 260.0
			var cause_panel = sm.get_node_or_null("GameOverCausePanel")
			if cause_panel:
				cause_panel.visible = true
		var p = get_parent()
		var ret_btn = p.get_node_or_null("returntitle") if p else null
		if ret_btn:
			ret_btn.visible = true
			ret_btn.size = Vector2(440, 84)
			ret_btn.position = Vector2(740, 640)
			ret_btn.add_theme_font_size_override("font_size", 42)
			ret_btn.z_index = 25
	interval += 1


const SKILL_EFFECT_STAGGER = 0.15

var _attack_phase_elem_played: Dictionary = {}

func _play_ally_attack_phase_effects(sm: Node2D) -> void:
	if not is_instance_valid(sm):
		turn_skill_log.clear()
		return
	var active_en = sm.active_enemies if "active_enemies" in sm else []
	if active_en.is_empty():
		turn_skill_log.clear()
		return
	
	var score_mgr = _get_score_manager()
	var counts: Dictionary = (score_mgr.turn_element_counts.duplicate() if score_mgr and "turn_element_counts" in score_mgr else {})
	
	var elements_present = false
	for el_enum in counts.keys():
		if int(counts[el_enum]) > 0:
			elements_present = true
			break
			
	if not elements_present:
		turn_skill_log.clear()
		return
	
	# 各攻撃フェーズにつき各属性1度だけ再生するためのガード
	_attack_phase_elem_played.clear()
	
	await get_tree().create_timer(0.45, false).timeout
	if not is_instance_valid(sm) or sm.isdeadf:
		turn_skill_log.clear()
		return
	
	for el_enum in counts.keys():
		if not is_instance_valid(sm) or sm.isdeadf:
			break
		var count: int = int(counts[el_enum])
		if count <= 0:
			continue
		if _attack_phase_elem_played.get(el_enum, false):
			continue
		_attack_phase_elem_played[el_enum] = true
		var el_name = ElementDataScript.get_element_name(el_enum)
		var cur_enemies = sm.active_enemies if "active_enemies" in sm else []
		if cur_enemies.is_empty():
			break
		_spawn_elemental_bombs(el_name, count, cur_enemies)
		await get_tree().create_timer(SKILL_EFFECT_STAGGER, false).timeout
		
	turn_skill_log.clear()

## 属性値(count)の大きさに応じた強度段階(1〜5)を算出し、各属性1回だけエフェクトを発生させる
func _get_elemental_effect_intensity(count: int) -> int:
	if count >= 150:
		return 5
	elif count >= 80:
		return 4
	elif count >= 30:
		return 3
	elif count >= 10:
		return 2
	return 1

func _spawn_elemental_bombs(elem: String, count: int, active_en: Array) -> void:
	var intensity: int = _get_elemental_effect_intensity(count)
	var sm = _get_stage_manager()
	var target_e: Dictionary = {}
	if sm and sm.has_method("get_focused_enemy"):
		target_e = sm.get_focused_enemy()
	if target_e.is_empty() and active_en.size() > 0:
		target_e = active_en[0]

	if not target_e.is_empty():
		var spr = target_e.get("sprite")
		if is_instance_valid(spr):
			_play_elemental_size(elem, intensity, spr.global_position, count)

func _play_elemental_size(elem: String, size: int, target_global_pos: Vector2, raw_count: int = 1) -> void:
	var local_pos = self.to_local(target_global_pos)
	var power_ratio: float = clampf(float(raw_count) / 200.0, 0.0, 2.0)
	
	match elem:
		"fire":
			if size >= 5:
				_spawn_mega_explosion_effect(local_pos, 5)
				_spawn_shockwave_ring(local_pos, Color(1.0, 0.35, 0.05, 0.95), 1100.0 + power_ratio * 250.0, 0.45)
				_spawn_shockwave_ring(local_pos, Color(1.0, 0.9, 0.3, 0.9), 800.0 + power_ratio * 150.0, 0.35)
			elif size == 4:
				_spawn_mega_explosion_effect(local_pos, 3)
				_spawn_shockwave_ring(local_pos, Color(1.0, 0.45, 0.1, 0.92), 850.0, 0.40)
			elif size == 3:
				_spawn_mega_explosion_effect(local_pos, 2)
			elif size == 2:
				_spawn_mega_explosion_effect(local_pos, 0)
			else:
				_spawn_explosion_effect(local_pos)
		"water":
			if size >= 5:
				_spawn_aqua_splash_effect(local_pos, 8)
				_spawn_shockwave_ring(local_pos, Color(0.1, 0.85, 1.0, 0.95), 1050.0, 0.45)
			elif size == 4:
				_spawn_aqua_splash_effect(local_pos, 6)
				_spawn_shockwave_ring(local_pos, Color(0.2, 0.8, 1.0, 0.9), 800.0, 0.38)
			elif size == 3:
				_spawn_aqua_splash_effect(local_pos, 5)
			elif size == 2:
				_spawn_aqua_splash_effect(local_pos, 3)
			else:
				_spawn_aqua_splash_effect(local_pos, 1)
		"wind":
			_spawn_enemy_tornado_effect(local_pos, size)
			if size >= 4:
				_spawn_shockwave_ring(local_pos, Color(0.2, 1.0, 0.7, 0.9), 450.0 + float(size) * 80.0, 0.35)
			elif size >= 2:
				_spawn_shockwave_ring(local_pos, Color(0.2, 1.0, 0.7, 0.8), 300.0 + float(size) * 60.0, 0.28)
		"thunder":
			if size >= 5:
				for dx in [-320, -200, -100, 0, 100, 200, 320]:
					_spawn_vertical_lightning_bolt(local_pos + Vector2(dx, 0), randf() * 0.12)
				_spawn_shockwave_ring(local_pos, Color(1.0, 0.95, 0.2, 0.95), 1050.0, 0.42)
				_spawn_screen_flash(Color(1.0, 1.0, 0.4, 0.6), 0.16)
			elif size == 4:
				for dx in [-240, -120, 0, 120, 240]:
					_spawn_vertical_lightning_bolt(local_pos + Vector2(dx, 0), randf() * 0.12)
				_spawn_shockwave_ring(local_pos, Color(1.0, 0.95, 0.2, 0.9), 800.0, 0.36)
				_spawn_screen_flash(Color(1.0, 1.0, 0.4, 0.5), 0.12)
			elif size == 3:
				for dx in [-200, -100, 0, 100, 200]:
					_spawn_vertical_lightning_bolt(local_pos + Vector2(dx, 0), randf() * 0.12)
				_spawn_screen_flash(Color(1.0, 1.0, 0.4, 0.45), 0.1)
			elif size == 2:
				for dx in [-100, 0, 100]:
					_spawn_vertical_lightning_bolt(local_pos + Vector2(dx, 0), randf() * 0.08)
			else:
				_spawn_vertical_lightning_bolt(local_pos, 0.0)
		"light":
			if size >= 5:
				_spawn_disco_effect(local_pos)
				_spawn_shockwave_ring(local_pos, Color(1.0, 0.95, 0.5, 0.95), 1150.0, 0.45)
			elif size == 4:
				_spawn_disco_effect(local_pos)
				_spawn_shockwave_ring(local_pos, Color(1.0, 0.95, 0.5, 0.9), 850.0, 0.38)
			elif size == 3:
				_spawn_disco_effect(local_pos)
			elif size == 2:
				_spawn_shockwave_ring(local_pos, Color(1.0, 1.0, 0.5, 0.9), 600.0, 0.4)
			else:
				_spawn_shockwave_ring(local_pos, Color(1.0, 1.0, 0.5, 0.9), 300.0, 0.2)
		"dark":
			if size >= 5:
				_spawn_black_hole_effect(local_pos, 4)
				_spawn_shockwave_ring(local_pos, Color(0.65, 0.15, 1.0, 0.95), 1100.0, 0.45)
			elif size == 4:
				_spawn_black_hole_effect(local_pos, 3)
				_spawn_shockwave_ring(local_pos, Color(0.65, 0.15, 1.0, 0.9), 850.0, 0.38)
			elif size == 3:
				_spawn_black_hole_effect(local_pos, 3)
			elif size == 2:
				_spawn_black_hole_effect(local_pos, 2)
			else:
				_spawn_black_hole_effect(local_pos, 1)
		"poison":
			if size >= 5:
				_spawn_curse_burst_effect(local_pos)
				_spawn_poison_bubble_burst_effect(local_pos)
				_spawn_shockwave_ring(local_pos, Color(0.75, 0.15, 0.95, 0.95), 1100.0, 0.45)
			elif size >= 3:
				_spawn_poison_bubble_burst_effect(local_pos)
				_spawn_shockwave_ring(local_pos, Color(0.75, 0.15, 0.95, 0.9), 800.0, 0.38)
			else:
				_spawn_poison_bubble_burst_effect(local_pos)


func _add_element_mark_to_sprite(sprite: Sprite2D) -> void:
	if sprite.has_node("ElementMark"): return
	var mark = Polygon2D.new()
	mark.name = "ElementMark"
	var pts = PackedVector2Array()
	for p_i in range(16):
		var ang = p_i * TAU / 16.0
		pts.append(Vector2(cos(ang), sin(ang)) * 25.0)
	mark.polygon = pts
	mark.position = Vector2(20, -20)
	mark.visible = false
	mark.material = CanvasItemMaterial.new()
	mark.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.add_child(mark)

func _update_piece_element_mark(p_idx: int, el: int) -> void:
	if p_idx < 0 or p_idx >= piece.size(): return
	var sp = piece[p_idx]
	if not is_instance_valid(sp): return
	var mark = sp.get_node_or_null("ElementMark")
	if is_instance_valid(mark):
		if el == ElementDataScript.Element.NONE:
			mark.visible = false
		else:
			mark.visible = true
			mark.color = ElementDataScript.ELEMENT_COLORS.get(el, Color.WHITE)


const DEBUG_ELEMENT = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10 or event.keycode == KEY_K:
			var sm = _get_stage_manager()
			if sm and sm.has_method("debug_kill_enemy"):
				sm.debug_kill_enemy()
				var vp = get_viewport()
				if vp: vp.set_input_as_handled()
				return
	if not DEBUG_ELEMENT: return
	if event is InputEventKey and event.pressed and not event.echo:
		var el = ElementDataScript.Element.NONE
		match event.keycode:
			KEY_1: el = ElementDataScript.Element.FIRE
			KEY_2: el = ElementDataScript.Element.WATER
			KEY_3: el = ElementDataScript.Element.WIND
			KEY_4: el = ElementDataScript.Element.THUNDER
			KEY_5: el = ElementDataScript.Element.LIGHT
			KEY_6: el = ElementDataScript.Element.DARK
			KEY_7: el = ElementDataScript.Element.POISON
			
		if el != ElementDataScript.Element.NONE:
			_debug_apply_element_random(el)

func _debug_apply_element_random(el: int) -> void:
	if grid_element.size() != GRID_ROWS: return
	var candidates = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var kind = grid_n[r][c]
			if (kind == PieceType.SWORD or kind == PieceType.SHIELD) and grid_element[r][c] == ElementDataScript.Element.NONE:
				candidates.append(Vector2i(r, c))
				
	candidates.shuffle()
	var applied_count = 0
	for cell in candidates:
		if applied_count >= 10: break
		grid_element[cell.x][cell.y] = el
		_update_piece_element_mark(grid_i[cell.x][cell.y], el)
		applied_count += 1
	print("[DEBUG] Applied element ", ElementDataScript.get_element_name(el), " to ", applied_count, " pieces.")

var _cached_relic_manager: Node = null
func _get_relic_manager() -> Node:
	if _cached_relic_manager and is_instance_valid(_cached_relic_manager):
		return _cached_relic_manager
	var p = get_parent()
	if p:
		var rm = p.get_node_or_null("RelicManager")
		if rm:
			_cached_relic_manager = rm
			return _cached_relic_manager
	var tree = get_tree()
	if tree and tree.get_root():
		_cached_relic_manager = tree.get_root().find_child("RelicManager", true, false)
		return _cached_relic_manager
	return null

var _cached_relic_ui_manager: Node = null
func _get_relic_ui_manager() -> Node:
	if _cached_relic_ui_manager and is_instance_valid(_cached_relic_ui_manager):
		return _cached_relic_ui_manager
	var p = get_parent()
	if p:
		var r_ui = p.get_node_or_null("RelicUIManager")
		if r_ui:
			_cached_relic_ui_manager = r_ui
			return _cached_relic_ui_manager
	var tree = get_tree()
	if tree and tree.get_root():
		_cached_relic_ui_manager = tree.get_root().find_child("RelicUIManager", true, false)
		return _cached_relic_ui_manager
	return null

func _hide_cell_hover_tooltip() -> void:
	_last_hovered_cell = Vector2i(-1, -1)
	var rm_ui = _get_relic_ui_manager()
	if rm_ui and rm_ui.has_method("hide_custom_tooltip"):
		rm_ui.hide_custom_tooltip("board_cell")
	if rm_ui and rm_ui.has_method("hide_cell_effect_tooltips"):
		rm_ui.hide_cell_effect_tooltips()

## マウスホバー中の効果マス（特殊アイテム、盤面ギミック、属性コマ）の説明ツールチップ更新
func _add_cell_effect_entry(entries: Array, title: String, desc: String, color: String = "#FFD54F") -> void:
	entries.append({"title": title, "desc": desc, "color": color})

# 【コマ・オブジェクト】と【マスに付与されている効果】を分けるための境界インデックス
var _cell_object_split: int = -1

## マスの説明を「効果」「コマ・オブジェクト」の2つの枠に分けて組み立てる
func _build_cell_tooltip_rich_text(entries: Array[Dictionary], split: int) -> String:
	var splt: int = split if (split >= 0 and split <= entries.size()) else entries.size()
	var effect_parts: Array[String] = []
	var object_parts: Array[String] = []
	for i in range(entries.size()):
		var e = entries[i]
		var seg: String = "[b]%s[/b]\n%s" % [str(e.get("title", "")), str(e.get("desc", ""))]
		if i < splt:
			object_parts.append(seg)
		else:
			effect_parts.append(seg)
	var out: String = ""
	# 上段：マスに付与されている効果
	out += "[table=1]"
	out += "[cell][bgcolor=#10222E][color=#7FDBFF][b]🎯 マスに付与されている効果[/b][/color][/bgcolor][/cell]"
	if effect_parts.is_empty():
		out += "[cell][bgcolor=#0B1620][color=#8FA3B0]（このマスに付与されている効果はありません）[/color][/bgcolor][/cell]"
	else:
		for seg in effect_parts:
			out += "[cell][bgcolor=#0B1620]%s[/bgcolor][/cell]" % seg
	out += "[/table]"
	out += "\n"
	# 下段：コマ・オブジェクトの説明
	out += "[table=1]"
	out += "[cell][bgcolor=#2E2410][color=#FFD54F][b]📦 コマ・オブジェクト[/b][/color][/bgcolor][/cell]"
	if object_parts.is_empty():
		out += "[cell][bgcolor=#1A1408][color=#B0A080]（このマスにはコマ・オブジェクトがありません）[/color][/bgcolor][/cell]"
	else:
		for seg in object_parts:
			out += "[cell][bgcolor=#1A1408]%s[/bgcolor][/cell]" % seg
	out += "[/table]"
	return out

## そのマスに重なっている効果をすべて収集する（特殊駒・地形・属性・霧など）
func _collect_cell_effect_entries(r: int, c: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	# 1. 特殊アイテムコマ (special_item)
	var sp = special_item[r][c] if (special_item.size() == GRID_ROWS and special_item[r].size() == GRID_COLUMNS) else SpecialItemType.NONE
	var is_b = is_bomb[r][c] if (is_bomb.size() == GRID_ROWS and is_bomb[r].size() == GRID_COLUMNS) else false
	if sp == SpecialItemType.NONE and is_b:
		sp = SpecialItemType.BOMB
	var sp_lvl = max(1, special_levels.get(sp, 1))
	match sp:
		SpecialItemType.BOMB:
			var blast_cnt = mini(3 + int((sp_lvl - 1) / 2), GRID_ROWS * GRID_COLUMNS)
			var blast_dmg = int(80.0 + sp_lvl * 20.0)
			_add_cell_effect_entry(entries, "[b][color=#FF3D00]🔥 ブレイズブラスト (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]盤面に味方の火マス（[color=#FFD700]%dマス[/color]）を展開して駒を焼き払い、\n敵に火属性ダメージ（威力 %d）を与えます。[/font_size]" % [blast_cnt, blast_dmg], "#FF3D00")
		SpecialItemType.CROSS_BOMB:
			var width_str = "縦横1列" if sp_lvl == 1 else ("縦横3列" if sp_lvl < 6 else "全画面十字貫通")
			_add_cell_effect_entry(entries, "[b][color=#FF3D00]⚔️ クロスブレイズ (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]起爆すると[color=#FFD700]%s[/color]を貫通する極太火柱で一掃消滅させます！（石貫通 %d）[/font_size]" % [width_str, 1 + int((sp_lvl - 1) / 4)], "#FF3D00")
		SpecialItemType.DISCO_BALL:
			_add_cell_effect_entry(entries, "[b][color=#E040FB]✨ スターオーブ (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]聖なる輝きで神聖な[color=#FFD700]聖像（味方の黄金像）[/color]を盤面に降臨！\n敵ハザードを一掃浄化し、敵へ聖光ダメージ（威力 %d）を与えます。[/font_size]" % (70 + sp_lvl * 15), "#E040FB")
		SpecialItemType.COLOR_CONVERTER:
			var span_str = "周囲8マス" if sp_lvl < 3 else ("周囲5×5マス" if sp_lvl < 8 else ("周囲7×7マス" if sp_lvl < 14 else "盤面全域"))
			_add_cell_effect_entry(entries, "[b][color=#69F0AE]🎨 フローラスプレー (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19][color=#FFD700]%s[/color]をすべて同一の属性コマに染め上げ、確実な巨大連鎖を生成します。[/font_size]" % span_str, "#69F0AE")
		SpecialItemType.LIGHTNING:
			var strikes = mini(GRID_ROWS * GRID_COLUMNS, 3 + int(sp_lvl * 1.1))
			_add_cell_effect_entry(entries, "[b][color=#FFEA00]⚡ ライトニング (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]盤面に[color=#FFD700]%d発[/color]の落雷追撃！（石貫通 %d）\n水たまりマスに触れると周囲へ感電連鎖します。[/font_size]" % [strikes, 2 + int((sp_lvl - 1) / 3)], "#FFEA00")
		SpecialItemType.BLACK_HOLE:
			var hole_str = "5×5マス" if sp_lvl < 2 else ("7×7マス" if sp_lvl < 7 else ("9×9マス" if sp_lvl < 13 else "超巨大重力渦"))
			_add_cell_effect_entry(entries, "[b][color=#7C4DFF]🌀 ブラックホール (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]超強力な重力渦を展開し、周囲[color=#FFD700]%s[/color]のコマを吸引・消滅させます。（石貫通 %d）[/font_size]" % [hole_str, 1 + int((sp_lvl - 1) / 3)], "#7C4DFF")
		SpecialItemType.TORNADO:
			var w_str = "1列" if sp_lvl < 2 else ("3列" if sp_lvl < 7 else "幅5マスの超巨大竜巻")
			_add_cell_effect_entry(entries, "[b][color=#00E676]🌪️ つむじ風・竜巻 (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]直線状の床効果・ハザードを一掃する竜巻で[color=#FFD700]%s[/color]を巻き上げ！（石貫通 %d）\n（進化【突風】で通常駒も巻き込み消去）[/font_size]" % [w_str, 1 + int((sp_lvl - 1) / 4)], "#00E676")
		SpecialItemType.AQUA_SPLASH:
			var aqua_rad = "半径1の円状範囲" if sp_lvl < 3 else ("半径2の円状範囲" if sp_lvl < 8 else "広域円状範囲")
			_add_cell_effect_entry(entries, "[b][color=#00B0FF]💧 アクアスプラッシュ (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]中心から[color=#FFD700]%s[/color]に水しぶきを拡散し水たまりを展開！\n落雷の感電や、苗木の成長を促進します。[/font_size]" % aqua_rad, "#00B0FF")
		SpecialItemType.TREE_SPROUT:
			var th_def = 1 + int((sp_lvl - 1) / 3)
			_add_cell_effect_entry(entries, "[b][color=#76FF03]🌱 生命の苗木 (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]盤面に根を張り、水を吸うことで大木へ進化！（耐雷耐久 %d）\n毎ターンプレイヤーのHPを自動回復します。[/font_size]" % th_def, "#76FF03")
		SpecialItemType.HOLY_LIGHT:
			_add_cell_effect_entry(entries, "[b][color=#FFEE58]✨ 聖光星 (ホーリースター) (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]神聖な[color=#FFD700]聖像（味方の黄金像）[/color]を盤面に降臨！\n毒・火・呪いなどの敵妨害マスを一掃浄化し、敵へ聖光ダメージ（威力 %d）を与えます。[/font_size]" % (70 + sp_lvl * 15), "#FFEE58")
		SpecialItemType.CHARGE_BOMB:
			var chg = special_charge[r][c] if special_charge.size() == GRID_ROWS else 0
			_add_cell_effect_entry(entries, "[b][color=#FFAB00]🔋 チャージボム (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]隣接消去で蓄電（残り[color=#FFD700]%d回[/color]）。\n蓄電完了で超広域大爆発を起こします！（石貫通 %d）[/font_size]" % [chg, chg + int((sp_lvl - 1) / 3)], "#FFAB00")
		SpecialItemType.GEMINI_BOMB:
			var split_cnt = mini(8, 2 + int(sp_lvl / 3))
			_add_cell_effect_entry(entries, "[b][color=#FF1744]💥 ジェミニボム (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]双子の爆弾が互いに共鳴爆破（計[color=#FFD700]%d箇所[/color]）！\n直線上の全コマを貫通レーザーで消滅させます。（石貫通 %d）[/font_size]" % [split_cnt, 1 + int((sp_lvl - 1) / 4)], "#FF1744")
		SpecialItemType.ICE_SHIELD:
			_add_cell_effect_entry(entries, "[b][color=#80D8FF]❄️ 氷盾・フリージング (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]起爆すると自軍氷結マスを展開＆シールド付与！\n氷マスは隣接する効果マスの進行を完全停止させ、炎隣接で融解消滅します。[/font_size]", "#80D8FF")
		SpecialItemType.POISON_MIST:
			_add_cell_effect_entry(entries, "[b][color=#00E676]🧪 免疫薬毒・ポイズン (Lv%d/20)[/color][/b]" % sp_lvl,
				"[font_size=19]起爆すると盤面のランダムな複数マスを薬毒マスに変え、その上の駒を消去！\n味方毒1マスにつき敵毒ダメージを20%軽減（最大90%免疫）し、敵に毒ダメージを与えます。[/font_size]", "#00E676")

	# 【境界】ここより上が「コマ・オブジェクト」、下が「マスに付与されている効果」
	_cell_object_split = entries.size()

	# 2. 盤面ギミックマス
	var plant = _get_plant_at(r, c)
	if not plant.is_empty():
		var p_stage = int(plant.get("stage", 0))
		if p_stage == 2:
			_add_cell_effect_entry(entries, "[b][color=#00E676]🌳 世界樹・生命の大木 (3×3)[/color][/b]",
				"[font_size=19]毎ターン大量のHPを自動回復！雷耐性あり。\n※炎上マスが接触すると大炎上するため注意。[/font_size]", "#00E676")
		elif p_stage == 1:
			_add_cell_effect_entry(entries, "[b][color=#76FF03]🌿 生命の若木[/color][/b]",
				"[font_size=19]毎ターンHPを回復。水たまりを吸うと3×3の大木へ進化します。[/font_size]", "#76FF03")
		else:
			_add_cell_effect_entry(entries, "[b][color=#AEEA00]🌱 生命の苗木[/color][/b]",
				"[font_size=19]毎ターンHPを回復。隣接する水たまりを吸って若木へ進化します。[/font_size]", "#AEEA00")

	if grid_gold_statue.size() == GRID_ROWS and int(grid_gold_statue[r][c]) > 0:
		var g_hp = int(grid_gold_statue[r][c])
		if is_ally_gold(r, c):
			_add_cell_effect_entry(entries, "[b][color=#FFF59D]✨ 聖像 (自・残り耐久: %d)[/color][/b]" % g_hp,
				"[font_size=19][color=#69F0AE]【自分による効果・移動可能】[/color]\n自由にスワップ移動でき、マッチすると大量のゴールドコインを獲得します！[/font_size]", "#FFF59D")
		else:
			_add_cell_effect_entry(entries, "[b][color=#FFD700]🏆 黄金像ブロック (敵・残り耐久: %d)[/color][/b]" % g_hp,
				"[font_size=19][color=#FF5252]【独立お邪魔ブロック】[/color]\n動かせない強固な障害物ブロック。隣接マスでマッチさせて粉砕すると+500G獲得！破壊後は空マスとなり上から新たな駒が落下します。[/font_size]", "#FFD700")

	if grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) > 0:
		var i_hp = int(grid_ice[r][c])
		if is_ally_ice(r, c):
			_add_cell_effect_entry(entries, "[b][color=#80DEEA]❄️ 氷盾マス (自・残り耐久: %d)[/color][/b]" % i_hp,
				"[font_size=19][color=#69F0AE]【自分による効果・移動可能】[/color]\n隣接する敵効果マスの進行・拡散を停止。凍りつかず自由に動かせます。マッチまたは雷属性攻撃（氷×雷シナジー）で周囲3×3を砕き敵に氷追撃！[/font_size]", "#80DEEA")
		else:
			_add_cell_effect_entry(entries, "[b][color=#00E5FF]❄️ 氷結マス (敵・残り耐久: %d)[/color][/b]" % i_hp,
				"[font_size=19][color=#FF5252]【敵による妨害】[/color] 隣接する効果マスの進行・拡散を停止。凍りついて動かせません。\n隣接マッチや炎で解凍、または雷で周囲3×3ごと粉砕（氷×雷シナジー）できます。[/font_size]", "#00E5FF")

	if grid_stones.size() == GRID_ROWS and int(grid_stones[r][c]) > 0:
		var s_hp = int(grid_stones[r][c])
		if is_ally_stone(r, c):
			_add_cell_effect_entry(entries, "[b][color=#69F0AE]💎 輝石マス (自・残り耐久: %d)[/color][/b]" % s_hp,
				"[font_size=19][color=#69F0AE]【自分による効果・移動可能】[/color]\n自由に動かせます。マッチで大地追撃、雷が当たると周囲3×3を破片で一掃（石×雷シナジー）します！[/font_size]", "#69F0AE")
		else:
			_add_cell_effect_entry(entries, "[b][color=#B0BEC5]🪨 障害物の岩石 (敵・残り耐久: %d)[/color][/b]" % s_hp,
				"[font_size=19][color=#FF5252]【敵による妨害】[/color] 動かせない障害物。\n隣接マッチで粉砕、または雷が当たると破片が飛び散り周囲3×3を消去（石×雷シナジー）します。[/font_size]", "#B0BEC5")

	if grid_water.size() == GRID_ROWS and grid_water[r][c]:
		if is_ally_water(r, c):
			_add_cell_effect_entry(entries, "[b][color=#40C4FF]💧 清流マス (自)[/color][/b]",
				"[font_size=19][color=#69F0AE]【自分による効果・移動可能】[/color]\n自由にスワップ可能！炎マスと隣接すると【水×火シナジー】で共通隣接マスを一掃消去します。雷感電・苗木成長にも有効。[/font_size]", "#40C4FF")
		else:
			_add_cell_effect_entry(entries, "[b][color=#00B0FF]💧 水没マス (敵)[/color][/b]",
				"[font_size=19][color=#FF5252]【敵による妨害】[/color] 水没して直接動かせません。\n炎マスと隣接すると【水×火シナジー】で共通隣接マスを消去して蒸発します！雷感電・苗木成長にも有効。[/font_size]", "#00B0FF")

	if grid_fire.size() == GRID_ROWS and int(grid_fire[r][c]) > 0:
		if is_ally_fire(r, c):
			_add_cell_effect_entry(entries, "[b][color=#00E5FF]🔥 蒼炎マス (自)[/color][/b]",
				"[font_size=19][color=#69F0AE]【自分による効果・無害】[/color]\nプレイヤーは火傷せず、毎ターン敵に蒼炎ダメージを与えます！水マスと隣接すると【水×火シナジー】で共通隣接マスを消去します。[/font_size]", "#00E5FF")
		else:
			_add_cell_effect_entry(entries, "[b][color=#FF3D00]🔥 炎上マス (敵)[/color][/b]",
				"[font_size=19][color=#FF5252]【敵による妨害】[/color] 毎ターン隣接マスへ延焼し火傷ダメージを受けます。\n水マスと隣接すると【水×火シナジー】で共通隣接マスを消去しつつ消火できます！[/font_size]", "#FF3D00")

	if grid_electrified.size() == GRID_ROWS and grid_electrified[r][c]:
		if is_ally_electrified(r, c):
			_add_cell_effect_entry(entries, "[b][color=#80D8FF]⚡ 充電マス (自)[/color][/b]",
				"[font_size=19][color=#69F0AE]【自分による効果・有利】[/color]\nスワップ移動またはマッチさせると、感電反動を受けずに敵へ放電追撃ダメージを与えます！[/font_size]", "#80D8FF")
		else:
			_add_cell_effect_entry(entries, "[b][color=#FFEA00]⚡ 帯電マス (敵)[/color][/b]",
				"[font_size=19][color=#FF5252]【危険】[/color] このマスをスワップ移動させると、感電バックラッシュダメージを受けます！[/font_size]", "#FFEA00")

	if grid_cursed.size() == GRID_ROWS and grid_cursed[r][c]:
		if is_ally_cursed(r, c):
			_add_cell_effect_entry(entries, "[b][color=#82B1FF]🌙 影護のコマ (自)[/color][/b]",
				"[font_size=19][color=#69F0AE]【自分による効果・有利】[/color]\n反動を受けず、マッチして消去すると敵に闇ダメージを与えつつHPを吸収回復します！[/font_size]", "#82B1FF")
		else:
			_add_cell_effect_entry(entries, "[b][color=#AA00FF]☠️ 呪いのコマ (敵)[/color][/b]",
				"[font_size=19][color=#FF5252]【消去時反動ダメージ】[/color] このコマを直接揃えて消去すると、呪詛反動ダメージを受けます！\n[color=#69F0AE]【安全な浄化方法】[/color] 隣接マスで他のコマを揃えてマッチさせると、反動を受けずに安全に浄化（消去）できます。[/font_size]", "#AA00FF")

	if grid_poison.size() == GRID_ROWS and grid_poison[r][c]:
		var is_wet = (grid_water.size() == GRID_ROWS and grid_water[r][c])
		if is_ally_poison(r, c):
			_add_cell_effect_entry(entries, "[b][color=#64FFDA]🧪 薬毒マス (自%s)[/color][/b]" % ("・水流2倍拡散" if is_wet else ""),
				"[font_size=19][color=#69F0AE]【自分による効果・無害】[/color]\nプレイヤーは毒を受けず、毎ターン伝染しながら敵に薬毒ダメージを与えます！（水マスで2倍速拡散）[/font_size]", "#64FFDA")
		elif is_wet:
			_add_cell_effect_entry(entries, "[b][color=#AB47BC]☠️ 猛毒水たまり (敵・伝染速度2倍！)[/color][/b]",
				"[font_size=19][color=#FF5252]【猛毒・拡散加速】[/color] 水に濡れているため、毎ターン2倍の速さ（2マス先まで）で周囲へ毒が伝染します！\n[color=#69F0AE]【解毒方法】[/color] この毒に侵されたコマをマッチ等で消去すると解毒できます。[/font_size]", "#AB47BC")
		else:
			_add_cell_effect_entry(entries, "[b][color=#AB47BC]☠️ 猛毒沼マス (敵・毎ターン伝染！)[/color][/b]",
				"[font_size=19][color=#FF5252]【毎ターン毒伝染＆毒ダメージ】[/color] 毎ターン隣接マスへ毒が伝染します！水に濡れたマスは2倍速く伝染します。\n[color=#69F0AE]【解毒方法】[/color] この毒に侵されたコマをマッチ等で消去すると解毒できます。[/font_size]", "#AB47BC")

	if grid_element.size() == GRID_ROWS and grid_element[r][c] != ElementDataScript.Element.NONE:
		var el = grid_element[r][c]
		var el_name_jp = ""
		var el_color = "#FFFFFF"
		match el:
			ElementDataScript.Element.FIRE: el_name_jp = "炎属性"; el_color = "#FF5722"
			ElementDataScript.Element.WATER: el_name_jp = "水属性"; el_color = "#03A9F4"
			ElementDataScript.Element.WIND: el_name_jp = "風・地属性"; el_color = "#4CAF50"
			ElementDataScript.Element.THUNDER: el_name_jp = "雷属性"; el_color = "#FFEB3B"
			ElementDataScript.Element.LIGHT: el_name_jp = "光・聖属性"; el_color = "#FFF176"
			ElementDataScript.Element.DARK: el_name_jp = "闇・魔属性"; el_color = "#BA68C8"
			ElementDataScript.Element.POISON: el_name_jp = "毒属性"; el_color = "#AB47BC"
		_add_cell_effect_entry(entries, "[b][color=%s]✦ %sコマ[/color][/b]" % [el_color, el_name_jp],
			"[font_size=19]このコマをマッチすると[color=%s]%s[/color]の魔力が蓄積され、ターン終了時に敵へ属性追撃を浴びせます！[/font_size]" % [el_color, el_name_jp], el_color)

	# 3. 黒い霧 (grid_fog)
	for fog in grid_fog:
		var f_rect: Rect2i = fog.get("rect", Rect2i(-1, -1, 0, 0))
		if f_rect.has_point(Vector2i(r, c)):
			var f_turns = fog.get("turns", 1)
			var is_enemy_fog: bool = fog.get("enemy_owned", true)
			if not is_enemy_fog:
				_add_cell_effect_entry(entries, "[b][color=#80D8FF]🌌 星影の霧 (自・残り%dターン)[/color][/b]" % f_turns,
					"[font_size=19][color=#69F0AE]【自分による効果・無害】[/color]\n毎ターン敵に星影の追撃ダメージを与えます！[/font_size]", "#80D8FF")
			else:
				_add_cell_effect_entry(entries, "[b][color=#BA68C8]🌫️ 瘴気の暗雲 (敵・残り%dターン)[/color][/b]" % f_turns,
					"[font_size=19][color=#FF5252]【危険・毎ターン瘴気ダメージ】[/color]\n暗雲が存在する間、ターン終了時に瘴気持続ダメージを受けます！\n[color=#69F0AE]【解除方法】[/color] このエリア内でコマをマッチさせると霧を晴らすことができます。[/font_size]", "#BA68C8")

	# 4. 通常のコマ説明（他に効果がない場合のみ）
	if entries.is_empty() and grid_n.size() == GRID_ROWS and r < grid_n.size() and c < grid_n[r].size() and grid_i[r][c] != -1:
		match grid_n[r][c]:
			PieceType.SWORD:
				_add_cell_effect_entry(entries, "[b][color=#FF5252]⚔️ 剣のコマ[/color][/b]", "[font_size=19]マッチすると剣を放ち、敵に物理ダメージを与えます。[/font_size]", "#FF5252")
			PieceType.SHIELD:
				_add_cell_effect_entry(entries, "[b][color=#448AFF]🛡️ 盾のコマ[/color][/b]", "[font_size=19]マッチすると盾を展開し、敵からの攻撃やスキルダメージを軽減・防御します。[/font_size]", "#448AFF")
			PieceType.FOOD:
				_add_cell_effect_entry(entries, "[b][color=#69F0AE]🍞 食糧（パン）のコマ[/color][/b]", "[font_size=19]マッチするとプレイヤーのHPを回復します。[/font_size]", "#69F0AE")
			PieceType.POTION:
				_add_cell_effect_entry(entries, "[b][color=#E040FB]🧪 秘薬（ポーション）のコマ[/color][/b]", "[font_size=19]マッチするとスコアを獲得し、フィーバーゲージを溜めます。[/font_size]", "#E040FB")
			PieceType.COIN:
				_add_cell_effect_entry(entries, "[b][color=#FFD700]🪙 コインのコマ[/color][/b]", "[font_size=19]マッチするとゴールドを獲得し、ショップでの強化に役立ちます。[/font_size]", "#FFD700")

	return entries

func _update_cell_hover_tooltip(global_mouse_pos: Vector2) -> void:
	var rm_ui = _get_relic_ui_manager()
	if rm_ui and rm_ui.has_method("is_cell_tooltip_under_mouse") and rm_ui.is_cell_tooltip_under_mouse(global_mouse_pos):
		return
	if is_holding:
		_hide_cell_hover_tooltip()
		return

	var sm = _get_stage_manager()
	if sm and (sm.isstageclear or sm.isdeadf):
		_hide_cell_hover_tooltip()
		return

	var c = int(floor((_current_local_mouse.x - BOARD_LEFT) / CELL_PITCH))
	var r = int(floor((_current_local_mouse.y - BOARD_TOP) / CELL_PITCH))
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS:
		_hide_cell_hover_tooltip()
		return

	var cur_cell = Vector2i(r, c)
	if cur_cell == _last_hovered_cell:
		return
	_last_hovered_cell = cur_cell

	var entries: Array[Dictionary] = _collect_cell_effect_entries(r, c)
	if rm_ui and rm_ui.has_method("show_cell_effect_tooltips"):
		rm_ui.show_cell_effect_tooltips(entries, global_mouse_pos)
	elif not entries.is_empty() and rm_ui and rm_ui.has_method("show_custom_tooltip"):
		# 「マスに付与されている効果」と「コマ・オブジェクト」を上下の枠で区切って表示する
		var rich: String = _build_cell_tooltip_rich_text(entries, _cell_object_split)
		rm_ui.show_custom_tooltip("[b]🔍 マス情報[/b]", rich, global_mouse_pos, "board_cell")
	elif entries.is_empty():
		_hide_cell_hover_tooltip()

## 盤面状態の集計（水たまり数、炎上マス数、大木の有無）
func get_board_state() -> Dictionary:
	var w_cnt = 0
	var f_cnt = 0
	var p_cnt = 0
	var s_cnt = 0
	var i_cnt = 0
	if grid_water.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_water[r][c]:
					w_cnt += 1
	if grid_fire.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_fire[r][c] > 0:
					f_cnt += 1
	if grid_poison.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_poison[r][c]:
					p_cnt += 1
	if grid_stones.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if grid_stones[r][c] > 0:
					s_cnt += 1
	if grid_ice.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				if int(grid_ice[r][c]) > 0:
					i_cnt += 1
	var big_tree = false
	for plant in plant_entities:
		if plant.get("stage", 0) >= 2:
			big_tree = true
			break
	return {
		"water_count": w_cnt,
		"fire_count": f_cnt,
		"poison_count": p_cnt,
		"stone_count": s_cnt,
		"ice_count": i_cnt,
		"has_big_tree": big_tree
	}

## 凍土の誓約レリック：ターン開始時に味方氷マスを生成
func spawn_ally_ice_for_relic() -> bool:
	if grid_i.size() != GRID_ROWS:
		return false
	_ensure_ally_grids()
	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) == 0:
					cands.append(Vector2i(r, c))
	if cands.is_empty():
		return false
	var chosen = cands[randi() % cands.size()]
	grid_ice[chosen.x][chosen.y] = 2
	_set_ally_flag(grid_ice_ally, chosen.x, chosen.y, true)
	_play_ice_freeze_expansion([chosen], get_cell_position(chosen.x, chosen.y), true)
	_spawn_floating_text(get_cell_position(chosen.x, chosen.y), "❄️ 凍土の誓約", Color(0.4, 0.9, 1.0))
	return true

## 指定マスがスワップ移動不可（障害物や固定マス）かどうかを判定
func _is_cell_blocked_for_swap(r: int, c: int) -> bool:
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLUMNS:
		return true
	if _is_plant_cell(r, c):
		return true
	if grid_water.size() == GRID_ROWS and grid_water[r][c] and not is_ally_water(r, c):
		return true
	if grid_ice.size() == GRID_ROWS and grid_ice[r][c] and not is_ally_ice(r, c):
		return true
	if grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0 and not is_ally_stone(r, c):
		return true
	if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0 and not is_ally_gold(r, c):
		return true
	return false

## 現在のマウス座標に基づいて移動先（スワップ対象）となる隣接マスを判定・更新
func _update_hovered_swap_direction(local_mouse: Vector2) -> void:
	if selected_cell.x == -1 or current_state != BoardState.IDLE:
		if hovered_swap_cell.x != -1:
			hovered_swap_cell = Vector2i(-1, -1)
			if swap_guide_overlay: swap_guide_overlay.queue_redraw()
		return

	var sel_pos = get_cell_position(selected_cell.x, selected_cell.y)
	var diff = local_mouse - sel_pos
	var target_cell = Vector2i(-1, -1)

	# 1. マウスが直接乗っているマスをチェック（マンハッタン距離1の隣接マス）
	var m_col = int(floor((local_mouse.x - BOARD_LEFT) / CELL_PITCH))
	var m_row = int(floor((local_mouse.y - BOARD_TOP) / CELL_PITCH))
	if m_row >= 0 and m_row < GRID_ROWS and m_col >= 0 and m_col < GRID_COLUMNS:
		if abs(m_row - selected_cell.x) + abs(m_col - selected_cell.y) == 1:
			target_cell = Vector2i(m_row, m_col)

	# 2. マウスが選択マスから一定距離（80px以上）動かされている場合、最も近い方向を判定
	if target_cell.x == -1 and diff.length() >= 80.0:
		if abs(diff.x) > abs(diff.y):
			var step_c = 1 if diff.x > 0 else -1
			target_cell = Vector2i(selected_cell.x, selected_cell.y + step_c)
		else:
			var step_r = 1 if diff.y > 0 else -1
			target_cell = Vector2i(selected_cell.x + step_r, selected_cell.y)

	# 3. ターゲットセルが盤面内かつ移動可能マスか検証
	if target_cell.x >= 0 and target_cell.x < GRID_ROWS and target_cell.y >= 0 and target_cell.y < GRID_COLUMNS:
		if not _is_cell_blocked_for_swap(target_cell.x, target_cell.y):
			if hovered_swap_cell != target_cell:
				hovered_swap_cell = target_cell
				if swap_guide_overlay: swap_guide_overlay.queue_redraw()
			return

	if hovered_swap_cell.x != -1:
		hovered_swap_cell = Vector2i(-1, -1)
		if swap_guide_overlay: swap_guide_overlay.queue_redraw()

## 移動可能隣接マスガイドおよび移動先方向の強調表示を描画
func _draw_swap_guides_on_overlay(overlay: Node2D) -> void:
	if overlay == null or current_state != BoardState.IDLE:
		return

	# チュートリアル指示マスの強調および方向矢印描画
	if tutorial_allowed_swap.size() == 2:
		var c1 = tutorial_allowed_swap[0]
		var c2 = tutorial_allowed_swap[1]
		var p1 = get_cell_position(c1.x, c1.y)
		var p2 = get_cell_position(c2.x, c2.y)
		var half_p = CELL_PITCH * 0.5 - 10.0
		var r1 = Rect2(p1.x - half_p, p1.y - half_p, half_p * 2.0, half_p * 2.0)
		var r2 = Rect2(p2.x - half_p, p2.y - half_p, half_p * 2.0, half_p * 2.0)
		var pulse = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		overlay.draw_rect(r1, Color(1.0, 0.85, 0.2, 0.25 * pulse), true)
		overlay.draw_rect(r1, Color(1.0, 0.9, 0.2, 0.95), false, 12.0)
		overlay.draw_rect(r2, Color(0.2, 0.95, 0.6, 0.25 * pulse), true)
		overlay.draw_rect(r2, Color(0.2, 0.95, 0.6, 0.95), false, 12.0)
		_draw_direction_arrow(overlay, p1, p2)

	if selected_cell.x == -1:
		return

	var sel_pos = get_cell_position(selected_cell.x, selected_cell.y)
	const DIRS = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

	for d in DIRS:
		var nr = selected_cell.x + d.x
		var nc = selected_cell.y + d.y
		if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLUMNS:
			continue
		if _is_cell_blocked_for_swap(nr, nc):
			continue

		var cell_pos = get_cell_position(nr, nc)
		var half_p = CELL_PITCH * 0.5 - 10.0
		var rect = Rect2(cell_pos.x - half_p, cell_pos.y - half_p, half_p * 2.0, half_p * 2.0)

		if hovered_swap_cell == Vector2i(nr, nc):
			# === 現在向いている移動先マスの特大強調表示 ===
			var time_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			var glow_col = Color(0.1, 0.9, 1.0, 0.35 + 0.15 * time_pulse)
			overlay.draw_rect(rect, glow_col, true)
			# 外側ネオンシアン枠
			overlay.draw_rect(rect, Color(0.0, 0.95, 1.0, 0.95), false, 14.0)
			# 内側ホワイトゴールド枠
			overlay.draw_rect(rect.grow(-8.0), Color(1.0, 1.0, 0.8, 0.9), false, 4.0)

			# ターゲットロックオンL字ブラケット
			var arm = 60.0
			var b_col = Color(1.0, 1.0, 1.0, 0.95)
			# TL
			overlay.draw_line(rect.position + Vector2(10, 10), rect.position + Vector2(10 + arm, 10), b_col, 8.0)
			overlay.draw_line(rect.position + Vector2(10, 10), rect.position + Vector2(10, 10 + arm), b_col, 8.0)
			# TR
			overlay.draw_line(Vector2(rect.end.x - 10, rect.position.y + 10), Vector2(rect.end.x - 10 - arm, rect.position.y + 10), b_col, 8.0)
			overlay.draw_line(Vector2(rect.end.x - 10, rect.position.y + 10), Vector2(rect.end.x - 10, rect.position.y + 10 + arm), b_col, 8.0)
			# BL
			overlay.draw_line(Vector2(rect.position.x + 10, rect.end.y - 10), Vector2(rect.position.x + 10 + arm, rect.end.y - 10), b_col, 8.0)
			overlay.draw_line(Vector2(rect.position.x + 10, rect.end.y - 10), Vector2(rect.position.x + 10, rect.end.y - 10 - arm), b_col, 8.0)
			# BR
			overlay.draw_line(rect.end - Vector2(10, 10), rect.end - Vector2(10 + arm, 10), b_col, 8.0)
			overlay.draw_line(rect.end - Vector2(10, 10), rect.end - Vector2(10, 10 + arm), b_col, 8.0)

			# 選択コマから移動先マスへ向かう光のネオン矢印
			_draw_direction_arrow(overlay, sel_pos, cell_pos)
		else:
			# === 移動可能隣接マスのガイド表示 ===
			overlay.draw_rect(rect, Color(0.2, 0.8, 1.0, 0.08), true)
			overlay.draw_rect(rect, Color(0.3, 0.85, 1.0, 0.50), false, 6.0)

			# 小さな方向ドット/インジケーター
			var mid_point = (sel_pos + cell_pos) * 0.5
			overlay.draw_circle(mid_point, 16.0, Color(0.2, 0.85, 1.0, 0.65))
			overlay.draw_circle(mid_point, 8.0, Color(1.0, 1.0, 1.0, 0.85))

## ネオン矢印のポリゴン描画
func _draw_direction_arrow(overlay: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var dir = (to_pos - from_pos).normalized()
	var normal = Vector2(-dir.y, dir.x)
	var mid = (from_pos + to_pos) * 0.5
	var tip = mid + dir * 140.0
	var base = mid - dir * 110.0
	var w1 = mid + normal * 75.0
	var w2 = mid - normal * 75.0
	var pts = PackedVector2Array([
		tip,
		w1,
		mid + normal * 28.0 - dir * 15.0,
		base + normal * 28.0,
		base - normal * 28.0,
		mid - normal * 28.0 - dir * 15.0,
		w2
	])
	overlay.draw_colored_polygon(pts, Color(0.0, 0.95, 1.0, 0.95))
	overlay.draw_polyline(PackedVector2Array([
		tip, w1, mid + normal * 28.0 - dir * 15.0, base + normal * 28.0,
		base - normal * 28.0, mid - normal * 28.0 - dir * 15.0, w2, tip
	]), Color(1.0, 1.0, 1.0, 1.0), 6.0)

## 移動方向ハイライト用のオーバーレイノード
class SwapGuideOverlayNode extends Node2D:
	var board: Node2D = null

	func _draw() -> void:
		if board != null and is_instance_valid(board):
			board._draw_swap_guides_on_overlay(self)

# ==============================================================================

# ==============================================================================
# プレイヤー10属性×3段階 盤面スキルシステム（PvP対称盤面スキル）
# ==============================================================================
const PLAYER_SKILL_DEFS: Dictionary = {
	"water": {
		"key": "water", "label": "💧水", "name": "清流展開", "color": Color(0.10, 0.72, 0.95),
		"tiers": [
			{"tier": 1, "id": "water_1", "name": "清流展開", "cost": 30},
			{"tier": 2, "id": "water_2", "name": "命の湧水", "cost": 45},
			{"tier": 3, "id": "water_3", "name": "大海嘯",   "cost": 60},
		]
	},
	"ice": {
		"key": "ice", "label": "❄️氷", "name": "氷盾付与", "color": Color(0.35, 0.88, 1.00),
		"tiers": [
			{"tier": 1, "id": "ice_1", "name": "氷盾付与", "cost": 30},
			{"tier": 2, "id": "ice_2", "name": "連鎖氷結", "cost": 45},
			{"tier": 3, "id": "ice_3", "name": "絶対零度", "cost": 60},
		]
	},
	"wood": {
		"key": "wood", "label": "🌱木", "name": "命の萌芽", "color": Color(0.25, 0.88, 0.45),
		"tiers": [
			{"tier": 1, "id": "wood_1", "name": "命の萌芽", "cost": 30},
			{"tier": 2, "id": "wood_2", "name": "大樹根張り", "cost": 45},
			{"tier": 3, "id": "wood_3", "name": "世界樹結実", "cost": 60},
		]
	},
	"wind": {
		"key": "wind", "label": "🌪️風", "name": "疾風突風", "color": Color(0.20, 0.90, 0.65),
		"tiers": [
			{"tier": 1, "id": "wind_1", "name": "疾風突風", "cost": 30},
			{"tier": 2, "id": "wind_2", "name": "ゲイルシフト",   "cost": 45},
			{"tier": 3, "id": "wind_3", "name": "廻風反転",     "cost": 60},
		]
	},
	"fire": {
		"key": "fire", "label": "🔥火", "name": "紅蓮爆破", "color": Color(1.00, 0.45, 0.15),
		"tiers": [
			{"tier": 1, "id": "fire_1", "name": "紅蓮爆破",   "cost": 30},
			{"tier": 2, "id": "fire_2", "name": "劫火延焼", "cost": 45},
			{"tier": 3, "id": "fire_3", "name": "焦土劫火", "cost": 60},
		]
	},
	"thunder": {
		"key": "thunder", "label": "⚡雷", "name": "雷電連鎖", "color": Color(0.95, 0.85, 0.20),
		"tiers": [
			{"tier": 1, "id": "thunder_1", "name": "雷電連鎖", "cost": 30},
			{"tier": 2, "id": "thunder_2", "name": "感電網電導", "cost": 45},
			{"tier": 3, "id": "thunder_3", "name": "超電磁砲", "cost": 60},
		]
	},
	"earth": {
		"key": "earth", "label": "💎地", "name": "岩盤崩落", "color": Color(0.20, 0.82, 0.65),
		"tiers": [
			{"tier": 1, "id": "earth_1", "name": "岩盤崩落", "cost": 30},
			{"tier": 2, "id": "earth_2", "name": "地脈引力", "cost": 45},
			{"tier": 3, "id": "earth_3", "name": "大陸破砕", "cost": 60},
		]
	},
	"poison": {
		"key": "poison", "label": "🧪毒", "name": "瘴気毒霧", "color": Color(0.70, 0.35, 0.95),
		"tiers": [
			{"tier": 1, "id": "poison_1", "name": "瘴気毒霧", "cost": 30},
			{"tier": 2, "id": "poison_2", "name": "腐食培養", "cost": 45},
			{"tier": 3, "id": "poison_3", "name": "劇毒大爆発", "cost": 60},
		]
	},
	"light": {
		"key": "light", "label": "✨光", "name": "聖像降臨", "color": Color(0.95, 0.82, 0.25),
		"tiers": [
			{"tier": 1, "id": "light_1", "name": "聖像降臨", "cost": 30},
			{"tier": 2, "id": "light_2", "name": "聖光レーザー", "cost": 45},
			{"tier": 3, "id": "light_3", "name": "黄金郷顕現", "cost": 60},
		]
	},
	"dark": {
		"key": "dark", "label": "🌙闇", "name": "星影の帳", "color": Color(0.55, 0.40, 0.95),
		"tiers": [
			{"tier": 1, "id": "dark_1", "name": "星影の帳", "cost": 30},
			{"tier": 2, "id": "dark_2", "name": "領域浸食", "cost": 45},
			{"tier": 3, "id": "dark_3", "name": "虚無特異点", "cost": 60},
		]
	}
}
const PLAYER_SKILL_KEYS: Array[String] = ["water", "fire", "ice", "thunder", "wood", "earth", "wind", "poison", "light", "dark"]

var current_skill_tier: int = 1
var tier_selector_buttons: Array[Button] = []
var _cached_skill_ui_font: Font = null

## スキルの生成マッチ条件を説明文として返す（盤面スキルボタンのツールチップ用）
func _get_skill_recipe_text(skill_id: String) -> String:
	var score_mgr = _get_score_manager()
	if score_mgr and score_mgr.has_method("get_skill_by_id"):
		var s_item: Dictionary = score_mgr.get_skill_by_id(skill_id)
		if not s_item.is_empty():
			var recipe: String = str(s_item.get("match_recipe", ""))
			if recipe != "":
				var icon: String = "✨"
				if recipe.find("ソード") != -1: icon = "⚔️"
				elif recipe.find("シールド") != -1: icon = "🛡️"
				elif recipe.find("コイン") != -1: icon = "🪙"
				elif recipe.find("ポーション") != -1: icon = "🧪"
				elif recipe.find("パン") != -1: icon = "🍞"
				return "%s【生成マッチ】%s\nこのコマを4個以上つなげて消すとスキル駒が生成されます。" % [icon, recipe]
	return ""

## スキルの現在レベルの説明文を返す（盤面スキルボタンのツールチップ用）
func _get_skill_description_text(skill_id: String) -> String:
	var score_mgr = _get_score_manager()
	if score_mgr and score_mgr.has_method("get_skill_by_id"):
		var s_item: Dictionary = score_mgr.get_skill_by_id(skill_id)
		if not s_item.is_empty():
			var lvl: int = score_mgr.get_skill_level(skill_id) if score_mgr.has_method("get_skill_level") else 0
			var desc_lv: Array = s_item.get("desc_lv", [])
			if desc_lv.size() > 0:
				var idx: int = clampi(lvl - 1, 0, desc_lv.size() - 1)
				if lvl <= 0 and desc_lv.size() > 0:
					idx = 0
				return "【効果】%s" % str(desc_lv[idx])
	return ""

func _get_skill_ui_font() -> Font:
	if _cached_skill_ui_font == null:
		var main_f = load("res://font/NotoSansJP.ttf")
		var emoji_f = load("res://font/NotoEmoji.ttf")
		main_f.set_fallbacks([emoji_f])
		_cached_skill_ui_font = main_f
	return _cached_skill_ui_font

func _setup_player_skill_ui() -> void:
	if player_skill_ui_panel != null and is_instance_valid(player_skill_ui_panel):
		_update_player_skill_ui()
		return

	var host: Node = get_parent() if get_parent() != null else self
	var panel = Panel.new()
	panel.name = "PlayerSkillUIPanel"
	if host == self:
		var inv_sc = Vector2(1.0 / maxf(0.01, scale.x), 1.0 / maxf(0.01, scale.y))
		panel.position = (Vector2(24.0, 560.0) - position) * inv_sc
		panel.scale = inv_sc
	else:
		panel.position = Vector2(24.0, 560.0)
	panel.size = Vector2(196.0, 396.0)
	panel.z_index = 40

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.01, 0.02, 0.65)
	style.border_color = Color(0.25, 0.88, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	host.add_child(panel)
	player_skill_ui_panel = panel

	var ui_font = _get_skill_ui_font()

	var title_lbl = Label.new()
	title_lbl.text = "✦ 盤面スキル (自・有利)"
	title_lbl.position = Vector2(8.0, 5.0)
	title_lbl.size = Vector2(180.0, 20.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", ui_font)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.55, 0.98, 1.0))
	panel.add_child(title_lbl)
	player_skill_title_label = title_lbl

	var sp_lbl = Label.new()
	sp_lbl.name = "SkillEnergyLabel"
	sp_lbl.text = "スキルは自由に発動できます"
	sp_lbl.position = Vector2(8.0, 25.0)
	sp_lbl.size = Vector2(180.0, 18.0)
	sp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp_lbl.add_theme_font_override("font", ui_font)
	sp_lbl.add_theme_font_size_override("font_size", 11)
	sp_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.8))
	panel.add_child(sp_lbl)
	player_skill_energy_label = sp_lbl

	# 3段階ティア切替ボタン [T1 基本] [T2 発展] [T3 究極]
	tier_selector_buttons.clear()
	var tier_labels = ["T1 基本", "T2 発展", "T3 究極"]
	for t_idx in range(3):
		var t_num = t_idx + 1
		var t_btn = Button.new()
		t_btn.name = "TierBtn_%d" % t_num
		t_btn.text = tier_labels[t_idx]
		t_btn.position = Vector2(8.0 + float(t_idx) * 61.0, 47.0)
		t_btn.size = Vector2(58.0, 24.0)
		t_btn.add_theme_font_override("font", ui_font)
		t_btn.add_theme_font_size_override("font_size", 11)
		t_btn.pressed.connect(func():
			current_skill_tier = t_num
			_update_player_skill_ui()
		)
		panel.add_child(t_btn)
		tier_selector_buttons.append(t_btn)

	player_skill_buttons.clear()
	for idx in range(PLAYER_SKILL_KEYS.size()):
		var sk_key = PLAYER_SKILL_KEYS[idx]
		var sdef: Dictionary = PLAYER_SKILL_DEFS[sk_key]
		var col: int = idx % 2
		var row: int = idx / 2
		var btn = Button.new()
		btn.name = "SkillBtn_" + sk_key
		btn.position = Vector2(8.0 + col * 91.0, 76.0 + row * 62.0)
		btn.size = Vector2(88.0, 58.0)
		btn.add_theme_font_override("font", ui_font)
		btn.add_theme_font_size_override("font_size", 12)

		var base_col: Color = sdef["color"]
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = base_col.darkened(0.55)
		btn_style.border_color = base_col.lightened(0.25)
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(7)
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style = btn_style.duplicate()
		hover_style.bg_color = base_col.darkened(0.35)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(func(): _on_player_skill_button_pressed(sk_key, btn))
		panel.add_child(btn)
		player_skill_buttons[sk_key] = btn

	_update_player_skill_ui()

func on_element_category_chosen(_cat: String) -> void:
	_update_player_skill_ui()

func _get_plain_skill_label(sk_key: String) -> String:
	var label: String = str(PLAYER_SKILL_DEFS[sk_key].get("label", sk_key))
	for emoji in ["💧", "❄️", "🌱", "🌪️", "🔥", "⚡", "💎", "🧪", "✨", "🌙"]:
		label = label.replace(emoji, "")
	return label

func _update_player_skill_ui() -> void:
	var rm = _get_relic_manager()
	var chosen_cat: String = rm.get_chosen_element_category() if (rm and rm.has_method("get_chosen_element_category")) else ""

	if player_skill_title_label != null and is_instance_valid(player_skill_title_label):
		match chosen_cat:
			"nature":
				player_skill_title_label.text = "✦ 盤面スキル【自然・生命】"
			"force":
				player_skill_title_label.text = "✦ 盤面スキル【元素・破壊】"
			"mystic":
				player_skill_title_label.text = "✦ 盤面スキル【神秘・冥術】"
			_:
				player_skill_title_label.text = "✦ 盤面スキル (自・有利)"

	# ティアボタンの強調表示更新
	for t_idx in range(tier_selector_buttons.size()):
		var t_btn = tier_selector_buttons[t_idx]
		if t_btn != null and is_instance_valid(t_btn):
			var is_act = (current_skill_tier == (t_idx + 1))
			var t_style = StyleBoxFlat.new()
			t_style.bg_color = Color(0.20, 0.45, 0.60, 0.95) if is_act else Color(0.08, 0.15, 0.22, 0.8)
			t_style.border_color = Color(1.0, 0.85, 0.3) if is_act else Color(0.25, 0.45, 0.65)
			t_style.set_border_width_all(2 if is_act else 1)
			t_style.set_corner_radius_all(5)
			t_btn.add_theme_stylebox_override("normal", t_style)
			t_btn.modulate = Color(1.2, 1.2, 1.0) if is_act else Color(0.75, 0.8, 0.85)

	var can_use: bool = (current_state == BoardState.IDLE) and not is_enemy_turn_in_progress

	var category_elements: Array = []
	match chosen_cat:
		"nature": category_elements = ["water", "ice", "wood", "wind"]
		"force": category_elements = ["fire", "thunder", "earth"]
		"mystic": category_elements = ["poison", "light", "dark"]

	for sk_key in player_skill_buttons.keys():
		var btn: Button = player_skill_buttons[sk_key]
		if btn != null and is_instance_valid(btn):
			var sdef: Dictionary = PLAYER_SKILL_DEFS[sk_key]
			var t_def: Dictionary = sdef["tiers"][clampi(current_skill_tier - 1, 0, 2)]
			var skill_id = "%s_1" % sk_key
			var evo_tag: String = ""
			var score_mgr = _get_score_manager()
			var sk_lvl: int = 0
			if score_mgr and score_mgr.has_method("get_skill_level"):
				sk_lvl = score_mgr.get_skill_level(skill_id)
			var is_unlocked: bool = (sk_lvl > 0)
			var in_chosen_cat: bool = (chosen_cat != "" and sk_key in category_elements)

			# 絵文字ラベルを、その属性の現在の進化アイコンへ置き換える
			var button_icon_path: String = ""
			if score_mgr and score_mgr.has_method("get_skill_display_icon_path"):
				button_icon_path = score_mgr.get_skill_display_icon_path(skill_id)
			if button_icon_path != "" and ResourceLoader.exists(button_icon_path):
				btn.icon = load(button_icon_path)
				btn.expand_icon = true
				btn.add_theme_constant_override("icon_max_width", 20)
				btn.add_theme_constant_override("h_separation", 2)
			else:
				btn.icon = null
			var plain_label: String = _get_plain_skill_label(sk_key)

			if not is_unlocked:
				btn.text = "%s\n🔒 未解放" % plain_label
				btn.disabled = true
				btn.modulate = Color(0.35, 0.38, 0.42, 0.45)
				btn.tooltip_text = "【未解放】ショップのスキルツリーで解放すると使用可能になります。\n\n" + _get_skill_recipe_text(skill_id)
				continue

			if score_mgr and score_mgr.has_method("get_chosen_evolution"):
				var e_fin = score_mgr.get_chosen_evolution(skill_id, 20)
				var e_mid = score_mgr.get_chosen_evolution(skill_id, 10)
				if e_mid == "": e_mid = score_mgr.get_chosen_evolution(skill_id, 5)
				if e_fin != "":
					evo_tag = "\n👑" + score_mgr._get_evolution_name(skill_id, 20, e_fin)
				elif e_mid != "":
					evo_tag = "\n✨" + score_mgr._get_evolution_name(skill_id, 10, e_mid)
			btn.text = "%s\n%s%s" % [plain_label, t_def["name"], evo_tag]
			btn.tooltip_text = "【T%d %s】\n%s\n\n%s" % [int(t_def.get("tier", 1)), str(t_def.get("name", "")), _get_skill_recipe_text(skill_id), _get_skill_description_text(skill_id)]

			btn.disabled = not (can_use and in_chosen_cat)
			if in_chosen_cat:
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if can_use else Color(0.65, 0.70, 0.75, 0.85)
			else:
				btn.modulate = Color(0.35, 0.38, 0.42, 0.50)

func _on_player_skill_button_pressed(skill_key: String, btn: Button = null) -> void:
	var intro_sm = _get_stage_manager()
	if intro_sm and intro_sm.isfevertime and not pvp_mode and (intro_sm.is_waiting_for_fever_se or intro_sm.appeartime < 15):
		return
	if current_state != BoardState.IDLE or is_enemy_turn_in_progress:
		return
	var score_mgr = _get_score_manager()
	if score_mgr and score_mgr.has_method("get_skill_level"):
		if score_mgr.get_skill_level("%s_1" % skill_key) <= 0:
			return
	# ビーム演出の発射元を「スキルボタンの位置」にする（影響マスへ向かう視覚的な導線）
	var origin: Vector2 = Vector2.ZERO
	if btn != null and is_instance_valid(btn):
		origin = to_local(btn.get_global_rect().get_center())
	cast_player_skill(skill_key, false, current_skill_tier, true, origin)


func _apply_skill_shield(amount: float) -> void:
	var sm = _get_stage_manager()
	if sm and "guard" in sm:
		sm.guard += amount
	var score_mgr = _get_score_manager()
	if score_mgr and "divscore" in score_mgr and score_mgr.divscore.has(PieceType.SHIELD):
		score_mgr.divscore[PieceType.SHIELD] += int(amount)
	_spawn_shield_projectiles(score_mgr)

func _evolve_plant_stage(plant: Dictionary, target_stage: int) -> void:
	if not (plant in plant_entities):
		return
	var org: Vector2i = plant.get("origin", Vector2i(7, 7))
	if target_stage == 1:
		plant["stage"] = 1
		plant["thunder_hp"] = 2
		_spawn_growth_effect(get_cell_position(org.x, org.y), 1)
	elif target_stage >= 2:
		plant["origin"] = Vector2i(clampi(org.x, 1, GRID_ROWS - 2), clampi(org.y, 1, GRID_COLUMNS - 2))
		plant["stage"] = 2
		plant["thunder_hp"] = 3
		_clear_pieces_in_cells(_get_plant_occupied_cells(plant))
		_spawn_growth_effect(get_cell_position(plant["origin"].x, plant["origin"].y), 2)

## プレイヤーによる10属性×3段階 盤面スキル発動
func cast_player_skill(skill_key: String, ignore_cost: bool = true, tier: int = 1, animate: bool = true, origin_pos: Vector2 = Vector2.ZERO) -> Array[Vector2]:
	if pvp_mode and pvp_my_turn:
		emit_signal("pvp_move_started")
		var pvp_skill_name: String = skill_key.to_upper()
		var pvp_score_mgr = _get_score_manager()
		if pvp_score_mgr and "skill_tree_items" in pvp_score_mgr:
			for s_item in pvp_score_mgr.skill_tree_items:
				if str(s_item.get("id", "")) == skill_key + "_1":
					pvp_skill_name = str(s_item.get("name", pvp_skill_name))
					break
		turn_skill_log.append({"name": pvp_skill_name, "element": skill_key, "tier": tier})
	_ensure_ally_grids()
	tier = clampi(tier, 1, 3)

	var affected_positions: Array[Vector2] = []
	var sm = _get_stage_manager()
	var score_mgr = _get_score_manager()
	var st_idx: int = _get_stage_index()
	var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))

	var is_in_match_phase: bool = (current_state == BoardState.MATCH_HIGHLIGHT or current_state == BoardState.BREAKING)
	var skill_id = "%s_1" % skill_key
	var sk_lvl: int = 1
	if score_mgr and score_mgr.has_method("get_skill_level"):
		sk_lvl = maxi(1, score_mgr.get_skill_level(skill_id))

	var direct_skill_dmg: float = 0.0

	match skill_key:
		"water":
			if tier == 2:
				# 💧 水T2【命の湧水】：盤面の水マス数×(150+30L) HP回復＋隣接(2+L/3)マスへ浸水拡大
				var water_count: int = 0
				var existing_water: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_water[r][c]:
							water_count += 1
							existing_water.append(Vector2i(r, c))

				var spread_candidates: Array[Vector2i] = []
				for wc in existing_water:
					for dr in [-1, 0, 1]:
						for dc in [-1, 0, 1]:
							if abs(dr) + abs(dc) != 1: continue
							var nr = wc.x + dr; var nc = wc.y + dc
							if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
								if not grid_water[nr][nc] and not _is_plant_cell(nr, nc):
									var v = Vector2i(nr, nc)
									if not spread_candidates.has(v):
										spread_candidates.append(v)
				if spread_candidates.is_empty():
					for r in range(GRID_ROWS):
						for c in range(GRID_COLUMNS):
							if not grid_water[r][c] and not _is_plant_cell(r, c):
								spread_candidates.append(Vector2i(r, c))
				spread_candidates.shuffle()
				var spread_count = mini(2 + sk_lvl / 3, spread_candidates.size())
				var rm_w = _get_relic_manager()
				if rm_w and rm_w.has_relic("water_sacred_crown"):
					var sp_b = int(rm_w.get_param("water_sacred_crown", "spread_bonus", 1))
					spread_count = mini(spread_count + sp_b, spread_candidates.size())
				for i in range(spread_count):
					var cell = spread_candidates[i]
					_apply_water_to_cell(cell.x, cell.y, true)
					var pos = get_cell_position(cell.x, cell.y)
					affected_positions.append(pos)
					_spawn_aqua_splash_effect(pos, 2)
					water_count += 1

				var heal_amount = float(water_count) * (150.0 + sk_lvl * 30.0) * stage_scale
				if rm_w and rm_w.has_relic("water_sacred_crown"):
					heal_amount *= (1.0 + float(rm_w.get_param("water_sacred_crown", "heal_bonus", 0.50)))
				if sm:
					sm.calchp(0.0, -heal_amount)
					_emit_combat_event("heal", "ally", "ally", heal_amount, "water_spring_heal")

				direct_skill_dmg = (130.0 + sk_lvl * 25.0) * stage_scale
				_check_and_trigger_water_fire_synergy(is_in_match_phase)
				var fl_pos = affected_positions[0] if not affected_positions.is_empty() else Vector2(640, 360)
				_spawn_floating_text(fl_pos, "💧 命の湧水！HP+%d (水マス%d)" % [int(heal_amount), water_count], Color(0.2, 0.9, 0.6))

			elif tier == 3:
				# 💧 水T3【大海嘯・駒変換】：水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+20%
				var water_cells: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_water[r][c]:
							water_cells.append(Vector2i(r, c))
				if water_cells.size() < 4:
					var fill_candidates: Array[Vector2i] = []
					for r in range(GRID_ROWS):
						for c in range(GRID_COLUMNS):
							if not grid_water[r][c] and not _is_plant_cell(r, c):
								fill_candidates.append(Vector2i(r, c))
					fill_candidates.shuffle()
					var need_fill = mini(4 - water_cells.size(), fill_candidates.size())
					for i in range(need_fill):
						var fc = fill_candidates[i]
						_apply_water_to_cell(fc.x, fc.y, true)
						water_cells.append(fc)

				for wc in water_cells:
					var pos = get_cell_position(wc.x, wc.y)
					affected_positions.append(pos)
					_spawn_aqua_splash_effect(pos, 3)
					grid_n[wc.x][wc.y] = PieceType.SWORD
					grid_att[wc.x][wc.y] = PieceType.SWORD % 5
					if grid_i[wc.x][wc.y] >= 0 and grid_i[wc.x][wc.y] < piece.size() and piece[grid_i[wc.x][wc.y]] != null:
						piece[grid_i[wc.x][wc.y]].texture = PIECE_TEXTURES[PieceType.SWORD]
					ismatched[wc.x][wc.y] = true

				var surge_mult = 1.0 + float(sk_lvl) * 0.20
				direct_skill_dmg = (260.0 + sk_lvl * 55.0) * surge_mult * stage_scale
				_check_and_trigger_water_fire_synergy(is_in_match_phase)
				var fl_pos = affected_positions[0] if not affected_positions.is_empty() else Vector2(640, 360)
				_spawn_floating_text(fl_pos, "🌊 大海嘯！水流激突！(x%.1f)" % surge_mult, Color(0.1, 0.7, 1.0))

			else:
				# 💧 水スキル【清流展開】：移動可能な自軍水マスを生成し、そのマスの駒を消去
				var candidates: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if not _is_plant_cell(r, c) and not grid_water[r][c]:
							candidates.append(Vector2i(r, c))
				# 水スキルは中心から円形に展開する（中心に近い順に水マスを配置）
				var center_cell: Vector2i = candidates[randi() % candidates.size()] if not candidates.is_empty() else Vector2i(GRID_ROWS / 2, GRID_COLUMNS / 2)
				candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					var a_dx: int = a.x - center_cell.x
					var a_dy: int = a.y - center_cell.y
					var b_dx: int = b.x - center_cell.x
					var b_dy: int = b.y - center_cell.y
					return (a_dx * a_dx + a_dy * a_dy) < (b_dx * b_dx + b_dy * b_dy)
				)
				var count = mini(2 + sk_lvl / 2, candidates.size())
				var cleared_cells: Array[Vector2i] = []
				for i in range(count):
					var cell = candidates[i]
					_apply_water_to_cell(cell.x, cell.y, true)
					var pos = get_cell_position(cell.x, cell.y)
					affected_positions.append(pos)
					_spawn_aqua_splash_effect(pos, 1)
					if ismatched.size() == GRID_ROWS:
						ismatched[cell.x][cell.y] = true
					cleared_cells.append(cell)

				if not is_in_match_phase and cleared_cells.size() > 0:
					_clear_pieces_in_cells(cleared_cells)
					_start_continuous_falling()

				direct_skill_dmg = (80.0 + sk_lvl * 15.0) * stage_scale
				_check_and_trigger_water_fire_synergy(is_in_match_phase)
				if not affected_positions.is_empty():
					_spawn_floating_text(affected_positions[0], "💧 清流展開 (水%dマス生成)！" % count, Color(0.2, 0.8, 1.0))

		"ice":
			# 氷中間進化 A: 氷壁 (発動時にシールド獲得)
			if has_actor_skill_trait(true, "ice", "ice_mid_a"):
				var shield_gain = (150.0 + sk_lvl * 30.0) * stage_scale
				_apply_skill_shield(shield_gain)
				_spawn_floating_text(Vector2(640, 360), "❄️ 氷壁展開！防壁獲得 +%d!" % int(shield_gain), Color(0.5, 0.85, 1.0))

			if tier == 2:
				# ❄️ 氷T2【連鎖氷結フリージング・チェーン】：水マスや敵効果マスを凍結変換して完全封鎖
				var targets: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if (grid_water[r][c]) or (grid_poison[r][c] and not is_ally_poison(r, c)) or (grid_fire[r][c] > 0 and not is_ally_fire(r, c)):
							targets.append(Vector2i(r, c))
				if targets.is_empty():
					for r in range(GRID_ROWS):
						for c in range(GRID_COLUMNS):
							if int(grid_ice[r][c]) == 0 and not _is_plant_cell(r, c):
								targets.append(Vector2i(r, c))
				targets.shuffle()
				var freeze_cnt = mini(2 + sk_lvl / 2, targets.size())
				var frozen_cells: Array[Vector2i] = []
				var ice_dur = 3
				var rm_ice2 = _get_relic_manager()
				if rm_ice2 and rm_ice2.has_relic("ice_crystal_crown"):
					ice_dur += int(rm_ice2.get_param("ice_crystal_crown", "durability_bonus", 1))
				for i in range(freeze_cnt):
					var t_pos = targets[i]
					grid_water[t_pos.x][t_pos.y] = false
					grid_poison[t_pos.x][t_pos.y] = false
					grid_fire[t_pos.x][t_pos.y] = 0
					grid_ice[t_pos.x][t_pos.y] = ice_dur
					_set_ally_flag(grid_ice_ally, t_pos.x, t_pos.y, true)
					frozen_cells.append(t_pos)
					var pos = get_cell_position(t_pos.x, t_pos.y)
					affected_positions.append(pos)
				_play_ice_freeze_expansion(frozen_cells, origin_pos, animate)
				direct_skill_dmg = (140.0 + sk_lvl * 25.0) * stage_scale
				var fl_pos2 = affected_positions[0] if not affected_positions.is_empty() else Vector2(640, 360)
				_spawn_floating_text(fl_pos2, "❄️ 連鎖氷結フリージング・チェーン！", Color(0.4, 0.9, 1.0))
			elif tier == 3:
				# ❄️ 氷T3【絶対零度アブソリュート・ゼロ】：全氷マスを一斉共鳴爆砕
				var ices: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if int(grid_ice[r][c]) > 0: ices.append(Vector2i(r, c))
				if ices.is_empty():
					for i in range(2):
						var rr = randi() % GRID_ROWS; var cc = randi() % GRID_COLUMNS
						grid_ice[rr][cc] = 1
						_set_ally_flag(grid_ice_ally, rr, cc, true)
						ices.append(Vector2i(rr, cc))
				for ic in ices:
					_trigger_thunder_shatter_synergy(ic.x, ic.y, is_in_match_phase)
					var pos = get_cell_position(ic.x, ic.y)
					affected_positions.append(pos)
				_play_ice_freeze_expansion(ices, origin_pos, animate)
				enemy_turn_skip_count += 1
				direct_skill_dmg = float(ices.size()) * (240.0 + sk_lvl * 60.0) * stage_scale
				var fl_pos = affected_positions[0] if not affected_positions.is_empty() else Vector2(640, 360)
				_spawn_floating_text(fl_pos, "❄️ 絶対零度アブソリュート・ゼロ！敵行動停止！", Color(0.3, 0.95, 1.0))
			else:
				# ❄️ 氷スキル：氷マス生成（耐久値3）
				var candidates: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if not _is_plant_cell(r, c) and int(grid_ice[r][c]) == 0 and grid_i[r][c] != -1:
							candidates.append(Vector2i(r, c))
				candidates.shuffle()
				var count = mini(2 + sk_lvl / 2, candidates.size())
				var dur = 3
				var rm_ice = _get_relic_manager()
				if rm_ice and rm_ice.has_relic("ice_crystal_crown"):
					dur += int(rm_ice.get_param("ice_crystal_crown", "durability_bonus", 1))
				var frozen_cells: Array[Vector2i] = []
				for i in range(count):
					var cell = candidates[i]
					grid_ice[cell.x][cell.y] = dur
					_set_ally_flag(grid_ice_ally, cell.x, cell.y, true)
					frozen_cells.append(cell)
					var pos = get_cell_position(cell.x, cell.y)
					affected_positions.append(pos)
				_play_ice_freeze_expansion(frozen_cells, origin_pos, animate)
				direct_skill_dmg = (80.0 + sk_lvl * 15.0) * stage_scale
				_check_and_trigger_ice_fire_melting()
				if not affected_positions.is_empty():
					_spawn_floating_text(affected_positions[0], "❄️ 凍結展開 (氷%dマス耐久%d)！" % [count, dur], Color(0.4, 0.9, 1.0))

		"wood":
			# 🌱 木スキル：植樹＆成長
			if tier == 1:
				_plant_sprout_on_board()
				var rm_wood = _get_relic_manager()
				if rm_wood and rm_wood.has_relic("world_tree_seed"):
					var extra_p = int(rm_wood.get_param("world_tree_seed", "extra_plants", 1))
					for _ei in range(extra_p):
						_plant_sprout_on_board()
				var p_pos = get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2)
				if not plant_entities.is_empty():
					var last_pl = plant_entities[plant_entities.size() - 1]
					var org: Vector2i = last_pl.get("origin", Vector2i(GRID_ROWS / 2, GRID_COLUMNS / 2))
					p_pos = get_cell_position(org.x, org.y)
				affected_positions.append(p_pos)
				direct_skill_dmg = (60.0 + sk_lvl * 12.0) * stage_scale
			elif tier == 2:
				for pl in plant_entities:
					if is_ally_plant(pl) and pl.get("stage", 0) < 3:
						pl["stage"] = pl.get("stage", 0) + 1
						var org: Vector2i = pl.get("origin", Vector2i(0, 0))
						affected_positions.append(get_cell_position(org.x, org.y))
				if affected_positions.is_empty():
					affected_positions.append(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2))
				direct_skill_dmg = (120.0 + sk_lvl * 25.0) * stage_scale
			elif tier == 3:
				var center_cell = Vector2i(3, 3)
				plant_entities.append({
					"origin": center_cell,
					"stage": 3,
					"thunder_hp": 3,
					"enemy_planted": false
				})
				affected_positions.append(get_cell_position(center_cell.x, center_cell.y))
				direct_skill_dmg = (250.0 + sk_lvl * 50.0) * stage_scale

			var rm_vine = _get_relic_manager()
			if rm_vine and rm_vine.has_relic("vine_binding"):
				var delay_t = int(rm_vine.get_param("vine_binding", "delay_turns", 1))
				enemy_turn_skip_count += delay_t
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else Vector2(640, 360), "🌿 藤蔓の拘束！敵行動%dターン遅延！" % delay_t, Color(0.3, 0.95, 0.4))


		"wind":
			if tier == 2:
				# 🌪️ 風T2【ゲイル・シフト】：自軍効果マスを風下へシフト移動させて属性シナジーを能動誘発
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS - 1, 0, -1):
						if grid_fire[r][c - 1] > 0 and is_ally_fire(r, c - 1) and grid_fire[r][c] == 0:
							grid_fire[r][c] = 1; _set_ally_flag(grid_fire_ally, r, c, true)
							grid_fire[r][c - 1] = 0; _set_ally_flag(grid_fire_ally, r, c - 1, false)
						if grid_water[r][c - 1] and is_ally_water(r, c - 1) and not grid_water[r][c]:
							grid_water[r][c] = true; _set_ally_flag(grid_water_ally, r, c, true)
							grid_water[r][c - 1] = false; _set_ally_flag(grid_water_ally, r, c - 1, false)
				_check_and_trigger_ice_fire_melting()
				_check_and_trigger_water_fire_synergy(false)
				direct_skill_dmg = (140.0 + sk_lvl * 25.0) * stage_scale
				affected_positions.append(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2))
				_spawn_floating_text(affected_positions[0], "🌪️ ゲイル・シフト (風向き操作＆シナジー誘発)！", Color(0.2, 0.95, 0.7))
			elif tier == 3:
				# 🌪️ 風T3【テンペスト・リバース】：敵所有の効果マスを自軍所有へ完全強奪・反転！
				var converted_cnt = 0
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_poison.size() == GRID_ROWS and grid_poison[r][c] and not is_ally_poison(r, c):
							_set_ally_flag(grid_poison_ally, r, c, true); converted_cnt += 1
						if grid_fire.size() == GRID_ROWS and grid_fire[r][c] > 0 and not is_ally_fire(r, c):
							_set_ally_flag(grid_fire_ally, r, c, true); converted_cnt += 1
						if grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) > 0 and not is_ally_ice(r, c):
							_set_ally_flag(grid_ice_ally, r, c, true); converted_cnt += 1
						if grid_stones.size() == GRID_ROWS and int(grid_stones[r][c]) > 0 and not is_ally_stone(r, c):
							_set_ally_flag(grid_stones_ally, r, c, true); converted_cnt += 1
						if grid_water.size() == GRID_ROWS and grid_water[r][c] and not is_ally_water(r, c):
							_set_ally_flag(grid_water_ally, r, c, true); converted_cnt += 1
						if grid_cursed.size() == GRID_ROWS and grid_cursed[r][c] and not is_ally_cursed(r, c):
							_set_ally_flag(grid_cursed_ally, r, c, true); converted_cnt += 1
						if grid_electrified.size() == GRID_ROWS and grid_electrified[r][c] and not is_ally_electrified(r, c):
							_set_ally_flag(grid_electrified_ally, r, c, true); converted_cnt += 1
						if grid_gold_statue.size() == GRID_ROWS and int(grid_gold_statue[r][c]) > 0 and not is_ally_gold(r, c):
							_set_ally_flag(grid_gold_ally, r, c, true); converted_cnt += 1
				direct_skill_dmg = float(maxi(1, converted_cnt)) * (70.0 + sk_lvl * 20.0) * stage_scale
				affected_positions.append(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2))
				_spawn_floating_text(affected_positions[0], "🌪️ 反転嵐テンペスト・リバース！(反転%dマス)" % converted_cnt, Color(0.3, 1.0, 0.7))
			else:
				# 🌪️ 風スキル：竜巻召喚（全盤面の敵ハザード除去・突風による駒消去）
				var col = randi() % GRID_COLUMNS
				# 風スキルは3レベルごとに竜巻の列数（幅）が増加する
				var base_cols: int = mini(1 + sk_lvl / 3, GRID_COLUMNS)
				var start_col: int = clampi(col - (base_cols - 1) / 2, 0, GRID_COLUMNS - base_cols)
				var cols_to_sweep: Array[int] = []
				for ci in range(base_cols):
					cols_to_sweep.append(start_col + ci)
				var rm_wind = _get_relic_manager()
				if rm_wind and rm_wind.has_relic("swift_wind_feather"):
					var w_extra = int(rm_wind.get_param("swift_wind_feather", "width_bonus", 1))
					for wi in range(w_extra):
						var adj_w = start_col - 1 - wi if start_col - 1 - wi >= 0 else start_col + base_cols + wi
						if adj_w >= 0 and adj_w < GRID_COLUMNS and not cols_to_sweep.has(adj_w):
							cols_to_sweep.append(adj_w)
				if has_actor_skill_trait(true, "wind", "wind_final_b1"): # 大竜巻 (列数+1)
					var adj_c = start_col - 1 if start_col > 0 else start_col + base_cols
					if adj_c >= 0 and adj_c < GRID_COLUMNS and not cols_to_sweep.has(adj_c):
						cols_to_sweep.append(adj_c)

				var converted_cnt: int = 0
				var has_w_snatch = has_actor_skill_trait(true, "wind", "wind_mid_c")

				# 1. 奪取 (wind_mid_c): 通過列の敵妨害マスを味方に反転
				if has_w_snatch:
					for sweep_col in cols_to_sweep:
						for r in range(GRID_ROWS):
							if grid_poison.size() == GRID_ROWS and grid_poison[r][sweep_col] and not is_ally_poison(r, sweep_col):
								_set_ally_flag(grid_poison_ally, r, sweep_col, true)
								converted_cnt += 1
							if grid_fire.size() == GRID_ROWS and grid_fire[r][sweep_col] > 0 and not is_ally_fire(r, sweep_col):
								_set_ally_flag(grid_fire_ally, r, sweep_col, true)
								converted_cnt += 1
							if grid_ice.size() == GRID_ROWS and int(grid_ice[r][sweep_col]) > 0 and not is_ally_ice(r, sweep_col):
								_set_ally_flag(grid_ice_ally, r, sweep_col, true)
								converted_cnt += 1
							if grid_stones.size() == GRID_ROWS and grid_stones[r][sweep_col] > 0 and not is_ally_stone(r, sweep_col):
								_set_ally_flag(grid_stones_ally, r, sweep_col, true)
								converted_cnt += 1
							if grid_water.size() == GRID_ROWS and grid_water[r][sweep_col] and not is_ally_water(r, sweep_col):
								_set_ally_flag(grid_water_ally, r, sweep_col, true)
								converted_cnt += 1
							if grid_cursed.size() == GRID_ROWS and grid_cursed[r][sweep_col] and not is_ally_cursed(r, sweep_col):
								_set_ally_flag(grid_cursed_ally, r, sweep_col, true)
								converted_cnt += 1
							if grid_electrified.size() == GRID_ROWS and grid_electrified[r][sweep_col] and not is_ally_electrified(r, sweep_col):
								_set_ally_flag(grid_electrified_ally, r, sweep_col, true)
								converted_cnt += 1
							if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][sweep_col] > 0 and not is_ally_gold(r, sweep_col):
								_set_ally_flag(grid_gold_ally, r, sweep_col, true)
								converted_cnt += 1

				# 追い風の恵み (wind_final_c2): 奪取した味方マスの数に応じてHP回復
				if has_actor_skill_trait(true, "wind", "wind_final_c2") and converted_cnt > 0:
					var heal_amt: float = float(converted_cnt) * 60.0 * stage_scale
					if sm:
						sm.myhp = minf(sm.myhpmax, sm.myhp + heal_amt)
						if sm.has_method("displayhp"): sm.displayhp()
					_spawn_floating_text(Vector2(640, 360), "🌪️ 追い風の恵み！HP+%d!" % int(heal_amt), Color(0.3, 1.0, 0.7))

				# 2. 全盤面の敵ハザード一掃（自軍有利マスは完全保護）
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_poison.size() == GRID_ROWS and grid_poison[r][c] and not is_ally_poison(r, c):
							grid_poison[r][c] = false
						if grid_cursed.size() == GRID_ROWS and grid_cursed[r][c] and not is_ally_cursed(r, c):
							grid_cursed[r][c] = false
						if grid_electrified.size() == GRID_ROWS and grid_electrified[r][c] and not is_ally_electrified(r, c):
							grid_electrified[r][c] = false
						if grid_fire.size() == GRID_ROWS and grid_fire[r][c] > 0 and not is_ally_fire(r, c):
							grid_fire[r][c] = 0
						if grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) > 0 and not is_ally_ice(r, c):
							grid_ice[r][c] = 0
						if grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0 and not is_ally_stone(r, c):
							grid_stones[r][c] = 0
						if grid_water.size() == GRID_ROWS and grid_water[r][c] and not is_ally_water(r, c):
							grid_water[r][c] = false
						if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0 and not is_ally_gold(r, c):
							grid_gold_statue[r][c] = 0

				# 3. 敵所有の暗雲を一掃
				var fog_i = grid_fog.size() - 1
				while fog_i >= 0:
					var fog = grid_fog[fog_i]
					if fog.get("enemy_owned", true):
						grid_fog.remove_at(fog_i)
					fog_i -= 1

				# 4. 敵所有の苗木/木を一掃
				for plant in plant_entities.duplicate():
					if plant.get("enemy_planted", false):
						var occ_cells = _get_plant_occupied_cells(plant)
						_damage_plant(plant, 999, "ally_wind_tornado")
						for occ in occ_cells:
							if occ.x >= 0 and occ.x < GRID_ROWS and occ.y >= 0 and occ.y < GRID_COLUMNS:
								if grid_i.size() == GRID_ROWS and grid_i[occ.x][occ.y] == -1:
									var chosen_kind = _board_randi() % CELL_KINDS
									grid_n[occ.x][occ.y] = chosen_kind
									grid_att[occ.x][occ.y] = chosen_kind % 5
									var sprite: Sprite2D = Sprite2D.new()
									sprite.texture = PIECE_TEXTURES[chosen_kind]
									sprite.position = get_cell_position(occ.x, occ.y)
									sprite.scale = cellsize
									sprite.modulate = Color.WHITE
									_add_element_mark_to_sprite(sprite)
									add_child(sprite)
									grid_i[occ.x][occ.y] = piece.size()
									piece.append(sprite)
									piececollid.append(null)

				# 5. 突風 (wind_mid_b): 通過列の駒を消去
				var swept_cells: Array[Vector2i] = []
				if has_actor_skill_trait(true, "wind", "wind_mid_b"):
					for sweep_col in cols_to_sweep:
						for r in range(GRID_ROWS):
							if grid_i[r][sweep_col] != -1:
								swept_cells.append(Vector2i(r, sweep_col))

				# 横風 (wind_final_a2): 中央行も消去
				if has_actor_skill_trait(true, "wind", "wind_final_a2"):
					var center_row = GRID_ROWS / 2
					for c in range(GRID_COLUMNS):
						if grid_i[center_row][c] != -1:
							swept_cells.append(Vector2i(center_row, c))

				if not is_in_match_phase and swept_cells.size() > 0:
					_clear_pieces_in_cells(swept_cells)
					_start_continuous_falling()

				# 6. 特殊ゾーン (暴風圏・風の守り) & エフェクト
				for sweep_col in cols_to_sweep:
					if has_actor_skill_trait(true, "wind", "wind_final_b2"):
						storm_zones[sweep_col] = 2
					if has_actor_skill_trait(true, "wind", "wind_final_c1"):
						wind_ward_columns[sweep_col] = 2
					affected_positions.append(get_cell_position(0, sweep_col))
					_spawn_enemy_tornado_effect(get_cell_position(GRID_ROWS / 2, sweep_col), 3)

				direct_skill_dmg = (80.0 + sk_lvl * 15.0) * stage_scale
				# 疾風怒濤 (wind_final_a1): 1コンボにつき+15%
				if has_actor_skill_trait(true, "wind", "wind_final_a1"):
					var c_cnt = (sm.combocount if sm else 0)
					direct_skill_dmg *= (1.0 + float(c_cnt) * 0.15)

		"fire":
			# 🔥 火スキル：炎マス生成＆駒消去（敵火スキルとコンセプト統一）
			# 爆発系スキルではなく、ランダムなマスを炎上させて駒を消し、寿命付きの火を配置
			var fire_lifetime = DEFAULT_FIRE_LIFETIME + (tier - 1)
			var base_count = 2 + (tier - 1) * 2 # T1: 2, T2: 4, T3: 6
			var rm_fire = _get_relic_manager()
			if rm_fire and rm_fire.has_relic("blazing_fire_orb"):
				base_count += int(rm_fire.get_param("blazing_fire_orb", "range_bonus", 2))
			var count = mini(base_count + sk_lvl / 2, GRID_ROWS * GRID_COLUMNS)

			var candidates: Array[Vector2i] = []
			var empty_candidates: Array[Vector2i] = []
			for r in range(GRID_ROWS):
				for c in range(GRID_COLUMNS):
					if _is_plant_cell(r, c) or grid_fire[r][c] != 0:
						continue
					if grid_i.size() == GRID_ROWS and grid_i[r][c] != -1:
						candidates.append(Vector2i(r, c))
					else:
						empty_candidates.append(Vector2i(r, c))
			candidates.shuffle()
			empty_candidates.shuffle()
			candidates.append_array(empty_candidates)
			if candidates.is_empty():
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if not _is_plant_cell(r, c):
							candidates.append(Vector2i(r, c))
				candidates.shuffle()

			var actual_count = mini(count, candidates.size())
			var ignited_cells: Array[Vector2i] = []
			for i in range(actual_count):
				var cell = candidates[i]
				ignited_cells.append(cell)
				grid_fire[cell.x][cell.y] = maxi(int(grid_fire[cell.x][cell.y]), fire_lifetime)
				_set_ally_flag(grid_fire_ally, cell.x, cell.y, true)
				var pos = get_cell_position(cell.x, cell.y)
				affected_positions.append(pos)
				_spawn_floating_text(pos, "🔥 蒼炎！", Color(0.2, 0.7, 1.0))
				_spawn_fire_ignition_effect(pos, true)

			# 炎上マスの駒を消去して重力落下処理
			if ignited_cells.size() > 0:
				_clear_pieces_in_cells(ignited_cells)
				_start_continuous_falling()

			# 破片・榴弾進化 (fire_mid_c, fire_final_c1)
			if has_actor_skill_trait(true, "fire", "fire_mid_c") or has_actor_skill_trait(true, "fire", "fire_final_c1"):
				_trigger_fire_shrapnel_evolution(ignited_cells, true)

			# 延焼進化 (fire_mid_b) 所持時のみ追加延焼
			if has_actor_skill_trait(true, "fire", "fire_mid_b"):
				_process_fire_spread()

			_check_and_trigger_ice_fire_melting()
			_check_and_trigger_water_fire_synergy(is_in_match_phase)

			var base_dmg = 100.0 if tier == 1 else (180.0 if tier == 2 else 320.0)
			var lvl_mult = 20.0 if tier == 1 else (35.0 if tier == 2 else 60.0)
			direct_skill_dmg = (base_dmg + sk_lvl * lvl_mult) * stage_scale

			var banner_title = "🔥 蒼炎陣！" if tier == 1 else ("🔥 劫火延焼！" if tier == 2 else "🔥 焦土劫火！")
			_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else Vector2(640, 360), banner_title, Color(1.0, 0.45, 0.15))

		"thunder":
			var rm_th = _get_relic_manager()
			if rm_th and rm_th.has_relic("magnet_charm"):
				for wr in range(GRID_ROWS):
					for wc in range(GRID_COLUMNS):
						if grid_water.size() == GRID_ROWS and grid_water[wr][wc]:
							if _count_electrified_tiles() < MAX_ELECTRIFIED_TILES:
								grid_electrified[wr][wc] = true
								_set_ally_flag(grid_electrified_ally, wr, wc, true)
								_spawn_shock_zap_effect(get_cell_position(wr, wc))
			if tier == 2:
				# ⚡ 雷T2【プラズマ・コンダクト】：帯電マスと水マスを雷ラインで結び一斉感電消去
				var nodes: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_electrified[r][c] or grid_water[r][c]: nodes.append(Vector2i(r, c))
				for n in nodes:
					grid_electrified[n.x][n.y] = false
					var pos = get_cell_position(n.x, n.y)
					affected_positions.append(pos)
					_spawn_shock_zap_effect(pos)
				direct_skill_dmg = float(nodes.size()) * (120.0 + sk_lvl * 30.0) * stage_scale
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "⚡ 感電伝播プラズマ・コンダクト！", Color(1.0, 0.9, 0.2))
			elif tier == 3:
				# ⚡ 雷T3【レールガン・オーバーロード】：全帯電・石・氷を高圧電流で一斉3x3爆砕
				var shat_cnt = 0
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_electrified[r][c] or (int(grid_ice[r][c]) > 0) or (int(grid_stones[r][c]) > 0):
							_trigger_thunder_shatter_synergy(r, c, is_in_match_phase)
							grid_electrified[r][c] = false
							shat_cnt += 1
							affected_positions.append(get_cell_position(r, c))
				direct_skill_dmg = float(shat_cnt + 1) * (280.0 + sk_lvl * 60.0) * stage_scale
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "⚡ 超電磁砲レールガン・オーバーロード！", Color(1.0, 0.95, 0.3))
			else:
				# ⚡ 雷スキル：紫電共鳴（帯電マス生成＆落雷）
				# 帯電マス数は上限を設けず、レベルに応じて増え続ける
				var count = 2 + sk_lvl / 2
				if rm_th and rm_th.has_relic("thunder_god_bracelet"):
					count += int(rm_th.get_param("thunder_god_bracelet", "chain_bonus", 2))
				var elec_candidates: Array[Vector2i] = []
				for er in range(GRID_ROWS):
					for ec in range(GRID_COLUMNS):
						if not grid_electrified[er][ec] and not _is_plant_cell(er, ec):
							elec_candidates.append(Vector2i(er, ec))
				elec_candidates.shuffle()
				var actual_elec: int = mini(count, elec_candidates.size())
				for i in range(actual_elec):
					var cell = elec_candidates[i]
					var r = cell.x
					var c = cell.y
					var pos = get_cell_position(r, c)
					if _count_electrified_tiles() < MAX_ELECTRIFIED_TILES:
						grid_electrified[r][c] = true
						_set_ally_flag(grid_electrified_ally, r, c, true)
						affected_positions.append(pos)
					_spawn_shock_zap_effect(pos)
					if (grid_ice.size() == GRID_ROWS and int(grid_ice[r][c]) > 0) or (grid_stones.size() == GRID_ROWS and int(grid_stones[r][c]) > 0):
						_trigger_thunder_shatter_synergy(r, c, is_in_match_phase)

				var strike_col = randi() % GRID_COLUMNS
				for r in range(GRID_ROWS):
					var is_obj = (grid_stones.size() == GRID_ROWS and grid_stones[r][strike_col] > 0) or _is_plant_cell(r, strike_col) or (int(grid_ice[r][strike_col]) > 0)
					if is_obj:
						# 反射雷 (thunder_mid_a): 直撃時に隣接駒1個へ跳弾破壊
						if has_actor_skill_trait(true, "thunder", "thunder_mid_a"):
							for off in [Vector2i(0,-1), Vector2i(0,1)]:
								var bc = strike_col + off.y
								if bc >= 0 and bc < GRID_COLUMNS and grid_i[r][bc] != -1:
									ismatched[r][bc] = true
									_spawn_vertical_lightning_bolt(get_cell_position(r, bc), 0.05)
									break

						# 乱反射 (thunder_final_a2): 盤面端まで貫通
						if has_actor_skill_trait(true, "thunder", "thunder_final_a2"):
							for edge_c in range(GRID_COLUMNS):
								if grid_i[r][edge_c] != -1: ismatched[r][edge_c] = true
						break

				# 電磁場・感電 (thunder_mid_c): コイン駒帯電化＆敵へ感電スタック付与
				if has_actor_skill_trait(true, "thunder", "thunder_mid_c"):
					for r in range(GRID_ROWS):
						for c in range(GRID_COLUMNS):
							if grid_n.size() == GRID_ROWS and grid_n[r][c] == PieceType.COIN and not grid_electrified[r][c]:
								if _count_electrified_tiles() < MAX_ELECTRIFIED_TILES:
									grid_electrified[r][c] = true
									_set_ally_flag(grid_electrified_ally, r, c, true)
					enemy_shock_stacks = mini(5, enemy_shock_stacks + 1)
					_spawn_floating_text(Vector2(640, 360), "⚡ 雷撃感電スタック付与 (%d/5)！" % enemy_shock_stacks, Color(1.0, 0.9, 0.2))
					if enemy_shock_stacks >= 5 and has_actor_skill_trait(true, "thunder", "thunder_final_c1"):
						enemy_shock_stacks = 0
						var discharge_dmg = (350.0 + sk_lvl * 75.0) * stage_scale
						if sm and sm.ehp > 0 and not sm.isdeadf:
							sm.calchp(discharge_dmg, 0.0)
							_emit_combat_event("damage", "ally", "enemy", discharge_dmg, "thunder_shock_discharge")
						_spawn_screen_flash(Color(1.0, 1.0, 0.4, 0.4), 0.25)
						_spawn_floating_text(Vector2(640, 360), "⚡ 感電5スタック解放！特大放電 -%d!" % int(discharge_dmg), Color(1.0, 0.95, 0.2))

				affected_positions.append(get_cell_position(0, strike_col))
				_spawn_vertical_lightning_bolt(get_cell_position(GRID_ROWS / 2, strike_col), 0.0)
				direct_skill_dmg = (90.0 + sk_lvl * 18.0) * stage_scale

		"earth":
			if tier == 2:
				# 💎 地T2【大地の激震アースクエイク】：全石マスの耐久を1削り周囲8マスの駒を一掃
				var stones_pos: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if int(grid_stones[r][c]) > 0: stones_pos.append(Vector2i(r, c))
				for st in stones_pos:
					_damage_stone_at(st.x, st.y, 1)
					affected_positions.append(get_cell_position(st.x, st.y))
				direct_skill_dmg = float(maxi(1, stones_pos.size())) * (110.0 + sk_lvl * 25.0) * stage_scale
				var rm_earth2 = _get_relic_manager()
				if rm_earth2 and rm_earth2.has_relic("earth_heart"):
					direct_skill_dmg *= 1.50
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "🪨 大地の激震アースクエイク！", Color(0.8, 0.65, 0.3))
			elif tier == 3:
				# 💎 地T3【天変地異カタクリズム】：全石を一斉粉砕し超巨大岩石落とし
				var s_cnt = 0
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if int(grid_stones[r][c]) > 0:
							grid_stones[r][c] = 0
							_set_ally_flag(grid_stones_ally, r, c, false)
							s_cnt += 1
							affected_positions.append(get_cell_position(r, c))
				direct_skill_dmg = float(s_cnt + 1) * (260.0 + sk_lvl * 55.0) * stage_scale
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "🪨 天変地異カタクリズム！", Color(0.85, 0.55, 0.2))
			else:
				# 🪨 地スキル：石配置
				var candidates: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_stones[r][c] == 0 and not _is_plant_cell(r, c) and grid_i[r][c] != -1:
							candidates.append(Vector2i(r, c))
				candidates.shuffle()
				var count = mini(2 + sk_lvl / 3, candidates.size())
				var stone_dur = 3 if has_actor_skill_trait(true, "earth", "earth_mid_a") else 2 # 堅牢で耐久3
				var rm_earth = _get_relic_manager()
				if rm_earth and rm_earth.has_relic("earth_heart"):
					stone_dur += int(rm_earth.get_param("earth_heart", "durability_bonus", 2))
				for i in range(count):
					var cell = candidates[i]
					grid_stones[cell.x][cell.y] = stone_dur
					_set_ally_flag(grid_stones_ally, cell.x, cell.y, true)
					var pos = get_cell_position(cell.x, cell.y)
					affected_positions.append(pos)
					_spawn_stone_break_effect(pos)
				# 地スキルは岩盤を展開すると同時にシールドを獲得する
				var earth_shield: float = (150.0 + sk_lvl * 30.0) * stage_scale
				_apply_skill_shield(earth_shield)
				var earth_pos = affected_positions[0] if not affected_positions.is_empty() else get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2)
				_spawn_floating_text(earth_pos, "🪨 岩盤防壁 +%d!" % int(earth_shield), Color(0.85, 0.7, 0.35))
				direct_skill_dmg = (80.0 + sk_lvl * 15.0) * stage_scale

		"poison":
			if tier == 2:
				# 🧪 毒T2【ヴェノム・インキュベート】：全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換
				_process_poison_spread()
				var rm_poison2 = _get_relic_manager()
				if rm_poison2 and rm_poison2.has_relic("venom_crown"):
					_process_poison_spread()
				var p_cnt = 0
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_poison[r][c]: p_cnt += 1
				direct_skill_dmg = float(p_cnt) * (60.0 + sk_lvl * 15.0) * stage_scale
				affected_positions.append(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2))
				_spawn_floating_text(affected_positions[0], "🧪 腐食培養ヴェノム・インキュベート！", Color(0.1, 0.9, 1.0))
			elif tier == 3:
				# 🧪 毒T3【パンデミック・ショック】：全毒マスを一斉起爆・致死ダメージ＋30%HP吸収
				var poisons: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_poison[r][c]: poisons.append(Vector2i(r, c))
				for p in poisons:
					grid_poison[p.x][p.y] = false
					_set_ally_flag(grid_poison_ally, p.x, p.y, false)
					var pos = get_cell_position(p.x, p.y)
					_spawn_poison_bubble_burst_effect(pos)
					affected_positions.append(pos)
				direct_skill_dmg = float(maxi(1, poisons.size())) * (220.0 + sk_lvl * 50.0) * stage_scale
				var drain_heal = direct_skill_dmg * 0.30
				if sm:
					sm.calchp(0.0, -drain_heal)
					_emit_combat_event("heal", "ally", "ally", drain_heal)
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "☠️ 劇毒大爆発パンデミック・ショック！", Color(0.2, 0.85, 1.0))
			else:
				# 🧪 毒スキル：毒マス配置
				var candidates: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if not grid_poison[r][c] and not _is_plant_cell(r, c) and grid_i[r][c] != -1:
							candidates.append(Vector2i(r, c))
				candidates.shuffle()
				var count = mini(2 + sk_lvl / 2, candidates.size())
				var init_stage = 3 if has_actor_skill_trait(true, "poison", "poison_mid_a") else 2 # 濃縮で初期段階3／通常2
				var rm_poison = _get_relic_manager()
				if rm_poison and rm_poison.has_relic("venom_crown"):
					init_stage += int(rm_poison.get_param("venom_crown", "stage_bonus", 1))
				var poisoned_cells: Array[Vector2i] = []
				for i in range(count):
					var cell = candidates[i]
					grid_poison[cell.x][cell.y] = true
					_set_ally_flag(grid_poison_ally, cell.x, cell.y, true)
					if grid_poison_stage.size() == GRID_ROWS:
						grid_poison_stage[cell.x][cell.y] = init_stage
					poisoned_cells.append(cell)
					var pos = get_cell_position(cell.x, cell.y)
					affected_positions.append(pos)
				_play_poison_expansion(poisoned_cells, origin_pos, animate)
				direct_skill_dmg = (80.0 + sk_lvl * 15.0) * stage_scale
				if not affected_positions.is_empty():
					_spawn_floating_text(affected_positions[0], "🧪 劇毒散布 (毒%dマス)！" % count, Color(0.3, 1.0, 0.6))

		"light":
			if tier == 2:
				# ✨ 光T2【プリズム・レイ】：聖像間のライン上の妨害マス浄化＆同色変換確定マッチ
				var statues: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if int(grid_gold_statue[r][c]) > 0: statues.append(Vector2i(r, c))
				if statues.size() >= 2:
					var p1 = statues[0]; var p2 = statues[1]
					var min_r = mini(p1.x, p2.x); var max_r = maxi(p1.x, p2.x)
					var min_c = mini(p1.y, p2.y); var max_c = maxi(p1.y, p2.y)
					for r in range(min_r, max_r + 1):
						for c in range(min_c, max_c + 1):
							if grid_poison.size() == GRID_ROWS and grid_poison[r][c] and not is_ally_poison(r, c):
								grid_poison[r][c] = false
							if grid_fire.size() == GRID_ROWS and grid_fire[r][c] > 0 and not is_ally_fire(r, c):
								grid_fire[r][c] = 0
							if grid_cursed.size() == GRID_ROWS and grid_cursed[r][c] and not is_ally_cursed(r, c):
								grid_cursed[r][c] = false
							affected_positions.append(get_cell_position(r, c))
				direct_skill_dmg = (130.0 + sk_lvl * 25.0) * stage_scale
				var fl_pos = affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0)
				_spawn_floating_text(fl_pos, "✨ 閃光屈折プリズム・レイ！", Color(1.0, 0.95, 0.4))
			elif tier == 3:
				# ✨ 光T3【聖剣エクスカリバー】：全聖像が一斉昇天し神聖極太レーザー投射
				var st_cnt = 0
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if int(grid_gold_statue[r][c]) > 0:
							grid_gold_statue[r][c] = 0
							_set_ally_flag(grid_gold_ally, r, c, false)
							st_cnt += 1
							affected_positions.append(get_cell_position(r, c))
				direct_skill_dmg = float(st_cnt + 1) * (260.0 + sk_lvl * 55.0) * stage_scale
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "⚔️ 神聖聖剣エクスカリバー！", Color(1.0, 1.0, 0.6))
			else:
				# ✨ 光スキル：ランダムなマスに聖像降臨 (火・氷と同様に複数ランダムマスに効果付与)
				var candidates: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if not _is_plant_cell(r, c) and int(grid_gold_statue[r][c]) == 0:
							candidates.append(Vector2i(r, c))
				candidates.shuffle()
				var count = mini(2 + sk_lvl / 2, candidates.size())
				var statue_cells: Array[Vector2i] = []
				for i in range(count):
					var cell = candidates[i]
					grid_gold_statue[cell.x][cell.y] = 2
					_set_ally_flag(grid_gold_ally, cell.x, cell.y, true)
					statue_cells.append(cell)
					var pos = get_cell_position(cell.x, cell.y)
					affected_positions.append(pos)
					_spawn_floating_text(pos, "✨ 聖像降臨！", Color(1.0, 0.95, 0.3))
				_play_light_expansion(statue_cells, origin_pos, animate)

				var rm_light = _get_relic_manager()
				var shield_gain = (80.0 + sk_lvl * 15.0) * stage_scale
				if rm_light and rm_light.has_relic("holy_lighthouse"):
					shield_gain *= (1.0 + float(rm_light.get_param("holy_lighthouse", "statue_damage", 0.50)))
				_apply_skill_shield(shield_gain)

				has_light_dazzle_this_turn = true
				if rm_light and rm_light.has_relic("sanctuary_lamp"):
					has_light_sanctuary_this_turn = true

				# 聖域の像 (light_mid_b): 発動ターン被ダメ25%軽減
				if has_actor_skill_trait(true, "light", "light_mid_b"):
					has_light_sanctuary_this_turn = true
					_spawn_floating_text(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2), "✨ 聖域結界！(被ダメ-25%)", Color(1.0, 0.95, 0.4))

				# 聖像共振 (light_final_a2): 全聖像がレーザー連結・ライン上のコマを一掃消滅＆貫通大追撃
				if has_actor_skill_trait(true, "light", "light_final_a2"):
					var ally_statues: Array[Vector2i] = []
					for r in range(GRID_ROWS):
						for c in range(GRID_COLUMNS):
							if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0 and is_ally_gold(r, c):
								ally_statues.append(Vector2i(r, c))
					if ally_statues.size() >= 2:
						# 聖像間を走る共鳴ライン上のコマを一掃
						var p1 = ally_statues[0]
						var p2 = ally_statues[1]
						var min_r = mini(p1.x, p2.x); var max_r = maxi(p1.x, p2.x)
						var min_c = mini(p1.y, p2.y); var max_c = maxi(p1.y, p2.y)
						for lr in range(min_r, max_r + 1):
							for lc in range(min_c, max_c + 1):
								if grid_i[lr][lc] != -1:
									ismatched[lr][lc] = true
					if not ally_statues.is_empty():
						var resonance_dmg = float(ally_statues.size()) * (90.0 + sk_lvl * 20.0) * stage_scale
						if sm: sm.calchp(resonance_dmg, 0.0)
						_emit_combat_event("damage", "ally", "enemy", resonance_dmg, "holy_statue_resonance")
						_spawn_floating_text(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2), "✨ 聖像共振レーザー！", Color(1.0, 1.0, 0.5))

				affected_positions.append(get_cell_position(GRID_ROWS / 2, GRID_COLUMNS / 2))
				_spawn_screen_flash(Color(1.0, 1.0, 0.7, 0.4), 0.3)
				direct_skill_dmg = (100.0 + sk_lvl * 20.0) * stage_scale

		"dark":
			if tier == 2:
				# 🌙 闇T2【シャドウ・イクリプス】：暗雲領域内マスを一気に影護マスへ侵食＋敵HP吸収
				var fog_cnt = 0
				for fog in grid_fog:
					var rect: Rect2i = fog.get("rect", Rect2i(0, 0, 0, 0))
					for r in range(rect.position.x, rect.position.x + rect.size.x):
						for c in range(rect.position.y, rect.position.y + rect.size.y):
							if r >= 0 and r < GRID_ROWS and c >= 0 and c < GRID_COLUMNS:
								grid_cursed[r][c] = true
								_set_ally_flag(grid_cursed_ally, r, c, true)
								fog_cnt += 1
								affected_positions.append(get_cell_position(r, c))
				direct_skill_dmg = float(maxi(1, fog_cnt)) * (50.0 + sk_lvl * 15.0) * stage_scale
				if sm:
					sm.calchp(0.0, -direct_skill_dmg)
					_emit_combat_event("heal", "ally", "ally", direct_skill_dmg)
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "🌙 領域浸食シャドウ・イクリプス！", Color(0.6, 0.4, 0.95))
			elif tier == 3:
				# 🌙 闇T3【アビス・ブラックホール】：全影護マスと駒を特異点へ一斉吸引消滅・超重力＋50%HP吸収
				var curses: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if grid_cursed[r][c]: curses.append(Vector2i(r, c))
				for cr in curses:
					grid_cursed[cr.x][cr.y] = false
					_set_ally_flag(grid_cursed_ally, cr.x, cr.y, false)
					affected_positions.append(get_cell_position(cr.x, cr.y))
				direct_skill_dmg = float(maxi(1, curses.size())) * (240.0 + sk_lvl * 50.0) * stage_scale
				var drain_rate = 0.50
				var rm_dark_t3 = _get_relic_manager()
				if rm_dark_t3 and rm_dark_t3.has_relic("void_ring"):
					drain_rate = float(rm_dark_t3.get_param("void_ring", "drain_rate", 0.75))
				var drain_heal = direct_skill_dmg * drain_rate
				if sm:
					sm.calchp(0.0, -drain_heal)
					_emit_combat_event("heal", "ally", "ally", drain_heal)
				_spawn_floating_text(affected_positions[0] if not affected_positions.is_empty() else get_cell_position(0,0), "🌑 虚無特異点アビス・ブラックホール！", Color(0.5, 0.3, 0.9))
			else:
				# 🌙 闇スキル：暗雲・影護マス生成＆重力場・混沌放出
				var r0 = randi() % (GRID_ROWS - 2)
				var c0 = randi() % (GRID_COLUMNS - 2)
				grid_fog.append({
					"rect": Rect2i(r0, c0, 2, 2),
					"turns": 3,
					"enemy_owned": false
				})
				affected_positions.append(get_cell_position(r0, c0))
				var candidates: Array[Vector2i] = []
				# 優先度1: 敵妨害マス（敵呪い・毒・炎を安全に上書き）
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						if not _is_plant_cell(r, c) and not is_ally_cursed(r, c):
							var is_enemy_hz = (grid_cursed.size() == GRID_ROWS and grid_cursed[r][c] and not is_ally_cursed(r, c)) or \
											  (grid_poison.size() == GRID_ROWS and grid_poison[r][c] and not is_ally_poison(r, c)) or \
											  (grid_fire.size() == GRID_ROWS and grid_fire[r][c] > 0 and not is_ally_fire(r, c))
							if is_enemy_hz:
								candidates.append(Vector2i(r, c))
				candidates.shuffle()
				var other_cands: Array[Vector2i] = []
				for r in range(GRID_ROWS):
					for c in range(GRID_COLUMNS):
						var cp = Vector2i(r, c)
						if not candidates.has(cp) and not _is_plant_cell(r, c) and not is_ally_cursed(r, c):
							other_cands.append(cp)
				other_cands.shuffle()
				candidates.append_array(other_cands)

				var count = mini(2 + sk_lvl / 2, candidates.size())
				for i in range(count):
					var cell = candidates[i]
					grid_cursed[cell.x][cell.y] = true
					_set_ally_flag(grid_cursed_ally, cell.x, cell.y, true)
					if grid_poison.size() == GRID_ROWS: grid_poison[cell.x][cell.y] = false
					if grid_fire.size() == GRID_ROWS: grid_fire[cell.x][cell.y] = 0
					var cpos = get_cell_position(cell.x, cell.y)
					affected_positions.append(cpos)
					_spawn_floating_text(cpos, "🌙 影護マス！", Color(0.65, 0.45, 1.0))

				if has_actor_skill_trait(true, "dark", "dark_final_a2"):
					free_swap_turns = max(free_swap_turns, 3)
					has_dark_teleport_swap = true
					_spawn_floating_text(Vector2(640, 360), "🌙 空間転移！3ターン自由スワップ！", Color(0.8, 0.4, 1.0))
				elif has_actor_skill_trait(true, "dark", "dark_mid_a"):
					free_swap_turns = max(free_swap_turns, 1)
					has_dark_teleport_swap = true
					_spawn_floating_text(Vector2(640, 360), "🌙 重力場！1ターン自由スワップ！", Color(0.7, 0.3, 1.0))

				var rm_dark = _get_relic_manager()
				if rm_dark and rm_dark.has_relic("underworld_contract"):
					var extra_sw = int(rm_dark.get_param("underworld_contract", "swap_bonus", 1))
					free_swap_turns += extra_sw
					has_dark_teleport_swap = true

				# 特異点 (dark_final_a1): 中央3x3の駒を特異点へ消滅
				if has_actor_skill_trait(true, "dark", "dark_final_a1"):
					var cr = GRID_ROWS / 2; var cc = GRID_COLUMNS / 2
					for dr in [-1, 0, 1]:
						for dc in [-1, 0, 1]:
							var nr = cr + dr; var nc = cc + dc
							if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS and grid_i[nr][nc] != -1:
								ismatched[nr][nc] = true
					_spawn_black_hole_effect(get_cell_position(cr, cc), 3)

				# 混沌 (dark_mid_c): 蓄積被ダメージの全放出
				if has_actor_skill_trait(true, "dark", "dark_mid_c") and dark_accumulated_damage > 0.0:
					var release_dmg = dark_accumulated_damage
					dark_accumulated_damage = 0.0
					if has_actor_skill_trait(true, "dark", "dark_final_c1"): # 復讐 (+50%)
						release_dmg *= 1.50
					if has_actor_skill_trait(true, "dark", "dark_final_c2"): # 逆流 (35%回復)
						var heal_amt = release_dmg * 0.35
						sm.calchp(0.0, -heal_amt)
						_emit_combat_event("heal", "ally", "ally", heal_amt)
					direct_skill_dmg += release_dmg
					_spawn_floating_text(Vector2(640, 360), "🌙 混沌解放 -%d!" % int(release_dmg), Color(0.8, 0.2, 0.95))

				direct_skill_dmg += (80.0 + sk_lvl * 15.0) * stage_scale

	# スキル発動時の敵への直接属性ダメージ
	if sm and sm.ehp > 0 and direct_skill_dmg > 0.0:
		var rm = _get_relic_manager()
		if rm:
			direct_skill_dmg = rm.modify_damage_dealt(direct_skill_dmg, {"element": skill_key, "element_name": skill_key, "is_skill": true})
		sm.calchp(direct_skill_dmg, 0.0)
		_emit_combat_event("damage", "ally", "enemy", direct_skill_dmg, "player_skill_" + skill_key)

	if not affected_positions.is_empty():
		_spawn_floating_text(affected_positions[0], "✦ 自軍スキル【T%d %s】発動！" % [tier, skill_key.to_upper()], Color(0.45, 0.98, 1.0))
		# 属性魔力弾（スペルビーム／彗星弾頭）演出：スキル発動位置から影響マスへビームを飛ばす
		if animate:
			_spawn_player_skill_beams(origin_pos, affected_positions, skill_key)

	# PvP: このスキルで実際に影響したマスを記録する（相手盤面へのミラー効果に使用）
	if pvp_mode and not turn_skill_log.is_empty():
		var mirror_cells: Array = []
		for pos in affected_positions:
			var m_c: int = int(round((pos.x - BOARD_LEFT) / CELL_PITCH - 0.5))
			var m_r: int = int(round((pos.y - BOARD_TOP) / CELL_PITCH - 0.5))
			if m_r >= 0 and m_r < GRID_ROWS and m_c >= 0 and m_c < GRID_COLUMNS:
				mirror_cells.append([m_r, m_c])
		turn_skill_log[turn_skill_log.size() - 1]["cells"] = mirror_cells

	var rm_end = _get_relic_manager()
	if rm_end and rm_end.has_relic("spirit_blessing"):
		var shield_ratio = float(rm_end.get_param("spirit_blessing", "shield_ratio", 0.03))
		var shield_gain = (sm.myhpmax if sm else 5000.0) * shield_ratio
		_apply_skill_shield(shield_gain)
		_spawn_floating_text(Vector2(640, 360), "🛡️ 精霊の祝福・シールド+%d" % int(shield_gain), Color(0.5, 1.0, 0.9))
		emit_signal("relic_triggered", "spirit_blessing")

	_update_player_skill_ui()
	_update_status_ailments()
	_redraw_board_effects()
	return affected_positions
