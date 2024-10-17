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
var clicknum = -1e9
var clicki = -1e9
var column_empty = []
var ismatched = []
var score = 0
var time_accumulator = 0.0
var update_interval = 0.5
var isbreak = false
func _ready() -> void:
	grid_column = 15
	grid_row = 15
	var collid
	var children = get_children()
	var valid_children = []
	for i in range(grid_column):
		column_empty.append(0)
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
		var arr2 = []
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
			arr2.append(false)
			var adc = valid_children[nval].duplicate();
			adc.position = Vector2(j*500+500+dx,i*500+500+dy)
			var nxtcollid = collid.duplicate();
			nxtcollid.position = Vector2(j*500+500+dx,i*500+500+dy)
			cellsize = adc.scale
			piece.append(adc)
			piececollid.append(nxtcollid)
			add_child(adc)
			for child in children:
				if child is Area2D:
					child.add_child(nxtcollid)
		grid_n.append(arr)
		grid_i.append(arr1)
		ismatched.append(arr2)
	pass # Replace with function body.
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and !isbreak:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_position = get_global_mouse_position()
				var i = (mouse_position.y-(130))/50
				var j = (mouse_position.x-(430))/50
				print("(%d, %d)" % [i, j])
				print("(%d, %d)" % [mouse_position.x, mouse_position.y])
				if(i<grid_row&&i>=0&&j<grid_column&&j>=0):
					piece[grid_i[i][j]].scale *= 2 
					clickedpositionx = int(j)
					clickedpositiony = int(i)
				isclick = true
				clicki = grid_i[i][j]
				clicknum = grid_n[i][j]
			else:
				var mouse_position = get_global_mouse_position()
				var i = (mouse_position.y-(130))/50
				var j = (mouse_position.x-(430))/50
				if(i<grid_row&&i>=0&&j<grid_column&&j>=0) and (grid_i[i][j]!=clicknum) and (isclick):
					var swapa = grid_i[i][j]
					var swapb = clicki
					var swapna = grid_n[i][j]
					var swapnb = clicknum
					print("swap(%d,%d)" % [swapa,swapb])
					grid_i[i][j] = swapb
					grid_i[clickedpositiony][clickedpositionx] = swapa
					grid_n[i][j] = swapnb
					grid_n[clickedpositiony][clickedpositionx] = swapna;
					var swapaposition = piece[swapa].position
					var swapacollidposition = piececollid[swapa].position
					piece[swapa].position = piece[swapb].position
					piece[swapb].position = swapaposition
					piececollid[swapa].position = piececollid[swapb].position
					piececollid[swapb].position = swapacollidposition
				isclick = false
	pass # Replace with function body.
func abs(x: int) -> int:
	if(x<0):
		x*=-1
	return x
func searchmatch() -> void:
	for i in range(grid_row):
		for j in range(grid_column):
			if(ismatched[i][j]||grid_n[i][j]==-1e9):
				continue
			var ni = i
			var nj = j
			var nnum = grid_n[i][j]
			while(true):
				if(ni==grid_row):
					break
				if(grid_n[ni][j]!=nnum):
					break
				ni+=1
			if(ni-i>=3):
				for k in range(i,ni):
					ismatched[k][j] = true
			ni = i
			while(true):
				if(ni==0):
					break
				if(grid_n[ni][j]!=nnum):
					break
				ni-=1
			if(i-ni>=3):
				for k in range(ni,i):
					ismatched[k][j] = true
			while(true):
				if(nj==grid_column):
					break
				if(grid_n[i][nj]!=nnum):
					break
				nj+=1
			if(nj-j>=3):
				for k in range(j,nj):
					ismatched[i][k] = true
			nj = j
			while(true):
				if(nj==0):
					break
				if(grid_n[i][nj]!=nnum):
					break
				nj-=1
			if(j-nj>=3):
				for k in range(nj,j):
					ismatched[i][k] = true
	var outcolumn = ""
	for i in range(grid_column):
		outcolumn += str(column_empty[i])
		outcolumn += " "
	print(outcolumn)
	
	breakmatchedcell()
