extends Control
#
#var buffs = [] # 表示するバフ情報のリスト
#
## バフ選択画面を初期化
#func _ready():
	#$ColorRect.visible = true
	#show_buff_choices()
#
## バフカードを表示するメソッド
#func show_buff_choices():
	#for buff in buffs:
		#var buff_card = preload("res://BuffCard.tscn").instance()
		#buff_card.setup(buff)  # BuffCardの設定
		#buff_card.connect("buff_selected", self, "_on_buff_selected")
		#$HBoxContainer.add_child(buff_card)
#
## バフカード選択時の処理
#func _on_buff_selected(selected_buff):
	#apply_buff(selected_buff)
	#$ColorRect.visible = false
	#$HBoxContainer.queue_free()  # バフカードを削除
	#emit_signal("buff_selection_complete")  # ステージ再開のシグナル
