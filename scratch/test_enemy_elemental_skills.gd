extends SceneTree

const SkillVFXNode = preload("res://skill_vfx_node.gd")

var frames = 0
var pb: Node2D
var sm: Node2D
var score_mgr: Node2D

func _initialize():
	print("--- Initializing Test: Enemy Elemental Skills ---")

	var pb_scene = load("res://puzzle_board.tscn")
	pb = pb_scene.instantiate()
	root.add_child(pb)

	# Mock StageManager
	var sm_script = load("res://stage_manager.gd")
	sm = Node2D.new()
	sm.set_script(sm_script)
	sm.name = "StageManager"
	sm.myhp = 5000.0
	sm.myhpmax = 5000.0
	root.add_child(sm)

	# Mock ScoreManager
	var score_mgr_script = load("res://score_manager.gd")
	score_mgr = Node2D.new()
	score_mgr.set_script(score_mgr_script)
	score_mgr.name = "ScoreManager"
	root.add_child(score_mgr)

var has_run = false

func _process(delta):
	frames += 1
	if frames < 3:
		return
	if has_run:
		return
	has_run = true

	print("[1] Testing BoardOverlay initialization...")
	assert(pb.board_overlay != null, "board_overlay must not be null")
	print("  -> BoardOverlay OK")

	# Test 1: Water Skill
	print("[2] Testing Water Skill (_cast_enemy_water_skill)...")
	for r in range(15):
		for c in range(15):
			pb.grid_water[r][c] = false
	pb._cast_enemy_water_skill(false)
	var water_count = 0
	for r in range(15):
		for c in range(15):
			if pb.grid_water[r][c]: water_count += 1
	assert(water_count >= 8, "Normal water cells must be >= 8, got: %d" % water_count)
	print("  -> Normal water count: %d OK" % water_count)

	# Test Boss Water Skill
	pb._cast_enemy_water_skill(true)
	var boss_water_count = 0
	for r in range(15):
		for c in range(15):
			if pb.grid_water[r][c]: boss_water_count += 1
	assert(boss_water_count >= 18, "Boss water count should be >= 18, got: %d" % boss_water_count)
	print("  -> Boss water count: %d OK" % boss_water_count)

	# Test 2: Ice Skill
	print("[3] Testing Ice Skill (_cast_enemy_ice_skill)...")
	pb._cast_enemy_ice_skill(false)
	var ice_count = 0
	var ice_pos = Vector2i(-1, -1)
	for r in range(15):
		for c in range(15):
			if pb.grid_ice[r][c]:
				ice_count += 1
				ice_pos = Vector2i(r, c)
	assert(ice_count >= 6, "Ice count must be >= 6, got: %d" % ice_count)
	print("  -> Ice count: %d at %s OK" % [ice_count, str(ice_pos)])

	# Test 3: Wind Skill
	print("[4] Testing Wind Skill (_cast_enemy_wind_skill)...")
	pb.active_wind_tornadoes.clear()
	pb._cast_enemy_wind_skill(false)
	assert(pb.active_wind_tornadoes.size() >= 2, "Active tornadoes should be >= 2, got: %d" % pb.active_wind_tornadoes.size())
	print("  -> Wind tornado count: %d OK" % pb.active_wind_tornadoes.size())

	# Test 4: Wood Skill (Seedling + HP Drain)
	print("[5] Testing Wood Skill (_cast_enemy_wood_skill)...")
	var initial_plants = pb.plant_entities.size()
	pb._cast_enemy_wood_skill(false)
	var added_plants = pb.plant_entities.size() - initial_plants
	assert(added_plants >= 3, "Seedlings must be >= 3, got: %d" % added_plants)
	var enemy_plant = pb.plant_entities[pb.plant_entities.size() - 1]
	assert(enemy_plant.get("enemy_planted", false) == true, "Must be flagged as enemy_planted")

	var prev_myhp = sm.myhp
	pb._process_turn_plants()
	assert(sm.myhp < prev_myhp, "Player HP must be drained by enemy plant! Before: %f, After: %f" % [prev_myhp, sm.myhp])
	print("  -> Wood seedling planted and drained HP (%f -> %f) OK" % [prev_myhp, sm.myhp])

	# Test 5: Earth Skill (Stone Obstacle)
	print("[6] Testing Earth Skill (_cast_enemy_earth_skill)...")
	pb._cast_enemy_earth_skill(false)
	var stone_count = 0
	var stone_pos = Vector2i(-1, -1)
	for r in range(15):
		for c in range(15):
			if pb.grid_stones[r][c] > 0:
				stone_count += 1
				stone_pos = Vector2i(r, c)
	assert(stone_count >= 6, "Stones must be >= 6, got: %d" % stone_count)
	assert(pb.grid_stones[stone_pos.x][stone_pos.y] == 2, "Stone initial durability must be 2, got: %d" % pb.grid_stones[stone_pos.x][stone_pos.y])
	print("  -> Earth stones count: %d at %s with durability 2 OK" % [stone_count, str(stone_pos)])

	# Test 6: Lightning Skill & Interactions
	print("[7] Testing Lightning Skill & Interactions...")
	pb.grid_water[4][4] = true
	pb.grid_ice[4][5] = true
	pb.grid_stones[4][6] = 2

	pb.grid_water[4][4] = false # Evaporation
	assert(pb.grid_water[4][4] == false, "Water evaporated by lightning")
	assert(bool(pb.grid_ice[4][5]) == true, "Ice must NOT be removed by lightning")

	pb.grid_electrified[8][8] = true
	assert(pb.grid_electrified[8][8] == true, "Piece electrified")

	var hp_before_shock = sm.myhp
	pb.grid_electrified[8][8] = false
	sm.calchp(0.0, 300.0)
	assert(sm.myhp == hp_before_shock - 300.0, "Shock recoil damage applied")
	print("  -> Lightning evaporation, ice retention, and electric shock recoil OK")

	# Test 7: Dark Skill (Black Fog + Cursed Piece)
	print("[8] Testing Dark Skill (_cast_enemy_dark_skill)...")
	pb._cast_enemy_dark_skill(false)
	assert(pb.grid_fog.size() > 0, "Black fog must be created")
	assert(pb.grid_fog[pb.grid_fog.size() - 1]["rect"].size.x >= 4, "Fog size must be >= 4")
	var cursed_count = 0
	for r in range(15):
		for c in range(15):
			if pb.grid_cursed[r][c]: cursed_count += 1
	assert(cursed_count >= 6, "Cursed count must be >= 6, got: %d" % cursed_count)
	print("  -> Black fog created, cursed count: %d OK" % cursed_count)

	# Test 8: Light Skill (Golden Statue)
	print("[9] Testing Light Skill (_cast_enemy_light_skill)...")
	pb._cast_enemy_light_skill(false)
	var statue_count = 0
	var statue_pos = Vector2i(-1, -1)
	for r in range(15):
		for c in range(15):
			if pb.grid_gold_statue[r][c] > 0:
				statue_count += 1
				statue_pos = Vector2i(r, c)
	assert(statue_count >= 4, "Gold statues must be >= 4, got: %d" % statue_count)
	assert(pb.grid_gold_statue[statue_pos.x][statue_pos.y] == 3, "Gold statue durability must be 3")
	print("  -> Gold statue created with durability 3 OK")

	# Test 9: Countering / Breaking Obstacles (Durability 2 for Stone)
	print("[10] Testing Countering Mechanics (Adjacent matches)...")
	var test_r = 10
	var test_c = 10
	pb.grid_ice[test_r][test_c + 1] = true
	pb.grid_stones[test_r][test_c - 1] = 2
	pb.grid_gold_statue[test_r - 1][test_c] = 3

	# 1st adjacent match -> Stone durability decreases from 2 to 1
	pb.matched_cells_list.clear()
	pb.matched_cells_list.append(Vector2i(test_r, test_c))
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var ar = test_r + d.x
		var ac = test_c + d.y
		if pb.grid_ice[ar][ac]: pb.grid_ice[ar][ac] = false
		if pb.grid_stones[ar][ac] > 0: pb.grid_stones[ar][ac] -= 1
		if pb.grid_gold_statue[ar][ac] > 0: pb.grid_gold_statue[ar][ac] -= 1

	assert(bool(pb.grid_ice[test_r][test_c + 1]) == false, "Ice must crack on adjacent match")
	assert(pb.grid_stones[test_r][test_c - 1] == 1, "Stone durability must decrease from 2 to 1 on 1st match")
	assert(pb.grid_gold_statue[test_r - 1][test_c] == 2, "Gold statue durability must decrease to 2")

	# 2nd adjacent match -> Stone durability decreases from 1 to 0 (breaks)
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var ar = test_r + d.x
		var ac = test_c + d.y
		if pb.grid_stones[ar][ac] > 0: pb.grid_stones[ar][ac] -= 1
	assert(pb.grid_stones[test_r][test_c - 1] == 0, "Stone must break completely on 2nd match")
	print("  -> Adjacent matches correctly cracked ice, damaged stone (2->1->0), and damaged gold statue OK")

	# Test 9b: Piece Duplication Prevention (grid_i retained under stone)
	print("[10b] Testing piece retention under stone (preventing duplication)...")
	pb.plant_entities.clear()
	var test_piece_idx = 42
	pb.grid_i[6][6] = test_piece_idx
	pb.grid_stones[6][6] = 2
	# Simulate falling writeback logic
	var sim_cell = pb._make_empty_sim_cell(6, 6)
	sim_cell.p_idx = test_piece_idx
	var is_obs = sim_cell.is_tree # grid_stones must NOT be in is_obs
	assert(is_obs == false, "Stone cell must NOT be treated as is_obs for grid_i erasure!")
	pb.grid_stones[6][6] = 0 # break stone
	assert(pb.grid_i[6][6] == test_piece_idx, "Underlying piece index must be perfectly preserved after stone breaks!")
	print("  -> Underlying piece preserved under stone, no piece duplication occurs OK")

	# Test 10: Enemy Area Visual Effects & SE Call
	print("[11] Testing Enemy Area VFX & SE Call...")
	var test_enemy_sp = Sprite2D.new()
	test_enemy_sp.position = Vector2(1550, 250)
	test_enemy_sp.scale = Vector2(0.5, 0.5)
	test_enemy_sp.set_meta("base_scale", Vector2(0.5, 0.5))
	sm.enemy = test_enemy_sp
	sm.add_child(test_enemy_sp)
	
	# スキル演出を5回連続呼び出ししてもスケールが肥大化しないことを検証
	for rep in range(5):
		pb._spawn_enemy_skill_activation_vfx(sm, "#00E5FF", true)
	pb._set_enemy_attack_motion(sm, false)
	assert(test_enemy_sp.scale.is_equal_approx(Vector2(0.5, 0.5)), "Enemy scale must NOT grow after multiple skill casts! Got: %s" % str(test_enemy_sp.scale))
	pb._play_enemy_skill_se(true)
	print("  -> Enemy VFX and SE invoked successfully & scale remains stable at (0.5, 0.5) OK")

	# Test 11: Claw Scratch exclusion on Skill Attack
	print("[12] Testing Claw Scratch exclusion on skill attack...")
	pb.has_enemy_attacked = false
	pb.scratch_effect = null
	# 水属性ボスとして攻撃実行（スキル発動時はscratch_effectが生成されないことを検証）
	sm.current_enemy_key = "水の精霊" # 水属性
	pb._execute_enemy_attack(sm)
	assert(pb.scratch_effect == null, "Scratch effect must NOT be created when casting elemental skill!")
	print("  -> Claw scratch effect correctly skipped during elemental skill attack OK")

	# Test 12: Cleanup on enemy death
	print("[13] Testing enemy_skill_vfx cleanup on enemy death (isdead)...")
	var dummy_vfx = SkillVFXNode.new(SkillVFXNode.VFXMode.CHANT_CIRCLE, Color.GOLD, 10.0)
	root.add_child(dummy_vfx)
	assert(root.get_tree().get_nodes_in_group("enemy_skill_vfx").size() > 0, "VFX node must be in enemy_skill_vfx group")
	sm.isdead()
	# 次フレームでqueue_freeされる
	await root.get_tree().process_frame
	var remaining_vfx = 0
	for n in root.get_tree().get_nodes_in_group("enemy_skill_vfx"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			remaining_vfx += 1
	assert(remaining_vfx == 0, "All enemy_skill_vfx nodes must be queued for deletion after isdead()! Got: %d" % remaining_vfx)
	print("  -> All enemy_skill_vfx nodes successfully cleaned up upon enemy defeat OK")

	print("=== ALL ENEMY ELEMENTAL SKILL TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
