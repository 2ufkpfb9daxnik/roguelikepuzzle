extends Node2D
# Called when the node enters the scene tree for the first time.
var grid_column # ボードの列数
var grid_row # ボードの行数
var dx = 4000 # ボードの左上の位置
var dy = 1000 # ボードの左上の位置
var piece = [] #駒
var grid_n = [] #grid_n[i][j] := (i,j)に位置する駒の種類
var piececollid = [] #駒の判定
var grid_i = [] #grid_i[i][j] := (i,j)に位置する駒の番号
var grid_att = [] #grid_att[i][j] := (i,j)に位置する駒の属性　盾 = 0,　武器 = 1, コイン = 2, ポーション = 3, 食べ物 = 4
var cellsize #駒の大きさ
var isclick = false #クリックされているか
var clickedpositionx = -1e9 #クリックされた駒の位置
var clickedpositiony = -1e9	#クリックされた駒の位置
var clicknum = -1e9	 #クリックされた駒の種類
var clicki = -1e9	 #クリックされた駒の番号
var clickatt = -1e9 #クリックされた駒の属性
var column_empty = []	#列の空き
var ismatched = []	#マッチした駒
var time_accumulator = 0.0	#時間
var update_interval = 0.2	#更新間隔
var isbreak = false	#消す処理が行われているか
var cellkinds = 5 #駒の種類
var prevposx = -1	#前の位置
var prevposy = -1	#前の位置
var scoremanagerscript	#スコアマネージャのスクリプト
var score_manager	#スコアマネージャ
var score_label	#スコアラベル
func _ready() -> void:	#初期化
	score_manager = get_parent().get_child(2)	#スコアマネージャの取得
	grid_column = 15	#ボードの列数
	grid_row = 15	#ボードの行数
	var collid	#駒の判定
	var children = get_children()	#子ノードの取得
	var valid_children = []	#有効な子ノード
	for i in range(grid_column):	#列の空きの初期化
		column_empty.append(0)	
	for child in children:	#有効な子ノードの取得
		if child is Sprite2D:	#Sprite2Dの場合
			child.position.x = -1000000	#位置の初期化
			valid_children.append(child)	#有効な子ノードに追加
		if child is Area2D:	#Area2Dの場合
			for nxtchild in child.get_children():	#子ノードの取得
				collid = nxtchild	#駒の判定の取得
	for i in range(grid_row):	#ボードの初期化
		var arr = []	#駒の種類
		var arr1 = []	#駒の番号
		var arr2 = []	#マッチした駒
		var arr3 = []   #駒の属性
		for j in range(grid_column):	#ボードの初期化
			var canset = []	#駒の種類
			for k in range(cellkinds):	#駒の種類の初期化
				canset.append(true)	#駒の種類の初期化
			if(i>=2):	#マッチしない駒の種類の初期化
				if(grid_n[i-1][j]==grid_n[i-2][j]):	#マッチしない駒の種類の初期化
					canset[grid_n[i-1][j]] = false	#マッチしない駒の種類の初期化
			if(j>=2):	#マッチしない駒の種類の初期化
				if(arr[j-1]==arr[j-2]):	#マッチしない駒の種類の初期化
					canset[arr[j-1]] = false	#マッチしない駒の種類の初期化
			var rng = []	#駒の種類
			for k in range(cellkinds):	#駒の種類の初期化
				if(canset[k]):	#駒の種類の初期化
					rng.append(k)	#駒の種類の初期化
			var nval = rng[randi() % rng.size()]	#駒の種類
			arr.append(nval)	#駒の種類
			arr1.append(i*grid_column+j)	#駒の番号
			arr2.append(false)	#マッチした駒
			arr3.append(nval%5)
			var adc = valid_children[nval].duplicate();	#駒の複製
			adc.position = Vector2(j*500+500+dx,i*500+500+dy)	#駒の位置
			var nxtcollid = collid.duplicate();	#駒の判定の複製	
			nxtcollid.position = Vector2(j*500+500+dx,i*500+500+dy)	#駒の判定の位置
			cellsize = adc.scale	#駒の大きさ
			piece.append(adc)	#駒の追加	
			piececollid.append(nxtcollid)	#駒の判定の追加
			add_child(adc)	#駒の追加
			for child in children:	#子ノードの取得
				if child is Area2D:	#Area2Dの場合
					child.add_child(nxtcollid)	#駒の判定の追加
		grid_n.append(arr)	#駒の種類
		grid_i.append(arr1)		#駒の番号
		ismatched.append(arr2)	#マッチした駒
		grid_att.append(arr3) #駒の属性
	pass # Replace with function body.
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:	#クリックされた時の処理
	if(isbreak):	#消す処理が行われている場合
		return	#処理を終了
	if event is InputEventMouseButton and !isbreak:	#マウスのボタンが押された場合
		if event.button_index == MOUSE_BUTTON_LEFT:	#左クリックされた場合
			if event.pressed:#駒がクリックされた時の処理
				var mouse_position = get_global_mouse_position()	#マウスの位置
				var i = (mouse_position.y-(130))/50	#マスの位置
				var j = (mouse_position.x-(430))/50	#マスの位置
				print("(%d, %d)" % [i, j])	#位置の表示
				print("(%d, %d)" % [mouse_position.x, mouse_position.y])	#位置の表示
				if(i<grid_row&&i>=0&&j<grid_column&&j>=0):	#範囲内の場合
					piece[grid_i[i][j]].scale *= 2 		#駒の大きさを2倍にする
					clickedpositionx = int(j)	#クリックされた駒の位置
					clickedpositiony = int(i)	#クリックされた駒の位置
				isclick = true	#クリックされているか
				clicki = grid_i[i][j]	#クリックされた駒の番号
				clicknum = grid_n[i][j]	#クリックされた駒の種類
				clickatt = grid_att[i][j]
				prevposx = piece[grid_i[i][j]].position.x	#前の位置
				prevposy = piece[grid_i[i][j]].position.y	#前の位置
			else:	#駒がクリックされた時の処理
				var mouse_position = get_global_mouse_position()	#マウスの位置
				var i = (mouse_position.y-(130))/50	#マスの位置
				var j = (mouse_position.x-(430))/50	#マスの位置
				if(prevposx!=-1e9):	#前の位置が存在する場合
					piece[clicki].position.x = prevposx	#前の位置に戻す
					piece[clicki].position.y = prevposy	#前の位置に戻す
					prevposx = -1e9		
					prevposy = -1e9
				print("c")
				if(i<grid_row&&i>=0&&j<grid_column&&j>=0) and (grid_i[i][j]!=clicknum) and (isclick):	#範囲内の場合
					#駒を交換する処理
					var swapa = grid_i[i][j]	
					var swapb = clicki
					var swapna = grid_n[i][j]
					var swapnb = clicknum
					var swapatta = grid_att[i][j]
					var swapattb = clickatt
					print("swap(%d,%d)" % [swapa,swapb])
					grid_i[i][j] = swapb
					grid_i[clickedpositiony][clickedpositionx] = swapa
					grid_n[i][j] = swapnb
					grid_n[clickedpositiony][clickedpositionx] = swapna
					grid_att[i][j] = swapattb
					grid_att[clickedpositiony][clickedpositionx] = swapatta
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
func searchmatch() -> void: #マッチした駒を調べる
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
				if(ni==-1):
					break
				if(grid_n[ni][j]!=nnum):
					break
				ni-=1
			if(i-ni>=3):
				for k in range(ni+1,i+1):
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
				if(nj==-1):
					break
				if(grid_n[i][nj]!=nnum):
					break
				nj-=1
			if(j-nj>=3):
				for k in range(nj+1,j+1):
					ismatched[i][k] = true
	var copyismatched = ismatched
	score_manager.calcscore(copyismatched,grid_att)
	breakmatchedcell()
