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

new_anim2 = '''func _play_idle_loop() -> void:
	if active_enemies.size() == 0:
		return
	
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null
	if _rush_tween and _rush_tween.is_valid():
		_rush_tween.kill()
		_rush_tween = null

	var base_key = active_enemies[0]["key"]
	var base_anims = ENEMY_ANIMATION_SHEETS.get(base_key, {})
	var base_info = base_anims.get("idle", {"total_frames": 1, "fps": 1.0})
	var total_f: int = base_info.get("total_frames", 1)
	var fps: float = base_info.get("fps", 1.0)
	var duration = float(total_f) / maxf(1.0, fps)

	for e in active_enemies:
		var spr = e["sprite"]
		var e_key = e["key"]
		var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
		if not e_anims.has("idle"):
			continue
		
		var anim_info = e_anims["idle"]
		var sheet_path = anim_info.get("path", "")
		var sheet_tex: Texture2D = _get_anim_texture(sheet_path)
		if sheet_tex == null:
			continue

		var hf: int = anim_info["hframes"]
		var vf: int = anim_info["vframes"]
		var should_flip: bool = anim_info.get("flip_h", false)
		var scale_mult: float = anim_info.get("scale_mult", 1.0)
		var offset_pos: Vector2 = anim_info.get("offset", Vector2.ZERO)

		if is_instance_valid(spr):
			if not spr.has_meta("anim_orig_tex"):
				spr.set_meta("anim_orig_tex", spr.texture)
				spr.set_meta("anim_orig_scale", spr.get_meta("base_scale", spr.scale))
				spr.set_meta("anim_orig_pos", spr.position)
				
			var orig_tex = spr.get_meta("anim_orig_tex")
			var orig_s = spr.get_meta("anim_orig_scale")
			var orig_p = spr.get_meta("anim_orig_pos")
			
			var frame_w = sheet_tex.get_size().x / float(hf)
			var orig_w = orig_tex.get_size().x if orig_tex else frame_w
			var target_scale = orig_s * (float(orig_w) / float(frame_w)) * scale_mult
			
			spr.texture = sheet_tex
			spr.hframes = hf
			spr.vframes = vf
			spr.frame = 0
			spr.scale = target_scale
			spr.flip_h = should_flip
			spr.position = orig_p + offset_pos
			spr.material = _get_or_create_edge_fade_material()
			spr.set_meta("anim_total_f", anim_info.get("total_frames", 1))

	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_method(func(f_idx: int):
		if not is_playing_custom_animation:
			for e in active_enemies:
				var spr = e["sprite"]
				if is_instance_valid(spr) and spr.has_meta("anim_total_f"):
					var e_total_f = spr.get_meta("anim_total_f")
					# 各敵のフレーム数に合わせてループさせる（フレーム数が違っても対応）
					var e_frame = f_idx % e_total_f
					spr.frame = clampi(e_frame, 0, e_total_f - 1)
	, 0, total_f - 1, duration)'''


