extends Node
class_name RelicManagerClass

const DEBUG_RELIC: bool = true
const RELIC_DAMAGE_BONUS_CAP: float = 2.0     # 与ダメージ加算合計上限 +200%
const RELIC_DAMAGE_REDUCTION_CAP: float = 0.5 # 被ダメージ軽減合計上限 50%

signal relic_triggered(relic_id: String)
signal relic_added(relic_id: String)
signal relic_leveled_up(relic_id: String, new_level: int)

# 所持データ: { "id": level(int) }
var owned_relics: Dictionary = {}
var temp_state: Dictionary = {}

func _process(_delta: float) -> void:
	if DEBUG_RELIC and Input.is_key_pressed(KEY_R) and Input.is_action_just_pressed("ui_accept"):
		for id in RelicDatabase.RELICS.keys():
			add_relic(id)
		print("DEBUG: Leveled up all relics! Current state: ", owned_relics)

func add_relic(id: String) -> void:
	if not RelicDatabase.RELICS.has(id):
		return
		
	var max_l = RelicDatabase.get_max_level(id)
	if not owned_relics.has(id):
		owned_relics[id] = 1
		print("Relic Added: ", id, " (Lv1)")
		emit_signal("relic_added", id)
	else:
		if owned_relics[id] < max_l:
			owned_relics[id] += 1
			print("Relic Leveled Up: ", id, " (Lv", owned_relics[id], ")")
			emit_signal("relic_leveled_up", id, owned_relics[id])
		else:
			print("Relic already at max level: ", id, " (Lv", owned_relics[id], ")")

func has_relic(id: String) -> bool:
	return owned_relics.has(id)

func get_level(id: String) -> int:
	return int(owned_relics.get(id, 0))

func is_max_level(id: String) -> bool:
	if not has_relic(id):
		return false
	return get_level(id) >= RelicDatabase.get_max_level(id)

func get_relics() -> Array[String]:
	var list: Array[String] = []
	for k in owned_relics.keys():
		list.append(str(k))
	return list

func get_relic_levels() -> Dictionary:
	return owned_relics.duplicate()

func get_param(id: String, key: String, default_val = null) -> Variant:
	var lvl = get_level(id)
	if lvl <= 0:
		return default_val
	var p = RelicDatabase.get_level_params(id, lvl)
	return p.get(key, default_val)

func reset_run() -> void:
	owned_relics.clear()
	if is_inside_tree() and get_tree():
		for c in get_tree().get_nodes_in_group("relic_ui"):
			c.queue_free()
	temp_state.clear()

# セーブ・ロード対応
func serialize_relics() -> Dictionary:
	return owned_relics.duplicate()

func deserialize_relics(data: Variant) -> void:
	owned_relics.clear()
	if data is Array:
		for item in data:
			var s_id = str(item)
			if RelicDatabase.RELICS.has(s_id):
				owned_relics[s_id] = 1
	elif data is Dictionary:
		for k in data.keys():
			var s_id = str(k)
			if RelicDatabase.RELICS.has(s_id):
				var max_lvl = RelicDatabase.get_max_level(s_id)
				var lvl = clampi(int(data[k]), 1, max_lvl)
				owned_relics[s_id] = lvl

func on_battle_start() -> void:
	temp_state["indomitable_heart_used_count"] = 0
	temp_state["soul_harvest_stacks"] = 0

func on_turn_start() -> void:
	temp_state["chain_ring_active"] = false
	temp_state["four_orb_damage"] = 0.0
	temp_state["special_detonation_count"] = 0
	temp_state["hazards_destroyed_count"] = 0
	temp_state["hazard_destroyed_by_kind"] = {}
	temp_state["backlash_damage_taken"] = 0.0
	temp_state["potions_cleared_this_turn"] = 0
	
	if has_relic("healing_drop"):
		var p = get_parent()
		if p:
			var sm = p.get_node_or_null("StageManager")
			if sm and "myhpmax" in sm and sm.myhpmax > 0:
				var heal_pct = float(get_param("healing_drop", "heal_percent", 0.02))
				var heal_val = sm.myhpmax * heal_pct
				if heal_val > 0:
					sm.calchp(0, -heal_val)
					emit_signal("relic_triggered", "healing_drop")
					var pb = p.get_node_or_null("PuzzleBoard")
					if pb and pb.has_method("_emit_combat_event"):
						pb._emit_combat_event("heal", "ally", "ally", heal_val)

	if has_relic("bloodstained_sword"):
		var p = get_parent()
		if p:
			var sm = p.get_node_or_null("StageManager")
			if sm and "myhpmax" in sm and sm.myhpmax > 0 and "myhp" in sm:
				var self_pct = float(get_param("bloodstained_sword", "self_damage_percent", 0.03))
				var raw_self_dmg = sm.myhpmax * self_pct
				# 自傷ダメージではHP0にならず最低HP1で止まり、不屈の心の復活回数も消費しない
				var actual_self_dmg = maxf(0.0, minf(raw_self_dmg, sm.myhp - 1.0))
				if actual_self_dmg > 0.0:
					sm.calchp(0, actual_self_dmg)
				emit_signal("relic_triggered", "bloodstained_sword")

