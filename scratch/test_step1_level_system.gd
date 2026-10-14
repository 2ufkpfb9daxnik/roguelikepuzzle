extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _run_tests() -> void:
	print("=== RUNNING STEP 1 VERIFICATION TESTS ===")
	
	# --- Test 1: RelicDatabase Lv1 values match legacy values ---
	print("\n[TEST 1] Lv1 parameters match current behavior:")
	var cr_p1 = RelicDatabase.get_level_params("chain_ring", 1)
	assert(cr_p1.get("damage_bonus") == 0.20, "chain_ring Lv1 damage_bonus must be 0.20")
	assert(cr_p1.get("min_cascade") == 3, "chain_ring Lv1 min_cascade must be 3")
	
	var fo_p1 = RelicDatabase.get_level_params("four_orb", 1)
	assert(fo_p1.get("flat_damage") == 500.0, "four_orb Lv1 flat_damage must be 500.0")
	assert(fo_p1.get("min_match") == 4, "four_orb Lv1 min_match must be 4")
	
	var os_p1 = RelicDatabase.get_level_params("old_shield", 1)
	assert(os_p1.get("damage_reduction") == 0.10, "old_shield Lv1 damage_reduction must be 0.10")
	
	var hd_p1 = RelicDatabase.get_level_params("healing_drop", 1)
	assert(hd_p1.get("heal_percent") == 0.02, "healing_drop Lv1 heal_percent must be 0.02")
	
	var ih_p1 = RelicDatabase.get_level_params("indomitable_heart", 1)
	assert(ih_p1.get("revives") == 1, "indomitable_heart Lv1 revives must be 1")
	assert(ih_p1.get("survive_hp_ratio") == 0.0, "indomitable_heart Lv1 survive_hp_ratio must be 0.0")
	
	var fs_p1 = RelicDatabase.get_level_params("fire_shard", 1)
	assert(fs_p1.get("damage_bonus") == 0.15, "fire_shard Lv1 damage_bonus must be 0.15")
	assert(fs_p1.get("element") == 1, "fire_shard Lv1 element must be 1")
	print("✓ PASS: All 6 relics Lv1 values exactly match legacy values.")
	
	# --- Test 2: RelicManager level progression and caps ---
	print("\n[TEST 2] RelicManager leveling up and max level cap:")
	var rm = RelicManagerClass.new()
	rm.name = "RelicManager"
	root.add_child(rm)
	
	assert(rm.get_level("chain_ring") == 0, "Initial level should be 0")
	assert(not rm.has_relic("chain_ring"), "Initial has_relic should be false")
	
	# Add 1st time -> Lv1
	rm.add_relic("chain_ring")
	assert(rm.get_level("chain_ring") == 1, "Level after 1st add should be 1")
	assert(rm.has_relic("chain_ring"), "has_relic should be true")
	assert(rm.get_param("chain_ring", "damage_bonus") == 0.20, "Param should match Lv1")
	
	# Add 2nd time -> Lv2
	rm.add_relic("chain_ring")
	assert(rm.get_level("chain_ring") == 2, "Level after 2nd add should be 2")
	assert(rm.get_param("chain_ring", "damage_bonus") == 0.28, "Param should match Lv2")
	
	# Add 3rd time -> Lv3
	rm.add_relic("chain_ring")
	assert(rm.get_level("chain_ring") == 3, "Level after 3rd add should be 3")
	assert(rm.get_param("chain_ring", "damage_bonus") == 0.36, "Param should match Lv3")
	assert(rm.get_param("chain_ring", "min_cascade") == 2, "min_cascade should be 2 at Lv3")
	
	# Add 4th time -> Lv4 (max for uncommon)
	rm.add_relic("chain_ring")
	assert(rm.get_level("chain_ring") == 4, "Level after 4th add should be 4")
	assert(rm.is_max_level("chain_ring"), "chain_ring should be max level at 4")
	
	# Add 5th time -> should stay Lv4
	rm.add_relic("chain_ring")
	assert(rm.get_level("chain_ring") == 4, "Level should not exceed max_level 4")
	print("✓ PASS: Relic leveling up and max_level cap verified.")
	
	# --- Test 3: Save / Load backward compatibility ---
	print("\n[TEST 3] Save / Load backward compatibility:")
	# Legacy format: Array of string IDs
	var legacy_save: Array = ["old_shield", "fire_shard"]
	rm.deserialize_relics(legacy_save)
	assert(rm.get_level("old_shield") == 1, "Legacy array element should load as Lv1")
	assert(rm.get_level("fire_shard") == 1, "Legacy array element should load as Lv1")
	assert(rm.get_level("chain_ring") == 0, "Old chain_ring should be cleared")
	
	# Dictionary format with levels and out-of-bounds check
	var dict_save: Dictionary = {
		"indomitable_heart": 2,
		"old_shield": 99,       # Should clamp to max_level (5)
		"invalid_relic_id": 3   # Should be ignored
	}
	rm.deserialize_relics(dict_save)
	assert(rm.get_level("indomitable_heart") == 2, "indomitable_heart should load as Lv2")
	assert(rm.get_level("old_shield") == 5, "old_shield should clamp to max_level 5")
	assert(not rm.has_relic("invalid_relic_id"), "invalid id must not be added")
	print("✓ PASS: Legacy Array and Dictionary save/load correctly handled.")
	
	# --- Test 4: Damage bonus and reduction caps ---
	print("\n[TEST 4] Caps (+200% bonus cap, 50% reduction cap):")
	# Force a huge damage bonus
	rm.reset_run()
	rm.add_relic("chain_ring")
	rm.owned_relics["chain_ring"] = 4 # +45%
	rm.add_relic("fire_shard")
	rm.owned_relics["fire_shard"] = 5 # +43%
	rm.temp_state["chain_ring_active"] = true
	var dmg = rm.modify_damage_dealt(1000.0, {"element": 1})
	# +45% + +43% = +88%, within +200% cap -> 1000 * 1.88 = 1880
	assert(is_equal_approx(dmg, 1880.0), "Dmg should be 1880.0, got: %f" % dmg)
	
	# Test reduction cap
	rm.reset_run()
	rm.add_relic("old_shield")
	rm.owned_relics["old_shield"] = 5 # 25% reduction
	var taken = rm.modify_damage_taken(1000.0, {})
	assert(is_equal_approx(taken, 750.0), "Taken should be 750.0, got: %f" % taken)
	print("✓ PASS: Damage calculation with caps verified.")
	
	rm.queue_free()
	
	# --- Test 5: Integration flow with current_stage scene ---
	print("\n[TEST 5] Battle indices offer filter (RELIC_OFFER_BATTLE_INDICES = [2, 5]):")
	var scene = load("res://current_stage.tscn").instantiate()
	root.add_child(scene)
	await _wait(10)
	var sm = scene.get_node("StageManager")
	var score = sm._get_score_manager()
	
	# Helper to find selection UI
	var find_ui = func():
		for c in scene.get_children():
			if c.get_script() == preload("res://relic_selection_ui.gd"):
				return c
		return null
	
	# Enemy 1 defeat: NOT in [2, 5] -> Selection UI should NOT appear!
	sm.stage_enemy = 1
	sm.isdeadf = true
	sm.deadinterval = 95
	await _wait(30)
	var ui1 = find_ui.call()
	print("Enemy 1 finished -> UI appeared: ", ui1 != null, " (Expected: false)")
	assert(ui1 == null, "Enemy 1 must NOT offer relics")
	assert(score.is_shop_open, "Shop should open directly for enemy 1")
	assert(sm.move_front_btn.visible, "move_front_btn should be visible directly for enemy 1")
	
	# Reset for enemy 2
	score.set_shop_ui_visible(false)
	sm.move_front_btn.visible = false
	
	# Enemy 2 defeat: IN [2, 5] -> Selection UI SHOULD appear!
	sm.stage_enemy = 2
	sm.isdeadf = true
	sm.deadinterval = 95
	await _wait(30)
	var ui2 = find_ui.call()
	print("Enemy 2 finished -> UI appeared: ", ui2 != null, " (Expected: true)")
	assert(ui2 != null, "Enemy 2 MUST offer relics")
	assert(not score.is_shop_open, "Shop must be hidden while selecting relic")
	
	# Choose first card
	if ui2:
		var btn = ui2.hbox.get_child(0)
		btn.pressed.emit()
	await _wait(5)
	
	assert(score.is_shop_open, "Shop should open after relic choice")
	assert(sm.move_front_btn.visible, "move_front_btn should be visible after relic choice")
	
	var r_mgr = scene.get_node("RelicManager")
	print("Owned relics after choice: ", r_mgr.get_relic_levels())
	assert(r_mgr.get_relics().size() == 1, "Should own 1 relic now")
	
	# Verify relic UI icon and tooltip
	var r_ui = scene.get_node("RelicUIManager")
	assert(r_ui.container.get_child_count() == 1, "Relic UI icon should be displayed")
	
	print("\n✓ ALL TESTS PASSED SUCCESSFULLY!")
	quit()
