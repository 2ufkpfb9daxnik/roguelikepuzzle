extends Node2D

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
const GRID_COLUMNS: int = 15
const GRID_ROWS: int = 15
const CELL_KINDS: int = 5
const OFFSET_X: float = 4000.0
const OFFSET_Y: float = 1000.0
const CELL_PITCH: float = 500.0

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

# スコア欄ラベルの初期座標とピッチ定数（ScoreManager内の元の配置に厳密に完全固定）
const SCORE_LABEL_BASE_X: float = 1200.0
const SCORE_LABEL_BASE_Y: float = 472.0
const SCORE_LABEL_PITCH: float = 50.0
const SCORE_LABEL_BASE_SCALE: Vector2 = Vector2(0.5, 0.5)

# スコア欄の上下運動（放物線バウンド）パラメータ（以前の挙動の完全復元 ＆ 3倍速化）
const BOUNCE_CYCLE_FRAMES: int = 12  # 1回の跳ね上がり周期 (12フレーム = 約0.2秒)
const BOUNCE_CYCLES: int = 3        # 跳ねる回数 (3回)
const BOUNCE_TOTAL_FRAMES: int = BOUNCE_CYCLE_FRAMES * BOUNCE_CYCLES # 36フレーム (約0.6秒)
const BOUNCE_HEIGHT: float = 28.0   # 上下運動の跳ね上がり高さ (px)

# 攻撃フェーズで生成する剣・盾・食料・ポーションの最大上限数（フリーズ対策・描画負荷最適化）
const MAX_COMBAT_PROJECTILES: int = 300

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
	MAGNET = 10,           # マグネット (互換用)
	CHARGE_BOMB = 11,      # チャージボム (互換用)
	GEMINI_BOMB = 12       # ジェミニボム (互換用)
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
	SpecialItemType.DISCO_BALL: 1.0        # スターオーブ (全画面消滅・極小)
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
var grid_water: Array = []     # [row][col] -> bool (水浸しマス・スワップ禁止・雷感電)
var grid_ice: Array = []       # [row][col] -> int (氷漬けマス・耐久値・スワップ禁止・落雷除去不可)
var grid_electrified: Array = [] # [row][col] -> bool (帯電コマ・触れる/マッチで反動ダメージ)
var grid_stones: Array = []    # [row][col] -> int (石・耐久値 1)
var grid_fog: Array[Dictionary] = [] # [{"rect": Rect2i, "turns": int}] (黒い霧)
var grid_cursed: Array = []    # [row][col] -> bool (呪いコマ・消すと反動ダメージ)
var grid_gold_statue: Array = [] # [row][col] -> int (黄金像スカコマ・耐久値 3)
var active_wind_tornadoes: Array[Dictionary] = [] # [{"col": int, "y": float, "speed": float, "active": bool}]
var enemy_skill_banner: RichTextLabel = null
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
	SpecialItemType.GEMINI_BOMB: 0
}

# 演出用状態
var encolor: float = 1.0
var isattack: int = 0
var isblock: int = 0
var has_enemy_attacked: bool = false
var isswap: bool = false
var isbreak: bool = false
var endbreak: bool = false
var canfall: bool = false
var isgameover: bool = false

# 内部変数
var current_state: BoardState = BoardState.IDLE

var cellsize: Vector2 = Vector2.ONE
var piece: Array = []        # Sprite2Dの1次元配列
var piececollid: Array = []  # CollisionShape2D等の1次元配列

var grid_n: Array = []       # [row][col] -> 駒の種類 (0..4)
var grid_i: Array = []       # [row][col] -> piece配列内のインデックス
var grid_att: Array = []     # [row][col] -> 属性 (PieceType)
var ismatched: Array = []    # [row][col] -> マッチフラグ

# 操作用（ドラッグ＆ドロップ、および2クリック選択の両対応）
var selected_cell: Vector2i = Vector2i(-1, -1)
var selected_piece_idx: int = -1
var is_holding: bool = false
var press_start_cell: Vector2i = Vector2i(-1, -1)

# 落下アニメーション管理
var falling_pieces: Array[Dictionary] = [] # {"sprite": Sprite2D, "target_y": float, "velocity_y": float, "landed": bool}
var matched_cells_list: Array[Vector2i] = [] # 現在マッチしているセルの座標リスト

# タイマー・フレーム管理
var interval: int = 0
var msisvalid: bool = false
var mshisvalid: bool = false

# --- 演出用オブジェクト管理 ---
var flying_cells: Array[Dictionary] = []    # マッチしてスコア欄へ飛ぶ駒
var flying_swords: Array[Dictionary] = []   # 剣
var active_shields: Array[Dictionary] = []  # 展開シールド
var current_total_shields: int = 0          # 生成総数（1000個制限後も被ダメージ軽減計算に使用）
var flying_foods: Array[Dictionary] = []    # 食料
var flying_potions: Array[Dictionary] = []  # ポーション

var scratch_effect: AnimatedSprite2D = null
var is_casting_skill_turn: bool = false

# ノード参照
var score_manager: Node2D = null
@onready var board_bg = get_node_or_null("BoardBackground")
var mark_overlay: Node2D = null
var board_overlay: Node2D = null

## 盤面描画の一括更新
func _redraw_board_effects() -> void:
	if board_bg: board_bg.queue_redraw()
	if board_overlay: board_overlay.queue_redraw()
	if mark_overlay: mark_overlay.queue_redraw()

# 戦闘演出・発射物シミュレーションの速度累積変数
var _turn_sim_accumulator: float = 0.0

## 現在のゲーム設定速度を取得（SettingsManager優先、FallbackはEngine.time_scale）
func _get_game_speed() -> float:
	var root_node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	if root_node:
		var sm_autoload = root_node.get_node_or_null("SettingsManager")
		if sm_autoload and "game_speed" in sm_autoload:
			return sm_autoload.game_speed
	return Engine.time_scale

func _get_stage_manager() -> Node2D:
	var p = get_parent()
	return p.get_node_or_null("StageManager") if p else null

func _get_score_manager() -> Node2D:
	if score_manager == null:
		var p = get_parent()
		if p:
			score_manager = p.get_node_or_null("ScoreManager")
	return score_manager

## セルのローカル座標を取得
func get_cell_position(r: int, c: int) -> Vector2:
	return Vector2(c * CELL_PITCH + CELL_PITCH + dx, r * CELL_PITCH + CELL_PITCH + dy)

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


func _ready() -> void:
	score_manager = _get_score_manager()
	if board_bg:
		board_bg.board = self
		board_bg.queue_redraw()

	# 属性妨害エフェクト・障害物のオーバーレイ (z_index = 8)
	var overlay_script = preload("res://board_overlay.gd")
	board_overlay = overlay_script.new()
	board_overlay.name = "BoardOverlay"
	board_overlay.board = self
	add_child(board_overlay)
	
	# 特殊アイテムのシンプルシンボルマーク（雷マーク⚡等）を描画する最前面レイヤー
	var ov = SpecialMarkOverlayNode.new()
	ov.name = "SpecialMarkOverlay"
	ov.board = self
	ov.z_index = 15
	mark_overlay = ov
	add_child(mark_overlay)
	
	var rensa_se = get_node_or_null("1rensa")
	if rensa_se:
		rensa_se.pitch_scale = 0.92

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

## 盤面の初期化（初期状態で3マッチが発生しないよう配置・定数テクスチャによる確実な属性紐付け）
func _initialize_board(collid_template: Node) -> void:
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
	grid_electrified.clear()
	grid_stones.clear()
	grid_fog.clear()
	grid_cursed.clear()
	grid_gold_statue.clear()

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
		var row_electrified: Array[bool] = []
		var row_stones: Array[int] = []
		var row_cursed: Array[bool] = []
		var row_gold_statue: Array[int] = []

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

			var chosen_kind: int = available_kinds[randi() % available_kinds.size()]
			var piece_idx: int = i * GRID_COLUMNS + j

			row_n.append(chosen_kind)
			row_i.append(piece_idx)
			row_matched.append(false)
			row_att.append(chosen_kind % 5)
			row_bomb.append(false)
			row_special.append(SpecialItemType.NONE)
			row_charge.append(0)
			row_water.append(false)
			row_ice.append(0)
			row_electrified.append(false)
			row_stones.append(0)
			row_cursed.append(false)
			row_gold_statue.append(0)

			var pos = get_cell_position(i, j)

			# 定数テクスチャ配列から確実に正しい絵柄のスプライトを生成
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = PIECE_TEXTURES[chosen_kind]
			sprite.position = pos
			sprite.scale = cellsize
			sprite.modulate = Color.WHITE
			add_child(sprite)
			piece.append(sprite)

			if collid_template and area_node:
				var collid = collid_template.duplicate()
				collid.position = pos
				area_node.add_child(collid)
				piececollid.append(collid)

		grid_n.append(row_n)
		grid_i.append(row_i)
		ismatched.append(row_matched)
		grid_att.append(row_att)
		is_bomb.append(row_bomb)
		special_item.append(row_special)
		special_charge.append(row_charge)
		grid_water.append(row_water)
		grid_ice.append(row_ice)
		grid_electrified.append(row_electrified)
		grid_stones.append(row_stones)
		grid_cursed.append(row_cursed)
		grid_gold_statue.append(row_gold_statue)

	current_state = BoardState.IDLE
	_spawn_turn_specials()

# --- マウス入力とスワップ処理 ---

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var sm = _get_stage_manager()

	# ゲームオーバー判定：体力が0またはゲームオーバー時はすべての盤面入力を遮断
	if isgameover or (sm and sm.myhpmax > 0 and sm.myhp <= 0):
		if selected_cell.x != -1:
			_deselect_piece()
		is_holding = false
		return

	# フィーバー突入文字の表示待機中：クリックで待機時間を即座にスキップし、BGM再生を保証してプレイ開始
	if sm and sm.isfevertime and sm.appeartime < sm.FEVER_INTRO_FRAMES:
		if mouse_event.pressed:
			sm.appeartime = sm.FEVER_INTRO_FRAMES
			if sm.has_method("_ensure_fever_bgm"):
				sm._ensure_fever_bgm()
			sm._process_fever_effects()
			# クリック操作を破棄せず、そのまま下の駒選択・ドラッグ操作へ継続
		else:
			return

	if sm and (sm.interval < 105 or sm.isstageclear or sm.isdeadf):
		if selected_cell.x != -1:
			_deselect_piece()
		return

	if current_state != BoardState.IDLE:
		return

	var local_pos = to_local(mouse_event.position)
	var col_idx = int(floor((local_pos.x - 4250.0) / 500.0))
	var row_idx = int(floor((local_pos.y - 1250.0) / 500.0))
	var is_in_bounds: bool = (row_idx >= 0 and row_idx < GRID_ROWS and col_idx >= 0 and col_idx < GRID_COLUMNS)

	if mouse_event.pressed:
		is_holding = true
		press_start_cell = Vector2i(row_idx, col_idx) if is_in_bounds else Vector2i(-1, -1)

		# 植物（木・苗）のマスは駒が存在せずクリック・スワップ不可
		if is_in_bounds and _is_plant_cell(row_idx, col_idx):
			if selected_cell.x != -1:
				_deselect_piece()
			return

		# 水浸しマスは滑って動かせない（スワップ・選択禁止）
		if is_in_bounds and grid_water.size() == GRID_ROWS and grid_water[row_idx][col_idx]:
			if selected_cell.x != -1:
				_deselect_piece()
			_splash_water_jiggle(row_idx, col_idx)
			return

		# 氷漬けマスは凍りついて動かせない（スワップ・選択禁止）
		if is_in_bounds and grid_ice.size() == GRID_ROWS and grid_ice[row_idx][col_idx]:
			if selected_cell.x != -1:
				_deselect_piece()
			_shake_ice_jiggle(row_idx, col_idx)
			return

		# 石マスは動かせない障害物（スワップ・選択禁止）
		if is_in_bounds and grid_stones.size() == GRID_ROWS and grid_stones[row_idx][col_idx] > 0:
			if selected_cell.x != -1:
				_deselect_piece()
			_shake_stone_jiggle(row_idx, col_idx)
			return

		# 黄金石像マスは動かせないスカコマ（スワップ・選択禁止）
		if is_in_bounds and grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[row_idx][col_idx] > 0:
			if selected_cell.x != -1:
				_deselect_piece()
			_shake_gold_jiggle(row_idx, col_idx)
			return

		# 帯電コマに触れた場合の感電放電・反動ダメージ
		if is_in_bounds and grid_electrified.size() == GRID_ROWS and grid_electrified[row_idx][col_idx]:
			grid_electrified[row_idx][col_idx] = false
			if sm:
				var shock_dmg = minf(sm.myhpmax * 0.05, 300.0) if sm.myhpmax > 0 else 300.0
				sm.calchp(0.0, shock_dmg)
			_spawn_shock_zap_effect(get_cell_position(row_idx, col_idx))
			_redraw_board_effects()


		# 爆弾・特殊アイテムのクリック即時起爆（1手消費）
		var has_special_at_click: bool = false
		if is_in_bounds:
			if is_bomb.size() == GRID_ROWS and is_bomb[row_idx][col_idx]:
				has_special_at_click = true
			elif special_item.size() == GRID_ROWS and special_item[row_idx][col_idx] != SpecialItemType.NONE:
				has_special_at_click = true

		if has_special_at_click:
			if selected_cell.x != -1:
				_deselect_piece()
			_detonate_special_by_click(row_idx, col_idx)
			return

		if selected_cell.x == -1:
			# 未選択時: クリックしたマスを選択
			if is_in_bounds:
				var p_idx = grid_i[row_idx][col_idx]
				if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
					selected_cell = Vector2i(row_idx, col_idx)
					selected_piece_idx = p_idx
					piece[p_idx].z_index = 10
					piece[p_idx].scale = cellsize * 1.2
					if board_bg: board_bg.queue_redraw()
					var se2 = get_node_or_null("AudioStreamPlayer2")
					if se2: se2.play()
		else:
			# すでに選択中: 今回クリックしたマスとの位置関係でスワップまたは解除
			if is_in_bounds and (abs(row_idx - selected_cell.x) + abs(col_idx - selected_cell.y) == 1):
				var r1 = selected_cell.x
				var c1 = selected_cell.y
				_execute_swap(r1, c1, row_idx, col_idx)
			else:
				_deselect_piece()
	else:
		# マウスボタン解放
		is_holding = false
		if selected_cell.x != -1:
			if is_in_bounds and (abs(row_idx - selected_cell.x) + abs(col_idx - selected_cell.y) == 1):
				# 隣接マスで離した (ドラッグ&ドロップ成立)
				var r1 = selected_cell.x
				var c1 = selected_cell.y
				_execute_swap(r1, c1, row_idx, col_idx)
			elif not is_in_bounds or (press_start_cell != Vector2i(row_idx, col_idx) and (abs(row_idx - selected_cell.x) + abs(col_idx - selected_cell.y) > 1)):
				# 盤面外や2マス以上離れた場所で離した (ドラッグ失敗・キャンセル)
				_deselect_piece()
			# (同じマスで離した場合は単なるクリック選択なので維持)

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
	press_start_cell = Vector2i(-1, -1)
	if board_bg: board_bg.queue_redraw()

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
		add_child(drop)
		var a = randf() * TAU
		var tw_d = create_tween().set_parallel(true)
		tw_d.tween_property(drop, "position", center + Vector2(cos(a), sin(a)) * 80.0, 0.25).set_ease(Tween.EASE_OUT)
		tw_d.tween_property(drop, "modulate:a", 0.0, 0.25)
		tw_d.chain().tween_callback(drop.queue_free)