new_anim3 = '''func play_enemy_animation(anim_name: String, on_complete: Callable = Callable()) -> bool:
	if active_enemies.size() == 0:
		return false

	var base_key = active_enemies[0]["key"]
	var base_anims = ENEMY_ANIMATION_SHEETS.get(base_key, {})
	if not base_anims.has(anim_name):
		# 代表の敵がそのアニメを持っていなければキャンセル
		return false

	if anim_name == "damaged" and is_playing_custom_animation:
		if _current_custom_anim == "attack" or _current_custom_anim == "skill":
			return false
		if _anim_tween and _anim_tween.is_valid():
			_anim_tween.kill()
			_anim_tween = null

	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
	if _rush_tween and _rush_tween.is_valid():
		_rush_tween.kill()
		_rush_tween = null

	is_playing_custom_animation = true
	_current_custom_anim = anim_name

	var base_info = base_anims[anim_name]
	var total_f: int = base_info.get("total_frames", 1)
	var fps: float = base_info.get("fps", 1.0)
	var duration = float(total_f) / maxf(1.0, fps)

	var rush_in_dur: float = minf(0.24, duration * 0.3)
	var rush_out_dur: float = minf(0.22, duration * 0.25)
	var hold_dur: float = maxf(0.0, duration - rush_in_dur - rush_out_dur)
	var first = true
	if anim_name == "attack":
		_rush_tween = create_tween()

	for e in active_enemies:
		var spr = e["sprite"]
		var e_key = e["key"]
		var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
		var anim_info = e_anims.get(anim_name, base_info) # 持ってなければ代表の動きの長さだけ合わせる
		
		var sheet_path = anim_info.get("path", "")
		var sheet_tex: Texture2D = _get_anim_texture(sheet_path)
		
		if is_instance_valid(spr) and sheet_tex != null:
			var hf: int = anim_info["hframes"]
			var vf: int = anim_info["vframes"]
			var should_flip: bool = anim_info.get("flip_h", false)
			var scale_mult: float = anim_info.get("scale_mult", 1.0)
			var offset_pos: Vector2 = anim_info.get("offset", Vector2.ZERO)

			if not spr.has_meta("anim_orig_tex"):
				spr.set_meta("anim_orig_tex", spr.texture)
				spr.set_meta("anim_orig_scale", spr.get_meta("base_scale", spr.scale))
				spr.set_meta("anim_orig_pos", spr.position)
			
			var orig_tex = spr.get_meta("anim_orig_tex")
			var orig_s = spr.get_meta("anim_orig_scale")
			var orig_p = spr.get_meta("anim_orig_pos")
			var frame_w = sheet_tex.get_size().x / float(hf)
			var orig_w = orig_tex.get_size().x if orig_tex else frame_w
			var target_scale = orig_s * (float(orig_w) / float(frame_w)) * scale_mult
			
			spr.texture = sheet_tex
			spr.hframes = hf
			spr.vframes = vf
			spr.frame = 0
			spr.scale = target_scale
			spr.flip_h = should_flip
			spr.position = orig_p + offset_pos
			spr.material = _get_or_create_edge_fade_material()
			spr.set_meta("anim_total_f", anim_info.get("total_frames", 1))
			
			if anim_name == "attack" and _rush_tween:
				if first:
					_rush_tween.tween_property(spr, "scale", target_scale * 1.45, rush_in_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					if hold_dur > 0.0: _rush_tween.tween_interval(hold_dur)
					_rush_tween.tween_property(spr, "scale", target_scale, rush_out_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
					first = false
				else:
					_rush_tween.parallel().tween_property(spr, "scale", target_scale * 1.45, rush_in_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					if hold_dur > 0.0: _rush_tween.parallel().tween_interval(hold_dur)
					_rush_tween.parallel().tween_property(spr, "scale", target_scale, rush_out_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	if anim_name == "attack":
		_play_enemy_attack_rush_se()

	_anim_tween = create_tween()
	_anim_tween.tween_method(func(f_idx: int):
		for e in active_enemies:
			var spr = e["sprite"]
			if is_instance_valid(spr) and spr.has_meta("anim_total_f"):
				var e_total_f = spr.get_meta("anim_total_f")
				var e_frame = f_idx % e_total_f
				spr.frame = clampi(e_frame, 0, e_total_f - 1)
	, 0, total_f - 1, duration)

	_anim_tween.tween_callback(func():
		stop_enemy_animation()
		if on_complete.is_valid():
			on_complete.call()
	)
	return true'''


with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    content = replace_func(content, '_play_idle_loop', new_anim2)
    content = replace_func(content, 'play_enemy_animation', new_anim3)
    
    # 敵の配置間隔を狭める
    old_pos = '''			var base_x = 1550
			if initial_spawn_count == 2: base_x = 1400 + i * 300
			if initial_spawn_count == 3: base_x = 1250 + i * 300'''
    new_pos = '''			var base_x = 1550
			if initial_spawn_count == 2: base_x = 1425 + i * 250
			if initial_spawn_count == 3: base_x = 1310 + i * 240'''
    content = content.replace(old_pos, new_pos)
    
    # UIの幅を少し小さくし、中央寄せにする
    content = content.replace('lbl.size = Vector2(300, 50)', 'lbl.size = Vector2(240, 50)')
    content = content.replace('lbl.position = bar_bg.position + Vector2(-100, -45)', 'lbl.position = bar_bg.position + Vector2(-70, -45)')
    content = content.replace('hp_lbl.size = Vector2(300, 20)', 'hp_lbl.size = Vector2(240, 20)')
    content = content.replace('hp_lbl.position = bar_bg.position + Vector2(-100, 12)', 'hp_lbl.position = bar_bg.position + Vector2(-70, 12)')
    
    f.write(content)
