extends Button

func _on_pressed() -> void:
	var next_scene = load("res://current_stage.tscn")
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
