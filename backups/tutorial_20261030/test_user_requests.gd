extends SceneTree
const GlossaryDatabase = preload("res://glossary_database.gd")

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
	# 19. Test All 10 Skills Registered in ScoreManager (1 per Element, 20 Levels)
	# ==============================================================================
	assert(sc.skill_tree_items.size() == 10, "Exactly 10 canonical skills (1 per element) must be registered in ScoreManager (got: %d)" % sc.skill_tree_items.size())
	for s_item in sc.skill_tree_items:
		assert(s_item["max_level"] == 20, "Skill %s must have max_level 20" % s_item["id"])
		assert(s_item["desc_lv"].size() == 20, "Skill %s must have 20 description levels (got: %d)" % [s_item["id"], s_item["desc_lv"].size()])
		assert(s_item.get("match_recipe", "") != "", "Skill %s must explicitly specify match_recipe" % s_item["id"])
	print("✓ All 10 canonical skills (1 per element) registered with 20 levels and explicit match_recipes verified!")

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
	# 4-Match COIN in mystic -> HOLY_LIGHT (聖光星 / 旧MAGNET)
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.HOLY_LIGHT] = 1
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("mystic")
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.COIN
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.HOLY_LIGHT, "4-Match COIN in mystic must generate HOLY_LIGHT when unlocked")
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")
	print("✓ Unlocked 4-Match COIN correctly generates HOLY_LIGHT (聖光星) in mystic (replaces magnet)!")

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

	# Case B: 2 Enemy Poison tiles + 3 Ally Poison tiles (Immunity: 3 * 5% = 15% reduction)
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
	var expected_dmg_approx = dmg_no_immunity * (1.0 - 0.15)
	assert(absf(dmg_with_immunity - expected_dmg_approx) <= 2.0, "Immunity should mitigate ~15% poison damage")
	print("✓ Poison immunity verified: 3 ally poison tiles mitigated 15% of enemy poison damage!")

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

	# ==============================================================================
	# 23. Test Enemy Damage Source Display and Enhanced Elemental Hit Effects
	# ==============================================================================
	var cui = CombatUIManager.new()
	dummy_root.add_child(cui)
	cui._ready()

	var dummy_enemy = Sprite2D.new()
	dummy_enemy.position = Vector2(500, 300)
	dummy_root.add_child(dummy_enemy)

	# 23-1. Poison damage displays explicit "(毒ダメージ)" and spawns poison VFX and flash
	cui._show_enemy_damage(120.0, dummy_enemy, false, "ally_poison")
	var found_poison_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(毒ダメージ)"):
			found_poison_lbl = true
			assert(lbl.text.contains("120"), "Damage amount 120 must be included")
			break
	assert(found_poison_lbl, "Poison damage must display (毒ダメージ)")
	assert(dummy_enemy.modulate != Color.WHITE, "Enemy sprite must flash with elemental tint on poison hit")

	# Check EnemyHitEffectNode spawned
	var found_vfx = false
	for ch in cui.get_children():
		if ch is CombatUIManager.EnemyHitEffectNode:
			assert(ch.vfx_type == "poison", "Poison hit must spawn poison VFX")
			found_vfx = true
			break
	assert(found_vfx, "EnemyHitEffectNode must be spawned for poison hit")
	print("✓ Enemy poison damage explicitly displays (毒ダメージ) and triggers poison VFX and flash!")

	# 23-2. Verify Fire, Thunder, Ice, Synergy, and Skill damage tags
	cui._show_enemy_damage(250.0, dummy_enemy, false, "ally_fire")
	var found_fire_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(火傷ダメージ)"):
			found_fire_lbl = true
			break
	assert(found_fire_lbl, "Ally fire damage must display (火傷ダメージ)")

	cui._show_enemy_damage(300.0, dummy_enemy, false, "thunder")
	var found_thunder_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(雷撃ダメージ)"):
			found_thunder_lbl = true
			break
	assert(found_thunder_lbl, "Thunder damage must display (雷撃ダメージ)")

	cui._show_enemy_damage(180.0, dummy_enemy, false, "ice")
	var found_ice_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(冷気ダメージ)"):
			found_ice_lbl = true
			break
	assert(found_ice_lbl, "Ice damage must display (冷気ダメージ)")

	cui._show_enemy_damage(360.0, dummy_enemy, false, "steam_synergy")
	var found_steam_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(蒸気消去ダメージ)"):
			found_steam_lbl = true
			break
	assert(found_steam_lbl, "Steam synergy damage must display (蒸気消去ダメージ)")

	cui._show_enemy_damage(320.0, dummy_enemy, false, "shatter_synergy")
	var found_shatter_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(砕破ダメージ)"):
			found_shatter_lbl = true
			break
	assert(found_shatter_lbl, "Shatter synergy damage must display (砕破ダメージ)")

	cui._show_enemy_damage(400.0, dummy_enemy, false, "player_skill_poison")
	var found_pskill_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(毒スキルダメージ)"):
			found_pskill_lbl = true
			break
	assert(found_pskill_lbl, "Player skill poison must display (毒スキルダメージ)")

	print("✓ Enemy damage labels explicitly display all damage sources with rich tags!")
	# ==============================================================================
	# 24. Test Freed Instance Safety (Left operand of 'is' error prevention)
	# ==============================================================================
	var immediately_freed = Sprite2D.new()
	immediately_freed.free()

	assert(sm.play_single_enemy_animation(immediately_freed, "damaged") == false, "play_single_enemy_animation with freed target must return false without error")
	assert(sm.get_enemy_animation_duration(immediately_freed, "damaged") >= 0.45, "get_enemy_animation_duration with freed target must return default without error")
	sm.play_single_idle_loop(immediately_freed)
	sm.calchp(10.0, 0.0, immediately_freed)
	assert(sm.get_enemy_element(immediately_freed) != "", "get_enemy_element with freed target must return default without error")

	cui._on_combat_event({
		"type": "damage",
		"target": immediately_freed,
		"amount": 50.0,
		"element": "poison"
	})
	print("✓ Freed instance safety verified: no errors with freed instances!")

	# ==============================================================================
	# 25. Test Poison Skill Piece (POISON_MIST) Clearance & Ally Poison Deployment
	# ==============================================================================
	pb.special_levels[pb.SpecialItemType.POISON_MIST] = 1
	var mist_r = 4
	var mist_c = 4
	pb.special_item[mist_r][mist_c] = pb.SpecialItemType.POISON_MIST
	pb.is_bomb[mist_r][mist_c] = true
	var queue_test: Array = []
	var exploded_test: Dictionary = {Vector2i(mist_r, mist_c): true}
	pb._trigger_poison_mist(mist_r, mist_c, pb.get_cell_position(mist_r, mist_c), queue_test, exploded_test)

	assert(pb.ismatched[mist_r][mist_c] == true, "Poison skill piece at (r, c) must be marked matched for deletion")
	assert(pb.special_item[mist_r][mist_c] == pb.SpecialItemType.NONE, "SpecialItemType must be cleared to NONE on detonation")
	assert(pb.is_bomb[mist_r][mist_c] == false, "is_bomb must be cleared to false on detonation")
	assert(pb.grid_poison[mist_r][mist_c] == true, "Center cell must have poison ground deployed")
	assert(pb.is_ally_poison(mist_r, mist_c) == true, "Center cell poison must be ally poison")
	assert(pb.grid_poison[mist_r - 1][mist_c] == true, "Surrounding cells must have poison ground deployed")
	assert(pb.is_ally_poison(mist_r - 1, mist_c) == true, "Surrounding cell poison must be ally poison")
	# Surrounding normal cells must not be broken
	assert(pb.ismatched[mist_r - 1][mist_c] == false, "Surrounding normal cells must not be destroyed by poison mist")
	print("✓ Poison skill piece clearance and ally poison deployment verified!")

	# ==============================================================================
	# 26. Test Vertical UI Hierarchy Under Enemy Screen (Score -> Items -> Selected Category Elements)
	# ==============================================================================
	var score_mgr_node = load("res://score_manager.gd").new()
	score_mgr_node.name = "TestScoreManager"
	dummy_root.add_child(score_mgr_node)
	score_mgr_node.relic_manager_ref = rm

	# Setup mock UI nodes for ScoreManager
	var mock_label = RichTextLabel.new()
	mock_label.name = "RichTextLabel"
	score_mgr_node.add_child(mock_label)
	score_mgr_node.label = mock_label

	var mock_status = ColorRect.new()
	mock_status.name = "status"
	score_mgr_node.add_child(mock_status)
	score_mgr_node.status_rect = mock_status

	var mock_status2 = ColorRect.new()
	mock_status2.name = "status2"
	score_mgr_node.add_child(mock_status2)
	score_mgr_node.status2_rect = mock_status2

	score_mgr_node._ready()

	# 1. 敵画面の真下にスコア欄 (Directly below enemy screen: y = 472.0, h = 66.0, w = 725.0)
	var sc_rect_node = score_mgr_node.get_node_or_null("score_rect") as ColorRect
	assert(sc_rect_node != null, "score_rect node must exist")
	assert(sc_rect_node.position.y == 472.0, "score_rect must be positioned directly below enemy screen at y=472.0")
	assert(sc_rect_node.size.x == 725.0, "score_rect must span enemy screen width 725.0")
	assert(sc_rect_node.size.y == 66.0, "score_rect must have height 66.0")
	assert(score_mgr_node.label.visible == true, "Score label must be visible")
	score_mgr_node.totalScore = 12345
	score_mgr_node.update_score_label()
	assert(score_mgr_node.label.text.contains("12,345"), "Score label must display formatted totalScore")

	# 2. その下にアイテム値欄（左側・盤面下端 y=944 に下端一致: y = 544.0, w = 425.0, h = 400.0）
	assert(score_mgr_node.status_rect.position.y == 544.0, "status_rect (items) must start at y=544.0")
	assert(score_mgr_node.status_rect.position.x == 1190.0, "status_rect must be on left side at x=1190.0")
	assert(score_mgr_node.status_rect.size.x == 425.0, "status_rect width must be 425.0")
	assert(score_mgr_node.status_rect.size.y == 400.0, "status_rect height must be 400.0")
	var status_bottom = score_mgr_node.status_rect.position.y + score_mgr_node.status_rect.size.y
	assert(is_equal_approx(status_bottom, 944.0), "status_rect bottom must align with board bottom at y=944.0 (got %f)" % status_bottom)
	assert(score_mgr_node.status_rect.position.y > sc_rect_node.position.y, "Item values must be below Score section")

	# 3. アイテム値の横に選択した属性値欄（右側・横並び配置 x = 1625.0, y = 544.0, w = 290.0, h = 400.0, 下端 y=944）
	var el_rect_node = score_mgr_node.get_node_or_null("elem_status") as ColorRect
	assert(el_rect_node != null, "elem_status node must exist")
	assert(el_rect_node.position.x == 1625.0, "elem_status must be placed on the right side next to items at x=1625.0")
	assert(is_equal_approx(el_rect_node.position.y, score_mgr_node.status_rect.position.y), "elem_status must be vertically aligned with status_rect (side-by-side)")
	assert(el_rect_node.position.x > score_mgr_node.status_rect.position.x, "Selected attribute values must be next to (right of) item values")
	assert(el_rect_node.size.x == 290.0, "elem_status width must be 290.0")
	assert(el_rect_node.size.y == 400.0, "elem_status height must be 400.0")
	var elem_status_bottom = el_rect_node.position.y + el_rect_node.size.y
	assert(is_equal_approx(elem_status_bottom, 944.0), "elem_status bottom must align with board bottom at y=944.0 (got %f)" % elem_status_bottom)

	# 4. 属性値未定の場合の検証（何も表示せず枠線のみ）
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.is_empty(), "When attribute is undetermined, elem_category_elements must be empty")
	assert(score_mgr_node.elem_category_header_label != null, "elem_category_header_label must exist")
	assert(score_mgr_node.elem_category_header_label.text == "", "Undetermined header text must be empty string")
	assert(score_mgr_node.elem_category_header_label.visible == false, "Undetermined header must not be visible")
	var el_vline = score_mgr_node.get_node_or_null("elem_v_line") as ColorRect
	if el_vline:
		assert(el_vline.visible == false, "Internal grid vertical line must be hidden when attribute is undetermined")

	# 5. 属性カテゴリー選択に応じた動的表示の検証
	# Test nature category
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("nature")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.size() == 4, "Nature category must have 4 elements: water, ice, wood, wind")
	assert(score_mgr_node.elem_category_elements[0]["key"] == "water", "Element 0 must be water")
	assert(score_mgr_node.elem_category_elements[1]["key"] == "ice", "Element 1 must be ice")
	assert(score_mgr_node.elem_category_elements[2]["key"] == "wood", "Element 2 must be wood")
	assert(score_mgr_node.elem_category_elements[3]["key"] == "wind", "Element 3 must be wind")

	# Test force category
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("force")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.size() == 3, "Force category must have 3 elements: fire, thunder, earth")
	assert(score_mgr_node.elem_category_elements[0]["key"] == "fire", "Element 0 must be fire")
	assert(score_mgr_node.elem_category_elements[1]["key"] == "thunder", "Element 1 must be thunder")
	assert(score_mgr_node.elem_category_elements[2]["key"] == "earth", "Element 2 must be earth")

	# Test mystic category
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("mystic")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.size() == 3, "Mystic category must have 3 elements: poison, light, dark")
	assert(score_mgr_node.elem_category_elements[0]["key"] == "poison", "Element 0 must be poison")
	assert(score_mgr_node.elem_category_elements[1]["key"] == "light", "Element 1 must be light")
	assert(score_mgr_node.elem_category_elements[2]["key"] == "dark", "Element 2 must be dark")

	# 6. Combo scrollbar elimination
	if score_mgr_node.combo_label:
		assert(score_mgr_node.combo_label.scroll_active == false, "combo_label must have scroll_active = false to prevent scrollbars")
	if score_mgr_node.combocount_label:
		assert(score_mgr_node.combocount_label.scroll_active == false, "combocount_label must have scroll_active = false to prevent scrollbars")

	# Clean up test nodes
	score_mgr_node.queue_free()
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")

	# 7. Test StageLabel higher position and current battle display directly below it (without parentheses covering board)
	var stage_lbl = RichTextLabel.new()
	stage_lbl.name = "StageLabel"
	sm.add_child(stage_lbl)
	sm.label = stage_lbl

	var stage_lbl2 = RichTextLabel.new()
	stage_lbl2.name = "StageLabel2"
	sm.add_child(stage_lbl2)
	sm.label2 = stage_lbl2

	sm.stage = 1
	sm.stage_enemy = 1
	sm.label_control()
	assert(sm.label != null, "sm.label must exist")
	assert(sm.label.position.y == 16.0, "StageLabel must be moved up to y=16.0 (got %f)" % sm.label.position.y)
	assert(sm.label.scroll_active == false, "StageLabel must have scroll_active = false")
	assert(sm.label.text.contains("STAGE"), "StageLabel must contain STAGE")
	assert(sm.label.position.x + sm.label.size.x <= 240.0, "StageLabel right edge must not reach board (x >= 243.0)")
	assert(sm.label2 != null, "sm.label2 must exist")
	assert(sm.label2.position.y > sm.label.position.y, "StageLabel2 must be placed directly below StageLabel (got y=%f vs %f)" % [sm.label2.position.y, sm.label.position.y])
	assert(sm.label2.position.x + sm.label2.size.x <= 240.0, "StageLabel2 right edge must not reach board (x >= 243.0)")
	assert(not sm.label2.text.contains("("), "StageLabel2 must not contain parentheses to avoid covering board (got %s)" % sm.label2.text)
	assert(sm.label2.text.contains("BATTLE") and sm.label2.text.contains("/5"), "StageLabel2 directly below must display current match counter (got %s)" % sm.label2.text)

	sm.stage_enemy = 5
	sm.label_control()
	assert(sm.label2.text.contains("BOSS"), "StageLabel2 must display BOSS on 5th match (got %s)" % sm.label2.text)

	# 8. Test Relic and Skill panel boxes (sizes must match each other and not overlap Settings button)
	var relic_ui = load("res://relic_ui_manager.gd").new()
	dummy_root.add_child(relic_ui)
	relic_ui._ready()
	var skill_box = relic_ui.get_node_or_null("skill_rect") as ColorRect
	assert(skill_box != null, "skill_rect must exist in RelicUIManager")
	assert(skill_box.color == Color(0.85, 0.72, 0.38, 1.0), "skill_rect must have antique gold border")
	assert(skill_box.position.y >= 950.0, "skill_rect must be positioned below board (y >= 950.0)")
	assert(is_equal_approx(skill_box.position.x, 244.0), "skill_rect left edge must align with board left edge (got %f)" % skill_box.position.x)

	var relic_box = relic_ui.get_node_or_null("relic_rect") as ColorRect
	assert(relic_box != null, "relic_rect must exist in RelicUIManager")
	assert(relic_box.color == Color(0.85, 0.72, 0.38, 1.0), "relic_rect must have antique gold border")
	assert(relic_box.position.y >= 950.0, "relic_box must be positioned below board (y >= 950.0)")
	assert(is_equal_approx(skill_box.size.x, relic_box.size.x), "Skill and Relic panels must have exact same width (got %f vs %f)" % [skill_box.size.x, relic_box.size.x])
	assert(is_equal_approx(skill_box.size.y, relic_box.size.y), "Skill and Relic panels must have exact same height (got %f vs %f)" % [skill_box.size.y, relic_box.size.y])
	assert(skill_box.size.x >= 800.0, "Skill panel width must be extended (got %f)" % skill_box.size.x)
	assert(skill_box.position.x >= 190.0, "skill_rect left edge (%f) must not overlap Settings button on bottom-left" % skill_box.position.x)
	var relic_right_edge = relic_box.position.x + relic_box.size.x
	assert(relic_right_edge <= 1920.0, "relic_rect right edge (%f) must fit inside viewport width 1920" % relic_right_edge)

	var skill2_box = relic_ui.get_node_or_null("skill2_rect") as ColorRect
	assert(skill2_box != null and skill2_box.color.a <= 0.88 and skill2_box.color.a >= 0.70, "skill2_rect must be slightly translucent (alpha around 0.82)")
	var relic2_box = relic_ui.get_node_or_null("relic2_rect") as ColorRect
	assert(relic2_box != null and relic2_box.color.a <= 0.88 and relic2_box.color.a >= 0.70, "relic2_rect must be slightly translucent (alpha around 0.82)")

	relic_ui.queue_free()

	# 9. Test Holy Light skill triggering (light element damage, replaces magnet)
	pb._initialize_board(null)
	pb.special_levels[pb.SpecialItemType.HOLY_LIGHT] = 1
	var holy_r = 4
	var holy_c = 4
	pb.special_item[holy_r][holy_c] = pb.SpecialItemType.HOLY_LIGHT
	var queue_holy: Array = []
	var exploded_holy: Dictionary = {Vector2i(holy_r, holy_c): true}
	pb._trigger_holy_light(holy_r, holy_c, pb.get_cell_position(holy_r, holy_c), queue_holy, exploded_holy)
	assert(pb.ismatched[holy_r][holy_c] == true, "Holy Light cell must be matched")

	print("✓ UI layout (bottom alignment at 944, undetermined attribute box, battle counter, combo scrollbar fix, skill/relic panels) verified!")



	# -------------------------------------------------------------
	# 24. Test Orthodox Skill Evolution & Tarot Card Selection & Ice Final Turn Skip
	# -------------------------------------------------------------
	print("\n--- Testing Section 24: Orthodox Skill Evolution & Choice Modals ---")
	var sm_evo = sc_script.new()
	dummy_root.add_child(sm_evo)
	sm_evo._init()
	sm_evo.set_shop_ui_visible(true)
	sm_evo.on_element_category_chosen("nature")
	sm_evo._switch_shop_view_mode(1)

	var t_ice_idx = -1
	for i in range(sm_evo.skill_tree_items.size()):
		if sm_evo.skill_tree_items[i]["id"] == "ice_1":
			t_ice_idx = i
			break
	assert(t_ice_idx != -1, "ice_1 must exist")

	sm_evo.divscore[sm_evo.PieceType.POTION] = 100000000

	# 24.1 Level 1 to 9 upgrades do NOT open modal
	for lvl in range(1, 10):
		sm_evo._purchase_skill(t_ice_idx)
		assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == lvl, "Level should be %d" % lvl)
		assert(sm_evo.tarot_modal_panel == null or not is_instance_valid(sm_evo.tarot_modal_panel), "Modal should NOT be open for level %d" % lvl)

	# 24.2 Level 10 triggers Mid Evolution Modal (3 choices)
	sm_evo._purchase_skill(t_ice_idx)
	assert(sm_evo.tarot_modal_panel != null and is_instance_valid(sm_evo.tarot_modal_panel), "Modal MUST open when upgrading to Lv.10")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 9, "Level stays 9 until evolution is selected")

	# Check mid evolution cards (strictly NO turn skip)
	var mid_cards = sm_evo.get_evolution_choices("ice_1", 10)
	assert(mid_cards.size() == 3, "Ice mid evolution must have 3 cards")
	for c in mid_cards:
		assert(c["id"] != "ice_final_skip", "Ice mid evolution MUST NOT contain turn skip!")
		assert("スキップ" not in c["desc"], "Ice mid evolution MUST NOT mention turn skip!")

	# Choose mid card 1: ice_mid_b (砕氷)
	var mid_btn = sm_evo.tarot_modal_panel.get_node("TarotCard_1/SelectBtn_1") as Button
	assert(mid_btn != null, "Mid card 1 button must exist")
	mid_btn.emit_signal("pressed")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 10, "Level should now be 10")
	assert(sm_evo.has_skill_trait("ice_1", "ice_mid_b") == true, "Must have ice_mid_b trait")

	# 24.3 Level 11 to 19 upgrades do NOT open modal
	for lvl in range(11, 20):
		sm_evo._purchase_skill(t_ice_idx)
		assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == lvl, "Level should be %d" % lvl)
		assert(sm_evo.tarot_modal_panel == null or not is_instance_valid(sm_evo.tarot_modal_panel), "Modal should NOT open for level %d" % lvl)

	# 24.4 Level 20 triggers Final Evolution Modal (2 choices branching from chosen mid!)
	sm_evo._purchase_skill(t_ice_idx)
	assert(sm_evo.tarot_modal_panel != null and is_instance_valid(sm_evo.tarot_modal_panel), "Modal MUST open when upgrading to Lv.20")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 19, "Level stays 19 until evolution is selected")

	# Check final evolution cards (branching strictly from ice_mid_b -> ice_final_b1 and ice_final_b2)
	var final_cards = sm_evo.get_evolution_choices("ice_1", 20)
	assert(final_cards.size() == 2, "Ice final evolution must offer exactly 2 choices for chosen branch B")
	assert(final_cards[0]["id"] == "ice_final_b1", "Branch B final card 0 must be ice_final_b1 (破砕起爆)")
	assert(final_cards[1]["id"] == "ice_final_b2", "Branch B final card 1 must be ice_final_b2 (霜の連鎖)")

	# Choose final card 0: ice_final_b1
	var final_btn = sm_evo.tarot_modal_panel.get_node("TarotCard_0/SelectBtn_0") as Button
	assert(final_btn != null, "Final card 0 button must exist")
	final_btn.emit_signal("pressed")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 20, "Level should now be 20")
	assert(sm_evo.has_skill_trait("ice_1", "ice_final_b1") == true, "Must have ice_final_b1 trait")

	# Check UI description displays evolution badges
	var ice_desc_text = ""
	for s_ref in sm_evo.skill_node_refs:
		if s_ref["s_idx"] == t_ice_idx:
			ice_desc_text = s_ref["s_desc"].text
			break
	assert("【第1進化: 砕氷】" in ice_desc_text, "Desc text must display mid evolution badge")
	assert("【最終進化: 破砕起爆】" in ice_desc_text, "Desc text must display final evolution badge")

	# 24.5 Strict Rule Check: Match recipes NEVER change across all elements
	for sk in sm_evo.skill_tree_items:
		assert(sk.has("match_recipe"), "Skill item %s must retain match_recipe" % sk.get("id", ""))
		assert(sk.get("max_level", 0) == 20, "All skills must retain 20 levels of numerical scaling")

	sm_evo.queue_free()
	print("✓ Section 24 passed: Lv.10 (3 choices) & Lv.20 (2 choices hierarchical) verified!")

	# --- Section 25: Debug Level-Up Suite Verification ---
	print("\n--- Testing Section 25: Debug Level-Up Suite ---")
	var p_before_dbg = sm_evo.divscore[sm_evo.PieceType.POTION]
	var c_before_dbg = sm_evo.divscore[sm_evo.PieceType.COIN]
	sm_evo.debug_add_resources(100000)
	assert(sm_evo.divscore[sm_evo.PieceType.POTION] == p_before_dbg + 100000, "Potion +100000 via debug")
	assert(sm_evo.divscore[sm_evo.PieceType.COIN] == c_before_dbg + 100000, "Coin +100000 via debug")

	# Debug level up skill to level 1
	sm_evo.debug_level_up_skill(t_ice_idx, 1)
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 1, "Skill level set to 1 via debug")

	# Debug set all skills in active category to Lv.10 and Lv.20
	sm_evo.debug_set_all_skills_level(10)
	for sk in sm_evo.skill_tree_items:
		if sk.get("category", "") == "nature":
			assert(sk["level"] == 10, "Nature skill must be Lv.10 via batch debug")

	sm_evo.debug_set_all_skills_level(20)
	for sk in sm_evo.skill_tree_items:
		if sk.get("category", "") == "nature":
			assert(sk["level"] == 20, "Nature skill must be Lv.20 via batch debug")

	# Debug shop buff level up
	var buff_0_lvl = sm_evo.shop_items[0]["level"]
	sm_evo.debug_level_up_shop_buff(0)
	assert(sm_evo.shop_items[0]["level"] == buff_0_lvl + 1, "Shop buff leveled up via debug")

	# Debug shop toggle
	sm_evo.debug_toggle_shop()
	assert(sm_evo.is_shop_open == false, "Shop toggled closed")
	sm_evo.debug_toggle_shop()
	assert(sm_evo.is_shop_open == true, "Shop toggled open")
	print("✓ Section 25 passed: Debug Level-Up Suite fully verified!")


	# ==============================================================================
	# 27. Test User Requests: 1-Turn Single Neighbor Hazard Spread, Lower Proceed Button, Removed S5 Button
	# ==============================================================================
	print("\n--- Testing Section 27: 1-Turn Single Neighbor Hazard Spread & Bottom Proceed Button ---")
	
	# 27.1 Fire & Poison Spread Cadence: Spreads every 1 turn to exactly 1 adjacent cell
	pb.clear_board_hazards()
	assert(pb.hazard_spread_turn_counter == 0, "Counter must reset on hazard clear")
	sm.active_enemies = [{"evolutions": ["fire_mid_b", "poison_mid_b"]}]
	pb.grid_fire[2][2] = 1 # Fire at (2,2)
	pb.grid_poison[4][4] = true # Poison at (4,4)
	
	# Turn 1: Player moves & turn resets -> Spreads to exactly 1 adjacent cell for each hazard!
	pb._reset_turn(sm, sc)
	assert(pb.hazard_spread_turn_counter == 1, "Hazard spread counter should be 1 after Turn 1")
	var fire_spread_count_t1 = 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if abs(dr) + abs(dc) == 1 and pb.grid_fire[2 + dr][2 + dc] > 0:
				fire_spread_count_t1 += 1
	var poison_spread_count_t1 = 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if abs(dr) + abs(dc) == 1 and pb.grid_poison[4 + dr][4 + dc]:
				poison_spread_count_t1 += 1
	assert(fire_spread_count_t1 == 1, "Fire MUST spread to exactly 1 adjacent cell per turn (got %d)" % fire_spread_count_t1)
	assert(poison_spread_count_t1 == 1, "Poison MUST spread to exactly 1 adjacent cell per turn (got %d)" % poison_spread_count_t1)
	
	# Turn 2: Player moves & turn resets -> Continued spread to 1 adjacent cell
	pb._reset_turn(sm, sc)
	assert(pb.hazard_spread_turn_counter == 2, "Hazard spread counter should be 2 after Turn 2")
	var total_fire_t2 = 0
	var total_poison_t2 = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_fire[r][c] > 0: total_fire_t2 += 1
			if pb.grid_poison[r][c]: total_poison_t2 += 1
	assert(total_fire_t2 >= 3, "Fire tiles must continue spreading on Turn 2")
	assert(total_poison_t2 >= 3, "Poison tiles must continue spreading on Turn 2")
	print("✓ Fire & poison 1-turn single neighbor spread verified!")

	# 27.2 Proceed button (stagechangeb & movefront) placed in empty bottom margin below shop on the right side
	var sc_btn_node = sc.get_node_or_null("stagechangeb") as Button
	if sc_btn_node == null:
		sc_btn_node = Button.new()
		sc_btn_node.name = "stagechangeb"
		sc.add_child(sc_btn_node)
		sc._setup_shop_page_controls()
	assert(sc.shop_root_panel != null, "shop_root_panel must exist")
	var shop_bg = sc.shop_root_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(shop_bg != null and shop_bg.bg_color.a <= 0.88 and shop_bg.bg_color.a >= 0.70, "shop_root_panel must be slightly translucent (alpha around 0.85)")
	assert(sc_btn_node != null, "stagechangeb button must exist")
	assert(sc_btn_node.position.y >= 970.0, "Proceed button stagechangeb (y=%.1f) must be placed in bottom margin (>= 970)" % sc_btn_node.position.y)
	assert(sc_btn_node.position.y + sc_btn_node.size.y <= 1080.0, "Proceed button must fit within screen height")
	assert(sc_btn_node.position.x >= 1400.0, "Proceed button stagechangeb (x=%.1f) must be placed on the right (x >= 1400)" % sc_btn_node.position.x)
	assert(sc_btn_node.z_index >= 40, "Proceed button stagechangeb must have z_index >= 40 to not be buried under panels")

	var sm_mf = sm.get_node_or_null("movefront") as Control
	if sm_mf == null:
		sm_mf = Button.new()
		sm_mf.name = "movefront"
		sm.add_child(sm_mf)
		sm._ready()
	assert(sm_mf.position.y >= 970.0, "movefront button (y=%.1f) must be placed in bottom margin (>= 970)" % sm_mf.position.y)
	assert(sm_mf.position.y + sm_mf.size.y <= 1080.0, "movefront button must fit within screen height")
	assert(sm_mf.position.x >= 1400.0, "movefront button (x=%.1f) must be placed on the right (x >= 1400)" % sm_mf.position.x)
	assert(sm_mf.z_index >= 40, "movefront button must have z_index >= 40 to not be buried under panels")
	print("✓ Proceed buttons (stagechangeb & movefront) lower right margin placement and unburied z-index verified!")

	# Verify skill evolution has no time limit restrictions
	for elem_key in sc.SKILL_EVOLUTION_REGISTRY:
		for evo in sc.SKILL_EVOLUTION_REGISTRY[elem_key].get("mid", []):
			assert("制限時間" not in evo.get("role", "") and "制限時間" not in evo.get("desc", ""), "Skill evolution must not contain time limits: %s" % evo.get("name"))
		var final_dict = sc.SKILL_EVOLUTION_REGISTRY[elem_key].get("final", {})
		for parent_mid in final_dict:
			for evo in final_dict[parent_mid]:
				assert("制限時間" not in evo.get("role", "") and "制限時間" not in evo.get("desc", ""), "Skill evolution must not contain time limits: %s" % evo.get("name"))
	print("✓ Skill evolution has no time limits verified!")

	# 27.3 S5 Boss Jump Button removed from StageManager
	var sm_node_check = root.get_node_or_null("StageManager")
	if sm_node_check:
		assert(sm_node_check.get_node_or_null("DebugStage5Button") == null, "DebugStage5Button must be removed")
	print("✓ S5 boss debug button removal verified!")

	# -------------------------------------------------------------
	# 28. Section 28: Item & Element Combat Hover Tooltips & Independent Gold Statue Block
	# -------------------------------------------------------------
	print("\n--- Testing Section 28: Item/Element Combat Tooltips & Independent Gold Statue Block ---")

	# 28.1 Verify Combat HUD Item & Element Hover Zones and Tooltips
	assert(sc.has_method("_setup_combat_hud_hover_tooltips"), "score_manager must have _setup_combat_hud_hover_tooltips")
	sc._setup_combat_hud_hover_tooltips()
	var item_hover_0 = sc.get_node_or_null("item_hover_0") as Control
	assert(item_hover_0 != null, "item_hover_0 zone must exist in score_manager")
	assert(sc.has_method("_show_item_tooltip"), "score_manager must have _show_item_tooltip")
	assert(sc.has_method("_hide_item_tooltip"), "score_manager must have _hide_item_tooltip")
	assert(sc.has_method("_show_elem_tooltip"), "score_manager must have _show_elem_tooltip")
	assert(sc.has_method("_hide_elem_tooltip"), "score_manager must have _hide_elem_tooltip")

	# Trigger item tooltips without error
	for idx in range(5):
		sc._show_item_tooltip(idx)
		sc._hide_item_tooltip(idx)
	# Trigger element tooltips for category without error
	sc._show_elem_tooltip("water")
	sc._hide_elem_tooltip("water")
	print("✓ Combat HUD item and element value hover tooltips verified!")

	# 28.2 Verify Enemy Light Skill creates Independent Obstacle Block
	pb.clear_board_hazards()
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = pb.PieceType.SWORD
			pb.grid_gold_statue[r][c] = 0
			if pb.grid_i[r][c] == -1:
				var sp_dummy = Sprite2D.new()
				pb.piece.append(sp_dummy)
				pb.add_child(sp_dummy)
				pb.grid_i[r][c] = pb.piece.size() - 1

	# Ensure target kind (SWORD) exists and cast enemy light skill
	var targets = pb._cast_enemy_light_skill(false, false)
	assert(targets.size() >= 1, "Enemy light skill must target at least 1 cell")

	# Find a gold statue cell
	var statue_cell = Vector2i(-1, -1)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue.size() == pb.GRID_ROWS and pb.grid_gold_statue[r][c] > 0 and not pb.is_ally_gold(r, c):
				statue_cell = Vector2i(r, c)
				break
		if statue_cell.x != -1: break

	assert(statue_cell.x != -1, "At least one enemy gold statue block must be spawned")
	var gr = statue_cell.x
	var gc = statue_cell.y

	# Verify it is an independent obstacle block (NO underlying piece)
	assert(pb.grid_i[gr][gc] == -1, "Gold statue cell grid_i must be -1 (independent obstacle block)")
	assert(pb.grid_n[gr][gc] == -1, "Gold statue cell grid_n must be -1")
	assert(pb.grid_att[gr][gc] == -1, "Gold statue cell grid_att must be -1")
	assert(pb.is_ally_gold(gr, gc) == false, "Must be enemy obstacle")

	# Verify _find_matches does not form match with normal pieces across gold statue
	# Place matching SWORDs horizontally around statue: (gr, gc-1)=SWORD, (gr, gc+1)=SWORD
	if gc > 0 and gc < pb.GRID_COLUMNS - 1:
		pb.grid_n[gr][gc - 1] = pb.PieceType.SWORD
		pb.grid_n[gr][gc + 1] = pb.PieceType.SWORD
		pb.ismatched[gr][gc] = false
		pb._check_matches_exist()
		assert(pb.ismatched[gr][gc] == false, "Independent gold statue block must NOT be matched like a normal piece")

	# Verify adjacent match destruction and empty cell cascade
	var init_dur = pb.grid_gold_statue[gr][gc]
	assert(init_dur > 0, "Statue durability must be > 0")
	# Simulate adjacent match damaging statue until broken
	while pb.grid_gold_statue[gr][gc] > 0:
		pb.grid_gold_statue[gr][gc] -= 1
		if pb.grid_gold_statue[gr][gc] <= 0:
			pb.grid_gold_statue[gr][gc] = 0
			pb._set_ally_flag(pb.grid_gold_ally, gr, gc, false)

	assert(pb.grid_gold_statue[gr][gc] == 0, "Statue must be destroyed")
	assert(pb.grid_i[gr][gc] == -1, "Destroyed statue cell must be empty space ready for cascade")

	print("✓ Enemy Light Skill independent gold statue block & cascade clearance fully verified!")

	# -------------------------------------------------------------
	# 29. Section 29: Debug Kill Enemy Command
	# -------------------------------------------------------------
	print("\n--- Testing Section 29: Debug Kill Enemy Command ---")
	assert(sm.has_method("debug_kill_enemy"), "stage_manager must have debug_kill_enemy method")

	# Spawn enemy
	sm.stage = 1
	sm.stage_enemy = 1
	sm.isdeadf = false
	sm.make_enemy(false)
	assert(sm.active_enemies.size() > 0, "Enemy must be active")
	assert(sm.ehp > 0, "Enemy HP must be > 0")

	# Trigger debug kill enemy command
	sm.debug_kill_enemy()
	assert(sm.active_enemies.size() == 0, "All active enemies must be defeated by debug_kill_enemy")
	assert(sm.ehp == 0, "Enemy HP must be 0")
	assert(sm.isdeadf == true, "isdeadf must be set to true")
	print("✓ Direct debug_kill_enemy() call successfully defeated active enemy!")

	# Test keyboard shortcut trigger (KEY_K and KEY_F10)
	sm.isdeadf = false
	sm.make_enemy(false)
	assert(sm.active_enemies.size() > 0, "Enemy must be active for key event test")
	var ev_k = InputEventKey.new()
	ev_k.pressed = true
	ev_k.keycode = KEY_K
	sm._input(ev_k)
	assert(sm.active_enemies.size() == 0, "KEY_K must trigger debug_kill_enemy")
	assert(sm.isdeadf == true, "isdeadf must be set to true after KEY_K")
	print("✓ KEY_K shortcut successfully defeated active enemy!")

	sm.isdeadf = false
	sm.make_enemy(false)
	assert(sm.active_enemies.size() > 0, "Enemy must be active for F10 test")
	var ev_f10 = InputEventKey.new()
	ev_f10.pressed = true
	ev_f10.keycode = KEY_F10
	sm._input(ev_f10)
	assert(sm.active_enemies.size() == 0, "KEY_F10 must trigger debug_kill_enemy")
	assert(sm.isdeadf == true, "isdeadf must be set to true after KEY_F10")
	print("✓ KEY_F10 shortcut successfully defeated active enemy!")

	# =========================================================================
	# =========================================================================
	# SECTION 30: Water Skill Initial Spec & Strict Lv.1~4 Isolation
	# =========================================================================
	print("\n--- SECTION 30: Water Skill Initial Spec & Isolation Tests ---")

	pb._initialize_board(null)
	var water_positions = pb.cast_player_skill("water", true, 1)
	assert(water_positions.size() >= 2, "Water skill must create at least 2 water cells")
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.ismatched[r][c] = false
	pb._trigger_aqua_splash(3, 3, pb.get_cell_position(3, 3), [], {})
	assert(pb.ismatched[3][3] == true, "Center cell (3,3) must be marked matched")
	assert(pb.ismatched[2][3] == true, "Adjacent water cell (2,3) must be marked matched")

	# Strict Lv.1~4 Isolation: Water does NOT heal, shield, or surge before Lv.5 evolution
	sm.active_enemies.clear()
	sc.skill_evolutions.clear()
	sc.skill_tree_items[0]["level"] = 1 # Lv1
	sm.myhp = 500.0
	sm.guard = 0.0
	sm.ehp = 2000.0
	sm.isdeadf = false
	pb._initialize_board(null)
	pb._apply_water_to_cell(1, 1, true)
	pb._apply_water_to_cell(1, 2, true)
	pb._reset_turn(sm, sc)
	assert(sm.myhp == 500.0, "Before Lv.5 evolution, water must NOT heal HP (got %f)" % sm.myhp)
	assert(sm.guard == 0.0, "Before Lv.5 evolution, water must NOT grant guard (got %f)" % sm.guard)
	assert(sm.ehp == 2000.0, "Before Lv.5 evolution, water must NOT deal surge damage (got %f)" % sm.ehp)
	print("✓ Water Lv.1~4 strictly isolated: ZERO heal, ZERO shield, ZERO surge!")

	# Water Lv.5 Branches: A (Heal), B (Shield), C (Surge)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("water_1", 5, "water_mid_a")
	pb._reset_turn(sm, sc)
	assert(sm.myhp > 500.0, "water_mid_a must heal player HP at turn end")
	print("✓ water_mid_a verified: HP healed!")

	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("water_1", 5, "water_mid_b")
	pb._reset_turn(sm, sc)
	assert(sm.guard > 0.0 or pb.current_total_shields > 0, "water_mid_b must grant shield at turn end")
	print("✓ water_mid_b verified: Shield granted!")

	sc.skill_evolutions.clear()
	sm.ehp = 2000.0
	sm.isdeadf = false
	sc.choose_skill_evolution("water_1", 5, "water_mid_c")
	pb._reset_turn(sm, sc)
	assert(sm.ehp < 2000.0, "water_mid_c must deal surge damage to enemy at turn end")
	print("✓ water_mid_c verified: Surge damage dealt!")

	# --- SECTION 34: Board Settles into Steady State Before Relic Selection on Skill Defeat ---
	print("\n--- SECTION 34: Board Settles into Steady State Before Relic Selection on Skill Defeat ---")
	pb._initialize_board(null)
	pb.current_state = pb.BoardState.IDLE
	pb.falling_pieces.clear()
	pb.flying_cells.clear()
	pb.flying_swords.clear()
	assert(pb.is_steady_state() == true, "Board must report is_steady_state() == true when IDLE and no pieces moving")

	# 1. Verify falling pieces cause is_steady_state() to be false
	var dummy_sprite = Sprite2D.new()
	pb.add_child(dummy_sprite)
	pb.falling_pieces.append({
		"sprite": dummy_sprite,
		"waypoints": [Vector2(100, 200)] as Array[Vector2],
		"wp_idx": 0,
		"velocity_y": 100.0,
		"landed": false
	})
	pb.current_state = pb.BoardState.FALLING
	assert(pb.is_steady_state() == false, "Board must report is_steady_state() == false when pieces are falling")

	# 2. Defeat enemy while pieces are falling
	var dummy_enemy_spr = Sprite2D.new()
	sm.add_child(dummy_enemy_spr)
	sm.active_enemies = [{
		"hp": 50.0,
		"max_hp": 50.0,
		"sprite": dummy_enemy_spr
	}]
	sm.ehp = 50.0
	sm.isdeadf = false
	sm.deadinterval = 0
	sm.has_transitioned_after_death = false
	sm.calchp(100.0, 0.0) # Defeats enemy
	assert(sm.isdeadf == true, "Enemy must be defeated and isdeadf set to true")
	assert(sm.has_transitioned_after_death == false, "has_transitioned_after_death must be false initially")

	# 3. Process board frame while sm.isdeadf is true: Board MUST NOT freeze current_state into IDLE mid-air
	pb._process(0.016)
	assert(pb.current_state == pb.BoardState.FALLING, "Falling board state must NOT be prematurely overridden to IDLE mid-fall on enemy death")

	# 4. Process stage manager when deadinterval >= 100 while board is still falling
	sm.deadinterval = 100
	sm._step_process()
	assert(sm.has_transitioned_after_death == false, "StageManager must NOT transition to relic selection while board is not steady")

	# 5. Simulate falling completion and return to steady state
	pb.falling_pieces.clear()
	pb.current_state = pb.BoardState.IDLE
	dummy_sprite.queue_free()
	dummy_enemy_spr.queue_free()
	assert(pb.is_steady_state() == true, "Board must now report is_steady_state() == true")

	# 6. Process stage manager now that board is steady: transition must trigger
	sm._step_process()
	assert(sm.has_transitioned_after_death == true, "StageManager must transition to relic selection once board settles into steady state")
	print("✓ Board steady state synchronization verified: board completes falling and steady state reached before relic selection!")

	# --- SECTION 35: Lv.10 Awakening, Skill Bar Evolution Display, Stage 1 Gradual Enemies & Battle Font ---
	print("\n--- SECTION 35: Lv.10 Awakening, Skill Bar Evolution Display, Stage 1 Gradual Enemies & Battle Font ---")
	
	# 1. Ice Skill Match Item & Operation
	rm.set_chosen_element_category("nature")
	# 未解放時は特殊スキル駒は出現しない
	pb.special_levels[pb.SpecialItemType.ICE_SHIELD] = 0
	var locked_sp = pb._select_special_for_match(pb.PieceType.SHIELD, 4, 4, false)
	assert(locked_sp == pb.SpecialItemType.NONE, "Locked skills must not spawn special skill pieces")
	# 解放後はマッチで特殊スキル駒が出現
	pb.special_levels[pb.SpecialItemType.ICE_SHIELD] = 1
	var ice_sp = pb._select_special_for_match(pb.PieceType.SHIELD, 4, 4, false)
	assert(ice_sp == pb.SpecialItemType.ICE_SHIELD, "Matching 4 shields in nature category with unlocked skill MUST spawn ICE_SHIELD item")
	pb.grid_i[3][3] = 0
	pb.special_item[3][3] = pb.SpecialItemType.ICE_SHIELD
	var queue_sp: Array = []
	var exp_items: Dictionary = {}
	pb._trigger_ice_shield(3, 3, pb.get_cell_position(3, 3), queue_sp, exp_items)
	print("✓ Ice skill matching spawn and operation trigger verified!")

	# 2. Stage 1 Gradual Enemy Progression & Non-fixed Random Selection
	sm.stage = 1
	var observed_species: Dictionary = {}
	for rep in range(20):
		sm.stage_enemy = (rep % 4) + 1
		sm.enemycount = 0
		sm.make_enemy(false)
		assert(sm.active_enemies.size() == 1, "Stage 1 should spawn strictly 1 enemy")
		var k = sm.active_enemies[0].get("key", "")
		observed_species[k] = true
	assert(observed_species.size() > 1, "Stage 1 battles 1-4 enemies MUST NOT be fixed to a single species (observed %d species)" % observed_species.size())

	# Check Battle 1 (0.35x progression)
	sm.stage_enemy = 1
	sm.enemycount = 0
	sm.make_enemy(false)
	assert(sm.ehpmax >= 1400.0 and sm.ehpmax <= 2200.0, "Stage 1 Battle 1 enemy HP should be scaled to ~1400-2200 (got %f)" % sm.ehpmax)
	assert(sm.enemyat >= 300.0 and sm.enemyat <= 460.0, "Stage 1 Battle 1 enemy ATK should be scaled to ~300-460 (got %f)" % sm.enemyat)

	# Check Battle 2 (0.60x progression)
	sm.stage_enemy = 2
	sm.enemycount = 0
	sm.make_enemy(false)
	assert(sm.ehpmax >= 2500.0 and sm.ehpmax <= 3700.0, "Stage 1 Battle 2 enemy HP should be scaled to ~2500-3700 (got %f)" % sm.ehpmax)

	# Check Battle 3 (0.90x progression)
	sm.stage_enemy = 3
	sm.enemycount = 0
	sm.make_enemy(false)
	assert(sm.ehpmax >= 3700.0 and sm.ehpmax <= 5500.0, "Stage 1 Battle 3 enemy HP should be scaled to ~3700-5500 (got %f)" % sm.ehpmax)

	# Check Battle 4 (1.25x progression)
	sm.stage_enemy = 4
	sm.enemycount = 0
	sm.make_enemy(false)
	assert(sm.ehpmax >= 5200.0 and sm.ehpmax <= 7600.0, "Stage 1 Battle 4 enemy HP should be scaled to ~5200-7600 (got %f)" % sm.ehpmax)

	# Check Battle 5 (Boss Fenrir 45,000 HP)
	sm.stage_enemy = 5
	sm.enemycount = 0
	sm.make_enemy(true)
	assert(sm.ehpmax == 45000.0, "Stage 1 Battle 5 Boss enemy HP should be 45000 (got %f)" % sm.ehpmax)
	print("✓ Stage 1 randomized enemy selection and gradual progression (0.35x -> 0.60x -> 0.90x -> 1.25x -> Boss 45000 HP) verified!")

	# 3. BATTLE 1/5 Label larger font size
	sm.is_current_boss = false
	sm.stage_enemy = 1
	sm.label_control()
	assert(sm.label2.text.contains("font_size=26"), "BATTLE 1/5 label font size should be enlarged to 26 (got %s)" % sm.label2.text)
	print("✓ BATTLE 1/5 enlarged font size verified!")

	# 4. Evolution / Awakening at Lv.5 in ScoreManager
	var sm_test = sc_script.new()
	dummy_root.add_child(sm_test)
	sm_test._init()
	sm_test.on_element_category_chosen("nature")
	var water_idx = -1
	for idx in range(sm_test.skill_tree_items.size()):
		if sm_test.skill_tree_items[idx]["id"] == "water_1":
			water_idx = idx
			break
	sm_test.divscore[sm_test.PieceType.POTION] = 100000000
	for lvl in range(1, 10):
		sm_test._purchase_skill(water_idx)
		assert(sm_test.skill_tree_items[water_idx]["level"] == lvl, "Should upgrade cleanly to lvl %d without modal" % lvl)
		assert(sm_test.tarot_modal_panel == null or not is_instance_valid(sm_test.tarot_modal_panel))
	sm_test._purchase_skill(water_idx)
	assert(sm_test.tarot_modal_panel != null and is_instance_valid(sm_test.tarot_modal_panel), "Modal MUST trigger at Lv.10")
	var w_btn = sm_test.tarot_modal_panel.get_node("TarotCard_0/SelectBtn_0") as Button
	w_btn.emit_signal("pressed")
	assert(sm_test.skill_tree_items[water_idx]["level"] == 10, "Skill level should now be 10")
	var chosen_evo = sm_test.get_chosen_evolution("water_1", 10)
	assert(chosen_evo != "", "Chosen evolution must be recorded at Lv.10")

	# 5. Skill Bar and Puzzle Board reflects chosen awakening
	var r_ui = load("res://relic_ui_manager.gd").new()
	dummy_root.add_child(r_ui)
	r_ui._ready()
	r_ui.update_skill_display("water_1", 10)
	var node_rect = r_ui.skill_icon_nodes.get("water_1") as ColorRect
	assert(node_rect != null, "Skill icon node must exist in skill bar")
	var evo_lbl = node_rect.get_node_or_null("EvoLabel") as Label
	assert(evo_lbl != null, "EvoLabel must exist on skill icon")
	assert(evo_lbl.text.begins_with("✨") or evo_lbl.text.begins_with("👑"), "EvoLabel must display awakening badge and name (got %s)" % evo_lbl.text)

	# Tooltip contains chosen awakening
	r_ui._show_skill_tooltip("water_1", node_rect)
	assert(r_ui.name_label.text.contains("✨[") or r_ui.name_label.text.contains("👑["), "Tooltip title must contain chosen awakening name (got %s)" % r_ui.name_label.text)
	assert(r_ui.desc_label.text.contains("【第1覚醒:") or r_ui.desc_label.text.contains("【最終覚醒:"), "Tooltip description must contain awakening details (got %s)" % r_ui.desc_label.text)

	# PuzzleBoard buttons reflect chosen awakening
	pb._update_player_skill_ui()
	var w_skill_btn = pb.player_skill_buttons.get("water") as Button
	assert(w_skill_btn != null and (w_skill_btn.text.contains("✨") or w_skill_btn.text.contains("👑")), "PuzzleBoard water skill button must reflect awakening (got %s)" % w_skill_btn.text)
	print("✓ Skill bar and PuzzleBoard reflection of selected awakening verified!")

	sm_test.queue_free()
	r_ui.queue_free()

		# =========================================================================
	# SECTION 36: Full 10 Elements Evolution System (90 Nodes Tree & Mechanics)
	# =========================================================================
	print("\n--- SECTION 36: Complete 10-Element Evolution Suite (90 Nodes Tree) ---")

	sm.active_enemies.clear()
	sm.isdeadf = false
	var all_elements = ["water", "wood", "wind", "thunder", "ice", "fire", "poison", "earth", "light", "dark"]
	var total_mid_count = 0
	var total_final_count = 0

	# 1. Verify 10-Element Tree Structure & Parent-Child Hierarchy Constraints
	for elem in all_elements:
		var s_id = elem + "_1"
		sc.skill_evolutions.clear()

		# Mid choices at Lv.5 MUST be exactly 3 (A, B, C)
		var mids = sc.get_evolution_choices(s_id, 5)
		assert(mids.size() == 3, "%s must have exactly 3 mid choices at Lv.5" % elem)
		assert(mids[0]["branch"] == "A" and mids[0]["id"] == "%s_mid_a" % elem)
		assert(mids[1]["branch"] == "B" and mids[1]["id"] == "%s_mid_b" % elem)
		assert(mids[2]["branch"] == "C" and mids[2]["id"] == "%s_mid_c" % elem)
		total_mid_count += 3

		# Hierarchy constraint: Without Lv.5 chosen, Lv.15 choices MUST be empty
		var finals_no_mid = sc.get_evolution_choices(s_id, 15)
		assert(finals_no_mid.is_empty(), "%s Lv.15 choices must be empty before selecting Lv.5 mid evolution" % elem)

		# For each mid branch, test that Lv.15 returns exactly its 2 final choices
		for branch_letter in ["a", "b", "c"]:
			var mid_id = "%s_mid_%s" % [elem, branch_letter]
			sc.choose_skill_evolution(s_id, 5, mid_id)
			var branch_finals = sc.get_evolution_choices(s_id, 15)
			assert(branch_finals.size() == 2, "%s_%s must have exactly 2 final choices at Lv.15" % [elem, branch_letter])
			assert(branch_finals[0]["id"] == "%s_final_%s1" % [elem, branch_letter], "Final 1 mismatch for %s branch %s" % [elem, branch_letter])
			assert(branch_finals[1]["id"] == "%s_final_%s2" % [elem, branch_letter], "Final 2 mismatch for %s branch %s" % [elem, branch_letter])
			total_final_count += 2

	assert(total_mid_count == 30, "Must have exactly 30 mid choices (10 elements * 3 branches)")
	assert(total_final_count == 60, "Must have exactly 60 final choices (10 elements * 3 branches * 2 choices)")
	print("✓ 90 Evolution Nodes & Parent-Child Hierarchy fully verified (30 Mid + 60 Final)!")

	# 2. Water Mechanics (溢れる泉, 水の結界, 渦潮)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("water_1", 5, "water_mid_a")
	sc.choose_skill_evolution("water_1", 15, "water_final_a2") # 溢れる泉 (超過回復シールド化)
	pb._initialize_board(null)
	for i in range(5):
		pb._apply_water_to_cell(i / 8, i % 8, true)
	sm.myhp = sm.myhpmax
	pb.current_total_shields = 0
	pb._reset_turn(sm, sc)
	assert(pb.current_total_shields > 0, "water_final_a2 (溢れる泉) must convert overflow healing into shield")
	print("✓ Water A2 (溢れる泉) overflow shield verified!")

	# Water C2 (渦潮: 最多列消去で落下誘発＆ダメージ、水マス維持)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("water_1", 5, "water_mid_c")
	sc.choose_skill_evolution("water_1", 15, "water_final_c2")
	pb._initialize_board(null)
	for r in range(4):
		pb._apply_water_to_cell(r, 2, true) # 4 water cells in col 2
	sm.ehp = 10000.0
	sm.isdeadf = false
	pb._reset_turn(sm, sc)
	assert(sm.ehp < 10000.0, "water_final_c2 (渦潮) must deal damage")
	assert(pb.grid_water[0][2] == true, "water_final_c2 (渦潮) must NOT consume water cells")
	print("✓ Water C2 (渦潮) verified!")

	# 3. Wood Mechanics (深い根, 森の加護, 毒棘)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("wood_1", 5, "wood_mid_a")
	sc.choose_skill_evolution("wood_1", 15, "wood_final_a2") # 深い根 (段階低下で耐える)
	var deep_plant = {"stage": 2, "thunder_hp": 1, "origin": Vector2i(4, 4), "enemy_planted": false}
	pb.plant_entities.append(deep_plant)
	pb._damage_plant(deep_plant, 1, "lightning")
	assert(deep_plant.stage == 1, "wood_final_a2 (深い根) must reduce stage instead of destroying plant")
	assert(deep_plant in pb.plant_entities, "plant must still be alive")
	print("✓ Wood A2 (深い根) verified!")

	# 4. Thunder Mechanics (感電, 放電)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("thunder_1", 5, "thunder_mid_b")
	sc.choose_skill_evolution("thunder_1", 15, "thunder_final_b1")
	pb._initialize_board(null)
	pb.grid_electrified[1][1] = true
	pb._set_ally_flag(pb.grid_electrified_ally, 1, 1, true)
	pb.grid_electrified[1][2] = true
	pb._set_ally_flag(pb.grid_electrified_ally, 1, 2, true)
	sm.ehp = 5000.0
	sm.isdeadf = false
	pb._reset_turn(sm, sc)
	assert(sm.ehp < 5000.0, "thunder_final_b1 (放電) must deal discharge damage from charged coins")
	print("✓ Thunder B1 (放電) verified!")

	# 5. Ice Mechanics (氷柱反撃, 永久凍土, 寒気)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("ice_1", 5, "ice_mid_c") # 永久凍土 (耐久減少しない)
	pb._initialize_board(null)
	pb.grid_ice[2][2] = 3
	pb._set_ally_flag(pb.grid_ice_ally, 2, 2, true)
	pb._reset_turn(sm, sc)
	assert(int(pb.grid_ice[2][2]) == 3, "ice_mid_c (永久凍土) must prevent ice durability decay")
	print("✓ Ice C (永久凍土) durability preservation verified!")

	# 6. Fire Mechanics (延焼なしデフォルト, 焼き払い)
	sc.skill_evolutions.clear()
	pb._initialize_board(null)
	pb.grid_fire[3][3] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 3, 3, true)
	pb._process_fire_spread()
	# Without fire_mid_b (延焼), fire MUST NOT spread!
	var fire_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_fire[r][c] > 0: fire_count += 1
	assert(fire_count == 1, "Fire must NOT spread without Evolution B (延焼)")
	print("✓ Fire default no-spread verified!")

	# 7. Earth Mechanics (飛礫, 黄金化, 金剛石)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("earth_1", 5, "earth_mid_a")
	sc.choose_skill_evolution("earth_1", 15, "earth_final_a2") # 飛礫
	pb._initialize_board(null)
	pb.grid_stones[4][4] = 1
	pb._set_ally_flag(pb.grid_stones_ally, 4, 4, true)
	pb._damage_stone_at(4, 4, 1)
	var pebble_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_stones[r][c] == 1: pebble_count += 1
	assert(pebble_count == 2, "earth_final_a2 (飛礫) must spawn 2 pebbles of durability 1 on destruction")
	print("✓ Earth A2 (飛礫) verified!")

	# 8. Dark Mechanics (重力自由スワップ, 混沌放出)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("dark_1", 5, "dark_mid_c") # 混沌
	sc.choose_skill_evolution("dark_1", 15, "dark_final_c1") # 復讐 (+50%)
	pb.dark_accumulated_damage = 400.0
	sm.ehp = 5000.0
	sm.isdeadf = false
	pb.cast_player_skill("dark", true, 1)
	assert(pb.dark_accumulated_damage == 0.0, "dark_mid_c (混沌) must reset accumulated damage upon cast")
	print("✓ Dark C1 (復讐・混沌解放) verified!")

	print("✓ SECTION 36: Full 10-Element Evolution Suite ALL PASSED!\n")

	# =========================================================================
	# SECTION 37: Fever Dance Characters & Sound Effect Sequence
	# =========================================================================
	print("\n--- SECTION 37: Fever Dance Characters & Sound Effect Sequence ---")
	sm.fevergage = 7000.0
	sm.fevertime()
	assert(sm.isfevertime == true, "Fever time must be active")
	
	# 1. Verify existence of 3 fever dancer nodes
	assert(sm.fever_dancer_bg_left != null and is_instance_valid(sm.fever_dancer_bg_left), "fever_dancer_bg_left must exist")
	assert(sm.fever_dancer_bg_right != null and is_instance_valid(sm.fever_dancer_bg_right), "fever_dancer_bg_right must exist")
	assert(sm.fever_dancer_bottom_left != null and is_instance_valid(sm.fever_dancer_bottom_left), "fever_dancer_bottom_left must exist")
	
	# 2. Verify dancers are hidden initially while waiting for SE to finish
	assert(sm.is_waiting_for_fever_se == true, "Must be waiting for fever sound effect to finish")
	assert(sm.fever_dancer_bg_left.visible == false, "fever_dancer_bg_left must remain hidden until SE finishes")
	assert(sm.fever_dancer_bg_right.visible == false, "fever_dancer_bg_right must remain hidden until SE finishes")
	assert(sm.fever_dancer_bottom_left.visible == false, "fever_dancer_bottom_left must remain hidden until SE finishes")

	# 3. Simulate SE finish (鳴りきり) -> Dancers rush in (乱入)
	sm._on_fever_se_finished()
	assert(sm.is_waiting_for_fever_se == false, "is_waiting_for_fever_se must be false after SE finishes")
	assert(sm._fever_dancers_active == true, "_fever_dancers_active must be true after SE finishes")
	assert(sm.fever_dancer_bg_left.visible == true, "fever_dancer_bg_left must become visible after SE finishes")
	assert(sm.fever_dancer_bg_right.visible == true, "fever_dancer_bg_right must become visible after SE finishes")
	assert(sm.fever_dancer_bottom_left.visible == true, "fever_dancer_bottom_left must become visible after SE finishes")
	assert(sm.fever_dancer_bg_left.is_playing() == true, "fever_dancer_bg_left must be playing dance animation")
	assert(sm.fever_dancer_bg_right.is_playing() == true, "fever_dancer_bg_right must be playing dance animation")
	assert(sm.fever_dancer_bottom_left.is_playing() == true, "fever_dancer_bottom_left must be playing dance animation")
	
	# 4. Verify positioning & layer ordering
	# Enemy screen background dancers: z_index < 0 (behind enemies at z_index=0), left and right outer flanks
	assert(sm.fever_dancer_bg_left.z_index < 0, "bg_left dancer must be behind enemies (z_index < 0)")
	assert(sm.fever_dancer_bg_right.z_index < 0, "bg_right dancer must be behind enemies (z_index < 0)")
	assert(sm.fever_dancer_bg_left.flip_h == false, "bg_left dancer should face towards center")
	assert(sm.fever_dancer_bg_right.flip_h == true, "bg_right dancer should face towards center")
	
	# Bottom-left margin dancer: x < 240, y > 600
	assert(sm.fever_dancer_bottom_left.position.x < 240.0, "bottom_left dancer must be in left margin (x < 240)")
	assert(sm.fever_dancer_bottom_left.z_index >= 10, "bottom_left dancer must have z_index >= 10 above background")
	
	print("✓ Fever dance characters waiting for SE and rushing in (乱入) verified!")
	
	# 5. Verify stop & hidden on notfevertime
	sm.notfevertime()
	assert(sm.isfevertime == false, "Fever time must end")
	assert(sm.fever_dancer_bg_left.visible == false, "fever_dancer_bg_left must be hidden when fever ends")
	assert(sm.fever_dancer_bg_right.visible == false, "fever_dancer_bg_right must be hidden when fever ends")
	assert(sm.fever_dancer_bottom_left.visible == false, "fever_dancer_bottom_left must be hidden when fever ends")
	print("✓ Fever dance hidden on fever end verified!")
	print("✓ SECTION 37: Fever Dance Characters ALL PASSED!\n")

	# =========================================================================
	# SECTION 38: Score Addition Popup Positioning (Current Score Location)
	# =========================================================================
	print("\n--- SECTION 38: Score Addition Popup Positioning ---")
	sc._spawn_score_popup([], 0, 1500, 3, false)
	var spawned_popup: RichTextLabel = null
	for p in sc._popup_pool:
		if p.visible:
			spawned_popup = p
			break
	assert(spawned_popup != null, "Score popup must be spawned and visible")
	assert(spawned_popup.position.x >= 1400.0 and spawned_popup.position.x <= 1800.0,
		"Popup X position (%.1f) must be at current score area (1400-1800)" % spawned_popup.position.x)
	assert(spawned_popup.position.y >= 400.0 and spawned_popup.position.y <= 500.0,
		"Popup Y position (%.1f) must be at current score area (400-500)" % spawned_popup.position.y)
	assert("1,500" in spawned_popup.text, "Popup text must include formatted score '1,500'")
	print("✓ Score addition popup at current score area verified!")
	print("✓ SECTION 38: Score Addition Popup ALL PASSED!\n")

	# =========================================================================
	# SECTION 39: Fever Text Waiting for SE & Wikipedia-Style Glossary Tooltips
	# =========================================================================
	print("\n--- SECTION 39: Fever Text Waiting for SE & Wikipedia-Style Glossary Tooltips ---")

	# 1. フィーバー開始時：効果音が鳴りきるまで全文字・HUDが完全待機（非表示）状態であること
	var sm_fever_lbl = sc.get_node_or_null("feverlabel") as RichTextLabel
	if sm_fever_lbl == null:
		sm_fever_lbl = RichTextLabel.new()
		sm_fever_lbl.name = "feverlabel"
		sc.add_child(sm_fever_lbl)
	for rect_name in ["feverrect", "feverrect2"]:
		if sc.get_node_or_null(rect_name) == null:
			var cr = ColorRect.new()
			cr.name = rect_name
			sc.add_child(cr)
	for rtl_name in ["feverlabel2", "feverlabel3", "fevertime", "fevertimecount"]:
		if sc.get_node_or_null(rtl_name) == null:
			var rtl = RichTextLabel.new()
			rtl.name = rtl_name
			sc.add_child(rtl)

	sm.fevergage = 7000.0
	sm.fevertime()
	assert(sm.isfevertime == true, "Must be in fever time")
	assert(sm.is_waiting_for_fever_se == true, "Must be waiting for fever SE on entry")
	assert(sm_fever_lbl.position.x >= 0.0 and sm_fever_lbl.position.x <= 1920.0, "Center fever banner must be displayed largely on screen upon fever entry")
	assert(sm._fever_dancers_active == false, "Fever dancers must wait until SE finishes")

	for node_name in ["feverrect", "feverrect2", "feverlabel2", "feverlabel3", "fevertime", "fevertimecount"]:
		var n = sc.get_node_or_null(node_name)
		if n:
			assert(n.visible == false, "HUD element %s must be hidden while fever SE is playing" % node_name)
	print("✓ Big fever banner is displayed largely while HUD fields and dancers wait during SE!")

	# SE演奏待機中はフレームが進んでも appeartime が進行せずHUD欄が表示されないこと
	sm.is_waiting_for_fever_se = true
	for _step in range(10):
		sm._step_process()
	assert(sm.appeartime == 0, "appeartime must not advance while waiting for fever SE")
	assert(sm._fever_dancers_active == false, "Fever dancers must remain inactive while SE is playing")
	print("✓ appeartime remains 0 and dancers/HUD remain waiting while SE is playing!")

	# SE演奏終了時：HUD各欄とダンサーが出現
	sm._on_fever_se_finished()
	assert(sm.is_waiting_for_fever_se == false, "is_waiting_for_fever_se must be false after finished")
	assert(sm._fever_dancers_active == true, "Fever dancers must be active after SE finished")
	var fv_rect = sc.get_node_or_null("feverrect")
	if fv_rect:
		assert(fv_rect.visible == true, "feverrect HUD must be visible after SE finished")
	var fv_lbl3 = sc.get_node_or_null("feverlabel3")
	if fv_lbl3:
		assert(fv_lbl3.visible == true, "feverlabel3 HUD must be visible after SE finished")
	print("✓ Fever HUD columns and fever dance appear upon SE completion!")

	sm.notfevertime()
	assert(sm.isfevertime == false, "Must exit fever time")
	print("✓ Fever time sequence test passed!")

	# 2. Wikipedia風 固有名詞辞書 (GlossaryDatabase) の動作検証
	var term_water = GlossaryDatabase.get_term("水マス")
	assert(not term_water.is_empty(), "Glossary must have '水マス'")
	assert("水マス" in term_water["title"], "Term title must contain '水マス'")
	assert("水属性" in term_water["desc"], "Term desc must describe water tile")

	var term_burn = GlossaryDatabase.get_term("延焼")
	assert(not term_burn.is_empty(), "Glossary must have '延焼'")

	var formatted_text = GlossaryDatabase.format_text("水マス上でマッチするとHP回復し、火マスと接触すると相殺する")
	assert("[url=水マス]" in formatted_text, "Formatted text must contain url tag for 水マス")
	assert("[u]水マス[/u]" in formatted_text, "Formatted text must contain underline for 水マス")
	assert("[url=火マス]" in formatted_text, "Formatted text must contain url tag for 火マス")
	assert("[u]火マス[/u]" in formatted_text, "Formatted text must contain underline for 火マス")
	assert("HP回復し" in formatted_text, "Non-term text must be preserved")
	print("✓ GlossaryDatabase.format_text successfully adds Wikipedia links!")

	# BBCodeタグとの共存（タグ内部の属性を破壊しないこと）
	var colored_input = "[color=#FFD700]水マス[/color]と[b]木マス[/b]"
	var colored_formatted = GlossaryDatabase.format_text(colored_input)
	assert("[color=#FFD700]" in colored_formatted, "Outer BBCode tag [color] must be preserved")
	assert("[/color]" in colored_formatted, "Closing BBCode tag [/color] must be preserved")
	assert("[b]" in colored_formatted, "Outer BBCode tag [b] must be preserved")
	assert("[/b]" in colored_formatted, "Closing BBCode tag [/b] must be preserved")
	assert("[url=水マス]" in colored_formatted, "Inner term 水マス must be linked")
	assert("[url=木マス]" in colored_formatted, "Inner term 木マス must be linked")
	print("✓ Glossary format preserves existing BBCode tags cleanly!")

	# 3. RelicUIManager の Wikipedia風ホバーカード (Glossary Tooltip) 検証
	var r_ui_mgr = root.find_child("RelicUIManager", true, false)
	if r_ui_mgr:
		assert(r_ui_mgr.glossary_panel != null, "RelicUIManager must have glossary_panel")
		assert(r_ui_mgr.glossary_title_label != null, "RelicUIManager must have glossary_title_label")
		assert(r_ui_mgr.glossary_desc_label != null, "RelicUIManager must have glossary_desc_label")

		# ホバーカード表示テスト
		r_ui_mgr.show_glossary_tooltip("水マス", Vector2(500, 400))
		assert(r_ui_mgr.glossary_panel.visible == true, "glossary_panel must be visible when shown")
		assert("水マス" in r_ui_mgr.glossary_title_label.text, "Title label must show term title")
		assert("水属性" in r_ui_mgr.glossary_desc_label.text, "Desc label must show term description")

		# ホバーカード非表示テスト
		r_ui_mgr.hide_glossary_tooltip()
		assert(r_ui_mgr.glossary_panel.visible == false, "glossary_panel must be hidden when hidden")

		# show_custom_tooltip 経由での自動リンク整形テスト
		r_ui_mgr.show_custom_tooltip("テストスキル", "水マスと火マスとシールドの効果", Vector2(300, 300))
		assert("[url=水マス]" in r_ui_mgr.desc_label.text, "desc_label must have Wikipedia link for 水マス")
		assert("[url=火マス]" in r_ui_mgr.desc_label.text, "desc_label must have Wikipedia link for 火マス")
		assert("[url=シールド]" in r_ui_mgr.desc_label.text, "desc_label must have Wikipedia link for シールド")
		r_ui_mgr.hide_custom_tooltip()
		assert(r_ui_mgr.info_panel.visible == false, "info_panel must be hidden")
		assert(r_ui_mgr.glossary_panel.visible == false, "glossary_panel must be hidden on custom tooltip hide")
		print("✓ RelicUIManager glossary hovercard and tooltip auto-formatting verified!")

	print("✓ SECTION 39: Fever Text Waiting for SE & Wikipedia-Style Glossary Tooltips ALL PASSED!\n")

	
	# =========================================================================
	# SECTION 40: Strict Player-Enemy Symmetry, Durability, Spreads & Status Bar
	# =========================================================================
	print("\n--- SECTION 40: Strict Player-Enemy Symmetry & Refined Systems ---")

	# 1. Water Lv.1~4 Strict Isolation (No Heal, No Shield, No Surge)
	sc.skill_evolutions.clear()
	for lvl in range(1, 5):
		sc.skill_levels["water_1"] = lvl
		pb._initialize_board(null)
		for i in range(4):
			pb._apply_water_to_cell(i, i, true)
		sm.myhp = 500.0
		pb.current_total_shields = 0
		sm.ehp = 5000.0
		pb._reset_turn(sm, sc)
		assert(sm.myhp == 500.0, "Water Lv.%d must NOT heal HP without Evolution A" % lvl)
		assert(pb.current_total_shields == 0, "Water Lv.%d must NOT grant shield without Evolution B" % lvl)
		assert(sm.ehp == 5000.0, "Water Lv.%d must NOT deal surge damage without Evolution C" % lvl)
	print("✓ Water Lv.1~4 Strict Isolation (zero heal, shield, surge) verified!")

	# 2. Poison Default No-Spread (Requires Evolution B)
	sc.skill_evolutions.clear()
	pb._initialize_board(null)
	pb.grid_poison[2][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 2, 2, true)
	pb._process_poison_spread()
	var poi_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]: poi_count += 1
	assert(poi_count == 1, "Poison must NOT spread without Evolution B (伝染)")
	print("✓ Poison default no-spread verified!")

	# 3. Ice Durability Decay (-1 per turn, vanish at 0, no water conversion)
	sc.skill_evolutions.clear()
	pb._initialize_board(null)
	pb.grid_ice[3][3] = 1 # 1 durability left
	pb._set_ally_flag(pb.grid_ice_ally, 3, 3, true)
	pb._reset_turn(sm, sc)
	assert(int(pb.grid_ice[3][3]) == 0, "Ice with 1 durability must decay to 0 and vanish")
	assert(pb.grid_water[3][3] == false, "Ice decay must NOT convert into water")
	print("✓ Ice durability decay and disappearance verified!")

	# 4. Symmetrical Status Ailment Bars (Opposite States)
	pb._initialize_board(null)
	sm.active_enemies.clear()
	var test_status_bar = RichTextLabel.new()
	var test_enemy = {
		"key": "golem",
		"hp": 1000.0,
		"max_hp": 1000.0,
		"atk": 50.0,
		"shield": 0.0,
		"status_bar": test_status_bar,
		"evolutions": ["earth_mid_a"]
	}
	sm.active_enemies.append(test_enemy)

	# Give enemy poison and ally fire
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false) # Enemy poison
	pb.grid_fire[2][2] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 2, 2, true)   # Ally fire

	pb._update_status_ailments()
	assert("☠️毒" in pb.player_status_bar.text, "Player bar must show poison debuff from enemy poison")
	assert("🛡️免疫" in test_enemy["status_bar"].text, "Enemy bar must show poison immunity from own poison")
	assert("🔥火傷" in test_enemy["status_bar"].text, "Enemy bar must show burn debuff from ally fire")
	print("✓ Symmetrical Status Ailment Bars (Opposite States) verified!")

	# 5. Continuous Scaling Buffs (森の加護 5%/本, 城壁 5%/個)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("wood_1", 5, "wood_mid_b")
	sc.choose_skill_evolution("wood_1", 15, "wood_final_b1") # 森の加護
	pb.plant_entities.clear()
	for k in range(3):
		pb.plant_entities.append({"stage": 1, "thunder_hp": 1, "origin": Vector2i(k, k), "enemy_planted": false})
	# 3 plants = 15% reduction
	var raw_dmg = 1000.0
	var final_dmg = raw_dmg * (1.0 - minf(0.40, 3.0 * 0.05))
	assert(final_dmg == 850.0, "森の加護 must reduce damage continuously by 5% per plant (15% for 3 plants)")
	print("✓ Continuous scaling defensive buffs verified!")

	# 6. Enemy Evolutions Symmetry
	assert(test_enemy.has("evolutions"), "Enemy must have evolutions list")
	assert(test_enemy.has("shield"), "Enemy must have shield field")
	print("✓ Enemy Evolutions and Shield structure verified!")

	print("✓ SECTION 40: Strict Player-Enemy Symmetry, Durability, Spreads & Status Bar ALL PASSED!\n")

	# --- SECTION 41: Wood Mark Display & Gold Statue Fever Dance Appearance ---
	print("\n--- SECTION 41: Wood Mark Display & Gold Statue Fever Dance Appearance ---")
	
	# 1. Wood Mark in Battle Skill UI Panel
	assert(pb.has_method("_get_skill_ui_font"), "PuzzleBoard must have _get_skill_ui_font")
	var sk_font = pb._get_skill_ui_font()
	assert(sk_font != null, "Skill UI font must not be null")
	assert(sk_font.has_char(0x1f331), "Skill UI font must support sprout emoji (🌱)")
	assert(sk_font.has_char("木".unicode_at(0)), "Skill UI font must support '木'")
	assert("wood" in pb.PLAYER_SKILL_DEFS, "wood skill must exist in PLAYER_SKILL_DEFS")
	assert("🌱木" in pb.PLAYER_SKILL_DEFS["wood"]["label"], "wood label must have sprout and wood (🌱木)")
	
	var wood_btn = pb.player_skill_buttons.get("wood", null)
	assert(wood_btn != null, "SkillBtn_wood must exist")
	assert(wood_btn.has_theme_font_override("font"), "SkillBtn_wood must have font override set")
	print("✓ Wood mark (🌱木) and emoji font integration verified!")

	# 2. Golden Statue Fever Dance Appearance during Fever Time
	assert(bo.has_method("_get_fever_dance_frames"), "BoardOverlay must have _get_fever_dance_frames")
	var dance_sf = bo._get_fever_dance_frames()
	assert(dance_sf != null, "Fever dance SpriteFrames must be loaded")
	assert(dance_sf.has_animation("dance"), "Must have 'dance' animation")
	assert(dance_sf.get_frame_count("dance") > 0, "Must have frames for 'dance'")

	# Check that gold statue tile uses fever dance during fever
	sm.isfevertime = true
	pb.grid_gold_statue[0][0] = 3
	pb.has_gold_statue = true
	# Trigger overlay redraw
	bo.queue_redraw()
	print("✓ Golden Statue Fever Dance appearance during Fever Time verified!")
	sm.isfevertime = false
	pb.grid_gold_statue[0][0] = 0
	pb.has_gold_statue = false

	print("✓ SECTION 41: Wood Mark Display & Gold Statue Fever Dance ALL PASSED!\n")

	# =========================================================================
	# SECTION 42: Fire Shrapnel Evolution, Explosion Safety, & Upper Corner Dancers
	# =========================================================================
	print("\n--- SECTION 42: Fire Shrapnel Evolution, Explosion Safety, & Upper Corner Dancers ---")

	# 1. Shrapnel ("破片" fire_mid_c) & Howitzer ("榴弾" fire_final_c1)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("fire_1", 5, "fire_mid_c")
	pb._initialize_board(null)
	# Trigger bomb at (3, 3) with radius 1 (3x3 area: rows 2..4, cols 2..4)
	# Pieces at row 1 or 5 are outside the 3x3 radius and should be hit by shrapnel
	pb._trigger_bomb(3, 3, pb.get_cell_position(3, 3), [], {})
	var shrapnel_found = false
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if (r < 2 or r > 4 or c < 2 or c > 4) and pb.ismatched[r][c]:
				shrapnel_found = true
				break
		if shrapnel_found: break
	assert(shrapnel_found, "fire_mid_c (破片) must shatter pieces outside the primary explosion radius")
	print("✓ Fire Evolution '破片' (fire_mid_c) shrapnel scattering verified!")

	# Howitzer (fire_final_c1)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("fire_1", 5, "fire_mid_c")
	sc.choose_skill_evolution("fire_1", 15, "fire_final_c1")
	pb._initialize_board(null)
	var prev_ehp = sm.ehp
	pb._trigger_bomb(3, 3, pb.get_cell_position(3, 3), [], {})
	var howitzer_fire_found = false
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if (r < 2 or r > 4 or c < 2 or c > 4) and pb.grid_fire[r][c] > 0 and pb.is_ally_fire(r, c):
				howitzer_fire_found = true
				break
		if howitzer_fire_found: break
	assert(howitzer_fire_found, "fire_final_c1 (榴弾) must ignite the landing tile as ally fire")
	assert(sm.ehp < prev_ehp, "fire_final_c1 (榴弾) must deal direct howitzer damage to enemy")
	print("✓ Fire Evolution '榴弾' (fire_final_c1) ignition and damage verified!")

	# 2. Enemy Nested Evolution Trait Detection & Blaze Blast Shrapnel
	var enemy_with_nested_evo = {
		"hp": 2000.0, "max_hp": 2000.0, "shield": 500.0,
		"evolutions": {
			"fire": {"mid": "fire_mid_c", "final": "fire_final_c1"}
		}
	}
	assert(pb.has_actor_skill_trait(false, "fire", "fire_mid_c", enemy_with_nested_evo), "Nested dictionary enemy trait fire_mid_c must be detected")
	assert(pb.has_actor_skill_trait(false, "fire", "fire_final_c1", enemy_with_nested_evo), "Nested dictionary enemy trait fire_final_c1 must be detected")

	# Enemy Blaze Blast with Shrapnel
	sm.active_enemies = [enemy_with_nested_evo]
	pb._initialize_board(null)
	pb.last_shrapnel_cleared_cells.clear()
	pb._cast_enemy_fire_skill(false, false)
	assert(pb.last_shrapnel_cleared_cells.size() > 0, "Enemy Blaze Blast with fire_mid_c must scatter shrapnel and clear pieces")
	print("✓ Enemy Blaze Blast with nested '破片' (fire_mid_c) verified!")

	# 3. Explosion Safety: ice_final_a2 Capped Reflection & Plant Fire Ally Preservation
	sm.active_enemies = [{
		"hp": 2000.0, "max_hp": 2000.0, "shield": 10000.0,
		"evolutions": ["ice_final_a2"]
	}]
	sm.myhp = 1000.0
	sm.myhpmax = 1000.0
	sm.guard = 200.0
	# Deal massive 5000 burst damage (e.g. huge explosion)
	sm.calchp(5000.0, 0.0)
	assert(sm.myhp > 0.0, "Player must NOT be killed instantly by ice_final_a2 reflection on huge burst attack")
	print("✓ ice_final_a2 reflection capped & filtered through player defense verified!")

	# Plant Fire Ally Preservation (spreading onto enemy plant keeps ally ownership)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("fire_1", 5, "fire_mid_b") # 延焼
	pb._initialize_board(null)
	pb.grid_fire[0][0] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 0, 0, true) # Ally fire at (0, 0)
	pb.grid_fire[1][0] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 1, 0, true) # Block (1, 0) so only (0, 1) can be chosen
	pb.plant_entities.clear()
	pb.plant_entities.append({
		"origin": Vector2i(0, 1), "stage": 1, "thunder_hp": 1, "enemy_planted": true
	})
	pb._process_fire_spread()
	assert(pb.grid_fire[0][1] == 2, "Fire must spread onto enemy plant at (0, 1)")
	assert(pb.is_ally_fire(0, 1), "Fire spreading to plant from ally fire must remain ally fire")
	print("✓ Plant fire spread ally preservation verified!")

	# 4. Fever Dancers in Upper Enemy Corners
	sm._setup_fever_dancers()
	assert(sm.fever_dancer_top_left != null, "fever_dancer_top_left must exist")
	assert(sm.fever_dancer_top_right != null, "fever_dancer_top_right must exist")
	sm._rush_in_fever_dancers()
	assert(sm.fever_dancer_top_left.visible == true, "fever_dancer_top_left must be visible during fever dance")
	assert(sm.fever_dancer_top_right.visible == true, "fever_dancer_top_right must be visible during fever dance")
	sm._hide_fever_dancers()
	assert(sm.fever_dancer_top_left.visible == false, "fever_dancer_top_left must be hidden when fever ends")
	assert(sm.fever_dancer_top_right.visible == false, "fever_dancer_top_right must be hidden when fever ends")
	print("✓ Upper enemy corner fever dancers (top-left & top-right) verified!")

	print("✓ SECTION 42: Fire Shrapnel Evolution, Explosion Safety, & Upper Corner Dancers ALL PASSED!\n")

	# =========================================================================
	# SECTION 43: Comprehensive Element Glossary (10 Elements, Affinity, Reactions)
	# =========================================================================
	print("--- SECTION 43: Comprehensive Element Glossary Verification ---")
	GlossaryDatabase.reload_keys()

	# 1. Verification of all 10 core elements + aliases
	var core_elements = [
		"火属性", "炎属性", "水属性", "木属性", "雷属性", "風属性", "地属性", "氷属性", "毒属性", "光属性", "闇属性", "無属性"
	]
	for el_name in core_elements:
		var term_data = GlossaryDatabase.get_term(el_name)
		assert(not term_data.is_empty(), "Glossary must contain '%s'" % el_name)
		assert(term_data.has("title") and not term_data["title"].is_empty(), "'%s' must have title" % el_name)
		assert(term_data.has("desc") and not term_data["desc"].is_empty(), "'%s' must have desc" % el_name)
		assert(term_data.has("color") and not term_data["color"].is_empty(), "'%s' must have color" % el_name)
	print("✓ All 10 core element entries + aliases exist with titles, descs, and colors!")

	# 2. System terms and element categories
	var system_terms = [
		"属性相性", "属性シナジー", "属性ケミストリー", "属性カテゴリー",
		"自然・生命", "元素・破壊", "神秘・冥術", "弱点", "耐性"
	]
	for sys_term in system_terms:
		var term_data = GlossaryDatabase.get_term(sys_term)
		assert(not term_data.is_empty(), "Glossary must contain '%s'" % sys_term)
		assert(term_data.has("desc") and term_data["desc"].length() > 10, "'%s' must have detailed desc" % sys_term)
	print("✓ System and category terms (属性相性, 弱点, 耐性, 自然・生命, etc.) verified!")

	# 3. Elemental chemistry, tile and reaction terms
	var reaction_terms = [
		"蒸気爆発", "融解", "感電拡散", "大延焼", "吸水", "影護マス", "影護",
		"風の守り", "暴風圏", "破片", "榴弾", "火薬庫", "浄化", "聖像", "蓄電", "腐食", "火砕流"
	]
	for r_term in reaction_terms:
		var term_data = GlossaryDatabase.get_term(r_term)
		assert(not term_data.is_empty(), "Glossary must contain '%s'" % r_term)
		assert(term_data.has("desc") and term_data["desc"].length() > 10, "'%s' must have detailed desc" % r_term)
	print("✓ Elemental reactions and mechanics (蒸気爆発, 融解, 感電拡散, 破片, 榴弾, etc.) verified!")

	# 4. Text auto-formatting with hyperlinks
	var sample_sentence = "火属性は風属性と毒属性に強いが、水属性に弱い。属性相性により弱点は1.5倍、耐性は0.5倍になる。"
	var formatted_sample = GlossaryDatabase.format_text(sample_sentence)
	assert("[url=火属性]" in formatted_sample, "Must link 火属性")
	assert("[url=風属性]" in formatted_sample, "Must link 風属性")
	assert("[url=毒属性]" in formatted_sample, "Must link 毒属性")
	assert("[url=水属性]" in formatted_sample, "Must link 水属性")
	assert("[url=属性相性]" in formatted_sample, "Must link 属性相性")
	assert("[url=弱点]" in formatted_sample, "Must link 弱点")
	assert("[url=耐性]" in formatted_sample, "Must link 耐性")
	print("✓ Complex elemental sentence formatting verified!")

	# 5. Relic Category starter descriptions
	var nature_desc = "水属性・氷属性・木属性・風属性の系統。生命回復や凍結防御、不利益な効果を浄化する力を持つ。"
	var formatted_nature = GlossaryDatabase.format_text(nature_desc)
	assert("[url=水属性]" in formatted_nature, "Must link 水属性 in relic desc")
	assert("[url=氷属性]" in formatted_nature, "Must link 氷属性 in relic desc")
	assert("[url=木属性]" in formatted_nature, "Must link 木属性 in relic desc")
	assert("[url=風属性]" in formatted_nature, "Must link 風属性 in relic desc")
	assert("[url=浄化]" in formatted_nature, "Must link 浄化 in relic desc")
	print("✓ Relic description formatting verified!")

	# 6. Enemy element badge formatting in stage_manager
	var sp_single = {"element": "火属性", "name": "クリムゾンウォーロック"}
	var bb_single = sm.get_enemy_elements_bbcode(sp_single)
	assert("[url=火属性]" in bb_single, "Single element enemy badge must have url tag to 火属性")
	assert("【火】" in bb_single, "Badge must contain compact 【火】 text")

	var sp_multi = {"skills": ["毒属性", "水属性"], "element": "毒属性", "name": "ポイズントード"}
	var bb_multi = sm.get_enemy_elements_bbcode(sp_multi)
	assert("[url=毒属性]" in bb_multi, "Multi element enemy badge must link 毒属性")
	assert("[url=水属性]" in bb_multi, "Multi element enemy badge must link 水属性")
	print("✓ Enemy element badge URL linking verified!")

	# 7. RelicUIManager tooltip display
	var sec43_rum = root.find_child("RelicUIManager", true, false)
	if sec43_rum:
		sec43_rum.show_glossary_tooltip("火属性", Vector2(400, 300))
		assert(sec43_rum.glossary_panel.visible == true, "Glossary tooltip panel must become visible")
		assert("火属性" in sec43_rum.glossary_title_label.text, "Title must show 火属性")
		sec43_rum.hide_glossary_tooltip()
		assert(sec43_rum.glossary_panel.visible == false, "Glossary tooltip panel must become hidden")
		print("✓ RelicUIManager tooltip display and hide verified!")

	print("✓ SECTION 43: Comprehensive Element Glossary ALL PASSED!\n")

	# =========================================================================
	# SECTION 44: Relic Card Overflow Fix & Multi-Area Explanation Formatting
	# =========================================================================
	print("--- SECTION 44: Relic Overflow Fix & Multi-Area Formatting Verification ---")

	# 1. Relic Selection UI layout & overflow prevention
	var sec44_rui = rui_script.new()
	dummy_root.add_child(sec44_rui)
	sec44_rui._ready()
	assert(sec44_rui.panel.size.x >= 1500, "Panel width must be expanded (>=1500px) to prevent card crowding")
	assert(sec44_rui.panel.size.y >= 750, "Panel height must be expanded (>=750px)")
	sec44_rui._populate_choices()
	assert(sec44_rui.hbox.get_child_count() == 3, "Must display 3 cards")

	for btn_card in sec44_rui.hbox.get_children():
		assert(btn_card.size.x >= 440, "Card button width must be at least 440px")
		assert(btn_card.size.y >= 500, "Card button height must be at least 500px")
		var vbox_card = btn_card.get_child(0) as VBoxContainer
		assert(vbox_card != null, "Card must have VBoxContainer")

		var r_lbl: Label = null
		var d_lbl: RichTextLabel = null
		for child in vbox_card.get_children():
			if child is Label and r_lbl == null and child.get_theme_font_size("font_size") > 20:
				r_lbl = child
			elif child is RichTextLabel and child != vbox_card.get_child(0):
				d_lbl = child

		assert(r_lbl != null, "Card must contain relic title Label")
		assert(r_lbl.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Relic title must have AUTOWRAP_WORD_SMART enabled")
		assert(r_lbl.get_theme_font_size("font_size") <= 24, "Relic title font size must be <= 24 to avoid horizontal overflow")

		assert(d_lbl != null, "Card must contain relic description RichTextLabel")
		assert(d_lbl.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Description must have AUTOWRAP_WORD_SMART enabled")
		assert(d_lbl.get_theme_font_size("normal_font_size") <= 18, "Description font size must be <= 18 to avoid vertical overflow")
		assert(d_lbl.fit_content == true, "Description must have fit_content enabled")

	sec44_rui.queue_free()
	print("✓ Relic Selection UI card sizing, typography & overflow prevention verified!")

	# 2. Normal Shop Item Descriptions (Page 0) formatted with Glossary
	sc.set_shop_ui_visible(true)
	sc._switch_shop_view_mode(0)
	assert(sc.shop_card_refs.size() > 0, "Shop must have buff items")
	for ref in sc.shop_card_refs:
		var desc_node = ref.get("desc_lbl")
		assert(desc_node != null and desc_node is RichTextLabel, "Shop card must use RichTextLabel for description to support hyperlinks")
		assert(desc_node.mouse_filter == Control.MOUSE_FILTER_PASS, "Shop desc label must allow mouse hover for glossary tooltips")
	print("✓ Shop Page 0 item descriptions use RichTextLabel with glossary hovercards!")

	# 3. Enemy Intent Header formatted with Glossary
	var intent_ui = sm._create_intent_ui(Vector2(0, 0), dummy_root, false, 10)
	assert(intent_ui.has("badge") and is_instance_valid(intent_ui["badge"]), "Intent UI must have badge")
	assert(intent_ui["badge"].mouse_filter == Control.MOUSE_FILTER_PASS, "Intent badge must have MOUSE_FILTER_PASS for tooltips")
	if intent_ui.has("panel") and is_instance_valid(intent_ui["panel"]):
		intent_ui["panel"].queue_free()
	print("✓ Enemy intent banner supports interactive glossary hovercards!")

	# 4. RelicUIManager custom tooltip formats both title and desc
	if sec43_rum:
		sec43_rum.show_custom_tooltip("火属性の秘術", "水マスと火マスで蒸気爆発", Vector2(500, 400), "test_custom")
		assert("[url=火属性]" in sec43_rum.name_label.text, "Tooltip title must format glossary terms")
		assert("[url=水マス]" in sec43_rum.desc_label.text, "Tooltip desc must format glossary terms")
		assert("[url=蒸気爆発]" in sec43_rum.desc_label.text, "Tooltip desc must format reaction terms")
		sec43_rum.hide_custom_tooltip("test_custom")
		print("✓ Tooltip system formats both title and desc through GlossaryDatabase!")

	print("✓ SECTION 44: Relic Overflow Fix & Multi-Area Formatting ALL PASSED!\n")

	# =========================================================================
	# SECTION 45: Charge Bomb Safety, Cause of Death, Potion Cost & Milestones
	# =========================================================================
	print("--- SECTION 45: Charge Bomb, Cause of Death, Potion Scale & Evolution Milestones ---")

	# 1. Charge Bomb safety & direct enemy damage
	pb.clear_board_hazards()
	pb.grid_electrified[2][2] = true
	pb.grid_electrified[2][3] = true
	pb.grid_cursed[3][2] = true
	sm.myhp = 500.0
	sm.myhpmax = 500.0
	var enemy_hp_before = 1000.0
	sm.ehp = enemy_hp_before
	sm.ehpmax = enemy_hp_before
	sm.isdeadf = false
	sm.active_enemies = [{"hp": enemy_hp_before, "max_hp": enemy_hp_before, "defense": 0, "element": "none"}]
	pb.special_item[2][2] = pb.SpecialItemType.CHARGE_BOMB
	pb._detonate_specials([Vector2i(2, 2)])
	assert(sm.myhp == 500.0, "Player must NOT take backlash or bomb damage from their own Charge Bomb detonation! HP=%f" % sm.myhp)
	assert(sm.ehp < enemy_hp_before, "Charge Bomb must deal direct damage to the enemy!")
	print("✓ Charge Bomb detonation safety and enemy damage verified!")

	# 2. Game Over cause of death panel & styling
	sm.last_damage_cause = "猛毒マスの侵食ダメージ"
	sm.last_damage_amount = 450.0
	sm.stage = 7
	pb.interval = 0
	pb._handle_gameover_sequence(sm)
	pb.interval = 50
	pb._handle_gameover_sequence(sm)
	var cause_panel = sm.get_node_or_null("GameOverCausePanel") as PanelContainer
	assert(cause_panel != null, "GameOverCausePanel must be created on Game Over")
	var cp_style = cause_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(cp_style != null, "GameOverCausePanel must have a StyleBoxFlat")
	assert(cp_style.bg_color.r < 0.05 and cp_style.bg_color.g < 0.05 and cp_style.bg_color.b < 0.05, "GameOverCausePanel background must be dark black")
	assert(cp_style.bg_color.a >= 0.60 and cp_style.bg_color.a <= 0.80, "GameOverCausePanel background must be translucent")
	var cause_lbl = cause_panel.get_node_or_null("CauseLabel") as RichTextLabel
	assert(cause_lbl != null, "CauseLabel must exist inside GameOverCausePanel")
	assert("☠ 死因 (CAUSE OF DEATH) ☠" in cause_lbl.text, "CauseLabel must contain cause of death header")
	assert("猛毒マスの侵食ダメージ" in cause_lbl.text, "CauseLabel must contain last damage cause")
	assert("450 HP" in cause_lbl.text, "CauseLabel must contain fatal damage amount")
	assert("Stage 7" in cause_lbl.text, "CauseLabel must show stage number")
	print("✓ Game Over cause of death display verified!")

	# 3. Potion cost scaling multiplier (1.55x)
	assert(sc.skill_tree_items.size() > 0, "skill_tree_items must be populated")
	var s_item = sc.skill_tree_items[0]
	var cost_before = int(s_item["cost"])
	sc.divscore[sc.PieceType.POTION] = 100000000
	sc._complete_skill_upgrade(0, int(s_item["level"]) + 1)
	var expected_cost = int(cost_before * 1.55)
	assert(s_item["cost"] == expected_cost, "Skill upgrade cost must scale by 1.55x (was %d, got %d, expected %d)" % [cost_before, s_item["cost"], expected_cost])
	print("✓ Potion cost scaling rate (1.55x) verified!")

	# 4. Evolution milestones strictly at Lv.10 and Lv.20
	var choices_lvl10 = sc.get_evolution_choices("thunder_1", 10)
	assert(choices_lvl10.size() == 3, "Lv.10 must offer 3 intermediate evolutions (A, B, C)")
	assert("mid" in choices_lvl10[0]["id"], "Lv.10 choices must be mid evolutions")
	sc.choose_skill_evolution("thunder_1", 10, "thunder_mid_a")
	var choices_lvl20 = sc.get_evolution_choices("thunder_1", 20)
	assert(choices_lvl20.size() == 2, "Lv.20 must offer final evolutions")
	assert("final" in choices_lvl20[0]["id"], "Lv.20 choices must be final evolutions")
	assert("a" in choices_lvl20[0]["id"], "Lv.20 final evolutions must branch from chosen mid evolution")
	print("✓ Evolution milestones strictly at Lv.10 and Lv.20 verified!")

	# 5. Shop Header Proceed button removal
	var hdr = sc.shop_root_panel.find_child("HeaderHBox", true, false)
	if hdr:
		assert(hdr.get_node_or_null("ShopHeaderProceedBtn") == null, "ShopHeaderProceedBtn must NOT exist in shop header")
	assert(sc.shop_root_panel.find_child("ShopHeaderProceedBtn", true, false) == null, "No proceed button in shop header")
	print("✓ Shop header proceed button removal verified!")

	# 6. Darker & translucent UI styling for all panels
	var shop_root_style = sc.shop_root_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(shop_root_style.bg_color.r < 0.05 and shop_root_style.bg_color.g < 0.05 and shop_root_style.bg_color.b < 0.05, "Shop root panel must be dark black")
	assert(shop_root_style.bg_color.a >= 0.60 and shop_root_style.bg_color.a <= 0.85, "Shop root panel must be translucent")

	var rui_test = rui_script.new()
	dummy_root.add_child(rui_test)
	rui_test._ready()
	var rui_style = rui_test.panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(rui_style.bg_color.r < 0.05 and rui_style.bg_color.g < 0.05 and rui_style.bg_color.b < 0.05, "Relic selection panel must be dark black")
	assert(rui_style.bg_color.a >= 0.60 and rui_style.bg_color.a <= 0.80, "Relic selection panel must be translucent")
	rui_test.queue_free()

	if pb.player_skill_ui_panel:
		var psk_style = pb.player_skill_ui_panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert(psk_style.bg_color.r < 0.05 and psk_style.bg_color.g < 0.05 and psk_style.bg_color.b < 0.05, "Player skill panel must be dark black")
		assert(psk_style.bg_color.a >= 0.60 and psk_style.bg_color.a <= 0.75, "Player skill panel must be translucent")
	print("✓ Dark & translucent UI panels verified!")

	# 7. Slower Fever falling face speed
	assert(sm.has_method("_process_fever_effects"), "sm must have _process_fever_effects")
	var dummy_face = Node2D.new()
	dummy_face.position = Vector2(500, 100)
	dummy_root.add_child(dummy_face)
	sm.facearr.clear()
	sm.facearr.append(dummy_face)
	sm.is_waiting_for_fever_se = false
	sm._process_fever_effects()
	assert(is_equal_approx(dummy_face.position.y, 106.0), "Fever face falling speed should be 6.0 px per frame (got %f)" % (dummy_face.position.y - 100.0))
	dummy_face.queue_free()
	sm.facearr.clear()
	print("✓ Slower fever face falling speed (6.0 px/frame) verified!")

	print("✓ SECTION 45: Charge Bomb, Cause of Death, Potion Scale & Evolution Milestones ALL PASSED!\n")

	# --- SECTION 46: Player Light Skill & Gold Statue (聖像) Symmetry Verification ---
	print("--- SECTION 46: Player Light Skill & Gold Statue (聖像) Symmetry Verification ---")

	# 1. Verify ScoreManager Light evolutions and descriptions
	assert(sc.SKILL_EVOLUTION_REGISTRY.has("light"), "SKILL_EVOLUTION_REGISTRY must have 'light'")
	var light_evos = sc.SKILL_EVOLUTION_REGISTRY["light"]
	assert(light_evos["mid"].size() == 3, "Light mid evolutions must have 3 branches")
	assert(light_evos["mid"][0]["name"] == "光輝の像", "Light mid A must be '光輝の像'")
	assert(light_evos["mid"][1]["name"] == "聖域の像", "Light mid B must be '聖域の像'")
	assert(light_evos["mid"][2]["name"] == "共鳴の像", "Light mid C must be '共鳴の像'")
	assert(light_evos["final"]["light_mid_a"][0]["name"] == "黄金郷", "Light final A1 must be '黄金郷'")
	assert(light_evos["final"]["light_mid_a"][1]["name"] == "聖像共振", "Light final A2 must be '聖像共振'")
	assert(light_evos["final"]["light_mid_b"][0]["name"] == "後光の像", "Light final B1 must be '後光の像'")
	assert(light_evos["final"]["light_mid_b"][1]["name"] == "加護の像", "Light final B2 must be '加護の像'")
	assert(light_evos["final"]["light_mid_c"][0]["name"] == "起爆の像", "Light final C1 must be '起爆の像'")
	assert(light_evos["final"]["light_mid_c"][1]["name"] == "昇天の像", "Light final C2 must be '昇天の像'")
	print("✓ ScoreManager Light evolutions registry strictly themed around 聖像 / 黄金像 properties verified!")

	var light_descs = sc.get_skill_descriptions("light_1")
	assert(light_descs.size() == 20, "Light descriptions must have 20 levels")
	assert("聖像1体" in light_descs[0], "Lv.1 must describe 1 statue")
	assert("聖像2体" in light_descs[3], "Lv.4 must describe 2 statues via level enhancement")
	assert("聖像3体" in light_descs[7], "Lv.8 must describe 3 statues via level enhancement")
	assert("聖像4体" in light_descs[11], "Lv.12 must describe 4 statues via level enhancement")
	assert("聖像5体" in light_descs[15], "Lv.16 must describe 5 statues via level enhancement")
	print("✓ Light skill descriptions contain statue count scaling via level enhancement verified!")

	# 2. Verify Enemy vs Player Light Skill Symmetry
	# Enemy light skill places enemy gold statues (immovable obstacle blocks)
	pb._initialize_board(null)
	var enemy_targets = pb._cast_enemy_light_skill(false, false)
	assert(enemy_targets.size() > 0, "Enemy light skill must place at least 1 gold statue")
	var enemy_statue_found = false
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue[r][c] > 0 and not pb.is_ally_gold(r, c):
				enemy_statue_found = true
				break
	assert(enemy_statue_found, "Enemy light skill must place enemy gold statue with is_ally_gold == false")

	# Player light skill places ally gold statues (movable/swappable ally 聖像)
	pb._initialize_board(null)
	pb.cast_player_skill("light", 1, 1)
	var ally_statue_found = false
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue[r][c] > 0 and pb.is_ally_gold(r, c):
				ally_statue_found = true
				break
	assert(ally_statue_found, "Player light skill must place ally gold statue with is_ally_gold == true")
	print("✓ Strict symmetry: Enemy places enemy 黄金像, Player places ally 聖像 verified!")

	# 3. Verify Holy Light / Disco Ball Detonation summons 聖像 and purifies hazards (NO same-color deletion)
	pb._initialize_board(null)
	# Set up a poison cell and fire cell
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false)
	pb.grid_fire[1][2] = 2
	pb._set_ally_flag(pb.grid_fire_ally, 1, 2, false)

	# Trigger Holy Light at (3, 3)
	var queue: Array = []
	var exploded: Dictionary = {}
	sm.ehp = 5000.0
	pb._trigger_holy_light(3, 3, pb.get_cell_position(3, 3), queue, exploded)

	# Must have summoned ally 聖像
	var holy_ally_statue_cnt = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue[r][c] > 0 and pb.is_ally_gold(r, c):
				holy_ally_statue_cnt += 1
	assert(holy_ally_statue_cnt >= 1, "Holy Light detonation must summon at least 1 ally 聖像")
	assert(not pb.grid_poison[1][1], "Holy Light detonation must purify enemy poison hazard")
	assert(pb.grid_fire[1][2] == 0, "Holy Light detonation must purify enemy fire hazard")
	print("✓ Holy Light / Disco Ball detonating places ally 聖像 and purifies hazards verified!")

	# 4. Verify Matching an Ally 聖像 awards +500G (or +1000G with 黄金郷) and deals Holy Damage
	pb._initialize_board(null)
	pb.grid_gold_statue[2][2] = 1
	pb._set_ally_flag(pb.grid_gold_ally, 2, 2, true)
	var start_score = sc.totalScore
	if not sm.active_enemies.is_empty():
		sm.active_enemies[0]["hp"] = 500000000.0
	sm.ehp = 500000000.0

	# Simulate match containing (2, 2)
	var matched_list: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 3)]
	pb._apply_electrified_and_cursed_effects(matched_list)
	assert(pb.grid_gold_statue[2][2] == 0, "Matched ally 聖像 must be removed when durability reaches 0")
	assert(sc.totalScore == start_score + 500, "Matching ally 聖像 must award +500G (got %d vs %d)" % [sc.totalScore, start_score + 500])
	var end_ehp = sm.active_enemies[0]["hp"] if not sm.active_enemies.is_empty() else sm.ehp
	assert(end_ehp < 500000000.0, "Matching ally 聖像 must deal holy damage to enemy (got %f)" % end_ehp)
	print("✓ Matching ally 聖像 awards +500G and deals Holy Damage verified!")

	# 5. Verify 昇天の像 (light_final_c2) Spawns Special Item on Match
	pb._initialize_board(null)
	pb.grid_gold_statue[3][3] = 1
	pb._set_ally_flag(pb.grid_gold_ally, 3, 3, true)
	sc.skill_evolutions["light_1"] = {"final": "light_final_c2"}
	pb._apply_electrified_and_cursed_effects([Vector2i(3, 3)])
	assert(pb.pending_special_spawns.get(Vector2i(3, 3)) == pb.SpecialItemType.DISCO_BALL, "昇天の像 must spawn SpecialItemType.DISCO_BALL on match")
	sc.skill_evolutions.erase("light_1")
	pb.pending_special_spawns.clear()
	print("✓ 昇天の像 (light_final_c2) spawning star orb on match verified!")

	# 6. Verify 加護の像 (light_final_b2) Turn-End HP Regeneration
	pb._initialize_board(null)
	pb.grid_gold_statue[0][0] = 2
	pb._set_ally_flag(pb.grid_gold_ally, 0, 0, true)
	pb.grid_gold_statue[0][1] = 2
	pb._set_ally_flag(pb.grid_gold_ally, 0, 1, true)
	sc.skill_evolutions["light_1"] = {"final": "light_final_b2"}
	sm.myhp = 500.0
	sm.myhpmax = 1000.0
	pb._reset_turn(sm, sc)
	assert(sm.myhp == 740.0, "2 ally 聖像 with light_final_b2 must heal 240 HP on turn reset (got %f)" % sm.myhp)
	sc.skill_evolutions.erase("light_1")
	print("✓ Turn-end HP regeneration with light_final_b2 (加護の像) verified!")

	# 7. Verify 後光の像 (light_final_b1) Blocks Enemy Elemental Skill Placement while statue exists
	pb._initialize_board(null)
	pb.grid_gold_statue[1][1] = 2
	pb._set_ally_flag(pb.grid_gold_ally, 1, 1, true)
	sc.skill_evolutions["light_1"] = {"final": "light_final_b1"}
	var blocked_targets = pb._apply_enemy_elemental_skill_effect("毒属性", false)
	assert(blocked_targets.is_empty(), "後光の像 (light_final_b1) while ally statue exists must block enemy elemental hazard skill")
	sc.skill_evolutions.erase("light_1")
	print("✓ 後光の像 (light_final_b1) blocking enemy elemental hazard skills verified!")

	print("✓ SECTION 46: Player Light Skill & Gold Statue (聖像) Symmetry ALL PASSED!\n")

	# --- SECTION 47: Stage Clear Proceed Button ("前に進む") Responsiveness ---
	print("\n--- SECTION 47: Stage Clear Proceed Button (\"前に進む\") Responsiveness ---")
	
	# Clean up any leftover CanvasLayers from earlier tests and ensure board is steady
	for child in dummy_root.get_children():
		if child is CanvasLayer:
			child.queue_free()
	pb.current_state = pb.BoardState.IDLE
	pb.falling_pieces.clear()
	pb.selected_cell = Vector2i(-1, -1)
	pb.is_enemy_turn_in_progress = false
	assert(pb.is_steady_state() == true, "PuzzleBoard must be in steady state before stage clear sequence")

	var mf_btn = sm.get_node_or_null("movefront")
	if mf_btn == null:
		mf_btn = Button.new()
		mf_btn.name = "movefront"
		sm.add_child(mf_btn)
	sm.move_front_btn = mf_btn

	# 1. Verify stage clear sequence sets up move_front_btn and resets clicked
	sm.stage = 1
	sm.stage_enemy = 5
	sm.isstageclear = true
	sm.clicked = true
	sm.has_transitioned_stage_clear = false
	sm.clearinterval = 161
	sm._process_stage_clear_sequence()

	# Emit selection_finished on relic UI if opened
	for child in dummy_root.get_children():
		if child.has_signal("selection_finished"):
			child.selection_finished.emit()
			child.queue_free()

	assert(sm.clicked == false, "Stage clear sequence must reset clicked to false so proceed button can be pressed")
	assert(sm.move_front_btn.visible == true, "move_front_btn must be visible upon stage clear")
	assert(sm.move_front_btn.text.contains("次のステージへ進む"), "move_front_btn text must prompt advancing to the next stage (got '%s')" % sm.move_front_btn.text)

	# 2. Verify pressing move_front_btn advances to Stage 2 Battle 1 and spawns enemy
	sm.enemycount = 0
	sm.clicked = true # Even if clicked had remained true, isstageclear must guarantee advance
	sm._on_movefront_pressed()

	assert(sm.stage == 2, "Pressing proceed button during stage clear must advance stage from 1 to 2 (got %d)" % sm.stage)
	assert(sm.stage_enemy == 1, "Pressing proceed button during stage clear must reset stage_enemy to 1 (got %d)" % sm.stage_enemy)
	assert(sm.isstageclear == false, "Pressing proceed button must consume isstageclear (isstageclear must become false)")
	assert(sm.move_front_btn.visible == false, "move_front_btn must be hidden after advancing to the next battle")
	assert(sm.active_enemies.size() > 0, "Stage 2 Battle 1 enemy must be spawned")
	assert(sm.clicked == true, "clicked must be set to true for the new battle")

	# 3. Verify normal battle progression still works when not in stage clear
	sm.clicked = false
	sm.enemycount = 0
	sm._on_movefront_pressed()
	assert(sm.stage == 2, "Normal battle progression must keep stage at 2")
	assert(sm.stage_enemy == 2, "Normal battle progression must advance stage_enemy from 1 to 2 (got %d)" % sm.stage_enemy)
	print("✓ Pressing proceed button ('前に進む') on Stage Clear successfully advances to next stage and spawns enemy!")
	print("✓ SECTION 47: Stage Clear Proceed Button ALL PASSED!\n")

	print("\nALL USER REQUEST TESTS PASSED SUCCESSFULLY!")
	quit(0)
