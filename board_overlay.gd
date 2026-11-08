extends Node2D
class_name BoardOverlay

## 盤面の手前に描画される障害物・状態異常・属性エフェクト描画クラス (z_index = 8)

@export var board: Node2D = null

const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")
const POISON_TILE_DRY_TEX: Texture2D = preload("res://Texture/element/poison_tile_dry.png")
const POISON_TILE_WET_TEX: Texture2D = preload("res://Texture/element/poison_tile_wet.png")

const GRID_COLS: int = 13
const GRID_ROWS: int = 13
const CELL_PITCH: float = 700.0

const BOARD_LEFT: float = 2550.0
const BOARD_TOP: float = 220.0
const BOARD_WIDTH: float = 9100.0
const BOARD_HEIGHT: float = 9100.0

func _ready() -> void:
	_setup_bake()
	z_index = 8 # コマ(0~3)より手前、UIより奥
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = load("res://font/NotoSansJP.ttf")
		CUSTOM_FONT.set_fallbacks([sys_font, load("res://font/NotoEmoji.ttf")])

# 常時アニメーション（脈動・揺らめき）する障害物の再描画間隔（秒）。描画は時間ベースなのでアニメ速度は不変
const ANIM_REDRAW_INTERVAL: float = 1.0 / 24.0
# 効果マスが多い時は描画頻度を落として負荷を抑える（見た目は維持）
const ANIM_REDRAW_INTERVAL_MED: float = 1.0 / 12.0
const ANIM_REDRAW_INTERVAL_HIGH: float = 1.0 / 6.0
const ANIM_REDRAW_INTERVAL_MAX: float = 1.0 / 3.0
var _anim_redraw_elapsed: float = 0.0
var _last_redraw_msec: int = -100000

# 描画用に ally 配列をキャッシュ（毎タイルの board.get() を回避）
var _ally_cache: Dictionary = {}
# 稲妻ポリライン用の使い回し配列（毎回の確保を避ける）
var _bolt_line_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _bolt_mark_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

## 効果マスの量に応じた再描画間隔を返す
func _current_interval() -> float:
	if board == null:
		return ANIM_REDRAW_INTERVAL
	# 竜巻は高速移動するため間引かない
	if "active_wind_tornadoes" in board and not board.active_wind_tornadoes.is_empty():
		return ANIM_REDRAW_INTERVAL
	var hazard_count: int = int(board.get("animated_hazard_count")) if "animated_hazard_count" in board else 0
	if hazard_count > 100:
		return ANIM_REDRAW_INTERVAL_MAX
	if hazard_count > 55:
		return ANIM_REDRAW_INTERVAL_HIGH
	if hazard_count > 25:
		return ANIM_REDRAW_INTERVAL_MED
	return ANIM_REDRAW_INTERVAL

## 再描画を間引きながら要求する（イベント駆動の再描画が毎フレーム走るのを防ぐ）
func _request_redraw() -> void:
	var now_msec: int = Time.get_ticks_msec()
	var min_gap: int = int(1000.0 * _current_interval())
	if now_msec - _last_redraw_msec < min_gap:
		return
	_last_redraw_msec = now_msec
	if _bake_vp != null and is_instance_valid(_bake_vp):
		if _bake_painter != null and is_instance_valid(_bake_painter):
			_bake_painter.queue_redraw()
		# テクスチャ化している場合は SubViewport の再描画だけを要求する
		_bake_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		queue_redraw()

## 盤面状態の変化など、外部からの再描画要求
func queue_redraw_throttled() -> void:
	_request_redraw()

func _process(delta: float) -> void:
	var _prof = Profiler.begin("board_overlay::_process")
	if board == null:
		return

	var needs_redraw = false

	# 竜巻の移動更新（高速移動するため存在中は毎フレーム再描画）
	if "active_wind_tornadoes" in board and not board.active_wind_tornadoes.is_empty():
		var removed = false
		var i = board.active_wind_tornadoes.size() - 1
		while i >= 0:
			var tor = board.active_wind_tornadoes[i]
			var spd: float = tor.get("speed", 4500.0)
			tor["y"] += spd * delta
			if spd >= 0.0 and tor["y"] > BOARD_TOP + BOARD_HEIGHT + 600.0:
				board.active_wind_tornadoes.remove_at(i)
				removed = true
			elif spd < 0.0 and tor["y"] < BOARD_TOP - 1600.0:
				board.active_wind_tornadoes.remove_at(i)
				removed = true
			i -= 1
		if removed and board.active_wind_tornadoes.is_empty() and board.has_method("_update_board_element_flags"):
			board._update_board_element_flags()
		needs_redraw = true

	# 脈動・揺らめきする障害物がある場合のみ一定間隔で再描画（石のみ・障害物なしなら定期再描画しない）
	# ※ 障害物の追加・削除・状態変化時は puzzle_board._redraw_board_effects() から即時に queue_redraw() される
	if not needs_redraw:
		var animated: bool = false
		if "has_animated_board_hazards" in board:
			animated = board.has_animated_board_hazards
		elif "has_board_hazards" in board:
			animated = board.has_board_hazards
		if not animated and bool(board.get("has_gold_statue")):
			var sm = board._get_stage_manager() if board.has_method("_get_stage_manager") else null
			if sm and bool(sm.get("isfevertime")):
				animated = true
		if animated:
			var interval: float = _current_interval()
			_anim_redraw_elapsed += delta
			if _anim_redraw_elapsed >= interval:
				_anim_redraw_elapsed = fmod(_anim_redraw_elapsed, interval)
				needs_redraw = true

	if needs_redraw:
		_request_redraw()

func _has_any_in_2d(arr: Array) -> bool:
	for r in range(arr.size()):
		for c in range(arr[r].size()):
			if arr[r][c]: return true
	return false

func _has_any_int_in_2d(arr: Array) -> bool:
	for r in range(arr.size()):
		for c in range(arr[r].size()):
			if arr[r][c] > 0: return true
	return false

func _is_ally_cell(prop_name: String, r: int, c: int) -> bool:
	if board == null or not (prop_name in board):
		return false
	var arr = _ally_cache.get(prop_name, null)
	if arr == null:
		arr = board.get(prop_name)
	if arr == null:
		return false
	if typeof(arr) == TYPE_ARRAY and arr.size() == GRID_ROWS and r >= 0 and r < GRID_ROWS:
		if typeof(arr[r]) == TYPE_ARRAY and c >= 0 and c < arr[r].size():
			return bool(arr[r][c])
	return false