func breakmatchedcell() -> void:
	var breakel = []
	for i in range(grid_row): 
		for j in range(grid_column):
			if(ismatched[i][j]):
				column_empty[j] += 1
				ismatched[i][j] = false
				breakel.append(grid_i[i][j])
				grid_i[i][j] = -1e9
				grid_n[i][j] = -1e9
	score += breakel.size()
	for i in range(breakel.size()):
		piece[breakel[i]].queue_free()
		piececollid[breakel[i]].queue_free()
		piece[breakel[i]] = null
		piececollid[breakel[i]] = null
		isbreak = true
	var fixnum = []
	var matchnum = []
	for i in range(grid_row):
		for j in range(grid_column):
			matchnum.append(-1e9)
	for i in range(grid_row):
		for j in range(grid_column):
			if(grid_i[i][j]==-1e9):
				continue
			fixnum.append(grid_i[i][j])
	fixnum.sort()
	for i in range(fixnum.size()):
		matchnum[fixnum[i]] = i
	for i in range(grid_row):
		for j in range(grid_column):
			if(grid_i[i][j]==-1e9):
				continue
			grid_i[i][j] = matchnum[grid_i[i][j]]
	var nxpiece = []
	var nxcollidpiece  = []
	for i in range(piece.size()):
		if(piece[i]!=null):
			nxpiece.append(piece[i])
		if(piececollid[i]!=null):
			nxcollidpiece.append(piececollid[i])
	piece = nxpiece
	piececollid = nxcollidpiece
func fallcell() -> void:
	var children = get_children()
	var valid_children = []
	var rng = []
	var collid
	for child in children:
		if child is Sprite2D:
			valid_children.append(child)
		if child is Area2D:
			for nxtchild in child.get_children():
				collid = nxtchild
	for i in range(5):
		rng.append(i)
	for j in range(grid_column):
		for i in range(grid_row):
			if(grid_i[grid_row-1-i][j]==-1e9):
				if(grid_row-1-i==0):
					var nval = rng[randi() % rng.size()]
					grid_n[grid_row-1-i][j] = nval
					grid_i[grid_row-1-i][j] = piece.size()
					var adc = valid_children[nval].duplicate();
					adc.position = Vector2(j*500+500+dx,(grid_row-1-i)*500+500+dy)
					var nxtcollid = collid.duplicate();
					nxtcollid.position = Vector2(j*500+500+dx,(grid_row-1-i)*500+500+dy)
					piece.append(adc)
					piececollid.append(nxtcollid)
					add_child(adc)
					for child in children:
						if child is Area2D:
							child.add_child(nxtcollid)
					column_empty[j]-=1
				else:
					for k in range(grid_row-1-i,0,-1):
						if(k==0):
							var nval = rng[randi() % rng.size()]
							grid_n[grid_row-1-i][j] = nval
							grid_i[grid_row-1-i][j] = piece.size()
							var adc = valid_children[nval].duplicate();
							adc.position = Vector2(j*500+500+dx,(grid_row-1-i)*500+500+dy)
							var nxtcollid = collid.duplicate();
							nxtcollid.position = Vector2(j*500+500+dx,(grid_row-1-i)*500+500+dy)
							piece.append(adc)
							piececollid.append(nxtcollid)
							add_child(adc)
							for child in children:
								if child is Area2D:
									child.add_child(nxtcollid)
							column_empty[j]-=1
						else:
							var gridi = grid_i[k-1][j]
							var gridn = grid_n[k-1][j]
							if(gridi!=-1e9):
								piece[grid_i[k-1][j]].position = Vector2(j*500+500+dx,k*500+500+dy)
								piececollid[grid_i[k-1][j]].position = Vector2(j*500+500+dx,k*500+500+dy)
							grid_i[k-1][j] = grid_i[k][j]
							grid_i[k][j] = gridi
							grid_n[k-1][j] = grid_n[k][j]
							grid_n[k][j] = gridn
	isbreak = false
	for i in range(grid_column):
		if(column_empty[i]>0):
			isbreak = true					
func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator >= update_interval:
		time_accumulator -= update_interval
		if(isbreak):
			fallcell()
		else:
			searchmatch()
	var mouse_position = get_global_mouse_position()
	var i = int((mouse_position.y-(130))/50)
	var j = int((mouse_position.x-(430))/50)
	if(int(abs(i-clickedpositiony)+abs(j-clickedpositionx))>1e9) and clickedpositionx!=-1e9:
		isclick = false
	if(!isclick):
		for k in range(piece.size()):
			if piece[k] != null:
				piece[k].scale = cellsize
	pass
