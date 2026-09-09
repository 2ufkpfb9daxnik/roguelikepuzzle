extends Node2D
class_name SkillVFXNode

enum VFXMode {
	CHANT_CIRCLE,   # 敵詠唱魔法陣
	SPELL_BEAM,      # 敵から盤面への魔力ビーム
	BURST_RING,      # 盤面着弾時の衝撃波バースト
	DRAIN_STREAM     # プレイヤーから植物・敵への生命力吸収ストリーム
}

var mode: VFXMode = VFXMode.CHANT_CIRCLE
var elem_color: Color = Color.GOLD
var duration: float = 0.6
var elapsed: float = 0.0

# ビーム・吸収ストリーム用
var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var current_beam_pos: Vector2 = Vector2.ZERO
var beam_trail: Array[Vector2] = []
var arc_height: float = 0.0

# バースト用
var max_radius: float = 250.0

func _init(vfx_mode: VFXMode = VFXMode.CHANT_CIRCLE, color: Color = Color.GOLD, dur: float = 0.6) -> void:
	mode = vfx_mode
	elem_color = color
	duration = dur
	add_to_group("enemy_skill_vfx")

func _ready() -> void:
	z_index = 40

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return

	if mode == VFXMode.SPELL_BEAM or mode == VFXMode.DRAIN_STREAM:
		var progress = clampf(elapsed / duration, 0.0, 1.0)
		var t = progress * progress if mode == VFXMode.SPELL_BEAM else sin(progress * PI * 0.5)
		var arc_y = -sin(progress * PI) * arc_height if mode == VFXMode.DRAIN_STREAM else 0.0
		current_beam_pos = start_pos.lerp(target_pos, t) + Vector2(0, arc_y)
		beam_trail.push_back(current_beam_pos)
		var max_t_len = 10 if mode == VFXMode.DRAIN_STREAM else 8
		if beam_trail.size() > max_t_len:
			beam_trail.pop_front()

	queue_redraw()

func _draw() -> void:
	var progress = clampf(elapsed / duration, 0.0, 1.0)
	var alpha = (1.0 - progress)

	match mode:
		VFXMode.CHANT_CIRCLE:
			_draw_chant_circle(progress, alpha)
		VFXMode.SPELL_BEAM:
			_draw_spell_beam(progress, alpha)
		VFXMode.BURST_RING:
			_draw_burst_ring(progress, alpha)
		VFXMode.DRAIN_STREAM:
			_draw_drain_stream(progress, alpha)

## ① 敵詠唱魔法陣
func _draw_chant_circle(progress: float, alpha: float) -> void:
	var r = lerpf(40.0, 180.0, sin(progress * PI * 0.5))
	var c_main = Color(elem_color.r, elem_color.g, elem_color.b, alpha * 0.85)
	var c_core = Color(1.0, 1.0, 1.0, alpha * 0.95)
	
	# 外周円 & 内周円
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, c_main, 5.0)
	draw_arc(Vector2.ZERO, r * 0.65, -progress * 3.0, -progress * 3.0 + TAU, 28, c_main, 3.0)
	draw_arc(Vector2.ZERO, r * 0.35, progress * 4.0, progress * 4.0 + TAU, 20, c_core, 2.5)

	# 8方向スポーク線
	var spoke_rot = progress * 2.0
	for i in range(8):
		var ang = spoke_rot + i * (TAU / 8.0)
		var p1 = Vector2(cos(ang), sin(ang)) * (r * 0.35)
		var p2 = Vector2(cos(ang), sin(ang)) * r
		draw_line(p1, p2, c_main, 3.0)

	# 放射状の魔力粒子
	for i in range(12):
		var ang = i * (TAU / 12.0) - progress * 1.5
		var p_r = r * (0.5 + 0.5 * sin(progress * 8.0 + i))
		var pt = Vector2(cos(ang), sin(ang)) * p_r
		draw_circle(pt, 4.0 * (1.0 - progress), c_core)

