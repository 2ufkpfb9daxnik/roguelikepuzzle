extends SceneTree

func _init() -> void:
	print("=== Verification Start: Summon Smoke, Viewport Bounds & Minion Turn Action Rule ===")
	var root = get_root()

	# 1. Setup StageManager
	var StageManagerScript = load("res://stage_manager.gd")
	var sm = Node2D.new()
	sm.set_script(StageManagerScript)
	root.add_child(sm)
	sm._ready()

	# Add base kemuri node
	var base_kemuri = AnimatedSprite2D.new()
	base_kemuri.name = "kemuri"
	var sf = SpriteFrames.new()
	sf.add_animation("new_animation")
	# dummy texture
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	sf.add_frame("new_animation", tex)
	base_kemuri.sprite_frames = sf
	base_kemuri.position = Vector2(-1e9, -1e9)
	base_kemuri.visible = false
	root.add_child(base_kemuri)

	sm._setup_enemy_viewport_container()

	# Verify base kemuri is reparented to _enemy_zoom_root
	assert(sm._enemy_zoom_root != null, "_enemy_zoom_root must be initialized")
	assert(sm._enemy_viewport_clip != null, "_enemy_viewport_clip must be initialized")
	assert(sm._enemy_viewport_clip.clip_contents == true, "Enemy viewport must have clip_contents = true")
	
	# Verify enemy viewport bounds: (1194, 13, 717, 394)
	assert(sm._enemy_viewport_clip.position == Vector2(1194, 13), "Viewport clip position must be (1194, 13)")
	assert(sm._enemy_viewport_clip.size == Vector2(717, 394), "Viewport clip size must be (717, 394)")

	# 2. Test Summon Smoke Scaling & Clipping
	sm._play_summon_smoke(1310.0, 240.0)
	var smoke_found: AnimatedSprite2D = null
	for child in sm._enemy_zoom_root.get_children():
		if child is AnimatedSprite2D and child.name.begins_with("SummonSmoke_"):
			smoke_found = child
			break
	assert(smoke_found != null, "Summon smoke must be spawned under _enemy_zoom_root")
	assert(smoke_found.scale.x <= 0.30 and smoke_found.scale.y <= 0.30, "Summon smoke scale must be compact (got %s), fitting within enemy area" % str(smoke_found.scale))
	assert(smoke_found.visible == true, "Summon smoke must be initially visible")
	print("[PASS] Smoke scale (%s) and placement inside clipped enemy viewport verified." % str(smoke_found.scale))

	# 3. Test Summoning Minion in Stage 5
	sm.stage = 5
	sm.stage_enemy = 5
	sm.is_current_boss = true
	var dummy_boss_spr = Sprite2D.new()
	dummy_boss_spr.position = Vector2(1550, 250)
	sm._enemy_zoom_root.add_child(dummy_boss_spr)
	var boss_e = {
		"key": "enemy18", "name": "冥王デモニアス", "sprite": dummy_boss_spr,
		"hp": 500000.0, "max_hp": 500000.0, "atk": 4000.0, "just_summoned": false
	}
	sm.active_enemies = [boss_e]
	sm.enemy = dummy_boss_spr

	# Setup PuzzleBoard
	var PuzzleBoardScript = load("res://puzzle_board.gd")
	var pb = Node2D.new()
	pb.set_script(PuzzleBoardScript)
	root.add_child(pb)

	# Boss summons a minion
	var minion_data = sm.summon_boss_minion()
	assert(not minion_data.is_empty(), "Boss must successfully summon a minion")
	assert(sm.active_enemies.size() == 2, "Active enemies must now be 2")
	var summoned_minion = sm.active_enemies[1]
	assert(summoned_minion.get("just_summoned", false) == true, "Summoned minion must have just_summoned flag == true")
	print("[PASS] Minion summoned with just_summoned == true.")

	# 4. Verify that summoned monster CANNOT act on the turn it is summoned
	pb._decide_enemy_actions(sm)
	assert(pb._enemy_turn_actions.size() == 2, "5th Boss should have 2 actions, minion must have 0 actions on summon turn")
	for act in pb._enemy_turn_actions:
		assert(act.get("enemy_index") == 0, "All actions on summon turn must belong to the Boss (enemy_index 0)")
		assert(act.get("enemy_data") == boss_e, "Actions must belong to the Boss data")
	print("[PASS] Verified that newly summoned monster does NOT act on the turn it is summoned.")

	# 5. Verify that minion CAN act on the following turn
	# End of turn simulation
	for e in sm.active_enemies:
		e["just_summoned"] = false
	pb._decide_enemy_actions(sm)
	var actions_index_0 = pb._enemy_turn_actions.filter(func(a): return a.get("enemy_index") == 0)
	var actions_index_1 = pb._enemy_turn_actions.filter(func(a): return a.get("enemy_index") == 1)
	assert(actions_index_0.size() == 2, "Boss still has 2 actions")
	assert(actions_index_1.size() == 1, "Minion now has 1 action on subsequent turn")
	print("[PASS] Verified that minion acts normally on subsequent turn.")

	# 6. Test Enemy Zoom on attacking enemy
	sm.zoom_on_attacking_enemy(0, 0.0)
	assert(sm._enemy_zoom_root.scale.x > 1.0, "Enemy area must zoom when boss attacks")
	sm.reset_enemy_zoom(0.0)
	assert(sm._enemy_zoom_root.scale == Vector2.ONE, "Enemy area must reset to scale 1.0 after reset_enemy_zoom")
	print("[PASS] Enemy area zoom & reset verified.")

	print("=== ALL REQUIREMENTS VERIFIED SUCCESSFULLY! ===")
	quit(0)
