extends Node
class_name RelicManagerClass

const DEBUG_RELIC: bool = true
signal relic_triggered(relic_id: String)
signal relic_added(relic_id: String)

var owned_relics: Array[String] = []
var temp_state: Dictionary = {}

func _process(delta: float) -> void:
	if DEBUG_RELIC and Input.is_key_pressed(KEY_R) and Input.is_action_just_pressed("ui_accept"):
		for id in ["chain_ring", "four_orb", "old_shield", "healing_drop", "indomitable_heart", "fire_shard"]:
			if not has_relic(id): add_relic(id)
		print("DEBUG: Added all 6 phase 2 relics")

func add_relic(id: String) -> void:
	if not owned_relics.has(id):
		owned_relics.append(id)
		print("Relic Added: ", id)
		emit_signal("relic_added", id)

func has_relic(id: String) -> bool:
	return owned_relics.has(id)

func get_relics() -> Array[String]:
	return owned_relics

func reset_run() -> void:
	owned_relics.clear()
	for c in get_tree().get_nodes_in_group("relic_ui"): c.queue_free()
	temp_state.clear()

func on_battle_start() -> void:
	# Keep some stats that shouldn't be cleared at battle start if they last entire run
	# But per-battle states should be cleared
	temp_state["indomitable_heart_used"] = false

func on_turn_start() -> void:
	temp_state["chain_ring_active"] = false
	temp_state["four_orb_damage"] = 0.0
	
	if has_relic("healing_drop"):
		var p = get_parent()
		if p:
			var sm = p.get_node_or_null("StageManager")
			if sm and "myhpmax" in sm and sm.myhpmax > 0:
				var r_data = RelicDatabase.get_relic("healing_drop")
				var heal_pct = r_data.get("params", {}).get("heal_percent", 0.02)
				var heal_val = sm.myhpmax * heal_pct
				if heal_val > 0:
					sm.calchp(0, -heal_val)
					emit_signal("relic_triggered", "healing_drop")
					# Emit combat event for heal popup if possible
					var pb = p.get_node_or_null("PuzzleBoard")
					if pb and pb.has_method("_emit_combat_event"):
						pb._emit_combat_event("heal", "ally", "ally", heal_val)

func on_match(count: int) -> void:
	if has_relic("four_orb"):
		var r_data = RelicDatabase.get_relic("four_orb")
		var min_m = r_data.get("params", {}).get("min_match", 4)
		if count >= min_m:
			var flat_dmg = r_data.get("params", {}).get("flat_damage", 500.0)
			temp_state["four_orb_damage"] = temp_state.get("four_orb_damage", 0.0) + flat_dmg
			emit_signal("relic_triggered", "four_orb")

func on_cascade(cascade_count: int) -> void:
	if has_relic("chain_ring"):
		var r_data = RelicDatabase.get_relic("chain_ring")
		var min_c = r_data.get("params", {}).get("min_cascade", 3)
		if cascade_count >= min_c:
			temp_state["chain_ring_active"] = true
			emit_signal("relic_triggered", "chain_ring")

func modify_damage_dealt(base_dmg: float, context: Dictionary) -> float:
	if owned_relics.is_empty(): return base_dmg
	var bonus_mult = 0.0
	var flat_add = 0.0
	
	if has_relic("chain_ring") and temp_state.get("chain_ring_active", false):
		var r_data = RelicDatabase.get_relic("chain_ring")
		bonus_mult += r_data.get("params", {}).get("damage_bonus", 0.20)
		
	if has_relic("fire_shard"):
		var r_data = RelicDatabase.get_relic("fire_shard")
		var target_el = r_data.get("params", {}).get("element", 1)
		if context.get("element", 0) == target_el:
			bonus_mult += r_data.get("params", {}).get("damage_bonus", 0.15)
			emit_signal("relic_triggered", "fire_shard")
			
	if has_relic("four_orb") and temp_state.get("four_orb_damage", 0.0) > 0.0:
		flat_add += temp_state["four_orb_damage"]
		# Consume the flat damage so it only applies to the first hit this turn
		temp_state["four_orb_damage"] = 0.0

	return (base_dmg + flat_add) * (1.0 + bonus_mult)

func modify_damage_taken(base_dmg: float, context: Dictionary) -> float:
	if owned_relics.is_empty(): return base_dmg
	var reduction = 0.0
	
	if has_relic("old_shield"):
		var r_data = RelicDatabase.get_relic("old_shield")
		reduction += r_data.get("params", {}).get("damage_reduction", 0.10)
		emit_signal("relic_triggered", "old_shield")
		
	# Cap reduction at 100%
	reduction = minf(reduction, 1.0)
	return base_dmg * (1.0 - reduction)

func on_heal(amount: float) -> float:
	return amount

func check_fatal_damage(hp: float, incoming_damage: float) -> float:
	if owned_relics.is_empty(): return incoming_damage
	
	if hp - incoming_damage <= 0:
		if has_relic("indomitable_heart") and not temp_state.get("indomitable_heart_used", false):
			temp_state["indomitable_heart_used"] = true
			emit_signal("relic_triggered", "indomitable_heart")
			print("Indomitable Heart Triggered!")
			return maxf(0.0, hp - 1.0)
			
	return incoming_damage

func on_stage_clear() -> void:
	pass
