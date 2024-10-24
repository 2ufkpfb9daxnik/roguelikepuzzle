extends Node2D
var match_index = []
var allFalse
var count
var totalScore: int = 0
var puzzleboardscript
var label :Label
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label = get_node("ScoreLabel")  # ScoreLabelの参照を取得
	if label != null:
		update_score_label()  # 初期スコア表示
	else:
		print("ScoreLabel ノードが見つかりません")

# スコア表示の更新
func update_score_label() -> void:
	if label != null:
		label.text = "合計得点: " + str(totalScore)
	else:
		pass
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func calcscore(matchi) -> void:
	match_index = matchi
	allFalse = []
	for i in range(match_index.size()):
		var columnFalse = []
		for j in range(match_index[i].size()):
				columnFalse.append(false)
		allFalse.append(columnFalse)
	var connectcell = []
	for i in range(match_index.size()):
		for j in range(match_index[i].size()):
			if (match_index[i][j] == true) and (allFalse[i][j] == false):
				count = 0
				lambda(i,j)
				connectcell.append(count)
				print(count)			
	for i in range(connectcell.size()):
		totalScore += connectcell[i]*(connectcell[i]-2)*100	
func _process(delta: float) -> void:
	update_score_label()
	pass
