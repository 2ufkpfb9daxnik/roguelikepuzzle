extends Node2D
var label :RichTextLabel
var label2 :RichTextLabel
var stage :int = 0
var stage_enemy :int = 5
var score :int
var board :Node2D
var enemycount :int = 0
const stage_standard = [1000, 2000, 30000, 50000,9223372036854775807]
var enemy :Sprite2D
var ehpbar :ColorRect
var ehpbar1 :ColorRect
var ehppar :float = 1.0
var ehp = 0

var myhp :float = 5000*pow(10,max(0,stage-1))
var myhpmax :float = 5000*pow(10,max(0,stage-1))
var myhppar :float = 1.0
var fevergage :float = 0
var feverpar :float = 0.0
var isfevertime = false
var fevercount = 0
signal stage_clear
var appeartime = 1e9
var stage1enemy = ["enemy4","enemy5","enemy8","enemy12","enemy15","enemy24"]
var stage2enemy = ["enemy2","enemy3","enemy6","enemy10","enemy5","enemy14"]
var stage3enemy = ["enemy2","enemy7","enemy19","enemy20","enemy21","enemy11"]
var stage4enemy = ["enemy3","enemy5","enemy13","enemy16","enemy23","enemy17"]
var stage5enemy = ["enemy1","enemy7","enemy9","enemy19","enemy12","enemy18"]
var stagehaikei = ["plane","cave","desert","snow field","castle"]
var stage1enemyhp = [10000,3000,4000,7500,6000,20000]
var stage1enemyat = [1500,1000,1500,2000,1700,1900]
var stage2enemyhp = [3000,8000,7000,6000,3000,15000]
var stage2enemyat = [2500,1500,1000,2000,1000,3000]
var stage3enemyhp = [3000,5000,9000,4000,3000,30000]
var stage3enemyat = [2500,2000,2000,2500,2000,1500]
var stage4enemyhp = [8000,3000,5000,7000,12000,25000]
var stage4enemyat = [1500,1000,2000,2000,1000,3500]
var stage5enemyhp = [7000,5000,7000,9000,7500,50000]
var stage5enemyat = [2000,2000,3000,2000,2000,4000]
var interval = 0
var facearr = []
var enemyat = 0
var ehpmax = 0
var isstageclear = false
var clearinterval = 0
var isdeadf = false
var deadinterval = 0
var clicked = false
var isdanger = false
var dangerinterval = 0
var islastboss = false
var lastbossinterval = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void: # 初期化
	connect("stage_clear", Callable(get_parent().get_child(0).get_child(3).get_child(1).get_child(2), "buff_selecter"))
	board = get_parent().get_node("PuzzleBoard")  # StageLabelの参照を取得
	label2 = get_node("StageLabel2")  # ScoreManagerのスコアの参照を取得
	label = get_node("StageLabel")
	if label != null&&label2!=null: # ScoreManagerのスコアの参照ができるかどうか
		print(label!=null)
		stage_enemy = 1
		stage += 1
		if(label!=null):
			label_control()
			emit_signal("stage_clear")
	else:
		print("スコアが取得できません") # 見つからなかったことを知らせる
	
	score = get_parent().get_node("ScoreManager").totalScore # PuzzleBoardの参照を取得
	if board != null: # PuzzleBoardの参照ができるかどうか
		print("PuzzleBoard ノードはあります") # 見つかったことを知らせる
	else:
		print("PuzzleBoard ノードが見つかりません") # 見つからなかったことを知らせる
	