## 2つの駒をTweenで滑らかにスワップ
func _execute_swap(r1: int, c1: int, r2: int, c2: int) -> void:
	if _is_plant_cell(r1, c1) or _is_plant_cell(r2, c2):
		_deselect_piece()
		return

	if grid_water.size() == GRID_ROWS and (grid_water[r1][c1] or grid_water[r2][c2]):
		_deselect_piece()
		if grid_water[r1][c1]: _splash_water_jiggle(r1, c1)
		if grid_water[r2][c2]: _splash_water_jiggle(r2, c2)
		return

	if (grid_ice.size() == GRID_ROWS and (grid_ice[r1][c1] or grid_ice[r2][c2])) or \
	   (grid_stones.size() == GRID_ROWS and (grid_stones[r1][c1] > 0 or grid_stones[r2][c2] > 0)) or \
	   (grid_gold_statue.size() == GRID_ROWS and (grid_gold_statue[r1][c1] > 0 or grid_gold_statue[r2][c2] > 0)):
		_deselect_piece()
		if grid_ice.size() == GRID_ROWS:
			if grid_ice[r1][c1]: _shake_ice_jiggle(r1, c1)
			if grid_ice[r2][c2]: _shake_ice_jiggle(r2, c2)
		if grid_stones.size() == GRID_ROWS:
			if grid_stones[r1][c1] > 0: _shake_stone_jiggle(r1, c1)
			if grid_stones[r2][c2] > 0: _shake_stone_jiggle(r2, c2)
		if grid_gold_statue.size() == GRID_ROWS:
			if grid_gold_statue[r1][c1] > 0: _shake_gold_jiggle(r1, c1)
			if grid_gold_statue[r2][c2] > 0: _shake_gold_jiggle(r2, c2)
		return

	current_state = BoardState.SWAPPING

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
	press_start_cell = Vector2i(-1, -1)
	if board_bg: board_bg.queue_redraw()

	# 盤面データを仮交換
	_swap_grid_data(r1, c1, r2, c2)

	var se2 = get_node_or_null("AudioStreamPlayer2")
	if se2: se2.play()

	var tween = create_tween().set_parallel(true)
	if p1: tween.tween_property(p1, "position", pos2, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if p2: tween.tween_property(p2, "position", pos1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

	# スワップ後にマッチが存在するか判定
	var has_match = _check_matches_exist()
	if has_match:
		_check_and_trigger_bomb_reactions()
		_start_match_highlight()
	else:
		# マッチ不成立：元に戻すアニメーション
		var revert_tween = create_tween().set_parallel(true)
		if p1: revert_tween.tween_property(p1, "position", pos1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if p2: revert_tween.tween_property(p2, "position", pos2, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_swap_grid_data(r1, c1, r2, c2)
		await revert_tween.finished
		current_state = BoardState.IDLE

## グリッドデータのスワップ
func _swap_grid_data(r1: int, c1: int, r2: int, c2: int) -> void:
	var tmp_i = grid_i[r1][c1]
	grid_i[r1][c1] = grid_i[r2][c2]
	grid_i[r2][c2] = tmp_i

	var tmp_n = grid_n[r1][c1]
	grid_n[r1][c1] = grid_n[r2][c2]
	grid_n[r2][c2] = tmp_n

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

	if grid_cursed.size() == GRID_ROWS:
		var tmp_cu = grid_cursed[r1][c1]
		grid_cursed[r1][c1] = grid_cursed[r2][c2]
		grid_cursed[r2][c2] = tmp_cu

	if tmp_i >= 0 and tmp_i < piececollid.size() and piececollid[tmp_i]:
		piececollid[tmp_i].position = get_cell_position(r2, c2)
	var other_i = grid_i[r1][c1]
	if other_i >= 0 and other_i < piececollid.size() and piececollid[other_i]:
		piececollid[other_i].position = get_cell_position(r1, c1)

# --- 3マッチ判定 ---

func _check_matches_exist() -> bool:
	for i in range(GRID_ROWS):
		for j in range(GRID_COLUMNS):
			ismatched[i][j] = false

	var found = false

	# 横方向スキャン
	for i in range(GRID_ROWS):
		var j: int = 0
		while j < GRID_COLUMNS:
			var kind: int = grid_n[i][j]
			if kind < 0:
				j += 1
				continue
			var match_len: int = 1
			while j + match_len < GRID_COLUMNS and grid_n[i][j + match_len] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(j, j + match_len):
					ismatched[i][k] = true
			j += match_len

	# 縦方向スキャン
	for j in range(GRID_COLUMNS):
		var i: int = 0
		while i < GRID_ROWS:
			var kind: int = grid_n[i][j]
			if kind < 0:
				i += 1
				continue
			var match_len: int = 1
			while i + match_len < GRID_ROWS and grid_n[i + match_len][j] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(i, i + match_len):
					ismatched[k][j] = true
			i += match_len

	return found

# --- 特殊アイテムシステム（爆弾・クロスボム・ディスコ・ペンキ・雷・黒穴・磁石・時限・分裂） ---

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

## 落下時の特殊アイテム抽選
func _roll_falling_special() -> int:
	var unlocked: Array[int] = []
	var total_levels: int = 0
	for item_type in special_levels:
		var lvl: int = special_levels[item_type]
		if lvl > 0:
			unlocked.append(item_type)
			total_levels += lvl

	if unlocked.is_empty() or total_levels <= 0:
		return SpecialItemType.NONE

	# 落下確率は未解放時 0% 〜 解放レベルに応じて微増し最大 3% (0.03) に厳格制限
	var chance: float = clampf(float(total_levels) * 0.005, 0.0, 0.03)
	if randf() >= chance:
		return SpecialItemType.NONE

	# 内訳の加重ランダム抽選（ディスコボール等の強すぎるアイテムは極小ウェイト）
	var total_weight: float = 0.0
	for item_type in unlocked:
		total_weight += SPECIAL_DROP_WEIGHTS.get(item_type, 10.0)

	if total_weight <= 0.0:
		return unlocked[0]

	var roll: float = randf() * total_weight
	var accumulated: float = 0.0
	for item_type in unlocked:
		accumulated += SPECIAL_DROP_WEIGHTS.get(item_type, 10.0)
		if roll <= accumulated:
			return item_type

	return unlocked[0]

## 毎ターン開始時の特殊アイテム生成およびチャージ進行
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

	# 2. 空きマス候補の収集
	var candidates: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_i[r][c] != -1 and special_item[r][c] == SpecialItemType.NONE and not is_bomb[r][c]:
				candidates.append(Vector2i(r, c))

	candidates.shuffle()

	# 3. 解放済みアイテムの生成
	var cand_idx: int = 0
	for item_type in special_levels:
		var lvl: int = special_levels[item_type]
		if lvl <= 0:
			continue

		var spawn_num: int = 1
		if lvl >= 3:
			spawn_num = 2 # Lv3以上なら毎ターン2個生成

		for k in range(spawn_num):
			if cand_idx >= candidates.size():
				break
			var pos = candidates[cand_idx]
			cand_idx += 1
			special_item[pos.x][pos.y] = item_type
			if is_bomb.size() == GRID_ROWS:
				is_bomb[pos.x][pos.y] = true
			if item_type == SpecialItemType.CHARGE_BOMB:
				special_charge[pos.x][pos.y] = 1

	if board_bg:
		board_bg.queue_redraw()

func _spawn_turn_bombs() -> void:
	_spawn_turn_specials()

## クリックによる即時起爆（1手消費）
func _detonate_special_by_click(r: int, c: int) -> void:
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
	if special_item.size() != GRID_ROWS and is_bomb.size() != GRID_ROWS:
		return
	var items_to_detonate: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if ismatched[r][c]:
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0: continue
						var nr = r + dr
						var nc = c + dc
						if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
							var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
							if has_sp and not (Vector2i(nr, nc) in items_to_detonate):
								items_to_detonate.append(Vector2i(nr, nc))

	if items_to_detonate.size() > 0:
		_detonate_specials(items_to_detonate)

func _check_and_trigger_bomb_reactions() -> void:
	_check_and_trigger_special_reactions()

## 特殊アイテムの連鎖起爆キュー処理
func _detonate_specials(start_items: Array) -> void:
	var queue: Array = start_items.duplicate()
	var exploded_items: Dictionary = {}

	while queue.size() > 0:
		var b = queue.pop_front()
		if b in exploded_items:
			continue
		exploded_items[b] = true

		var item_type: int = SpecialItemType.BOMB
		if special_item.size() == GRID_ROWS:
			item_type = special_item[b.x][b.y]
			if item_type == SpecialItemType.NONE and is_bomb.size() == GRID_ROWS and is_bomb[b.x][b.y]:
				item_type = SpecialItemType.BOMB
			special_item[b.x][b.y] = SpecialItemType.NONE
		if is_bomb.size() == GRID_ROWS:
			is_bomb[b.x][b.y] = false

		var pos = get_cell_position(b.x, b.y)

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
			SpecialItemType.MAGNET:
				_trigger_magnet(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.CHARGE_BOMB:
				_trigger_charge_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.GEMINI_BOMB:
				_trigger_gemini_bomb(b.x, b.y, pos, queue, exploded_items)
			_:
				_trigger_bomb(b.x, b.y, pos, queue, exploded_items)

	if board_bg:
		board_bg.queue_redraw()

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
		effects_parent.add_child(puff)

		var tw = create_tween().set_parallel(true)
		var rise_y = randf_range(60.0, 120.0)
		tw.tween_property(puff, "position:y", puff.position.y - rise_y, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "position:x", puff.position.x + randf_range(-20.0, 20.0), 0.45)
		tw.tween_property(puff, "scale", Vector2(1.8, 1.8), 0.45)
		tw.tween_property(puff, "color:a", 0.0, 0.45)
		tw.chain().tween_callback(puff.queue_free)

# --- 各アイテムの個別アクション処理 ---

func _trigger_bomb(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.BOMB, 1))
	var radius: int = 1 # Lv1: 3x3
	if lvl == 2:
		radius = 2 # Lv2: 5x5
	elif lvl >= 3:
		radius = 3 # Lv3: 7x7

	_spawn_explosion_effect(pos)
	for dr in range(-radius, radius + 1):
		for dc in range(-radius, radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][nc])
				if is_water:
					grid_water[nr][nc] = false
					_spawn_steam_effect(get_cell_position(nr, nc))
				else:
					if grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
						if has_sp and not (Vector2i(nr, nc) in exploded_items):
							queue.append(Vector2i(nr, nc))

	_check_burn_plants_in_rect(r - radius, r + radius, c - radius, c + radius, queue, exploded_items)

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

	# 縦方向
	for dr in range(-r_reach, r_reach + 1):
		var nr = r + dr
		if nr >= 0 and nr < GRID_ROWS:
			var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][c])
			if is_water:
				grid_water[nr][c] = false
				_spawn_steam_effect(get_cell_position(nr, c))
			else:
				if grid_i[nr][c] != -1:
					ismatched[nr][c] = true
					var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][c] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][c])
					if has_sp and not (Vector2i(nr, c) in exploded_items):
						queue.append(Vector2i(nr, c))

	# 横方向
	for dc in range(-c_reach, c_reach + 1):
		var nc = c + dc
		if nc >= 0 and nc < GRID_COLUMNS:
			var is_water = (grid_water.size() == GRID_ROWS and grid_water[r][nc])
			if is_water:
				grid_water[r][nc] = false
				_spawn_steam_effect(get_cell_position(r, nc))
			else:
				if grid_i[r][nc] != -1:
					ismatched[r][nc] = true
					var has_sp = (special_item.size() == GRID_ROWS and special_item[r][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[r][nc])
					if has_sp and not (Vector2i(r, nc) in exploded_items):
						queue.append(Vector2i(r, nc))

	_check_burn_plants_in_rect(r - r_reach, r + r_reach, c, c, queue, exploded_items)
	_check_burn_plants_in_rect(r, r, c - c_reach, c + c_reach, queue, exploded_items)


func _trigger_tornado(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.TORNADO, 1))
	var half_w: int = 0 # Lv1: 幅1マス (つむじ風)
	if lvl == 2:
		half_w = 1 # Lv2: 幅3マス (疾風竜巻)
	elif lvl >= 3:
		half_w = 2 # Lv3: 幅5マス (天災大竜巻)

	_spawn_tornado_effect(pos, lvl, half_w)

	var hit_plants: Array = []
	for nr in range(r, -1, -1):
		for dc in range(-half_w, half_w + 1):
			var nc = c + dc
			if nc >= 0 and nc < GRID_COLUMNS:
				if grid_water.size() == GRID_ROWS:
					grid_water[nr][nc] = false
				if grid_i[nr][nc] != -1:
					ismatched[nr][nc] = true
					var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
					if has_sp and not (Vector2i(nr, nc) in exploded_items):
						queue.append(Vector2i(nr, nc))

				var plant = _get_plant_at(nr, nc)
				if not plant.is_empty() and not (plant in hit_plants):
					hit_plants.append(plant)

	# つむじ風(Lv1)は木の耐久値-1、竜巻(Lv2以上)は-2
	var tornado_dmg: int = 1 if lvl == 1 else 2
	for p in hit_plants:
		_damage_plant(p, tornado_dmg, "tornado")

