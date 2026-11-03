extends Node2D

func _ready() -> void:
	# タイトル表示中に次ステージを先読みし、START押下時の同期ロードによるフリーズを防ぐ
	ResourceLoader.load_threaded_request("res://current_stage.tscn")
	var new_scene = load("res://title_screen.tscn")
	if new_scene:
		get_tree().change_scene_to_packed(new_scene)
