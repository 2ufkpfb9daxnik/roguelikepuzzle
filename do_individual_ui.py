import codecs
import re

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

def replace_func(content, func_name, new_body):
    pattern = r'(func ' + func_name + r'\b.*?\n)(?:(?:[ \t].*\n)|(?:^\s*\n))*'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return content[:match.start()] + new_body + '\n' + content[match.end():]
    return content

new_make_enemy = '''func make_enemy(spawn_as_boss: bool = false) -> void:
	if enemycount != 0: return
	stop_enemy_animation()
	_anim_original_texture = null
	_cleanup_battle_camera()
	var is_boss: bool = spawn_as_boss or (stage_enemy == 5)
	is_current_boss = is_boss
	if is_boss: stage_enemy = 5
	_set_buff_buttons_visible(false)
	if choose_buff_rect: choose_buff_rect.visible = false
	if move_front_btn: move_front_btn.visible = false
	var boss_bgm = get_node_or_null("bossbgm")
	var maou_bgm = get_node_or_null("maoubgm")
	var field_bgm = get_node_or_null("fieldbgm")
	if is_boss and stage == 5:
		if maou_bgm: maou_bgm.seek(0.0); maou_bgm.play()
	elif is_boss:
		if boss_bgm: boss_bgm.seek(0.0); boss_bgm.play()
	else:
		if field_bgm: field_bgm.seek(0.0); field_bgm.play()
	interval = 0
	var kemuri = get_parent().get_node_or_null("kemuri")
	if kemuri: kemuri.position = Vector2(1552.375, 210.125); kemuri.play()

	active_enemies.clear()
	ehp = 0.0
	ehpmax = 0.0
	enemyat = 0.0
	initial_spawn_count = 1 if is_boss else randi_range(1, 3)
	var pb = _get_puzzle_board()
	var first_color_set = false
	var stage_mult: float = pow(10.0, max(0, stage - 1))
	var stage_idx: int = clampi(stage - 1, 0, STAGE_ENEMIES.size() - 1)
	var enemy_info = STAGE_ENEMIES[stage_idx]
	
	for i in range(initial_spawn_count):
		var e_idx: int = 5 if is_boss else (randi() % 5)
		var ename: String = enemy_info["names"][e_idx]
		var r_hp: int = enemy_info["hp"][e_idx]
		var r_atk: int = enemy_info["atk"][e_idx]
		var sp_data = ENEMY_SPECIES.get(ename, {"name": ename, "element": "無属性", "race": "無属性", "color": "#FFFFFF"})
		var en: Sprite2D = null
		if ename in ENEMY_TEXTURES:
			var tex: Texture2D = _cached_enemy_textures.get(ename)
			if tex == null:
				tex = load(ENEMY_TEXTURES[ename]) as Texture2D
				_cached_enemy_textures[ename] = tex
			en = Sprite2D.new()
			en.name = "Enemy_" + str(i)
			en.texture = tex
			en.scale = Vector2(0.5, 0.5)
		else:
			var template_enemy = get_parent().get_child(0).get_node_or_null(ename)
			if template_enemy: en = template_enemy.duplicate()
		if en:
			en.set_meta("base_scale", en.scale)
			var base_x = 1550
			if initial_spawn_count == 2: base_x = 1400 + i * 300
			if initial_spawn_count == 3: base_x = 1250 + i * 300
			en.position = Vector2(base_x, 250)
			add_child(en)
			if ENEMY_ANIMATION_SHEETS.has(ename):
				var anims = ENEMY_ANIMATION_SHEETS[ename]
				for a_key in anims:
					var a_info = anims[a_key]
					var s_path = a_info.get("path", "")
					_get_anim_texture(s_path)
			if not first_color_set and pb:
				pb.set("encolor", en.modulate.r)
				current_enemy_key = ename
				first_color_set = true
			var e_hp = r_hp * stage_mult
			var e_atk = r_atk * stage_mult
			ehp += e_hp
			ehpmax += e_hp
			enemyat += e_atk
			
			var bar_bg = ColorRect.new()
			bar_bg.color = Color(0, 0, 0, 0.5)
			bar_bg.size = Vector2(100, 10)
			bar_bg.position = en.position + Vector2(-50, -100)
			add_child(bar_bg)
			var bar_fg = ColorRect.new()
			bar_fg.color = Color(1.0, 0.1, 0.1, 1.0)
			bar_fg.size = Vector2(100, 10)
			bar_fg.position = bar_bg.position
			add_child(bar_fg)
			var lbl = RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.fit_content = false
			lbl.scroll_active = false
			lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			lbl.add_theme_font_size_override("normal_font_size", 16)
			lbl.add_theme_font_size_override("bold_font_size", 16)
			lbl.add_theme_constant_override("outline_size", 4)
			lbl.add_theme_color_override("font_outline_color", Color(0,0,0,1))
			lbl.size = Vector2(240, 50)
			lbl.position = bar_bg.position + Vector2(-70, -45)
			var elem_raw = sp_data.get("element", sp_data.get("race", "無属性"))
			var elem_str = "/".join(elem_raw) if typeof(elem_raw) == TYPE_ARRAY else elem_raw
			var c_color = sp_data.get("color", "#FFFFFF")
			var boss_tag = "[color=#FF1744]☠ BOSS ☠[/color]\\n" if is_boss else ""
			lbl.text = "[center]" + boss_tag + "[color=" + c_color + "]" + elem_str + "[/color] " + sp_data["name"] + "[/center]"
			add_child(lbl)
			var hp_lbl = RichTextLabel.new()
			hp_lbl.bbcode_enabled = true
			hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hp_lbl.fit_content = false
			hp_lbl.scroll_active = false
			hp_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			hp_lbl.add_theme_font_size_override("normal_font_size", 16)
			hp_lbl.add_theme_constant_override("outline_size", 4)
			hp_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,1))
			hp_lbl.size = Vector2(100, 20)
			hp_lbl.position = bar_bg.position + Vector2(0, 12)
			hp_lbl.text = "[center][color=#FFFFFF]" + str(int(e_hp)) + "[/color][/center]"
			add_child(hp_lbl)
			active_enemies.append({
				"key": ename, "sprite": en, "hp": e_hp, "max_hp": e_hp, "atk": e_atk,
				"bar_bg": bar_bg, "bar_fg": bar_fg, "lbl": lbl, "hp_lbl": hp_lbl, "sp_data": sp_data
			})

	if active_enemies.size() > 0:
		enemy = active_enemies[0]["sprite"]
		start_enemy_idle_animation()
		
	# 右上の全体HPバーは使用しない
	if ehpbar != null and is_instance_valid(ehpbar): ehpbar.visible = false
	if ehpbar1 != null and is_instance_valid(ehpbar1): ehpbar1.visible = false

	ehppar = 1.0
	enemycount += 1'''

