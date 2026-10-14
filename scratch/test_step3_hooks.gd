extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== RUNNING STEP 3 HOOKS TESTS ===")
	
	var rm = RelicManagerClass.new()
	root.add_child(rm)
	
	# Test 1: on_special_detonated
	rm.on_turn_start()
	assert(rm.temp_state.get("special_detonation_count", 0) == 0, "Initial special count must be 0")
	rm.on_special_detonated(1) # BOMB
	rm.on_special_detonated(2) # CROSS_BOMB
	assert(rm.temp_state.get("special_detonation_count", 0) == 2, "Special count must be 2 after 2 detonations")
	print("✓ PASS: on_special_detonated hook verified.")
	
	# Test 2: on_hazard_destroyed
	rm.on_hazard_destroyed("stone", 2)
	rm.on_hazard_destroyed("ice", 1)
	assert(rm.temp_state.get("hazards_destroyed_count", 0) == 3, "Total hazards destroyed must be 3")
	var by_k = rm.temp_state.get("hazard_destroyed_by_kind", {})
	assert(by_k.get("stone") == 2, "Stones destroyed must be 2")
	assert(by_k.get("ice") == 1, "Ice destroyed must be 1")
	print("✓ PASS: on_hazard_destroyed hook verified.")
	
	# Test 3: on_backlash_damage
	rm.on_backlash_damage("electrified", 150.0)
	rm.on_backlash_damage("cursed", 250.0)
	assert(is_equal_approx(float(rm.temp_state.get("backlash_damage_taken", 0.0)), 400.0), "Backlash dmg must be 400")
	print("✓ PASS: on_backlash_damage hook verified.")
	
	# Test 4: reset on turn start
	rm.on_turn_start()
	assert(rm.temp_state.get("special_detonation_count", 0) == 0, "Should reset on turn start")
	assert(rm.temp_state.get("hazards_destroyed_count", 0) == 0, "Should reset on turn start")
	assert(is_equal_approx(float(rm.temp_state.get("backlash_damage_taken", 0.0)), 0.0), "Should reset on turn start")
	print("✓ PASS: turn start resets verified.")
	
	rm.queue_free()
	
	# Test 5: Scene integration (PuzzleBoard get_board_state and ScoreManager turn_sword_element_counts)
	var scene = load("res://current_stage.tscn").instantiate()
	root.add_child(scene)
	for i in range(10): await process_frame
	
	var pb = scene.get_node("PuzzleBoard")
	var state = pb.get_board_state()
	print("Board state from PuzzleBoard: ", state)
	assert(state.has("water_count"), "Must have water_count")
	assert(state.has("fire_count"), "Must have fire_count")
	assert(state.has("has_big_tree"), "Must have has_big_tree")
	
	var sm = scene.get_node("ScoreManager")
	var sword_counts = sm.get_turn_sword_element_counts()
	assert(sword_counts is Dictionary, "Must return dictionary")
	
	print("\n✓ ALL STEP 3 TESTS PASSED!")
	quit()