func _draw_content(target: CanvasItem) -> void:
	var _prof = Profiler.begin("board_overlay::_draw")
	if board == null:
		return

	# ally 判定配列を描画開始時にキャッシュ（毎タイルの board.get() を回避）
	_ally_cache.clear()
	for prop in ["grid_ice_ally", "grid_stones_ally", "grid_gold_ally", "grid_electrified_ally", "grid_cursed_ally", "grid_poison_ally", "grid_fire_ally", "grid_water_ally"]:
		if prop in board:
			_ally_cache[prop] = board.get(prop)

	var has_hazards: bool = board.has_board_hazards if "has_board_hazards" in board else true
	var has_tornadoes: bool = ("active_wind_tornadoes" in board and not board.active_wind_tornadoes.is_empty())
	var has_fog: bool = ("grid_fog" in board and not board.grid_fog.is_empty())
	var has_plants: bool = ("plant_entities" in board and not board.plant_entities.is_empty())

	if not has_hazards and not has_tornadoes and not has_fog and not has_plants:
		return

	var now = Time.get_ticks_msec()
	var pulse = 0.8 + 0.2 * sin(now * 0.008)
	var rot_fast = now * 0.006

	# 1. 氷漬けマス (grid_ice: 操作不可・落雷除去不可・耐久値対応)
	if bool(board.get("has_ice")) and "grid_ice" in board and board.grid_ice.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var hp = int(board.grid_ice[r][c])
				if hp > 0:
					_draw_ice_tile(target, r, c, hp, pulse)

	# 2. 地属性の石 (grid_stones: 耐久1・落下遮蔽)
	if bool(board.get("has_stones")) and "grid_stones" in board and board.grid_stones.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var hp = board.grid_stones[r][c]
				if hp > 0:
					_draw_stone_tile(target, r, c, hp)

	# 3. 光属性の黄金石像 (grid_gold_statue: 耐久3・スカコマ)
	if bool(board.get("has_gold_statue")) and "grid_gold_statue" in board and board.grid_gold_statue.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var hp = board.grid_gold_statue[r][c]
				if hp > 0:
					_draw_gold_statue_tile(target, r, c, hp, pulse)

	# 4. 雷属性の純粋な雷オブジェクトコマ (grid_electrified: 触れる/動かす/マッチで反動)
	if bool(board.get("has_electrified")) and "grid_electrified" in board and board.grid_electrified.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_electrified[r][c]:
					_draw_electrified_tile(target, r, c, pulse, now)

	# 5. 闇属性の呪いコマ (grid_cursed: 消すと反動ダメージ)
	if bool(board.get("has_cursed")) and "grid_cursed" in board and board.grid_cursed.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_cursed[r][c]:
					_draw_cursed_tile(target, r, c, pulse)

	# 6. 植物エンティティ（苗木・若木・3x3大木: 盤面手前 z_index=8）
	if has_plants:
		for plant in board.plant_entities:
			_draw_plant_entity(target, plant, pulse, now)

	# 7. 闇属性の黒い霧 (grid_fog: 3x3または4x4を覆い隠す)
	# [復元] 水マス (grid_water: 美麗水面・波紋)
	if bool(board.get("has_water")) and "grid_water" in board and board.grid_water.size() == GRID_ROWS:
		var water_pulse = 0.85 + 0.15 * sin(now * 0.005)
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_water[r][c]:
					_draw_water_tile(target, r, c, water_pulse)

	# 猛毒マス（水マスの手前に重ねて描画・GPU完全バッチ描画で負荷ゼロ）
	if bool(board.get("has_poison")) and "grid_poison" in board and board.grid_poison.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_poison[r][c]:
					_draw_poison_tile(target, r, c)
	if has_fog:
		for fog in board.grid_fog:
			_draw_black_fog(target, fog, pulse, now)

	# 8. 風属性の竜巻 (active_wind_tornadoes: 列を縦断)
	if has_tornadoes:
		for tor in board.active_wind_tornadoes:
			_draw_wind_tornado(target, tor, rot_fast)

	# 9. 炎マス (grid_fire: 毎ターン隣接延焼・木大延焼・水/氷で消火)
	if bool(board.get("has_fire")) and "grid_fire" in board and board.grid_fire.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var f_type = int(board.grid_fire[r][c])
				if f_type > 0:
					_draw_fire_tile(target, r, c, f_type, pulse, now)

## 氷漬けタイルの描画（凍結クリスタル・フロストフレーム・耐久値表示・自他色分け対応）
func _draw_ice_tile(target: CanvasItem, r: int, c: int, hp: int, pulse: float) -> void:
	var is_ally = _is_ally_cell("grid_ice_ally", r, c)
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 12.0, BOARD_TOP + r * CELL_PITCH + 12.0, CELL_PITCH - 24.0, CELL_PITCH - 24.0)
	var center = rect.get_center()

	# 自分＝ミントクリスタル（翠銀）、敵＝冷酷なダークコバルト・バイオレット
	var ice_bg_col: Color
	var frame_outer: Color
	var frame_inner: Color
	if is_ally:
		ice_bg_col = Color(0.10, 0.85, 0.72, 0.36 * pulse)
		frame_outer = Color(0.45, 1.0, 0.88, 0.96)
		frame_inner = Color(0.20, 0.95, 0.78, 0.75)
	else:
		ice_bg_col = Color(0.32, 0.38, 0.92, 0.56 * pulse) if hp >= 2 else Color(0.28, 0.52, 0.95, 0.48 * pulse)
		frame_outer = Color(0.75, 0.65, 1.0, 0.98)
		frame_inner = Color(0.45, 0.55, 1.0, 0.75)

	target.draw_rect(rect, ice_bg_col, true)
	target.draw_rect(rect, frame_outer, false, 24.0)
	target.draw_rect(rect.grow(-20.0), frame_inner, false, 12.0)

	# 四隅の氷柱（つらら）
	var m = 110.0
	var corner_col = Color(0.65, 1.0, 0.92, 0.95) if is_ally else Color(0.90, 0.85, 1.0, 0.95)
	target.draw_line(rect.position, rect.position + Vector2(m, m * 0.4), corner_col, 14.0)
	target.draw_line(rect.position, rect.position + Vector2(m * 0.4, m), corner_col, 14.0)
	target.draw_line(rect.end, rect.end - Vector2(m, m * 0.4), corner_col, 14.0)
	target.draw_line(rect.end, rect.end - Vector2(m * 0.4, m), corner_col, 14.0)

	# 中央の雪晶・氷星
	var star_len = 120.0
	for a_deg in [0, 45, 90, 135]:
		var rad = deg_to_rad(a_deg)
		var dir = Vector2(cos(rad), sin(rad)) * star_len
		target.draw_line(center - dir, center + dir, corner_col, 16.0)
		var b_dir = Vector2(-sin(rad), cos(rad)) * 30.0
		target.draw_line(center + dir * 0.65 - b_dir, center + dir * 0.65 + b_dir, frame_outer, 10.0)
		target.draw_line(center - dir * 0.65 - b_dir, center - dir * 0.65 + b_dir, frame_outer, 10.0)
	target.draw_circle(center, 30.0, corner_col)

	var badge_y = center.y - 120.0
	target.draw_circle(Vector2(center.x, badge_y), 65.0, Color(0.04, 0.15, 0.28, 0.92))
	target.draw_arc(Vector2(center.x, badge_y), 65.0, 0.0, TAU, 24, frame_outer, 10.0)
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 50, badge_y + 35), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 100, 95, Color(0.95, 1.0, 1.0))

	var ice_label = ("❄ 氷盾(自)" if is_ally else "❄ 凍結(敵)")
	var lbl_col = Color(0.45, 1.0, 0.85, 0.98) if is_ally else Color(0.88, 0.80, 1.0, 0.98)
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 210, center.y + 195), ice_label, HORIZONTAL_ALIGNMENT_CENTER, 420, 105, lbl_col)

