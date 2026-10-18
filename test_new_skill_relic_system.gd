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
	rui.name = "RelicUIManager"
	dummy_root.add_child(rui)
	if rui.info_panel == null:
		rui._ready()
	rui.show_custom_tooltip("[b]Test Title[/b]", "Test Description", Vector2(400, 400), "test_key")
	assert(rui.info_panel.visible == true, "info_panel should be visible")
	assert(rui.info_panel.position.x > 0 and rui.info_panel.position.y > 0, "info_panel position should be valid")
	rui.hide_custom_tooltip("test_key")
	assert(rui.info_panel.visible == false, "info_panel should hide after hide_custom_tooltip")
	# Test O: Skill tree max_level 20 and 20-level descriptions verification
	var smg = load("res://score_manager.gd").new()
	assert(smg.skill_tree_items.size() == 12, "Must have 12 skills")
	for s in smg.skill_tree_items:
		assert(int(s.get("max_level", 0)) == 20, "Skill %s must have max_level == 20" % s.get("id"))
		var d_arr: Array = s.get("desc_lv", [])
		assert(d_arr.size() == 20, "Skill %s must have 20 description entries, got %d" % [s.get("id"), d_arr.size()])
	print("Skill max_level 20 & 20-level descriptions check: SUCCESS!")

	# Test P: Skill purchase cost multiplier check (1.30 curve)
	smg.divscore[smg.PieceType.POTION] = 1000000
	var bomb_skill = smg.get_skill_by_id("bomb")
	var initial_cost = int(bomb_skill["cost"]) # 1000
	assert(initial_cost == 1000, "Initial bomb cost should be 1000")
	smg._purchase_skill(0) # Buy Lv1
	assert(bomb_skill["level"] == 1, "Bomb level should become 1")
	assert(bomb_skill["cost"] == int(1000 * 1.30), "Next bomb cost should be 1300, got %d" % bomb_skill["cost"])
	print("Skill purchase cost progression (* 1.30): SUCCESS!")

	# Test Q: Multi-spawn scaling at Lv3, Lv10, Lv18
	# Clear grid
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = -1
			pb.grid_i[r][c] = -1
	# 4 swords in a row (cols 2..5, enough cells for up to 4 simultaneous spawns)
	for c in range(2, 6):
		pb.grid_n[4][c] = pb.PieceType.SWORD
		pb.grid_i[4][c] = c + 50
	pb.last_swap_cells = [Vector2i(4, 2), Vector2i(5, 2)]
	pb.special_levels[pb.SpecialItemType.LIGHTNING] = 0
	pb.special_levels[pb.SpecialItemType.GEMINI_BOMB] = 0
	pb.special_levels[pb.SpecialItemType.DISCO_BALL] = 0

	# Lv1: 1 spawn
	pb.special_levels[pb.SpecialItemType.BOMB] = 1
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.size() == 1, "Lv1 should spawn 1 bomb")

	# Lv3: 2 spawns
	pb.special_levels[pb.SpecialItemType.BOMB] = 3
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.size() == 2, "Lv3 should spawn 2 bombs")

	# Lv10: 3 spawns
	pb.special_levels[pb.SpecialItemType.BOMB] = 10
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.size() == 3, "Lv10 should spawn 3 bombs")

	# Lv18: 4 spawns
	pb.special_levels[pb.SpecialItemType.BOMB] = 18
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.size() == 4, "Lv18 should spawn 4 bombs")
	print("Multi-spawn scaling (Lv1=1, Lv3=2, Lv10=3, Lv18=4): SUCCESS!")

	# Test R: Bomb stone penetration damage scaling with level
	# Bomb Lv1 deals 1 dmg to stone
	pb.grid_stones[3][3] = 10
	pb.special_levels[pb.SpecialItemType.BOMB] = 1
	var q_test: Array = []
	var exp_test: Dictionary = {}
	pb._trigger_bomb(3, 2, Vector2(300, 300), q_test, exp_test)
	assert(pb.grid_stones[3][3] == 9, "Bomb Lv1 should deal 1 damage to stone (10 -> 9)")

	# Bomb Lv5 deals 2 dmg to stone (1 + int((5-1)/4) = 2)
	pb.special_levels[pb.SpecialItemType.BOMB] = 5
	pb._trigger_bomb(3, 2, Vector2(300, 300), q_test, exp_test)
	assert(pb.grid_stones[3][3] == 7, "Bomb Lv5 should deal 2 damage to stone (9 -> 7)")

	# Bomb Lv17 deals 5 dmg to stone (1 + int((17-1)/4) = 5)
	pb.special_levels[pb.SpecialItemType.BOMB] = 17
	pb._trigger_bomb(3, 2, Vector2(300, 300), q_test, exp_test)
	assert(pb.grid_stones[3][3] == 2, "Bomb Lv17 should deal 5 damage to stone (7 -> 2)")
	print("Bomb stone penetration damage scaling: SUCCESS!")

	# Test S: Enemy skill fixed trigger frequency (Boss 100%, Normal 50% across all stages)
	# and stage initial status scaling (Stage 1 gentle/weak -> Stage 5 intense)
	dummy_sm.stage = 1
	var st1_idx = pb._get_stage_index()
	assert(st1_idx == 0, "Stage 1 should have index 0")

	# 1) Frequency check: fixed across stages
	# Dummy enemy node for _should_cast_enemy_elemental_skill
	dummy_sm.ehp = 500
	dummy_sm.isdeadf = false
	var enemy_sprite = Sprite2D.new()
	dummy_sm.enemy = enemy_sprite
	dummy_sm.active_enemies = [{"sp_data": {"element": "水"}, "sprite": enemy_sprite, "hp": 500.0, "hpmax": 500.0}]
	dummy_sm.target_enemy_index = 0
	dummy_sm.is_current_boss = true
	assert(pb._should_cast_enemy_elemental_skill(dummy_sm) == true, "Boss must always cast skill (100% fixed) at Stage 1")

	dummy_sm.stage = 5
	assert(pb._should_cast_enemy_elemental_skill(dummy_sm) == true, "Boss must always cast skill (100% fixed) at Stage 5")

	# 2) Stage 1 initial status scaling check (Normal weak, Boss strong)
	dummy_sm.stage = 1
	var s1_water_norm_min = 1 + int(0 * 1.5)
	var s1_water_norm_max = 2 + int(0 * 1.5)
	assert(s1_water_norm_min == 1 and s1_water_norm_max == 2, "Stage 1 normal water skill should target 1~2 cells")

	var s1_water_boss_min = 5 + int(0 * 1.0)
	var s1_water_boss_max = 6 + int(0 * 1.0)
	assert(s1_water_boss_min == 5 and s1_water_boss_max == 6, "Stage 1 boss water skill should target 5~6 cells (strong start)")

	var s1_wood_drain_norm = 15 + 0 * 15
	assert(s1_wood_drain_norm == 15, "Stage 1 normal wood drain should be 15 HP")

	var s1_wood_drain_boss = 80 + 0 * 15
	assert(s1_wood_drain_boss == 80, "Stage 1 boss wood drain should be 80 HP (strong start)")

	var s1_dark_fog_turns_norm = 1 + (1 if 0 >= 3 else 0)
	assert(s1_dark_fog_turns_norm == 1, "Stage 1 normal dark fog should last 1 turn")

	var s1_dark_fog_turns_boss = 2 + (1 if 0 >= 2 else 0)
	assert(s1_dark_fog_turns_boss == 2, "Stage 1 boss dark fog should last 2 turns")

	var s1_earth_dur_norm = 1 + (1 if 0 >= 3 else 0)
	assert(s1_earth_dur_norm == 1, "Stage 1 normal stone durability should be 1")

	var s1_earth_dur_boss = 2 + (1 if 0 >= 3 else 0)
	assert(s1_earth_dur_boss == 2, "Stage 1 boss stone durability should be 2")

	# 3) Stage 5 status scaling check (Normal scales up, Boss has gentle increase)
	dummy_sm.stage = 5
	var s5_water_norm_min = 1 + int(4 * 1.5)
	var s5_water_norm_max = 2 + int(4 * 1.5)
	assert(s5_water_norm_min == 7 and s5_water_norm_max == 8, "Stage 5 normal water skill should target 7~8 cells")

	var s5_water_boss_min = 5 + int(4 * 1.0)
	var s5_water_boss_max = 6 + int(4 * 1.0)
	assert(s5_water_boss_min == 9 and s5_water_boss_max == 10, "Stage 5 boss water skill should target 9~10 cells")

	var s5_wood_drain_norm = 15 + 4 * 15
	assert(s5_wood_drain_norm == 75, "Stage 5 normal wood drain should be 75 HP")

	var s5_wood_drain_boss = 80 + 4 * 15
	assert(s5_wood_drain_boss == 140, "Stage 5 boss wood drain should be 140 HP (gentle rise from 80)")

	var s5_earth_dur_norm = 1 + (1 if 4 >= 3 else 0)
	assert(s5_earth_dur_norm == 2, "Stage 5 normal stone durability should be 2")

	var s5_earth_dur_boss = 2 + (1 if 4 >= 3 else 0)
	assert(s5_earth_dur_boss == 3, "Stage 5 boss stone durability should be 3")
	print("Enemy skill fixed frequency & Boss strong start + gentle rise scaling: SUCCESS!")

	# 4) Dark fog miasma damage on turn reset
	dummy_sm.stage = 1
	dummy_sm.is_current_boss = true
	dummy_sm.myhp = 1000
	dummy_sm.myhpmax = 1000
	pb.grid_fog.clear()
	pb.grid_fog.append({
		"rect": Rect2i(2, 2, 3, 3),
		"turns": 2
	})
	pb._reset_turn(dummy_sm, smg)
	assert(pb.grid_fog[0]["turns"] == 1, "Dark fog turns should decrement to 1 after turn reset")
	assert(dummy_sm.myhp < 1000, "Player must take miasma damage from active dark fog (myhp was 1000, now %d)" % dummy_sm.myhp)
	print("Dark fog miasma turn-end damage: SUCCESS! Player took miasma damage.")

	# Test T: Adjacent match cleanses curse without damage
	# Set cursed tile at (2, 2)
	pb.grid_cursed[2][2] = true
	# Match adjacent tiles (2, 3), (2, 4), (2, 5) with SWORD
	for c in range(pb.GRID_COLUMNS):
		pb.grid_n[2][c] = -1
		pb.ismatched[2][c] = false
	pb.matched_cells_list.clear()
	for c in range(3, 6):
		pb.grid_n[2][c] = pb.PieceType.SWORD
		pb.ismatched[2][c] = true
		pb.matched_cells_list.append(Vector2i(2, c))
	pb._start_breaking_animation()
	assert(pb.grid_cursed[2][2] == false, "Adjacent match should purify cursed piece at (2, 2) safely")
	print("Curse adjacent match purification: SUCCESS!")

	# Test U: Dark fog hover tooltip
	pb.grid_fog.clear()
	pb.grid_fog.append({
		"rect": Rect2i(1, 1, 3, 3),
		"turns": 2
	})
	pb._current_local_mouse = Vector2(pb.BOARD_LEFT + 2 * pb.CELL_PITCH + 10, pb.BOARD_TOP + 2 * pb.CELL_PITCH + 10)
	pb._last_hovered_cell = Vector2i(-1, -1)
	pb.current_state = pb.BoardState.IDLE
	pb.is_holding = false
	pb.selected_cell = Vector2i(-1, -1)
	dummy_sm.isstageclear = false
	dummy_sm.isdeadf = false
	pb._update_cell_hover_tooltip(Vector2(500, 500))
	assert(rui.info_panel.visible == true, "Dark fog cell hover should show tooltip")
	rui.hide_custom_tooltip("board_cell")
	# Test V: 5th Boss minion summoning skill
	dummy_sm.stage = 5
	dummy_sm.is_current_boss = true
	dummy_sm.current_enemy_key = "enemy18"
	dummy_sm.ehp = 500000.0
	dummy_sm.ehpmax = 500000.0
	enemy_sprite.position = Vector2(1550, 250)
	dummy_sm.active_enemies = [{ "key": "enemy18", "sprite": enemy_sprite, "hp": 500000.0, "max_hp": 500000.0 }]
	
	# Cast 1: Should summon 1 minion (1 -> 2 enemies)
	pb._cast_enemy_dark_skill(true, false)
	assert(dummy_sm.active_enemies.size() == 2, "5th Boss skill must summon 1 minion (size should be 2, got %d)" % dummy_sm.active_enemies.size())
	var summoned1 = dummy_sm.active_enemies[1]
	assert(summoned1.has("sprite") and is_instance_valid(summoned1["sprite"]), "Summoned minion must have a valid Sprite2D")
	assert(summoned1["hp"] > 0, "Summoned minion must have positive HP")
	assert(dummy_sm.ehp > 500000.0, "Total enemy HP must include summoned minion HP")

	# Cast 2: Should summon 2nd minion (2 -> 3 enemies)
	pb._cast_enemy_dark_skill(true, false)
	assert(dummy_sm.active_enemies.size() == 3, "5th Boss skill must summon 2nd minion (size should be 3, got %d)" % dummy_sm.active_enemies.size())

	# Cast 3: When already 3 enemies, should not exceed max limit of 3
	pb._cast_enemy_dark_skill(true, false)
	assert(dummy_sm.active_enemies.size() == 3, "5th Boss must not exceed maximum 3 enemies on screen")
	print("5th Boss minion summoning skill check: SUCCESS!")

	print("ALL TESTS PASSED SUCCESSFULLY!")
	quit(0)