func _trigger_lightning(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var lvl: int = max(1, special_levels.get(SpecialItemType.LIGHTNING, 1))
	var target_count: int = 3
	if lvl == 2: target_count = 5
	elif lvl >= 3: target_count = 8

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

	for k in range(mini(target_count, candidates.size())):
		var cp = candidates[k]
		ismatched[cp.x][cp.y] = true
		targets.append(get_cell_position(cp.x, cp.y))
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
	if lvl == 2:
		radius = 2 # Lv2: 5x5
	elif lvl >= 3:
		radius = 3 # Lv3: 7x7

	ismatched[r][c] = true
	_spawn_aqua_splash_effect(pos, radius)

	for dr in range(-radius, radius + 1):
		for dc in range(-radius, radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				if grid_water.size() == GRID_ROWS:
					grid_water[nr][nc] = true

	# 周囲の植物による即時吸水
	for plant in plant_entities.duplicate():
		_process_plant_water_absorption(plant)

	if board_bg:
		board_bg.queue_redraw()

func _trigger_tree_sprout(r: int, c: int, pos: Vector2, _queue: Array, _exploded_items: Dictionary) -> void:
	ismatched[r][c] = true
	_spawn_sprout_effect(pos)
	if _get_plant_at(r, c).is_empty():
		var new_plant: Dictionary = {
			"origin": Vector2i(r, c),
			"stage": 0, # 0: 苗木, 1: 若木, 2: 3x3大木
			"absorbed_water": 0,
			"thunder_hp": 1 # 苗木は1回耐える
		}
		plant_entities.append(new_plant)
		_process_plant_water_absorption(new_plant)
	if board_bg:
		board_bg.queue_redraw()

func _trigger_disco_ball(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var target_att: int = grid_att[r][c]
	if target_att < 0:
		target_att = _get_dominant_attribute()
	var lvl: int = max(1, special_levels.get(SpecialItemType.DISCO_BALL, 1))
	_spawn_disco_effect(pos)

	for nr in range(GRID_ROWS):
		for nc in range(GRID_COLUMNS):
			if grid_att[nr][nc] == target_att and grid_i[nr][nc] != -1:
				ismatched[nr][nc] = true
				if lvl >= 2:
					for dr in [-1, 0, 1]:
						for dc in [-1, 0, 1]:
							var ar = nr + dr
							var ac = nc + dc
							if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS and grid_i[ar][ac] != -1:
								ismatched[ar][ac] = true
				var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
				if has_sp and not (Vector2i(nr, nc) in exploded_items):
					queue.append(Vector2i(nr, nc))

func _trigger_color_converter(r: int, c: int, pos: Vector2, _queue: Array, _exploded_items: Dictionary) -> void:
	var dom_att: int = _get_dominant_attribute()
	var lvl: int = max(1, special_levels.get(SpecialItemType.COLOR_CONVERTER, 1))
	_spawn_paint_effect(pos)
	ismatched[r][c] = true

	var paint_radius: int = 1 if lvl == 1 else 2
	for dr in range(-paint_radius, paint_radius + 1):
		for dc in range(-paint_radius, paint_radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
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
	if lvl == 2: radius = 2
	elif lvl >= 3: radius = 3
	_spawn_black_hole_effect(pos, radius)

	for dr in range(-radius, radius + 1):
		for dc in range(-radius, radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				if grid_i[nr][nc] != -1:
					ismatched[nr][nc] = true
					var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
					if has_sp and not (Vector2i(nr, nc) in exploded_items):
						queue.append(Vector2i(nr, nc))

func _trigger_magnet(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var target_att: int = grid_att[r][c]
	if target_att < 0: target_att = _get_dominant_attribute()
	var lvl: int = max(1, special_levels.get(SpecialItemType.MAGNET, 1))
	var max_pull: int = 4 if lvl == 1 else (8 if lvl == 2 else 999)

	var candidates: Array[Vector2i] = []
	for nr in range(GRID_ROWS):
		for nc in range(GRID_COLUMNS):
			if grid_i[nr][nc] != -1 and grid_att[nr][nc] == target_att and not (nr == r and nc == c):
				candidates.append(Vector2i(nr, nc))
	candidates.shuffle()

	var target_positions: Array[Vector2] = []
	ismatched[r][c] = true
	for k in range(mini(max_pull, candidates.size())):
		var cp = candidates[k]
		ismatched[cp.x][cp.y] = true
		target_positions.append(get_cell_position(cp.x, cp.y))
		var has_sp = (special_item.size() == GRID_ROWS and special_item[cp.x][cp.y] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[cp.x][cp.y])
		if has_sp and not (cp in exploded_items):
			queue.append(cp)

	_spawn_magnet_effect(pos, target_positions)

func _trigger_charge_bomb(r: int, c: int, pos: Vector2, queue: Array, exploded_items: Dictionary) -> void:
	var ch: int = 1
	if special_charge.size() == GRID_ROWS:
		ch = max(1, special_charge[r][c])
	_spawn_mega_explosion_effect(pos, ch)

	var radius: int = ch
	for dr in range(-radius, radius + 1):
		for dc in range(-radius, radius + 1):
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][nc])
				if is_water:
					grid_water[nr][nc] = false
					_spawn_steam_effect(get_cell_position(nr, nc))
				else:
					if grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true
						var has_sp = (special_item.size() == GRID_ROWS and special_item[nr][nc] != SpecialItemType.NONE) or (is_bomb.size() == GRID_ROWS and is_bomb[nr][nc])
						if has_sp and not (Vector2i(nr, nc) in exploded_items):
							queue.append(Vector2i(nr, nc))

func _trigger_gemini_bomb(r: int, c: int, pos: Vector2, _queue: Array, _exploded_items: Dictionary) -> void:
	_spawn_explosion_effect(pos)
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			var nr = r + dr
			var nc = c + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
				var is_water = (grid_water.size() == GRID_ROWS and grid_water[nr][nc])
				if is_water:
					grid_water[nr][nc] = false
					_spawn_steam_effect(get_cell_position(nr, nc))
				else:
					if grid_i[nr][nc] != -1:
						ismatched[nr][nc] = true


	var lvl: int = max(1, special_levels.get(SpecialItemType.GEMINI_BOMB, 1))
	var split_count: int = 2 + (lvl - 1)
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
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var cr = tp.x + dr
				var cc = tp.y + dc
				if cr >= 0 and cr < GRID_ROWS and cc >= 0 and cc < GRID_COLUMNS and grid_i[cr][cc] != -1:
					ismatched[cr][cc] = true

	_spawn_gemini_effect(pos, targets)

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

	if board_bg:
		board_bg.queue_redraw()

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

## 指定マスの駒を盤面から完全に消去（植物占有時等）
func _clear_pieces_in_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if cell.x < 0 or cell.x >= GRID_ROWS or cell.y < 0 or cell.y >= GRID_COLUMNS:
			continue
		if grid_i.size() == GRID_ROWS:
			var idx = grid_i[cell.x][cell.y]
			if idx >= 0 and idx < piece.size() and piece[idx] != null:
				piece[idx].queue_free()
				piece[idx] = null
			if idx >= 0 and idx < piececollid.size() and piececollid[idx] != null:
				piececollid[idx].queue_free()
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
	if board_bg:
		board_bg.queue_redraw()
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
	plant["thunder_hp"] = plant.get("thunder_hp", 1) - dmg
	var org: Vector2i = plant.get("origin", Vector2i(7, 7))
	var p_pos = get_cell_position(org.x, org.y)
	_spawn_plant_damage_effect(p_pos, plant.get("thunder_hp", 0) <= 0)

	if plant["thunder_hp"] <= 0:
		plant_entities.erase(plant)
	if board_bg:
		board_bg.queue_redraw()

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
	if board_bg:
		board_bg.queue_redraw()

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

		if board_bg:
			board_bg.queue_redraw()

	return absorbed_any

## 毎ターンの植物処理（吸水 ＆ マイルド自動回復）
func _process_turn_plants() -> void:
	if plant_entities.is_empty():
		return

	var sm = _get_stage_manager()
	var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))

	# 1. 各植物の吸水成長
	for plant in plant_entities.duplicate():
		_process_plant_water_absorption(plant)

	# 2. 自動回復（プレイヤー植物）または体力ドレイン（敵の植えた苗木・大木）
	var total_heal: float = 0.0
	var enemy_drain_plants: Array[Dictionary] = []

	for plant in plant_entities:
		var st: int = plant.get("stage", 0)
		var org: Vector2i = plant.get("origin", Vector2i(7, 7))

		if plant.get("enemy_planted", false):
			enemy_drain_plants.append(plant)
		else:
			var heal_val: float = 150.0
			if st == 1: heal_val = 350.0
			elif st == 2: heal_val = 800.0
			total_heal += heal_val * stage_scale
			_spawn_heal_number_effect(get_cell_position(org.x, org.y), int(heal_val * stage_scale))

	if sm:
		if total_heal > 0.0:
			sm.calchp(0.0, -total_heal)
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

	sm.calchp(-heal_enemy_amount, total_drain)

	if sm.myhp <= 0:
		var go_node = sm.get_node_or_null("gameover")
		if go_node:
			go_node.position = Vector2.ZERO
		isgameover = true
		interval = 0
		current_state = BoardState.TURN_SEQUENCE
		if selected_cell.x != -1:
			_deselect_piece()
		is_holding = false

	if heal_enemy_amount > 0.0:
		_spawn_enemy_heal_effect(sm, int(heal_enemy_amount))

	# ⑦ 吸収専用効果音の再生
	_play_wood_drain_se()

## 木属性生命吸収専用効果音の再生
func _play_wood_drain_se() -> void:
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	var vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0)) if (sm_autoload and "se_volume" in sm_autoload) else 0.0
	var p = get_parent()
	var target_parent = p if p != null else self

	# 打撃吸収インパクト音
	var s_impact = load("res://Sound/se/teki/utu-2.mp3") as AudioStream
	if s_impact:
		var asp_i = AudioStreamPlayer.new()
		asp_i.stream = s_impact
		asp_i.volume_db = vol
		target_parent.add_child(asp_i)
		asp_i.play()
		asp_i.finished.connect(asp_i.queue_free)

	# 神秘的生命吸収ループ音
	var s_drain = load("res://Sound/ゲージ回復2.mp3") as AudioStream
	if s_drain:
		var asp_d = AudioStreamPlayer.new()
		asp_d.stream = s_drain
		asp_d.volume_db = vol
		asp_d.pitch_scale = 0.95
		target_parent.add_child(asp_d)
		asp_d.play()
		asp_d.finished.connect(asp_d.queue_free)

## 植物マス上の体力吸収ポップアップ（「吸血 -〇〇〇」）
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
	target_parent.add_child(rtl)

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
		target_parent.add_child(dot)

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
			root_node.add_child(stream1)
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
			root_node.add_child(stream2)
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
	target_parent.add_child(rtl)

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
	var base_scale: Vector2 = enemy_sp.get_meta("base_scale", Vector2(0.5, 0.5))

	# 敵の緑色生命力パルス発光
	var tw_pulse = create_tween()
	tw_pulse.tween_property(enemy_sp, "modulate", Color(0.4, 2.2, 0.8, 1.0), 0.18)
	tw_pulse.parallel().tween_property(enemy_sp, "scale", base_scale * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pulse.tween_property(enemy_sp, "modulate", Color.WHITE, 0.3)
	tw_pulse.parallel().tween_property(enemy_sp, "scale", base_scale, 0.3)

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
	target_parent.add_child(rtl)

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
		target_parent.add_child(spark)

		var tw_s = create_tween()
		tw_s.tween_property(spark, "position:y", spark.position.y - randf_range(60, 110), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_s.parallel().tween_property(spark, "scale", Vector2.ZERO, 0.6)
		tw_s.chain().tween_callback(spark.queue_free)

## 汎用ショックウェーブリング（衝撃波リング演出）
func _spawn_shockwave_ring(pos: Vector2, color: Color, max_radius: float, duration: float = 0.3) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
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
	effects_parent.add_child(ring)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(max_radius / 10.0, max_radius / 10.0), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "width", 3.0, duration)
	tw.chain().tween_callback(ring.queue_free)

## 汎用全画面フラッシュ
func _spawn_screen_flash(color: Color, duration: float = 0.08) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
	var flash = ColorRect.new()
	flash.size = Vector2(40000.0, 40000.0)
	flash.position = Vector2(-20000.0, -20000.0)
	flash.color = color
	flash.z_index = 40
	effects_parent.add_child(flash)

	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, duration)
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
	parent.add_child(glow)

	var bolt = Line2D.new()
	bolt.points = pts
	bolt.width = bolt_w
	bolt.default_color = bolt_color
	bolt.joint_mode = Line2D.LINE_JOINT_BEVEL
	bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.z_index = z + 1
	parent.add_child(bolt)

	var core = Line2D.new()
	core.points = pts
	core.width = core_w
	core.default_color = core_color
	core.joint_mode = Line2D.LINE_JOINT_BEVEL
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	core.z_index = z + 2
	parent.add_child(core)

	return [glow, bolt, core]