## 地属性の石タイル描画（自＝エメラルド輝鉱石、敵＝黒赤褐色の障害岩石）
func _draw_stone_tile(target: CanvasItem, r: int, c: int, hp: int) -> void:
	var is_ally = _is_ally_cell("grid_stones_ally", r, c)
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 10.0, BOARD_TOP + r * CELL_PITCH + 10.0, CELL_PITCH - 20.0, CELL_PITCH - 20.0)
	var center = rect.get_center()

	var pts = PackedVector2Array([
		rect.position + Vector2(60, 0),
		rect.position + Vector2(CELL_PITCH - 80, 20),
		rect.position + Vector2(CELL_PITCH - 20, 100),
		rect.position + Vector2(CELL_PITCH - 10, CELL_PITCH - 80),
		rect.position + Vector2(CELL_PITCH - 70, CELL_PITCH - 20),
		rect.position + Vector2(80, CELL_PITCH - 10),
		rect.position + Vector2(10, CELL_PITCH - 90),
		rect.position + Vector2(0, 80)
	])
	if is_ally:
		target.draw_colored_polygon(pts, Color(0.10, 0.42, 0.32, 0.82))
		var hl_pts = PackedVector2Array([pts[0], pts[1], pts[2], center])
		target.draw_colored_polygon(hl_pts, Color(0.25, 0.78, 0.58, 0.85))
		target.draw_polyline(pts, Color(0.40, 1.0, 0.75, 0.98), 20.0)
	else:
		target.draw_colored_polygon(pts, Color(0.28, 0.20, 0.18, 0.96))
		var hl_pts = PackedVector2Array([pts[0], pts[1], pts[2], center])
		target.draw_colored_polygon(hl_pts, Color(0.46, 0.34, 0.30, 0.92))
		target.draw_polyline(pts, Color(0.88, 0.45, 0.35, 0.98), 20.0)

	target.draw_line(center, center + Vector2(90, -80), Color(0.15, 0.12, 0.08, 0.95), 14.0)
	target.draw_line(center, center + Vector2(-70, 100), Color(0.15, 0.12, 0.08, 0.95), 14.0)
	if hp <= 1:
		target.draw_line(center, center + Vector2(-110, -60), Color(0.9, 0.3, 0.1, 0.95), 16.0)
		target.draw_line(center, center + Vector2(100, 80), Color(0.9, 0.3, 0.1, 0.95), 16.0)

	target.draw_circle(center + Vector2(0, -90), 65.0, Color(0.1, 0.1, 0.1, 0.88))
	var badge_col = Color(0.3, 1.0, 0.75) if is_ally else (Color(1.0, 0.8, 0.2) if hp > 1 else Color(1.0, 0.4, 0.2))
	target.draw_arc(center + Vector2(0, -90), 65.0, 0.0, TAU, 24, badge_col, 10.0)
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 50, center.y - 50), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 100, 100, badge_col)

	var st_lbl = "💎 輝石(自)" if is_ally else "🪨 石(敵)"
	var st_col = Color(0.45, 1.0, 0.80) if is_ally else Color(1.0, 0.75, 0.55)
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 210, center.y + 190), st_lbl, HORIZONTAL_ALIGNMENT_CENTER, 420, 105, st_col)

var _fever_dance_frames: SpriteFrames = null

func _get_fever_dance_frames() -> SpriteFrames:
	if _fever_dance_frames == null:
		var sf_path = "res://Texture/fever_dance/fever_dance_frames.tres"
		if ResourceLoader.exists(sf_path):
			_fever_dance_frames = load(sf_path) as SpriteFrames
	return _fever_dance_frames

