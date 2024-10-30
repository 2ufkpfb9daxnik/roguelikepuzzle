extends Node2D
var label :Label
var stage :int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label = get_node("StageLabel")  # ScoreLabelの参照を取得
	if label != null:
		add_stage_label() 
	else:
		print("StageLabel ノードが見つかりません")

func add_stage_label() -> void:
	stage+=1
	if label != null:
		print(stage)
		label.text = "現在のステージ: " + str(stage)
	else:
		pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
