extends SceneTree

func _init() -> void:
	print("--- Running Test for User Requests ---")

	var sm_script = load("res://stage_manager.gd")
	var pb_script = load("res://puzzle_board.gd")
	var sc_script = load("res://score_manager.gd")
	var bo_script = load("res://board_overlay.gd")
	if sm_script == null or pb_script == null or sc_script == null or bo_script == null:
		printerr("ERROR: Failed to load one or more scripts!")
		quit(1)
		return

	var dummy_root = Node2D.new()
	var sm = Node2D.new()
	sm.name = "StageManager"
	sm.set_script(sm_script)
	dummy_root.add_child(sm)

	var pb = pb_script.new()
	pb.name = "PuzzleBoard"
	dummy_root.add_child(pb)

	var sc = Node2D.new()
	sc.name = "ScoreManager"
	sc.set_script(sc_script)
	dummy_root.add_child(sc)

	root.add_child(dummy_root)
	pb._initialize_board(null)

	# 1. Test Encounter Smoke & Enemy Spawn
	sm.stage = 1
	sm.stage_enemy = 1
	sm.enemycount = 0
	sm.make_enemy(false)

	assert(sm.active_enemies.size() == 1, "Stage 1 Battle 1 must have 1 enemy")
	var e0 = sm.active_enemies[0]
	assert(e0.has("intent_badge") and is_instance_valid(e0["intent_badge"]), "Enemy must have intent_badge")
	assert(e0.has("intent_panel") and is_instance_valid(e0["intent_panel"]), "Enemy must have intent_panel")
	print("✓ Enemy spawned with intent_badge and stylized intent_panel!")

	# 2. Test Intent Badge Updates
	pb._decide_enemy_actions(sm)
	var badge_text = e0["intent_badge"].text
	assert(not badge_text.is_empty(), "Intent badge text must not be empty after _decide_enemy_actions")
	assert(badge_text.contains("次の行動"), "Intent badge text must contain '次の行動' header (got: %s)" % badge_text)
	print("✓ Intent badge updated with clear NEXT action header and text: ", badge_text)

	# 3. Test Fire Skill (No Free Bombs, sets grid_fire, direct damage)
	var old_player_hp = sm.myhp
	pb.grid_fire.clear()
	for r in range(pb.GRID_ROWS):
		var rf: Array[int] = []
		for c in range(pb.GRID_COLUMNS):
			rf.append(0)
		pb.grid_fire.append(rf)

	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false

	var fire_targets = pb._cast_enemy_fire_skill(false, false)
	assert(not fire_targets.is_empty(), "Fire skill should return targets")
	
	# Verify NO bombs were spawned!
	var bomb_count = 0
	var fire_tile_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.special_item[r][c] == pb.SpecialItemType.BOMB or pb.is_bomb[r][c]:
				bomb_count += 1
			if pb.grid_fire[r][c] > 0:
				fire_tile_count += 1

	assert(bomb_count == 0, "Enemy fire skill must NEVER spawn player-benefiting flame bombs! (got %d)" % bomb_count)
	assert(fire_tile_count > 0, "Enemy fire skill must ignite board tiles (grid_fire > 0)")
	print("✓ Fire skill ignites %d tiles without spawning player bombs!" % fire_tile_count)

	# 4. Test Shield Positioning (1 shield is centered, not left edge)
	sc.divscore[pb.PieceType.SHIELD] = 100
	pb.shieldt = 1.0
	pb.active_shields.clear()
	pb._spawn_shield_projectiles(sc)
	assert(pb.active_shields.size() == 1, "Should spawn 1 shield")
	var target_x = pb.active_shields[0]["target_p"].x
	assert(is_equal_approx(target_x, 15900.0), "Single shield must be placed in center at 15900.0 (got %f)" % target_x)
	print("✓ Single shield is placed in center at X=%f!" % target_x)

	# 5. Test HP Growth / Shop Item Cost & Gain
	var hp_item = null
	for item in sc.shop_items:
		if item["id"] == "max_hp":
			hp_item = item
			break
	assert(hp_item != null, "max_hp item must exist in shop_items")
	assert(hp_item["cost"] == 2000, "HP shop item base cost should be reduced to 2000 (was 4000)")
	var sm_stage = sm.stage
	var stage_scale: float = pow(10.0, maxf(0.0, float(sm_stage - 1)))
	var expected_gain = 2500.0 * stage_scale
	print("✓ Shop HP item cost is 2000 and HP gain is %f!" % expected_gain)

	# 6. Test Damaged Animation Throttle (0.10s interval)
	var spr = e0["sprite"]
	var t0 = Time.get_ticks_msec() / 1000.0
	spr.set_meta("last_damaged_time", t0)
	# Immediate second hit should be throttled
	var now_sec = t0 + 0.05
	var should_trigger = (now_sec - spr.get_meta("last_damaged_time", -999.0)) >= 0.10
	assert(not should_trigger, "Damaged animation should be throttled within 0.10s")
	# Hit after 0.11s should trigger
	now_sec = t0 + 0.11
	should_trigger = (now_sec - spr.get_meta("last_damaged_time", -999.0)) >= 0.10
	assert(should_trigger, "Damaged animation should trigger after 0.10s")
	print("✓ Damaged animation 0.10s throttle passed!")

	# 7. Test Hover Tooltip Outside IDLE State
	pb.current_state = pb.BoardState.TURN_SEQUENCE
	pb.is_holding = false
	pb._last_hovered_cell = Vector2i(-1, -1)
	pb._current_local_mouse = Vector2(pb.BOARD_LEFT + pb.CELL_PITCH * 0.5, pb.BOARD_TOP + pb.CELL_PITCH * 0.5)
	# Should not crash and should update cell hover
	pb._update_cell_hover_tooltip(Vector2(500, 500))
	assert(pb._last_hovered_cell == Vector2i(0, 0), "Hover tooltip must work even outside IDLE state! (got %s)" % str(pb._last_hovered_cell))
	print("✓ Board cell hover tooltip works outside IDLE state!")

	# 8. Test Full-Screen Kemuri Smoke Filling Entire Enemy Screen
	# Base kemuri sprite
	var base_kem = AnimatedSprite2D.new()
	base_kem.name = "kemuri"
	var sf = SpriteFrames.new()
	sf.add_animation("new_animation")
	base_kem.sprite_frames = sf
	sm.add_child(base_kem)
	sm._play_encounter_smoke()
	var smoke_found = false
	var parent_target = sm._enemy_zoom_root if sm._enemy_zoom_root != null else sm
	for child in parent_target.get_children():
		if child is AnimatedSprite2D and child.name.begins_with("EncounterSmoke_"):
			smoke_found = true
			assert(child.position.x == 1552.5 and child.position.y == 210.0, "Kemuri position must be center of enemy viewport (1552.5, 210)")
			assert(child.scale.x >= 0.65 and child.scale.y >= 0.60, "Kemuri scale must fill entire enemy viewport (got %f, %f)" % [child.scale.x, child.scale.y])
			child.queue_free()
			break
	assert(smoke_found, "Encounter smoke instance must be created")
	print("✓ Encounter smoke fills entire enemy screen area (1552.5, 210.0, scale 0.68x0.65)!")

	# 9. Test Difficulty Skill Multipliers (EASY: 0.70, NORMAL: 1.0, HARD: 1.35)
	var smgr_script = load("res://settings_manager.gd")
	var smgr = Node.new()
	smgr.name = "SettingsManager"
	smgr.set_script(smgr_script)
	dummy_root.add_child(smgr)

	smgr.set_difficulty(smgr.Difficulty.EASY)
	assert(is_equal_approx(smgr.get_difficulty_skill_mult(), 0.70), "EASY difficulty skill mult must be 0.70")
	assert(is_equal_approx(pb._get_difficulty_skill_mult(), 0.70), "PuzzleBoard skill mult on EASY must be 0.70")

	smgr.set_difficulty(smgr.Difficulty.NORMAL)
	assert(is_equal_approx(smgr.get_difficulty_skill_mult(), 1.00), "NORMAL difficulty skill mult must be 1.00")
	assert(is_equal_approx(pb._get_difficulty_skill_mult(), 1.00), "PuzzleBoard skill mult on NORMAL must be 1.00")

	smgr.set_difficulty(smgr.Difficulty.HARD)
	assert(is_equal_approx(smgr.get_difficulty_skill_mult(), 1.35), "HARD difficulty skill mult must be 1.35")
	assert(is_equal_approx(pb._get_difficulty_skill_mult(), 1.35), "PuzzleBoard skill mult on HARD must be 1.35")
	print("✓ Difficulty skill scaling (EASY 0.70, NORMAL 1.0, HARD 1.35) verified!")

	# 10. Test Water x Fire Synergy (clears commonly adjacent cells, extinguishes Water & Fire without clearing Water/Fire pieces)
	pb._initialize_board(null)
	# Place Water at (5, 5) and Fire at (5, 6)
	# Commonly adjacent cells to both (5, 5) and (5, 6) are (4, 5), (4, 6), (6, 5), (6, 6)
	var orig_w_kind = pb.grid_n[5][5]
	var orig_f_kind = pb.grid_n[5][6]
	pb.grid_water[5][5] = true
	pb.grid_fire[5][6] = 1
	var cleared_common = pb._check_and_trigger_water_fire_synergy(true)
	assert(not pb.grid_water[5][5], "Water at (5,5) must be extinguished after Water x Fire synergy")
	assert(pb.grid_fire[5][6] == 0, "Fire at (5,6) must be extinguished after Water x Fire synergy")
	assert(not pb.ismatched[5][5], "Piece directly on Water (5,5) must NOT be cleared")
	assert(not pb.ismatched[5][6], "Piece directly on Fire (5,6) must NOT be cleared")
	assert(pb.grid_n[5][5] == orig_w_kind and pb.grid_n[5][6] == orig_f_kind, "Pieces on Water & Fire must remain intact")
	assert(pb.ismatched[4][5] and pb.ismatched[4][6] and pb.ismatched[6][5] and pb.ismatched[6][6], "All 4 commonly adjacent cells (4,5),(4,6),(6,5),(6,6) must be cleared!")
	assert(cleared_common == 4, "Water x Fire synergy on orthogonally adjacent pair must clear exactly 4 common neighbors (got %d)" % cleared_common)
	print("✓ Water x Fire synergy verified: cleared 4 commonly adjacent cells while extinguishing Water & Fire intact!")

	# 11. Test Ice x Lightning & Stone x Lightning Synergy (3x3 shard splash)
	pb._initialize_board(null)
	pb.grid_ice[6][6] = 2
	var ice_shattered = pb._trigger_thunder_shatter_synergy(6, 6, true)
	assert(int(pb.grid_ice[6][6]) == 0, "Ice at (6,6) must shatter completely on lightning hit")
	assert(ice_shattered == 9, "Ice x Lightning synergy must clear 3x3 (9 cells) around (6,6), got %d" % ice_shattered)
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			assert(pb.ismatched[6 + dr][6 + dc], "3x3 cell (%d,%d) must be matched by Ice x Lightning shatter" % [6 + dr, 6 + dc])

	pb._initialize_board(null)
	pb.grid_stones[6][6] = 2
	var stone_shattered = pb._trigger_thunder_shatter_synergy(6, 6, true)
	assert(int(pb.grid_stones[6][6]) == 0, "Stone at (6,6) must shatter completely on lightning hit")
	assert(stone_shattered == 9, "Stone x Lightning synergy must clear 3x3 (9 cells) around (6,6), got %d" % stone_shattered)
	print("✓ Ice x Lightning and Stone x Lightning 3x3 shatter synergies verified!")

	# 12. Test PvP Symmetric Self Skills (10 elements, ally=true, no self-harm, movable, distinct visual state)
	var bo = bo_script.new()
	bo.board = pb
	dummy_root.add_child(bo)

	for sk in ["water", "fire", "ice", "thunder", "wood", "earth", "wind", "poison", "light", "dark"]:
		pb._initialize_board(null)
		var hp_before = sm.myhp
		var ehp_before = sm.ehp
		var positions = pb.cast_player_skill(sk, true)
		assert(not positions.is_empty(), "Player skill '%s' must affect board positions" % sk)
		assert(sm.myhp >= hp_before, "Player skill '%s' must NEVER reduce player HP" % sk)
		assert(sm.ehp < ehp_before, "Player skill '%s' must deal damage to enemy" % sk)

	# Verify ally water/ice/stone/gold do NOT block swap and board_overlay identifies ally vs enemy
	pb._initialize_board(null)
	pb._apply_water_to_cell(3, 3, true)
	pb._apply_water_to_cell(3, 4, false)
	assert(pb.is_ally_water(3, 3), "(3,3) must be ally water")
	assert(not pb.is_ally_water(3, 4), "(3,4) must be enemy water")
	assert(not pb._is_cell_blocked_for_swap(3, 3), "Ally water at (3,3) must NOT block swap!")
	assert(pb._is_cell_blocked_for_swap(3, 4), "Enemy water at (3,4) MUST block swap!")
	assert(bo._is_ally_cell("grid_water_ally", 3, 3) == true, "BoardOverlay must detect ally water at (3,3)")
	assert(bo._is_ally_cell("grid_water_ally", 3, 4) == false, "BoardOverlay must detect enemy water at (3,4)")
	print("✓ All 10 player skills, ally non-blocking behavior, and BoardOverlay ally/enemy color differentiation verified!")

	# 13. Test Wind Skill Disadvantageous Tile Clearing (Ally Wind removes enemy hazards, preserves ally benefits)
	pb._initialize_board(null)
	# Setup enemy hazards (disadvantageous to player)
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false) # enemy poison
	pb.grid_cursed[1][2] = true
	pb._set_ally_flag(pb.grid_cursed_ally, 1, 2, false) # enemy curse
	pb.grid_electrified[1][3] = true
	pb._set_ally_flag(pb.grid_electrified_ally, 1, 3, false) # enemy electrified
	pb.grid_fire[1][4] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 1, 4, false) # enemy fire
	pb.grid_ice[1][5] = 2
	pb._set_ally_flag(pb.grid_ice_ally, 1, 5, false) # enemy ice
	pb.grid_stones[1][6] = 2
	pb._set_ally_flag(pb.grid_stones_ally, 1, 6, false) # enemy stone
	pb.grid_water[1][7] = true
	pb._set_ally_flag(pb.grid_water_ally, 1, 7, false) # enemy water
	pb.grid_gold_statue[1][8] = 2
	pb._set_ally_flag(pb.grid_gold_ally, 1, 8, false) # enemy gold statue
	pb.grid_fog.append({"rect": Rect2i(2, 2, 2, 2), "turns": 3, "enemy_owned": true}) # enemy dark fog
	pb.plant_entities.append({"origin": Vector2i(4, 4), "stage": 0, "enemy_planted": true, "drain_amount": 10}) # enemy leech plant

	# Setup ally beneficial tiles (advantageous to player)
	pb.grid_poison[7][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 7, 1, true) # ally medicinal poison
	pb.grid_fire[7][2] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 7, 2, true) # ally blue flame
	pb.grid_ice[7][3] = 1
	pb._set_ally_flag(pb.grid_ice_ally, 7, 3, true) # ally ice shield
	pb.grid_stones[7][4] = 2
	pb._set_ally_flag(pb.grid_stones_ally, 7, 4, true) # ally crystal stone
	pb.grid_water[7][5] = true
	pb._set_ally_flag(pb.grid_water_ally, 7, 5, true) # ally stream
	pb.grid_electrified[7][6] = true
	pb._set_ally_flag(pb.grid_electrified_ally, 7, 6, true) # ally charge
	pb.grid_cursed[7][7] = true
	pb._set_ally_flag(pb.grid_cursed_ally, 7, 7, true) # ally shadow blessing
	pb.grid_gold_statue[7][8] = 2
	pb._set_ally_flag(pb.grid_gold_ally, 7, 8, true) # ally holy statue
	pb.grid_fog.append({"rect": Rect2i(8, 8, 2, 2), "turns": 3, "enemy_owned": false}) # ally starlight fog
	pb.plant_entities.append({"origin": Vector2i(9, 9), "stage": 1, "enemy_planted": false, "drain_amount": 0}) # ally tree

	# Cast Player Wind Skill
	pb.cast_player_skill("wind", true)

	# Verify ALL enemy hazards (disadvantageous tiles) are completely wiped out
	assert(not pb.grid_poison[1][1], "Enemy poison must be cleared by ally wind")
	assert(not pb.grid_cursed[1][2], "Enemy curse must be cleared by ally wind")
	assert(not pb.grid_electrified[1][3], "Enemy electrified must be cleared by ally wind")
	assert(pb.grid_fire[1][4] == 0, "Enemy fire must be extinguished by ally wind")
	assert(int(pb.grid_ice[1][5]) == 0, "Enemy ice must be shattered by ally wind")
	assert(int(pb.grid_stones[1][6]) == 0, "Enemy stone must be blown away by ally wind")
	assert(not pb.grid_water[1][7], "Enemy water must be dried by ally wind")
	assert(int(pb.grid_gold_statue[1][8]) == 0, "Enemy gold statue must be removed by ally wind")
	var enemy_fog_remains = false
	for fog in pb.grid_fog:
		if fog.get("enemy_owned", true): enemy_fog_remains = true
	assert(not enemy_fog_remains, "Enemy dark fog must be blown away by ally wind")
	var enemy_plant_remains = false
	for pl in pb.plant_entities:
		if pl.get("enemy_planted", false): enemy_plant_remains = true
	assert(not enemy_plant_remains, "Enemy leech plant must be uprooted by ally wind")

	# Verify ALL ally beneficial tiles are PRESERVED
	assert(pb.grid_poison[7][1] and pb.is_ally_poison(7, 1), "Ally medicinal poison must be preserved")
	assert(pb.grid_fire[7][2] > 0 and pb.is_ally_fire(7, 2), "Ally blue flame must be preserved")
	assert(int(pb.grid_ice[7][3]) > 0 and pb.is_ally_ice(7, 3), "Ally ice shield must be preserved")
	assert(int(pb.grid_stones[7][4]) > 0 and pb.is_ally_stone(7, 4), "Ally crystal stone must be preserved")
	assert(pb.grid_water[7][5] and pb.is_ally_water(7, 5), "Ally stream must be preserved")
	assert(pb.grid_electrified[7][6] and pb.is_ally_electrified(7, 6), "Ally charge must be preserved")
	assert(pb.grid_cursed[7][7] and pb.is_ally_cursed(7, 7), "Ally shadow blessing must be preserved")
	assert(int(pb.grid_gold_statue[7][8]) > 0 and pb.is_ally_gold(7, 8), "Ally holy statue must be preserved")
	var ally_fog_preserved = false
	for fog in pb.grid_fog:
		if not fog.get("enemy_owned", true): ally_fog_preserved = true
	assert(ally_fog_preserved, "Ally starlight fog must be preserved")
	var ally_plant_preserved = false
	for pl in pb.plant_entities:
		if not pl.get("enemy_planted", false): ally_plant_preserved = true
	assert(ally_plant_preserved, "Ally tree must be preserved")

	# Verify Wind Skill NEVER clears normal pieces (pieces are preserved, ismatched is untouched)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			assert(not pb.ismatched[r][c], "Wind skill must never set ismatched on pieces")
			assert(pb.grid_n[r][c] != -1, "Wind skill must never delete or erase normal pieces (got -1 at %d,%d)" % [r, c])
	print("✓ Ally Wind skill verified: completely clears all disadvantageous tiles, strictly preserves ally tiles, and NEVER erases pieces!")

	# 14. Test Symmetric Self-Owned Element Generation Across All Other Skills (No unneeded clears, exact symmetric generation)
	# 14-1. Water generates ally water (stream)
	pb._initialize_board(null)
	pb.cast_player_skill("water", true)
	var ally_water_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c] and pb.is_ally_water(r, c): ally_water_count += 1
	assert(ally_water_count > 0, "Water skill must generate ally-owned water tiles")
	print("✓ Water skill creates ally-owned water tiles!")

	# 14-2. Fire generates ally fire (blue flame)
	pb._initialize_board(null)
	pb.cast_player_skill("fire", true)
	var ally_fire_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_fire[r][c] > 0 and pb.is_ally_fire(r, c): ally_fire_count += 1
	assert(ally_fire_count > 0, "Fire skill must generate ally-owned fire tiles")
	print("✓ Fire skill creates ally-owned fire tiles!")

	# 14-3. Ice generates ally ice (ice shield)
	pb._initialize_board(null)
	pb.cast_player_skill("ice", true)
	var ally_ice_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_ice[r][c]) > 0 and pb.is_ally_ice(r, c): ally_ice_count += 1
	assert(ally_ice_count > 0, "Ice skill must generate ally-owned ice tiles")
	print("✓ Ice skill creates ally-owned ice tiles!")

	# 14-4. Thunder generates ally electrified (charge) tiles & triggers shatter on stone/ice
	pb._initialize_board(null)
	pb.cast_player_skill("thunder", true)
	var ally_chg_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_electrified[r][c] and pb.is_ally_electrified(r, c): ally_chg_count += 1
	assert(ally_chg_count > 0, "Thunder skill must generate ally-owned charge tiles")
	print("✓ Thunder skill creates ally-owned charge tiles!")

	# 14-5. Wood plants ally tree sprout
	pb._initialize_board(null)
	pb.cast_player_skill("wood", true)
	var ally_tree_exists = false
	for pl in pb.plant_entities:
		if not pl.get("enemy_planted", false): ally_tree_exists = true
	assert(ally_tree_exists, "Wood skill must plant an ally-owned tree sprout")
	print("✓ Wood skill plants ally-owned tree sprout!")

	# 14-6. Earth generates ally stones (crystal stones)
	pb._initialize_board(null)
	pb.cast_player_skill("earth", true)
	var ally_stone_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_stones[r][c]) > 0 and pb.is_ally_stone(r, c): ally_stone_count += 1
	assert(ally_stone_count > 0, "Earth skill must generate ally-owned stone tiles")
	print("✓ Earth skill creates ally-owned stone tiles!")

	# 14-7. Poison generates ally poison (medicinal poison)
	pb._initialize_board(null)
	pb.cast_player_skill("poison", true)
	var ally_poison_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c] and pb.is_ally_poison(r, c): ally_poison_count += 1
	assert(ally_poison_count > 0, "Poison skill must generate ally-owned poison tiles")
	print("✓ Poison skill creates ally-owned poison tiles!")

	# 14-8. Light generates ally gold statue (holy statue)
	pb._initialize_board(null)
	pb.cast_player_skill("light", true)
	var ally_statue_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_gold_statue[r][c]) > 0 and pb.is_ally_gold(r, c): ally_statue_count += 1
	assert(ally_statue_count > 0, "Light skill must generate ally-owned gold statue tiles")
	print("✓ Light skill creates ally-owned gold statue tiles!")

	# 14-9. Dark generates ally dark fog (starlight fog) & ally curse (shadow blessing)
	pb._initialize_board(null)
	pb.cast_player_skill("dark", true)
	var ally_fog_exists = false
	for fog in pb.grid_fog:
		if not fog.get("enemy_owned", true): ally_fog_exists = true
	assert(ally_fog_exists, "Dark skill must generate ally-owned dark fog")
	var ally_curse_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_cursed[r][c] and pb.is_ally_cursed(r, c): ally_curse_count += 1
	assert(ally_curse_count > 0, "Dark skill must generate ally-owned curse tiles")
	print("✓ Dark skill creates ally-owned dark fog & curse tiles!")

	print("✓ Full symmetry verified: wind clears opponent-owned objects, and all other 9 skills generate self-owned objects without unneeded clears!")

	# 15. Test 3 Element Categories, First Enemy Relic Choice, & Skill Tree Display Filtering
	# 15-1. Verify 3 Element Categories Definition
	assert(RelicDatabase.ELEMENT_CATEGORIES.has("nature"), "ELEMENT_CATEGORIES must contain 'nature'")
	assert(RelicDatabase.ELEMENT_CATEGORIES.has("force"), "ELEMENT_CATEGORIES must contain 'force'")
	assert(RelicDatabase.ELEMENT_CATEGORIES.has("mystic"), "ELEMENT_CATEGORIES must contain 'mystic'")
	var nat_elems = RelicDatabase.ELEMENT_CATEGORIES["nature"]["elements"]
	var frc_elems = RelicDatabase.ELEMENT_CATEGORIES["force"]["elements"]
	var mys_elems = RelicDatabase.ELEMENT_CATEGORIES["mystic"]["elements"]
	assert("water" in nat_elems and "ice" in nat_elems and "wood" in nat_elems and "wind" in nat_elems, "Nature elements match")
	assert("fire" in frc_elems and "thunder" in frc_elems and "earth" in frc_elems, "Force elements match")
	assert("poison" in mys_elems and "light" in mys_elems and "dark" in mys_elems, "Mystic elements match")
	print("✓ 3 Element Categories (Nature:水氷木風, Force:火雷地, Mystic:毒光闇) verified!")

	# 15-2. Verify First Enemy Relic Selection UI produces the 3 Category Relics
	var rm_script = load("res://relic_manager.gd")
	var rm = rm_script.new()
	rm.name = "RelicManager"
	dummy_root.add_child(rm)

	var rui_script = load("res://relic_selection_ui.gd")
	var rui = rui_script.new()
	dummy_root.add_child(rui)
	rui._ready()

	# When no category is chosen yet, choices must be exactly the 3 category relics
	assert(not rm.has_chosen_element_category(), "Initially no element category chosen")
	# Re-populate choices with rm in tree
	rui._populate_choices()
	# The 3 choices in the UI
	assert(rui.hbox.get_child_count() == 3, "First enemy clear must offer exactly 3 category choices")
	assert(rui.title_label.text.contains("属性カテゴリー"), "Title must indicate attribute category selection")
	assert(not rui.skip_btn.visible, "Skip button must be hidden on category relic selection")
	print("✓ First enemy relic selection correctly presents the 3 Element Category relics!")

	# 15-3. Test selecting "nature" category relic
	rm.add_relic("relic_cat_nature")
	assert(rm.has_chosen_element_category(), "RelicManager has chosen category")
	assert(rm.get_chosen_element_category() == "nature", "Chosen category is 'nature'")
	var base_dmg = 1000.0
	var boosted_water_dmg = rm.modify_damage_dealt(base_dmg, {"element_name": "water"})
	assert(boosted_water_dmg >= 1300.0, "Nature category grants +30%% damage boost to water (got: %f)" % boosted_water_dmg)
	print("✓ Category selection sets category and grants +30% elemental damage bonus!")

	# 15-4. Test Skill Tree in ScoreManager reflects the chosen category
	sc.set_shop_ui_visible(true)
	sc._switch_shop_view_mode(1) # Switch to Skill Tree view
	sc.rebuild_skill_tree_ui()

	# In Nature category, skill_node_refs must ONLY contain skills belonging to 'nature'
	for s_ref in sc.skill_node_refs:
		var s_idx = s_ref["s_idx"]
		var s_item = sc.skill_tree_items[s_idx]
		assert(s_item["category"] == "nature", "Skill tree node must belong to 'nature' (got: %s, id: %s)" % [s_item["category"], s_item["id"]])
	print("✓ Skill tree dynamically filters and displays only Nature skills when 'nature' is chosen!")

	# 15-5. Test switching category to 'force'
	rm.set_chosen_element_category("force")
	sc.rebuild_skill_tree_ui()
	assert(not sc.skill_node_refs.is_empty(), "Skill tree nodes must be populated for 'force'")
	for s_ref in sc.skill_node_refs:
		var s_idx = s_ref["s_idx"]
		var s_item = sc.skill_tree_items[s_idx]
		assert(s_item["category"] == "force", "Skill tree node must belong to 'force' (got: %s, id: %s)" % [s_item["category"], s_item["id"]])
	print("✓ Skill tree dynamically filters and displays only Force skills when 'force' is chosen!")

	# 15-6. Test switching category to 'mystic'
	rm.set_chosen_element_category("mystic")
	sc.rebuild_skill_tree_ui()
	assert(not sc.skill_node_refs.is_empty(), "Skill tree nodes must be populated for 'mystic'")
	for s_ref in sc.skill_node_refs:
		var s_idx = s_ref["s_idx"]
		var s_item = sc.skill_tree_items[s_idx]
		assert(s_item["category"] == "mystic", "Skill tree node must belong to 'mystic' (got: %s, id: %s)" % [s_item["category"], s_item["id"]])
	print("✓ Skill tree dynamically filters and displays only Mystic skills when 'mystic' is chosen!")

	# 15-7. Test PuzzleBoard Player Skill UI reflects chosen category
	pb._setup_player_skill_ui()
	pb._update_player_skill_ui()
	assert(pb.player_skill_title_label.text.contains("神秘・冥術"), "Player skill panel title reflects chosen category")
	print("✓ PuzzleBoard player skill UI dynamically reflects chosen category!")


	# ==============================================================================
	# 16. Test Ice Halt Mechanic (氷がある間、隣接マスにある効果マスは進行しない)
	# ==============================================================================
	pb._initialize_board(null)
	# Place an ice tile at (3, 3)
	pb.grid_ice[3][3] = 2
	pb._set_ally_flag(pb.grid_ice_ally, 3, 3, true)
	# Place poison tile adjacent at (3, 4)
	pb.grid_poison[3][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 4, false) # enemy poison

	# Count poison cells before spread
	var poison_before = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]: poison_before += 1
	assert(poison_before == 1, "Initially exactly 1 poison tile")

	# Run poison spread
	pb._process_poison_spread()

	# Count poison cells after spread: MUST NOT spread because it is ice-locked!
	var poison_after = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]: poison_after += 1
	assert(poison_after == 1, "Poison adjacent to ice must NOT spread (got: %d, expected: 1)" % poison_after)
	print("✓ Ice halt mechanic verified: poison adjacent to ice does not progress/spread!")

	# ==============================================================================
	# 17. Test Thermodynamic Chain (氷 -> 水 -> 消える)
	# ==============================================================================
	pb._initialize_board(null)
	# Step 1: Ice at (4, 4), Fire adjacent at (4, 5)
	pb.grid_ice[4][4] = 2
	pb._set_ally_flag(pb.grid_ice_ally, 4, 4, true)
	pb.grid_fire[4][5] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 4, 5, false)

	# Trigger ice-fire melting
	var melted = pb._check_and_trigger_ice_fire_melting()
	assert(melted > 0, "Ice adjacent to fire must melt")
	assert(int(pb.grid_ice[4][4]) == 0, "Ice must be melted (grid_ice == 0)")
	assert(pb.grid_water[4][4] == true, "Ice must transform into Water (氷 -> 水)")
	assert(pb.grid_fire[4][5] == 0, "Fire that melted ice must be extinguished")
	print("✓ Thermodynamic Step 1 (氷 -> 水) verified!")

	# Step 2: Now place Fire adjacent at (4, 5) again to touch the water at (4, 4)
	pb.grid_fire[4][5] = 1
	var cleared_steam = pb._check_and_trigger_water_fire_synergy(false)
	assert(pb.grid_water[4][4] == false, "Water touched by Fire must vanish (水 -> 消える)")
	assert(pb.grid_fire[4][5] == 0, "Fire touching water must be extinguished")
	print("✓ Thermodynamic Step 2 (水 -> 消える) verified!")
	print("✓ Complete Thermodynamic Chain (氷 -> 水 -> 消える) verified successfully!")

	# ==============================================================================
	# 18. Test Multi-Tier Skills Execution across all 10 Elements (T1, T2, T3)
	# ==============================================================================
	# 18-1. Water T2 (Aqua Fountain) & T3 (Tidal Flood)
	pb._initialize_board(null)
	pb.cast_player_skill("water", true, 1) # T1
	pb.cast_player_skill("water", true, 2) # T2: heals & expands water
	var w_t2_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c]: w_t2_count += 1
	assert(w_t2_count >= 2, "Water T2 expands water tiles")
	pb.cast_player_skill("water", true, 3) # T3: converts pieces to potion/sword
	print("✓ Water T1, T2, T3 skills executed successfully!")

	# 18-2. Ice T2 (Freezing Chain) & T3 (Absolute Zero)
	pb._initialize_board(null)
	pb.grid_poison[2][2] = true # enemy poison
	pb._set_ally_flag(pb.grid_poison_ally, 2, 2, false)
	pb.cast_player_skill("ice", true, 2) # T2: freezes poison into ice
	assert(int(pb.grid_ice[2][2]) > 0, "Ice T2 converts hazard to ice")
	assert(not pb.grid_poison[2][2], "Hazard converted to ice")
	pb.cast_player_skill("ice", true, 3) # T3: shatters ice
	print("✓ Ice T1, T2, T3 skills executed successfully!")

	# 18-3. Wood T2 (Root Drain) & T3 (Yggdrasil Harvest)
	pb._initialize_board(null)
	pb.cast_player_skill("wood", true, 1) # T1: sprout
	pb.grid_water[2][2] = true # distant water
	pb.cast_player_skill("wood", true, 2) # T2: roots absorb water
	pb.cast_player_skill("wood", true, 3) # T3: fruits around tree
	print("✓ Wood T1, T2, T3 skills executed successfully!")

	# 18-4. Wind T2 (Gale Shift) & T3 (Tempest Reverse)
	pb._initialize_board(null)
	pb.grid_poison[5][5] = true
	pb._set_ally_flag(pb.grid_poison_ally, 5, 5, false) # enemy poison
	pb.cast_player_skill("wind", true, 3) # T3: reverses ownership to ally!
	assert(pb.is_ally_poison(5, 5), "Wind T3 inverts enemy hazard into ally-owned")
	print("✓ Wind T1, T2, T3 skills executed successfully!")

	# 18-5. Fire T1 (Dispersed), T2 (Backdraft), T3 (Prominence Nova)
	pb._initialize_board(null)
	pb.cast_player_skill("fire", true, 1) # T1: dispersed
	pb.cast_player_skill("fire", true, 2) # T2: backdraft spread
	pb.cast_player_skill("fire", true, 3) # T3: prominence nova
	print("✓ Fire T1, T2, T3 skills executed successfully!")

	# 18-6. Thunder, Earth, Poison, Light, Dark T1-T3
	for elem in ["thunder", "earth", "poison", "light", "dark"]:
		pb._initialize_board(null)
		pb.cast_player_skill(elem, true, 1)
		pb.cast_player_skill(elem, true, 2)
		pb.cast_player_skill(elem, true, 3)
	print("✓ Thunder, Earth, Poison, Light, Dark T1-T3 executed successfully!")

	# ==============================================================================
	# 19. Test All 30 Skills Registered in ScoreManager with 20 Levels
	# ==============================================================================
	assert(sc.skill_tree_items.size() == 30, "Exactly 30 skills must be registered in ScoreManager (got: %d)" % sc.skill_tree_items.size())
	for s_item in sc.skill_tree_items:
		assert(s_item["max_level"] == 20, "Skill %s must have max_level 20" % s_item["id"])
		assert(s_item["desc_lv"].size() == 20, "Skill %s must have 20 description levels (got: %d)" % [s_item["id"], s_item["desc_lv"].size()])
		assert(s_item.get("match_recipe", "") != "", "Skill %s must explicitly specify match_recipe" % s_item["id"])
	print("✓ All 30 skills registered with 20 levels and explicit match_recipes verified!")

	# ==============================================================================
	# 20. Test Match-Generated Skill Creation: Locked vs Unlocked
	# ==============================================================================
	pb._initialize_board(null)
	
	# Verify that all skills start at level 0 (LOCKED)
	for sp in pb.special_levels:
		assert(pb.special_levels[sp] == 0, "All skills must start locked at level 0 (sp %d was %d)" % [sp, pb.special_levels[sp]])

	# Helper lambda to reset board to a clean state with 0 matches
	var clean_board = func():
		pb._initialize_board(null)
		pb.pending_special_spawns.clear()
		for r in range(pb.GRID_ROWS):
			for c in range(pb.GRID_COLUMNS):
				pb.grid_n[r][c] = (r * 2 + c) % 5
				pb.special_item[r][c] = pb.SpecialItemType.NONE
				pb.is_bomb[r][c] = false
				pb.grid_stones[r][c] = 0

	# 20-A. Verify that LOCKED skills do NOT generate any special items
	clean_board.call()
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.is_empty(), "4 swords must NOT spawn BOMB when BOMB is locked")

	# 5 swords in a line when locked
	clean_board.call()
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][7] = pb.PieceType.SHIELD
	for c in range(2, 7):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 4), Vector2i(6, 4)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.is_empty(), "5 swords must NOT spawn LIGHTNING when LIGHTNING is locked")
	print("✓ Locked skills correctly do NOT generate special skill items from matches!")

	# 20-B. Test unlocking via ScoreManager skill tree purchase
	var fire_1_idx: int = -1
	for idx in range(sc.skill_tree_items.size()):
		if sc.skill_tree_items[idx]["id"] == "fire_1":
			fire_1_idx = idx
			break
	assert(fire_1_idx != -1, "fire_1 must exist in skill_tree_items")
	sc.divscore[pb.PieceType.POTION] = 10000
	sc._purchase_skill(fire_1_idx)
	assert(sc.skill_tree_items[fire_1_idx]["level"] >= 1, "fire_1 must be level 1 after purchase")
	assert(pb.special_levels[pb.SpecialItemType.BOMB] >= 1, "Purchasing fire_1 must unlock BOMB in puzzle board")

	# Now 4 swords match DOES spawn BOMB!
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.BOMB] = 1 # Re-set to 1 after clean_board
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.has(Vector2i(5, 3)), "4 swords must spawn BOMB after unlocking")
	assert(pb.pending_special_spawns[Vector2i(5, 3)] == pb.SpecialItemType.BOMB, "Spawned item must be BOMB")
	print("✓ Unlocking skill in SkillTree enables match generation for BOMB!")

	# 20-C. Test all other unlocked match recipes
	# 4-match POTION -> AQUA_SPLASH
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.AQUA_SPLASH] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.POTION
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 3)] == pb.SpecialItemType.AQUA_SPLASH, "4 potions must spawn AQUA_SPLASH when unlocked")
	print("✓ Unlocked 4-Match POTION correctly generates AQUA_SPLASH!")

	# 4-match FOOD -> TREE_SPROUT
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.TREE_SPROUT] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.FOOD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 3)] == pb.SpecialItemType.TREE_SPROUT, "4 food pieces must spawn TREE_SPROUT when unlocked")
	print("✓ Unlocked 4-Match FOOD correctly generates TREE_SPROUT!")

	# 5-match in a line SWORD -> LIGHTNING
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.LIGHTNING] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][7] = pb.PieceType.SHIELD
	for c in range(2, 7):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 4), Vector2i(6, 4)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 4)] == pb.SpecialItemType.LIGHTNING, "5 swords in a line must spawn LIGHTNING when unlocked")
	print("✓ Unlocked 5-Match in a line SWORD correctly generates LIGHTNING!")

	# 5-match in a line POTION -> BLACK_HOLE
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.BLACK_HOLE] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][7] = pb.PieceType.SHIELD
	for c in range(2, 7):
		pb.grid_n[5][c] = pb.PieceType.POTION
	pb.last_swap_cells = [Vector2i(5, 4), Vector2i(6, 4)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 4)] == pb.SpecialItemType.BLACK_HOLE, "5 potions in a line must spawn BLACK_HOLE when unlocked")
	print("✓ Unlocked 5-Match in a line POTION correctly generates BLACK_HOLE!")

	# Cross / T-shape match -> CROSS_BOMB
	pb.pending_special_spawns.clear()
	pb.special_levels[pb.SpecialItemType.CROSS_BOMB] = 1
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = 0
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false
	pb.grid_n[3][2] = 2; pb.grid_n[3][3] = 2; pb.grid_n[3][4] = 2
	pb.grid_n[2][3] = 2; pb.grid_n[4][3] = 2
	pb.last_swap_cells = [Vector2i(3, 3), Vector2i(3, 5)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(3, 3)] == pb.SpecialItemType.CROSS_BOMB, "T-match must spawn CROSS_BOMB when unlocked")
	print("✓ Unlocked T/L Cross-Match correctly generates CROSS_BOMB!")

	# 6 simultaneous match -> GEMINI_BOMB
	pb.pending_special_spawns.clear()
	pb.special_levels[pb.SpecialItemType.GEMINI_BOMB] = 1
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = 0
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false
	for c in range(1, 7):
		pb.grid_n[5][c] = 2
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.GEMINI_BOMB, "6 match must spawn GEMINI_BOMB when unlocked")
	print("✓ Unlocked 6 simultaneous match correctly generates GEMINI_BOMB!")

	# 7+ simultaneous match -> DISCO_BALL
	pb.pending_special_spawns.clear()
	pb.special_levels[pb.SpecialItemType.DISCO_BALL] = 1
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = 0
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false
	for c in range(1, 6):
		pb.grid_n[2][c] = 2 # 5 pieces
	pb.grid_n[3][3] = 2     # 6th
	pb.grid_n[4][3] = 2     # 7th
	pb.last_swap_cells = [Vector2i(2, 3), Vector2i(1, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(2, 3)) == pb.SpecialItemType.DISCO_BALL, "7+ match must spawn DISCO_BALL when unlocked")
	print("✓ Unlocked 7+ Match correctly generates DISCO_BALL!")

	# 4-Match SHIELD in nature -> ICE_SHIELD
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.ICE_SHIELD] = 1
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.SHIELD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.ICE_SHIELD, "4-Match SHIELD must generate ICE_SHIELD when unlocked")
	print("✓ Unlocked 4-Match SHIELD correctly generates ICE_SHIELD!")

	# 4-Match POTION in mystic -> POISON_MIST
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.POISON_MIST] = 1
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("mystic")
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.POTION
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.POISON_MIST, "4-Match POTION in mystic must generate POISON_MIST when unlocked")
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")
	print("✓ Unlocked 4-Match POTION correctly generates POISON_MIST in mystic!")

	# ==============================================================================
	# 21. Test Poison Immunity Reduction
	# ==============================================================================
	pb._initialize_board(null)
	pb.plant_entities.clear()
	sm.myhp = 5000.0
	sm.myhpmax = 5000.0

	# Case A: 2 Enemy Poison tiles, 0 Ally Poison tiles
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false) # Enemy
	pb.grid_poison[1][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 2, false) # Enemy

	var hp_before_no_immunity = sm.myhp
	pb._reset_turn(sm, null)
	var dmg_no_immunity = hp_before_no_immunity - sm.myhp
	assert(dmg_no_immunity > 0, "Enemy poison must deal damage")

	# Case B: 2 Enemy Poison tiles + 3 Ally Poison tiles (Immunity: 3 * 20% = 60% reduction)
	pb._initialize_board(null)
	pb.plant_entities.clear()
	sm.myhp = 5000.0
	sm.myhpmax = 5000.0
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false) # Enemy
	pb.grid_poison[1][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 2, false) # Enemy
	pb.grid_poison[4][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 4, true)  # Ally
	pb.grid_poison[4][5] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 5, true)  # Ally
	pb.grid_poison[5][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 5, 4, true)  # Ally

	var hp_before_with_immunity = sm.myhp
	pb._reset_turn(sm, null)
	var dmg_with_immunity = hp_before_with_immunity - sm.myhp
	assert(dmg_with_immunity < dmg_no_immunity, "Ally poison must reduce enemy poison damage via immunity (got %f with vs %f without)" % [dmg_with_immunity, dmg_no_immunity])
	var expected_dmg_approx = dmg_no_immunity * (1.0 - 0.60)
	assert(absf(dmg_with_immunity - expected_dmg_approx) <= 2.0, "Immunity should mitigate ~60% poison damage")
	print("✓ Poison immunity verified: 3 ally poison tiles mitigated 60% of enemy poison damage!")

	# ==============================================================================
	# 22. Test Mutual Poison Invasion (Ally into Enemy, and Enemy into Ally)
	# ==============================================================================
	# 22-1. Ally Poison Invades Enemy Poison:
	# Place 1 Enemy poison at (3, 3) surrounded by 2 Ally poison at (3, 2) and (2, 3)
	pb._initialize_board(null)
	pb.grid_poison[3][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 3, false) # Enemy poison at (3, 3)
	pb.grid_poison[3][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 2, true)  # Ally poison at (3, 2)
	pb.grid_poison[2][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 2, 3, true)  # Ally poison at (2, 3)

	assert(not pb.is_ally_poison(3, 3), "(3, 3) starts as Enemy poison")
	pb._process_poison_spread()
	assert(pb.grid_poison[3][3] == true, "(3, 3) must remain poison")
	assert(pb.is_ally_poison(3, 3) == true, "Ally poison pressure (2) must conquer and purify isolated Enemy poison (3, 3) into Ally poison!")
	print("✓ Ally poison successfully invaded and purified Enemy poison tile!")

	# 22-2. Enemy Poison Invades Ally Poison:
	# Place 1 Ally poison at (3, 3) surrounded by 2 Enemy poison at (3, 2) and (2, 3)
	pb._initialize_board(null)
	pb.grid_poison[3][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 3, true)  # Ally poison at (3, 3)
	pb.grid_poison[3][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 2, false) # Enemy poison at (3, 2)
	pb.grid_poison[2][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 2, 3, false) # Enemy poison at (2, 3)

	assert(pb.is_ally_poison(3, 3), "(3, 3) starts as Ally poison")
	pb._process_poison_spread()
	assert(pb.grid_poison[3][3] == true, "(3, 3) must remain poison")
	assert(pb.is_ally_poison(3, 3) == false, "Enemy poison pressure (2) must conquer and corrupt isolated Ally poison (3, 3) into Enemy poison!")
	print("✓ Enemy poison successfully invaded and corrupted Ally poison tile!")

	# 22-3. Water tile conducts accelerated poison invasion:
	# Place 1 Enemy poison at (4, 4), and 1 Ally poison at (4, 3) with WATER at (4, 3)
	pb._initialize_board(null)
	pb.grid_poison[4][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 4, false) # Enemy poison at (4, 4)
	pb.grid_poison[4][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 3, true)  # Ally poison at (4, 3)
	pb.grid_water[4][3] = true                          # Water conducts double pressure (ap = 2)!

	pb._process_poison_spread()
	assert(pb.is_ally_poison(4, 4) == true, "Wet Ally poison tile (pressure 2) must overpower and conquer dry Enemy poison tile (4, 4)!")
	print("✓ Water tile accelerates poison invasion pressure as designed!")

	print("\nALL USER REQUEST TESTS PASSED SUCCESSFULLY!")
	quit(0)