## 光属性の黄金石像タイル描画（自＝神聖プラチナ聖像、敵＝呪われた赤銅黄金像）
## フィーバータイム中は見た目が華麗なフィーバーダンスに切り替わる
func _draw_gold_statue_tile(target: CanvasItem, r: int, c: int, hp: int, pulse: float) -> void:
	var is_ally = _is_ally_cell("grid_gold_ally", r, c)
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 10.0, BOARD_TOP + r * CELL_PITCH + 10.0, CELL_PITCH - 20.0, CELL_PITCH - 20.0)
	var center = rect.get_center()

	var is_fever: bool = false
	if board != null and board.has_method("_get_stage_manager"):
		var sm = board._get_stage_manager()
		if sm != null and "isfevertime" in sm:
			is_fever = bool(sm.isfevertime)

	if is_fever:
		_draw_fever_dance_gold_statue(target, rect, center, hp, is_ally, pulse)
		return

	if is_ally:
		target.draw_rect(rect, Color(0.08, 0.35, 0.40, 0.78), true)
		target.draw_rect(rect, Color(0.45, 1.0, 0.92, 0.98), false, 26.0)
		target.draw_rect(rect.grow(-18.0), Color(0.85, 1.0, 0.98, 0.65 * pulse), false, 10.0)
		target.draw_circle(center + Vector2(0, -10), 85.0, Color(0.55, 1.0, 0.95, 0.98))
		target.draw_circle(center + Vector2(0, -10), 65.0, Color(0.90, 1.0, 1.0))
		target.draw_line(center + Vector2(0, 60), center + Vector2(0, 130), Color(0.45, 0.95, 0.88), 70.0)
	else:
		# 独立お邪魔ブロック：完全に不透明な黄金岩塊ベース
		target.draw_rect(rect, Color(0.22, 0.14, 0.04, 1.0), true)
		target.draw_rect(rect.grow(-8.0), Color(0.36, 0.22, 0.06, 1.0), true)
		target.draw_rect(rect, Color(1.0, 0.70, 0.18, 1.0), false, 24.0)
		target.draw_rect(rect.grow(-18.0), Color(1.0, 0.88, 0.45, 0.75 * pulse), false, 8.0)
		target.draw_line(rect.position + Vector2(45, 20), rect.position + Vector2(45, CELL_PITCH - 40), Color(0.85, 0.58, 0.16), 14.0)
		target.draw_line(rect.position + Vector2(CELL_PITCH - 45, 20), rect.position + Vector2(CELL_PITCH - 45, CELL_PITCH - 40), Color(0.85, 0.58, 0.16), 14.0)
		target.draw_circle(center + Vector2(0, -10), 85.0, Color(0.98, 0.74, 0.22, 1.0))
		target.draw_circle(center + Vector2(0, -10), 65.0, Color(1.0, 0.90, 0.48))
		target.draw_line(center + Vector2(0, 50), center + Vector2(0, 125), Color(0.90, 0.66, 0.18), 70.0)

	var badge_y = center.y - 120.0
	var b_col = Color(0.4, 1.0, 0.9) if is_ally else Color(1.0, 0.75, 0.2)
	target.draw_circle(Vector2(center.x, badge_y), 65.0, Color(0.12, 0.09, 0.02, 0.95))
	target.draw_arc(Vector2(center.x, badge_y), 65.0, 0.0, TAU, 24, b_col, 10.0)
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 50, badge_y + 35), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 100, 95, b_col)

	var gd_lbl = "✨ 聖像(自)" if is_ally else "🏆 黄金像ブロック"
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 220, center.y + 195), gd_lbl, HORIZONTAL_ALIGNMENT_CENTER, 440, 95, b_col)

func _draw_fever_dance_gold_statue(target: CanvasItem, rect: Rect2, center: Vector2, hp: int, is_ally: bool, pulse: float) -> void:
	# 黄金＆レインボーのフィーバーフロア背景
	var bg_col = Color(0.20, 0.14, 0.03, 0.96) if not is_ally else Color(0.06, 0.28, 0.32, 0.95)
	var border_col = Color(1.0, 0.85, 0.25, 1.0) if not is_ally else Color(0.40, 1.0, 0.95, 1.0)
	target.draw_rect(rect, bg_col, true)
	target.draw_rect(rect.grow(-4.0), Color(0.35, 0.26, 0.05, 0.9) if not is_ally else Color(0.12, 0.45, 0.50, 0.85), true)
	target.draw_rect(rect, border_col, false, 24.0)
	target.draw_rect(rect.grow(-18.0), Color(1.0, 0.95, 0.50, 0.70 * pulse), false, 8.0)
	target.draw_circle(center, 90.0 * pulse, Color(1.0, 0.88, 0.3, 0.35))

	# フィーバーダンスのアニメーションフレーム描画
	var sf = _get_fever_dance_frames()
	if sf != null and sf.get_frame_count("dance") > 0:
		var f_count = sf.get_frame_count("dance")
		var frame_idx = int(Time.get_ticks_msec() * 0.024) % f_count
		var tex = sf.get_frame_texture("dance", frame_idx)
		if tex:
			var t_size = tex.get_size()
			var aspect = t_size.x / maxf(1.0, t_size.y)
			var draw_h = (CELL_PITCH - 20.0) * 1.08
			var draw_w = draw_h * aspect
			var draw_r = Rect2(center.x - draw_w * 0.5, center.y - draw_h * 0.5 - 6.0, draw_w, draw_h)
			target.draw_texture_rect(tex, draw_r, false)

	# 耐久値HPバッジ
	var badge_y = center.y - 120.0
	var b_col = Color(0.4, 1.0, 0.9) if is_ally else Color(1.0, 0.85, 0.2)
	target.draw_circle(Vector2(center.x, badge_y), 65.0, Color(0.12, 0.09, 0.02, 0.95))
	target.draw_arc(Vector2(center.x, badge_y), 65.0, 0.0, TAU, 24, b_col, 10.0)
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 50, badge_y + 35), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 100, 95, b_col)

	var gd_lbl = "✨ フィーバー聖像" if is_ally else "💃 フィーバーダンス！"
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 220, center.y + 195), gd_lbl, HORIZONTAL_ALIGNMENT_CENTER, 440, 95, Color(1.0, 0.92, 0.35))

## 雷属性の雷オブジェクト描画（自＝エメラルドシアンの過充電、敵＝赤黄の感電スパーク）
func _draw_electrified_tile(target: CanvasItem, r: int, c: int, pulse: float, now: int) -> void:
	var is_ally = _is_ally_cell("grid_electrified_ally", r, c)
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 8.0, BOARD_TOP + r * CELL_PITCH + 8.0, CELL_PITCH - 16.0, CELL_PITCH - 16.0)
	var center = rect.get_center()

	# ??????????: ??2??1???2??1????2??0??????
	if is_ally:
		target.draw_rect(rect, Color(0.02, 0.25, 0.28, 0.55), true)
		target.draw_rect(rect, Color(0.25, 1.0, 0.80, 0.98), false, 24.0)
		target.draw_circle(center, 85.0, Color(0.30, 1.0, 0.90, 0.55))
	else:
		target.draw_rect(rect, Color(0.16, 0.04, 0.06, 0.88), true)
		target.draw_rect(rect, Color(1.0, 0.30, 0.20, 0.98), false, 24.0)
		target.draw_circle(center, 85.0, Color(1.0, 0.75, 0.20, 0.60))

	# ??????????????
	_bolt_mark_pts[0] = center + Vector2(30, -145)
	_bolt_mark_pts[1] = center + Vector2(-85, -10)
	_bolt_mark_pts[2] = center + Vector2(-15, -10)
	_bolt_mark_pts[3] = center + Vector2(-55, 145)
	_bolt_mark_pts[4] = center + Vector2(85, 10)
	_bolt_mark_pts[5] = center + Vector2(15, 10)
	target.draw_colored_polygon(_bolt_mark_pts, Color(0.30, 1.0, 0.85, 1.0) if is_ally else Color(1.0, 0.86, 0.25, 1.0))

