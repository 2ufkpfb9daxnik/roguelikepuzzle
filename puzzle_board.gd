extends Node2D
# Called when the node enters the scene tree for the first time.
var dx = 6500
var dy = 1000
var piece = []
func _ready() -> void:
	var children = get_children()
	var valid_children = []
	for child in children:
		if child is Sprite2D:
			child.position.x = -1000000
			valid_children.append(child)
	for i in range(10):
		for j in range(10):
			var adc = valid_children[randi() % valid_children.size()].duplicate();
			adc.position = Vector2(i*1000+500+dx,j*1000+500+dy)
			piece.append(adc)
			add_child(adc)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass
