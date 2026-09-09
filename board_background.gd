extends Node2D
class_name BoardBackground

## パズル盤面の背景、罫線（グリッド線）、外枠、および選択セルのハイライト描画

@export var board = null
@export var background_texture: Texture2D = null

const GRID_COLS: int = 15
const GRID_ROWS: int = 15
const CELL_PITCH: float = 500.0

const BOARD_LEFT: float = 4250.0
const BOARD_TOP: float = 1250.0
const BOARD_WIDTH: float = 7500.0   # 15 * 500
const BOARD_HEIGHT: float = 7500.0  # 15 * 500
const BOARD_RIGHT: float = BOARD_LEFT + BOARD_WIDTH
const BOARD_BOTTOM: float = BOARD_TOP + BOARD_HEIGHT

const FRAME_MARGIN: float = 120.0

func _draw() -> void:
	# 1. 盤面全体のドロップシャドウ
	var shadow_rect = Rect2(
		BOARD_LEFT - FRAME_MARGIN + 50.0,
		BOARD_TOP - FRAME_MARGIN + 50.0,
		BOARD_WIDTH + FRAME_MARGIN * 2.0,
		BOARD_HEIGHT + FRAME_MARGIN * 2.0
	)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.45), true)

	# 2. 高級マホガニーウッド ＆ シャンパンゴールド外枠（VIPカジノテーブル外装フレーム）
	var outer_rect = Rect2(
		BOARD_LEFT - FRAME_MARGIN,
		BOARD_TOP - FRAME_MARGIN,
		BOARD_WIDTH + FRAME_MARGIN * 2.0,
		BOARD_HEIGHT + FRAME_MARGIN * 2.0
	)
	# フレーム地塗り（深みのあるマホガニーチェリーウッド）
	draw_rect(outer_rect, Color(0.14, 0.06, 0.03, 1.0), true)
	draw_rect(outer_rect.grow(-12.0), Color(0.18, 0.08, 0.04, 1.0), true)
	# シャンパンゴールド・ダブルフィリグリーリム
	draw_rect(outer_rect, Color(0.88, 0.72, 0.30, 0.95), false, 14.0)
	draw_rect(outer_rect.grow(-22.0), Color(1.0, 0.88, 0.45, 0.75), false, 6.0)
	# 内側ブラス（真鍮）リム
	var inner_frame_rect = Rect2(
		BOARD_LEFT - 12.0,
		BOARD_TOP - 12.0,
		BOARD_WIDTH + 24.0,
		BOARD_HEIGHT + 24.0
	)
	draw_rect(inner_frame_rect, Color(0.92, 0.78, 0.35, 0.90), false, 10.0)

	# 四隅の装飾コーナーブラケット（L字金具）＆リベット
	_draw_corner_brackets()

	# 3. 盤面内部の描画（最高級VIPカジノ・ベルベットグリーンフェルト ＋ トランプスート刻印）
	var board_inner_rect = Rect2(BOARD_LEFT, BOARD_TOP, BOARD_WIDTH, BOARD_HEIGHT)
	draw_rect(board_inner_rect, Color(0.04, 0.18, 0.10, 1.0), true)

	# ルーレット＆バカラテーブルを想起させるシャンパンゴールドのアーク＆オーバル装飾線
	var board_center = board_inner_rect.get_center()
	draw_arc(board_center, 2400.0, 0.0, TAU, 64, Color(0.9, 0.75, 0.3, 0.10), 16.0)
	draw_arc(board_center, 1800.0, 0.0, TAU, 48, Color(0.9, 0.75, 0.3, 0.08), 10.0)
	draw_arc(board_center, 1200.0, 0.0, TAU, 36, Color(1.0, 0.85, 0.4, 0.12), 12.0)
	draw_arc(board_center, 600.0, 0.0, TAU, 24, Color(1.0, 0.90, 0.5, 0.16), 8.0)

	# 緑色市松模様タイルの描画（ベルベットフェルト質感 ＋ トランプスート ♠♥♦♣ 透かし刻印）
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var cell_rect = Rect2(
				BOARD_LEFT + c * CELL_PITCH,
				BOARD_TOP + r * CELL_PITCH,
				CELL_PITCH,
				CELL_PITCH
			)
			var tile_color: Color = Color(0.06, 0.22, 0.13, 0.95) if (r + c) % 2 == 0 else Color(0.04, 0.17, 0.09, 0.95)
			draw_rect(cell_rect, tile_color, true)

			# トランプスートの透かし刻印（(r*3+c)%4 で ♠, ♥, ♦, ♣ を均等配置）
			var c_center = cell_rect.get_center()
			_draw_casino_suit_watermark(c_center, (r * 3 + c) % 4)

			# タイルの立体感を出す微細インセット
			var top_left = cell_rect.position
			var top_right = cell_rect.position + Vector2(CELL_PITCH, 0.0)
			var bot_left = cell_rect.position + Vector2(0.0, CELL_PITCH)
			var bot_right = cell_rect.end

			draw_line(top_left, top_right, Color(1.0, 0.9, 0.5, 0.06), 4.0)
			draw_line(top_left, bot_left, Color(1.0, 0.9, 0.5, 0.05), 4.0)
			draw_line(bot_left, bot_right, Color(0.0, 0.0, 0.0, 0.35), 4.0)
			draw_line(top_right, bot_right, Color(0.0, 0.0, 0.0, 0.35), 4.0)

	# 3.5 水浸しマス（grid_water）の美麗水面・波紋描画
	if board != null and "grid_water" in board and board.grid_water.size() == GRID_ROWS:
		var water_pulse = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.005)
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_water[r][c]:
					var cell_rect = Rect2(
						BOARD_LEFT + c * CELL_PITCH,
						BOARD_TOP + r * CELL_PITCH,
						CELL_PITCH,
						CELL_PITCH
					)
					# 深いアクアブルーの水たまり
					draw_rect(cell_rect, Color(0.10, 0.45, 0.85, 0.38 * water_pulse), true)
					draw_rect(cell_rect.grow(-4.0), Color(0.30, 0.80, 1.0, 0.55), false, 8.0)
					var center = cell_rect.get_center()
					# 水滴・水面ハイライト
					draw_circle(center + Vector2(-40.0, -40.0), 35.0, Color(1.0, 1.0, 1.0, 0.35))
					draw_arc(center, 90.0 * water_pulse, 0.0, TAU, 20, Color(0.4, 0.85, 1.0, 0.65), 5.0)

	# 3.6 植物エンティティ（苗木・若木・大木）は前面オーバーレイ (BoardOverlay z_index=8) にて描画


	# 4. グリッド罫線（Ruled Lines）の描画（シャンパンゴールド・ステッチ調）
	var grid_line_color = Color(0.78, 0.65, 0.25, 0.75)
	var grid_shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	for c in range(GRID_COLS + 1):
		var x = BOARD_LEFT + c * CELL_PITCH
		draw_line(Vector2(x + 3.0, BOARD_TOP + 3.0), Vector2(x + 3.0, BOARD_BOTTOM + 3.0), grid_shadow_color, 14.0)
		draw_line(Vector2(x, BOARD_TOP), Vector2(x, BOARD_BOTTOM), grid_line_color, 12.0)

	for r in range(GRID_ROWS + 1):
		var y = BOARD_TOP + r * CELL_PITCH
		draw_line(Vector2(BOARD_LEFT + 3.0, y + 3.0), Vector2(BOARD_RIGHT + 3.0, y + 3.0), grid_shadow_color, 14.0)
		draw_line(Vector2(BOARD_LEFT, y), Vector2(BOARD_RIGHT, y), grid_line_color, 12.0)

	# 罫線の交差点アクセント（ゴールドリベット）
	var dot_color = Color(1.0, 0.88, 0.40, 1.0)
	for r in range(GRID_ROWS + 1):
		for c in range(GRID_COLS + 1):
			var pt = Vector2(BOARD_LEFT + c * CELL_PITCH, BOARD_TOP + r * CELL_PITCH)
			draw_circle(pt, 12.0, dot_color)
			draw_circle(pt, 5.0, Color(0.20, 0.12, 0.04))

	# 5. 特殊アイテムマスのスタイリッシュなオーラ・フレーム・シンボル描画
	if board != null and "special_item" in board and board.special_item.size() == GRID_ROWS:
		var time_pulse = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.007)
		var rot_angle = Time.get_ticks_msec() * 0.004

		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				var sp_type = board.special_item[r][c]
				# 後方互換性: is_bombがtrueだがspecial_itemがNONEの場合はBOMBとして扱う
				if sp_type == 0 and "is_bomb" in board and board.is_bomb.size() == GRID_ROWS and board.is_bomb[r][c]:
					sp_type = 1 # BOMB

				if sp_type == 0:
					continue

				var item_rect = Rect2(
					BOARD_LEFT + c * CELL_PITCH + 10.0,
					BOARD_TOP + r * CELL_PITCH + 10.0,
					CELL_PITCH - 20.0,
					CELL_PITCH - 20.0
				)
				var center = item_rect.get_center()

				match sp_type:
					1: # BOMB: 通常爆弾（紅蓮オーラ ＋ ハザードフレーム ＋ 起爆コア）
						draw_rect(item_rect, Color(1.0, 0.22, 0.05, 0.28 * time_pulse), true)
						draw_rect(item_rect, Color(1.0, 0.65, 0.10, 0.90), false, 12.0)
						draw_circle(center, 70.0 * time_pulse, Color(1.0, 0.15, 0.0, 0.65))
						draw_circle(center, 35.0 * time_pulse, Color(1.0, 0.90, 0.2, 0.90))

					2: # CROSS_BOMB: 十字爆弾（ネオンシアン ＋ 十字クロスレーザーシンボル）
						draw_rect(item_rect, Color(0.0, 0.85, 1.0, 0.25 * time_pulse), true)
						draw_rect(item_rect, Color(0.1, 0.95, 1.0, 0.95), false, 12.0)
						# 十字クロスシンボル
						var arm_len = 100.0 * time_pulse
						draw_line(center - Vector2(arm_len, 0), center + Vector2(arm_len, 0), Color(1.0, 1.0, 1.0, 0.95), 14.0)
						draw_line(center - Vector2(0, arm_len), center + Vector2(0, arm_len), Color(1.0, 1.0, 1.0, 0.95), 14.0)
						draw_circle(center, 30.0, Color(0.2, 1.0, 1.0, 0.95))

					3: # DISCO_BALL: ディスコボール（虹色カラーサイクル ＋ ミラーボール星光）
						var hue = fposmod(Time.get_ticks_msec() * 0.0008, 1.0)
						var disco_col = Color.from_hsv(hue, 0.85, 1.0, 0.95)
						draw_rect(item_rect, Color.from_hsv(hue, 0.7, 1.0, 0.25 * time_pulse), true)
						draw_rect(item_rect, disco_col, false, 14.0)
						draw_circle(center, 65.0 * time_pulse, Color(1.0, 1.0, 1.0, 0.75))
						draw_circle(center, 40.0, disco_col)

					4: # COLOR_CONVERTER: ペンキ爆弾（エメラルド枠 ＋ 3色パレットドット）
						draw_rect(item_rect, Color(0.0, 1.0, 0.45, 0.22 * time_pulse), true)
						draw_rect(item_rect, Color(0.1, 1.0, 0.5, 0.90), false, 12.0)
						draw_circle(center + Vector2(-35.0, 20.0), 28.0, Color(1.0, 0.25, 0.25, 0.9)) # 赤
						draw_circle(center + Vector2(35.0, 20.0), 28.0, Color(0.2, 0.6, 1.0, 0.9))   # 青
						draw_circle(center + Vector2(0.0, -35.0), 28.0, Color(0.2, 1.0, 0.3, 0.9))   # 緑

					5: # LIGHTNING: チェインライトニング（電撃ゴールド ＋ ジグザグ稲妻）
						draw_rect(item_rect, Color(1.0, 0.9, 0.1, 0.25 * time_pulse), true)
						draw_rect(item_rect, Color(1.0, 0.95, 0.2, 0.95), false, 12.0)
						var l_pts = PackedVector2Array([
							center + Vector2(10.0, -70.0),
							center + Vector2(-30.0, -10.0),
							center + Vector2(15.0, 0.0),
							center + Vector2(-15.0, 70.0)
						])
						draw_polyline(l_pts, Color(1.0, 1.0, 0.6, 1.0), 12.0)

					6: # BLACK_HOLE: ブラックホール（暗黒バイオレット ＋ 吸引回転スパイラル）
						draw_rect(item_rect, Color(0.3, 0.05, 0.6, 0.35), true)
						draw_rect(item_rect, Color(0.7, 0.2, 1.0, 0.90), false, 12.0)
						draw_circle(center, 55.0, Color(0.1, 0.0, 0.2, 0.95))
						draw_arc(center, 90.0 * time_pulse, rot_angle, rot_angle + PI * 1.3, 24, Color(0.8, 0.3, 1.0, 0.85), 10.0)
						draw_arc(center, 60.0 * time_pulse, rot_angle + PI, rot_angle + PI * 2.3, 24, Color(0.9, 0.5, 1.0, 0.85), 8.0)

					7: # TORNADO: つむじ風/竜巻（エメラルドシアン ＋ 渦巻きトルネード）
						draw_rect(item_rect, Color(0.1, 0.9, 0.7, 0.25 * time_pulse), true)
						draw_rect(item_rect, Color(0.2, 1.0, 0.8, 0.95), false, 12.0)
						draw_arc(center, 80.0 * time_pulse, rot_angle, rot_angle + PI * 1.5, 20, Color(0.3, 1.0, 0.85, 0.9), 10.0)
						draw_arc(center, 45.0 * time_pulse, -rot_angle, -rot_angle + PI * 1.5, 16, Color(0.6, 1.0, 0.9, 0.95), 8.0)
						draw_circle(center, 18.0, Color.WHITE)

					8: # AQUA_SPLASH: アクアスプラッシュ（ディープアクア ＋ 水滴スプラッシュ）
						draw_rect(item_rect, Color(0.05, 0.5, 1.0, 0.28 * time_pulse), true)
						draw_rect(item_rect, Color(0.2, 0.75, 1.0, 0.95), false, 12.0)
						draw_circle(center, 60.0 * time_pulse, Color(0.1, 0.6, 1.0, 0.85))
						draw_circle(center + Vector2(-15.0, -15.0), 18.0, Color(1.0, 1.0, 1.0, 0.8))
						for i in range(4):
							var a = i * PI * 0.5 + rot_angle * 0.5
							draw_circle(center + Vector2(cos(a), sin(a)) * 95.0, 14.0 * time_pulse, Color(0.4, 0.85, 1.0, 0.9))

					9: # TREE_SPROUT: 生命の苗木（ライムグリーン ＋ 双葉シンボル）
						draw_rect(item_rect, Color(0.2, 0.9, 0.3, 0.25 * time_pulse), true)
						draw_rect(item_rect, Color(0.3, 1.0, 0.4, 0.95), false, 12.0)
						draw_circle(center, 55.0 * time_pulse, Color(0.15, 0.75, 0.25, 0.75))
						draw_line(center + Vector2(0.0, 30.0), center + Vector2(-30.0, -15.0), Color(1.0, 1.0, 1.0, 0.95), 10.0)
						draw_line(center + Vector2(0.0, 30.0), center + Vector2(30.0, -15.0), Color(1.0, 1.0, 1.0, 0.95), 10.0)
						draw_circle(center + Vector2(-30.0, -18.0), 16.0, Color(0.6, 1.0, 0.4))
						draw_circle(center + Vector2(30.0, -18.0), 16.0, Color(0.6, 1.0, 0.4))

					10: # MAGNET: マグネット（赤青ツートン ＋ 磁力U字）
						draw_rect(item_rect, Color(1.0, 0.4, 0.0, 0.2 * time_pulse), true)
						draw_rect(item_rect, Color(1.0, 0.3, 0.2, 0.9), false, 12.0)
						draw_circle(center + Vector2(-40.0, 0.0), 30.0, Color(1.0, 0.2, 0.2, 0.95)) # N極(赤)
						draw_circle(center + Vector2(40.0, 0.0), 30.0, Color(0.2, 0.5, 1.0, 0.95))  # S極(青)

					11: # CHARGE_BOMB: チャージボム（熱狂パルス ＋ 段階ドット）
						var ch = 1
						if "special_charge" in board and board.special_charge.size() == GRID_ROWS:
							ch = max(1, board.special_charge[r][c])
						var ch_col = Color(1.0, 0.5, 0.0) if ch == 1 else (Color(1.0, 0.2, 0.0) if ch == 2 else Color(1.0, 0.0, 0.4))
						draw_rect(item_rect, Color(ch_col.r, ch_col.g, ch_col.b, 0.35 * time_pulse), true)
						draw_rect(item_rect, ch_col, false, 12.0 + ch * 4.0)
						draw_circle(center, (35.0 + ch * 20.0) * time_pulse, ch_col)
						for k in range(ch):
							var dot_x = center.x + (k - (ch - 1) * 0.5) * 40.0
							draw_circle(Vector2(dot_x, center.y + 65.0), 12.0, Color.WHITE)

					12: # GEMINI_BOMB: 双子ボム（オレンジゴールド ＋ 2連サークル）
						draw_rect(item_rect, Color(1.0, 0.6, 0.1, 0.25 * time_pulse), true)
						draw_rect(item_rect, Color(1.0, 0.75, 0.15, 0.95), false, 12.0)
						draw_circle(center + Vector2(-35.0, 0.0), 35.0 * time_pulse, Color(1.0, 0.3, 0.1, 0.9))
						draw_circle(center + Vector2(35.0, 0.0), 35.0 * time_pulse, Color(1.0, 0.8, 0.1, 0.9))

	# 6. 選択中マスの発光ハイライト
	if board != null and "selected_cell" in board:
		var sel: Vector2i = board.selected_cell
		if sel.x >= 0 and sel.y >= 0 and sel.x < GRID_ROWS and sel.y < GRID_COLS:
			var sel_rect = Rect2(
				BOARD_LEFT + sel.y * CELL_PITCH,
				BOARD_TOP + sel.x * CELL_PITCH,
				CELL_PITCH,
				CELL_PITCH
			)
			# 黄金のグロー塗り
			draw_rect(sel_rect, Color(1.0, 0.88, 0.10, 0.22), true)
			# 発光太枠
			draw_rect(sel_rect.grow(-4.0), Color(1.0, 0.92, 0.25, 0.95), false, 14.0)

			# コーナー装飾マーク
			var arm = 45.0
			var p1 = sel_rect.position + Vector2(8.0, 8.0)
			draw_line(p1, p1 + Vector2(arm, 0.0), Color(1.0, 1.0, 0.7, 1.0), 6.0)
			draw_line(p1, p1 + Vector2(0.0, arm), Color(1.0, 1.0, 0.7, 1.0), 6.0)

			var p2 = sel_rect.position + Vector2(CELL_PITCH - 8.0, 8.0)
			draw_line(p2, p2 - Vector2(arm, 0.0), Color(1.0, 1.0, 0.7, 1.0), 6.0)
			draw_line(p2, p2 + Vector2(0.0, arm), Color(1.0, 1.0, 0.7, 1.0), 6.0)

			var p3 = sel_rect.position + Vector2(8.0, CELL_PITCH - 8.0)
			draw_line(p3, p3 + Vector2(arm, 0.0), Color(1.0, 1.0, 0.7, 1.0), 6.0)
			draw_line(p3, p3 - Vector2(0.0, arm), Color(1.0, 1.0, 0.7, 1.0), 6.0)

			var p4 = sel_rect.end - Vector2(8.0, 8.0)
			draw_line(p4, p4 - Vector2(arm, 0.0), Color(1.0, 1.0, 0.7, 1.0), 6.0)
			draw_line(p4, p4 - Vector2(0.0, arm), Color(1.0, 1.0, 0.7, 1.0), 6.0)

