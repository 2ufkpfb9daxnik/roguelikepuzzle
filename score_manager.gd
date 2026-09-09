extends Node2D

## スコアおよび各種属性ポイント・コンボ・バフ購入を管理するクラス

# 駒の属性定義（他スクリプトと共通）
enum PieceType {
	SHIELD = 0,
	SWORD = 1,
	COIN = 2,
	POTION = 3,
	FOOD = 4,
}

# --- 公開プロパティ（他ノードから参照される変数） ---
var totalScore: int = 0
var divscore: Array = [0, 0, 0, 0, 0] # [SHIELD, SWORD, COIN, POTION, FOOD]
var combocount: int = 0
var iscombo: bool = false
var gridscore: Array = []

# バフ購入に必要なコインコスト（後方互換用）
var currentshieldcoin: int = 5000
var currentswordcoin: int = 5000
var currentcoincoin: int = 5000
var currentfoodcoin: int = 5000
var currentfevercoin: int = 3000
var currentbombcoin: int = 5000
var fever_boost_level: int = 0
var bomb_buff_level: int = 0

# ショップページ管理
var current_shop_page: int = 0
var is_shop_open: bool = false
var shop_page_container: HBoxContainer = null
var prev_page_btn: Button = null
var next_page_btn: Button = null
var page_indicator_lbl: Label = null

# 全バフ・特殊アイテムのカタログ定義
var stat_levels: Array[int] = [0, 0, 0, 0, 0] # 属性ごとのレベル [SHIELD, SWORD, COIN, POTION, FOOD]

var shop_items: Array[Dictionary] = [
	# --- ページ 1: 基本ステータス（レベルに応じて+〇） ---
	{
		"id": "shield",
		"type": "stat_shield",
		"name": "シールド\n+100",
		"desc": "消去時のシールド獲得量が上昇",
		"color": Color("#00E5FF"),
		"cost": 5000,
		"level": 0
	},
	{
		"id": "sword",
		"type": "stat_sword",
		"name": "攻撃\n+100",
		"desc": "消去時の敵ダメージが上昇",
		"color": Color("#FF5252"),
		"cost": 5000,
		"level": 0
	},
	{
		"id": "food",
		"type": "stat_food",
		"name": "回復\n+100",
		"desc": "消去時のHP回復量が上昇",
		"color": Color("#76FF03"),
		"cost": 5000,
		"level": 0
	},
	{
		"id": "coin",
		"type": "stat_coin",
		"name": "お金\n+100",
		"desc": "消去時のコイン獲得量が上昇",
		"color": Color("#FFD700"),
		"cost": 5000,
		"level": 0
	},
	{
		"id": "fever",
		"type": "stat_fever",
		"name": "フィーバー\n+10%",
		"desc": "フィーバースコア倍率が増加",
		"color": Color("#FF2E93"),
		"cost": 3000,
		"level": 0
	},
	{
		"id": "bomb",
		"type": "special_bomb",
		"name": "フレイムボム\n業火爆破",
		"desc": "炎: Lvで3x3➔5x5➔7x7拡大",
		"color": Color("#FF9100"),
		"cost": 10000,
		"level": 0
	},

	# --- ページ 2: 元素ケミストリー＆属性スペル ---
	{
		"id": "tornado",
		"type": "special_tornado",
		"name": "つむじ風/竜巻\n直進巻き上げ",
		"desc": "風: 直進してコマ一掃(木の耐久-1/-2)",
		"color": Color("#00E676"),
		"cost": 20000,
		"level": 0
	},
	{
		"id": "lightning",
		"type": "special_lightning",
		"name": "ライトニング\n落雷＆感電",
		"desc": "雷: 3➔5➔8発落雷(水たまり全体へ感電拡散)",
		"color": Color("#FFEA00"),
		"cost": 25000,
		"level": 0
	},
	{
		"id": "aqua_splash",
		"type": "special_aqua_splash",
		"name": "アクアスプラッシュ\n水浸し展開",
		"desc": "水: 周囲を水浸しに(雷感電＆苗の糧)",
		"color": Color("#00B0FF"),
		"cost": 18000,
		"level": 0
	},
	{
		"id": "tree_sprout",
		"type": "special_tree_sprout",
		"name": "生命の苗木\n吸水大木進化",
		"desc": "地: 水を吸って3x3大木へ進化＆毎ターン回復",
		"color": Color("#76FF03"),
		"cost": 30000,
		"level": 0
	},
	{
		"id": "cross_bomb",
		"type": "special_cross_bomb",
		"name": "クロスブレイズ\n十文字業火",
		"desc": "炎: 十字貫通火柱(木に引火で大延焼)",
		"color": Color("#FF3D00"),
		"cost": 35000,
		"level": 0
	},
	{
		"id": "color_converter",
		"type": "special_color_converter",
		"name": "フローラスプレー\n同色染め上げ",
		"desc": "地: 周囲を同一属性に塗り替える",
		"color": Color("#69F0AE"),
		"cost": 22000,
		"level": 0
	},

	# --- ページ 3: 究極奇跡スペル ---
	{
		"id": "black_hole",
		"type": "special_black_hole",
		"name": "ブラックホール\n重力渦巻吸引",
		"desc": "闇: 周囲を渦状に吸い込んで大消滅",
		"color": Color("#7C4DFF"),
		"cost": 100000,
		"level": 0
	},
	{
		"id": "disco_ball",
		"type": "special_disco_ball",
		"name": "スターオーブ\n同色全滅奇跡",
		"desc": "星: 画面中の同色全コマ一斉破壊",
		"color": Color("#E040FB"),
		"cost": 200000,
		"level": 0
	}
]

