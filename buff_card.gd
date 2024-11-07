# BuffCard.gd
extends Button

signal buff_selected

# バフデータを保持する変数
var buff_data

# 初期設定メソッド
func setup(data):
	buff_data = data
	# バフの情報を設定
	$Title.text = buff_data["name"]
	$Description.text = buff_data["description"]
	$Icon.texture = load(buff_data["icon_path"])

# ボタンが押されたときにシグナルを発信
func _on_button_pressed():
	emit_signal("buff_selected", buff_data)

# ステージをクリアしたとき
func buff_selecter():
	print("buff_selecterの実行に成功")
