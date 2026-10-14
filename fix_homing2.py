import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
end = -1
for i, line in enumerate(lines):
    if 'if t >= 0:' in line and 's.position.x +=' in lines[i+1]:
        start = i
    if start != -1 and 'item["t"] = t + 1.0' in line:
        end = i - 1
        break

new_code = '''		if t >= 0:
			var progress = clampf(t / 50.0, 0.0, 1.0)
			var ease_p = pow(progress, 2.0)
			var sp = item.get("start_pos", Vector2(12300, 5200))
			var tp = item.get("target_pos", Vector2(12300, 2700))
			var cp = item.get("control_pos", Vector2((sp.x + tp.x)/2.0, sp.y - 2000.0))
			
			var q0 = sp.lerp(cp, ease_p)
			var q1 = cp.lerp(tp, ease_p)
			s.position = q0.lerp(q1, ease_p)
			
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
					_sword_hit_sound_timer = SWORD_HIT_SOUND_INTERVAL
'''

lines = lines[:start] + new_code.split('\n') + lines[end:]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
