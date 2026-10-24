extends Node2D
class_name CombatUIManager

const POPUP_POOL_SIZE = 32
const POPUP_DURATION = 0.9
const POPUP_FLOAT_DIST = -80.0
const MAX_ENEMY_POPUPS = 12

var popup_pool: Array[Label] = []
var enemy_popup_counts = {}

var player_hp_delay_bar: ColorRect
var custom_font = preload("res://font/g_comickoin_freeR.ttf")

## 属性別ダメージタグ・カラー・VFX定義
const DAMAGE_TYPE_INFO = {
	"ally_poison": {
		"tag": "(毒ダメージ)",
		"color": Color(0.2, 1.0, 0.55),
		"flash": Color(0.3, 2.5, 0.7),
		"vfx": "poison"
	},
	"poison": {
		"tag": "(毒ダメージ)",
		"color": Color(0.2, 1.0, 0.55),
		"flash": Color(0.3, 2.5, 0.7),
		"vfx": "poison"
	},
	"poison_mist": {
		"tag": "(毒ダメージ)",
		"color": Color(0.2, 1.0, 0.55),
		"flash": Color(0.3, 2.5, 0.7),
		"vfx": "poison"
	},
	"ally_poison_blade": {
		"tag": "(毒刃ダメージ)",
		"color": Color(0.2, 1.0, 0.65),
		"flash": Color(0.3, 2.5, 0.8),
		"vfx": "poison"
	},
	"player_skill_poison": {
		"tag": "(毒スキルダメージ)",
		"color": Color(0.2, 1.0, 0.55),
		"flash": Color(0.3, 2.5, 0.7),
		"vfx": "poison"
	},
	"ally_fire": {
		"tag": "(火傷ダメージ)",
		"color": Color(1.0, 0.45, 0.15),
		"flash": Color(2.5, 0.9, 0.3),
		"vfx": "fire"
	},
	"fire": {
		"tag": "(炎ダメージ)",
		"color": Color(1.0, 0.45, 0.15),
		"flash": Color(2.5, 0.9, 0.3),
		"vfx": "fire"
	},
	"bomb": {
		"tag": "(爆破ダメージ)",
		"color": Color(1.0, 0.45, 0.15),
		"flash": Color(2.5, 0.9, 0.3),
		"vfx": "fire"
	},
	"player_skill_fire": {
		"tag": "(炎スキルダメージ)",
		"color": Color(1.0, 0.45, 0.15),
		"flash": Color(2.5, 0.9, 0.3),
		"vfx": "fire"
	},
	"water": {
		"tag": "(水流ダメージ)",
		"color": Color(0.2, 0.75, 1.0),
		"flash": Color(0.4, 1.8, 2.8),
		"vfx": "water"
	},
	"aqua_splash": {
		"tag": "(水流ダメージ)",
		"color": Color(0.2, 0.75, 1.0),
		"flash": Color(0.4, 1.8, 2.8),
		"vfx": "water"
	},
	"player_skill_water": {
		"tag": "(水スキルダメージ)",
		"color": Color(0.2, 0.75, 1.0),
		"flash": Color(0.4, 1.8, 2.8),
		"vfx": "water"
	},
	"steam_synergy": {
		"tag": "(蒸気消去ダメージ)",
		"color": Color(0.4, 0.9, 1.0),
		"flash": Color(1.0, 2.2, 2.8),
		"vfx": "water"
	},
	"ice": {
		"tag": "(冷気ダメージ)",
		"color": Color(0.55, 0.95, 1.0),
		"flash": Color(0.6, 2.2, 2.8),
		"vfx": "ice"
	},
	"ice_shield": {
		"tag": "(冷気ダメージ)",
		"color": Color(0.55, 0.95, 1.0),
		"flash": Color(0.6, 2.2, 2.8),
		"vfx": "ice"
	},
	"player_skill_ice": {
		"tag": "(氷スキルダメージ)",
		"color": Color(0.55, 0.95, 1.0),
		"flash": Color(0.6, 2.2, 2.8),
		"vfx": "ice"
	},
	"shatter_synergy": {
		"tag": "(砕破ダメージ)",
		"color": Color(0.7, 0.92, 1.0),
		"flash": Color(1.2, 2.4, 2.8),
		"vfx": "ice"
	},
	"thunder": {
		"tag": "(雷撃ダメージ)",
		"color": Color(1.0, 0.92, 0.15),
		"flash": Color(2.8, 2.8, 0.5),
		"vfx": "thunder"
	},
	"lightning": {
		"tag": "(雷撃ダメージ)",
		"color": Color(1.0, 0.92, 0.15),
		"flash": Color(2.8, 2.8, 0.5),
		"vfx": "thunder"
	},
	"ally_electrified": {
		"tag": "(感電追撃)",
		"color": Color(1.0, 0.92, 0.2),
		"flash": Color(2.8, 2.8, 0.5),
		"vfx": "thunder"
	},
	"player_skill_thunder": {
		"tag": "(雷スキルダメージ)",
		"color": Color(1.0, 0.92, 0.15),
		"flash": Color(2.8, 2.8, 0.5),
		"vfx": "thunder"
	},
	"wood": {
		"tag": "(自然ダメージ)",
		"color": Color(0.35, 1.0, 0.4),
		"flash": Color(0.6, 2.6, 0.8),
		"vfx": "wood"
	},
	"tree_sprout": {
		"tag": "(自然ダメージ)",
		"color": Color(0.35, 1.0, 0.4),
		"flash": Color(0.6, 2.6, 0.8),
		"vfx": "wood"
	},
	"player_skill_wood": {
		"tag": "(木スキルダメージ)",
		"color": Color(0.35, 1.0, 0.4),
		"flash": Color(0.6, 2.6, 0.8),
		"vfx": "wood"
	},
	"wind": {
		"tag": "(風撃ダメージ)",
		"color": Color(0.25, 1.0, 0.8),
		"flash": Color(0.5, 2.4, 1.8),
		"vfx": "wind"
	},
	"tornado": {
		"tag": "(風撃ダメージ)",
		"color": Color(0.25, 1.0, 0.8),
		"flash": Color(0.5, 2.4, 1.8),
		"vfx": "wind"
	},
	"player_skill_wind": {
		"tag": "(風スキルダメージ)",
		"color": Color(0.25, 1.0, 0.8),
		"flash": Color(0.5, 2.4, 1.8),
		"vfx": "wind"
	},
	"earth": {
		"tag": "(地脈ダメージ)",
		"color": Color(1.0, 0.78, 0.25),
		"flash": Color(2.4, 1.8, 0.6),
		"vfx": "earth"
	},
	"charge_bomb": {
		"tag": "(地脈ダメージ)",
		"color": Color(1.0, 0.78, 0.25),
		"flash": Color(2.4, 1.8, 0.6),
		"vfx": "earth"
	},
	"player_skill_earth": {
		"tag": "(土スキルダメージ)",
		"color": Color(1.0, 0.78, 0.25),
		"flash": Color(2.4, 1.8, 0.6),
		"vfx": "earth"
	},
	"light": {
		"tag": "(聖光ダメージ)",
		"color": Color(1.0, 0.95, 0.45),
		"flash": Color(2.8, 2.6, 1.4),
		"vfx": "light"
	},
	"disco_ball": {
		"tag": "(聖光ダメージ)",
		"color": Color(1.0, 0.95, 0.45),
		"flash": Color(2.8, 2.6, 1.4),
		"vfx": "light"
	},
	"player_skill_light": {
		"tag": "(光スキルダメージ)",
		"color": Color(1.0, 0.95, 0.45),
		"flash": Color(2.8, 2.6, 1.4),
		"vfx": "light"
	},
	"dark": {
		"tag": "(闇ダメージ)",
		"color": Color(0.85, 0.35, 1.0),
		"flash": Color(1.8, 0.4, 2.5),
		"vfx": "dark"
	},
	"black_hole": {
		"tag": "(虚無ダメージ)",
		"color": Color(0.85, 0.35, 1.0),
		"flash": Color(1.8, 0.4, 2.5),
		"vfx": "dark"
	},
	"ally_dark_fog": {
		"tag": "(暗雲ダメージ)",
		"color": Color(0.85, 0.35, 1.0),
		"flash": Color(1.8, 0.4, 2.5),
		"vfx": "dark"
	},
	"ally_drain": {
		"tag": "(影護吸収)",
		"color": Color(0.85, 0.4, 1.0),
		"flash": Color(1.8, 0.5, 2.5),
		"vfx": "dark"
	},
	"player_skill_dark": {
		"tag": "(闇スキルダメージ)",
		"color": Color(0.85, 0.35, 1.0),
		"flash": Color(1.8, 0.4, 2.5),
		"vfx": "dark"
	},
	"sword": {
		"tag": "(剣撃ダメージ)",
		"color": Color(1.0, 1.0, 1.0),
		"flash": Color(2.2, 2.0, 2.0),
		"vfx": "sword"
	},
	"physical": {
		"tag": "(剣撃ダメージ)",
		"color": Color(1.0, 1.0, 1.0),
		"flash": Color(2.2, 2.0, 2.0),
		"vfx": "sword"
	},
	"": {
		"tag": "(剣撃ダメージ)",
		"color": Color(1.0, 1.0, 1.0),
		"flash": Color(2.2, 2.0, 2.0),
		"vfx": "sword"
	}
}

