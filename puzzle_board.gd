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
var update_interval = 0.04	#更新間隔
var isbreak = false	#消す処理が行われているか
var cellkinds = 5 #駒の種類
var prevposx = -1	#前の位置
var prevposy = -1	#前の位置
var scoremanagerscript	#スコアマネージャのスクリプト
var score_manager	#スコアマネージャ
var score_label	#スコアラベル
var interval = -1e18
var movetoscore = []
var movetoscoren = []
var endbreak = false
var movesword = []
var moveswordt = []
var moveswordrnd = []
var moveswordcnt = 0
var moveshield = []
var moveshieldt = []
var moveshieldp = []
var moveshieldv = []
var movefood  = []
var movefoodt = []
var movefoodrnd = []
var movepotion = []
var movepotiont = []
var movepotionrnd = []
var shismoved = []
var isswap = false
var msisvalid = false
var mshisvalid = false
var touchsword = 0
var encolor
var breakinterval = 0
var canfall = false
var scratch :AnimatedSprite2D
var isattack :int = 0
var isblock :int = 0
var isgameover = false
func _ready() -> void:	#初期化
	score_manager = get_parent().get_child(2)	#スコアマネージャの取得
	grid_column = 15	#ボードの列数
	grid_row = 15	#ボードの行数
	get_node("1rensa").pitch_scale = 0.92
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
	if(isbreak||endbreak||isswap||get_parent().get_node("StageManager").interval<105||get_parent().get_node("StageManager").isstageclear||get_parent().get_node("StageManager").isdeadf):	#消す処理が行われている場合
		return	#処理を終了
	if event is InputEventMouseButton and !isbreak:	#マウスのボタンが押された場合
		if event.button_index == MOUSE_BUTTON_LEFT:	#左クリックされた場合
			if event.pressed:#駒がクリックされた時の処理
				var mouse_position = get_global_mouse_position()	#マウスの位置
				var i = (mouse_position.y-(130))/50	#マスの位置
				var j = (mouse_position.x-(430))/50	#マスの位置
				if(i<grid_row&&i>=0&&j<grid_column&&j>=0):	#範囲内の場合
					piece[grid_i[i][j]].scale *= 2 		#駒の大きさを2倍にする
					clickedpositionx = int(j)	#クリックされた駒の位置
					clickedpositiony = int(i)	#クリックされた駒の位置
					get_node("AudioStreamPlayer2").play()
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
				if(i<grid_row&&i>=0&&j<grid_column&&j>=0) and (grid_i[i][j]!=clicknum) and (isclick):	#範囲内の場合
					#駒を交換する処理
					get_node("AudioStreamPlayer2").play()
					isswap = true
					if(int(i)==int(clickedpositiony)&&int(j)==int(clickedpositionx)):
						isswap = false
					var swapa = grid_i[i][j]	
					var swapb = clicki
					var swapna = grid_n[i][j]
					var swapnb = clicknum
					var swapatta = grid_att[i][j]
					var swapattb = clickatt
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
	var canbreak = false
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
				canbreak = true
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
				canbreak = true
			while(true):
				if(nj==grid_column):
					break
				if(grid_n[i][nj]!=nnum):
					break
				nj+=1
			if(nj-j>=3):
				for k in range(j,nj):
					ismatched[i][k] = true
				canbreak = true
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
				canbreak = true
	var copyismatched = ismatched
	if(breakinterval>=20):
		score_manager.calcscore(copyismatched,grid_att)
		breakmatchedcell()
		breakinterval = 0
	breakinterval += 1
