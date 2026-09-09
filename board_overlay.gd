extends Node2D
class_name BoardOverlay

## 盤面の手前に描画される障害物・状態異常・属性エフェクト描画クラス (z_index = 8)

@export var board: Node2D = null

const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")

const GRID_COLS: int = 15
const GRID_ROWS: int = 15
const CELL_PITCH: float = 500.0

const BOARD_LEFT: float = 4250.0
const BOARD_TOP: float = 1250.0
const BOARD_WIDTH: float = 7500.0
const BOARD_HEIGHT: float = 7500.0

func _ready() -> void:
	z_index = 8 # コマ(0~3)より手前、UIより奥
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

func _process(delta: float) -> void:
	if board == null:
		return

	var needs_redraw = false

	# 竜巻の移動更新
	if "active_wind_tornadoes" in board and not board.active_wind_tornadoes.is_empty():
		var i = board.active_wind_tornadoes.size() - 1
		while i >= 0:
			var tor = board.active_wind_tornadoes[i]
			tor["y"] += tor.get("speed", 4500.0) * delta
			if tor["y"] > BOARD_TOP + BOARD_HEIGHT + 600.0:
				board.active_wind_tornadoes.remove_at(i)
			i -= 1
		needs_redraw = true

	# 常時アニメーションする効果がある場合は再描画
	if not needs_redraw:
		if ("grid_electrified" in board and _has_any_in_2d(board.grid_electrified)) or \
		   ("grid_fog" in board and not board.grid_fog.is_empty()) or \
		   ("grid_ice" in board and _has_any_in_2d(board.grid_ice)) or \
		   ("grid_stones" in board and _has_any_int_in_2d(board.grid_stones)) or \
		   ("grid_gold_statue" in board and _has_any_int_in_2d(board.grid_gold_statue)) or \
		   ("grid_cursed" in board and _has_any_in_2d(board.grid_cursed)) or \
		   ("plant_entities" in board and not board.plant_entities.is_empty()):
			needs_redraw = true

	if needs_redraw:
		queue_redraw()

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

func _draw() -> void:
	if board == null:
		return

	var now = Time.get_ticks_msec()
	var pulse = 0.8 + 0.2 * sin(now * 0.008)
	var rot_fast = now * 0.006

	# 1. 氷漬けマス (grid_ice: 操作不可・落雷除去不可・耐久値対応)
	if "grid_ice" in board and board.grid_ice.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var hp = int(board.grid_ice[r][c])
				if hp > 0:
					_draw_ice_tile(r, c, hp, pulse)

	# 2. 地属性の石 (grid_stones: 耐久1・落下遮蔽)
	if "grid_stones" in board and board.grid_stones.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var hp = board.grid_stones[r][c]
				if hp > 0:
					_draw_stone_tile(r, c, hp)

	# 3. 光属性の黄金石像 (grid_gold_statue: 耐久3・スカコマ)
	if "grid_gold_statue" in board and board.grid_gold_statue.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var hp = board.grid_gold_statue[r][c]
				if hp > 0:
					_draw_gold_statue_tile(r, c, hp, pulse)

	# 4. 雷属性の純粋な雷オブジェクトコマ (grid_electrified: 触れる/動かす/マッチで反動)
	if "grid_electrified" in board and board.grid_electrified.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_electrified[r][c]:
					_draw_electrified_tile(r, c, pulse, now)

	# 5. 闇属性の呪いコマ (grid_cursed: 消すと反動ダメージ)
	if "grid_cursed" in board and board.grid_cursed.size() == GRID_ROWS:
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_cursed[r][c]:
					_draw_cursed_tile(r, c, pulse)

	# 6. 植物エンティティ（苗木・若木・3x3大木: 盤面手前 z_index=8）
	if "plant_entities" in board and not board.plant_entities.is_empty():
		for plant in board.plant_entities:
			_draw_plant_entity(plant, pulse, now)

	# 7. 闇属性の黒い霧 (grid_fog: 3x3または4x4を覆い隠す)
	if "grid_fog" in board and not board.grid_fog.is_empty():
		for fog in board.grid_fog:
			_draw_black_fog(fog, pulse, now)

	# 8. 風属性の竜巻 (active_wind_tornadoes: 列を縦断)
	if "active_wind_tornadoes" in board and not board.active_wind_tornadoes.is_empty():
		for tor in board.active_wind_tornadoes:
			_draw_wind_tornado(tor, rot_fast)