const ELEMENT_COLORS = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.3, 0.6, 1.0),
	"wind": Color(0.4, 0.9, 0.4),
	"thunder": Color(0.9, 0.9, 0.2),
	"ice": Color(0.6, 0.9, 1.0),
	"light": Color(1.0, 0.9, 0.6),
	"dark": Color(0.7, 0.3, 0.9)
}

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
		lbl.reset_size()
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
		blbl.reset_size()
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
	lbl.reset_size()
	
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

func _get_elem_jp_name(elem: String) -> String:
	match elem:
		"fire": return "炎"
		"water": return "水"
		"ice": return "氷"
		"thunder": return "雷"
		"wood": return "木"
		"wind": return "風"
		"earth": return "土"
		"poison": return "毒"
		"light": return "光"
		"dark": return "闇"
		_: return elem

## 敵被弾時：ダメージ数値を明示タグ付きで表示し、属性ごとのわかりやすいエフェクトを発生
func _show_enemy_damage(amount: float, enemy_node: Node, is_crit: bool, element: String, effectiveness: String = "normal") -> void:
	if amount <= 0 or not is_instance_valid(enemy_node): return

	var e_id = enemy_node.get_instance_id()
	if not enemy_popup_counts.has(e_id): enemy_popup_counts[e_id] = 0

	if enemy_popup_counts[e_id] >= MAX_ENEMY_POPUPS:
		return

	enemy_popup_counts[e_id] += 1

	var info = DAMAGE_TYPE_INFO.get(element, null)
	if info == null:
		if element.begins_with("player_skill_"):
			var sub_elem = element.replace("player_skill_", "")
			var sub_info = DAMAGE_TYPE_INFO.get(sub_elem, {})
			info = {
				"tag": "(%sスキルダメージ)" % _get_elem_jp_name(sub_elem),
				"color": sub_info.get("color", Color(1.0, 0.6, 0.2)),
				"flash": sub_info.get("flash", Color(2.2, 1.8, 1.8)),
				"vfx": sub_info.get("vfx", sub_elem)
			}
		else:
			var tag_name = "(剣撃ダメージ)" if (element == "" or element == "none" or element == "physical" or element == "sword") else "(%sダメージ)" % element
			info = {
				"tag": tag_name,
				"color": Color.WHITE,
				"flash": Color(2.0, 1.8, 1.8),
				"vfx": "sword"
			}

	var tag_str: String = info["tag"]
	var c: Color = info["color"]

	var lbl = _get_free_label()
	if effectiveness == "weak":
		lbl.text = "WEAK!