func add_stage_label() -> void: # ステージを1増やす処理
	if(stage_enemy==5&&stage==5):
		islastboss = true
		lastbossinterval = 0
	elif(stage_enemy == 5):
		isstageclear = true
		clearinterval = 0
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
		if(stage_enemy==4&&stage==5):
			get_node("maoubgm").play()
		elif(stage_enemy==4):
			get_node("bossbgm").play()
		else:
			get_node("fieldbgm").play()
		interval = 0
		get_parent().get_node("kemuri").position = Vector2(1552.375,210.125)
		get_parent().get_node("kemuri").play()
		var rand = randi()%5
		if(stage==1):
			if(stage_enemy==4):
				enemy = get_parent().get_child(0).get_node(stage1enemy[5]).duplicate()
			else:
				enemy = get_parent().get_child(0).get_node(stage1enemy[rand]).duplicate()
		elif(stage==2):
			if(stage_enemy==4):
				enemy = get_parent().get_child(0).get_node(stage2enemy[5]).duplicate()
			else:
				enemy = get_parent().get_child(0).get_node(stage2enemy[rand]).duplicate()
		elif(stage==3):
			if(stage_enemy==4):
				enemy = get_parent().get_child(0).get_node(stage3enemy[5]).duplicate()
			else:
				enemy = get_parent().get_child(0).get_node(stage3enemy[rand]).duplicate()
		elif(stage==4):
			if(stage_enemy==4):
				enemy = get_parent().get_child(0).get_node(stage4enemy[5]).duplicate()
			else:
				enemy = get_parent().get_child(0).get_node(stage4enemy[rand]).duplicate()
		elif(stage==5):
			if(stage_enemy==4):
				enemy = get_parent().get_child(0).get_node(stage5enemy[5]).duplicate()
			else:
				enemy = get_parent().get_child(0).get_node(stage5enemy[rand]).duplicate()
		enemy.position = Vector2(1550,250)
		get_parent().get_node("PuzzleBoard").encolor = enemy.modulate.r
		ehpbar = get_parent().get_node("ScoreManager").get_node("ehpbar").duplicate()
		ehpbar1 = get_parent().get_node("ScoreManager").get_node("ehpbar1").duplicate()
		ehpbar.position = Vector2(1475,145)
		ehpbar1.position = Vector2(1475,145)
		ehppar = 1.0
		if(stage_enemy==4):
			if(stage==1):
				ehp = stage1enemyhp[5]
				enemyat = stage1enemyat[5]
			elif(stage==2):
				ehp = stage2enemyhp[5]
				enemyat = stage2enemyat[5]
			elif(stage==3):
				ehp = stage3enemyhp[5]
				enemyat = stage3enemyat[5]
			elif(stage==4):
				ehp = stage4enemyhp[5]
				enemyat = stage4enemyat[5]
			elif(stage==5):	
				ehp = stage5enemyhp[5]
				enemyat = stage5enemyat[5]
		else:
			if(stage==1):
				ehp = stage1enemyhp[rand]
				enemyat = stage1enemyat[rand]
			elif(stage==2):
				ehp = stage2enemyhp[rand]
				enemyat = stage2enemyat[rand]
			elif(stage==3):
				ehp = stage3enemyhp[rand]
				enemyat = stage3enemyat[rand]
			elif(stage==4):
				ehp = stage4enemyhp[rand]
				enemyat = stage4enemyat[rand]
			elif(stage==5):	
				ehp = stage5enemyhp[rand]
				enemyat = stage5enemyat[rand]
		ehp *= pow(10,max((stage-1),0))
		enemyat *= pow(10,max(0,stage-1))
		ehpmax = ehp
		add_child(enemy)
		add_child(ehpbar)
		add_child(ehpbar1)
		enemycount+=1
func calchp(damage1,damage2) -> void:
	ehp -= damage1
	myhp -= damage2
	ehppar = ehp/ehpmax
	myhppar = myhp/myhpmax
	if(ehp<=0&&!isdeadf):
		isdead()
func calcgage(potion) -> void:
	fevergage += potion
	feverpar = float(fevergage/7000)
func displayhp() -> void:
	if(ehppar*150!=0):
		ehpbar1.size = Vector2(ehppar*150,10)
		get_parent().get_node("ScoreManager/hpbar1").size = Vector2(min(int(myhppar*725),725),15)
func displaygage() -> void:
	get_parent().get_node("ScoreManager/feverbar2").size = Vector2(int(feverpar*725),15)
	get_parent().get_node("ScoreManager/fevertimecount").text = "[center][rainbow freq=0.5 sat=2 val=20][wave amp=100 freq=5]"+str(fevercount)+"[/wave][/rainbow][/center]"