## 剣命中時の斬撃十字スパーク演出
func _spawn_hit_spark(hit_pos: Vector2) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

	for slash_dir in [-1.0, 1.0]:
		var slash = Line2D.new()
		slash.width = 14.0
		slash.default_color = Color(1.0, 0.95, 0.4, 0.98)
		slash.z_index = 35
		var p1 = hit_pos + Vector2(-140.0 * slash_dir, -140.0)
		var p2 = hit_pos + Vector2(140.0 * slash_dir, 140.0)
		slash.points = PackedVector2Array([p1, p2])
		effects_parent.add_child(slash)

		var tw_sl = create_tween().set_parallel(true)
		tw_sl.tween_property(slash, "width", 0.0, 0.14)
		tw_sl.tween_property(slash, "modulate:a", 0.0, 0.14)
		tw_sl.chain().tween_callback(slash.queue_free)

	_spawn_shockwave_ring(hit_pos, Color(1.0, 0.85, 0.2, 0.9), 180.0, 0.16)

## 爆発演出（白熱スターフラッシュ、二重火炎球、火炎衝撃波リング、飛散火の粉パーティクル）
func _spawn_explosion_effect(pos: Vector2) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
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
	effects_parent.add_child(star)

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
		effects_parent.add_child(flame)

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
		effects_parent.add_child(ember)

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

## 十字クロス爆砕エフェクト（高エネルギーレーザービーム ＆ スターフレア）
func _spawn_cross_effect(pos: Vector2, _lvl: int) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
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
	effects_parent.add_child(star)

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
		effects_parent.add_child(beam_aura)

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
		effects_parent.add_child(beam_core)

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
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
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
		effects_parent.add_child(ray)

		var tw_r = create_tween().set_parallel(true)
		tw_r.tween_property(ray, "width", 0.0, 0.38)
		tw_r.tween_property(ray, "modulate:a", 0.0, 0.38)
		tw_r.chain().tween_callback(ray.queue_free)

	for i in range(25):
		_spawn_burst_particles(pos, randi() % 5)