## 闇属性の呪いコマ描画（自＝蒼星の影護、敵＝紫黒ドクロの呪い）
func _draw_cursed_tile(target: CanvasItem, r: int, c: int, pulse: float) -> void:
	var is_ally = _is_ally_cell("grid_cursed_ally", r, c)
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 10.0, BOARD_TOP + r * CELL_PITCH + 10.0, CELL_PITCH - 20.0, CELL_PITCH - 20.0)
	var center = rect.get_center()

	if is_ally:
		target.draw_rect(rect, Color(0.06, 0.35, 0.55, 0.32 * pulse), true)
		target.draw_rect(rect, Color(0.25, 0.95, 1.0, 0.94), false, 20.0)
		target.draw_circle(center, 100.0, Color(0.04, 0.18, 0.28, 0.92))
		target.draw_arc(center, 100.0, 0.0, TAU, 28, Color(0.35, 0.95, 1.0), 12.0)
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 75, center.y + 55), "★", HORIZONTAL_ALIGNMENT_CENTER, 150, 150, Color(0.45, 1.0, 0.95))
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 210, center.y + 195), "🌙 影護(自)", HORIZONTAL_ALIGNMENT_CENTER, 420, 100, Color(0.45, 1.0, 0.95))
	else:
		target.draw_rect(rect, Color(0.38, 0.06, 0.55, 0.30 * pulse), true)
		target.draw_rect(rect, Color(0.85, 0.20, 1.0, 0.92), false, 20.0)
		target.draw_circle(center, 100.0, Color(0.14, 0.02, 0.20, 0.92))
		target.draw_arc(center, 100.0, 0.0, TAU, 28, Color(0.90, 0.30, 1.0), 12.0)
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 75, center.y + 55), "☠", HORIZONTAL_ALIGNMENT_CENTER, 150, 150, Color(0.98, 0.40, 1.0))
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 210, center.y + 195), "☠ 呪い(敵)", HORIZONTAL_ALIGNMENT_CENTER, 420, 100, Color(0.92, 0.50, 1.0))

## 植物エンティティ描画（盤面の手前レイヤー z_index=8 にて青々と描画）
func _draw_plant_entity(target: CanvasItem, plant: Dictionary, pulse: float, _now: int) -> void:
	var st: int = plant.get("stage", 0)
	var org: Vector2i = plant.get("origin", Vector2i(-1, -1))
	if org.x < 0 or org.y < 0 or org.x >= GRID_ROWS or org.y >= GRID_COLS:
		return

	var center = Vector2(
		BOARD_LEFT + org.y * CELL_PITCH + CELL_PITCH * 0.5,
		BOARD_TOP + org.x * CELL_PITCH + CELL_PITCH * 0.5
	)
	var hp: int = plant.get("thunder_hp", 1)
	var is_enemy: bool = plant.get("enemy_planted", false)

	if st == 0:
		# 苗木（1マス）: 立体的な盛り土 ＋ みずみずしい緑の双葉（敵植樹時は茨トゲ付き）
		# 土台
		var earth_col = Color(0.28, 0.14, 0.08, 0.96) if is_enemy else Color(0.38, 0.22, 0.12, 0.96)
		target.draw_circle(center + Vector2(0.0, 70.0), 110.0, earth_col)
		target.draw_arc(center + Vector2(0.0, 70.0), 110.0, 0.0, TAU, 24, Color(0.48, 0.28, 0.15), 10.0)

		# 双葉の茎
		var stem_col = Color(0.35, 0.15, 0.28) if is_enemy else Color(0.22, 0.65, 0.25)
		target.draw_line(center + Vector2(0.0, 80.0), center + Vector2(0.0, -20.0), stem_col, 28.0)

		# 左右の豊かな葉
		var leaf_col1 = Color(0.45, 0.85, 0.25, 0.98) if not is_enemy else Color(0.70, 0.15, 0.40, 0.98)
		var leaf_col2 = Color(0.30, 0.98, 0.35, 0.98) if not is_enemy else Color(0.85, 0.20, 0.50, 0.98)

		target.draw_line(center + Vector2(0.0, 0.0), center + Vector2(-80.0, -60.0), stem_col, 20.0)
		target.draw_line(center + Vector2(0.0, 0.0), center + Vector2(80.0, -60.0), stem_col, 20.0)
		target.draw_circle(center + Vector2(-85.0, -65.0), 65.0, leaf_col1)
		target.draw_circle(center + Vector2(85.0, -65.0), 65.0, leaf_col2)

		# 耐久値＆ドレインバッジ（上部）
		target.draw_circle(center + Vector2(0.0, -135.0), 55.0, Color(0.08, 0.12, 0.08, 0.94))
		target.draw_arc(center + Vector2(0.0, -135.0), 55.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.5), 8.0)
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 40, center.y - 105), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 80, 80, Color.WHITE)

		# 敵植樹時の「🌱 ドレイン」表示
		if is_enemy:
			target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🌱 苗木(吸血)", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(1.0, 0.4, 0.6))
		else:
			target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🌱 苗木", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(0.4, 1.0, 0.6))

	elif st == 1:
		# 若木（1マス）: 太い樹幹 ＋ 茂み（敵植樹時は妖魔の紫茂み）
		var trunk_col = Color(0.25, 0.10, 0.22, 0.98) if is_enemy else Color(0.38, 0.22, 0.12, 0.98)
		target.draw_line(center + Vector2(0.0, 150.0), center + Vector2(0.0, -40.0), trunk_col, 55.0)

		# 茂み
		var f_col1 = Color(0.42, 0.08, 0.50, 0.95) if is_enemy else Color(0.12, 0.58, 0.22, 0.95)
		var f_col2 = Color(0.55, 0.12, 0.62, 0.95) if is_enemy else Color(0.15, 0.64, 0.25, 0.95)
		var f_col3 = Color(0.72, 0.18, 0.80, 0.98) if is_enemy else Color(0.20, 0.78, 0.32, 0.98)
		var f_col4 = Color(0.88, 0.35, 0.95, 0.75 * pulse) if is_enemy else Color(0.35, 0.90, 0.45, 0.75 * pulse)

		target.draw_circle(center + Vector2(-80.0, -60.0), 110.0, f_col1)
		target.draw_circle(center + Vector2(80.0, -60.0), 110.0, f_col2)
		target.draw_circle(center + Vector2(0.0, -120.0), 130.0, f_col3)
		target.draw_circle(center + Vector2(0.0, -130.0), 95.0, f_col4)

		# 耐久値インジケーター（2ドット）
		var b_y = center.y - 210.0
		var badge_bg = Color(0.16, 0.04, 0.18, 0.94) if is_enemy else Color(0.06, 0.16, 0.08, 0.94)
		var badge_border = Color(0.9, 0.3, 1.0) if is_enemy else Color(0.4, 1.0, 0.6)
		target.draw_circle(Vector2(center.x, b_y), 60.0, badge_bg)
		target.draw_arc(Vector2(center.x, b_y), 60.0, 0.0, TAU, 24, badge_border, 8.0)
		for k in range(hp):
			var dot_x = center.x + (k - (hp - 1) * 0.5) * 32.0
			target.draw_circle(Vector2(dot_x, b_y), 10.0, Color.WHITE)

		if is_enemy:
			target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🌿 呪木(吸血)", HORIZONTAL_ALIGNMENT_CENTER, 400, 100, Color(1.0, 0.45, 0.85))
		else:
			target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🌿 若木", HORIZONTAL_ALIGNMENT_CENTER, 400, 100, Color(0.5, 1.0, 0.6))

	elif st == 2:
		# 3x3大木: 9マスを覆う荘厳な大樹冠（敵植樹時は妖魔大樹）
		var trunk_col = Color(0.22, 0.08, 0.18, 0.98) if is_enemy else Color(0.32, 0.18, 0.08, 0.98)
		target.draw_line(center + Vector2(0.0, 500.0), center + Vector2(0.0, -80.0), trunk_col, 120.0)

		var foliage_offsets = [
			Vector2(-420.0, -100.0), Vector2(420.0, -100.0),
			Vector2(-280.0, -350.0), Vector2(280.0, -350.0),
			Vector2(0.0, -450.0), Vector2(-360.0, 150.0),
			Vector2(360.0, 150.0), Vector2(0.0, -120.0)
		]
		var big_col1 = Color(0.36, 0.06, 0.44, 0.92) if is_enemy else Color(0.08, 0.48, 0.18, 0.92)
		var big_col2 = Color(0.54, 0.10, 0.64, 0.96) if is_enemy else Color(0.18, 0.72, 0.28, 0.96)
		var big_col3 = Color(0.78, 0.20, 0.88, 0.80 * pulse) if is_enemy else Color(0.30, 0.88, 0.40, 0.80 * pulse)

		for fo in foliage_offsets:
			target.draw_circle(center + fo, 260.0, big_col1)
		for fo in foliage_offsets:
			target.draw_circle(center + fo * 0.85, 210.0, big_col2)
		for fo in foliage_offsets:
			target.draw_circle(center + fo * 0.70, 150.0, big_col3)

		# オーラリング
		var aura_col = Color(0.90, 0.25, 1.0, 0.70 * pulse) if is_enemy else Color(0.45, 1.0, 0.65, 0.65 * pulse)
		target.draw_arc(center + Vector2(0.0, -120.0), 650.0, 0.0, TAU, 36, aura_col, 16.0)

		# 耐久値インジケーター（3ドット）
		var b_y3 = center.y - 520.0
		var badge_bg3 = Color(0.16, 0.04, 0.18, 0.95) if is_enemy else Color(0.06, 0.16, 0.08, 0.95)
		var badge_border3 = Color(0.9, 0.3, 1.0) if is_enemy else Color(0.4, 1.0, 0.6)
		target.draw_circle(Vector2(center.x, b_y3), 80.0, badge_bg3)
		target.draw_arc(Vector2(center.x, b_y3), 80.0, 0.0, TAU, 28, badge_border3, 10.0)
		for k in range(hp):
			var dot_x = center.x + (k - (hp - 1) * 0.5) * 36.0
			target.draw_circle(Vector2(dot_x, b_y3), 12.0, Color.WHITE)

		if is_enemy:
			target.draw_string(CUSTOM_FONT, Vector2(center.x - 300, center.y + 400), "🌳 妖魔大樹 3x3(大吸血)", HORIZONTAL_ALIGNMENT_CENTER, 600, 130, Color(1.0, 0.45, 0.90))
		else:
			target.draw_string(CUSTOM_FONT, Vector2(center.x - 300, center.y + 400), "🌳 神聖大木 3x3", HORIZONTAL_ALIGNMENT_CENTER, 600, 130, Color(0.6, 1.0, 0.7))

