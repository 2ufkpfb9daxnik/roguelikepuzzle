extends Node2D
var label :Label
var stage :int
var score :int
var board :Node2D
const stage_standard = [10000, 20000, 30000, 50000, 999999999999999]

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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void: # ずっとする
	score_check()
