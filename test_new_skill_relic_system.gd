extends SceneTree

func _init() -> void:
	print("--- Starting Test New Skill & Relic System ---")

	# 1. RelicDatabase tests
	var spark_data = RelicDatabase.get_relic("resonant_spark")
	assert(not spark_data.is_empty(), "resonant_spark not found in RelicDatabase")
	assert(spark_data.get("rarity") == "rare", "resonant_spark rarity should be rare")
	var desc_spark = RelicDatabase.get_description("resonant_spark", 1)
	print("Resonant Spark Lv1 Desc: ", desc_spark)

	var shura_data = RelicDatabase.get_relic("cursed_shura_sword")
	assert(not shura_data.is_empty(), "cursed_shura_sword not found")
	assert(shura_data.get("rarity") == "cursed", "cursed_shura_sword rarity should be cursed")
	print("Cursed Shura Sword Lv1 Desc: ", RelicDatabase.get_description("cursed_shura_sword", 1))

	var grail_data = RelicDatabase.get_relic("cursed_gluttony_grail")
	assert(not grail_data.is_empty(), "cursed_gluttony_grail not found")
	assert(grail_data.get("rarity") == "cursed", "cursed_gluttony_grail rarity should be cursed")
	print("Cursed Grail Lv1 Desc: ", RelicDatabase.get_description("cursed_gluttony_grail", 1))

	var midas_data = RelicDatabase.get_relic("cursed_midas_touch")
	assert(not midas_data.is_empty(), "cursed_midas_touch not found")
	assert(midas_data.get("rarity") == "cursed", "cursed_midas_touch rarity should be cursed")
	print("Cursed Midas Lv1 Desc: ", RelicDatabase.get_description("cursed_midas_touch", 1))

	# 2. RelicManager logic tests
	var rm = RelicManagerClass.new()
	rm.name = "RelicManager"
	var dummy_root = Node2D.new()
	var dummy_sm = Node2D.new()
	dummy_sm.name = "StageManager"
	dummy_sm.set_script(load("res://stage_manager.gd"))
	dummy_sm.myhpmax = 1000.0
	dummy_sm.myhp = 1000.0
	dummy_root.add_child(dummy_sm)
	dummy_root.add_child(rm)
	root.add_child(dummy_root)

	# Test cursed_shura_sword add effect
	rm.add_relic("cursed_shura_sword")
	assert(dummy_sm.myhpmax == 500.0, "cursed_shura_sword should halve max HP to 500.0")
	var dmg = rm.modify_damage_dealt(100.0, {})
	assert(dmg == 250.0, "cursed_shura_sword should multiply damage by 2.5")
	print("Shura sword damage check: 100 -> %f, maxhp -> %f" % [dmg, dummy_sm.myhpmax])

	# Test cursed_gluttony_grail
	rm.add_relic("cursed_gluttony_grail")
	var heal_val = rm.on_heal(50.0)
	assert(heal_val == 150.0, "cursed_gluttony_grail should multiply heal by 3.0")
	print("Gluttony grail heal check: 50 -> %f" % heal_val)

	# Test cursed_midas_touch
	rm.add_relic("cursed_midas_touch")
	var coin_val = rm.modify_coin_gain(100.0)
	assert(coin_val == 300.0, "cursed_midas_touch should multiply coin by 3.0")
	var incoming_dmg = rm.modify_damage_taken(100.0, {})
	assert(incoming_dmg == 130.0, "cursed_midas_touch should multiply incoming damage by 1.3")
	print("Midas touch check: coin 100 -> %f, incoming dmg 100 -> %f" % [coin_val, incoming_dmg])

	# 3. PuzzleBoard match detection & spawn tests
	var pb = load("res://puzzle_board.gd").new()
	pb.name = "PuzzleBoard"
	dummy_root.add_child(pb)
	
	# Verify falling special items are disabled (NONE)
	assert(pb._roll_falling_special() == pb.SpecialItemType.NONE, "Falling specials must be NONE")
	print("Falling special check: confirmed NONE")

	# Setup board grid with -1
	for r in range(pb.GRID_ROWS):
		var row_i: Array = []
		var row_n: Array = []
		var row_att: Array = []
		var row_sp: Array = []
		var row_ch: Array = []
		var row_b: Array = []
		var row_m: Array = []
		var row_stones: Array = []
		var row_ice: Array = []
		var row_cursed: Array = []
		var row_statue: Array = []
		for c in range(pb.GRID_COLUMNS):
			row_i.append(-1)
			row_n.append(0) # SHIELD by default
			row_att.append(0)
			row_sp.append(pb.SpecialItemType.NONE)
			row_ch.append(0)
			row_b.append(false)
			row_m.append(false)
			row_stones.append(0)
			row_ice.append(0)
			row_cursed.append(false)
			row_statue.append(0)
		pb.grid_i.append(row_i)
		pb.grid_n.append(row_n)
		pb.grid_att.append(row_att)
		pb.special_item.append(row_sp)
		pb.special_charge.append(row_ch)
		pb.is_bomb.append(row_b)
		pb.ismatched.append(row_m)
		pb.grid_stones.append(row_stones)
		pb.grid_ice.append(row_ice)
		pb.grid_cursed.append(row_cursed)
		pb.grid_gold_statue.append(row_statue)

	# Test A: 4 Swords match when BOMB is locked (lvl 0)
	pb.special_levels[pb.SpecialItemType.BOMB] = 0
	# Put 4 swords at row 5, cols 2..5
	for c in range(2, 6):
		pb.grid_n[5][c] = 1 # SWORD
		pb.grid_i[5][c] = c
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.is_empty(), "No skill should spawn when BOMB is locked")
	print("Match 4 SWORD (Locked): Pending spawns correctly empty")

	# Test B: 4 Swords match when BOMB is unlocked (lvl 1)
	pb.special_levels[pb.SpecialItemType.BOMB] = 1
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.size() == 1, "1 BOMB should spawn when BOMB is Lv1")
	assert(pb.pending_special_spawns.has(Vector2i(5, 3)), "Spawn pivot should be the swapped cell (5, 3)")
	assert(pb.pending_special_spawns[Vector2i(5, 3)] == pb.SpecialItemType.BOMB, "Spawned type should be BOMB")
	print("Match 4 SWORD (Lv1): Successfully scheduled BOMB at (5, 3)")

	# Test C: 4 Swords match when BOMB is Lv3 (2 pieces simultaneously generated)
	pb.special_levels[pb.SpecialItemType.BOMB] = 3
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.size() == 2, "2 BOMBs should spawn when BOMB is Lv3 (Dual spawn perk)")
	assert(pb.pending_special_spawns.has(Vector2i(5, 3)), "Pivot cell (5, 3) must be one of the spawns")
	print("Match 4 SWORD (Lv3 Dual Spawn): Successfully scheduled 2 BOMBs at ", pb.pending_special_spawns.keys())

	# Test D: 5 Swords match in a line when LIGHTNING is unlocked (Lv1)
	pb.grid_n[5][6] = 1 # 5 swords: cols 2..6
	pb.special_levels[pb.SpecialItemType.LIGHTNING] = 1
	pb.last_swap_cells = [Vector2i(5, 4), Vector2i(4, 4)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 4)] == pb.SpecialItemType.LIGHTNING, "5 swords should spawn LIGHTNING")
	print("Match 5 SWORD in a line: Successfully scheduled LIGHTNING at (5, 4)")

	# Test E: Cross Match (T-shape) -> CROSS_BOMB
	# Clear row 5
	for c in range(pb.GRID_COLUMNS):
		pb.grid_n[5][c] = 0
	# Create T-shape of Coins (kind 2) around (3, 3)
	# Horizontal: (3, 2), (3, 3), (3, 4)
	pb.grid_n[3][2] = 2; pb.grid_i[3][2] = 10
	pb.grid_n[3][3] = 2; pb.grid_i[3][3] = 11
	pb.grid_n[3][4] = 2; pb.grid_i[3][4] = 12
	# Vertical: (2, 3), (3, 3), (4, 3)
	pb.grid_n[2][3] = 2; pb.grid_i[2][3] = 13
	pb.grid_n[4][3] = 2; pb.grid_i[4][3] = 14
	pb.special_levels[pb.SpecialItemType.CROSS_BOMB] = 1
	pb.last_swap_cells = [Vector2i(3, 3), Vector2i(3, 5)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(3, 3)] == pb.SpecialItemType.CROSS_BOMB, "Cross match should spawn CROSS_BOMB at intersection (3, 3)")
	print("Cross Match T-Shape: Successfully scheduled CROSS_BOMB at intersection (3, 3)")

	# Test F: Resonant Spark steady state triggering
	rm.add_relic("resonant_spark")
	# Place 1 special item on board
	pb.special_item[3][3] = pb.SpecialItemType.BOMB
	pb.grid_i[3][3] = 11
	var triggered = rm.trigger_steady_state_relics(pb)
	assert(triggered == true, "resonant_spark should trigger steady state detonation")
	print("Resonant Spark Steady State Trigger: SUCCESS!")

	# Test G: Cursed Gluttony Grail hazard spawn
	pb.spawn_random_hazard_for_curse()
	var found_hazard = false
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if (pb.grid_stones.size() == pb.GRID_ROWS and pb.grid_stones[r][c] > 0) or \
			   (pb.grid_ice.size() == pb.GRID_ROWS and pb.grid_ice[r][c] > 0) or \
			   (pb.grid_cursed.size() == pb.GRID_ROWS and pb.grid_cursed[r][c]):
				found_hazard = true
				break
	assert(found_hazard, "cursed_gluttony_grail should spawn a hazard on the board")
	print("Cursed Gluttony Grail Hazard Spawn: SUCCESS!")

	# Test H: Water extinguishing fire
	# Initialize grid_fire and grid_water if not already sized
	while pb.grid_fire.size() < pb.GRID_ROWS:
		var rf: Array = []
		for c in range(pb.GRID_COLUMNS): rf.append(0)
		pb.grid_fire.append(rf)
	while pb.grid_water.size() < pb.GRID_ROWS:
		var rw: Array = []
		for c in range(pb.GRID_COLUMNS): rw.append(false)
		pb.grid_water.append(rw)

	pb.grid_fire[2][2] = 1
	assert(pb.grid_fire[2][2] == 1, "Fire should be 1")
	pb._apply_water_to_cell(2, 2)
	assert(pb.grid_fire[2][2] == 0, "Water must extinguish fire (grid_fire == 0)")
	assert(pb.grid_water[2][2] == true, "Water must be placed at (2, 2)")
	print("Water extinguishing fire: SUCCESS! Fire extinguished and water placed.")

	# Test I: Stone blocked from matching
	# Clear grid_n
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = -1
			pb.grid_stones[r][c] = 0
	# Set SWORD at (1, 1), Stone (with SWORD type) at (1, 2), SWORD at (1, 3)
	pb.grid_n[1][1] = 1
	pb.grid_n[1][2] = 1
	pb.grid_stones[1][2] = 2 # Stone!
	pb.grid_n[1][3] = 1
	var match_found = pb._check_matches_exist()
	assert(not match_found, "Stone must NOT function as a piece or bridge matches across it")
	assert(pb.ismatched[1][2] == false, "Stone cell must not be matched")
	print("Stone matching exclusion check: SUCCESS! Stone correctly blocked match.")

	# Test J: Stone damage helper
	pb.grid_stones[4][4] = 2
	var damaged = pb._damage_stone_at(4, 4, 1)
	assert(damaged == true, "_damage_stone_at should return true")
	assert(pb.grid_stones[4][4] == 1, "Stone durability should decrease from 2 to 1")
	pb._damage_stone_at(4, 4, 1)
	assert(pb.grid_stones[4][4] == 0, "Stone durability should reach 0 and be destroyed")
	print("Stone damage & destruction check: SUCCESS!")

	# Test K: Bomb skill damaging stone
	pb.grid_stones[3][3] = 2
	pb.special_levels[pb.SpecialItemType.BOMB] = 1
	var q: Array = []
	var exp_dict: Dictionary = {}
	pb._trigger_bomb(3, 2, Vector2(300, 300), q, exp_dict)
	assert(pb.grid_stones[3][3] == 1, "Bomb should deal 1 damage to stone at (3, 3), reducing durability from 2 to 1")
	assert(pb.ismatched[3][3] == false, "Stone should not be matched while durability remains")
	print("Skill damage to stone check: SUCCESS!")

	# Test L: Skill piece de-attribution & matching exclusion check
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = -1
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false
	pb.grid_n[2][1] = pb.PieceType.SWORD
	pb.grid_n[2][2] = -1
	pb.special_item[2][2] = pb.SpecialItemType.BOMB
	pb.is_bomb[2][2] = true
	pb.grid_n[2][3] = pb.PieceType.SWORD
	var sp_match_found = pb._check_matches_exist()
	assert(not sp_match_found, "Skill piece must NOT match with basic pieces")
	assert(pb.ismatched[2][2] == false, "Skill piece must not be matched as basic piece")
	print("Skill piece matching exclusion check: SUCCESS! Skill piece ignored basic 3-match.")

	# Test M: Fever gauge accumulation, fever time protection, and reset flow
	dummy_sm.fevergage = 0.0
	dummy_sm.isfevertime = false
	dummy_sm.calcgage(3500.0)
	assert(dummy_sm.fevergage == 3500.0 and dummy_sm.feverpar == 0.5, "Fever gauge should be 50%")
	dummy_sm.calcgage(5000.0) # Exceeds 7000
	assert(dummy_sm.fevergage == 7000.0 and dummy_sm.feverpar == 1.0, "Fever gauge should clamp to 7000.0 (100%)")
	dummy_sm.fevertime()
	assert(dummy_sm.isfevertime == true, "isfevertime should be true")
	assert(dummy_sm.fevercount == 5, "fevercount should be 5")
	# Potion arrival during fever time should be ignored and not reset gauge to 0 or low value
	dummy_sm.calcgage(100.0)
	assert(dummy_sm.isfevertime == true, "Fever time should remain active")
	dummy_sm.notfevertime()
	assert(dummy_sm.isfevertime == false, "isfevertime should become false")
	assert(dummy_sm.fevergage == 0.0 and dummy_sm.feverpar == 0.0, "Fever gauge should reset to 0.0")
	print("Fever gauge & fever time flow check: SUCCESS!")

	# Test N: Tooltip display check in RelicUIManager
	var rui = load("res://relic_ui_manager.gd").new()
	dummy_root.add_child(rui)
	if rui.info_panel == null:
		rui._ready()
	rui.show_custom_tooltip("[b]Test Title[/b]", "Test Description", Vector2(400, 400), "test_key")
	assert(rui.info_panel.visible == true, "info_panel should be visible")
	assert(rui.info_panel.position.x > 0 and rui.info_panel.position.y > 0, "info_panel position should be valid")
	rui.hide_custom_tooltip("test_key")
	assert(rui.info_panel.visible == false, "info_panel should hide after hide_custom_tooltip")
	print("Tooltip display check: SUCCESS!")

	print("ALL TESTS PASSED SUCCESSFULLY!")
	quit(0)