# --- 内部変数 ---
var health: float = 1.0
var interval: int = 0
var labelarr: Array[RichTextLabel] = []

const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")
const ATT_COLORS: Array[String] = [
	"#00E5FF", # SHIELD (クリスタルシアン)
	"#FF3D3D", # SWORD (バーニングレッド)
	"#FFD700", # COIN (スパークゴールド)
	"#FF2E93", # POTION (ネオンマゼンタ)
	"#76FF03", # FOOD (エナジーライム)
]

const TEXTURE_DIR: Array[String] = ["shield", "sword", "coin", "potion", "food"]
const TEXTURE_FILE: Array[String] = ["shield_cut", "sword_cut", "coin_cut", "potion_cut", "bread_cut"]

# ノード参照キャッシュ
@onready var label: RichTextLabel = get_node_or_null("RichTextLabel")
@onready var label2: RichTextLabel = get_node_or_null("RichTextLabel2")
@onready var status_rect: Control = get_node_or_null("status")
@onready var status2_rect: Control = get_node_or_null("status2")
@onready var combo_label: RichTextLabel = get_node_or_null("combo")
@onready var combocount_label: RichTextLabel = get_node_or_null("combocount")
@onready var template_score_label: RichTextLabel = get_node_or_null("RichTextLabel3")

var divscorelabel: Array[RichTextLabel] = []

## 3桁カンマ区切りの数値フォーマット
func _format_comma(value: int) -> String:
	var s = str(absi(value))
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return ("-" if value < 0 else "") + res

# 外部ノード（親経由）の遅延取得用ヘルパー
func _get_puzzle_board() -> Node2D:
	var p = get_parent()
	return p.get_node_or_null("PuzzleBoard") if p else null

func _get_stage_manager() -> Node2D:
	var p = get_parent()
	return p.get_node_or_null("StageManager") if p else null