func breakmatchedcell() -> void: #マッチした駒を消す
	var breakel = []
	var breakeln = []
	for i in range(grid_row): 
		for j in range(grid_column):
			if(ismatched[i][j]):
				column_empty[j] += 1
				ismatched[i][j] = false
				breakel.append(grid_i[i][j])
				breakeln.append(grid_n[i][j])
				grid_i[i][j] = -1e9
				grid_n[i][j] = -1e9
	if(breakel.size()>0):
		canfall = true
		get_parent().get_node("ScoreManager").combocount += 1
		get_parent().get_node("ScoreManager").iscombo = true
		get_node("1rensa").play()
		get_node("1rensa").pitch_scale += 0.08
	for i in range(breakel.size()):
		var adc = piece[breakel[i]].duplicate()
		movetoscore.append(adc)
		movetoscoren.append(breakeln[i])
		add_child(adc)
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
	if(!isbreak):
		canfall = false
func moveswords() -> void:
	for i in range(movesword.size()):
		if(moveswordt[i]>=0):
			movesword[i].position.x+=10+moveswordrnd[i]
			movesword[i].position.y = -moveswordt[i]**2+5200
		moveswordt[i] += 1
	for i in range(movesword.size()):
		if(movesword[i].position.y==2700):
			get_parent().get_node("StageManager").calchp(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1)),0)
			if(get_parent().get_node("StageManager").ehp<=0):
				pass
			if(get_parent().get_node("StageManager").enemy!=null):
				get_parent().get_node("StageManager").enemy.modulate.r += 50
			get_node("AudioStreamPlayer").play()
			
	for i in range(movesword.size()):
		if(movesword[i].position.y<=-300):
			movesword[i].queue_free()
			movesword[i] = null
			moveswordrnd[i] = null
			moveswordt[i] = null
	var nmovesword = []
	var nmoveswordt = []
	var nmoveswordrnd = []
	for i in range(movesword.size()):
		if(movesword[i]!=null):
			nmovesword.append(movesword[i])
			nmoveswordt.append(moveswordt[i])
			nmoveswordrnd.append(moveswordrnd[i])
	movesword = nmovesword
	moveswordt = nmoveswordt
	moveswordrnd = nmoveswordrnd
func moveshields() -> void:
	for i in range(moveshield.size()):
		if(moveshieldt[i]>=0):
			moveshield[i].position.x = 12300+moveshieldv[i].x*moveshieldt[i]*10
			moveshield[i].position.y = 4800-moveshieldv[i].y*moveshieldt[i]*10
			moveshield[i].position.x =  min(moveshieldp[i].x,moveshield[i].position.x)
			moveshield[i].position.y =  max(moveshieldp[i].y,moveshield[i].position.y)
		moveshieldt[i] += 1
	for i in range(moveshield.size()):
		if(moveshield[i].position.x==moveshieldp[i].x&&moveshield[i].position.y==moveshieldp[i].y):
			if(shismoved[i]):
				continue
			shismoved[i] = true
			get_node("shieldmove").play()
func movefoods() -> void:
	for i in range(movefood.size()):
		if(movefoodt[i]>=0):
			movefood[i].position.x+=10+movefoodrnd[i]
			movefood[i].position.y = -movefoodt[i]**2+6800
		movefoodt[i] += 1
	for i in range(movefood.size()):
		if(movefood[i].position.y<=5000):
			get_parent().get_node("StageManager").calchp(0,-100)
			get_parent().get_node("kaihuku").play()
			movefood[i].queue_free()
			movefood[i] = null
			movefoodrnd[i] = null
			movefoodt[i] = null
	var nmovefood = []
	var nmovefoodt = []
	var nmovefoodrnd = []
	for i in range(movefood.size()):
		if(movefood[i]!=null):
			nmovefood.append(movefood[i])
			nmovefoodt.append(movefoodt[i])
			nmovefoodrnd.append(movefoodrnd[i])
	movefood = nmovefood
	movefoodt = nmovefoodt
	movefoodrnd = nmovefoodrnd
	pass