## 氷漬けタイルの描画（凍結クリスタル・フロストフレーム・耐久値表示対応）
func _draw_ice_tile(r: int, c: int, hp: int, pulse: float) -> void:
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 12.0, BOARD_TOP + r * CELL_PITCH + 12.0, CELL_PITCH - 24.0, CELL_PITCH - 24.0)
	var center = rect.get_center()

	# 半透明の氷ブルーコーティング（高耐久時はより重厚なクリスタルブルー）
	var ice_bg_col = Color(0.25, 0.65, 0.95, 0.60 * pulse) if hp >= 2 else Color(0.35, 0.78, 1.0, 0.48 * pulse)
	draw_rect(rect, ice_bg_col, true)
	# 鋭角なフロストフレーム
	draw_rect(rect, Color(0.88, 0.96, 1.0, 0.98), false, 24.0)
	draw_rect(rect.grow(-20.0), Color(0.45, 0.82, 1.0, 0.70), false, 12.0)

	# 四隅の氷柱（つらら）
	var m = 110.0
	draw_line(rect.position, rect.position + Vector2(m, m * 0.4), Color(1.0, 1.0, 1.0, 0.95), 14.0)
	draw_line(rect.position, rect.position + Vector2(m * 0.4, m), Color(1.0, 1.0, 1.0, 0.95), 14.0)
	draw_line(rect.end, rect.end - Vector2(m, m * 0.4), Color(1.0, 1.0, 1.0, 0.95), 14.0)
	draw_line(rect.end, rect.end - Vector2(m * 0.4, m), Color(1.0, 1.0, 1.0, 0.95), 14.0)

	# 中央の雪晶・氷星
	var star_len = 120.0
	for a_deg in [0, 45, 90, 135]:
		var rad = deg_to_rad(a_deg)
		var dir = Vector2(cos(rad), sin(rad)) * star_len
		draw_line(center - dir, center + dir, Color(1.0, 1.0, 1.0, 0.90), 16.0)
		# 枝分かれ
		var b_dir = Vector2(-sin(rad), cos(rad)) * 30.0
		draw_line(center + dir * 0.65 - b_dir, center + dir * 0.65 + b_dir, Color(0.85, 0.95, 1.0, 0.85), 10.0)
		draw_line(center - dir * 0.65 - b_dir, center - dir * 0.65 + b_dir, Color(0.85, 0.95, 1.0, 0.85), 10.0)
	draw_circle(center, 30.0, Color(0.85, 0.98, 1.0, 0.98))

	# 耐久値が2以上の場合は上部に耐久バッジを表示
	if hp >= 2:
		var badge_y = center.y - 120.0
		draw_circle(Vector2(center.x, badge_y), 65.0, Color(0.04, 0.15, 0.28, 0.92))
		draw_arc(Vector2(center.x, badge_y), 65.0, 0.0, TAU, 24, Color(0.6, 0.9, 1.0), 10.0)
		draw_string(CUSTOM_FONT, Vector2(center.x - 50, badge_y + 35), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 100, 95, Color(0.95, 1.0, 1.0))

	# 「❄ 凍結」文字
	var ice_label = "❄ 凍結 %d" % hp if hp >= 2 else "❄ 凍結"
	draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), ice_label, HORIZONTAL_ALIGNMENT_CENTER, 400, 110, Color(0.92, 0.98, 1.0, 0.98))

## 地属性の石タイル描画（耐久値2・岩石ブロック）
func _draw_stone_tile(r: int, c: int, hp: int) -> void:
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 10.0, BOARD_TOP + r * CELL_PITCH + 10.0, CELL_PITCH - 20.0, CELL_PITCH - 20.0)
	var center = rect.get_center()

	# ゴツゴツした多角形岩石
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
	draw_colored_polygon(pts, Color(0.28, 0.24, 0.20, 0.96))
	# ハイライト面
	var hl_pts = PackedVector2Array([pts[0], pts[1], pts[2], center])
	draw_colored_polygon(hl_pts, Color(0.44, 0.40, 0.34, 0.92))
	# 外枠
	draw_polyline(pts, Color(0.70, 0.62, 0.52, 0.98), 20.0)
	# 基本ひび割れ
	draw_line(center, center + Vector2(90, -80), Color(0.15, 0.12, 0.08, 0.95), 14.0)
	draw_line(center, center + Vector2(-70, 100), Color(0.15, 0.12, 0.08, 0.95), 14.0)
	# 残りHPが1に減った時の追加ダメージひび割れ
	if hp <= 1:
		draw_line(center, center + Vector2(-110, -60), Color(0.9, 0.3, 0.1, 0.95), 16.0)
		draw_line(center, center + Vector2(100, 80), Color(0.9, 0.3, 0.1, 0.95), 16.0)
		draw_line(center + Vector2(40, -40), center + Vector2(120, -20), Color(0.12, 0.08, 0.05, 0.95), 12.0)

	# 耐久バッジ (残りHP表示)
	draw_circle(center + Vector2(0, -90), 65.0, Color(0.1, 0.1, 0.1, 0.88))
	var badge_col = Color(1.0, 0.8, 0.2) if hp > 1 else Color(1.0, 0.4, 0.2)
	draw_arc(center + Vector2(0, -90), 65.0, 0.0, TAU, 24, badge_col, 10.0)
	draw_string(CUSTOM_FONT, Vector2(center.x - 50, center.y - 50), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 100, 100, badge_col)

	# 「🪨 石」文字
	draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 190), "🪨 石", HORIZONTAL_ALIGNMENT_CENTER, 400, 110, Color(1.0, 0.88, 0.5))