## ② 敵から盤面への属性魔力ビーム・彗星弾頭
func _draw_spell_beam(progress: float, alpha: float) -> void:
	var c_main = Color(elem_color.r, elem_color.g, elem_color.b, 0.9)
	var c_core = Color.WHITE

	# トレイル（残像）
	for i in range(beam_trail.size() - 1):
		var t_alpha = float(i) / float(beam_trail.size())
		var t_col = Color(elem_color.r, elem_color.g, elem_color.b, t_alpha * 0.7)
		var width = lerpf(2.0, 18.0, t_alpha)
		draw_line(to_local(beam_trail[i]), to_local(beam_trail[i + 1]), t_col, width)

	# 先端の弾頭（魔力彗星）
	var local_head = to_local(current_beam_pos)
	draw_circle(local_head, 28.0, Color(elem_color.r, elem_color.g, elem_color.b, 0.35))
	draw_circle(local_head, 16.0, c_main)
	draw_circle(local_head, 8.0, c_core)

## ③ 盤面着弾バースト衝撃波
func _draw_burst_ring(progress: float, alpha: float) -> void:
	var cur_r = lerpf(20.0, max_radius, progress)
	var c_main = Color(elem_color.r, elem_color.g, elem_color.b, alpha * 0.8)
	var c_inner = Color(1.0, 1.0, 1.0, alpha * 0.9)

	# 外側衝撃波リング
	draw_arc(Vector2.ZERO, cur_r, 0.0, TAU, 48, c_main, lerpf(12.0, 2.0, progress))
	# 内側急速拡大リング
	if cur_r * 0.75 > 0:
		draw_arc(Vector2.ZERO, cur_r * 0.75, 0.0, TAU, 36, c_inner, lerpf(8.0, 1.0, progress))

	# 炸裂スパーク（多角放射線）
	var spark_count = 16
	for i in range(spark_count):
		var ang = i * (TAU / float(spark_count))
		var p1 = Vector2(cos(ang), sin(ang)) * (cur_r * 0.5)
		var p2 = Vector2(cos(ang), sin(ang)) * (cur_r * 1.15)
		draw_line(p1, p2, Color(elem_color.r, elem_color.g, elem_color.b, alpha * 0.6), 3.0)

## ④ プレイヤーから植物・敵へ飛翔する生命力吸収ストリーム
func _draw_drain_stream(progress: float, alpha: float) -> void:
	var c_main = Color(elem_color.r, elem_color.g, elem_color.b, 0.9 * alpha)
	var c_trail = Color(elem_color.r * 0.8, elem_color.g * 0.9, elem_color.b * 0.6, 0.6 * alpha)
	var c_core = Color(1.0, 1.0, 1.0, alpha)

	# トレイル（残像）
	for i in range(beam_trail.size() - 1):
		var t_ratio = float(i) / float(max(1, beam_trail.size() - 1))
		var w = lerpf(2.0, 12.0, t_ratio)
		var col = Color(c_trail.r, c_trail.g, c_trail.b, c_trail.a * t_ratio)
		draw_line(to_local(beam_trail[i]), to_local(beam_trail[i + 1]), col, w)

	# 先端の生命力オーブ
	var local_head = to_local(current_beam_pos)
	draw_circle(local_head, 18.0, Color(elem_color.r, elem_color.g, elem_color.b, 0.3 * alpha))
	draw_circle(local_head, 10.0, c_main)
	draw_circle(local_head, 5.0, c_core)

	# 周囲の小オーブ（2個旋回）
	var ang1 = elapsed * 14.0
	var orb1 = local_head + Vector2(cos(ang1), sin(ang1)) * 14.0
	draw_circle(orb1, 3.5, c_core)
	var ang2 = ang1 + PI
	var orb2 = local_head + Vector2(cos(ang2), sin(ang2)) * 14.0
	draw_circle(orb2, 3.5, c_main)
