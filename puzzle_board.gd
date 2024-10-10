extends Node2D
# Called when the node enters the scene tree for the first time.
var grid_column
var grid_row
var dx = 4000
var dy = 1000
var piece = []
var grid_n = []
var piececollid = []
var grid_i = []
var cellsize
var isclick = false
var clickedpositionx = -1e9
var clickedpositiony = -1e9
func _ready() -> void:
	grid_column = 10
	grid_row = 15
	var collid
	var children = get_children()
	var valid_children = []
	for child in children:
		if child is Sprite2D:
			child.position.x = -1000000
			valid_children.append(child)
		if child is Area2D:
			for nxtchild in child.get_children():
				collid = nxtchild
	for i in range(grid_row):
		var arr = []
		var arr1 = []
		for j in range(grid_column):
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
			arr1.append(i*grid_column+j)
			var adc = valid_children[nval].duplicate();
			adc.position = Vector2(i*500+500+dx,j*500+500+dy)
			var nxtcollid = collid.duplicate();
			nxtcollid.position = Vector2(i*500+500+dx,j*500+500+dy)
			cellsize = adc.scale
			piece.append(adc)
			piececollid.append(nxtcollid)
			add_child(adc)
			for child in children:
				if child is Area2D:
					child.add_child(nxtcollid)
		grid_n.append(arr)
		grid_i.append(arr1)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_position = get_global_mouse_position()
				var i = (mouse_position.x-(430))/50
				var j = (mouse_position.y-(130))/50
				print("(%d, %d)" % [i, j])
				print("(%d, %d)" % [mouse_position.x, mouse_position.y])
				if(i<grid_row&&i>=0&&j<grid_column&&j>=0):
					piece[grid_i[i][j]].scale *= 2 
					clickedpositionx = int(i)
					clickedpositiony = int(j)
				isclick = true
			else:
				isclick = false
	pass # Replace with function body.
func abs(x: int) -> int:
	if(x<0):
		x*=-1
	return x
func _process(delta: float) -> void:
	var mouse_position = get_global_mouse_position()
	var i = int((mouse_position.x-(430))/50)
	var j = int((mouse_position.y-(130))/50)
	if(int(abs(i-clickedpositionx)+abs(j-clickedpositiony))>1) and clickedpositionx!=-1e9:
		isclick = false
	if(!isclick):
		for k in range(piece.size()):
			piece[k].scale = cellsize
	pass