func _ready() -> void:
	# フォントにシステム日本語フォールバックを設定（あらゆる漢字の確実な描画を保証）
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	# スコアラベルのフォント＆アウトライン設定
	if label != null:
		label.add_theme_font_override("normal_font", CUSTOM_FONT)
		label.add_theme_font_override("bold_font", CUSTOM_FONT)
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	if label2 != null:
		label2.text = ""

	for i in range(5):
		var score_lbl = get_node_or_null("score" + str(i)) as RichTextLabel
		if score_lbl:
			score_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			score_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			score_lbl.add_theme_constant_override("outline_size", 8)
			score_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			divscorelabel.append(score_lbl)
	
	var pb = _get_puzzle_board()
	var row_count: int = pb.grid_row if pb and "grid_row" in pb else 15
	var col_count: int = pb.grid_column if pb and "grid_column" in pb else 15
	
	gridscore.clear()
	for i in range(row_count):
		var columnscore: Array[int] = []
		for j in range(col_count):
			columnscore.append(-1)
		gridscore.append(columnscore)
	
	# コンボ表示のフォント＆スタイリング（明瞭でくっきり読めるSystemFontボールド＆前面表示を保証）
	var combo_font = SystemFont.new()
	combo_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Arial", "sans-serif"])
	combo_font.font_weight = 800

	if combo_label != null:
		combo_label.z_index = 2
		combo_label.add_theme_font_override("normal_font", combo_font)
		combo_label.add_theme_font_override("bold_font", combo_font)
		combo_label.add_theme_font_size_override("normal_font_size", 42)
		combo_label.add_theme_font_size_override("bold_font_size", 42)
		combo_label.add_theme_constant_override("outline_size", 4)
		combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	if combocount_label != null:
		combocount_label.z_index = 2
		combocount_label.add_theme_font_override("normal_font", combo_font)
		combocount_label.add_theme_font_override("bold_font", combo_font)
		combocount_label.add_theme_font_size_override("normal_font_size", 68)
		combocount_label.add_theme_font_size_override("bold_font_size", 68)
		combocount_label.add_theme_constant_override("outline_size", 6)
		combocount_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	# ステージクリア・ゲームクリア・フィーバーラベルのスタイリング（漢字・日本語を美しく保持）
	var sc_lbl = get_node_or_null("stageclear") as RichTextLabel
	if sc_lbl:
		sc_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
		sc_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
		sc_lbl.add_theme_constant_override("outline_size", 12)
		sc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		sc_lbl.text = "[center][b][color=#FFD700]★ ステージクリアー!! ★[/color][/b][/center]"

	var gc_lbl = get_node_or_null("GameClear") as RichTextLabel
	if gc_lbl:
		gc_lbl.position = Vector2(0, 310)
		gc_lbl.size = Vector2(1920, 240)
		gc_lbl.z_index = 50
		gc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gc_lbl.bbcode_enabled = true
		gc_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
		gc_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
		gc_lbl.add_theme_font_size_override("normal_font_size", 150)
		gc_lbl.add_theme_font_size_override("bold_font_size", 150)
		gc_lbl.add_theme_constant_override("outline_size", 24)
		gc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		gc_lbl.text = "[center][b][rainbow freq=0.5 sat=2 val=20]★ ゲームクリアー!! ★[/rainbow][/b][/center]"
	var gc_lbl2 = get_node_or_null("GameClear2") as RichTextLabel
	if gc_lbl2:
		gc_lbl2.visible = false
		gc_lbl2.text = ""

	var gcw = get_node_or_null("GameClearWhite") as ColorRect
	if gcw:
		gcw.position = Vector2(0, 0)
		gcw.size = Vector2(1920, 1080)
		gcw.z_index = 45
		gcw.color = Color(0.02, 0.02, 0.06, 0.88)
		gcw.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gc_btn = get_node_or_null("gameclearbutton") as Button
	if gc_btn:
		gc_btn.position = Vector2(740, 600)
		gc_btn.size = Vector2(440, 90)
		gc_btn.z_index = 51
		gc_btn.text = "タイトルへ"
		gc_btn.add_theme_font_override("font", CUSTOM_FONT)
		gc_btn.add_theme_font_size_override("font_size", 42)
		gc_btn.add_theme_constant_override("outline_size", 6)
		gc_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		gc_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))

		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.12, 0.12, 0.22, 0.95)
		style_normal.border_color = Color(1.0, 0.84, 0.0, 1.0)
		style_normal.set_border_width_all(4)
		style_normal.set_corner_radius_all(14)
		gc_btn.add_theme_stylebox_override("normal", style_normal)

		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.2, 0.2, 0.35, 1.0)
		style_hover.border_color = Color(1.0, 0.95, 0.3, 1.0)
		style_hover.set_border_width_all(4)
		style_hover.set_corner_radius_all(14)
		gc_btn.add_theme_stylebox_override("hover", style_hover)

	# フィーバータイム欄をコンボ欄（x: 34..372, y: 266..478）の真下に美しく配置
	var fv_rect = get_node_or_null("feverrect") as ColorRect
	if fv_rect:
		fv_rect.position = Vector2(34, 490)
		fv_rect.size = Vector2(338, 250)
	var fv_rect2 = get_node_or_null("feverrect2") as ColorRect
	if fv_rect2:
		fv_rect2.position = Vector2(38, 494)
		fv_rect2.size = Vector2(330, 242)

	var fv_lbl2 = get_node_or_null("feverlabel2") as RichTextLabel
	if fv_lbl2:
		fv_lbl2.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_lbl2.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_lbl2.add_theme_constant_override("outline_size", 8)
		fv_lbl2.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_lbl2.add_theme_font_size_override("normal_font_size", 24)
		fv_lbl2.add_theme_font_size_override("bold_font_size", 24)
		fv_lbl2.position = Vector2(38, 502)
		fv_lbl2.size = Vector2(330, 44)
		fv_lbl2.text = "[center][b][rainbow freq=0.8 sat=2 val=20]★ フィーバータイム ★[/rainbow][/b][/center]"

	var fv_lbl3 = get_node_or_null("feverlabel3") as RichTextLabel
	if fv_lbl3:
		fv_lbl3.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_lbl3.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_lbl3.add_theme_constant_override("outline_size", 8)
		fv_lbl3.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_lbl3.add_theme_font_size_override("normal_font_size", 24)
		fv_lbl3.add_theme_font_size_override("bold_font_size", 24)
		fv_lbl3.position = Vector2(38, 546)
		fv_lbl3.size = Vector2(330, 42)
		update_fever_label3()

	var fv_time = get_node_or_null("fevertime") as RichTextLabel
	if fv_time:
		fv_time.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_time.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_time.add_theme_constant_override("outline_size", 8)
		fv_time.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_time.add_theme_font_size_override("normal_font_size", 22)
		fv_time.add_theme_font_size_override("bold_font_size", 22)
		fv_time.position = Vector2(38, 590)
		fv_time.size = Vector2(330, 38)
		fv_time.text = "[center][b][color=#FFFFFF]残り手数[/color][/b][/center]"

	var fv_cnt = get_node_or_null("fevertimecount") as RichTextLabel
	if fv_cnt:
		fv_cnt.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_cnt.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_cnt.add_theme_constant_override("outline_size", 10)
		fv_cnt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_cnt.add_theme_font_size_override("normal_font_size", 52)
		fv_cnt.add_theme_font_size_override("bold_font_size", 52)
		fv_cnt.position = Vector2(38, 628)
		fv_cnt.size = Vector2(330, 95)

	var sc_btn = get_node_or_null("stagechangeb") as Button
	if sc_btn:
		sc_btn.add_theme_font_override("font", CUSTOM_FONT)
		sc_btn.add_theme_font_size_override("font_size", 30)
		sc_btn.add_theme_constant_override("outline_size", 6)
		sc_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))


	update_score_label()
	_setup_shop_page_controls()
	_update_buff_button_labels()

