extends Node2D
var label :RichTextLabel
var label2 :RichTextLabel
var stage :int = 0
var stage_enemy :int = 5
var score :int
var board :Node2D
var enemycount :int = 0
const stage_standard = [50000, 500000, 5000000, 50000000,9223372036854775807]
var enemy :Sprite2D
var ehpbar :ColorRect
var ehpbar1 :ColorRect
var ehppar :float = 1.0
var ehp = 4000*pow(10,stage)
var myhp :float = 5000
var myhppar :float = 1.0
var fevergage :float = 0
var feverpar :float = 0.0
var isfevertime = false
var fevercount = 0
signal stage_clear
var appeartime = 1e9
var stage1enemy = []
var stage2enemy = []
var stage3enemy = []
var stage4enemy = []
var stage5enemy = []
# Called when the node enters the scene tree for the first time.
func _ready() -> void: # 初期化
	connect("stage_clear", Callable(get_parent().get_child(0).get_child(3).get_child(1).get_child(2), "buff_selecter"))
	board = get_parent().get_node("PuzzleBoard")  # StageLabelの参照を取得
	
	label2 = get_node("StageLabel2")  # ScoreManagerのスコアの参照を取得
	label = get_node("StageLabel")
	if label != null&&label2!=null: # ScoreManagerのスコアの参照ができるかどうか
		print(label!=null)
		add_stage_label()
	else:
		print("スコアが取得できません") # 見つからなかったことを知らせる
	
	score = get_parent().get_node("ScoreManager").totalScore # PuzzleBoardの参照を取得
	if board != null: # PuzzleBoardの参照ができるかどうか
		print("PuzzleBoard ノードはあります") # 見つかったことを知らせる
	else:
		print("PuzzleBoard ノードが見つかりません") # 見つからなかったことを知らせる
	

func add_stage_label() -> void: # ステージを1増やす処理
	if(stage_enemy == 5):
		stage_enemy = 1
		stage += 1
		if(label!=null):
			label_control()
			emit_signal("stage_clear")
	else:
		stage_enemy += 1
func score_check() -> void: # スコアがステージを増やす基準を満たしたかチェックする
	score = get_parent().get_node("ScoreManager").totalScore  # ScoreManagerのスコアの参照を取得
	if score != null: # ScoreManagerのスコアの参照ができるかどうか
		if score > stage_standard[stage - 1]: # scoreが基準値を超えたら
			add_stage_label() # ステージを1増やす
		else:
			pass
	else:
		print("スコアが取得できません") # 見つからなかったことを知らせる
func label_control() -> void:
	score = get_parent().get_node("ScoreManager").totalScore
	label.text = "[rainbow freq=0.5 sat=2 val=20][tornado radius="+str(5+score/10000)+"freq="+str(1+score/10000)+"]"+"ステージ:"+str(stage)+"[/tornado][/rainbow]"
	label2.text = "[b][color=#FFDF00][tornado radius="+str(5+score/10000)+"freq="+str(1+score/10000)+"]"+"ステージ:"+str(stage)+"[/tornado][/color][/b]"
func make_enemy() -> void:
	if(enemycount==0):
		enemy = get_parent().get_child(0).get_node("enemy0").duplicate()
		enemy.position = Vector2(1550,250)
		get_parent().get_node("PuzzleBoard").encolor = enemy.modulate.r
		ehpbar = get_parent().get_node("ScoreManager").get_node("ehpbar").duplicate()
		ehpbar1 = get_parent().get_node("ScoreManager").get_node("ehpbar1").duplicate()
		ehpbar.position = Vector2(1475,145)
		ehpbar1.position = Vector2(1475,145)
		ehppar = 1.0
		ehp = 4000*pow(10,(stage-1))
		add_child(enemy)
		add_child(ehpbar)
		add_child(ehpbar1)
		enemycount+=1
func calchp(damage1,damage2) -> void:
	ehp -= damage1
	myhp -= damage2
	ehppar = ehp/(4000*pow(10,(stage-1)))
	myhppar = myhp/5000
	if(ehp<=0):
		isdead()
func calcgage(potion) -> void:
	fevergage += potion
	feverpar = float(fevergage/500)
func displayhp() -> void:
	if(ehppar*150!=0):
		ehpbar1.size = Vector2(ehppar*150,10)
		get_parent().get_node("ScoreManager/hpbar1").size = Vector2(int(myhppar*725),15)
func displaygage() -> void:
	get_parent().get_node("ScoreManager/feverbar2").size = Vector2(int(feverpar*725),15)
func isdead() -> void:
	get_parent().get_node("gekiha").play()
	enemy.queue_free()
	ehpbar.queue_free()
	ehpbar1.queue_free()
	enemy = null
	ehpbar = null
	ehpbar1 = null
	enemycount = 0
	make_enemy()
	add_stage_label()
func fevertime() -> void:
	if(int(fevergage)>=500):
		fevercount = 0
		fevergage = 0
		appeartime = 0
		isfevertime = true
		get_parent().get_node("fevertime").play()
		get_parent().get_node("ScoreManager/feverlabel").text = "[rainbow freq=0.5 sat=2 val=20][tornado radius=50 freq=50]フィーバー[/tornado][/rainbow]"
		get_parent().get_node("ScoreManager/feverlabel").position = Vector2(400,300)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void: # ずっとする
	make_enemy()
	displayhp()
	displaygage()
	appeartime += 1
	if(appeartime>=220):
		get_parent().get_node("ScoreManager/feverlabel").position = Vector2(-1e9,-1e9)
