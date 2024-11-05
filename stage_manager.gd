extends Node2D
var label :Label
var stage :int = 0
var score :int
var board :Node2D
var enemycount :int = 0
const stage_standard = [10000, 20000, 30000, 50000,9223372036854775807]
var enemy :Sprite2D
var ehpbar :ColorRect
var ehpbar1 :ColorRect
var ehppar :float = 1.0
var ehp = 8000*pow(10,stage)
# Called when the node enters the scene tree for the first time.
func _ready() -> void: # 初期化
	label = get_node("StageLabel")  # StageLabelの参照を取得
	if label != null: # StageLabelの参照ができるかどうか
		add_stage_label() # ステージを初期化(実際にはステージを1増やす処理だが、初期値が0なのでステージを1にする処理となる)
	else:
		print("StageLabel ノードが見つかりません") # 見つからなかったことを知らせる
	
	score = get_parent().get_node("ScoreManager").totalScore  # ScoreManagerのスコアの参照を取得
	if score != null: # ScoreManagerのスコアの参照ができるかどうか
		print("スコアの取得に成功しました") # 見つかったことを知らせる
	else:
		print("スコアが取得できません") # 見つからなかったことを知らせる
	
	board = get_parent().get_node("PuzzleBoard") # PuzzleBoardの参照を取得
	if board != null: # PuzzleBoardの参照ができるかどうか
		print("PuzzleBoard ノードはあります") # 見つかったことを知らせる
	else:
		print("PuzzleBoard ノードが見つかりません") # 見つからなかったことを知らせる
	score_check()
func add_stage_label() -> void: # ステージを1増やす処理
	stage+=1 # ステージを1増やす
	if label != null: # labelがnullでないかどうか
		print(stage) # ログに何ステージになったか書き出す
		label.text = "現在のステージ: " + str(stage) # ステージラベルを更新する
	else:
		pass

func score_check() -> void: # スコアがステージを増やす基準を満たしたかチェックする
	score = get_parent().get_node("ScoreManager").totalScore  # ScoreManagerのスコアの参照を取得
	if score != null: # ScoreManagerのスコアの参照ができるかどうか
		if score > stage_standard[stage - 1]: # scoreが基準値を超えたら
			add_stage_label() # ステージを1増やす
		else:
			pass
	else:
		print("スコアが取得できません") # 見つからなかったことを知らせる
func make_enemy() -> void:
	if(enemycount==0):
		enemy = get_parent().get_child(0).get_node("enemy0").duplicate()
		enemy.position = Vector2(1550,250)
		ehpbar = get_parent().get_node("ScoreManager").get_node("ehpbar").duplicate()
		ehpbar1 = get_parent().get_node("ScoreManager").get_node("ehpbar1").duplicate()
		ehpbar.position = Vector2(1475,145)
		ehpbar1.position = Vector2(1475,145)
		ehppar = 1.0
		ehp = 8000*pow(10,(stage-1))
		add_child(enemy)
		add_child(ehpbar)
		add_child(ehpbar1)
		enemycount+=1
func calchp(damage) -> void:
	ehp -= damage
	ehppar = ehp/(8000*pow(10,(stage-1)))
	if(ehp<=0):
		isdead()
func displayhp() -> void:
	if(ehppar*150!=0):
		ehpbar1.size = Vector2(ehppar*150,10)
func isdead() -> void:
	enemy.queue_free()
	ehpbar.queue_free()
	ehpbar1.queue_free()
	enemy = null
	ehpbar = null
	ehpbar1 = null
	enemycount = 0
	make_enemy()
	score_check()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void: # ずっとする
	make_enemy()
	displayhp()
	