## 闇属性の黒い霧描画（自＝星影の蒼霧、敵＝妖気の暗黒霧）
func _draw_black_fog(target: CanvasItem, fog: Dictionary, pulse: float, now: int) -> void:
	var f_rect: Rect2i = fog.get("rect", Rect2i(5, 5, 3, 3))
	var turns: int = fog.get("turns", 2)
	var is_enemy: bool = fog.get("enemy_owned", true)

	var world_rect = Rect2(
		BOARD_LEFT + f_rect.position.y * CELL_PITCH,
		BOARD_TOP + f_rect.position.x * CELL_PITCH,
		f_rect.size.y * CELL_PITCH,
		f_rect.size.x * CELL_PITCH
	)

	var bg_col = Color(0.12, 0.03, 0.20, 0.35) if is_enemy else Color(0.03, 0.18, 0.28, 0.28)
	var border_col = Color(0.75, 0.25, 1.0, 0.80 * pulse) if is_enemy else Color(0.25, 0.90, 1.0, 0.80 * pulse)
	var cloud_col = Color(0.22, 0.06, 0.35, 0.16) if is_enemy else Color(0.08, 0.32, 0.48, 0.14)
	var cell_b_col = Color(0.60, 0.15, 0.85, 0.20 * pulse) if is_enemy else Color(0.20, 0.85, 0.95, 0.20 * pulse)

	target.draw_rect(world_rect, bg_col, true)
	target.draw_rect(world_rect, border_col, false, 18.0)

	for br in range(f_rect.position.x, f_rect.position.x + f_rect.size.x):
		for bc in range(f_rect.position.y, f_rect.position.y + f_rect.size.y):
			var c_pos = Vector2(BOARD_LEFT + bc * CELL_PITCH + CELL_PITCH * 0.5, BOARD_TOP + br * CELL_PITCH + CELL_PITCH * 0.5)
			var cloud_r = 180.0 + 25.0 * sin(now * 0.003 + (br * 3 + bc))
			target.draw_circle(c_pos, cloud_r, cloud_col)
			var c_rect = Rect2(c_pos.x - CELL_PITCH * 0.46, c_pos.y - CELL_PITCH * 0.46, CELL_PITCH * 0.92, CELL_PITCH * 0.92)
			target.draw_rect(c_rect, cell_b_col, false, 4.0)

	var badge_pos = world_rect.position + Vector2(world_rect.size.x - 350, 20)
	target.draw_rect(Rect2(badge_pos, Vector2(340, 90)), Color(0.12, 0.02, 0.18, 0.92) if is_enemy else Color(0.02, 0.14, 0.22, 0.92), true)
	target.draw_rect(Rect2(badge_pos, Vector2(340, 90)), border_col, false, 8.0)
	var fog_lbl = ("瘴気の暗雲(敵) %dT" % turns) if is_enemy else ("星影の霧(自) %dT" % turns)
	var fog_txt_col = Color(0.95, 0.70, 1.0) if is_enemy else Color(0.55, 1.0, 0.95)
	target.draw_string(CUSTOM_FONT, badge_pos + Vector2(10, 65), fog_lbl, HORIZONTAL_ALIGNMENT_CENTER, 320, 56, fog_txt_col)

