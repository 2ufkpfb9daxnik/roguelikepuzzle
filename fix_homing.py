import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re

# 1. Modify _spawn_attack_projectiles
spawn_regex = r'(for i in range\(spawn_sword_cnt\):\s*var s: Sprite2D = _get_sprite_from_pool\(\)\s*s\.texture = PIECE_TEXTURES\[PieceType\.SWORD\]\s*)s\.position = Vector2\(12300, 5300\)\s*s\.scale = Vector2\(2\.0, 2\.0\)\s*s\.visible = true\s*flying_swords\.append\(\{\s*"node": s,\s*"t": -float\(i \* 70\) / float\(max\(1, spawn_sword_cnt\)\),\s*"rnd": float\(randi\(\) % 120\),\s*"has_hit": false,\s*"damage": dmg_per_sword\s*\}\)'

new_spawn = r'''\1var target_pos = Vector2(12300.0 + float(randi() % 2000 - 1000), 2700.0)
		var active_en = sm.active_enemies if sm and "active_enemies" in sm else []
		if not active_en.is_empty():
			var e = active_en[randi() % active_en.size()]
			var spr = e.get("sprite")
			if is_instance_valid(spr):
				target_pos = self.to_local(spr.global_position)
		
		var start_x = float(randi() % 15000)
		var start_y = 5300.0
		var cp_x = (start_x + target_pos.x) / 2.0 + float(randi() % 6000 - 3000)
		var cp_y = min(start_y, target_pos.y) - float(randi() % 2000)
		
		s.position = Vector2(start_x, start_y)
		s.scale = Vector2(2.0, 2.0)
		s.visible = true
		flying_swords.append({
			"node": s,
			"t": -float(i * 70) / float(max(1, spawn_sword_cnt)),
			"start_pos": Vector2(start_x, start_y),
			"target_pos": target_pos,
			"control_pos": Vector2(cp_x, cp_y),
			"has_hit": false,
			"damage": dmg_per_sword
		})'''

text = re.sub(spawn_regex, new_spawn, text)

# 2. Modify update loop
update_regex = r'if t >= 0:\s*s\.position\.x \+= 10\.0 \+ rnd\s*s\.position\.y = -pow\(t, 2\) \+ 5200\.0\s*if s\.position\.y <= 2700\.0 and not item\.get\("has_hit", false\):\s*item\["has_hit"\] = true\s*if sm:\s*var dmg: float = item\.get\("damage", 100\.0 \* swordt\)\s*sm\.calchp\(dmg, 0\)\s*_emit_combat_event\("damage", "ally", "enemy", dmg\)\s*_spawn_hit_spark\(s\.position\)\s*if _sword_hit_sound_timer <= 0\.0:\s*_play_sword_hit_sound\(\)\s*_sword_hit_sound_timer = SWORD_HIT_SOUND_INTERVAL'

new_update = r'''if t >= 0:
			var progress = clampf(t / 50.0, 0.0, 1.0)
			var ease_p = pow(progress, 2.0)
			var sp = item.get("start_pos", Vector2(12300, 5200))
			var tp = item.get("target_pos", Vector2(12300, 2700))
			var cp = item.get("control_pos", Vector2((sp.x + tp.x)/2.0, sp.y - 2000.0))
			
			var q0 = sp.lerp(cp, ease_p)
			var q1 = cp.lerp(tp, ease_p)
			s.position = q0.lerp(q1, ease_p)
			
			# Rotate sword to point along velocity
			var next_q0 = sp.lerp(cp, ease_p + 0.05)
			var next_q1 = cp.lerp(tp, ease_p + 0.05)
			var next_pos = next_q0.lerp(next_q1, ease_p + 0.05)
			s.rotation = (next_pos - s.position).angle() + PI/2.0
			
			if progress >= 1.0 and not item.get("has_hit", false):
				item["has_hit"] = true
				if sm:
					var dmg: float = item.get("damage", 100.0 * swordt)
					sm.calchp(dmg, 0)
					_emit_combat_event("damage", "ally", "enemy", dmg)
				_spawn_hit_spark(s.position)
				if _sword_hit_sound_timer <= 0.0:
					_play_sword_hit_sound()
					_sword_hit_sound_timer = SWORD_HIT_SOUND_INTERVAL'''

text = re.sub(update_regex, new_update, text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
