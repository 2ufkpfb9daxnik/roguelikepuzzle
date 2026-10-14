extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== RUNNING STEP 2 RELIC VALUES TESTS ===")
	
	# 1. Chain Ring
	print("[TEST] chain_ring progression:")
	var cr_expected_bonus = [0.20, 0.28, 0.36, 0.45]
	var cr_expected_cascades = [3, 3, 2, 2]
	for l in range(1, 5):
		var p = RelicDatabase.get_level_params("chain_ring", l)
		assert(is_equal_approx(float(p["damage_bonus"]), cr_expected_bonus[l-1]), "chain_ring bonus mismatch at Lv%d" % l)
		assert(int(p["min_cascade"]) == cr_expected_cascades[l-1], "chain_ring min_cascade mismatch at Lv%d" % l)
	print("✓ PASS: chain_ring Lv1..4 verified.")
	
	# 2. Four Orb
	print("[TEST] four_orb progression and stage scaling:")
	var fo_mults = [1.0, 1.5, 2.0, 2.5, 3.0]
	for l in range(1, 6):
		var p = RelicDatabase.get_level_params("four_orb", l)
		assert(is_equal_approx(float(p["mult"]), fo_mults[l-1]), "four_orb mult mismatch at Lv%d" % l)
		assert(is_equal_approx(float(p["base_damage"]), 500.0), "four_orb base_damage must be 500.0")
	
	var rm = RelicManagerClass.new()
	root.add_child(rm)
	rm.add_relic("four_orb")
	
	# Simulate stage 1, 4-match
	rm.on_match(4)
	assert(is_equal_approx(float(rm.temp_state.get("four_orb_damage", 0.0)), 500.0), "Stage 1 Lv1 flat damage must be 500")
	
	# Simulate Lv5
	rm.owned_relics["four_orb"] = 5
	rm.temp_state.clear()
	rm.on_match(4)
	assert(is_equal_approx(float(rm.temp_state.get("four_orb_damage", 0.0)), 1500.0), "Stage 1 Lv5 flat damage must be 1500")
	print("✓ PASS: four_orb Lv1..5 and base math verified.")
	
	# 3. Old Shield
	print("[TEST] old_shield progression:")
	var os_expected = [0.10, 0.15, 0.19, 0.22, 0.25]
	for l in range(1, 6):
		var p = RelicDatabase.get_level_params("old_shield", l)
		assert(is_equal_approx(float(p["damage_reduction"]), os_expected[l-1]), "old_shield reduction mismatch at Lv%d" % l)
	print("✓ PASS: old_shield Lv1..5 verified.")
	
	# 4. Healing Drop
	print("[TEST] healing_drop progression:")
	var hd_expected = [0.02, 0.03, 0.04, 0.05, 0.06]
	for l in range(1, 6):
		var p = RelicDatabase.get_level_params("healing_drop", l)
		assert(is_equal_approx(float(p["heal_percent"]), hd_expected[l-1]), "healing_drop heal mismatch at Lv%d" % l)
	print("✓ PASS: healing_drop Lv1..5 verified.")
	
	# 5. Indomitable Heart
	print("[TEST] indomitable_heart progression:")
	var ih_revives = [1, 1, 2]
	var ih_ratios = [0.0, 0.10, 0.10]
	for l in range(1, 4):
		var p = RelicDatabase.get_level_params("indomitable_heart", l)
		assert(int(p["revives"]) == ih_revives[l-1], "indomitable_heart revives mismatch at Lv%d" % l)
		assert(is_equal_approx(float(p["survive_hp_ratio"]), ih_ratios[l-1]), "indomitable_heart ratio mismatch at Lv%d" % l)
	
	# Test fatal damage survival at Lv1 (survives at 1 HP)
	rm.reset_run()
	rm.add_relic("indomitable_heart")
	var fatal1 = rm.check_fatal_damage(50.0, 100.0)
	# Incoming dmg 100 on 50 HP -> modified incoming damage should be 49 so HP becomes 1!
	assert(is_equal_approx(fatal1, 49.0), "fatal damage at Lv1 should leave 1 HP (dmg = 49), got: %f" % fatal1)
	
	# Test fatal damage survival at Lv2 (survives at 10% max HP)
	rm.reset_run()
	rm.add_relic("indomitable_heart")
	rm.owned_relics["indomitable_heart"] = 2
	var fatal2 = rm.check_fatal_damage(500.0, 1000.0)
	# With hp = 500, 10% = 50 -> modified incoming damage should be 450 so HP becomes 50!
	assert(is_equal_approx(fatal2, 450.0), "fatal damage at Lv2 should leave 10%% HP, got: %f" % fatal2)
	print("✓ PASS: indomitable_heart Lv1..3 and fatal checks verified.")
	
	# 6. Fire Shard
	print("[TEST] fire_shard progression:")
	var fs_expected = [0.15, 0.22, 0.29, 0.36, 0.43]
	for l in range(1, 6):
		var p = RelicDatabase.get_level_params("fire_shard", l)
		assert(is_equal_approx(float(p["damage_bonus"]), fs_expected[l-1]), "fire_shard bonus mismatch at Lv%d" % l)
	print("✓ PASS: fire_shard Lv1..5 verified.")
	
	# 7. Caps Verification
	print("[TEST] Damage caps:")
	rm.reset_run()
	rm.add_relic("chain_ring")
	rm.owned_relics["chain_ring"] = 4 # +45%
	rm.add_relic("fire_shard")
	rm.owned_relics["fire_shard"] = 5 # +43%
	rm.temp_state["chain_ring_active"] = true
	var dmg = rm.modify_damage_dealt(1000.0, {"element": 1})
	assert(is_equal_approx(dmg, 1880.0), "Dmg must be 1880.0, got: %f" % dmg)
	
	rm.queue_free()
	print("\n✓ ALL STEP 2 TESTS PASSED!")
	quit()
