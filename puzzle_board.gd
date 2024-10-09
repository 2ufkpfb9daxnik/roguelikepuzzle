extends Node2D
# Called when the node enters the scene tree for the first time.
var grid_column
var grid_row
var dx = 4000
var dy = 1000
var piece = []
func _ready() -> void:
	grid_column = 20
	grid_row = 15
	var children = get_children()
	var valid_children = []
	for child in children:
		if child is Sprite2D:
			child.position.x = -1000000
			valid_children.append(child)
	for i in range(grid_column):
		for j in range(grid_row):
			var adc = valid_children[randi() % valid_children.size()].duplicate();
			adc.position = Vector2(i*500+500+dx,j*500+500+dy)
			piece.append(adc)
			add_child(adc)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass
