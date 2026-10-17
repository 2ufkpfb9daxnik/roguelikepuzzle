extends Node2D
class_name BoardBackground

## パズル盤面の背景、罫線（グリッド線）、外枠、および選択セルのハイライト描画

@export var board = null
@export var background_texture: Texture2D = null

const GRID_COLS: int = 10
const GRID_ROWS: int = 10
const CELL_PITCH: float = 750.0

const BOARD_LEFT: float = 4250.0
const BOARD_TOP: float = 1250.0
const BOARD_WIDTH: float = 7500.0   # 10 * 750
const BOARD_HEIGHT: float = 7500.0  # 10 * 750
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

	# 3.5 水浸しマス(grid_water)の描画はBackgroundEffectsOverlayNodeに移行しました

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

	# 5. 特殊アイテムの描画はBackgroundEffectsOverlayNodeに移行しました

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