## ペンキ同色染め上げエフェクト（広がるインクスプラッシュ波紋）
func _spawn_paint_effect(pos: Vector2) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

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
	effects_parent.add_child(wave)

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
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

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
		effects_parent.add_child(s_line)
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
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
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
	effects_parent.add_child(disk)

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
	effects_parent.add_child(void_core)

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
		effects_parent.add_child(part)

		var tw_p = create_tween().set_parallel(true)
		tw_p.tween_property(part, "position", pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_p.tween_property(part, "scale", Vector2.ZERO, 0.42)
		tw_p.chain().tween_callback(part.queue_free)

	tw.chain().tween_property(disk, "scale", Vector2.ZERO, 0.12)
	tw.parallel().tween_property(void_core, "scale", Vector2.ZERO, 0.12)
	tw.chain().tween_callback(disk.queue_free)
	tw.parallel().tween_callback(void_core.queue_free)

## マグネットエフェクト（対象から中心への磁力線）
func _spawn_magnet_effect(center_pos: Vector2, targets: Array[Vector2]) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
	_trigger_screen_shake(30.0)

	for t_pos in targets:
		var line = Line2D.new()
		line.default_color = Color(1.0, 0.3, 0.1, 0.85)
		line.width = 14.0
		line.z_index = 28
		line.add_point(t_pos)
		line.add_point(center_pos)
		effects_parent.add_child(line)

		var tw = create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.25)
		tw.tween_callback(line.queue_free)

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
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

	for t_pos in targets:
		var spark = Polygon2D.new()
		spark.polygon = PackedVector2Array([
			Vector2(0, -22), Vector2(16, 0), Vector2(0, 22), Vector2(-16, 0)
		])
		spark.color = Color(1.0, 0.6, 0.1, 1.0)
		spark.position = start_pos
		spark.z_index = 32
		effects_parent.add_child(spark)

		var tw = create_tween()
		tw.tween_property(spark, "position", t_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			_spawn_explosion_effect(t_pos)
			spark.queue_free()
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
		life_time += delta
		if life_time >= duration:
			queue_free()
			return

		var p: float = clampf(life_time / duration, 0.0, 1.0)
		# 上昇移動 (イーズアウト)
		var rise_t: float = 1.0 - pow(1.0 - p, 2.2)
		position.y = lerpf(start_pos.y, target_top_y, rise_t)
		queue_redraw()

	func _draw() -> void:
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

## 竜巻・つむじ風エフェクト（高速回転サイクロンファンネル ＆ 旋回風刃 ＆ 渦巻き木の葉）
func _spawn_tornado_effect(pos: Vector2, lvl: int, half_w: int) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
	_trigger_screen_shake(35.0 + lvl * 10.0)

	var sound = get_node_or_null("AudioStreamPlayer")
	if sound:
		sound.pitch_scale = 1.45
		sound.play()

	var width_px = (half_w * 2 + 1) * CELL_PITCH
	var target_top_y = get_cell_position(0, 0).y - CELL_PITCH * 2.5

	var vortex = TornadoVortexNode.new(pos, target_top_y, width_px, lvl)
	effects_parent.add_child(vortex)

## 水しぶき・アクアスプラッシュ演出（同心円波紋 ＆ 重力水滴放物線スプラッシュ ＆ ミスト）
func _spawn_aqua_splash_effect(pos: Vector2, radius: int) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
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
		effects_parent.add_child(drop)

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
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

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
	effects_parent.add_child(mandala)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(mandala, "scale", Vector2(1.4, 1.4), 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mandala, "rotation", TAU * 0.5, 0.36)
	tw.tween_property(mandala, "modulate:a", 0.0, 0.36)
	tw.chain().tween_callback(mandala.queue_free)

## 水たまり電撃伝導演出（感電水路ネットワーク）
func _spawn_water_electric_effect(cells: Array[Vector2i]) -> void:
	if cells.is_empty(): return
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
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
		effects_parent.add_child(aura)

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
			effects_parent.add_child(sp_line)
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
				effects_parent.add_child(arc_line)
				var tw_arc = create_tween()
				tw_arc.tween_interval(0.20)
				tw_arc.tween_property(arc_line, "modulate:a", 0.0, 0.28)
				tw_arc.tween_callback(arc_line.queue_free)

## 植物の成長進化演出（天空を貫く神聖エメラルド光柱 ＆ 螺旋光粒子）
func _spawn_growth_effect(pos: Vector2, _stage: int) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self
	_trigger_screen_shake(32.0)

	# 1. 天空光柱（純白コア ＋ エメラルドオーラ）
	var pillar_aura = ColorRect.new()
	pillar_aura.size = Vector2(280.0, 2500.0)
	pillar_aura.pivot_offset = Vector2(140.0, 2500.0)
	pillar_aura.position = pos - pillar_aura.pivot_offset
	pillar_aura.color = Color(0.2, 1.0, 0.5, 0.70)
	pillar_aura.z_index = 32
	effects_parent.add_child(pillar_aura)

	var pillar_core = ColorRect.new()
	pillar_core.size = Vector2(80.0, 2500.0)
	pillar_core.pivot_offset = Vector2(40.0, 2500.0)
	pillar_core.position = pos - pillar_core.pivot_offset
	pillar_core.color = Color(1.0, 1.0, 0.8, 0.95)
	pillar_core.z_index = 33
	effects_parent.add_child(pillar_core)

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
		effects_parent.add_child(star)

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
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

	for i in range(12):
		var leaf = Polygon2D.new()
		leaf.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(10, 0), Vector2(0, 16), Vector2(-10, 0)
		])
		leaf.color = Color(0.2, randf_range(0.7, 0.9), 0.3, 0.95)
		leaf.position = pos
		leaf.z_index = 31
		effects_parent.add_child(leaf)

		var angle = randf() * TAU
		var dist = randf_range(180.0, 400.0)
		var l_tw = create_tween().set_parallel(true)
		l_tw.tween_property(leaf, "position", pos + Vector2(cos(angle), sin(angle)) * dist, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		l_tw.tween_property(leaf, "rotation", randf_range(-PI * 2.0, PI * 2.0), 0.35)
		l_tw.tween_property(leaf, "scale", Vector2.ZERO, 0.35)
		l_tw.tween_property(leaf, "modulate:a", 0.0, 0.35)
		l_tw.chain().tween_callback(leaf.queue_free)

## 植物回復ポップアップ数値演出（緑の「+〇〇〇」）
func _spawn_heal_number_effect(pos: Vector2, amount: int) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

	var lbl = Label.new()
	lbl.text = "+%d" % amount
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.position = pos - Vector2(100.0, 60.0)
	lbl.z_index = 35
	effects_parent.add_child(lbl)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 160.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

## マッチした駒の破砕クリスタルシャード演出（属性別宝石カット多角形 ＆ スパークル光芒）
func _spawn_burst_particles(origin: Vector2, kind: int) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

	var colors = [
		Color(0.2, 0.9, 1.0),   # SHIELD: サファイアクリスタルシアン
		Color(1.0, 0.25, 0.25),  # SWORD: ルビーバーニングレッド
		Color(1.0, 0.88, 0.15),  # COIN: トパーズゴールド
		Color(1.0, 0.3, 0.9),    # POTION: アメジストネオンマゼンタ
		Color(0.45, 1.0, 0.2)    # FOOD: エメラルドエナジーライム
	]
	var base_color = colors[clampi(kind % 5, 0, 4)]
	var shard_count = 10

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
		effects_parent.add_child(shard)

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

	if has_highlights:
		await tween.finished
	else:
		tween.kill()
	_start_breaking_animation()

## マッチした駒の破砕バースト・フェード消滅演出（すべて消えるまで待機）
func _start_breaking_animation() -> void:
	current_state = BoardState.BREAKING

	# スコア計算
	var copy_matched = ismatched.duplicate(true)
	var sm = _get_score_manager()
	if sm and sm.has_method("calcscore"):
		sm.calcscore(copy_matched, grid_att)

	# 画面微細シェイクを発生（適度な振動に抑える）
	if matched_cells_list.size() > 0:
		_trigger_screen_shake(10.0 + minf(float(matched_cells_list.size()) * 1.0, 15.0))

	# 1. 帯電コマ・呪いコマの反動ダメージ処理
	var stage_mgr = _get_stage_manager()
	for cell in matched_cells_list:
		if grid_electrified.size() == GRID_ROWS and grid_electrified[cell.x][cell.y]:
			grid_electrified[cell.x][cell.y] = false
			if stage_mgr:
				var shock_dmg = minf(stage_mgr.myhpmax * 0.05, 300.0) if stage_mgr.myhpmax > 0 else 300.0
				stage_mgr.calchp(0.0, shock_dmg)
			_spawn_shock_zap_effect(get_cell_position(cell.x, cell.y))

		if grid_cursed.size() == GRID_ROWS and grid_cursed[cell.x][cell.y]:
			grid_cursed[cell.x][cell.y] = false
			if stage_mgr:
				var curse_dmg = minf(stage_mgr.myhpmax * 0.08, 500.0) if stage_mgr.myhpmax > 0 else 500.0
				stage_mgr.calchp(0.0, curse_dmg)
			_spawn_curse_burst_effect(get_cell_position(cell.x, cell.y))

	# 2. 隣接マッチによる氷割れ・石破壊・黄金像耐久減算・黒い霧解除
	var adj_dirs = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for cell in matched_cells_list:
		for d in adj_dirs:
			var ar = cell.x + d.x
			var ac = cell.y + d.y
			if ar >= 0 and ar < GRID_ROWS and ac >= 0 and ac < GRID_COLUMNS:
				if grid_ice.size() == GRID_ROWS and int(grid_ice[ar][ac]) > 0:
					grid_ice[ar][ac] = int(grid_ice[ar][ac]) - 1
					_spawn_ice_break_effect(get_cell_position(ar, ac))
				if grid_stones.size() == GRID_ROWS and grid_stones[ar][ac] > 0:
					grid_stones[ar][ac] -= 1
					if grid_stones[ar][ac] <= 0:
						_spawn_stone_break_effect(get_cell_position(ar, ac))
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[ar][ac] > 0:
					grid_gold_statue[ar][ac] -= 1
					if grid_gold_statue[ar][ac] <= 0:
						_spawn_gold_shatter_effect(get_cell_position(ar, ac))
						if sm and "totalScore" in sm:
							sm.totalScore += 500

		# 黒い霧内のマッチによる霧晴れ判定
		var f_idx = grid_fog.size() - 1
		while f_idx >= 0:
			var f_rect: Rect2i = grid_fog[f_idx].get("rect", Rect2i(-1, -1, 0, 0))
			if f_rect.has_point(cell):
				grid_fog[f_idx]["turns"] -= 1
				if grid_fog[f_idx]["turns"] <= 0:
					grid_fog.remove_at(f_idx)
			f_idx -= 1

	var has_breaking: bool = false
	var tween = create_tween().set_parallel(true)

	for cell in matched_cells_list:
		var idx = grid_i[cell.x][cell.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			has_breaking = true
			var p = piece[idx]
			var kind = grid_n[cell.x][cell.y]

			# 放射状破片パーティクルを生成
			_spawn_burst_particles(p.position, kind)

			# コマ自体のポップ＆バースト消滅
			var rand_rot = randf_range(-0.4, 0.4)
			tween.tween_property(p, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(p, "rotation", rand_rot, 0.18)
			tween.tween_property(p, "modulate:a", 0.0, 0.18)

			# 右側のステータス枠に向かって飛ぶエフェクト（確実に属性に対応したテクスチャを使用）
			var fly_sprite: Sprite2D = Sprite2D.new()
			fly_sprite.texture = PIECE_TEXTURES[clampi(kind % 5, 0, 4)]
			fly_sprite.position = p.position
			fly_sprite.scale = cellsize
			fly_sprite.rotation = 0.0
			fly_sprite.modulate = Color.WHITE
			add_child(fly_sprite)
			flying_cells.append({
				"node": fly_sprite,
				"kind": kind
			})

	# 「すべてが消えるまで待つ」
	if has_breaking:
		await tween.finished
	else:
		tween.kill()

	# スプライトを破棄し、マスを空にする
	for cell in matched_cells_list:
		var idx = grid_i[cell.x][cell.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			piece[idx].queue_free()
			piece[idx] = null
		if idx >= 0 and idx < piececollid.size() and piececollid[idx] != null:
			piececollid[idx].queue_free()
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
		if grid_cursed.size() == GRID_ROWS:
			grid_cursed[cell.x][cell.y] = false

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
		"is_obstacle": _is_plant_cell(r, c) or (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0) or (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0),
		"is_electrified": false,
		"is_cursed": false,
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
			var is_water: bool = (grid_water.size() == GRID_ROWS and grid_water[r][c])
			var is_ice: bool = (grid_ice.size() == GRID_ROWS and grid_ice[r][c])
			var is_tree: bool = _is_plant_cell(r, c)
			var is_stone: bool = (grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0)
			var is_gold_statue: bool = (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0)
			var is_electrified: bool = (grid_electrified.size() == GRID_ROWS and grid_electrified[r][c])
			var is_cursed: bool = (grid_cursed.size() == GRID_ROWS and grid_cursed[r][c])

			var is_locked: bool = (is_water and p_idx != -1) or (is_ice and p_idx != -1)
			var is_obstacle: bool = is_tree or is_stone or is_gold_statue

			row_sim.append({
				"p_idx": p_idx,
				"kind": (grid_n[r][c] if grid_n.size() == GRID_ROWS else 0) if p_idx != -1 else -1,
				"att": (grid_att[r][c] if grid_att.size() == GRID_ROWS else 0) if p_idx != -1 else -1,
				"sp_item": special_item[r][c] if special_item.size() == GRID_ROWS and p_idx != -1 else 0,
				"sp_charge": special_charge[r][c] if special_charge.size() == GRID_ROWS and p_idx != -1 else 0,
				"is_bomb": is_bomb[r][c] if is_bomb.size() == GRID_ROWS and p_idx != -1 else false,
				"is_water_locked": (is_water and p_idx != -1),
				"is_locked": is_locked,
				"is_obstacle": is_obstacle,
				"is_electrified": is_electrified,
				"is_cursed": is_cursed,
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
						sim_grid[r + 1][c] = cell
						sim_grid[r][c] = _make_empty_sim_cell(r, c)
						any_movement = true

		# B. 上空からの新規生成 (Top Spawn Pass)
		for c in range(GRID_COLUMNS):
			var cell = sim_grid[0][c]
			if cell.p_idx == -1 and not cell.get("is_obstacle", false):
				var nval: int = randi() % CELL_KINDS
				var spawned_sp: int = _roll_falling_special()
				var sp_ch: int = 1 if spawned_sp == SpecialItemType.CHARGE_BOMB else 0
				var is_b: bool = (spawned_sp != SpecialItemType.NONE)
				var spawn_count = spawn_counts_per_col[c]
				spawn_counts_per_col[c] += 1

				var spawn_item = {
					"p_idx": -2, # 新規フラグ
					"kind": nval,
					"att": nval % 5,
					"sp_item": spawned_sp,
					"sp_charge": sp_ch,
					"is_bomb": is_b,
					"is_water_locked": false,
					"is_locked": false,
					"is_obstacle": false,
					"is_electrified": false,
					"is_cursed": false,
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
		add_child(new_sprite)
		piece.append(new_sprite)

		if collid_template and area_node:
			var new_collid = collid_template.duplicate()
			new_collid.position = spawn_item.start_pos
			area_node.add_child(new_collid)
			piececollid.append(new_collid)

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
				continue

			var p_idx: int = final_cell.p_idx
			if grid_i.size() == GRID_ROWS: grid_i[r][c] = p_idx
			if grid_n.size() == GRID_ROWS: grid_n[r][c] = final_cell.kind
			if grid_att.size() == GRID_ROWS: grid_att[r][c] = final_cell.att
			if is_bomb.size() == GRID_ROWS:
				is_bomb[r][c] = final_cell.is_bomb
			if special_item.size() == GRID_ROWS:
				special_item[r][c] = final_cell.sp_item
			if special_charge.size() == GRID_ROWS:
				special_charge[r][c] = final_cell.sp_charge
			if grid_electrified.size() == GRID_ROWS:
				grid_electrified[r][c] = final_cell.get("is_electrified", false)
			if grid_cursed.size() == GRID_ROWS:
				grid_cursed[r][c] = final_cell.get("is_cursed", false)


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
		_check_cascade()

## 落下中の重力・斜めスライド物理更新 (毎フレーム)
func _update_falling_physics(delta: float) -> void:
	var all_landed: bool = true

	for item in falling_pieces:
		if item["landed"]:
			continue

		all_landed = false
		var s: Sprite2D = item["sprite"]
		var waypoints: Array[Vector2] = item["waypoints"]
		var wp_idx: int = item["wp_idx"]
		var target_pos: Vector2 = waypoints[wp_idx]
		var start_pos: Vector2 = item["current_start_pos"]

		item["velocity_y"] = minf(item["velocity_y"] + GRAVITY * delta, MAX_FALL_SPEED)
		var dy = item["velocity_y"] * delta

		if target_pos.y > start_pos.y:
			s.position.y += dy
			var total_dy = target_pos.y - start_pos.y
			var t = clampf((s.position.y - start_pos.y) / maxf(1.0, total_dy), 0.0, 1.0)
			s.position.x = lerpf(start_pos.x, target_pos.x, t)

			if s.position.y >= target_pos.y:
				s.position = target_pos
				item["wp_idx"] += 1
				if item["wp_idx"] < waypoints.size():
					item["current_start_pos"] = target_pos
				else:
					item["landed"] = true
					var bounce_tween = create_tween()
					bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
					bounce_tween.tween_property(s, "scale", cellsize, 0.08)
		else:
			var speed_h = 7500.0 * delta
			s.position = s.position.move_toward(target_pos, speed_h)
			if s.position.distance_to(target_pos) < 4.0:
				s.position = target_pos
				item["wp_idx"] += 1
				if item["wp_idx"] < waypoints.size():
					item["current_start_pos"] = target_pos
				else:
					item["landed"] = true
					var bounce_tween = create_tween()
					bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
					bounce_tween.tween_property(s, "scale", cellsize, 0.08)

	if all_landed:
		falling_pieces.clear()
		_check_cascade()


## 落下後の連鎖判定
func _check_cascade() -> void:
	current_state = BoardState.CASCADE_CHECK

	var has_match = _check_matches_exist()
	if has_match:
		_check_and_trigger_bomb_reactions()
		_start_match_highlight()
	else:
		# 盤面が安定したらターン演出へ
		current_state = BoardState.TURN_SEQUENCE
		endbreak = true
		interval = 0

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
			if grid_i[i][j] != -1 and grid_i[i][j] in old_to_new:
				grid_i[i][j] = old_to_new[grid_i[i][j]]

	piece = remaining_pieces
	piececollid = remaining_collids

# --- 戦闘・エフェクト処理群 (バグ修正済み) ---

func _process(delta: float) -> void:
	var sm = _get_stage_manager()
	var score_mgr = _get_score_manager()

	# 落下アニメーション中の物理更新
	if current_state == BoardState.FALLING:
		_update_falling_physics(delta)

	# マウス操作中の追従 (盤面枠内に安全にクランプしつつマウス位置に追従)
	if selected_piece_idx >= 0 and selected_piece_idx < piece.size() and piece[selected_piece_idx] != null:
		var local_mouse = to_local(get_global_mouse_position())
		local_mouse.x = clampf(local_mouse.x, 4250.0, 11750.0)
		local_mouse.y = clampf(local_mouse.y, 1250.0, 8750.0)
		piece[selected_piece_idx].position = local_mouse

	# 戦闘演出ターンおよび発射物シミュレーションのゲーム速度連動
	var spd: float = maxf(0.1, _get_game_speed())
	_turn_sim_accumulator += spd
	var sim_steps: int = 0
	while _turn_sim_accumulator >= 1.0 and sim_steps < 16:
		_turn_sim_accumulator -= 1.0
		sim_steps += 1

		# ステージクリア時または敵死亡時の演出停止
		if sm and (sm.isstageclear or sm.isdeadf):
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
			_update_all_projectiles()
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

	# 特殊アイテムマークの再描画更新
	if mark_overlay:
		mark_overlay.queue_redraw()

	# 特殊アイテムマスの点滅・脈動演出
	if (is_bomb.size() == GRID_ROWS or special_item.size() == GRID_ROWS):
		var time_pulse = 0.80 + 0.30 * sin(Time.get_ticks_msec() * 0.008)
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
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
							SpecialItemType.MAGNET: glow_color = Color(1.8, 0.6, 0.2, 1.0)
							SpecialItemType.CHARGE_BOMB: glow_color = Color(2.0, 0.3, 0.1, 1.0)
							SpecialItemType.GEMINI_BOMB: glow_color = Color(1.8, 0.8, 0.2, 1.0)
						piece[p_idx].modulate = glow_color * time_pulse
					elif not ismatched[r][c] and (selected_piece_idx != p_idx):
						if piece[p_idx].modulate != Color.WHITE:
							piece[p_idx].modulate = Color.WHITE


## 特殊アイテムシンボルマーク専用描画ノード
class SpecialMarkOverlayNode extends Node2D:
	var board: Node2D = null

	func _draw() -> void:
		if board != null and is_instance_valid(board):
			board._draw_special_item_marks_on_overlay(self)

## 特殊アイテムのシンプルシンボルマーク（雷マーク⚡・爆弾マーク💣・苗木マーク🌱等）の一括描画
func _draw_special_item_marks_on_overlay(overlay: Node2D) -> void:
	if overlay == null or grid_i.size() != GRID_ROWS:
		return

	var time_pulse = 0.95 + 0.05 * sin(Time.get_ticks_msec() * 0.007)

	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
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
				_draw_single_special_mark(overlay, center, sp_type, s_factor * time_pulse, alpha, r, c)

## 個別のシンプルシンボルマーク描画（複雑にせず単純で直感的にわかりやすい幾何学マーク）
func _draw_single_special_mark(overlay: Node2D, center: Vector2, sp_type: int, s: float, alpha: float, r: int, c: int) -> void:
	if overlay == null or s <= 0.05 or alpha <= 0.01:
		return

	var badge_r: float = 95.0 * s

	# 1. 視認性を保証する背面の半透明ダークサークルプレート
	overlay.draw_circle(center, badge_r, Color(0.06, 0.08, 0.12, 0.85 * alpha))

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

		SpecialItemType.MAGNET: # 10: マグネット（🧲赤青U字磁石）
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color(1.0, 0.4, 0.1, alpha), 9.0 * s)
			overlay.draw_arc(center + Vector2(0, 8) * s, 30.0 * s, 0, PI, 16, Color(0.65, 0.65, 0.7, alpha), 12.0 * s)
			overlay.draw_line(center + Vector2(-30, 8) * s, center + Vector2(-30, -30) * s, Color(1.0, 0.2, 0.2, alpha), 12.0 * s)
			overlay.draw_line(center + Vector2(30, 8) * s, center + Vector2(30, -30) * s, Color(0.2, 0.4, 1.0, alpha), 12.0 * s)

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

		_:
			overlay.draw_arc(center, badge_r, 0, TAU, 32, Color.WHITE, 8.0 * s)
			overlay.draw_circle(center, 30.0 * s, Color.WHITE)


## 剣の発射物アニメーション (通過判定によるダメージすり抜けバグ完全解消)
func moveswords() -> void:
	var remaining: Array[Dictionary] = []
	var sm = _get_stage_manager()

	for item in flying_swords:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		var rnd: float = item["rnd"]

		if t >= 0:
			s.position.x += 10.0 + rnd
			s.position.y = -pow(t, 2) + 5200.0

		if s.position.y <= 2700.0 and not item.get("has_hit", false):
			item["has_hit"] = true
			if sm:
				var dmg: float = item.get("damage", 100.0 * swordt)
				sm.calchp(dmg, 0)
				if sm.enemy != null:
					sm.enemy.modulate.r += 50.0
			_spawn_hit_spark(s.position)
			var se = get_node_or_null("AudioStreamPlayer")
			if se: se.play()

		item["t"] = t + 1.0

		if s.position.y <= -300.0:
			s.queue_free()
		else:
			remaining.append(item)

	flying_swords = remaining

## 展開シールドのアニメーション
func moveshields() -> void:
	var remaining: Array[Dictionary] = []
	for item in active_shields:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		var target_p: Vector2 = item["target_p"]
		var v: Vector2 = item["v"]

		if t >= 0:
			s.position.x = min(target_p.x, 12300.0 + v.x * t * 10.0)
			s.position.y = max(target_p.y, 4800.0 - v.y * t * 10.0)

		if s.position.distance_to(target_p) < 20.0 and not item["has_arrived"]:
			item["has_arrived"] = true
			s.position = target_p
			_spawn_shockwave_ring(target_p, Color(0.3, 0.9, 1.0, 0.8), 80.0, 0.22)
			var se = get_node_or_null("shieldmove")
			if se: se.play()

		item["t"] = t + 1.0
		remaining.append(item)
	active_shields = remaining

## 食料のアニメーション
func movefoods() -> void:
	var remaining: Array[Dictionary] = []
	var sm = _get_stage_manager()

	for item in flying_foods:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		var rnd: float = item["rnd"]

		if t >= 0:
			s.position.x += 10.0 + rnd
			s.position.y = -pow(t, 2) + 6800.0

		item["t"] = t + 1.0

		if s.position.y <= 5000.0:
			if sm: sm.calchp(0, -100.0)
			var p = get_parent()
			var se = p.get_node_or_null("kaihuku") if p else null
			if se: se.play()
			s.queue_free()
		else:
			remaining.append(item)

	flying_foods = remaining

## ポーションのアニメーション
func movepotions() -> void:
	var remaining: Array[Dictionary] = []
	var sm = _get_stage_manager()

	for item in flying_potions:
		if not is_instance_valid(item.get("node")):
			continue
		var s: Sprite2D = item["node"]
		var t: float = item["t"]
		var rnd: float = item["rnd"]

		if t >= 0:
			s.position.x += 10.0 + rnd
			s.position.y = -pow(t, 2) + 6800.0

		item["t"] = t + 1.0

		if s.position.y <= 5000.0:
			if sm: sm.calcgage(100.0)
			var p = get_parent()
			var se = p.get_node_or_null("potion") if p else null
			if se: se.play()
			s.queue_free()
		else:
			remaining.append(item)

	flying_potions = remaining

## 消滅した駒が右側のステータス枠へ吸い込まれるアニメーション（高速・キビキビ吸入）
func movecell() -> void:
	var remaining: Array[Dictionary] = []
	var target_ys = [4600.0, 5100.0, 5600.0, 6100.0, 6600.0]

	for item in flying_cells:
		var s: Sprite2D = item["node"]
		var kind: int = clampi(item["kind"] % 5, 0, 4)
		var dest_y: float = target_ys[kind]

		var dist_x: float = 12100.0 - s.position.x
		var speed_x: float = maxf(450.0, dist_x * 0.28)
		s.position.x += minf(speed_x, dist_x)

		var dist_y: float = absf(dest_y - s.position.y)
		var speed_y: float = maxf(160.0, dist_y * 0.28)
		s.position.y = move_toward(s.position.y, dest_y, speed_y)

		if s.position.x >= 12100.0 and absf(s.position.y - dest_y) < 25.0:
			s.queue_free()
		else:
			remaining.append(item)

	flying_cells = remaining

func _update_all_projectiles() -> void:
	movecell()
	moveswords()
	moveshields()
	movefoods()
	movepotions()

## ターン進行の演出シーケンス
func _handle_turn_sequence(sm: Node2D, score_mgr: Node2D) -> void:
	if isgameover:
		_handle_gameover_sequence(sm)
		return

	# ターン開始時（interval == 0）に、実際に発射物・アクションが発生するかを厳密に判定
	if interval == 0:
		has_enemy_attacked = false
		isattack = 0
		isblock = 0
		if score_mgr:
			var s_cnt = min(int((sm.ehp if sm else 0) / swordt), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))
			var stage_idx = sm.stage - 1 if sm else 0
			var max_heal = 50 * int(pow(10, stage_idx)) - int((sm.myhp if sm else 0) / (foodt * 100.0))
			var f_cnt = min(max_heal, int(score_mgr.divscore[PieceType.FOOD] / (foodt * 100.0)))
			var max_gage = 70 - int((sm.fevergage if sm else 0) / (100.0 * potiont))
			var p_cnt = min(max_gage, int(score_mgr.divscore[PieceType.POTION] / (potiont * 100.0)))
			if s_cnt > 0 or (f_cnt > 0 and sm and sm.myhp < sm.myhpmax) or (p_cnt > 0 and sm and sm.fevergage < 5000.0):
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

		# 待機時間を一切挟まず、即座に敵が攻撃（スキル発動時は演出確認のため待機時間をしっかり確保）
		var end_wait_fast = 95 if is_casting_skill_turn else 14
		if interval == 0:
			var anten = get_node_or_null("anten")
			if anten: anten.play()
			_set_enemy_attack_motion(sm, true)
		elif interval == 4:
			_execute_enemy_attack(sm)
		elif interval == 10:
			_set_enemy_attack_motion(sm, false)
		elif interval == end_wait_fast:
			if sm and not sm.isfevertime:
				sm.fevertime()
		elif interval > end_wait_fast:
			_reset_turn(sm, score_mgr)
			current_state = BoardState.IDLE
			return
		interval += 1
		return

	# --- 行動が発生する場合の通常のタイムライン ---
	# 効果音の再生
	if interval == 0:
		var anten = get_node_or_null("anten")
		if anten: anten.play()

	if interval < BOUNCE_TOTAL_FRAMES:
		# 以前の上下放物線バウンド挙動に復元し、テンポよく大幅に高速化 (12フレーム/周期 x 3回)
		var t_in_cycle: float = float(interval % BOUNCE_CYCLE_FRAMES)
		var half: float = float(BOUNCE_CYCLE_FRAMES) / 2.0
		# 放物線: t=0で0, t=6で-BOUNCE_HEIGHT, t=12で0
		var hop_y: float = ((t_in_cycle - half) * (t_in_cycle - half) * (BOUNCE_HEIGHT / (half * half))) - BOUNCE_HEIGHT

		if score_mgr:
			for i in range(5):
				var lbl = score_mgr.get_node_or_null("score" + str(i))
				if lbl:
					lbl.position.x = SCORE_LABEL_BASE_X
					lbl.position.y = SCORE_LABEL_BASE_Y + SCORE_LABEL_PITCH * i + hop_y
					lbl.scale = SCORE_LABEL_BASE_SCALE
					lbl.modulate = Color.WHITE
	else:
		# バウンド終了後および攻撃フェーズ中は、初期位置・通常スケール・白色に復帰固定
		_restore_score_label_positions()

	# 攻撃・防御・敵ターンのタイムライン（BOUNCE_TOTAL_FRAMES を基準にテンポよく進行）
	var base_time: int = BOUNCE_TOTAL_FRAMES

	if interval == base_time + 1 and isattack:
		_spawn_attack_projectiles(sm, score_mgr)

	elif interval <= base_time + 144 and isattack:
		# 敵が撃破された場合、残存発射物の着地完了後に即座にターン終了（無駄な待機・シールド・死んだ敵の攻撃を完全カット）
		if sm and (sm.isdeadf or (sm.enemy == null and sm.ehp <= 0)):
			if flying_swords.is_empty() and flying_foods.is_empty() and flying_potions.is_empty():
				_reset_turn(sm, score_mgr)
				current_state = BoardState.IDLE
				return
		# 攻撃発射物が全数着地済みなら、長すぎる144フレームの空き時間をスキップして速やかに次フェーズへ
		if interval >= base_time + 10 and flying_swords.is_empty() and flying_foods.is_empty() and flying_potions.is_empty():
			interval = base_time + 144

	elif interval == base_time + 1 + 144 * isattack and isblock:
		_spawn_shield_projectiles(score_mgr)

	elif interval <= base_time + 56 + 144 * isattack and isblock:
		pass

	elif interval < base_time + 1 + 144 * isattack + 128 * isblock:
		# シールド展開が完了していれば、長すぎる空き時間をスキップして速やかに敵ターンへ
		if interval > base_time + 35 + 144 * isattack and isblock:
			var all_arrived: bool = true
			for it in active_shields:
				if not it.get("has_arrived", false):
					all_arrived = false
					break
			if all_arrived:
				interval = base_time + 144 * isattack + 128 * isblock

	elif interval == base_time + 1 + 144 * isattack + 128 * isblock:
		_set_enemy_attack_motion(sm, true)

	elif interval == base_time + 13 + 144 * isattack + 128 * isblock:
		_execute_enemy_attack(sm)

	elif interval == base_time + 30 + 144 * isattack + 128 * isblock:
		_set_enemy_attack_motion(sm, false)

	elif interval == base_time + (125 if is_casting_skill_turn else 52) + 144 * isattack + 128 * isblock:
		if sm and not sm.isfevertime:
			sm.fevertime()

	elif interval > base_time + (125 if is_casting_skill_turn else 52) + 144 * isattack + 128 * isblock:
		_reset_turn(sm, score_mgr)
		current_state = BoardState.IDLE
		return

	interval += 1

## プレイヤー攻撃・回復・ゲージ発射物の生成
func _spawn_attack_projectiles(sm: Node2D, score_mgr: Node2D) -> void:
	if not score_mgr: return

	# 剣（フリーズ対策・描画負荷最適化のため生成数を最大300個に制限。総ダメージは100%保持）
	var raw_sword_cnt: int = min(int((sm.ehp if sm else 0) / swordt), int(score_mgr.divscore[PieceType.SWORD] / (swordt * 100.0)))
	score_mgr.divscore[PieceType.SWORD] -= int(raw_sword_cnt * swordt * 100.0)
	var spawn_sword_cnt: int = clampi(raw_sword_cnt, 0, MAX_COMBAT_PROJECTILES)
	var dmg_per_sword: float = (float(raw_sword_cnt) / float(max(1, spawn_sword_cnt))) * 100.0 * swordt

	for i in range(spawn_sword_cnt):
		var s: Sprite2D = Sprite2D.new()
		s.texture = PIECE_TEXTURES[PieceType.SWORD]
		s.position = Vector2(12300, 5300)
		s.scale = Vector2(2.0, 2.0)
		s.visible = true
		add_child(s)
		flying_swords.append({
			"node": s,
			"t": -float(i * 70) / float(max(1, spawn_sword_cnt)),
			"rnd": float(randi() % 120),
			"has_hit": false,
			"damage": dmg_per_sword
		})
		msisvalid = true

	# 食料（生成数最大300個制限）
	var stage_idx = sm.stage - 1 if sm else 0
	var max_heal_cap: int = 50 * int(pow(10, stage_idx)) - int((sm.myhp if sm else 0) / (foodt * 100.0))
	var raw_food_cnt: int = min(max_heal_cap, int(score_mgr.divscore[PieceType.FOOD] / (foodt * 100.0)))
	score_mgr.divscore[PieceType.FOOD] -= int(raw_food_cnt * foodt * 100.0)
	var food_cnt: int = clampi(raw_food_cnt, 0, MAX_COMBAT_PROJECTILES)
	for i in range(food_cnt):
		var s: Sprite2D = Sprite2D.new()
		s.texture = PIECE_TEXTURES[PieceType.FOOD]
		s.position = Vector2(12300, 6800)
		s.scale = Vector2(2.0, 2.0)
		s.visible = true
		add_child(s)
		flying_foods.append({"node": s, "t": -float(i * 70) / float(max(1, food_cnt)), "rnd": float(randi() % 120)})

	# ポーション（生成数最大300個制限）
	var max_gage_cap: int = 70 - int((sm.fevergage if sm else 0) / (100.0 * potiont))
	var raw_potion_cnt: int = min(max_gage_cap, int(score_mgr.divscore[PieceType.POTION] / (potiont * 100.0)))
	score_mgr.divscore[PieceType.POTION] -= int(raw_potion_cnt * potiont * 100.0)
	var potion_cnt: int = clampi(raw_potion_cnt, 0, MAX_COMBAT_PROJECTILES)
	for i in range(potion_cnt):
		var s: Sprite2D = Sprite2D.new()
		s.texture = PIECE_TEXTURES[PieceType.POTION]
		s.position = Vector2(12300, 6300)
		s.scale = Vector2(2.0, 2.0)
		s.visible = true
		add_child(s)
		flying_potions.append({"node": s, "t": -float(i * 70) / float(max(1, potion_cnt)), "rnd": float(randi() % 120)})

## シールド生成（フリーズ対策・描画負荷最適化のため生成数を最大300個に制限。防御力は全数保持）
func _spawn_shield_projectiles(score_mgr: Node2D) -> void:
	if not score_mgr: return
	var raw_shield_cnt: int = int(score_mgr.divscore[PieceType.SHIELD] / (shieldt * 100.0))
	score_mgr.divscore[PieceType.SHIELD] -= int(raw_shield_cnt * shieldt * 100.0)
	current_total_shields = raw_shield_cnt
	var spawn_shield_cnt: int = clampi(raw_shield_cnt, 0, MAX_COMBAT_PROJECTILES)

	for i in range(spawn_shield_cnt):
		var s: Sprite2D = Sprite2D.new()
		s.texture = PIECE_TEXTURES[PieceType.SHIELD]
		s.position = Vector2(12300, 4800)
		s.scale = Vector2(2.0, 2.0)
		s.z_index = 1
		s.visible = true
		add_child(s)

		var target_p = Vector2(
			7200.0 / float(max(1, spawn_shield_cnt)) * i + 12300.0,
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

## 敵の攻撃モーション（安全なbase_scale絶対指定）
func _set_enemy_attack_motion(sm: Node2D, forward: bool) -> void:
	if sm == null or sm.enemy == null:
		return
	var base_s: Vector2 = sm.enemy.get_meta("base_scale", Vector2(0.5, 0.5))
	if forward:
		sm.enemy.scale = base_s * 1.35
	else:
		sm.enemy.scale = base_s

## 敵が属性スキルを発動するかどうかの判定
func _should_cast_enemy_elemental_skill(sm: Node2D) -> bool:
	if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
		return false
	var elem = sm.get_current_enemy_element() if sm.has_method("get_current_enemy_element") else "無属性"
	if elem == "無属性" or elem == "":
		return false
	var is_boss: bool = sm.is_boss_monster() if sm.has_method("is_boss_monster") else (sm.is_current_boss or sm.stage_enemy == 5)
	# ボスは確定発動、通常敵は50%の確率でスキル発動
	if not is_boss and randf() > 0.5:
		return false
	return true

## 敵の攻撃処理（通常攻撃時は爪斬撃、スキル発動時は爪斬撃を排除し本格スキル演出）
func _execute_enemy_attack(sm: Node2D) -> void:
	# 同一ターン内での多重攻撃を完全防止
	if has_enemy_attacked:
		return
	has_enemy_attacked = true

	# 敵が倒れている、または存在しない場合は攻撃しない
	if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
		return

	var will_cast_skill = _should_cast_enemy_elemental_skill(sm)
	is_casting_skill_turn = will_cast_skill

	if will_cast_skill:
		# スキル攻撃時: 爪斬撃（scratch）とblock音を完全にスキップし、本格属性スキル演出を発動！
		_execute_enemy_elemental_skill(sm)
	else:
		# 通常攻撃時: 従来の爪引っかき攻撃演出
		var p = get_parent()
		var scratch_template = p.get_node_or_null("scratch") if p else null
		if scratch_template:
			scratch_effect = scratch_template.duplicate()
			scratch_effect.scale *= 8.0
			scratch_effect.position = Vector2(15000, 2500)
			scratch_effect.frame = 0
			scratch_effect.play()
			add_child(scratch_effect)

		var block_se = get_node_or_null("block")
		if block_se:
			block_se.play()
			block_se.seek(0.7)

	if sm:
		var effective_shield_cnt: int = max(current_total_shields, active_shields.size())
		var incoming_damage = sm.enemyat / float(effective_shield_cnt + 1)
		sm.calchp(0, incoming_damage)

	for item in active_shields:
		item["node"].queue_free()
	active_shields.clear()
	current_total_shields = 0

	if sm and sm.myhp <= 0:
		var go_node = sm.get_node_or_null("gameover")
		if go_node: go_node.position = Vector2.ZERO
		isgameover = true
		interval = 0

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
			return {"name": "生命強奪・フォレストカース" if is_boss else "ソーンシード", "color": "#69F0AE"}
		"地属性":
			return {"name": "天変地異・グランドカタストロフ" if is_boss else "ロックフォール", "color": "#FFB74D"}
		"雷属性":
			return {"name": "神罰・ジャッジメントサンダー" if is_boss else "ギガスパーク", "color": "#FFD700"}
		"闇属性":
			return {"name": "終焉の夜・アビスディメンション" if is_boss else "シャドウベール＆カース", "color": "#E040FB"}
		"光属性":
			return {"name": "太陽神の審判・ソーラープリズム" if is_boss else "ミダスグレイス", "color": "#FFD700"}
		"火属性":
			return {"name": "獄炎焦土・ヘルフレイム" if is_boss else "インフェルノバースト", "color": "#FF1744"}
		_:
			return {"name": "天変地異・グランドカタストロフ" if is_boss else "ロックフォール", "color": "#FFB74D"}

## 敵属性スキルの総合ハンドラ（スキル名表示 ➜ 詠唱待機 ➜ 盤面発射・妨害展開）
func _execute_enemy_elemental_skill(sm: Node2D) -> void:
	if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
		return

	var is_boss: bool = sm.is_boss_monster() if sm.has_method("is_boss_monster") else (sm.is_current_boss or sm.stage_enemy == 5)
	var elem = sm.get_current_enemy_element() if sm.has_method("get_current_enemy_element") else "無属性"
	var s_info = _get_enemy_skill_info(elem, is_boss)
	var s_name: String = s_info["name"]
	var elem_color: String = s_info["color"]

	# ① 敵スキル専用魔法SEの再生
	_play_enemy_skill_se(is_boss)

	# ② 【重要】まずスキル名バナーを真っ先に画面中央上部に表示！
	_show_enemy_skill_banner(s_name, elem_color, is_boss)

	# ③ 敵が属性魔力を全身に滾らせ、足元に魔法陣を展開して詠唱開始
	_spawn_enemy_skill_chant_vfx(sm, elem_color, is_boss)

	# ④ スキル名を表示してから【待機時間（約0.7秒）】を置き、その後に盤面へスペル発射＆妨害展開！
	var tw_cast = create_tween()
	tw_cast.tween_interval(0.70)
	tw_cast.tween_callback(func():
		if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
			return
		# ⑤ 敵から盤面へ属性スペルビーム疾走 ＆ 着弾バースト炸裂
		_spawn_enemy_skill_beam_and_burst(sm, elem_color, is_boss)

		# ⑥ 盤面に属性妨害オブジェクト（水・氷・竜巻・苗木・岩・雷・霧・金像・爆弾）を展開！
		_apply_enemy_elemental_skill_effect(elem, is_boss)
	)

## 現在のステージ進行度に応じた難易度インデックスを取得 (0: Stage 1, 1: Stage 2, ...)
func _get_stage_index() -> int:
	var sm = _get_stage_manager()
	return clampi((sm.stage - 1) if sm else 0, 0, 10)

## 盤面への各属性妨害効果の適用
func _apply_enemy_elemental_skill_effect(elem: String, is_boss: bool) -> void:
	match elem:
		"水属性":
			_cast_enemy_water_skill(is_boss, false)
		"氷属性":
			_cast_enemy_ice_skill(is_boss, false)
		"風属性":
			_cast_enemy_wind_skill(is_boss, false)
		"木属性":
			_cast_enemy_wood_skill(is_boss, false)
		"地属性":
			_cast_enemy_earth_skill(is_boss, false)
		"雷属性":
			_cast_enemy_lightning_skill(is_boss, false)
		"闇属性":
			_cast_enemy_dark_skill(is_boss, false)
		"光属性":
			_cast_enemy_light_skill(is_boss, false)
		"火属性":
			_cast_enemy_fire_skill(is_boss, false)
		_:
			_cast_enemy_earth_skill(is_boss, false)

## 敵スキル専用効果音の再生（魔法スキル発動SE）
func _play_enemy_skill_se(is_boss: bool) -> void:
	# 攻撃音ではなく、神秘的・本格的な魔法スキル発動効果音
	var se_path = "res://Sound/se/buff/buff2.mp3" if is_boss else "res://Sound/se/buff/buff.mp3"
	var se_stream = load(se_path) as AudioStream
	if se_stream:
		var asp = AudioStreamPlayer.new()
		asp.stream = se_stream
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			asp.volume_db = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		else:
			asp.volume_db = 0.0
		var p = get_parent()
		var target_parent = p if p != null else self
		target_parent.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)

## スペルビーム飛翔効果音の再生
func _play_spell_beam_se() -> void:
	var se_path = "res://Sound/se/patinko/acceleration_15_demo.mp3"
	var se_stream = load(se_path) as AudioStream
	if se_stream:
		var asp = AudioStreamPlayer.new()
		asp.stream = se_stream
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			asp.volume_db = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		else:
			asp.volume_db = 0.0
		var p = get_parent()
		var target_parent = p if p != null else self
		target_parent.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)

## 敵エリアの詠唱演出（敵発光・巨大化・咆哮シェイク・足元魔法陣展開）
func _spawn_enemy_skill_chant_vfx(sm: Node2D, elem_color_hex: String, is_boss: bool) -> void:
	if sm == null or sm.enemy == null:
		return

	var enemy_sp = sm.enemy
	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var p = get_parent()
	var root_node = p if p != null else self

	# ① 敵スプライトのカラーフラッシュ・咆哮巨大化・シェイク
	var base_scale: Vector2 = enemy_sp.get_meta("base_scale", Vector2(0.5, 0.5))
	var orig_mod = Color.WHITE
	var orig_pos = enemy_sp.position

	# 以前のTweenがあれば強制終了して初期状態に復帰
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
	# 属性カラーで強烈に発光
	tw_enemy.tween_property(enemy_sp, "modulate", Color(elem_col.r * 2.0, elem_col.g * 2.0, elem_col.b * 2.0, 1.0), 0.15)
	# 咆哮するように拡大（常に base_scale を基準にする）
	var boost_scale = base_scale * (1.38 if is_boss else 1.28)
	tw_enemy.tween_property(enemy_sp, "scale", boost_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 激しいシェイク
	for s_i in range(8):
		var offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
		tw_enemy.chain().tween_property(enemy_sp, "position", orig_pos + offset, 0.04)

	# 元の状態へ確実に復帰
	tw_enemy.chain().set_parallel(true)
	tw_enemy.tween_property(enemy_sp, "position", orig_pos, 0.2)
	tw_enemy.tween_property(enemy_sp, "scale", base_scale, 0.2)
	tw_enemy.tween_property(enemy_sp, "modulate", orig_mod, 0.25)
	# 終了時コールバックで絶対に base_scale に復帰
	tw_enemy.chain().tween_callback(func():
		if is_instance_valid(enemy_sp):
			enemy_sp.scale = base_scale
			enemy_sp.modulate = orig_mod
			enemy_sp.position = orig_pos
	)

	# ② 敵足元・背後の詠唱魔法陣サークル（SkillVFXNode）
	var chant_node = SkillVFXNode.new(SkillVFXNode.VFXMode.CHANT_CIRCLE, elem_col, 0.95)
	chant_node.position = enemy_sp.global_position
	root_node.add_child(chant_node)

## 敵から盤面への属性スペルビーム疾走 ＆ 盤面着弾バースト演出
func _spawn_enemy_skill_beam_and_burst(sm: Node2D, elem_color_hex: String, is_boss: bool) -> void:
	if sm == null or sm.enemy == null:
		return

	var enemy_sp = sm.enemy
	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var p = get_parent()
	var root_node = p if p != null else self

	# ① 敵から盤面へ突進する属性スペルビーム（SkillVFXNode）
	var target_board_center = Vector2(780, 480)
	var beam_node = SkillVFXNode.new(SkillVFXNode.VFXMode.SPELL_BEAM, elem_col, 0.35)
	beam_node.start_pos = enemy_sp.global_position
	beam_node.target_pos = target_board_center
	root_node.add_child(beam_node)
	_play_spell_beam_se()

	# ② ビーム到達時に盤面中央で炸裂する着弾バースト（SkillVFXNode）
	var tw_burst = create_tween()
	tw_burst.tween_interval(0.30)
	tw_burst.tween_callback(func():
		if not is_instance_valid(root_node): return
		var burst_node = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, elem_col, 0.50)
		burst_node.position = target_board_center
		burst_node.max_radius = 340.0 if is_boss else 260.0
		root_node.add_child(burst_node)
	)

	# ③ 散乱する補助スパーク粒子（8発）
	for p_i in range(8):
		var orb = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, elem_col, randf_range(0.35, 0.55))
		orb.position = target_board_center + Vector2(randf_range(-220, 220), randf_range(-220, 220))
		orb.max_radius = randf_range(40.0, 90.0)
		root_node.add_child(orb)

## 敵エリアのスキル発動カットインビジュアル演出（互換用）
func _spawn_enemy_skill_activation_vfx(sm: Node2D, elem_color_hex: String, is_boss: bool) -> void:
	_spawn_enemy_skill_chant_vfx(sm, elem_color_hex, is_boss)
	_spawn_enemy_skill_beam_and_burst(sm, elem_color_hex, is_boss)

## 敵スキル発動アナウンスバナー表示
func _show_enemy_skill_banner(skill_name: String, elem_color_hex: String, is_boss: bool) -> void:
	var custom_font = preload("res://font/g_comickoin_freeR.ttf")
	var p = get_parent()
	var target_parent = p if p != null else self

	# スタイル付きバナーパネル
	var panel = Panel.new()
	panel.name = "EnemySkillBanner"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 40

	var panel_w = 720.0
	var panel_h = 86.0
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
	label.position = Vector2(0, 8)

	var boss_tag = "[color=#FF3D00]☠ BOSS SKILL ☠[/color]" if is_boss else "[color=#FFD700]⚡ 敵スキル発動 ⚡[/color]"
	label.text = "[center][font_size=18]%s[/font_size]\n[b][color=%s][font_size=32]『%s』[/font_size][/color][/b][/center]" % [boss_tag, elem_color_hex, skill_name]
	panel.add_child(label)

	if target_parent == p:
		panel.position = Vector2(800.0 - panel_w * 0.5, 30.0)
	else:
		panel.position = Vector2(8000.0 - panel_w * 5.0, 300.0)
		panel.scale = Vector2(10.0, 10.0)

	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	var orig_scale = panel.scale
	panel.scale = orig_scale * 0.8
	target_parent.add_child(panel)

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

## 1. 水属性スキル: 水浸しで操作困難（ステージ上昇でマス数増加）
func _cast_enemy_water_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "怒涛・タイダルウェイブ" if is_boss else "アクアサージ"
	if show_banner: _show_enemy_skill_banner(s_name, "#00E5FF", is_boss)
	var st_idx = _get_stage_index()
	var count = randi_range(18 + st_idx * 3, 24 + st_idx * 3) if is_boss else randi_range(8 + st_idx * 2, 12 + st_idx * 2)

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
		grid_water[p.x][p.y] = true
		_spawn_aqua_splash_effect(get_cell_position(p.x, p.y), 1)

	_redraw_board_effects()

## 2. 氷属性スキル: 氷漬けで操作困難・落雷除去不可（ステージ上昇でマス数＆耐久値増加）
func _cast_enemy_ice_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "絶対零度・ブリザード" if is_boss else "フロストロック"
	if show_banner: _show_enemy_skill_banner(s_name, "#80DEEA", is_boss)
	var st_idx = _get_stage_index()
	var count = randi_range(16 + st_idx * 3, 22 + st_idx * 3) if is_boss else randi_range(6 + st_idx * 2, 10 + st_idx * 2)

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
		# ステージ上昇に応じて氷の耐久値を強化（Stage 1~2: 耐久1, Stage 3~4: 耐久1~2, Stage 5: 耐久2、ボスは最大耐久3）
		var ice_dur = 1
		if is_boss:
			ice_dur = 2 + (1 if st_idx >= 4 and i < 4 else 0)
		elif st_idx >= 4:
			ice_dur = 2
		elif st_idx >= 2 and i < 4:
			ice_dur = 2
		grid_ice[p.x][p.y] = ice_dur
		_spawn_ice_break_effect(get_cell_position(p.x, p.y))

	_redraw_board_effects()

## 3. 風属性スキル: 縦1直線の竜巻が非コマオブジェクトを一掃（ステージ上昇で竜巻列数増加）
func _cast_enemy_wind_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "滅神風・テンペスト" if is_boss else "ダウンバースト"
	if show_banner: _show_enemy_skill_banner(s_name, "#64FFDA", is_boss)
	var st_idx = _get_stage_index()
	var base_min = 4 + int((st_idx + 1) / 2) if is_boss else 2 + int(st_idx / 2)
	var base_max = 5 + int((st_idx + 1) / 2) if is_boss else 3 + int(st_idx / 2)
	var num_cols = randi_range(mini(base_min, GRID_COLUMNS - 1), mini(base_max, GRID_COLUMNS))

	var cols: Array[int] = []
	var col_pool: Array[int] = []
	for c in range(GRID_COLUMNS): col_pool.append(c)
	col_pool.shuffle()
	for i in range(mini(num_cols, col_pool.size())):
		cols.append(col_pool[i])

	for col in cols:
		active_wind_tornadoes.append({
			"col": col,
			"y": 1250.0,
			"speed": 5500.0,
			"active": true
		})

		# 列上の非コマオブジェクト（木・アイテム・石・水たまり）を吹き飛ばす
		for plant in plant_entities.duplicate():
			var occ = _get_plant_occupied_cells(plant)
			var hit = false
			for pcell in occ:
				if pcell.y == col:
					hit = true
					break
			if hit:
				_damage_plant(plant, 999, "wind_tornado")

		for r in range(GRID_ROWS):
			if special_item.size() == GRID_ROWS:
				special_item[r][col] = SpecialItemType.NONE
			if is_bomb.size() == GRID_ROWS:
				is_bomb[r][col] = false
			if special_charge.size() == GRID_ROWS:
				special_charge[r][col] = 0
			if grid_stones.size() == GRID_ROWS:
				grid_stones[r][col] = 0
			if grid_water.size() == GRID_ROWS:
				grid_water[r][col] = false

	var rensa_se = get_node_or_null("1rensa")
	if rensa_se: rensa_se.play()

	_redraw_board_effects()

## 4. 木属性スキル: 苗木を植えて毎ターンドレイン（ステージ上昇で本数・若木割合・ドレイン量増加）
func _cast_enemy_wood_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "生命強奪・フォレストカース" if is_boss else "ソーンシード"
	if show_banner: _show_enemy_skill_banner(s_name, "#69F0AE", is_boss)
	var st_idx = _get_stage_index()
	var count = randi_range(6 + st_idx * 2, 9 + st_idx * 2) if is_boss else randi_range(3 + st_idx * 1, 5 + st_idx * 1)
	var drain_hp = (300 + st_idx * 60) if is_boss else (150 + st_idx * 30)

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
	var num_saplings = (2 + int(st_idx / 2)) if is_boss else (1 if st_idx >= 2 else 0)
	for i in range(num):
		var p = cands[i]
		var idx = grid_i[p.x][p.y]
		if idx >= 0 and idx < piece.size() and piece[idx] != null:
			piece[idx].queue_free()
			piece[idx] = null
		grid_i[p.x][p.y] = -1
		grid_n[p.x][p.y] = -1
		grid_att[p.x][p.y] = -1

		# ステージ上昇に応じて植物の耐雷耐久値（thunder_hp）を強化
		# 苗木: Stage 1~2: 耐久 1, Stage 3~4: 耐久 2, Stage 5: 耐久 3
		# 若木: Stage 1~2: 耐久 2 (ボス 3), Stage 3~4: 耐久 3 (ボス 4), Stage 5: 耐久 4 (ボス 5)
		var st_val = 1 if i < num_saplings else 0
		var th_hp = 1
		if st_val == 0:
			th_hp = 1 + (1 if st_idx >= 2 else 0) + (1 if st_idx >= 4 else 0)
		else:
			th_hp = 2 + int((st_idx + 1) / 2) + (1 if is_boss else 0)

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

	_compact_piece_arrays()
	_redraw_board_effects()

	# 初動生命力吸収（植えられた直後にプレイヤーから生命力を吸引）
	var sm = _get_stage_manager()
	if sm and not newly_planted.is_empty():
		var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
		_execute_wood_hp_drain(sm, newly_planted, stage_scale)

## 5. 地属性スキル: 石を複数配置（ステージ上昇で個数＆耐久値強化、巨岩出現）
func _cast_enemy_earth_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "天変地異・グランドカタストロフ" if is_boss else "ロックフォール"
	if show_banner: _show_enemy_skill_banner(s_name, "#FFB74D", is_boss)
	var st_idx = _get_stage_index()
	var count = randi_range(14 + st_idx * 3, 18 + st_idx * 3) if is_boss else randi_range(6 + st_idx * 2, 9 + st_idx * 2)

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c):
				if grid_stones.size() == GRID_ROWS and grid_stones[r][c] == 0:
					if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] == 0:
						cands.append(Vector2i(r, c))
	cands.shuffle()

	var num = mini(count, cands.size())
	# ステージ上昇に応じて石の耐久値を強化
	# 基礎耐久: Stage 1~2: 2, Stage 3~4: 3, Stage 5: 4 (ボスはさらに+1)
	# 巨岩耐久: 基礎耐久 + 1 (Stage 5ボス戦では耐久5~6の超巨岩が混入！)
	var base_dur = 2 + int(st_idx / 2) + (1 if is_boss else 0)
	var heavy_stones = mini(randi_range(2, 4) + st_idx, num) if st_idx >= 2 else (1 if is_boss else 0)
	for i in range(num):
		var p = cands[i]
		var stone_dur = (base_dur + 1) if i < heavy_stones else base_dur
		grid_stones[p.x][p.y] = stone_dur
		_spawn_stone_break_effect(get_cell_position(p.x, p.y))

	_trigger_screen_shake(12.0)
	var block_se = get_node_or_null("block")
	if block_se: block_se.play()

	_redraw_board_effects()

## 6. 雷属性スキル: 落雷（ステージ上昇で落雷本数大幅増加）
func _cast_enemy_lightning_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "神罰・ジャッジメントサンダー" if is_boss else "ギガスパーク"
	if show_banner: _show_enemy_skill_banner(s_name, "#FFD700", is_boss)
	var st_idx = _get_stage_index()
	var count = randi_range(18 + st_idx * 4, 25 + st_idx * 4) if is_boss else randi_range(8 + st_idx * 3, 12 + st_idx * 3)

	for i in range(count):
		var r = randi() % GRID_ROWS
		var c = randi() % GRID_COLUMNS
		var pos = get_cell_position(r, c)
		var delay = i * 0.06
		_spawn_vertical_lightning_bolt(pos, delay)

		# 落雷ヒット時の処理
		var tw_hit = create_tween()
		tw_hit.tween_interval(delay)
		tw_hit.tween_callback(func():
			# ① 水マスに当たると水たまりのみ蒸発（※氷マスは消去不可！）
			if grid_water.size() == GRID_ROWS and grid_water[r][c]:
				grid_water[r][c] = false
				_spawn_screen_flash(Color(0.2, 0.8, 1.0, 0.4), 0.08)

			# ② 木に当たると耐久値-1
			var plant = _get_plant_at(r, c)
			if not plant.is_empty():
				_damage_plant(plant, 1, "lightning")

			# ③ 石に当たると粉砕
			if grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0:
				grid_stones[r][c] = 0
				_spawn_stone_break_effect(pos)

			# ④ 黄金像に当たると耐久-1
			if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] > 0:
				grid_gold_statue[r][c] -= 1
				if grid_gold_statue[r][c] <= 0:
					_spawn_gold_shatter_effect(pos)

			# ⑤ 通常コマに当たると純粋な雷オブジェクトコマ化（触れる/動かす/マッチで反動）
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if (grid_stones.size() == GRID_ROWS and grid_stones[r][c] == 0) and \
				   (grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] == 0):
					grid_electrified[r][c] = true

			_redraw_board_effects()
		)

