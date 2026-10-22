extends Node2D
class_name CombatUIManager

const POPUP_POOL_SIZE = 16
const POPUP_DURATION = 0.9
const POPUP_FLOAT_DIST = -80.0
const MAX_ENEMY_POPUPS = 8

var popup_pool: Array[Label] = []
var enemy_popup_counts = {}

var player_hp_delay_bar: ColorRect
var custom_font = preload("res://font/g_comickoin_freeR.ttf")

func _ready() -> void:
	scale = Vector2(10.0, 10.0)
	z_index = 4000
	for i in range(POPUP_POOL_SIZE):
		var lbl = Label.new()
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", custom_font)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(lbl)
		popup_pool.append(lbl)

	call_deferred("_init_player_delay_bar")

func _init_player_delay_bar() -> void:
	var sm = get_node_or_null("../../ScoreManager")
	if not sm: return
	var hpbar1 = sm.get_node_or_null("hpbar1") as ColorRect
	if not hpbar1: return
	
	player_hp_delay_bar = ColorRect.new()
	player_hp_delay_bar.name = "player_hp_delay_bar"
	player_hp_delay_bar.color = Color(1.0, 0.9, 0.2, 1.0)
	player_hp_delay_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hp_delay_bar.z_index = hpbar1.z_index - 1
	player_hp_delay_bar.position = hpbar1.position
	player_hp_delay_bar.size = hpbar1.size
	sm.add_child(player_hp_delay_bar)
	sm.move_child(player_hp_delay_bar, hpbar1.get_index())

func _on_combat_event(event: Dictionary) -> void:
	if event.type == "damage":
		if typeof(event.target) == TYPE_STRING and event.target == "ally":
			_show_player_damage(event.amount, event.get("element", ""), event.get("blocked_amount", 0.0))
		elif event.target is Node:
			_show_enemy_damage(event.amount, event.target, event.get("is_critical", false), event.get("element", ""), event.get("effectiveness", "normal"))
	elif event.type == "heal":
		if typeof(event.target) == TYPE_STRING and event.target == "ally":
			_show_player_heal(event.amount)

func _get_free_label() -> Label:
	var fallback = popup_pool[0]
	for lbl in popup_pool:
		if not lbl.visible:
			fallback = lbl
			break
	if fallback.has_meta("tw"):
		var old_tw = fallback.get_meta("tw")
		if is_instance_valid(old_tw): old_tw.kill()
	return fallback
const ELEMENT_COLORS = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.3, 0.6, 1.0),
	"wind": Color(0.4, 0.9, 0.4),
	"thunder": Color(0.9, 0.9, 0.2),
	"ice": Color(0.6, 0.9, 1.0),
	"light": Color(1.0, 0.9, 0.6),
	"dark": Color(0.7, 0.3, 0.9)
}