func damage() -> float:
	return float(divscore[PieceType.SHIELD])

## スコア表示と各属性ポイント表示の更新
func update_score_label() -> void:
	if label == null:
		return
		
	# 洗練されたゴールド＋ホワイトのスコア表示（漢字「得点」）
	label.text = "[b][color=#FFD700]得点 [/color][color=#FFFFFF]%s[/color][/b]" % _format_comma(totalScore)
	if label2 != null:
		label2.text = ""
	
	var max_len: int = 0
	for i in range(mini(5, divscorelabel.size())):
		var formatted_val = _format_comma(divscore[i])
		max_len = maxi(max_len, formatted_val.length())
		divscorelabel[i].text = "[img=60]res://Texture/%s/%s.png[/img] [b][color=%s]%s[/color][/b]" % [
			TEXTURE_DIR[i], TEXTURE_FILE[i], ATT_COLORS[i], formatted_val
		]

	# 桁数に応じたステータス枠の横幅自動追従
	var frame_width = maxf(120.0 + 22.0 * float(max_len), 120.0)
	if status_rect != null:
		status_rect.size = Vector2(frame_width + 5.0, 275)
	if status2_rect != null:
		status2_rect.size = Vector2(frame_width, 271)

	if combocount_label != null:
		combocount_label.text = "[center][b][color=#FFD700]%d[/color][/b][/center]" % combocount
	if combo_label != null:
		combo_label.text = "[center][b][color=#00E5FF]COMBO[/color][/b][/center]"

## マッチしたセルにポップアップスコア表示を生成 (Tweenによる自律アニメーション)
func display_score_label() -> void:
	# calcscore 内の _spawn_score_popup で直接スタイリッシュに生成するため互換維持
	pass