## 光属性の黄金石像タイル描画（耐久値3・スカコマ）
func _draw_gold_statue_tile(r: int, c: int, hp: int, pulse: float) -> void:
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 10.0, BOARD_TOP + r * CELL_PITCH + 10.0, CELL_PITCH - 20.0, CELL_PITCH - 20.0)
	var center = rect.get_center()

	# 黄金石像フレーム＆メタリックゴールド塗り
	draw_rect(rect, Color(0.38, 0.30, 0.06, 0.90), true)
	draw_rect(rect, Color(1.0, 0.86, 0.25, 0.98), false, 26.0)
	draw_rect(rect.grow(-18.0), Color(1.0, 0.95, 0.6, 0.6 * pulse), false, 10.0)

	# 神殿ピラー調デザイン
	draw_line(rect.position + Vector2(50, 20), rect.position + Vector2(50, CELL_PITCH - 40), Color(0.88, 0.72, 0.2), 16.0)
	draw_line(rect.position + Vector2(CELL_PITCH - 50, 20), rect.position + Vector2(CELL_PITCH - 50, CELL_PITCH - 40), Color(0.88, 0.72, 0.2), 16.0)

	# 黄金の彫像シルエット
	draw_circle(center + Vector2(0, -10), 85.0, Color(0.98, 0.82, 0.22, 0.98))
	draw_circle(center + Vector2(0, -10), 65.0, Color(1.0, 0.92, 0.45))
	draw_line(center + Vector2(0, 60), center + Vector2(0, 130), Color(0.92, 0.76, 0.18), 70.0)

	# 耐久値インジケーター（残りHP数値バッジ）
	var badge_y = center.y - 120.0
	draw_circle(Vector2(center.x, badge_y), 65.0, Color(0.12, 0.09, 0.02, 0.92))
	draw_arc(Vector2(center.x, badge_y), 65.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.2), 10.0)
	draw_string(CUSTOM_FONT, Vector2(center.x - 50, badge_y + 35), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 100, 95, Color(1.0, 0.92, 0.25))

	# 「👑 黄金像」文字
	draw_string(CUSTOM_FONT, Vector2(center.x - 220, center.y + 195), "👑 黄金像", HORIZONTAL_ALIGNMENT_CENTER, 440, 95, Color(1.0, 0.94, 0.45))