## 四隅の装飾ブラケットの描画
func _draw_corner_brackets() -> void:
	var bracket_len = 220.0
	var bracket_col = Color(1.0, 0.85, 0.20, 0.95) # ゴールド
	var rivet_col = Color(1.0, 0.90, 0.40, 1.0)
	var rivet_inner = Color(0.20, 0.15, 0.05, 1.0)

	var tl = Vector2(BOARD_LEFT - FRAME_MARGIN, BOARD_TOP - FRAME_MARGIN)
	var tr = Vector2(BOARD_RIGHT + FRAME_MARGIN, BOARD_TOP - FRAME_MARGIN)
	var bl = Vector2(BOARD_LEFT - FRAME_MARGIN, BOARD_BOTTOM + FRAME_MARGIN)
	var br = Vector2(BOARD_RIGHT + FRAME_MARGIN, BOARD_BOTTOM + FRAME_MARGIN)

	# Top-Left
	draw_line(tl, tl + Vector2(bracket_len, 0.0), bracket_col, 18.0)
	draw_line(tl, tl + Vector2(0.0, bracket_len), bracket_col, 18.0)
	draw_circle(tl + Vector2(40.0, 40.0), 20.0, rivet_col)
	draw_circle(tl + Vector2(40.0, 40.0), 10.0, rivet_inner)

	# Top-Right
	draw_line(tr, tr - Vector2(bracket_len, 0.0), bracket_col, 18.0)
	draw_line(tr, tr + Vector2(0.0, bracket_len), bracket_col, 18.0)
	draw_circle(tr + Vector2(-40.0, 40.0), 20.0, rivet_col)
	draw_circle(tr + Vector2(-40.0, 40.0), 10.0, rivet_inner)

	# Bottom-Left
	draw_line(bl, bl + Vector2(bracket_len, 0.0), bracket_col, 18.0)
	draw_line(bl, bl - Vector2(0.0, bracket_len), bracket_col, 18.0)
	draw_circle(bl + Vector2(40.0, -40.0), 20.0, rivet_col)
	draw_circle(bl + Vector2(40.0, -40.0), 10.0, rivet_inner)

	# Bottom-Right
	draw_line(br, br - Vector2(bracket_len, 0.0), bracket_col, 18.0)
	draw_line(br, br - Vector2(0.0, bracket_len), bracket_col, 18.0)
	draw_circle(br + Vector2(-40.0, -40.0), 20.0, rivet_col)
	draw_circle(br + Vector2(-40.0, -40.0), 10.0, rivet_inner)