func movepotions() -> void:
	for i in range(movepotion.size()):
		if(movepotiont[i]>=0):
			movepotion[i].position.x+=10+movepotionrnd[i]
			movepotion[i].position.y = -movepotiont[i]**2+6800
		movepotiont[i] += 1
	for i in range(movepotion.size()):
		if(movepotion[i].position.y<=5000):
			get_parent().get_node("StageManager").calcgage(100)
			get_parent().get_node("potion").play()
			movepotion[i].queue_free()
			movepotion[i] = null
			movepotionrnd[i] = null
			movepotiont[i] = null
	var nmovepotion = []
	var nmovepotiont = []
	var nmovepotionrnd = []
	for i in range(movepotion.size()):
		if(movepotion[i]!=null):
			nmovepotion.append(movepotion[i])
			nmovepotiont.append(movepotiont[i])
			nmovepotionrnd.append(movepotionrnd[i])
	movepotion = nmovepotion
	movepotiont = nmovepotiont
	movepotionrnd = nmovepotionrnd
	pass
func movecell() -> void:
	for i in range(movetoscore.size()):
		if(movetoscoren[i]==0):
			if(movetoscore[i].position.y<=4600):
				movetoscore[i].position.y+=min(80,4600-movetoscore[i].position.y) 
			else:
				movetoscore[i].position.y-=min(80,movetoscore[i].position.y-4600) 
		elif(movetoscoren[i]==1):
			if(movetoscore[i].position.y<=5100):
				movetoscore[i].position.y+=min(80,5100-movetoscore[i].position.y) 
			else:
				movetoscore[i].position.y-=min(80,movetoscore[i].position.y-5100) 
		elif(movetoscoren[i]==2):
			if(movetoscore[i].position.y<=5600):
				movetoscore[i].position.y+=min(80,5600-movetoscore[i].position.y) 
			else:
				movetoscore[i].position.y-=min(80,movetoscore[i].position.y-5600) 
		elif(movetoscoren[i]==3):
			if(movetoscore[i].position.y<=6100):
				movetoscore[i].position.y+=min(80,6100-movetoscore[i].position.y) 
			else:
				movetoscore[i].position.y-=min(80,movetoscore[i].position.y-6100) 
		else:
			if(movetoscore[i].position.y<=6600):
				movetoscore[i].position.y+=min(80,6600-movetoscore[i].position.y) 
			else:
				movetoscore[i].position.y-=min(80,movetoscore[i].position.y-6600) 
		movetoscore[i].position.x+=min(200,12100-movetoscore[i].position.x) 
	for i in range(movetoscore.size()):
		if(movetoscoren[i]==0):
			if(movetoscore[i].position.x==12100&&movetoscore[i].position.y==4600):
				movetoscore[i].queue_free()
				movetoscore[i] = null
				movetoscoren[i] = null
		elif(movetoscoren[i]==1):
			if(movetoscore[i].position.x==12100&&movetoscore[i].position.y==5100):
				movetoscore[i].queue_free()
				movetoscore[i] = null
				movetoscoren[i] = null
		elif(movetoscoren[i]==2):
			if(movetoscore[i].position.x==12100&&movetoscore[i].position.y==5600):
				movetoscore[i].queue_free()
				movetoscore[i] = null
				movetoscoren[i] = null
		elif(movetoscoren[i]==3):
			if(movetoscore[i].position.x==12100&&movetoscore[i].position.y==6100):
				movetoscore[i].queue_free()
				movetoscore[i] = null
				movetoscoren[i] = null
		else:
			if(movetoscore[i].position.x==12100&&movetoscore[i].position.y==6600):
				movetoscore[i].queue_free()
				movetoscore[i] = null
				movetoscoren[i] = null
	var nmovetoscore = []
	var nmovetoscoren = []
	for i in range(movetoscore.size()):
		if(movetoscore[i]!=null):
			nmovetoscore.append(movetoscore[i])
			nmovetoscoren.append(movetoscoren[i])
	movetoscore = nmovetoscore
	movetoscoren = nmovetoscoren