## 雷属性の純粋な雷オブジェクト描画（下地を完全遮蔽する高密度プラズマ稲妻ブロック）
func _draw_electrified_tile(r: int, c: int, pulse: float, now: int) -> void:
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 8.0, BOARD_TOP + r * CELL_PITCH + 8.0, CELL_PITCH - 16.0, CELL_PITCH - 16.0)
	var center = rect.get_center()

	# 1. 下地の通常コマを完全に覆い隠す高密度ダークストーム背景
	draw_rect(rect, Color(0.04, 0.04, 0.14, 0.98), true)

	# 2. 激しく明滅するエレクトリックフィールド（高圧プラズマ層）
	draw_rect(rect, Color(0.15, 0.75, 1.0, 0.35 * pulse), true)
	draw_rect(rect, Color(1.0, 0.92, 0.20, 0.98), false, 24.0)
	draw_rect(rect.grow(-16.0), Color(0.30, 0.95, 1.0, 0.80 * pulse), false, 12.0)

	# 3. 中心で激しく脈動する高エネルギー雷球プラズマコア
	draw_circle(center, 130.0 * pulse, Color(1.0, 0.85, 0.15, 0.30))
	draw_circle(center, 85.0, Color(0.20, 0.90, 1.0, 0.60))

	# 4. 八方に激しく迸るジグザグ放電アーク（高速ランダム放電）
	var t_step = int(now * 0.03)
	for i in range(8):
		var rand_angle = (i * 45.0 + (t_step * 41 + i * 29) % 45) * (PI / 180.0)
		var p1 = center + Vector2(cos(rand_angle), sin(rand_angle)) * 60.0
		var p2 = center + Vector2(cos(rand_angle + 0.3), sin(rand_angle + 0.3)) * 220.0
		var mid = (p1 + p2) * 0.5 + Vector2(-sin(rand_angle), cos(rand_angle)) * 45.0
		var bolt_col = Color(1.0, 1.0, 0.60, 0.98) if (i % 2 == 0) else Color(0.65, 0.95, 1.0, 0.95)
		draw_polyline(PackedVector2Array([p1, mid, p2]), bolt_col, 14.0)

	# 5. 中央にシャープで迫力ある巨大稲妻ポリゴン（純粋な雷オブジェクト）
	var bolt_pts = PackedVector2Array([
		center + Vector2(30, -145),
		center + Vector2(-85, -10),
		center + Vector2(-15, -10),
		center + Vector2(-55, 145),
		center + Vector2(85, 10),
		center + Vector2(15, 10)
	])
	draw_colored_polygon(bolt_pts, Color(1.0, 0.96, 0.25, 1.0))
	draw_polyline(bolt_pts, Color(1.0, 1.0, 0.90, 1.0), 12.0)

	# 6. 「【雷】」文字（下部）
	draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 205), "【雷】", HORIZONTAL_ALIGNMENT_CENTER, 400, 105, Color(1.0, 0.95, 0.40))

## 闇属性の呪いコマ描画（紫ドクロマーク・怨念オーラ）
func _draw_cursed_tile(r: int, c: int, pulse: float) -> void:
	var rect = Rect2(BOARD_LEFT + c * CELL_PITCH + 10.0, BOARD_TOP + r * CELL_PITCH + 10.0, CELL_PITCH - 20.0, CELL_PITCH - 20.0)
	var center = rect.get_center()

	# 紫黒の怨念オーラ
	draw_rect(rect, Color(0.38, 0.06, 0.55, 0.30 * pulse), true)
	draw_rect(rect, Color(0.85, 0.20, 1.0, 0.92), false, 20.0)

	# 呪いのドクロ（☠）バッジ（中央）
	draw_circle(center, 100.0, Color(0.14, 0.02, 0.20, 0.92))
	draw_arc(center, 100.0, 0.0, TAU, 28, Color(0.90, 0.30, 1.0), 12.0)
	draw_string(CUSTOM_FONT, Vector2(center.x - 75, center.y + 55), "☠", HORIZONTAL_ALIGNMENT_CENTER, 150, 150, Color(0.98, 0.40, 1.0))

	# 「【呪い】」文字
	draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "【呪い】", HORIZONTAL_ALIGNMENT_CENTER, 400, 100, Color(0.92, 0.50, 1.0))

