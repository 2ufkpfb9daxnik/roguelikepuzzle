extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_pressed() -> void:
	print("pressed")
	var next_scene = load("res://current_stage.tscn")
	get_tree().change_scene_to_packed(next_scene)
	pass # Replace with function body.