%d
%s" % [int(amount), tag_str]
		c = Color(1.0, 0.35, 0.35)
	elif effectiveness == "resist":
		lbl.text = "RESIST
%d
%s" % [int(amount), tag_str]
		c = Color(0.65, 0.65, 0.65)
	elif is_crit:
		lbl.text = "CRITICAL!
%d
%s" % [int(amount), tag_str]
		c = Color(1.0, 0.85, 0.2)
	else:
		lbl.text = "%d
%s" % [int(amount), tag_str]

	lbl.add_theme_color_override("font_color", c)
	lbl.add_theme_font_size_override("font_size", 52 if is_crit else 40)
	lbl.scale = Vector2.ONE
	lbl.modulate = Color.WHITE
	lbl.visible = true
	lbl.reset_size()

	var start_pos = to_local(enemy_node.global_position)
	start_pos.x += randf_range(-40, 40)
	start_pos.y += randf_range(-50, 10)
	lbl.position = start_pos - lbl.size / 2

	# 敵スプライトの属性別カラーフラッシュ
	if is_instance_valid(enemy_node) and enemy_node is Sprite2D:
		var flash_col = info.get("flash", Color(2.0, 1.8, 1.8))
		if enemy_node.has_meta("dmg_tw"):
			var old_tw = enemy_node.get_meta("dmg_tw")
			if is_instance_valid(old_tw) and old_tw is Tween:
				old_tw.kill()
		var tw_flash = create_tween()
		enemy_node.set_meta("dmg_tw", tw_flash)
		enemy_node.modulate = flash_col
		tw_flash.tween_property(enemy_node, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 敵被弾位置での属性ビジュアルエフェクトの発生
	var vfx_type = info.get("vfx", "sword")
	var vfx_node = EnemyHitEffectNode.new(vfx_type, info["color"], info.get("flash", Color.WHITE), 0.45)
	vfx_node.position = to_local(enemy_node.global_position)
	add_child(vfx_node)

	var tw = create_tween()
	lbl.set_meta("tw", tw)
	if is_crit:
		lbl.scale = Vector2(1.35, 1.35)
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var dur = POPUP_DURATION * (1.2 if is_crit else 1.0)
	tw.parallel().tween_property(lbl, "position", lbl.position + Vector2(0, POPUP_FLOAT_DIST * 1.5), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	tw.tween_callback(func():
		lbl.visible = false
		if enemy_popup_counts.has(e_id): enemy_popup_counts[e_id] -= 1
	)

## 属性別・敵被弾ビジュアルエフェクト描画ノード
class EnemyHitEffectNode extends Node2D:
	var vfx_type: String = "sword"
	var duration: float = 0.45
	var elapsed: float = 0.0
	var particles: Array[Dictionary] = []
	var primary_color: Color = Color.WHITE
	var secondary_color: Color = Color.YELLOW

	func _init(type: String, p_color: Color, s_color: Color, dur: float = 0.45) -> void:
		vfx_type = type
		primary_color = p_color
		secondary_color = s_color
		duration = dur
		z_index = 50

		var count = 12
		for i in range(count):
			var ang = randf() * TAU
			var spd = randf_range(35.0, 120.0)
			particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(ang), sin(ang)) * spd,
				"size": randf_range(4.0, 9.0),
				"rot": randf() * TAU,
				"rot_spd": randf_range(-6.0, 6.0)
			})

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= duration:
			set_process(false)
			queue_free()
			return

		for p in particles:
			p["pos"] += p["vel"] * delta
			p["rot"] += p["rot_spd"] * delta
			if vfx_type == "water":
				p["vel"].y += 240.0 * delta # 水滴の重力落下
			elif vfx_type == "poison" or vfx_type == "fire":
				p["vel"].y -= 90.0 * delta # 煙・泡の上昇
				p["vel"].x += sin(elapsed * 10.0 + p["rot"]) * 25.0 * delta

		queue_redraw()

	func _draw() -> void:
		var progress = clampf(elapsed / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		match vfx_type:
			"poison":
				_draw_poison_vfx(progress, alpha)
			"fire":
				_draw_fire_vfx(progress, alpha)
			"thunder":
				_draw_thunder_vfx(progress, alpha)
			"ice":
				_draw_ice_vfx(progress, alpha)
			"water":
				_draw_water_vfx(progress, alpha)
			"wind":
				_draw_wind_vfx(progress, alpha)
			"wood":
				_draw_wood_vfx(progress, alpha)
			"earth":
				_draw_earth_vfx(progress, alpha)
			"light":
				_draw_light_vfx(progress, alpha)
			"dark":
				_draw_dark_vfx(progress, alpha)
			_:
				_draw_sword_vfx(progress, alpha)

	func _draw_poison_vfx(progress: float, alpha: float) -> void:
		# 1. 拡散する毒素衝撃波リング（緑と紫の鮮明な輪）
		var ring_r = lerpf(8.0, 60.0, progress)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 24, Color(0.2, 1.0, 0.5, alpha * 0.8), lerpf(6.0, 1.0, progress))
		draw_arc(Vector2.ZERO, ring_r * 0.7, 0, TAU, 18, Color(0.7, 0.2, 0.9, alpha * 0.6), lerpf(4.0, 1.0, progress))

		# 2. 弾ける毒泡・毒滴パーティクル
		for i in range(particles.size()):
			var p = particles[i]
			var bubble_col = Color(0.2, 1.0, 0.5, alpha * 0.9) if (i % 2 == 0) else Color(0.75, 0.25, 0.95, alpha * 0.85)
			var cur_s = p["size"] * (1.0 - progress * 0.4)
			draw_circle(p["pos"], cur_s, bubble_col)
			draw_circle(p["pos"] + Vector2(-cur_s * 0.3, -cur_s * 0.3), cur_s * 0.25, Color(1.0, 1.0, 1.0, alpha * 0.95))

		# 3. 立ち上る毒蒸気
		for k in range(3):
			var vy = -progress * 55.0 - k * 8.0
			var vx = sin(progress * 12.0 + k * 2.0) * 16.0
			draw_arc(Vector2(vx, vy), 12.0 * (1.0 - progress * 0.5), 0, TAU, 16, Color(0.3, 1.0, 0.6, alpha * 0.5), 2.5)

	func _draw_fire_vfx(progress: float, alpha: float) -> void:
		var ring_r = lerpf(12.0, 70.0, progress)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 24, Color(1.0, 0.4, 0.1, alpha * 0.85), lerpf(8.0, 1.5, progress))
		for p in particles:
			var flame_col = Color(1.0, lerpf(0.9, 0.2, progress), 0.1, alpha * 0.9)
			draw_circle(p["pos"], p["size"] * (1.0 - progress * 0.5), flame_col)
			draw_line(p["pos"], p["pos"] - p["vel"].normalized() * (10.0 * (1.0 - progress)), Color(1.0, 0.85, 0.2, alpha * 0.7), 2.5)

	func _draw_thunder_vfx(progress: float, alpha: float) -> void:
		var ring_r = lerpf(15.0, 75.0, progress)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 24, Color(1.0, 0.95, 0.2, alpha * 0.9), lerpf(6.0, 1.0, progress))
		for i in range(4):
			var ang = i * (PI * 0.5) + randf_range(-0.2, 0.2)
			var b_len = lerpf(20.0, 65.0, progress)
			var mid1 = Vector2(cos(ang + 0.3), sin(ang + 0.3)) * (b_len * 0.4)
			var mid2 = Vector2(cos(ang - 0.2), sin(ang - 0.2)) * (b_len * 0.7)
			var b_end = Vector2(cos(ang), sin(ang)) * b_len
			var pts = PackedVector2Array([Vector2.ZERO, mid1, mid2, b_end])
			draw_polyline(pts, Color(1.0, 1.0, 0.8, alpha), 3.0)
			draw_polyline(pts, Color(1.0, 0.9, 0.2, alpha * 0.5), 6.0)

	func _draw_ice_vfx(progress: float, alpha: float) -> void:
		var ring_r = lerpf(10.0, 60.0, progress)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 6, Color(0.5, 0.92, 1.0, alpha * 0.8), 3.0)
		for p in particles:
			var s = p["size"] * (1.0 - progress * 0.4)
			var rot = p["rot"]
			var pts = PackedVector2Array([
				p["pos"] + Vector2(0, -s).rotated(rot),
				p["pos"] + Vector2(s * 0.6, 0).rotated(rot),
				p["pos"] + Vector2(0, s).rotated(rot),
				p["pos"] + Vector2(-s * 0.6, 0).rotated(rot),
				p["pos"] + Vector2(0, -s).rotated(rot)
			])
			draw_colored_polygon(pts, Color(0.65, 0.95, 1.0, alpha * 0.9))
			draw_polyline(pts, Color.WHITE, 1.5)

	func _draw_water_vfx(progress: float, alpha: float) -> void:
		var ring_r = lerpf(10.0, 65.0, progress)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 24, Color(0.2, 0.75, 1.0, alpha * 0.8), lerpf(6.0, 1.0, progress))
		draw_arc(Vector2.ZERO, ring_r * 0.6, 0, TAU, 18, Color(0.6, 0.9, 1.0, alpha * 0.6), 2.5)
		for p in particles:
			var s = p["size"] * (1.0 - progress * 0.4)
			draw_circle(p["pos"], s, Color(0.2, 0.7, 1.0, alpha * 0.85))
			draw_circle(p["pos"] + Vector2(-s * 0.3, -s * 0.3), s * 0.3, Color.WHITE)

	func _draw_wind_vfx(progress: float, alpha: float) -> void:
		for i in range(3):
			var ang = progress * 6.0 + i * (TAU / 3.0)
			var r = lerpf(15.0, 65.0, progress)
			draw_arc(Vector2.ZERO, r, ang, ang + PI * 0.5, 12, Color(0.25, 1.0, 0.8, alpha * 0.9), 3.5)
		for p in particles:
			draw_circle(p["pos"], p["size"] * (1.0 - progress * 0.5), Color(0.4, 1.0, 0.85, alpha * 0.8))

	func _draw_wood_vfx(progress: float, alpha: float) -> void:
		var ring_r = lerpf(10.0, 60.0, progress)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 24, Color(0.35, 1.0, 0.4, alpha * 0.75), 3.0)
		for p in particles:
			var s = p["size"] * (1.0 - progress * 0.4)
			var rot = p["rot"]
			var pts = PackedVector2Array([
				p["pos"] + Vector2(0, -s * 1.3).rotated(rot),
				p["pos"] + Vector2(s * 0.8, 0).rotated(rot),
				p["pos"] + Vector2(0, s * 0.5).rotated(rot),
				p["pos"] + Vector2(-s * 0.8, 0).rotated(rot)
			])
			draw_colored_polygon(pts, Color(0.35, 1.0, 0.4, alpha * 0.9))

	func _draw_earth_vfx(progress: float, alpha: float) -> void:
		var ring_r = lerpf(12.0, 65.0, progress)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 20, Color(0.9, 0.7, 0.25, alpha * 0.8), lerpf(6.0, 1.5, progress))
		for p in particles:
			var s = p["size"] * (1.0 - progress * 0.3)
			var rot = p["rot"]
			var pts = PackedVector2Array([
				p["pos"] + Vector2(-s, -s).rotated(rot),
				p["pos"] + Vector2(s * 0.8, -s * 0.6).rotated(rot),
				p["pos"] + Vector2(s, s * 0.9).rotated(rot),
				p["pos"] + Vector2(-s * 0.5, s).rotated(rot)
			])
			draw_colored_polygon(pts, Color(1.0, 0.78, 0.25, alpha * 0.9))
			draw_polyline(pts, Color(0.4, 0.25, 0.1, alpha * 0.8), 1.5)

	func _draw_light_vfx(progress: float, alpha: float) -> void:
		draw_circle(Vector2.ZERO, lerpf(20.0, 3.0, progress), Color(1.0, 1.0, 0.9, alpha * 0.95))
		for i in range(8):
			var ang = i * (TAU / 8.0)
			var dir = Vector2(cos(ang), sin(ang))
			draw_line(Vector2.ZERO, dir * lerpf(15.0, 70.0, progress), Color(1.0, 0.95, 0.5, alpha * 0.9), lerpf(5.0, 1.0, progress))

	func _draw_dark_vfx(progress: float, alpha: float) -> void:
		draw_circle(Vector2.ZERO, 15.0 * (1.0 - progress), Color(0.05, 0.0, 0.1, alpha * 0.95))
		draw_arc(Vector2.ZERO, lerpf(10.0, 65.0, progress), elapsed * 6.0, elapsed * 6.0 + PI * 1.5, 20, Color(0.85, 0.35, 1.0, alpha * 0.85), 4.5)
		for p in particles:
			draw_circle(p["pos"], p["size"] * (1.0 - progress * 0.5), Color(0.7, 0.2, 0.95, alpha * 0.8))

	func _draw_sword_vfx(progress: float, alpha: float) -> void:
		draw_line(Vector2(-35, -25) * (1.0 - progress * 0.2), Vector2(35, 25) * (1.0 - progress * 0.2), Color(1.0, 1.0, 1.0, alpha * 0.95), lerpf(6.0, 1.0, progress))
		for p in particles:
			draw_line(p["pos"], p["pos"] + p["vel"].normalized() * (8.0 * (1.0 - progress)), Color(1.0, 0.9, 0.4, alpha * 0.9), 2.5)