## --- ステップ3 追加フック ---
func on_special_detonated(_type: int) -> void:
	temp_state["special_detonation_count"] = int(temp_state.get("special_detonation_count", 0)) + 1
	if has_relic("resonant_explosive") and int(temp_state["special_detonation_count"]) >= 2:
		emit_signal("relic_triggered", "resonant_explosive")

func on_hazard_destroyed(kind: String, count: int = 1) -> void:
	if count <= 0:
		return
	if kind in ["stone", "ice", "gold_statue"]:
		temp_state["hazards_destroyed_count"] = int(temp_state.get("hazards_destroyed_count", 0)) + count
		if has_relic("ruins_collector"):
			emit_signal("relic_triggered", "ruins_collector")
	var by_kind = temp_state.get("hazard_destroyed_by_kind", {}) as Dictionary
	by_kind[kind] = int(by_kind.get(kind, 0)) + count
	temp_state["hazard_destroyed_by_kind"] = by_kind

func on_backlash_damage(_kind: String, amount: float) -> void:
	temp_state["backlash_damage_taken"] = float(temp_state.get("backlash_damage_taken", 0.0)) + amount

func on_enemy_defeated() -> void:
	if has_relic("soul_harvester"):
		var cur_stk = int(temp_state.get("soul_harvest_stacks", 0)) + 1
		temp_state["soul_harvest_stacks"] = cur_stk
		emit_signal("relic_triggered", "soul_harvester")
		var p = get_parent()
		var sm = p.get_node_or_null("StageManager") if p else null
		if sm and "myhpmax" in sm and sm.myhpmax > 0:
			var heal_pct = float(get_param("soul_harvester", "heal_pct", 0.10))
			var heal_val = sm.myhpmax * heal_pct
			if heal_val > 0:
				sm.calchp(0, -heal_val)
				var pb = p.get_node_or_null("PuzzleBoard")
				if pb and pb.has_method("_emit_combat_event"):
					pb._emit_combat_event("heal", "ally", "ally", heal_val)

func on_fever_started() -> void:
	if has_relic("fever_overdrive"):
		var extra = int(get_param("fever_overdrive", "extra_fever_turns", 1))
		var p = get_parent()
		var sm = p.get_node_or_null("StageManager") if p else null
		if sm and "fevercount" in sm:
			sm.fevercount += extra
			emit_signal("relic_triggered", "fever_overdrive")

func on_potions_cleared(count: int) -> void:
	temp_state["potions_cleared_this_turn"] = int(temp_state.get("potions_cleared_this_turn", 0)) + count

func modify_coin_gain(base_coins: float) -> float:
	if has_relic("midas_chalice"):
		var bonus = float(get_param("midas_chalice", "coin_bonus", 0.50))
		emit_signal("relic_triggered", "midas_chalice")
		return base_coins * (1.0 + bonus)
	return base_coins

func is_all_weak_active(combo_or_cascade: int = 0) -> bool:
	if has_relic("crown_of_origin"):
		var min_th = int(get_param("crown_of_origin", "min_threshold", 5))
		if combo_or_cascade >= min_th:
			emit_signal("relic_triggered", "crown_of_origin")
			return true
	return false

func get_board_state() -> Dictionary:
	var p = get_parent()
	if p:
		var pb = p.get_node_or_null("PuzzleBoard")
		if pb and pb.has_method("get_board_state"):
			return pb.get_board_state()
	return {"water_count": 0, "fire_count": 0, "has_big_tree": false}

func get_turn_sword_element_counts() -> Dictionary:
	if temp_state.has("sword_element_counts"):
		return temp_state["sword_element_counts"]
	var p = get_parent()
	if p:
		var score_mgr = p.get_node_or_null("ScoreManager")
		if score_mgr and score_mgr.has_method("get_turn_sword_element_counts"):
			return score_mgr.get_turn_sword_element_counts()
	return {}