func breakmatchedcell() -> void: #マッチした駒を消す
	var breakel = []
	for i in range(grid_row): 
		for j in range(grid_column):
			if(ismatched[i][j]):
				column_empty[j] += 1
				ismatched[i][j] = false
				breakel.append(grid_i[i][j])
				grid_i[i][j] = -1e9
				grid_n[i][j] = -1e9
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
func fallcell() -> void: #駒が消された場所を駒で埋める
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
	for i in range(cellkinds):
		rng.append(i)
	for j in range(grid_column):
		for i in range(grid_row):
			if(grid_i[grid_row-1-i][j]==-1e9):
				if(grid_row-1-i==0):
					var nval = rng[randi() % rng.size()]
					grid_n[grid_row-1-i][j] = nval
					grid_i[grid_row-1-i][j] = piece.size()
					grid_att[grid_row-1-i][j] = nval%5
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
							grid_att[grid_row-1-i][j] = nval%5
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
							var gridatt = grid_att[k-1][j]
							if(gridi!=-1e9):
								piece[grid_i[k-1][j]].position = Vector2(j*500+500+dx,k*500+500+dy)
								piececollid[grid_i[k-1][j]].position = Vector2(j*500+500+dx,k*500+500+dy)
							grid_i[k-1][j] = grid_i[k][j]
							grid_i[k][j] = gridi
							grid_n[k-1][j] = grid_n[k][j]
							grid_n[k][j] = gridn
							grid_att[k-1][j] = grid_att[k][j]
							grid_att[k][j] = gridatt
	isbreak = false
	for i in range(grid_column):
		if(column_empty[i]>0):
			isbreak = true
func _process(delta: float) -> void:
	var mouse_position = get_global_mouse_position()
	if(isclick):
		Input.warp_mouse(Vector2(max(mouse_position.x,435),max(mouse_position.y,135)))
		mouse_position.x = max(mouse_position.x,435)
		mouse_position.y = max(mouse_position.y,135)
		Input.warp_mouse(Vector2(min(mouse_position.x,1160),min(mouse_position.y,860)))
		mouse_position.x = min(mouse_position.x,1160)
	mouse_position.y = min(mouse_position.y,860)
	var i = int((mouse_position.y-(130))/50)
	var j = int((mouse_position.x-(430))/50)
	if(isclick):
		piece[clicki].position.x = (mouse_position.x-430)*10+400+dx
		piece[clicki].position.y = (mouse_position.y-130)*10+400+dy
	time_accumulator += delta
	if time_accumulator >= update_interval:
		time_accumulator -= update_interval
		if(isbreak):
			fallcell()
		else:
			searchmatch()
	if(!isclick):
		for k in range(piece.size()):
			if piece[k] != null:
				piece[k].scale = cellsize
	pass