func isdead() -> void:
	get_parent().get_node("gekiha").play()
	enemy.queue_free()
	ehpbar.queue_free()
	ehpbar1.queue_free()
	enemy = null
	ehpbar = null
	ehpbar1 = null
	enemycount = 0
	isdeadf = true
	if(stage==5&&stage_enemy==5):
		islastboss = true
	elif(stage_enemy==5):
		isstageclear = true
func fevertime() -> void:
	if(int(fevergage)>=7000):
		fevercount = 5
		fevergage = 0
		appeartime = 0
		isfevertime = true
		get_node("fieldbgm").stop()
		get_parent().get_node("fevertime").play()
		get_parent().get_node("ScoreManager/feverlabel").text = "[rainbow freq=0.5 sat=2 val=20][tornado radius=50 freq=50]フィーバー[/tornado][/rainbow]"
		get_parent().get_node("ScoreManager/feverlabel").position = Vector2(400,300)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func notfevertime() -> void:
	isfevertime = false
	get_node("feverbgm").stop()
	if(stage_enemy==5):
		get_node("bossbgm").play()
	else:
		get_node("fieldbgm").play()
	get_parent().get_node("ScoreManager").get_node("feverrect").visible = false
	get_parent().get_node("ScoreManager").get_node("feverrect2").visible = false
	get_parent().get_node("ScoreManager").get_node("feverlabel2").visible = false
	get_parent().get_node("ScoreManager").get_node("feverlabel3").visible = false
	get_parent().get_node("ScoreManager").get_node("fevertime").visible = false
	get_parent().get_node("ScoreManager").get_node("fevertimecount").visible = false