## 植物エンティティ描画（盤面の手前レイヤー z_index=8 にて青々と描画）
func _draw_plant_entity(plant: Dictionary, pulse: float, _now: int) -> void:
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
		draw_circle(center + Vector2(0.0, 70.0), 110.0, earth_col)
		draw_arc(center + Vector2(0.0, 70.0), 110.0, 0.0, TAU, 24, Color(0.48, 0.28, 0.15), 10.0)

		# 双葉の茎
		var stem_col = Color(0.35, 0.15, 0.28) if is_enemy else Color(0.22, 0.65, 0.25)
		draw_line(center + Vector2(0.0, 80.0), center + Vector2(0.0, -20.0), stem_col, 28.0)

		# 左右の豊かな葉
		var leaf_col1 = Color(0.45, 0.85, 0.25, 0.98) if not is_enemy else Color(0.70, 0.15, 0.40, 0.98)
		var leaf_col2 = Color(0.30, 0.98, 0.35, 0.98) if not is_enemy else Color(0.85, 0.20, 0.50, 0.98)

		draw_line(center + Vector2(0.0, 0.0), center + Vector2(-80.0, -60.0), stem_col, 20.0)
		draw_line(center + Vector2(0.0, 0.0), center + Vector2(80.0, -60.0), stem_col, 20.0)
		draw_circle(center + Vector2(-85.0, -65.0), 65.0, leaf_col1)
		draw_circle(center + Vector2(85.0, -65.0), 65.0, leaf_col2)

		# 耐久値＆ドレインバッジ（上部）
		draw_circle(center + Vector2(0.0, -135.0), 55.0, Color(0.08, 0.12, 0.08, 0.94))
		draw_arc(center + Vector2(0.0, -135.0), 55.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.5), 8.0)
		draw_string(CUSTOM_FONT, Vector2(center.x - 40, center.y - 105), str(hp), HORIZONTAL_ALIGNMENT_CENTER, 80, 80, Color.WHITE)

		# 敵植樹時の「🌱 ドレイン」表示
		if is_enemy:
			draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🌱 苗木(吸血)", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(1.0, 0.4, 0.6))
		else:
			draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🌱 苗木", HORIZONTAL_ALIGNMENT_CENTER, 400, 95, Color(0.4, 1.0, 0.6))

	elif st == 1:
		# 若木（1マス）: 太い樹幹 ＋ 青々とした若葉の茂み
		# 樹幹
		draw_line(center + Vector2(0.0, 150.0), center + Vector2(0.0, -40.0), Color(0.38, 0.22, 0.12, 0.98), 55.0)
		# 茂み（手前に豊かに広がる円群）
		draw_circle(center + Vector2(-80.0, -60.0), 110.0, Color(0.12, 0.58, 0.22, 0.95))
		draw_circle(center + Vector2(80.0, -60.0), 110.0, Color(0.15, 0.64, 0.25, 0.95))
		draw_circle(center + Vector2(0.0, -120.0), 130.0, Color(0.20, 0.78, 0.32, 0.98))
		draw_circle(center + Vector2(0.0, -130.0), 95.0, Color(0.35, 0.90, 0.45, 0.75 * pulse))

		# 耐久値インジケーター（2ドット）
		var b_y = center.y - 210.0
		draw_circle(Vector2(center.x, b_y), 60.0, Color(0.06, 0.16, 0.08, 0.94))
		draw_arc(Vector2(center.x, b_y), 60.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.6), 8.0)
		for k in range(hp):
			var dot_x = center.x + (k - (hp - 1) * 0.5) * 32.0
			draw_circle(Vector2(dot_x, b_y), 10.0, Color.WHITE)

		draw_string(CUSTOM_FONT, Vector2(center.x - 200, center.y + 195), "🌿 若木", HORIZONTAL_ALIGNMENT_CENTER, 400, 100, Color(0.5, 1.0, 0.6))

	elif st == 2:
		# 3x3大木: 9マスを覆う荘厳な大樹冠（盤面グリッドの手前で圧倒的存在感）
		# 巨大な幹
		draw_line(center + Vector2(0.0, 500.0), center + Vector2(0.0, -80.0), Color(0.32, 0.18, 0.08, 0.98), 120.0)
		# 豊かな樹冠レイヤー（3x3マス＝1500pxに広がる）
		var foliage_offsets = [
			Vector2(-420.0, -100.0), Vector2(420.0, -100.0),
			Vector2(-280.0, -350.0), Vector2(280.0, -350.0),
			Vector2(0.0, -450.0), Vector2(-360.0, 150.0),
			Vector2(360.0, 150.0), Vector2(0.0, -120.0)
		]
		for fo in foliage_offsets:
			draw_circle(center + fo, 260.0, Color(0.08, 0.48, 0.18, 0.92))
		for fo in foliage_offsets:
			draw_circle(center + fo * 0.85, 210.0, Color(0.18, 0.72, 0.28, 0.96))
		for fo in foliage_offsets:
			draw_circle(center + fo * 0.70, 150.0, Color(0.30, 0.88, 0.40, 0.80 * pulse))

		# 神聖な光のオーラリング
		draw_arc(center + Vector2(0.0, -120.0), 650.0, 0.0, TAU, 36, Color(0.45, 1.0, 0.65, 0.65 * pulse), 16.0)

		# 耐久値インジケーター（3ドット）
		var b_y3 = center.y - 520.0
		draw_circle(Vector2(center.x, b_y3), 80.0, Color(0.06, 0.16, 0.08, 0.95))
		draw_arc(Vector2(center.x, b_y3), 80.0, 0.0, TAU, 28, Color(0.4, 1.0, 0.6), 10.0)
		for k in range(hp):
			var dot_x = center.x + (k - (hp - 1) * 0.5) * 36.0
			draw_circle(Vector2(dot_x, b_y3), 12.0, Color.WHITE)

		draw_string(CUSTOM_FONT, Vector2(center.x - 300, center.y + 400), "🌳 神聖大木 3x3", HORIZONTAL_ALIGNMENT_CENTER, 600, 130, Color(0.6, 1.0, 0.7))

