extends Node2D

func _ready() -> void:
	var new_scene = load("res://title_screen.tscn")
	if new_scene:
		get_tree().change_scene_to_packed(new_scene)