func _process(delta: float) -> void: # ずっとする	
	if(isdanger&&stage_enemy!=5):
		if(dangerinterval==0):
			get_node("fieldbgm").stop()
			get_node("feverbgm").stop()
			get_node("danger").play()
			get_node("movefront").visible = false
			get_node("dangerlabel").visible = true
			get_node("dangerrect").visible = true
		elif(dangerinterval<42):
			pass
		elif(dangerinterval==42):
			get_node("dangerlabel").visible = false
		elif(dangerinterval<68):
			pass
		elif(dangerinterval==68):
			get_node("dangerlabel").visible = true
		elif(dangerinterval<110):
			pass
		elif(dangerinterval==110):
			get_node("dangerlabel").visible = false
		elif(dangerinterval<136):
			pass
		elif(dangerinterval==136):
			get_node("dangerlabel").visible = true
		elif(dangerinterval<178):
			pass
		elif(dangerinterval==178):
			get_node("dangerlabel").visible = false	
		elif(dangerinterval<204):
			pass
		elif(dangerinterval==204):
			get_node("dangerlabel").visible = true
		elif(dangerinterval<246):
			pass
		elif(dangerinterval==246):
			get_node("dangerlabel").visible = false	
		elif(dangerinterval<260):
			pass
		elif(dangerinterval==260):
			get_node("dangerrect").visible = false
			make_enemy()
			add_stage_label()
			isdeadf = false
			clicked = true
			deadinterval = 0
			isdanger = false
		dangerinterval += 1
		return
	if(islastboss):
		if(lastbossinterval<=100):
			pass
		elif(lastbossinterval==101):
			get_parent().get_node("ScoreManager/GameClear2").visible = true
			get_parent().get_node("ScoreManager/GameClear").visible = true
			get_parent().get_node("ScoreManager/GameClearWhite").visible = true
			get_node("bossbgm").stop()
			get_parent().get_node("StageManager/lastbossclear").play()
		elif(lastbossinterval<=120):
			pass
		elif(lastbossinterval==121):
			get_parent().get_node("StageManager/ending").play()
		else:
			get_parent().get_node("ScoreManager/gameclearbutton").visible = true
		lastbossinterval += 1
		return
	if(isstageclear&&!islastboss):
		if(clearinterval<=100):
			pass
		elif(clearinterval==101):
			get_parent().get_node("ScoreManager/stageclear").visible = true
			get_parent().get_node("ScoreManager/stageclearWhite2").visible = true
			get_parent().get_node("ScoreManager/stageclearblack").visible = true
			get_node("choosebuff").visible = true
			for i in range(4):
				get_parent().get_node("buffselectbutton"+str(i)).visible = true
			get_node("bossbgm").stop()
			get_parent().get_node("stagekirikae").play()
		elif(clearinterval<=160):
			pass
		else:
			get_parent().get_node("ScoreManager/stagechangeb").visible = true
		clearinterval += 1
		return
	if(isdeadf):
		if(deadinterval==100):
			if(stage_enemy!=5):
				get_node("movefront").visible = true
				get_node("choosebuff").visible = true
				for i in range(4):
					get_parent().get_node("buffselectbutton"+str(i)).visible = true
			clicked = false
		deadinterval += 1
		return
	make_enemy()
	displayhp()
	displaygage()
	interval += 1
	if(interval==40):
		get_parent().get_node("syutsugen").play()
	elif(interval==105):
		get_parent().get_node("kemuri").position = Vector2(-1e9,-1e9)
	appeartime += 1
	if(appeartime>=220&&appeartime<230&&isfevertime):
		get_parent().get_node("fevertime").stop()
		get_node("feverbgm").play()
	elif(appeartime>=230&&isfevertime):
		get_node("fieldbgm").stop()
		get_parent().get_node("ScoreManager/feverlabel").position = Vector2(-1e9,-1e9)
		get_parent().get_node("ScoreManager").get_node("feverrect").visible = true
		get_parent().get_node("ScoreManager").get_node("feverrect2").visible = true
		get_parent().get_node("ScoreManager").get_node("feverlabel2").visible = true
		get_parent().get_node("ScoreManager").get_node("feverlabel3").visible = true
		get_parent().get_node("ScoreManager").get_node("fevertime").visible = true
		get_parent().get_node("ScoreManager").get_node("fevertimecount").visible = true
		for i in range(facearr.size()):
			facearr[i].position.y += 10
		var nfacearr = []
		for i in range(facearr.size()):
			if(facearr[i].position.y>=4000):
				facearr[i].queue_free()
				facearr[i] = null
		for i in range(facearr.size()):
			if(facearr[i]!=null):
				nfacearr.append(facearr[i])
		facearr = nfacearr
		var adc = get_node("feverface").duplicate()
		adc.position = Vector2(randi()%14000,0)
		add_child(adc)
		facearr.append(adc)
	for i in range(5):
		get_node(stagehaikei[i]).visible = false
	get_node(stagehaikei[stage-1]).visible = true


func _on_stagechangeb_pressed() -> void:
	if(!isstageclear):
		return
	myhp *= 10
	myhpmax *= 10
	isstageclear = false
	stage_enemy = 1
	stage += 1
	if(label!=null):
		label_control()
		emit_signal("stage_clear")
	get_node("bossbgm").stop()
	get_parent().get_node("ScoreManager/stageclear").visible = false
	get_parent().get_node("ScoreManager/stagechangeb").visible = false
	get_parent().get_node("ScoreManager/stageclearWhite2").visible = false
	get_parent().get_node("ScoreManager/stageclearblack").visible = false
	get_node("choosebuff").visible = false
	for i in range(4):
		get_parent().get_node("buffselectbutton"+str(i)).visible = false
	make_enemy()
	add_stage_label()
	isdeadf = false
	clicked = true
	deadinterval = 0
	clearinterval = 0
	get_node("movefront").visible = false
	get_node("choosebuff").visible = false
	for i in range(4):
		get_parent().get_node("buffselectbutton"+str(i)).visible = false
	pass # Replace with function body.


func _on_movefront_pressed() -> void:
	if(!clicked):
		if(stage_enemy==4):
			isdanger = true
			dangerinterval = 0
		else:
			make_enemy()
			add_stage_label()
			isdeadf = false
			clicked = true
			deadinterval = 0
			get_node("movefront").visible = false
			get_node("choosebuff").visible = false
			for i in range(4):
				get_parent().get_node("buffselectbutton"+str(i)).visible = false
	pass # Replace with function body.