new_displayhp = '''func displayhp() -> void:
	for e in active_enemies:
		if is_instance_valid(e["bar_fg"]):
			var p = e["hp"] / e["max_hp"] if e["max_hp"] > 0 else 0
			e["bar_fg"].size = Vector2(p * 100.0, 10.0)
		if is_instance_valid(e["hp_lbl"]):
			var cur_hp_int = int(e["hp"])
			var last_hp = e.get("last_hp_int", -1)
			if cur_hp_int != last_hp:
				e["last_hp_int"] = cur_hp_int
				e["hp_lbl"].text = "[center][color=#FFFFFF]" + str(cur_hp_int) + " / " + str(int(e["max_hp"])) + "[/color][/center]"
				
	# 全体UIは非表示化
	if enemy_race_lbl != null and is_instance_valid(enemy_race_lbl):
		enemy_race_lbl.visible = false
	if enemy_hp_lbl != null and is_instance_valid(enemy_hp_lbl):
		enemy_hp_lbl.visible = false
	if ehpbar != null and is_instance_valid(ehpbar):
		ehpbar.visible = false
	if ehpbar1 != null and is_instance_valid(ehpbar1):
		ehpbar1.visible = false'''

content = replace_func(content, 'make_enemy', new_make_enemy)
content = replace_func(content, 'displayhp', new_displayhp)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)
