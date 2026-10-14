extends SceneTree

# 敵撃破 → レリック選択 → ショップ の流れを検証するヘッドレステスト
func _initialize() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _find_selection_ui(node: Node) -> Node:
	for c in node.get_children():
		if c.get_script() == preload("res://relic_selection_ui.gd"):
			return c
	return null

func _run() -> void:
	var scene = load("res://current_stage.tscn").instantiate()
	root.add_child(scene)
	await _wait(10)
	var sm = scene.get_node("StageManager")
	var score = sm._get_score_manager()

	# --- 1. 通常敵の撃破 ---
	sm.stage_enemy = 1
	sm.isdeadf = true
	sm.deadinterval = 95
	await _wait(30)
	var ui = _find_selection_ui(scene)
	print("[TEST] normal kill -> selection UI shown: ", ui != null)
	print("[TEST] shop hidden while selecting: ", not score.is_shop_open, " / movefront hidden: ", not sm.move_front_btn.visible)
	if ui:
		print("[TEST] panel pos: ", ui.panel.position, " size: ", ui.panel.size)
		print("[TEST] choice buttons: ", ui.hbox.get_child_count())
		ui._on_choice_pressed(ui.hbox.get_child(0).get_meta("x", "chain_ring") if false else "chain_ring")
	await _wait(3)
	print("[TEST] after choice -> shop open: ", score.is_shop_open, " / movefront visible: ", sm.move_front_btn.visible)
	var rm = scene.get_node("RelicManager")
	print("[TEST] owned relics: ", rm.get_relics())

	# --- 2. ステージクリア ---
	sm.isdeadf = false
	sm.isstageclear = true
	sm.clearinterval = 155
	score.set_shop_ui_visible(false)
	await _wait(30)
	ui = _find_selection_ui(scene)
	print("[TEST] stage clear -> selection UI shown: ", ui != null)
	if ui: ui._on_skip_pressed()
	await _wait(3)
	var next_btn = score.get_node_or_null("stagechangeb")
	print("[TEST] after skip -> shop open: ", score.is_shop_open, " / next visible: ", next_btn.visible if next_btn else "n/a")
	quit()
