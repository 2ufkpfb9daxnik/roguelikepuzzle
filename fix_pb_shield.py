import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

# Add current_shield_pools dict
if 'var current_shield_pools: Dictionary = {}' not in text:
    text = text.replace('var current_total_shields: int = 0', 'var current_total_shields: int = 0\nvar current_shield_pools: Dictionary = {}')

# Update _spawn_shield_projectiles
old_shield = r'(func _spawn_shield_projectiles\(score_mgr: Node2D\) -> void:\s*if not score_mgr: return\s*var raw_shield_cnt: int = int\(score_mgr\.divscore\[PieceType\.SHIELD\] / \(shieldt \* 100\.0\)\)\s*score_mgr\.divscore\[PieceType\.SHIELD\] -= int\(raw_shield_cnt \* shieldt \* 100\.0\)\s*current_total_shields = raw_shield_cnt)'
new_shield = r'''func _spawn_shield_projectiles(score_mgr: Node2D) -> void:
	if not score_mgr: return
	var original_shield_score = score_mgr.divscore[PieceType.SHIELD]
	current_shield_pools.clear()
	
	if "turn_element_gain" in score_mgr and score_mgr.turn_element_gain.has(PieceType.SHIELD):
		var total_allocated = 0
		if original_shield_score > 0:
			for el in score_mgr.turn_element_gain[PieceType.SHIELD]:
				var el_score = score_mgr.turn_element_gain[PieceType.SHIELD][el]
				var count = float(el_score) / (shieldt * 100.0)
				current_shield_pools[el] = current_shield_pools.get(el, 0.0) + count
				total_allocated += el_score
		var remaining_score = max(0, original_shield_score - total_allocated)
		if remaining_score > 0:
			var r_count = float(remaining_score) / (shieldt * 100.0)
			current_shield_pools[0] = current_shield_pools.get(0, 0.0) + r_count
	else:
		var count = float(original_shield_score) / (shieldt * 100.0)
		current_shield_pools[0] = count
		
	var raw_shield_cnt: int = int(score_mgr.divscore[PieceType.SHIELD] / (shieldt * 100.0))
	score_mgr.divscore[PieceType.SHIELD] -= int(raw_shield_cnt * shieldt * 100.0)
	current_total_shields = raw_shield_cnt'''
text = re.sub(old_shield, new_shield, text)


# Update the enemy attack logic
old_atk = r'(var effective_shield_cnt: int = max\(current_total_shields, active_shields\.size\(\)\)\s*var incoming_damage = atk / float\(effective_shield_cnt \+ 1\))'
new_atk = r'''var effective_shield_cnt: float = 0.0
			for el in current_shield_pools:
				effective_shield_cnt += current_shield_pools[el]
			
			effective_shield_cnt = maxf(effective_shield_cnt, float(active_shields.size()))
			
			var e_name = e.get("key", e.get("name", "slime"))
			var atk_el = 0
			if sm: atk_el = ElementData.get_element_from_enemy_name(e_name, sm)
			
			var total_blocked = 0.0
			var remaining_atk = float(atk)
			
			if effective_shield_cnt > 0.0:
				var blocked_per_shield = (float(atk) - (float(atk) / (effective_shield_cnt + 1.0))) / effective_shield_cnt
				
				var shield_list = []
				for el in current_shield_pools:
					var count = current_shield_pools[el]
					if count <= 0.0: continue
					var mult = 1.0
					if el != 0 and atk_el != 0:
						mult = ElementData.get_damage_multiplier(atk_el, el)
					shield_list.append({"el": el, "count": count, "mult": mult})
				
				shield_list.sort_custom(func(a, b): return a["mult"] < b["mult"])
				
				for s_data in shield_list:
					var el = s_data["el"]
					var count = s_data["count"]
					var mult = s_data["mult"]
					
					var capacity = count * blocked_per_shield / mult
					var block_amount = min(remaining_atk, capacity)
					
					total_blocked += block_amount
					remaining_atk -= block_amount
					
					var consumed = (block_amount * mult) / blocked_per_shield if blocked_per_shield > 0 else 0
					current_shield_pools[el] -= consumed
					
					if remaining_atk <= 0.0:
						break
			
			var incoming_damage = maxf(0.0, remaining_atk)
			var event_payload = {"blocked_amount": total_blocked}'''
text = re.sub(old_atk, new_atk, text)

# Pass payload to _emit_combat_event
old_emit = r'(_emit_combat_event\("damage", "enemy", "ally", incoming_damage\))'
new_emit = r'_emit_combat_event("damage", "enemy", "ally", incoming_damage, "", false, "normal", event_payload)'
text = re.sub(old_emit, new_emit, text)

# Modify signature of _emit_combat_event to take dict
old_emit_sig = r'func _emit_combat_event\(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false, effectiveness: String = "normal"\) -> void:'
new_emit_sig = r'func _emit_combat_event(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false, effectiveness: String = "normal", extra: Dictionary = {}) -> void:'
text = text.replace(old_emit_sig, new_emit_sig)

# Add extra to event dict
old_emit_dict = r'("effectiveness": effectiveness\n\t\})'
new_emit_dict = r'''"effectiveness": effectiveness
	}
	for k in extra:
		event[k] = extra[k]'''
text = re.sub(old_emit_dict, new_emit_dict, text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
