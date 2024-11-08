extends Control
# 表示/非表示を切り替えたいノードを取得します
@onready var color_rect = get_node("ColorRect")
@onready var hbox_container = get_node("HBoxContainer")
@onready var button = get_node("Button")

func _ready():
	# 初期状態で全てのノードを非表示に設定
	color_rect.visible = false
	hbox_container.visible = false
	button.visible = false
	
func show_ui(): # 見せる
	color_rect.visible = true
	hbox_container.visible = true
	button.visible = true

func hide_ui(): # 隠す
	color_rect.visible = false
	hbox_container.visible = false
	button.visible = false
	
func toggle_button():
	button.visible = !button.visible