func _get_stage_scale() -> float:
	var p = get_parent()
	if p:
		var sm = p.get_node_or_null("StageManager")
		if sm and "stage" in sm:
			return pow(10.0, max(0, int(sm.stage) - 1))
	return 1.0

func on_match(count: int) -> void:
	if has_relic("four_orb"):
		var min_m = int(get_param("four_orb", "min_match", 4))
		if count >= min_m:
			var base_dmg = float(get_param("four_orb", "base_damage", 500.0))
			var mult = float(get_param("four_orb", "mult", 1.0))
			var stage_scale = _get_stage_scale()
			var flat_dmg = base_dmg * mult * stage_scale
			temp_state["four_orb_damage"] = temp_state.get("four_orb_damage", 0.0) + flat_dmg
			emit_signal("relic_triggered", "four_orb")

func on_cascade(cascade_count: int) -> void:
	if has_relic("chain_ring"):
		var min_c = int(get_param("chain_ring", "min_cascade", 3))
		if cascade_count >= min_c:
			temp_state["chain_ring_active"] = true
			emit_signal("relic_triggered", "chain_ring")

func modify_damage_dealt(base_dmg: float, context: Dictionary) -> float:
	if owned_relics.is_empty():
		return base_dmg
		
	var bonus_mult = 0.0
	var flat_add = 0.0
	
	if has_relic("chain_ring") and temp_state.get("chain_ring_active", false):
		bonus_mult += float(get_param("chain_ring", "damage_bonus", 0.20))
		
	if has_relic("fire_shard"):
		var target_el = int(get_param("fire_shard", "element", 1))
		if int(context.get("element", 0)) == target_el:
			bonus_mult += float(get_param("fire_shard", "damage_bonus", 0.15))
			emit_signal("relic_triggered", "fire_shard")
			
	if has_relic("wetland_crown"):
		var target_el = int(get_param("wetland_crown", "element", 4))
		if int(context.get("element", 0)) == target_el:
			var water_cnt = int(context.get("water_count", get_board_state().get("water_count", 0)))
			if water_cnt > 0:
				var per_w = float(get_param("wetland_crown", "per_water", 0.015))
				var max_b = float(get_param("wetland_crown", "max_bonus", 0.30))
				bonus_mult += minf(float(water_cnt) * per_w, max_b)
				emit_signal("relic_triggered", "wetland_crown")
				
	if has_relic("ruins_collector"):
		var hz_cnt = int(context.get("hazards_destroyed_count", temp_state.get("hazards_destroyed_count", 0)))
		if hz_cnt > 0:
			var per_h = float(get_param("ruins_collector", "per_hazard", 0.03))
			var max_b = float(get_param("ruins_collector", "max_bonus", 0.30))
			bonus_mult += minf(float(hz_cnt) * per_h, max_b)
			emit_signal("relic_triggered", "ruins_collector")
			
	if has_relic("resonant_explosive"):
		var det_cnt = int(context.get("special_detonation_count", temp_state.get("special_detonation_count", 0)))
		var extra_cnt = maxi(0, det_cnt - 1)
		if extra_cnt > 0:
			var per_d = float(get_param("resonant_explosive", "per_extra_detonation", 0.10))
			var max_b = float(get_param("resonant_explosive", "max_bonus", 0.40))
			bonus_mult += minf(float(extra_cnt) * per_d, max_b)
			emit_signal("relic_triggered", "resonant_explosive")
			
	if has_relic("bloodstained_sword"):
		bonus_mult += float(get_param("bloodstained_sword", "damage_bonus", 0.30))
		emit_signal("relic_triggered", "bloodstained_sword")
		
	if has_relic("desperate_banner"):
		var hp_ratio = 1.0
		if context.has("hp_ratio"):
			hp_ratio = float(context["hp_ratio"])
		else:
			var p = get_parent()
			var sm = p.get_node_or_null("StageManager") if p else null
			if sm and "myhpmax" in sm and sm.myhpmax > 0 and "myhp" in sm:
				hp_ratio = float(sm.myhp) / float(sm.myhpmax)
		var threshold = float(get_param("desperate_banner", "hp_threshold", 0.30))
		if hp_ratio <= threshold + 0.0001:
			bonus_mult += float(get_param("desperate_banner", "damage_bonus", 0.35))
			emit_signal("relic_triggered", "desperate_banner")
			
	if has_relic("excavator_pickaxe"):
		var enemy_el_str = str(context.get("enemy_element", ""))
		if enemy_el_str == "":
			var p = get_parent()
			var sm = p.get_node_or_null("StageManager") if p else null
			if sm and sm.has_method("get_current_enemy_element"):
				enemy_el_str = sm.get_current_enemy_element()
		if enemy_el_str.contains("地") or enemy_el_str.contains("木") or enemy_el_str.contains("氷"):
			bonus_mult += float(get_param("excavator_pickaxe", "damage_bonus", 0.20))
			emit_signal("relic_triggered", "excavator_pickaxe")
			
	if has_relic("pure_oath"):
		var atk_el = int(context.get("element", 0))
		if atk_el > 0:
			var sword_counts: Dictionary = context.get("sword_element_counts", get_turn_sword_element_counts())
			var total_swords: int = 0
			for k in sword_counts.keys():
				var cnt = int(sword_counts[k])
				if cnt > 0:
					total_swords += cnt
			if total_swords > 0:
				var el_cnt = int(sword_counts.get(atk_el, 0))
				var ratio = float(el_cnt) / float(total_swords)
				var min_ratio = float(get_param("pure_oath", "min_ratio", 0.70))
				if ratio + 0.0001 >= min_ratio:
					bonus_mult += float(get_param("pure_oath", "damage_bonus", 0.25))
					emit_signal("relic_triggered", "pure_oath")
					
	if has_relic("tome_of_four_elements"):
		var sword_counts: Dictionary = context.get("sword_element_counts", get_turn_sword_element_counts())
		var distinct_4: int = 0
		for el_id in [1, 2, 3, 4]: # 1:炎, 2:水, 3:風, 4:雷
			if int(sword_counts.get(el_id, 0)) > 0:
				distinct_4 += 1
		if distinct_4 >= 4:
			bonus_mult += float(get_param("tome_of_four_elements", "bonus_4", 0.45))
			emit_signal("relic_triggered", "tome_of_four_elements")
		elif distinct_4 == 3:
			bonus_mult += float(get_param("tome_of_four_elements", "bonus_3", 0.25))
			emit_signal("relic_triggered", "tome_of_four_elements")
			
	if has_relic("counter_blade"):
		var p = get_parent()
		var pb = p.get_node_or_null("PuzzleBoard") if p else null
		var s_cnt: float = 0.0
		if pb and "current_total_shields" in pb:
			s_cnt = float(pb.current_total_shields)
		elif pb and "active_shields" in pb:
			s_cnt = float(pb.active_shields.size())
		if s_cnt > 0.0:
			var per_s = float(get_param("counter_blade", "per_shield", 0.02))
			var max_b = float(get_param("counter_blade", "max_bonus", 0.30))
			bonus_mult += minf(s_cnt * per_s, max_b)
			emit_signal("relic_triggered", "counter_blade")

	if has_relic("alchemy_flask"):
		var pot_cnt: float = float(context.get("potion_count", temp_state.get("potions_cleared_this_turn", 0)))
		if pot_cnt > 0.0:
			var per_p = float(get_param("alchemy_flask", "per_potion", 0.015))
			var max_b = float(get_param("alchemy_flask", "max_bonus", 0.30))
			bonus_mult += minf(pot_cnt * per_p, max_b)
			emit_signal("relic_triggered", "alchemy_flask")

	if has_relic("executioner_brand"):
		var p = get_parent()
		var sm = p.get_node_or_null("StageManager") if p else null
		var f_enemy = sm.get_focused_enemy() if sm and sm.has_method("get_focused_enemy") else {}
		if not f_enemy.is_empty():
			var t_hp = float(f_enemy.get("hp", 1.0))
			var t_max = float(f_enemy.get("max_hp", 1.0))
			var th = float(get_param("executioner_brand", "hp_threshold", 0.50))
			if t_max > 0.0 and (t_hp / t_max) <= th:
				bonus_mult += float(get_param("executioner_brand", "damage_bonus", 0.30))
				emit_signal("relic_triggered", "executioner_brand")

	if has_relic("soul_harvester"):
		var stacks = int(temp_state.get("soul_harvest_stacks", 0))
		if stacks > 0:
			var per_stack = float(get_param("soul_harvester", "stack_bonus", 0.15))
			var max_b = float(get_param("soul_harvester", "max_bonus", 0.90))
			bonus_mult += minf(float(stacks) * per_stack, max_b)
			emit_signal("relic_triggered", "soul_harvester")

	if has_relic("fever_overdrive"):
		var p = get_parent()
		var sm = p.get_node_or_null("StageManager") if p else null
		if sm and "isfevertime" in sm and sm.isfevertime:
			bonus_mult += float(get_param("fever_overdrive", "fever_damage_bonus", 0.40))
			emit_signal("relic_triggered", "fever_overdrive")

	if has_relic("prismatic_resonator"):
		var p = get_parent()
		var score_mgr = p.get_node_or_null("ScoreManager") if p else null
		var el_counts = score_mgr.turn_element_counts if score_mgr and "turn_element_counts" in score_mgr else {}
		var diff_el_count = 0
		for el in el_counts:
			if int(el_counts[el]) > 0:
				diff_el_count += 1
		if diff_el_count >= int(get_param("prismatic_resonator", "min_elements", 2)):
			bonus_mult += float(get_param("prismatic_resonator", "damage_bonus", 0.35))
			emit_signal("relic_triggered", "prismatic_resonator")

	if has_relic("crown_of_origin"):
		var p = get_parent()
		var score_mgr = p.get_node_or_null("ScoreManager") if p else null
		var combo = int(score_mgr.combocount) if score_mgr and "combocount" in score_mgr else 0
		var cascade = int(context.get("cascade_count", 0))
		var min_th = int(get_param("crown_of_origin", "min_threshold", 5))
		if combo >= min_th or cascade >= min_th:
			bonus_mult += float(get_param("crown_of_origin", "damage_bonus", 0.50))
			emit_signal("relic_triggered", "crown_of_origin")

	if has_relic("midas_chalice"):
		var p = get_parent()
		var score_mgr = p.get_node_or_null("ScoreManager") if p else null
		var total_sc = float(score_mgr.totalScore) if score_mgr and "totalScore" in score_mgr else 0.0
		var per_sc = float(get_param("midas_chalice", "per_score", 10000))
		var step = float(get_param("midas_chalice", "dmg_per_step", 0.01))
		var max_b = float(get_param("midas_chalice", "max_dmg_bonus", 0.50))
		if total_sc > 0.0 and per_sc > 0.0:
			bonus_mult += minf(floorf(total_sc / per_sc) * step, max_b)
			emit_signal("relic_triggered", "midas_chalice")

	if has_relic("four_orb") and temp_state.get("four_orb_damage", 0.0) > 0.0:
		flat_add += temp_state["four_orb_damage"]
		temp_state["four_orb_damage"] = 0.0

	# 上限適用 (+200%)
	bonus_mult = minf(bonus_mult, RELIC_DAMAGE_BONUS_CAP)
	return (base_dmg + flat_add) * (1.0 + bonus_mult)