func _show_player_damage(amount: float, element: String = "", blocked: float = 0.0) -> void:
	if amount <= 0 and blocked <= 0: return
	
	var start_pos = Vector2(1190 + 360, 412 - 40)
	var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect
	if hpbar1:
		start_pos = to_local(hpbar1.global_position)
		start_pos.x += hpbar1.size.x / 2.0
		
	if amount > 0:
		var lbl = _get_free_label()
		lbl.text = str(int(amount)) + " DMG"
		var c = Color(1.0, 0.3, 0.3)
		if ELEMENT_COLORS.has(element): c = ELEMENT_COLORS[element]
		lbl.add_theme_color_override("font_color", c)
		lbl.add_theme_font_size_override("font_size", 56)
		lbl.scale = Vector2.ONE
		lbl.modulate = Color.WHITE
		lbl.visible = true
		lbl.position = start_pos - lbl.size / 2 + Vector2(randf_range(-50, 50), 0)
		var tw = create_tween()
		lbl.set_meta("tw", tw)
		tw.tween_property(lbl, "position", lbl.position + Vector2(0, POPUP_FLOAT_DIST), POPUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, POPUP_DURATION * 0.5).set_delay(POPUP_DURATION * 0.5)
		tw.tween_callback(func(): lbl.visible = false)
		
	if blocked > 0:
		var blbl = _get_free_label()
		blbl.text = "BLOCKED " + str(int(blocked))
		blbl.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
		blbl.add_theme_font_size_override("font_size", 42)
		blbl.scale = Vector2.ONE
		blbl.modulate = Color.WHITE
		blbl.visible = true
		blbl.position = start_pos - blbl.size / 2 + Vector2(randf_range(-50, 50), -50)
		var btw = create_tween()
		blbl.set_meta("tw", btw)
		btw.tween_property(blbl, "position", blbl.position + Vector2(0, POPUP_FLOAT_DIST), POPUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		btw.parallel().tween_property(blbl, "modulate:a", 0.0, POPUP_DURATION * 0.5).set_delay(POPUP_DURATION * 0.5)
		btw.tween_callback(func(): blbl.visible = false)
	if is_instance_valid(player_hp_delay_bar):
		var sm_mgr = get_node_or_null("../../StageManager")
		if sm_mgr and sm_mgr.has_method("displayhp"):
			sm_mgr.displayhp()
		if hpbar1:
			var target_w = hpbar1.size.x
			var old_w = player_hp_delay_bar.size.x
			if old_w > target_w:
				player_hp_delay_bar.color = Color(1.0, 0.9, 0.2, 1.0)
				if player_hp_delay_bar.has_meta("tw"):
					var old_tw = player_hp_delay_bar.get_meta("tw")
					if is_instance_valid(old_tw) and old_tw is Tween:
						old_tw.kill()
				var bar_tw = create_tween()
				player_hp_delay_bar.set_meta("tw", bar_tw)
				bar_tw.tween_interval(0.2)
				bar_tw.tween_property(player_hp_delay_bar, "size:x", float(target_w), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				bar_tw.tween_callback(func():
					if is_instance_valid(player_hp_delay_bar) and is_instance_valid(hpbar1):
						player_hp_delay_bar.size.x = hpbar1.size.x
				)
			else:
				if player_hp_delay_bar.has_meta("tw"):
					var old_tw = player_hp_delay_bar.get_meta("tw")
					if is_instance_valid(old_tw) and old_tw is Tween:
						old_tw.kill()
				player_hp_delay_bar.size.x = target_w

func _show_player_heal(amount: float) -> void:
	if amount <= 0: return
	var lbl = _get_free_label()
	lbl.text = "+" + str(int(amount))
	lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.scale = Vector2.ONE
	lbl.modulate = Color.WHITE
	lbl.visible = true
	
	var start_pos = Vector2(1190 + 360, 412 - 40)
	var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect
	if hpbar1:
		start_pos = to_local(hpbar1.global_position)
		start_pos.x += hpbar1.size.x / 2.0
	start_pos.x += randf_range(-50, 50)
	lbl.position = start_pos - lbl.size / 2
	
	var tw = create_tween()
	lbl.set_meta("tw", tw)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, POPUP_FLOAT_DIST), POPUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, POPUP_DURATION * 0.5).set_delay(POPUP_DURATION * 0.5)
	tw.tween_callback(func(): lbl.visible = false)
	
	if is_instance_valid(player_hp_delay_bar):
		var sm_mgr = get_node_or_null("../../StageManager")
		if sm_mgr and sm_mgr.has_method("displayhp"):
			sm_mgr.displayhp()
		if hpbar1:
			var target_w = hpbar1.size.x
			if player_hp_delay_bar.has_meta("tw"):
				var old_tw = player_hp_delay_bar.get_meta("tw")
				if is_instance_valid(old_tw) and old_tw is Tween:
					old_tw.kill()
			player_hp_delay_bar.size.x = target_w
			
			if hpbar1.has_meta("tw"):
				var old_tw = hpbar1.get_meta("tw")
				if is_instance_valid(old_tw): old_tw.kill()
			hpbar1.color = Color(0.5, 1.0, 0.5, 1.0)
			var bar_tw = create_tween()
			hpbar1.set_meta("tw", bar_tw)
			bar_tw.tween_property(hpbar1, "color", Color(0, 0.9, 0.3, 1.0), 0.5)
func _show_enemy_damage(amount: float, enemy_node: Node, is_crit: bool, element: String, effectiveness: String = "normal") -> void:
	if amount <= 0 or not is_instance_valid(enemy_node): return

	var e_id = enemy_node.get_instance_id()
	if not enemy_popup_counts.has(e_id): enemy_popup_counts[e_id] = 0

	if enemy_popup_counts[e_id] >= MAX_ENEMY_POPUPS:
		return

	enemy_popup_counts[e_id] += 1

	var lbl = _get_free_label()
	lbl.text = str(int(amount)) + " DMG"

	var c = Color(1.0, 1.0, 1.0)
	
	if effectiveness == "weak":
		c = Color(1.0, 0.3, 0.3)
		lbl.text = "WEAK
" + lbl.text
	elif effectiveness == "resist":
		c = Color(0.5, 0.5, 0.5)
		lbl.text = "RESIST
" + lbl.text
	else:
		if ELEMENT_COLORS.has(element) and element != "none":
			c = ELEMENT_COLORS[element]
			
	if is_crit: c = Color(1.0, 0.8, 0.2)
	
	lbl.add_theme_color_override("font_color", c)
	lbl.add_theme_font_size_override("font_size", 64 if is_crit else 48)
	lbl.scale = Vector2.ONE
	lbl.modulate = Color.WHITE
	lbl.visible = true
	
	# to_local ensures it displays correctly within CombatUIManager's space
	var start_pos = to_local(enemy_node.global_position)
	start_pos.x += randf_range(-80, 80)
	start_pos.y += randf_range(-80, 20)
	lbl.position = start_pos - lbl.size / 2
	
	var tw = create_tween()
	lbl.set_meta("tw", tw)
	if is_crit:
		lbl.scale = Vector2(1.5, 1.5)
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	var dur = POPUP_DURATION * (1.2 if is_crit else 1.0)
	tw.parallel().tween_property(lbl, "position", lbl.position + Vector2(0, POPUP_FLOAT_DIST * 1.5), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	tw.tween_callback(func(): 
		lbl.visible = false
		if enemy_popup_counts.has(e_id): enemy_popup_counts[e_id] -= 1
	)