## 7. 闇属性スキル: 黒い霧＆呪いコマ（ステージ上昇で霧拡大・呪いコマ数増加）
func _cast_enemy_dark_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "終焉の夜・アビスディメンション" if is_boss else "シャドウベール＆カース"
	if show_banner: _show_enemy_skill_banner(s_name, "#E040FB", is_boss)
	var st_idx = _get_stage_index()

	# 黒い霧（高ステージで範囲拡大＆解除必要ターン数増加）
	var fog_size = mini(GRID_ROWS, (6 + (1 if st_idx >= 3 else 0)) if is_boss else (4 + (1 if st_idx >= 3 else 0)))
	var fog_turns = (4 if is_boss else 3) + int(st_idx / 2)
	var top_r = clampi(randi() % (GRID_ROWS - fog_size + 1), 0, GRID_ROWS - fog_size)
	var left_c = clampi(randi() % (GRID_COLUMNS - fog_size + 1), 0, GRID_COLUMNS - fog_size)
	grid_fog.append({
		"rect": Rect2i(top_r, left_c, fog_size, fog_size),
		"turns": fog_turns
	})

	# 呪いコマ生成（盾やパンを優先的に呪う）
	var curse_count = randi_range(12 + st_idx * 3, 16 + st_idx * 3) if is_boss else randi_range(6 + st_idx * 2, 8 + st_idx * 2)
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
		grid_cursed[p.x][p.y] = true

	var anten_se = get_node_or_null("anten")
	if anten_se: anten_se.play()

	_redraw_board_effects()