func modify_damage_taken(base_dmg: float, _context: Dictionary) -> float:
	if owned_relics.is_empty():
		return base_dmg
		
	var reduction = 0.0
	if has_relic("old_shield"):
		reduction += float(get_param("old_shield", "damage_reduction", 0.10))
		emit_signal("relic_triggered", "old_shield")
		
	# 上限適用 (50%)
	reduction = minf(reduction, RELIC_DAMAGE_REDUCTION_CAP)
	return base_dmg * (1.0 - reduction)

func on_heal(amount: float) -> float:
	return amount

func check_fatal_damage(hp: float, incoming_damage: float) -> float:
	if owned_relics.is_empty():
		return incoming_damage
	
	if hp - incoming_damage <= 0:
		if has_relic("indomitable_heart"):
			var max_revives = int(get_param("indomitable_heart", "revives", 1))
			var used = int(temp_state.get("indomitable_heart_used_count", 0))
			if used < max_revives:
				temp_state["indomitable_heart_used_count"] = used + 1
				emit_signal("relic_triggered", "indomitable_heart")
				print("Indomitable Heart Triggered! (Used: ", used + 1, "/", max_revives, ")")
				
				var ratio = float(get_param("indomitable_heart", "survive_hp_ratio", 0.0))
				if ratio <= 0.001:
					return maxf(0.0, hp - 1.0)
				else:
					var p = get_parent()
					var sm = p.get_node_or_null("StageManager") if p else null
					var max_hp = sm.myhpmax if (sm and "myhpmax" in sm and sm.myhpmax > 0) else hp
					var survive_target = max_hp * ratio
					return maxf(0.0, hp - survive_target)
			
	return incoming_damage

func on_stage_clear() -> void:
	pass