## 風属性の竜巻描画（自＝エメラルドグリーンの追い風、敵＝赤紫の暴風）
func _draw_wind_tornado(target: CanvasItem, tor: Dictionary, rot: float) -> void:
	var col = tor.get("col", 7)
	var cur_y = tor.get("y", BOARD_TOP)
	var is_ally: bool = tor.get("ally", false)
	var center_x = BOARD_LEFT + col * CELL_PITCH + CELL_PITCH * 0.5

	var tor_h = 1500.0
	var top_w = 420.0
	var bot_w = 90.0

	var pts = PackedVector2Array([
		Vector2(center_x - top_w, cur_y - tor_h),
		Vector2(center_x + top_w, cur_y - tor_h),
		Vector2(center_x + bot_w, cur_y),
		Vector2(center_x - bot_w, cur_y)
	])
	var cone_col = Color(0.15, 1.0, 0.65, 0.45) if is_ally else Color(0.85, 0.20, 0.65, 0.45)
	var ring_col = Color(0.55, 1.0, 0.85, 0.90) if is_ally else Color(1.0, 0.55, 0.85, 0.90)
	var shock_col = Color(0.3, 1.0, 0.75, 0.95) if is_ally else Color(0.95, 0.35, 0.75, 0.95)
	target.draw_colored_polygon(pts, cone_col)

	for ring_i in range(8):
		var frac = float(ring_i) / 8.0
		var r_y = cur_y - tor_h * frac
		var r_w = lerpf(bot_w, top_w, frac)
		var r_angle = rot * (3.0 + frac * 2.0)
		target.draw_arc(Vector2(center_x, r_y), r_w, r_angle, r_angle + PI * 1.4, 24, ring_col, 22.0)

	target.draw_arc(Vector2(center_x, cur_y), bot_w * 1.8, 0.0, TAU, 22, shock_col, 18.0)

## 炎タイルの描画（自＝聖なる蒼炎・シアンブルー、敵＝紅蓮の赤黒業火）
func _draw_fire_tile(target: CanvasItem, r: int, c: int, fire_type: int, pulse: float, now: int) -> void:
	var is_ally = _is_ally_cell("grid_fire_ally", r, c)
	var x = BOARD_LEFT + c * CELL_PITCH
	var y = BOARD_TOP + r * CELL_PITCH
	var center = Vector2(x + CELL_PITCH * 0.5, y + CELL_PITCH * 0.5)

	var flicker1 = sin(now * 0.012 + r * 2.0 + c) * 20.0
	var flicker2 = cos(now * 0.015 + c * 3.0) * 15.0

	if is_ally:
		var glow_col = Color(0.05, 0.75, 1.0, 0.32 * pulse)
		var border_col = Color(0.25, 0.95, 1.0, 0.90 * pulse)
		target.draw_rect(Rect2(x + 10, y + 10, CELL_PITCH - 20, CELL_PITCH - 20), glow_col, true)
		target.draw_rect(Rect2(x + 15, y + 15, CELL_PITCH - 30, CELL_PITCH - 30), border_col, false, 12.0)
		target.draw_circle(center + Vector2(flicker1 * 0.3, flicker2 * 0.3 - 30.0), 90.0 * pulse, Color(0.10, 0.65, 1.0, 0.65))
		target.draw_circle(center + Vector2(flicker2 * 0.3, flicker1 * 0.3 - 50.0), 60.0 * pulse, Color(0.35, 0.95, 1.0, 0.82))
		target.draw_circle(center + Vector2(0, -60.0), 30.0 * pulse, Color(0.85, 1.0, 1.0, 0.92))
		var lbl = "🔥 蒼炎(残%dT)" % fire_type if fire_type > 0 else "🔥 蒼炎(自)"
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), lbl, HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(0.45, 0.98, 1.0))
	else:
		var glow_col = Color(1.0, 0.25, 0.0, 0.38 * pulse) if fire_type == 1 else Color(1.0, 0.1, 0.1, 0.55 * pulse)
		var border_col = Color(1.0, 0.5, 0.1, 0.88 * pulse) if fire_type == 1 else Color(1.0, 0.2, 0.0, 0.95 * pulse)
		target.draw_rect(Rect2(x + 10, y + 10, CELL_PITCH - 20, CELL_PITCH - 20), glow_col, true)
		target.draw_rect(Rect2(x + 15, y + 15, CELL_PITCH - 30, CELL_PITCH - 30), border_col, false, 12.0)
		target.draw_circle(center + Vector2(flicker1 * 0.3, flicker2 * 0.3 - 30.0), 90.0 * pulse, Color(1.0, 0.35, 0.0, 0.65))
		target.draw_circle(center + Vector2(flicker2 * 0.3, flicker1 * 0.3 - 50.0), 60.0 * pulse, Color(1.0, 0.75, 0.1, 0.80))
		target.draw_circle(center + Vector2(0, -60.0), 30.0 * pulse, Color(1.0, 1.0, 0.6, 0.90))
		if fire_type == 2 and board.has_method("_is_plant_cell") and board._is_plant_cell(r, c):
			target.draw_string(CUSTOM_FONT, center + Vector2(-120, 140), "⚠大延焼⚠", HORIZONTAL_ALIGNMENT_CENTER, 240, 40, Color(1.0, 0.9, 0.2, 0.95))
		else:
			var lbl = "🔥 炎上(残%dT)" % fire_type if fire_type > 0 else "🔥 炎上(敵)"
			target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), lbl, HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(1.0, 0.55, 0.35))