## 8. 光属性スキル: 重要アイテム（盾/剣）を黄金石像スカコマ化（ステージ上昇で個数＆耐久値強化）
func _cast_enemy_light_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "太陽神の審判・ソーラープリズム" if is_boss else "ミダスグレイス"
	if show_banner: _show_enemy_skill_banner(s_name, "#FFD700", is_boss)
	var st_idx = _get_stage_index()
	var count = randi_range(10 + st_idx * 2, 15 + st_idx * 2) if is_boss else randi_range(4 + st_idx * 1, 6 + st_idx * 1)

	var sm = _get_stage_manager()
	# プレイヤーピンチ時は盾、それ以外は剣を優先してスカコマ化
	var target_kind = PieceType.SHIELD if (sm and sm.myhp < sm.myhpmax * 0.4) else PieceType.SWORD

	var cands: Array[Vector2i] = []
	var backup_cands: Array[Vector2i] = []

	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if grid_gold_statue.size() == GRID_ROWS and grid_gold_statue[r][c] == 0:
					if grid_n[r][c] == target_kind:
						cands.append(Vector2i(r, c))
					else:
						backup_cands.append(Vector2i(r, c))

	cands.shuffle()
	backup_cands.shuffle()
	cands.append_array(backup_cands)

	# ステージ上昇に応じて黄金像の耐久値を強化
	# 通常: Stage 1~2: 耐久 3, Stage 3~4: 耐久 4, Stage 5: 耐久 5
	# ボス: Stage 1~2: 耐久 4, Stage 3~4: 耐久 5, Stage 5: 耐久 6（神聖黄金像）
	var statue_dur = 3 + int(st_idx / 2) + (1 if is_boss else 0)

	var num = mini(count, cands.size())
	for i in range(num):
		var p = cands[i]
		grid_gold_statue[p.x][p.y] = statue_dur
		_spawn_gold_shatter_effect(get_cell_position(p.x, p.y))

	# ボス時はさらにランダムな通常コマも追加で黄金石像化
	if is_boss:
		var extra_num = mini(randi_range(5, 8) + st_idx, backup_cands.size())
		for j in range(extra_num):
			var p2 = backup_cands[j]
			grid_gold_statue[p2.x][p2.y] = statue_dur

	_redraw_board_effects()

