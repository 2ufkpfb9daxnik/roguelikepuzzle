import codecs
import re

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

# _play_idle_loop を単一敵にも対応できるようにする
# または play_single_enemy_animation を追加
new_func = '''func play_single_enemy_animation(enemy_index: int, anim_name: String, on_complete: Callable = Callable()) -> bool:
	if enemy_index < 0 or enemy_index >= active_enemies.size():
		return false
	var e = active_enemies[enemy_index]
	var spr: Sprite2D = e["sprite"]
	var e_key = e["key"]
	var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
	if not e_anims.has(anim_name):
		return false

	if spr.has_meta("anim_tween"):
		var old_tw = spr.get_meta("anim_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()

	if spr.has_meta("rush_tween"):
		var old_tw = spr.get_meta("rush_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
			
	if spr.has_meta("idle_tween"):
		var old_tw = spr.get_meta("idle_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()

	var anim_info = e_anims[anim_name]
	var sheet_path = anim_info.get("path", "")
	var sheet_tex: Texture2D = _get_anim_texture(sheet_path)
	if sheet_tex == null or not is_instance_valid(spr):
		return false

	var hf: int = anim_info["hframes"]
	var vf: int = anim_info["vframes"]
	var total_f: int = anim_info.get("total_frames", 1)
	var fps: float = anim_info.get("fps", 1.0)
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

	var duration = float(total_f) / maxf(1.0, fps)
	
	if anim_name == "attack":
		var rush_tw = create_tween()
		spr.set_meta("rush_tween", rush_tw)
		rush_tw.bind_node(spr)
		var rush_in_dur = minf(0.24, duration * 0.3)
		var rush_out_dur = minf(0.22, duration * 0.25)
		var hold_dur = maxf(0.0, duration - rush_in_dur - rush_out_dur)
		
		rush_tw.tween_property(spr, "position", orig_p + Vector2(-60, 0) + offset_pos, rush_in_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		rush_tw.tween_interval(hold_dur)
		rush_tw.tween_property(spr, "position", orig_p + offset_pos, rush_out_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tw = create_tween()
	spr.set_meta("anim_tween", tw)
	tw.bind_node(spr)
	tw.tween_method(func(f_idx: int):
		if is_instance_valid(spr):
			spr.frame = clampi(f_idx, 0, total_f - 1)
	, 0, total_f - 1, duration)
	
	tw.tween_callback(func():
		if is_instance_valid(spr):
			spr.texture = orig_tex
			spr.hframes = 1
			spr.vframes = 1
			spr.frame = 0
			spr.scale = orig_s
			spr.flip_h = false
			spr.position = orig_p
			spr.material = null
			play_single_idle_loop(enemy_index)
		if on_complete:
			on_complete.call()
	)
	return true

func play_single_idle_loop(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= active_enemies.size():
		return
	var e = active_enemies[enemy_index]
	var spr: Sprite2D = e["sprite"]
	var e_key = e["key"]
	var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
	if not e_anims.has("idle"):
		return
		
	if spr.has_meta("idle_tween"):
		var old_tw = spr.get_meta("idle_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
			
	var anim_info = e_anims["idle"]
	var sheet_path = anim_info.get("path", "")
	var sheet_tex = _get_anim_texture(sheet_path)
	if not sheet_tex or not is_instance_valid(spr): return
	
	var hf: int = anim_info["hframes"]
	var vf: int = anim_info["vframes"]
	var total_f: int = anim_info["total_frames"]
	var fps: float = anim_info["fps"]
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

	var duration = float(total_f) / maxf(1.0, fps)
	var tw = create_tween().set_loops()
	spr.set_meta("idle_tween", tw)
	tw.bind_node(spr)
	tw.tween_method(func(f_idx: int):
		if is_instance_valid(spr):
			spr.frame = clampi(f_idx, 0, total_f - 1)
	, 0, total_f - 1, duration)
'''

content += "\n" + new_func

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)
