extends Node
var match_index = []
var allFalse
var count
var totalScore: int = 0
var score_label: Label
var puzzleboardscript
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# ScoreLabel ノードを取得
	score_label = $ScoreLabel
	puzzleboardscript = load("res://puzzle_board.gd").new()
	# 初期スコアを表示
	update_score_label() # Replace with function body.
	
# スコアを更新して表示
func update_score_label() -> void:
	# totalScore を ScoreLabel に表示
	score_label.text = str(totalScore)

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
	allFalse = match_index
	for i in range(match_index.size()):
		for j in range(match_index[i].size()):
				allFalse[i][j] = false
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