## 9. 火属性スキル: 燃焼爆弾コマ生成（ステージ上昇で生成数増加）
func _cast_enemy_fire_skill(is_boss: bool, show_banner: bool = true) -> void:
	var s_name = "獄炎焦土・ヘルフレイム" if is_boss else "インフェルノバースト"
	if show_banner: _show_enemy_skill_banner(s_name, "#FF1744", is_boss)
	var st_idx = _get_stage_index()
	var count = randi_range(12 + st_idx * 3, 16 + st_idx * 3) if is_boss else randi_range(5 + st_idx * 2, 8 + st_idx * 2)

	var cands: Array[Vector2i] = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if not _is_plant_cell(r, c) and grid_i[r][c] != -1:
				if special_item.size() == GRID_ROWS and special_item[r][c] == SpecialItemType.NONE:
					cands.append(Vector2i(r, c))
	cands.shuffle()

	var num = mini(count, cands.size())
	for i in range(num):
		var p = cands[i]
		special_item[p.x][p.y] = SpecialItemType.BOMB
		if is_bomb.size() == GRID_ROWS: is_bomb[p.x][p.y] = true

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
		add_child(p)
		var a = randf() * TAU
		var tw_p = create_tween().set_parallel(true)
		tw_p.tween_property(p, "position", center + Vector2(cos(a), sin(a)) * 70.0, 0.22).set_ease(Tween.EASE_OUT)
		tw_p.tween_property(p, "modulate:a", 0.0, 0.22)
		tw_p.chain().tween_callback(p.queue_free)

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
		add_child(shard)
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
		add_child(dust)
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
		add_child(coin)
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
		add_child(sp)
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
		add_child(orb)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(orb, "position", pos + Vector2(cos(a), sin(a)) * dist, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(orb, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(orb.queue_free)

## ターン終了時リセット
func _reset_turn(sm: Node2D, score_mgr: Node2D) -> void:
	# 敵スキル演出ノードを安全に消去
	if get_tree():
		get_tree().call_group("enemy_skill_vfx", "queue_free")

	isattack = 0
	isblock = 0
	has_enemy_attacked = false
	is_casting_skill_turn = false
	isswap = false
	endbreak = false
	isbreak = false
	interval = 0
	current_total_shields = 0
	_restore_score_label_positions()

	if sm and sm.isfevertime:
		sm.fevercount -= 1
		if sm.fevercount <= 0:
			sm.notfevertime()

	if score_mgr: score_mgr.combocount = 0
	var rensa_se = get_node_or_null("1rensa")
	if rensa_se:
		var spd: float = 1.0
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "game_speed" in sm_autoload:
			spd = sm_autoload.game_speed
		rensa_se.pitch_scale = 0.92 * spd

	# 黒い霧の持続ターン進行
	var f_idx = grid_fog.size() - 1
	while f_idx >= 0:
		grid_fog[f_idx]["turns"] -= 1
		if grid_fog[f_idx]["turns"] <= 0:
			grid_fog.remove_at(f_idx)
		f_idx -= 1

	_spawn_turn_bombs()
	_redraw_board_effects()

## ゲームオーバー演出
func _handle_gameover_sequence(sm: Node2D) -> void:
	if interval <= 1:
		if sm:
			var f_bgm = sm.get_node_or_null("feverbgm")
			var fl_bgm = sm.get_node_or_null("fieldbgm")
			if f_bgm: f_bgm.stop()
			if fl_bgm: fl_bgm.stop()
		var p = get_parent()
		var haiboku_se = p.get_node_or_null("haiboku") if p else null
		if haiboku_se: haiboku_se.play()
	elif interval < 100:
		if sm:
			var go_lbl = sm.get_node_or_null("GameOver")
			if go_lbl: go_lbl.position.y = (interval - 50) * 6.0
	elif interval == 100:
		if sm:
			var go_lbl = sm.get_node_or_null("GameOver")
			if go_lbl:
				if not go_lbl.has_theme_font_override("normal_font"):
					var custom_font = preload("res://font/g_comickoin_freeR.ttf")
					go_lbl.add_theme_font_override("normal_font", custom_font)
					go_lbl.add_theme_font_override("bold_font", custom_font)
					go_lbl.add_theme_constant_override("outline_size", 12)
					go_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
				go_lbl.text = "[center][b][color=#FF1744]GAME OVER[/color][/b][/center]"
		var p = get_parent()
		var ret_btn = p.get_node_or_null("returntitle") if p else null
		if ret_btn: ret_btn.visible = !ret_btn.visible
	interval += 1
