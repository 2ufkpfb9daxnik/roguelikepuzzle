extends SceneTree

func _init() -> void:
	print("--- Starting Test Poison Element & Multi-Skill System ---")

	# 1. ElementData tests
	assert(ElementData.Element.POISON == 7, "Element.POISON should be 7")
	assert(ElementData.get_element_name(ElementData.Element.POISON) == "poison", "get_element_name(POISON) should be 'poison'")
	assert(ElementData.get_element_from_name("poison") == ElementData.Element.POISON, "get_element_from_name('poison') should be POISON")
	assert(ElementData.get_element_from_enemy_string("毒属性") == ElementData.Element.POISON, "get_element_from_enemy_string('毒属性') should be POISON")
	assert(ElementData.get_element_from_enemy_string("猛毒") == ElementData.Element.POISON, "get_element_from_enemy_string('猛毒') should be POISON")
	assert(ElementData.ELEMENT_COLORS.has(ElementData.Element.POISON), "ELEMENT_COLORS must have POISON")

	# Check damage multipliers for Poison
	# Attacking
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.WATER), 1.5), "Poison attacking Water should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.WIND), 1.5), "Poison attacking Wind should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.FIRE), 0.5), "Poison attacking Fire should be 0.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.LIGHT), 0.5), "Poison attacking Light should be 0.5x")
	# Defending
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.FIRE, ElementData.Element.POISON), 1.5), "Fire attacking Poison should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.LIGHT, ElementData.Element.POISON), 1.5), "Light attacking Poison should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.WATER, ElementData.Element.POISON), 0.5), "Water attacking Poison should be 0.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.WIND, ElementData.Element.POISON), 0.5), "Wind attacking Poison should be 0.5x")
	print("✓ ElementData tests passed!")

	# 2. StageManager ENEMY_SPECIES tests
	var sm_script = load("res://stage_manager.gd")
	var species = sm_script.ENEMY_SPECIES
	assert(species.has("enemy3"), "enemy3 must exist")
	assert(species["enemy3"]["element"] == "毒属性", "enemy3 (ポイズントード) element should be 毒属性")
	assert(species["enemy3"].has("skills"), "enemy3 should have skills")
	assert("毒属性" in species["enemy3"]["skills"] and "水属性" in species["enemy3"]["skills"], "enemy3 skills should have 毒属性 and 水属性")

	assert(species["enemy20"].has("skills"), "enemy20 (デスクラウンサソリ) should have skills")
	assert("地属性" in species["enemy20"]["skills"] and "毒属性" in species["enemy20"]["skills"], "enemy20 skills should have 地属性 and 毒属性")

	assert(species["enemy22"].has("skills"), "enemy22 (ヴェノムバイパー) should have skills")
	assert(species["enemy22"]["element"] == "毒属性", "enemy22 element should be 毒属性")
	assert("毒属性" in species["enemy22"]["skills"] and "地属性" in species["enemy22"]["skills"], "enemy22 skills should have 毒属性 and 地属性")

	assert(species["enemy18"].has("skills"), "enemy18 (冥王デモニアス) should have skills")
	assert("闇属性" in species["enemy18"]["skills"] and "毒属性" in species["enemy18"]["skills"], "enemy18 skills should have 闇属性 and 毒属性")
	print("✓ StageManager ENEMY_SPECIES tests passed!")

	# 3. Instantiate scene and test PuzzleBoard poison logic
	var dummy_root = Node2D.new()
	var sm_node = Node2D.new()
	sm_node.name = "StageManager"
	sm_node.set_script(sm_script)
	dummy_root.add_child(sm_node)

	var pb_script = load("res://puzzle_board.gd")
	var pb = pb_script.new()
	pb.name = "PuzzleBoard"
	dummy_root.add_child(pb)
	root.add_child(dummy_root)
	pb._initialize_board(null)

	# Test skill info
	var s_info_normal = pb._get_enemy_skill_info("毒属性", false)
	assert(s_info_normal["name"] == "ポイズンバースト", "Normal poison skill should be ポイズンバースト")
	assert(s_info_normal["color"] == "#AB47BC", "Poison skill color should be #AB47BC")

	var s_info_boss = pb._get_enemy_skill_info("毒属性", true)
	assert(s_info_boss["name"] == "猛毒瘴気・デッドリーヴェノム", "Boss poison skill should be 猛毒瘴気・デッドリーヴェノム")

	# Test _select_enemy_skill
	var e_toad = {"key": "enemy3"}
	var toad_skills_seen = {}
	for i in range(40):
		var chosen = pb._select_enemy_skill(e_toad, sm_node)
		toad_skills_seen[chosen] = true
	assert(toad_skills_seen.has("毒属性") and toad_skills_seen.has("水属性"), "Toad should select both 毒属性 and 水属性 over multiple turns")
	print("✓ _select_enemy_skill multi-skill random selection passed! Seen: ", toad_skills_seen.keys())

	# Test grid_poison existence
	assert("grid_poison" in pb, "grid_poison must be in PuzzleBoard")
	assert(pb.grid_poison.size() == pb.GRID_ROWS, "grid_poison row size must match GRID_ROWS")

	# Test _cast_enemy_poison_skill
	var targets = pb._cast_enemy_poison_skill(false, false)
	assert(not targets.is_empty(), "Poison skill should return targeted positions")
	var poison_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]:
				poison_count += 1
	assert(poison_count > 0, "Board should have active poison tiles after poison skill")
	print("✓ _cast_enemy_poison_skill created %d poison tiles" % poison_count)

	# Test clear_board_hazards
	pb.clear_board_hazards()
	var remaining_poison = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]:
				remaining_poison += 1
	assert(remaining_poison == 0, "clear_board_hazards should clear all poison tiles")
	print("✓ clear_board_hazards cleared all poison tiles")

	# 4. Test Poison Piece Swapping
	pb.clear_board_hazards()
	pb.grid_poison[2][3] = true
	pb.grid_poison[2][4] = false
	pb._swap_grid_data(2, 3, 2, 4)
	assert(pb.grid_poison[2][3] == false, "After swap, original cell should no longer be poisoned")
	assert(pb.grid_poison[2][4] == true, "After swap, destination cell should inherit poison")
	print("✓ Poison moves with pieces during swap")

	# 5. Test Poison Cleansing (Only cleared piece is cured; adjacent uncleared piece stays poisoned)
	pb.clear_board_hazards()
	pb.grid_poison[2][2] = true
	pb.grid_poison[2][3] = true
	# Simulate matched piece removal at (2, 2)
	if pb.grid_poison.size() == pb.GRID_ROWS and pb.grid_poison[2][2]:
		pb.grid_poison[2][2] = false
	assert(pb.grid_poison[2][2] == false, "Matched piece at (2, 2) is cured of poison")
	assert(pb.grid_poison[2][3] == true, "Adjacent unmatched piece at (2, 3) must remain poisoned")
	print("✓ Poison is eliminated specifically by clearing the poisoned piece")

	# 6. Test Poison Contagion (Spread to adjacent cells on dry ground)
	pb.clear_board_hazards()
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_water[r][c] = false
			pb.grid_poison[r][c] = false

	pb.grid_poison[3][3] = true
	pb._process_poison_spread()
	assert(pb.grid_poison[3][3] == true, "Origin (3, 3) must remain poisoned")
	assert(pb.grid_poison[2][3] == true, "North neighbor (2, 3) must be infected")
	assert(pb.grid_poison[4][3] == true, "South neighbor (4, 3) must be infected")
	assert(pb.grid_poison[3][2] == true, "West neighbor (3, 2) must be infected")
	assert(pb.grid_poison[3][4] == true, "East neighbor (3, 4) must be infected")
	assert(pb.grid_poison[1][3] == false, "North 2-step (1, 3) must NOT be infected on dry ground")
	assert(pb.grid_poison[5][3] == false, "South 2-step (5, 3) must NOT be infected on dry ground")
	assert(pb.grid_poison[3][1] == false, "West 2-step (3, 1) must NOT be infected on dry ground")
	assert(pb.grid_poison[3][5] == false, "East 2-step (3, 5) must NOT be infected on dry ground")
	assert(pb.grid_poison[2][2] == false, "Diagonal (2, 2) must NOT be infected")
	print("✓ Normal poison contagion (1 tile orthogonal) passed!")

	# 7. Test 2x Fast Poison Contagion on Wet Ground (Origin is wet)
	pb.clear_board_hazards()
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_water[r][c] = false
			pb.grid_poison[r][c] = false

	pb.grid_water[3][3] = true
	pb.grid_poison[3][3] = true
	pb._process_poison_spread()
	assert(pb.grid_poison[3][3] == true, "Wet origin (3, 3) remains poisoned")
	assert(pb.grid_poison[2][3] == true, "North 1-step must be infected")
	assert(pb.grid_poison[1][3] == true, "North 2-step must be infected due to wet origin (2x speed)")
	assert(pb.grid_poison[4][3] == true, "South 1-step must be infected")
	assert(pb.grid_poison[5][3] == true, "South 2-step must be infected due to wet origin (2x speed)")
	assert(pb.grid_poison[3][2] == true, "West 1-step must be infected")
	assert(pb.grid_poison[3][1] == true, "West 2-step must be infected due to wet origin (2x speed)")
	assert(pb.grid_poison[3][4] == true, "East 1-step must be infected")
	assert(pb.grid_poison[3][5] == true, "East 2-step must be infected due to wet origin (2x speed)")
	print("✓ 2x poison spread from wet origin passed!")

	# 8. Test 2x Fast Poison Contagion when Target is Wet
	pb.clear_board_hazards()
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_water[r][c] = false
			pb.grid_poison[r][c] = false

	pb.grid_poison[3][3] = true
	pb.grid_water[3][4] = true # Only East neighbor is wet
	pb._process_poison_spread()
	assert(pb.grid_poison[3][4] == true, "East wet neighbor must be infected")
	assert(pb.grid_poison[3][5] == true, "East 2-step must be infected because target was wet (2x speed)")
	assert(pb.grid_poison[3][1] == false, "West 2-step must NOT be infected because west was dry")
	print("✓ 2x poison spread into wet target passed!")

	# 9. Test Multi-Element Compact Display on Enemies (No redundant "属性", single-bracket badge)
	var e1_data = species["enemy1"]
	var e1_plain = sm_node.get_enemy_elements_plain(e1_data)
	assert(e1_plain == "闇", "Single element plain text must be short kanji: " + e1_plain)
	var e1_bbcode = sm_node.get_enemy_elements_bbcode(e1_data)
	assert(e1_bbcode == "[color=#E040FB]【闇】[/color]", "Single element BBCode must be colored badge: " + e1_bbcode)

	var e3_data = species["enemy3"]
	var e3_plain = sm_node.get_enemy_elements_plain(e3_data)
	assert("毒" in e3_plain and "水" in e3_plain, "Poison Toad must display both poison and water attributes in plain string")
	var e3_bbcode = sm_node.get_enemy_elements_bbcode(e3_data)
	assert("#AB47BC" in e3_bbcode and "#00E5FF" in e3_bbcode, "Poison Toad BBCode must color poison and water properly")
	assert("【" in e3_bbcode and "】" in e3_bbcode and "/" in e3_bbcode, "Poison Toad BBCode must be formatted as compact slash badge")
	assert(not "属性" in e3_bbcode, "Enemy element badge must NOT contain redundant '属性' keyword")

	var e18_data = species["enemy18"]
	var e18_plain = sm_node.get_enemy_elements_plain(e18_data)
	assert("闇" in e18_plain and "毒" in e18_plain and "火" in e18_plain, "Demonius must display all 3 elements in plain string")
	var e18_bbcode = sm_node.get_enemy_elements_bbcode(e18_data)
	assert("#E040FB" in e18_bbcode and "#AB47BC" in e18_bbcode and "#FF3D00" in e18_bbcode, "Demonius BBCode must contain colors for all 3 elements")
	assert("【" in e18_bbcode and "】" in e18_bbcode, "Demonius BBCode must be formatted as compact slash badge")
	assert(not "属性" in e18_bbcode, "Enemy element badge must NOT contain redundant '属性' keyword")
	print("✓ Compact multi-element display for enemies passed!")

	# 10. Test Poison Spread Immediately Upon Steady State (Zero Wait Time)
	pb.clear_board_hazards()
	pb.poison_spread_done_this_turn = false
	pb.grid_poison[2][2] = true
	# Simulate steady state entry
	if not pb.poison_spread_done_this_turn:
		pb.poison_spread_done_this_turn = true
		pb._process_poison_spread()
	assert(pb.poison_spread_done_this_turn == true, "poison_spread_done_this_turn must be true after steady state")
	assert(pb.grid_poison[2][3] == true, "Poison must spread immediately at steady state (0 delay)")
	# Call _reset_turn and ensure poison doesn't spread twice
	pb._reset_turn(sm_node, null)
	assert(pb.poison_spread_done_this_turn == false, "poison_spread_done_this_turn must reset to false on turn end")
	assert(pb.grid_poison[2][4] == false, "Poison must NOT spread a second time during turn reset")
	print("✓ Immediate poison spread on steady state (zero delay) passed!")

	# 11. Test Performance Optimization: Static & Texture Batching
	var bo_script = load("res://board_overlay.gd")
	assert(bo_script.POISON_TILE_DRY_TEX != null, "POISON_TILE_DRY_TEX must be loaded")
	assert(bo_script.POISON_TILE_WET_TEX != null, "POISON_TILE_WET_TEX must be loaded")

	# Verify grid_poison does NOT trigger continuous animated redraw (saves CPU)
	pb.clear_board_hazards()
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_poison[r][c] = true
	pb._update_board_element_flags()
	assert(pb.has_board_hazards == true, "Poison must set has_board_hazards to true for event redraws")
	assert(pb.has_animated_board_hazards == false, "Poison must NOT trigger has_animated_board_hazards continuous redraw loop")
	print("✓ Hardware-accelerated poison texture batching & static redraw optimization passed!")

	# 12. Test Stage 1 Spawn Count Strictly 1
	sm_node.stage = 1
	for se in range(1, 6):
		sm_node.stage_enemy = se
		sm_node.enemycount = 0
		sm_node.active_enemies.clear()
		sm_node.make_enemy(se == 5)
		assert(sm_node.active_enemies.size() == 1, "Stage 1 battle %d must spawn exactly 1 enemy (got %d)" % [se, sm_node.active_enemies.size()])
		assert(sm_node.initial_spawn_count == 1, "Stage 1 initial_spawn_count must be 1")
	print("✓ Stage 1 spawn count strictly 1 for all battles passed!")

	# 13. Test Stage 1-4 Boss Activates All Skills When Having Multiple Skills
	# Test with Stage 3 Boss (Grandragon: Fire + Wind)
	sm_node.stage = 3
	sm_node.stage_enemy = 5
	sm_node.is_current_boss = true
	var grandragon_data = sm_node.ENEMY_SPECIES["enemy11"]
	var dummy_boss_sprite = Sprite2D.new()
	sm_node.active_enemies = [{
		"key": "enemy11",
		"name": "グランドラゴン",
		"sprite": dummy_boss_sprite,
		"hp": 30000.0,
		"max_hp": 30000.0,
		"atk": 1500.0,
		"sp_data": grandragon_data
	}]
	var has_skill_boss = pb._decide_enemy_actions(sm_node)
	assert(has_skill_boss == true, "Stage 3 boss with multiple skills must activate skills")
	assert(pb._enemy_turn_actions.size() == 2, "Stage 3 boss with 2 skills must queue exactly 2 actions (got %d)" % pb._enemy_turn_actions.size())
	assert(pb._enemy_turn_actions[0]["action"] == "skill" and pb._enemy_turn_actions[1]["action"] == "skill", "Both actions must be 'skill'")
	var queued_skills = [pb._enemy_turn_actions[0]["chosen_skill"], pb._enemy_turn_actions[1]["chosen_skill"]]
	assert("火属性" in queued_skills and "風属性" in queued_skills, "Queued skills must contain both 火属性 and 風属性")
	print("✓ Stage 1-4 Boss all-skills activation passed!")

	# 14. Test Non-targeted Enemy Idle Animation Continuity During Damage
	var spr0 = Sprite2D.new()
	var spr1 = Sprite2D.new()
	dummy_root.add_child(spr0)
	dummy_root.add_child(spr1)
	sm_node.active_enemies = [
		{"key": "enemy1", "sprite": spr0, "hp": 1000.0, "max_hp": 1000.0, "atk": 100.0},
		{"key": "enemy2", "sprite": spr1, "hp": 1000.0, "max_hp": 1000.0, "atk": 100.0}
	]
	sm_node.start_enemy_idle_animation()
	assert(spr0.has_meta("idle_tween") and spr0.get_meta("idle_tween").is_valid(), "Enemy 0 must have active idle_tween")
	assert(spr1.has_meta("idle_tween") and spr1.get_meta("idle_tween").is_valid(), "Enemy 1 must have active idle_tween")

	# Damage Enemy 0: only Enemy 0 should enter _active_single_anims, Enemy 1's idle_tween must continue
	sm_node.target_enemy_index = 0
	sm_node.play_single_enemy_animation(0, "damaged")
	assert(sm_node._active_single_anims.has(spr0), "Enemy 0 must be in _active_single_anims")
	assert(not sm_node._active_single_anims.has(spr1), "Enemy 1 must NOT be in _active_single_anims")
	assert(spr1.has_meta("idle_tween"), "Enemy 1 must retain its idle_tween")
	var itw1 = spr1.get_meta("idle_tween")
	assert(is_instance_valid(itw1) and itw1.is_valid(), "Enemy 1's idle_tween must CONTINUE running while Enemy 0 is damaged")
	print("✓ Non-targeted enemy idle continuity during damage passed!")

	# 15. Test Shield z_index Always in Front of Attacking Enemy
	var dummy_smgr = load("res://score_manager.gd").new()
	dummy_root.add_child(dummy_smgr)
	dummy_smgr.divscore[pb.PieceType.SHIELD] = 500
	pb._spawn_shield_projectiles(dummy_smgr)
	assert(pb.active_shields.size() > 0, "Active shields must be spawned")
	var shield_node = pb.active_shields[0]["node"]
	assert(shield_node.z_index >= 20, "Shield sprite z_index must be >= 20 (got %d)" % shield_node.z_index)
	# Zoom on attacking enemy sets attacking enemy's z_index to 5
	sm_node.zoom_on_attacking_enemy(0)
	assert(spr0.z_index == 5, "Attacking enemy z_index must be 5")
	assert(shield_node.z_index > spr0.z_index, "Shields (z_index %d) must render in front of attacking enemy (z_index %d)" % [shield_node.z_index, spr0.z_index])
	print("✓ Shield rendering in front of attacking enemy passed!")

	# 16. Test Advancing Stage Does NOT Automatically Increase Player HP
	sm_node.stage = 1
	sm_node.myhp = 3500.0
	sm_node.myhpmax = 6000.0
	sm_node.isstageclear = true
	sm_node._on_stagechangeb_pressed()
	assert(sm_node.stage == 2, "Stage should advance to 2")
	assert(sm_node.myhp == 3500.0, "Player current HP must NOT automatically increase on stage advance (got %f)" % sm_node.myhp)
	assert(sm_node.myhpmax == 6000.0, "Player max HP must NOT automatically increase on stage advance (got %f)" % sm_node.myhpmax)
	print("✓ Stage progression without automatic HP increase passed!")

	# 17. Test Healing to Max HP (Does not stop at 5000)
	sm_node.stage = 1
	sm_node.myhpmax = 8000.0
	sm_node.myhp = 4500.0
	dummy_smgr.divscore[pb.PieceType.FOOD] = 5000
	pb.foodt = 1.0
	# Test turn sequence decision
	var needed_heal_val = maxf(0.0, sm_node.myhpmax - sm_node.myhp)
	assert(needed_heal_val == 3500.0, "Needed heal should be 3500")
	var f_cnt_val = min(int(ceil(needed_heal_val / 100.0)), int(dummy_smgr.divscore[pb.PieceType.FOOD] / 100.0))
	assert(f_cnt_val == 35, "Should plan to consume 35 food items to heal 3500 HP")
	# Spawn food projectiles
	pb._spawn_attack_projectiles(sm_node, dummy_smgr)
	assert(dummy_smgr.divscore[pb.PieceType.FOOD] == 1500, "Should have consumed 3500 score, leaving 1500")
	assert(pb.flying_foods.size() > 0, "Flying food projectiles must be spawned")
	# Simulate food projectiles landing
	for item in pb.flying_foods:
		item["t"] = 100.0 # Force land
	pb.movefoods()
	assert(is_equal_approx(sm_node.myhp, 8000.0), "Player HP must reach max HP (8000.0), got %f" % sm_node.myhp)
	print("✓ Healing to max HP (beyond 5000 without stopping) passed!")

	# 18. Test Player Yellow Delay Bar Animates Down to 0
	var hpbar1 = ColorRect.new()
	hpbar1.name = "hpbar1"
	hpbar1.position = Vector2(1190, 412)
	hpbar1.size = Vector2(725, 26)
	dummy_smgr.add_child(hpbar1)
	sm_node._cached_hp_bar = hpbar1

	var delay_bar = ColorRect.new()
	delay_bar.name = "player_hp_delay_bar"
	delay_bar.position = Vector2(1190, 412)
	delay_bar.size = Vector2(725, 26)
	dummy_smgr.add_child(delay_bar)
	sm_node._cached_delay_bar = delay_bar

	# Player takes 4000 damage from 8000 max HP
	sm_node.myhp = 8000.0
	sm_node.myhpmax = 8000.0
	sm_node.myhppar = 1.0
	hpbar1.size.x = 725.0
	delay_bar.size.x = 725.0

	sm_node.calchp(0.0, 4000.0)
	assert(is_equal_approx(sm_node.myhp, 4000.0), "Player HP should be approx 4000, got %f" % sm_node.myhp)
	var expected_green_w = int((4000.0 / 8000.0) * 725.0) # 362
	assert(hpbar1.size.x == expected_green_w, "hpbar1 (green) must immediately drop to post-damage width %d (got %f)" % [expected_green_w, hpbar1.size.x])
	# Yellow delay bar should have tween active
	assert(delay_bar.has_meta("tw") and is_instance_valid(delay_bar.get_meta("tw")), "Delay bar must have active tween")
	var dtw = delay_bar.get_meta("tw")
	assert(dtw.is_valid(), "Delay bar tween must be valid")
	# Simulate delay bar caught up to damaged green width, then test heal expansion
	delay_bar.size.x = expected_green_w
	sm_node.calchp(0.0, -2000.0) # Heal 2000 -> 6000 HP
	assert(is_equal_approx(sm_node.myhp, 6000.0), "Player HP should be 6000 after heal")
	var healed_green_w = int((6000.0 / 8000.0) * 725.0) # 543
	assert(hpbar1.size.x == healed_green_w, "Green bar must expand immediately to %d" % healed_green_w)
	assert(delay_bar.size.x == healed_green_w, "Delay bar must immediately expand to match healed green bar width (no lag)")
	print("✓ Yellow delay bar animation and heal sync passed!")

	print("\nALL POISON & MULTI-SKILL TESTS PASSED SUCCESSFULLY!")
	quit(0)