## マッチした駒グループにスタイリッシュなスコアポップアップを生成
func _spawn_score_popup(component_cells: Array[Vector2i], att_type: int, earned_score: int, count: int, is_fever: bool) -> void:
	if template_score_label == null:
		template_score_label = get_node_or_null("RichTextLabel3")
	if template_score_label == null:
		return

	var popup: RichTextLabel = template_score_label.duplicate()
	popup.bbcode_enabled = true
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_override("normal_font", CUSTOM_FONT)
	popup.add_theme_font_override("bold_font", CUSTOM_FONT)
	popup.add_theme_constant_override("outline_size", 8)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	popup.add_theme_font_size_override("normal_font_size", 34)
	popup.add_theme_font_size_override("bold_font_size", 38)
	popup.fit_content = true
	popup.autowrap_mode = TextServer.AUTOWRAP_OFF

	var col = ATT_COLORS[att_type % 5]
	var header = ""
	if is_fever:
		header = "[center][b][rainbow freq=0.8 sat=2 val=20]★FEVER!!★[/rainbow][/b][/center]\n"
	elif combocount >= 2:
		header = "[center][b][color=#00E5FF]%d COMBO![/color][/b][/center]\n" % combocount
	elif count >= 5:
		header = "[center][b][color=#FF1493]★EXCELLENT!!★[/color][/b][/center]\n"
	elif count == 4:
		header = "[center][b][color=#FFD700]GREAT![/color][/b][/center]\n"

	var score_text = "[center][b][color=%s]+%d[/color][/b][/center]" % [col, earned_score]
	popup.text = header + score_text

	# グループの中心座標を計算（画面座標: セル中心は c * 50 + 450, r * 50 + 150）
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	for cell in component_cells:
		sum_x += cell.y * 50.0 + 450.0
		sum_y += cell.x * 50.0 + 150.0
	var center_pos = Vector2(sum_x / float(count), sum_y / float(count))

	popup.size = Vector2(300.0, 100.0)
	popup.pivot_offset = Vector2(150.0, 50.0)
	popup.position = center_pos - popup.pivot_offset
	popup.scale = Vector2(0.2, 0.2)
	popup.modulate.a = 1.0
	popup.z_index = 25
	add_child(popup)

	# ポップアップ・Tweenアニメーション（勢いよく飛び出してフワッと消える）
	var p_tween = create_tween()
	p_tween.tween_property(popup, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p_tween.parallel().tween_property(popup, "position:y", popup.position.y - 20.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p_tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.08)

	p_tween.chain().tween_interval(0.35)
	p_tween.tween_property(popup, "position:y", popup.position.y - 45.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p_tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.22)
	p_tween.chain().tween_callback(popup.queue_free)

## マッチした駒のスコアおよび属性ポイントを計算
func calcscore(match_index: Array, grid_att: Array) -> void:
	var rows: int = match_index.size()
	if rows == 0:
		return
	var cols: int = match_index[0].size()
	
	var visited: Array = []
	for i in range(rows):
		var row_visited: Array[bool] = []
		row_visited.resize(cols)
		row_visited.fill(false)
		visited.append(row_visited)
	
	var pb = _get_puzzle_board()
	var multipliers = [1.0, 1.0, 1.0, 1.0, 1.0]
	if pb:
		multipliers = [pb.shieldt, pb.swordt, pb.coint, pb.potiont, pb.foodt]
	
	var sm = _get_stage_manager()
	var is_fever: bool = sm.isfevertime if sm and "isfevertime" in sm else false

	# マッチしたセルの連結成分を探索しスコアを付与
	for i in range(rows):
		for j in range(cols):
			if match_index[i][j] and not visited[i][j]:
				var att_type: int = grid_att[i][j]
				var component_cells: Array[Vector2i] = []
				
				# BFSで同じ属性の連結マッチ駒を収集
				_collect_connected_match_cells(i, j, att_type, match_index, grid_att, visited, component_cells)
				
				var count: int = component_cells.size()
				if count <= 0:
					continue
					
				var base_score: int = maxi(count * 100, count * (count - 2) * 100)
				
				# レベルに応じて+〇 (1レベルにつき +100 * 消去コマ数の固定加算ボーナス)
				var bonus_add: int = (stat_levels[att_type] * 100 * count) if att_type < stat_levels.size() else 0
				var mult: float = multipliers[att_type] if att_type < multipliers.size() else 1.0
				# コンボ倍率ボーナス (連鎖が続くほど指数的に大逆転ボーナス！中毒性UP)
				var combo_mult: float = 1.0 + maxf(0.0, float(combocount - 1)) * 0.25
				var earned_score: int = maxi(100 * count, int((int(base_score * mult) + bonus_add) * combo_mult))
				
				totalScore += earned_score
				
				# スタイリッシュなスコアポップアップを生成
				_spawn_score_popup(component_cells, att_type, earned_score, count, is_fever)
				
				# フィーバータイム時は属性獲得量が倍率アップ（通常2倍 ＋ バフによるボーナス）
				var fv_rate: float = (2.0 + fever_boost_level * 0.5) if is_fever else 1.0
				var gain: int = int(earned_score * fv_rate)
				if att_type < divscore.size():
					divscore[att_type] += gain

## 幅優先探索 (BFS) で同じ属性の連結したマッチ駒を探索
func _collect_connected_match_cells(start_r: int, start_c: int, target_att: int, match_index: Array, grid_att: Array, visited: Array, out_cells: Array[Vector2i]) -> void:
	var queue: Array[Vector2i] = [Vector2i(start_r, start_c)]
	visited[start_r][start_c] = true
	var rows: int = match_index.size()
	var cols: int = match_index[0].size()
	
	var directions = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		out_cells.append(curr)
		
		for dir in directions:
			var nr: int = curr.x + dir.x
			var nc: int = curr.y + dir.y
			if nr >= 0 and nr < rows and nc >= 0 and nc < cols:
				if not visited[nr][nc] and match_index[nr][nc] and grid_att[nr][nc] == target_att:
					visited[nr][nc] = true
					queue.append(Vector2i(nr, nc))

## コンボテキストの演出更新
func combo() -> void:
	if not iscombo:
		return
	if interval == 0:
		if combocount_label != null:
			var c_tween = create_tween()
			combocount_label.scale = Vector2(1.35, 1.35)
			combocount_label.pivot_offset = combocount_label.size / 2.0
			c_tween.tween_property(combocount_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if combo_label != null:
			var l_tween = create_tween()
			combo_label.scale = Vector2(1.15, 1.15)
			combo_label.pivot_offset = combo_label.size / 2.0
			l_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 3連鎖以上で中央カットインバースト演出
		if combocount >= 3:
			_spawn_combo_burst_effect(combocount)

	if interval <= 36:
		var bounce: float = float((interval - 18) * (interval - 18)) / 10.0 - 33.0
		if combo_label != null:
			combo_label.position.y = 280.0 + bounce * 0.6
		if combocount_label != null:
			combocount_label.position.y = 350.0 + bounce * 0.6
	else:
		iscombo = false
		interval = 0
		if combo_label != null: combo_label.position.y = 280.0
		if combocount_label != null: combocount_label.position.y = 350.0
	interval += 1

## 特大コンボ・アチーブメント演出（中央カットインバースト）
func _spawn_combo_burst_effect(combo_num: int) -> void:
	if combo_num < 3:
		return

	var burst_lbl = RichTextLabel.new()
	burst_lbl.bbcode_enabled = true
	burst_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst_lbl.fit_content = true
	burst_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	burst_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
	burst_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
	burst_lbl.add_theme_constant_override("outline_size", 12)
	burst_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	var text_content = ""
	var font_sz = 52
	var pb = _get_puzzle_board()

	if combo_num >= 10:
		font_sz = 68
		text_content = "[center][b][rainbow freq=1.2 sat=2 val=20]★ ULTRA OVERDRIVE!! ★\n%d COMBO!![/rainbow][/b][/center]" % combo_num
		if pb and pb.has_method("_trigger_screen_shake"):
			pb._trigger_screen_shake(50.0)
	elif combo_num >= 7:
		font_sz = 60
		text_content = "[center][b][color=#FF1744]🔥 MEGA CHAIN!! 🔥[/color]\n[color=#FFD700]%d COMBO!![/color][/b][/center]" % combo_num
		if pb and pb.has_method("_trigger_screen_shake"):
			pb._trigger_screen_shake(35.0)
	elif combo_num >= 5:
		font_sz = 54
		text_content = "[center][b][color=#FFD700]⚡ GREAT COMBO!! ⚡[/color]\n[color=#00E5FF]%d COMBO![/color][/b][/center]" % combo_num
		if pb and pb.has_method("_trigger_screen_shake"):
			pb._trigger_screen_shake(20.0)
	elif combo_num >= 3:
		font_sz = 46
		text_content = "[center][b][color=#00E5FF]★ COOL COMBO! ★[/color]\n[color=#FFFFFF]%d COMBO[/color][/b][/center]" % combo_num

	burst_lbl.add_theme_font_size_override("normal_font_size", font_sz)
	burst_lbl.add_theme_font_size_override("bold_font_size", font_sz)
	burst_lbl.text = text_content
	burst_lbl.size = Vector2(800, 180)
	burst_lbl.pivot_offset = burst_lbl.size * 0.5
	burst_lbl.position = Vector2(560, 420)
	burst_lbl.z_index = 45
	add_child(burst_lbl)

	burst_lbl.scale = Vector2(0.2, 0.2)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(burst_lbl, "scale", Vector2(1.15, 1.15), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(burst_lbl, "position:y", burst_lbl.position.y - 45.0, 0.65)
	tw.tween_property(burst_lbl, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(burst_lbl.queue_free)

func _process(_delta: float) -> void:
	# ショップボタンの価格表示を更新
	_update_buff_button_labels()
	
	update_score_label()
	display_score_label()
	combo()
	_update_popup_labels()

## ショップUIのページ送りコントロール生成
func _setup_shop_page_controls() -> void:
	var parent = get_parent()
	if parent == null: return

	var jp_font = SystemFont.new()
	jp_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
	jp_font.font_weight = 700

	if shop_page_container == null:
		shop_page_container = HBoxContainer.new()
		# ショップ欄の幅 (0〜1170px) の中央に配置し、価格表示 (y=853〜936) 直下の y=955 に配置
		shop_page_container.position = Vector2(0, 955)
		shop_page_container.size = Vector2(1170, 60)
		shop_page_container.alignment = BoxContainer.ALIGNMENT_CENTER
		shop_page_container.add_theme_constant_override("separation", 24)
		shop_page_container.z_index = 25
		shop_page_container.visible = false
		shop_page_container.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child.call_deferred(shop_page_container)

	if prev_page_btn == null:
		prev_page_btn = Button.new()
		prev_page_btn.text = "◀ 前のページ"
		prev_page_btn.custom_minimum_size = Vector2(180, 56)
		prev_page_btn.add_theme_font_override("font", jp_font)
		prev_page_btn.add_theme_font_size_override("font_size", 22)
		prev_page_btn.pressed.connect(_on_prev_page_pressed)
		shop_page_container.add_child(prev_page_btn)

	if page_indicator_lbl == null:
		page_indicator_lbl = Label.new()
		page_indicator_lbl.text = "ページ 1 / 3"
		page_indicator_lbl.custom_minimum_size = Vector2(160, 56)
		page_indicator_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page_indicator_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page_indicator_lbl.add_theme_font_override("font", jp_font)
		page_indicator_lbl.add_theme_font_size_override("font_size", 26)
		page_indicator_lbl.add_theme_color_override("font_color", Color("#FFD700"))
		page_indicator_lbl.add_theme_constant_override("outline_size", 6)
		page_indicator_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		shop_page_container.add_child(page_indicator_lbl)

	if next_page_btn == null:
		next_page_btn = Button.new()
		next_page_btn.text = "次のページ ▶"
		next_page_btn.custom_minimum_size = Vector2(180, 56)
		next_page_btn.add_theme_font_override("font", jp_font)
		next_page_btn.add_theme_font_size_override("font_size", 22)
		next_page_btn.pressed.connect(_on_next_page_pressed)
		shop_page_container.add_child(next_page_btn)

func _on_prev_page_pressed() -> void:
	var total_pages = int(ceil(float(shop_items.size()) / 6.0))
	current_shop_page = (current_shop_page - 1 + total_pages) % total_pages
	_update_buff_button_labels()
	var click_se = get_parent().get_node_or_null("click")
	if click_se: click_se.play()

func _on_next_page_pressed() -> void:
	var total_pages = int(ceil(float(shop_items.size()) / 6.0))
	current_shop_page = (current_shop_page + 1) % total_pages
	_update_buff_button_labels()
	var click_se = get_parent().get_node_or_null("click")
	if click_se: click_se.play()

func set_shop_ui_visible(is_vis: bool) -> void:
	is_shop_open = is_vis
	if shop_page_container: shop_page_container.visible = is_vis
	if prev_page_btn: prev_page_btn.visible = is_vis
	if page_indicator_lbl: page_indicator_lbl.visible = is_vis
	if next_page_btn: next_page_btn.visible = is_vis
	var parent = get_parent()
	if parent:
		for i in range(6):
			var btn = parent.get_node_or_null("buffselectbutton" + str(i))
			if btn:
				if not is_vis:
					btn.visible = false
				else:
					var item_idx = current_shop_page * 6 + i
					btn.visible = (item_idx < shop_items.size())
	_update_buff_button_labels()

## バフ選択ボタンのラベル更新
func _update_buff_button_labels() -> void:
	var parent = get_parent()
	if parent == null:
		return

	var total_pages = int(ceil(float(shop_items.size()) / 6.0))
	if page_indicator_lbl:
		page_indicator_lbl.text = "ページ %d / %d" % [current_shop_page + 1, total_pages]

	var label_names = ["shieldlabel2", "swordlabel2", "foodlabel2", "coinlabel2", "feverlabel2", "bomblabel2"]
	var desc_names = ["shieldlabel", "swordlabel", "foodlabel", "coinlabel", "feverlabel", "bomblabel"]

	var jp_font = SystemFont.new()
	jp_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
	jp_font.font_weight = 700

	for i in range(6):
		var btn = parent.get_node_or_null("buffselectbutton" + str(i))
		if btn == null:
			continue

		var item_idx = current_shop_page * 6 + i
		if item_idx >= shop_items.size():
			btn.visible = false
			continue

		# ショップが開いているときのみ表示（勝手に表示されるバグを防止）
		btn.visible = is_shop_open

		var item = shop_items[item_idx]

		var desc_lbl = btn.get_node_or_null(desc_names[i]) as Label
		if desc_lbl:
			desc_lbl.add_theme_font_override("font", jp_font)
			desc_lbl.add_theme_font_size_override("font_size", 30)
			desc_lbl.add_theme_constant_override("outline_size", 8)
			desc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			desc_lbl.add_theme_color_override("font_color", item["color"])
			desc_lbl.position = Vector2(0, 155)
			desc_lbl.size = Vector2(390, 145)
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			var title_text = item["name"]
			if item["id"] in ["shield", "sword", "food", "coin"]:
				var base_name = {"shield": "シールド", "sword": "攻撃", "food": "回復", "coin": "お金"}[item["id"]]
				var cur_lvl: int = item["level"]
				title_text = "%s\n+%d" % [base_name, (cur_lvl + 1) * 100]
				if cur_lvl > 0:
					title_text += " (Lv%d)" % cur_lvl
			elif item["level"] > 0:
				title_text += " (Lv%d)" % item["level"]
			desc_lbl.text = title_text

		var lbl = btn.get_node_or_null(label_names[i]) as RichTextLabel
		if lbl:
			if not lbl.has_theme_font_override("normal_font"):
				lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
				lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
				lbl.add_theme_constant_override("outline_size", 6)
				lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
				lbl.add_theme_font_size_override("normal_font_size", 28)
				lbl.add_theme_font_size_override("bold_font_size", 28)
			lbl.text = "[center][img=45]res://Texture/coin/coin_cut.png[/img] [b][color=#FFD700]%s[/color][/b][/center]" % _format_comma(item["cost"])

## スコアポップアップのアニメーションおよびフェード処理
func _update_popup_labels() -> void:
	var remaining_labels: Array[RichTextLabel] = []
	for lbl in labelarr:
		if lbl == null or not is_instance_valid(lbl):
			continue
			
		if lbl.modulate.a <= 0.95:
			lbl.position.y -= 2.0
		else:
			lbl.scale -= Vector2(0.1, 0.1)
			lbl.position += Vector2(0.6, 0.6)
		
		if lbl.modulate.a > 0.0:
			var alpha_cube = lbl.modulate.a * lbl.modulate.a * lbl.modulate.a
			lbl.modulate.a -= (0.005 / alpha_cube) * 0.9
		
		if lbl.modulate.a <= 0.0:
			lbl.queue_free()
		else:
			remaining_labels.append(lbl)
			
	labelarr = remaining_labels

## バフ購入の共通処理
func _purchase_buff(slot_idx: int) -> void:
	var item_idx = current_shop_page * 6 + slot_idx
	if item_idx < 0 or item_idx >= shop_items.size():
		return

	var item = shop_items[item_idx]
	var cost_ref: int = item["cost"]
	var coin_amount = divscore[PieceType.COIN]
	var parent = get_parent()
	var pb = _get_puzzle_board()

	if coin_amount >= cost_ref:
		divscore[PieceType.COIN] -= cost_ref
		item["cost"] = int(cost_ref * 1.3) # 購入ごとに1.3倍
		item["level"] += 1

		# 各タイプごとの適用およびレベル反映
		match item["type"]:
			"stat_shield":
				currentshieldcoin = item["cost"]
				stat_levels[PieceType.SHIELD] += 1
			"stat_sword":
				currentswordcoin = item["cost"]
				stat_levels[PieceType.SWORD] += 1
			"stat_food":
				currentfoodcoin = item["cost"]
				stat_levels[PieceType.FOOD] += 1
			"stat_coin":
				currentcoincoin = item["cost"]
				stat_levels[PieceType.COIN] += 1
			"stat_fever":
				currentfevercoin = item["cost"]
				fever_boost_level += 1
				if pb: pb.fever_bonus_multiplier = fever_boost_level * 0.5
				update_fever_label3()
			"special_bomb":
				currentbombcoin = item["cost"]
				bomb_buff_level += 1
				if pb: pb.special_levels[pb.SpecialItemType.BOMB] = item["level"]
			"special_cross_bomb":
				if pb: pb.special_levels[pb.SpecialItemType.CROSS_BOMB] = item["level"]
			"special_tornado":
				if pb: pb.special_levels[pb.SpecialItemType.TORNADO] = item["level"]
			"special_lightning":
				if pb: pb.special_levels[pb.SpecialItemType.LIGHTNING] = item["level"]
			"special_aqua_splash":
				if pb: pb.special_levels[pb.SpecialItemType.AQUA_SPLASH] = item["level"]
			"special_tree_sprout":
				if pb:
					pb.special_levels[pb.SpecialItemType.TREE_SPROUT] = item["level"]
					if pb.has_method("_plant_sprout_on_board"):
						pb._plant_sprout_on_board()
			"special_color_converter":
				if pb: pb.special_levels[pb.SpecialItemType.COLOR_CONVERTER] = item["level"]
			"special_black_hole":
				if pb: pb.special_levels[pb.SpecialItemType.BLACK_HOLE] = item["level"]
			"special_disco_ball":
				if pb: pb.special_levels[pb.SpecialItemType.DISCO_BALL] = item["level"]
			"special_magnet":
				if pb: pb.special_levels[pb.SpecialItemType.MAGNET] = item["level"]

		var sound = parent.get_node_or_null("coinsound") if parent else null
		if sound: sound.play()
		_update_buff_button_labels()
	else:
		var cancel_sound = parent.get_node_or_null("cancel") if parent else null
		if cancel_sound: cancel_sound.play()

func update_fever_label3() -> void:
	var fv_lbl3 = get_node_or_null("feverlabel3") as RichTextLabel
	if fv_lbl3:
		var mult: float = 2.0 + fever_boost_level * 0.5
		if fposmod(mult, 1.0) == 0.0:
			fv_lbl3.text = "[center][b][color=#FFD700]スコア%d倍[/color][/b][/center]" % int(mult)
		else:
			fv_lbl3.text = "[center][b][color=#FFD700]スコア%.1f倍[/color][/b][/center]" % mult

# シーン側から接続されるボタンイベントハンドラ
func _on_buffselectbutton_0_pressed() -> void:
	_purchase_buff(0)

func _on_buffselectbutton_1_pressed() -> void:
	_purchase_buff(1)

func _on_buffselectbutton_2_pressed() -> void:
	_purchase_buff(2)

func _on_buffselectbutton_3_pressed() -> void:
	_purchase_buff(3)

func _on_buffselectbutton_4_pressed() -> void:
	_purchase_buff(4)

func _on_buffselectbutton_5_pressed() -> void:
	_purchase_buff(5)