## トランプスート（♠, ♥, ♦, ♣）の繊細な透かし刻印描画
func _draw_casino_suit_watermark(center: Vector2, suit_type: int) -> void:
	var watermark_col = Color(1.0, 0.88, 0.45, 0.055) # シャンパンゴールドの繊細な透かし
	var s = 65.0 # スケールサイズ
	match suit_type:
		0: # スペード ♠
			var pts = PackedVector2Array([
				center + Vector2(0.0, -s * 0.85),
				center + Vector2(s * 0.7, -s * 0.1),
				center + Vector2(s * 0.55, s * 0.45),
				center + Vector2(0.0, s * 0.25),
				center + Vector2(-s * 0.55, s * 0.45),
				center + Vector2(-s * 0.7, -s * 0.1)
			])
			draw_colored_polygon(pts, watermark_col)
			draw_circle(center + Vector2(-s * 0.32, s * 0.15), s * 0.35, watermark_col)
			draw_circle(center + Vector2(s * 0.32, s * 0.15), s * 0.35, watermark_col)
			var stem_pts = PackedVector2Array([
				center + Vector2(0.0, s * 0.2),
				center + Vector2(s * 0.28, s * 0.8),
				center + Vector2(-s * 0.28, s * 0.8)
			])
			draw_colored_polygon(stem_pts, watermark_col)
		1: # ハート ♥
			var pts = PackedVector2Array([
				center + Vector2(-s * 0.65, -s * 0.1),
				center + Vector2(s * 0.65, -s * 0.1),
				center + Vector2(0.0, s * 0.8)
			])
			draw_colored_polygon(pts, watermark_col)
			draw_circle(center + Vector2(-s * 0.32, -s * 0.25), s * 0.36, watermark_col)
			draw_circle(center + Vector2(s * 0.32, -s * 0.25), s * 0.36, watermark_col)
		2: # ダイヤ ♦
			var pts = PackedVector2Array([
				center + Vector2(0.0, -s * 0.85),
				center + Vector2(s * 0.65, 0.0),
				center + Vector2(0.0, s * 0.85),
				center + Vector2(-s * 0.65, 0.0)
			])
			draw_colored_polygon(pts, watermark_col)
		3: # クラブ ♣
			draw_circle(center + Vector2(0.0, -s * 0.35), s * 0.34, watermark_col)
			draw_circle(center + Vector2(-s * 0.35, s * 0.15), s * 0.34, watermark_col)
			draw_circle(center + Vector2(s * 0.35, s * 0.15), s * 0.34, watermark_col)
			draw_circle(center, s * 0.25, watermark_col)
			var stem_pts = PackedVector2Array([
				center + Vector2(0.0, 0.0),
				center + Vector2(s * 0.28, s * 0.8),
				center + Vector2(-s * 0.28, s * 0.8)
			])
			draw_colored_polygon(stem_pts, watermark_col)