## 闇属性の黒い霧描画（指定エリアを暗黒煙で覆いコマを隠す）
func _draw_black_fog(fog: Dictionary, pulse: float, now: int) -> void:
	var f_rect: Rect2i = fog.get("rect", Rect2i(5, 5, 3, 3))
	var turns: int = fog.get("turns", 2)

	var world_rect = Rect2(
		BOARD_LEFT + f_rect.position.y * CELL_PITCH,
		BOARD_TOP + f_rect.position.x * CELL_PITCH,
		f_rect.size.y * CELL_PITCH,
		f_rect.size.x * CELL_PITCH
	)

	# 濃密な暗黒煙覆い
	draw_rect(world_rect, Color(0.04, 0.02, 0.07, 0.90), true)
	draw_rect(world_rect, Color(0.55, 0.15, 0.85, 0.85 * pulse), false, 30.0)

	# 渦巻く暗黒霧の雲
	for br in range(f_rect.position.x, f_rect.position.x + f_rect.size.x):
		for bc in range(f_rect.position.y, f_rect.position.y + f_rect.size.y):
			var c_pos = Vector2(BOARD_LEFT + bc * CELL_PITCH + CELL_PITCH * 0.5, BOARD_TOP + br * CELL_PITCH + CELL_PITCH * 0.5)
			# 不規則な煙雲
			var cloud_r = 230.0 + 35.0 * sin(now * 0.004 + (br * 3 + bc))
			draw_circle(c_pos, cloud_r, Color(0.07, 0.02, 0.11, 0.82))
			# 隠されたコマの「？」シルエット
			draw_string(CUSTOM_FONT, Vector2(c_pos.x - 100, c_pos.y + 75), "？", HORIZONTAL_ALIGNMENT_CENTER, 200, 220, Color(0.75, 0.55, 0.95, 0.85 * pulse))

	# 霧の持続ターンインジケーター（右上）
	var badge_pos = world_rect.position + Vector2(world_rect.size.x - 300, 40)
	draw_rect(Rect2(badge_pos, Vector2(280, 110)), Color(0.12, 0.02, 0.18, 0.95), true)
	draw_rect(Rect2(badge_pos, Vector2(280, 110)), Color(0.85, 0.25, 1.0, 0.95), false, 10.0)
	draw_string(CUSTOM_FONT, badge_pos + Vector2(20, 80), "暗雲 %dT" % turns, HORIZONTAL_ALIGNMENT_CENTER, 240, 85, Color(0.92, 0.65, 1.0))

## 風属性の竜巻描画（列を縦断する回転渦巻き）
func _draw_wind_tornado(tor: Dictionary, rot: float) -> void:
	var col = tor.get("col", 7)
	var cur_y = tor.get("y", BOARD_TOP)
	var center_x = BOARD_LEFT + col * CELL_PITCH + CELL_PITCH * 0.5

	# 竜巻の逆三角コーン（大きくダイナミックに描画）
	var tor_h = 1500.0
	var top_w = 420.0
	var bot_w = 90.0

	var pts = PackedVector2Array([
		Vector2(center_x - top_w, cur_y - tor_h),
		Vector2(center_x + top_w, cur_y - tor_h),
		Vector2(center_x + bot_w, cur_y),
		Vector2(center_x - bot_w, cur_y)
	])
	draw_colored_polygon(pts, Color(0.2, 0.95, 0.75, 0.45))

	# 竜巻内部の高速回転スパイラルリング
	for ring_i in range(8):
		var frac = float(ring_i) / 8.0
		var r_y = cur_y - tor_h * frac
		var r_w = lerpf(bot_w, top_w, frac)
		var r_angle = rot * (3.0 + frac * 2.0)
		draw_arc(Vector2(center_x, r_y), r_w, r_angle, r_angle + PI * 1.4, 24, Color(0.65, 1.0, 0.92, 0.90), 22.0)

	# 衝撃波リング
	draw_arc(Vector2(center_x, cur_y), bot_w * 1.8, 0.0, TAU, 22, Color(0.4, 1.0, 0.85, 0.95), 18.0)