func _process(delta: float) -> void:
	if(get_parent().get_node("StageManager").isstageclear||get_parent().get_node("StageManager").isdeadf):
		isattack = false
		isblock = false
		isswap = false 
		endbreak = false
		isbreak = false
		interval = 0
		get_parent().get_node("ScoreManager").combocount = 0
		get_node("1rensa").pitch_scale = 0.92
		movecell()
		moveswords()
		moveshields()
		movefoods()
		movepotions()
		return 
	if(endbreak&&movetoscore.size()==0):
		if(isgameover):
			if(interval<=1):
				get_parent().get_node("StageManager").get_node("feverbgm").stop()
				get_parent().get_node("StageManager").get_node("fieldbgm").stop()
				get_parent().get_node("haiboku").play()
			if(interval<50):
				pass
			if(interval<100):
				get_parent().get_node("StageManager").get_node("GameOver").position.y = (interval-50)*6
			if(interval==100):
				get_parent().get_node("StageManager").get_node("GameOver").text = "[color=black][tornado radius=20 freq=2]ゲームオーバー[/tornado][/color]"
				get_parent().get_node("returntitle").visible = !get_parent().get_node("returntitle").visible
			interval += 1
			return
		if(get_parent().get_node("ScoreManager").divscore[1]>0||(get_parent().get_node("ScoreManager").divscore[4]>0&&get_parent().get_node("StageManager").myhp<5000)||(get_parent().get_node("ScoreManager").divscore[3]>0&&get_parent().get_node("StageManager").fevergage<5000)):
			isattack = 1
		if(get_parent().get_node("ScoreManager").divscore[0]>0):
			isblock = 1
		if(interval<=36):
			if(interval==0):
				get_node("anten").play()
			for i in range(5):
				get_parent().get_node("ScoreManager").get_node("score"+str(i)).position.y = 450+50*i+(interval-18)*(interval-18)/10-33
		elif(interval<=72):
			if(interval==37):
				get_node("anten").play()
			for i in range(5):
				get_parent().get_node("ScoreManager").get_node("score"+str(i)).position.y = 450+50*i+((interval-36)-18)*((interval-36)-18)/10-33
		elif(interval<=108):
			if(interval==73):
				get_node("anten").play()
			for i in range(5):
				get_parent().get_node("ScoreManager").get_node("score"+str(i)).position.y = 450+50*i+((interval-72)-18)*((interval-72)-18)/10-33
		elif(interval==109&&isattack):
			var makecnt = min(int(get_parent().get_node("StageManager").ehp/(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1)))),int(get_parent().get_node("ScoreManager").divscore[1]/(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1)))))
			get_parent().get_node("ScoreManager").divscore[1] -= makecnt*100*pow(10,max(0,get_parent().get_node("StageManager").stage-1))
			for i in range(makecnt):
				var adc = get_node("Sprite2D1").duplicate();
				adc.position = Vector2(12300,5300)
				adc.scale *= 2
				add_child(adc)
				movesword.append(adc)
				msisvalid = true
				moveswordt.append(-i*70/makecnt)
				moveswordrnd.append(randi()%120)
			var makecnt2 = min(50-int(get_parent().get_node("StageManager").myhp/(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1)))),int(get_parent().get_node("ScoreManager").divscore[4]/(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1)))))
			get_parent().get_node("ScoreManager").divscore[4] -= makecnt2*100*pow(10,max(0,get_parent().get_node("StageManager").stage-1))
			for i in range(makecnt2):
				var adc = get_node("Sprite2D4").duplicate();
				adc.position = Vector2(12300,6800)
				adc.scale *= 2
				add_child(adc)
				movefood.append(adc)
				movefoodt.append(-i*70/makecnt2)
				movefoodrnd.append(randi()%120)
			var makecnt3 = min(70-int(get_parent().get_node("StageManager").fevergage/(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1)))),int(get_parent().get_node("ScoreManager").divscore[3]/(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1)))))
			get_parent().get_node("ScoreManager").divscore[3] -= makecnt3*100*pow(10,max(0,get_parent().get_node("StageManager").stage-1))
			for i in range(makecnt3):
				var adc = get_node("Sprite2D3").duplicate();
				adc.position = Vector2(12300,6300)
				adc.scale *= 2
				add_child(adc)
				movepotion.append(adc)
				movepotiont.append(-i*70/makecnt3)
				movepotionrnd.append(randi()%120)
		elif(interval<=252&&isattack):
			pass
		elif(interval==109+144*isattack&&isblock):
			var makecnt = int(get_parent().get_node("ScoreManager").divscore[0]/(100*pow(10,max(0,get_parent().get_node("StageManager").stage-1))))
			get_parent().get_node("ScoreManager").divscore[0] -= makecnt*100*pow(10,max(0,get_parent().get_node("StageManager").stage-1))
			for i in range(makecnt):
				var adc = get_node("Sprite2D0").duplicate();
				adc.position = Vector2(12300,4800)
				adc.scale *= 2
				adc.z_index = 1
				add_child(adc)
				moveshield.append(adc)
				mshisvalid = true
				moveshieldp.append(Vector2(7200/makecnt*i+12300,-1000/(makecnt*2)*(randi()%(makecnt*2))+3800))
				moveshieldt.append(-i*70/makecnt)
				moveshieldv.append(Vector2(abs(adc.position.x-moveshieldp.back().x)/108,abs(adc.position.y-moveshieldp.back().y)/108))
				shismoved.append(false)
		elif(interval<=164+144*isattack&&isblock):
			pass
		elif(interval==109+144*isattack+128*isblock):
			get_parent().get_node("StageManager").enemy.scale *= 1.5
		elif(interval<121+144*isattack+128*isblock):
			pass
		elif(interval==121+144*isattack+128*isblock):
			scratch = get_parent().get_node("scratch").duplicate()
			scratch.scale *= 8
			scratch.position = Vector2(15000,2500)
			scratch.frame = 0
			scratch.play()
			add_child(scratch)
			get_node("block").play()
			get_node("block").seek(0.7)
			get_parent().get_node("StageManager").calchp(0,get_parent().get_node("StageManager").enemyat/(moveshield.size()+1))
			for i in range(moveshield.size()):
				moveshield[i].queue_free()
				moveshield[i] = null
			while(moveshield.size()>0):
				moveshield.pop_back()
				moveshieldt.pop_back()
				moveshieldp.pop_back()
				moveshieldv.pop_back()
			if(get_parent().get_node("StageManager").myhp<=0):
				get_parent().get_node("StageManager").get_node("gameover").position = Vector2(0,0)
				isgameover = true
				interval = 0
		elif(interval<138+144*isattack+128*isblock):
			pass
		elif(interval==138+144*isattack+128*isblock):
			get_parent().get_node("StageManager").enemy.scale /= 1.5
		elif(interval<160+144*isattack+128*isblock):
			pass
		elif(interval==160+144*isattack+128*isblock):
			if(!get_parent().get_node("StageManager").isfevertime):
				get_parent().get_node("StageManager").fevertime()
		else:
			isattack = false
			isblock = false
			isswap = false 
			endbreak = false
			isbreak = false
			interval = 0
			get_parent().get_node("StageManager").fevercount -= 1
			if(get_parent().get_node("StageManager").fevercount==0):
				get_parent().get_node("StageManager").notfevertime()
			get_parent().get_node("ScoreManager").combocount = 0
			get_node("1rensa").pitch_scale = 0.92
		interval+=1	
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
			if(canfall):
				fallcell()
			else:
				searchmatch()
			print("combo")
			if(!isbreak):
				endbreak = true
				interval = 0
		else:
			searchmatch()
			if(!isbreak&&isswap):
				endbreak = true
				isswap = false
				interval = 0
	movecell()
	moveswords()
	moveshields()
	movefoods()
	movepotions()
	if(movesword.size()==0):
		if(get_parent().get_node("StageManager").enemy!=null):
			if(msisvalid):
				get_parent().get_node("StageManager").enemy.modulate.r = encolor
				msisvalid = false
	if(!isclick):
		for k in range(piece.size()):
			if piece[k] != null:
				piece[k].scale = cellsize
	pass
