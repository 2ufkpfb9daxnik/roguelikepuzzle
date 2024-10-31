extends Node2D
var match_index = []
var allFalse
var allFalse1
var count
var totalScore: int = 0
var puzzleboardscript
var label :RichTextLabel
var label2 :RichTextLabel
var gridscore = []
var labelarr = []
var puzzleboard
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label = get_node("RichTextLabel")  # ScoreLabelの参照を取得
	label2 = get_node("RichTextLabel2")
	puzzleboard = get_parent().get_child(0)
	for i in range(puzzleboard.grid_row):
		var columnscore = []
		for j in range(puzzleboard.grid_column):
				columnscore.append(-1)
		gridscore.append(columnscore)
	if label != null:
		update_score_label()  # 初期スコア表示
	else:
		print("ScoreLabel ノードが見つかりません")

# スコア表示の更新
func update_score_label() -> void:
	if label != null:
		label.text = "[rainbow freq=0.5 sat=2 val=20][tornado radius="+str(5+totalScore/10000)+" freq="+str(1+totalScore/10000)+"]"+"得点:"+str(totalScore)+"[/tornado][/rainbow]"
		label2.text = "[b][color=#FFDF00][tornado radius="+str(5+totalScore/10000)+" freq="+str(1+totalScore/10000)+"]"+"得点:"+str(totalScore)+"[/tornado][/color][/b]"
	else:
		pass
func display_score_label()-> void:
	for i in range(len(gridscore)):
		for j in range(len(gridscore[i])):
			if(gridscore[i][j]!=-1):
				var label3 = get_node("RichTextLabel3").duplicate()
				label3.text = "[rainbow freq=0.5 sat=2 val=20]"+str(gridscore[i][j])+"[/rainbow]"
				label3.position = Vector2(j*50+400, i*50+100)
				gridscore[i][j] = -1
				add_child(label3)
				labelarr.append(label3)
func lambda(x,y):
	if(x-1>=0):	
		if(allFalse[x-1][y]==false&&match_index[x-1][y]==true):
			allFalse[x-1][y] = true
			count += 1
			lambda(x-1,y)
	if(x+1<match_index.size()):
		if(allFalse[x+1][y]==false&&match_index[x+1][y]==true):
			allFalse[x+1][y] = true
			count += 1
			lambda(x+1,y)
	if(y-1>=0):
		if(allFalse[x][y-1]==false&&match_index[x][y-1]==true):
			allFalse[x][y-1] = true
			count += 1
			lambda(x,y-1)
	if(y+1<match_index.size()):
		if(allFalse[x][y+1]==false&&match_index[x][y+1]==true):
			allFalse[x][y+1] = true
			count += 1
			lambda(x,y+1)
func lambda1(x,y,c):
	gridscore[x][y] = c*(c-2)*100;
	if(x-1>=0):	
		if(allFalse1[x-1][y]==false&&match_index[x-1][y]==true):
			allFalse1[x-1][y] = true
			lambda1(x-1,y,c)
	if(x+1<match_index.size()):
		if(allFalse1[x+1][y]==false&&match_index[x+1][y]==true):
			allFalse1[x+1][y] = true
			lambda1(x+1,y,c)
	if(y-1>=0):
		if(allFalse1[x][y-1]==false&&match_index[x][y-1]==true):
			allFalse1[x][y-1] = true
			lambda1(x,y-1,c)
	if(y+1<match_index.size()):
		if(allFalse1[x][y+1]==false&&match_index[x][y+1]==true):
			allFalse1[x][y+1] = true
			lambda1(x,y+1,c)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func calcscore(matchi) -> void:
	match_index = matchi
	allFalse = []
	allFalse1 = []
	for i in range(match_index.size()):
		var columnFalse = []
		var columnscore = []
		for j in range(match_index[i].size()):
				columnFalse.append(false)
		allFalse.append(columnFalse)
		allFalse1.append(columnFalse)
	var connectcell = []
	for i in range(match_index.size()):
		for j in range(match_index[i].size()):
			if (match_index[i][j] == true) and (allFalse[i][j] == false):
				count = 0
				lambda(i,j)
				lambda1(i,j,count)
				connectcell.append(count)
				print(count)			
	for i in range(connectcell.size()):
		totalScore += connectcell[i]*(connectcell[i]-2)*100	
	for i in range(match_index.size()):
		for j in range(match_index[i].size()):
			if(gridscore[i][j]!=-1):
				print(gridscore[i][j])
func _process(delta: float) -> void:
	update_score_label()
	display_score_label()
	for i in range(labelarr.size()):
		if(labelarr[i]==null):
			continue
		if(labelarr[i].modulate.a<=0.9):
			labelarr[i].position.y -= 2
		else:
			labelarr[i].scale = Vector2(labelarr[i].scale.x-0.05,labelarr[i].scale.y-0.05)
			labelarr[i].position.x += 0.6
			labelarr[i].position.y += 0.6
			
		if(labelarr[i].modulate.a!=0):
			labelarr[i].modulate.a -= 0.005/(labelarr[i].modulate.a*labelarr[i].modulate.a*labelarr[i].modulate.a)*0.9
	var labelarr1 = []
	for i in range(labelarr.size()):
		if(labelarr[i].modulate.a<=0):
			labelarr[i].queue_free()
			labelarr[i] = null
		else:
			labelarr1.append(labelarr[i])
	labelarr = labelarr1
	pass
