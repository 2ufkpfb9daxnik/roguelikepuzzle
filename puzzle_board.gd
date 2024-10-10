extends Node2D
# Called when the node enters the scene tree for the first time.
var grid_column
var grid_row
var dx = 4000
var dy = 1000
var piece = []
var grid_n = []
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
		var arr = []
		for j in range(grid_row):
			var canset = []
			for k in range(5):
				canset.append(true)
			if(i>=2):
				if(grid_n[i-1][j]==grid_n[i-2][j]):
					canset[grid_n[i-1][j]] = false
			if(j>=2):
				if(arr[j-1]==arr[j-2]):
					canset[arr[j-1]] = false
			var rng = []
			for k in range(5):
				if(canset[k]):
					rng.append(k)
			var nval = rng[randi() % rng.size()]
			arr.append(nval)
			var adc = valid_children[nval].duplicate();
			adc.position = Vector2(i*500+500+dx,j*500+500+dy)
			piece.append(adc)
			add_child(adc)
		grid_n.append(arr)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass
