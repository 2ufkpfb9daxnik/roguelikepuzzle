# BuffCard.gd
extends Button
 
signal buff_selected
 
# バフデータを保持する変数
var buff_data
var screen # 親ノード
var hbox # 表示する欄
var buffs # ランダムで決めるバフ
var picture # バフの絵
var original_picture # バフの絵の元
 
# 初期設定メソッド
func setup(data):
	buff_data = data
	# バフの情報を設定
	$Title.text = buff_data["name"]
	$Description.text = buff_data["description"]
	$Icon.texture = load(buff_data["icon_path"])
 
func _ready():
	screen = get_parent() # 親ノードを設定する
	hbox =screen.get_child(1) # HBoxContainerを設定する
	screen.visible = false # バフを選ぶ画面を隠す
 
# ボタンが押されたときにシグナルを発信
func _on_button_pressed():
	emit_signal("buff_selected", buff_data)
 
# ステージをクリアしたとき
func buff_selecter():
	screen.visible = true # バフを選ぶ画面を表示する
	buffs=[0, 0, 0, 0, 0, 0] # バフをランダムで選ぶ予定
	original_picture=get_child(0).texture # 元の画像を代入する
	var scale=Control.new()
	scale.set_custom_minimum_size(Vector2(128, 128))
	hbox.add_child(scale)
	for i in range(6):
		picture=TextureRect.new() # pictureをTextureRectとして作る
		picture.texture=original_picture # pictureの中身を元の画像にする
		picture.visible=true # pictureを表示する
		hbox.add_child(picture) # hboxに追加する