## 毒属性の猛毒沼マス描画（自＝エメラルド薬毒・免疫リング、敵＝紫黒の猛毒沼・危険警告）
func _draw_poison_tile(target: CanvasItem, r: int, c: int) -> void:
	var is_ally = _is_ally_cell("grid_poison_ally", r, c)
	var is_wet: bool = ("grid_water" in board and board.grid_water.size() == GRID_ROWS and board.grid_water[r][c])
	var tex = POISON_TILE_WET_TEX if is_wet else POISON_TILE_DRY_TEX
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 10.0, BOARD_TOP + r * CELL_PITCH + 10.0, CELL_PITCH - 20.0, CELL_PITCH - 20.0)
	var center = rect.get_center()

	var p_stage = 1
	if "grid_poison_stage" in board and board.grid_poison_stage.size() == GRID_ROWS and r < board.grid_poison_stage.size() and c < board.grid_poison_stage[r].size():
		p_stage = maxi(1, int(board.grid_poison_stage[r][c]))

	var stage_badge_y = center.y - 110.0
	target.draw_circle(Vector2(center.x, stage_badge_y), 55.0, Color(0.12, 0.04, 0.20, 0.90))
	var st_border = Color(0.35, 1.0, 0.80) if is_ally else Color(0.95, 0.35, 1.0)
	target.draw_arc(Vector2(center.x, stage_badge_y), 55.0, 0.0, TAU, 24, st_border, 8.0)
	target.draw_string(CUSTOM_FONT, Vector2(center.x - 45, stage_badge_y + 30), str(p_stage), HORIZONTAL_ALIGNMENT_CENTER, 90, 85, Color(1.0, 1.0, 1.0))

	if is_ally:
		var mod_col = Color(0.20, 1.0, 0.65, 0.95)
		target.draw_texture_rect(tex, rect, false, mod_col)
		var border_col = Color(0.25, 1.0, 0.70, 0.95)
		target.draw_rect(rect.grow(-4.0), border_col, false, 10.0)
		# 免疫オーラサークル
		target.draw_arc(center, 80.0, 0.0, TAU, 24, Color(0.35, 1.0, 0.80, 0.75), 6.0)
		target.draw_circle(center, 18.0, Color(0.40, 1.0, 0.85, 0.60))
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🧪 免疫薬毒(自)", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(0.35, 1.0, 0.75))
	else:
		var mod_col = Color(0.95, 0.30, 1.0, 0.95)
		target.draw_texture_rect(tex, rect, false, mod_col)
		var border_col = Color(0.85, 0.20, 0.95, 0.92)
		target.draw_rect(rect.grow(-4.0), border_col, false, 10.0)
		# 危険コア
		target.draw_circle(center, 22.0, Color(0.60, 0.10, 0.70, 0.70))
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "☠ 猛毒(敵)", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(0.95, 0.40, 1.0))

## 水タイルの描画（自＝エメラルドアクアの清流、敵＝深海パープルブルーの水没）
func _draw_water_tile(target: CanvasItem, r: int, c: int, pulse: float) -> void:
	var is_ally = _is_ally_cell("grid_water_ally", r, c)
	var cell_rect = Rect2(BOARD_LEFT + c * CELL_PITCH, BOARD_TOP + r * CELL_PITCH, CELL_PITCH, CELL_PITCH)
	var center = cell_rect.get_center()
	if is_ally:
		target.draw_rect(cell_rect, Color(0.05, 0.78, 0.72, 0.34 * pulse), true)
		target.draw_rect(cell_rect.grow(-6.0), Color(0.25, 1.0, 0.88, 0.88), false, 14.0)
		target.draw_circle(center + Vector2(-40.0, -40.0), 35.0, Color(0.80, 1.0, 0.95, 0.45))
		target.draw_arc(center, 90.0 * pulse, 0.0, TAU, 20, Color(0.35, 1.0, 0.90, 0.75), 6.0)
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "💧 清流(自)", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(0.45, 1.0, 0.90))
	else:
		target.draw_rect(cell_rect, Color(0.16, 0.28, 0.85, 0.44 * pulse), true)
		target.draw_rect(cell_rect.grow(-6.0), Color(0.55, 0.45, 1.0, 0.85), false, 14.0)
		target.draw_circle(center + Vector2(-40.0, -40.0), 35.0, Color(0.85, 0.85, 1.0, 0.35))
		target.draw_arc(center, 90.0 * pulse, 0.0, TAU, 20, Color(0.50, 0.65, 1.0, 0.65), 6.0)
		target.draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "💧 水没(敵)", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(0.75, 0.82, 1.0))

# --- ?????????????????????????????????????? ---
var _baked_tex: Texture2D = null
var _bake_rect: Rect2 = Rect2()
var _bake_vp: SubViewport = null
var _bake_painter: Node2D = null

func _draw() -> void:
	# テクスチャが焼き込めている場合のみ使用し、未焼き込み時は従来描画へフォールバック
	if _baked_tex != null and _bake_painter != null and is_instance_valid(_bake_painter) and _bake_painter.draw_count > 0:
		draw_texture_rect(_baked_tex, _bake_rect, false)
		return
	_draw_content(self)

func _setup_bake() -> void:
	var pad: float = 1700.0
	var origin := Vector2(BOARD_LEFT - pad, BOARD_TOP - pad)
	var span := Vector2(BOARD_WIDTH + pad * 2.0, BOARD_HEIGHT + pad * 2.0)
	_bake_rect = Rect2(origin, span)
	var tex_size: int = 2048
	var sc: float = float(tex_size) / maxf(span.x, span.y)
	_bake_vp = SubViewport.new()
	_bake_vp.size = Vector2i(tex_size, tex_size)
	_bake_vp.transparent_bg = true
	_bake_vp.disable_3d = true
	_bake_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_bake_vp)
	var holder := Node2D.new()
	holder.scale = Vector2(sc, sc)
	holder.position = -origin * sc
	_bake_vp.add_child(holder)
	var painter := _OverlayPainter.new()
	painter.host = self
	holder.add_child(painter)
	_bake_painter = painter
	painter.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	if _bake_vp != null and is_instance_valid(_bake_vp):
		var tex: Texture2D = _bake_vp.get_texture()
		if tex != null:
			_baked_tex = tex
		_bake_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	queue_redraw()

## ????????????????
class _OverlayPainter extends Node2D:
	var host: Node2D = null
	var draw_count: int = 0
	func _draw() -> void:
		draw_count += 1
		if host != null and host.has_method("_draw_content"):
			host._draw_content(self)
