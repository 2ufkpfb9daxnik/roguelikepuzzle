extends CanvasLayer
class_name TutorialManager

## 初心者向け実践チュートリアル案内マネージャー
## 説明欄パネル方式を廃止し、対象（盤面マス・敵・UI）をスポットライトで注目させ、
## 案内役(feverdance/instructor.png)を対象の横に配置して指差し、案内役の【右】に吹き出しで説明を表示する
## 説明はページ分割され、画面のどこをクリックしても次のページへ進む
## 行動（攻撃発射・敵の反撃）は説明表示中に発生し、act_state で待機中は次ステップへ進まない

const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")
const INSTRUCTOR_PATH: String = "res://Texture/instructor.png"

signal tutorial_completed
signal tutorial_returned_to_title

const BUBBLE_W: float = 660.0
const INS_W: float = 168.0
const INS_H: float = 196.0
const BUBBLE_GAP: float = 16.0  # 案内役と吹き出しの水平間隔
const BTN_H: float = 46.0
const BTN_ROW_W: float = 622.0
const MARGIN: float = 12.0
const SIDE_GAP: float = 24.0
const ROW_GAP_Y: float = 40.0  # 注目対象と案内役ユニットの垂直間隔

## スポットライト演出（注目領域を残した暗幕＋発光枠＋指差し矢印）
class SpotlightOverlay extends Control:
	var focus_rect: Rect2 = Rect2()
	var has_focus: bool = false
	var arrow_from: Vector2 = Vector2.ZERO
	var arrow_to: Vector2 = Vector2.ZERO
	var has_arrow: bool = false
	var pulse_t: float = 0.0

	func _process(delta: float) -> void:
		pulse_t += delta
		queue_redraw()

	func _draw() -> void:
		var sz: Vector2 = size
		if not has_focus:
			draw_rect(Rect2(Vector2.ZERO, sz), Color(0.01, 0.02, 0.05, 0.35))
			return
		var dim := Color(0.01, 0.02, 0.05, 0.55)
		var f := focus_rect
		var fy0 := clampf(f.position.y, 0.0, sz.y)
		var fy1 := clampf(f.position.y + f.size.y, 0.0, sz.y)
		var fx0 := clampf(f.position.x, 0.0, sz.x)
		var fx1 := clampf(f.position.x + f.size.x, 0.0, sz.x)
		if fy0 > 0.0:
			draw_rect(Rect2(0.0, 0.0, sz.x, fy0), dim)
		if fy1 < sz.y:
			draw_rect(Rect2(0.0, fy1, sz.x, sz.y - fy1), dim)
		if fx0 > 0.0:
			draw_rect(Rect2(0.0, fy0, fx0, maxf(0.0, fy1 - fy0)), dim)
		if fx1 < sz.x:
			draw_rect(Rect2(fx1, fy0, sz.x - fx1, maxf(0.0, fy1 - fy0)), dim)
		var pulse := 0.5 + 0.5 * sin(pulse_t * 5.0)
		draw_rect(f.grow(5.0), Color(1.0, 0.84, 0.31, 0.30 + 0.40 * pulse), false, 7.0)
		draw_rect(f.grow(5.0), Color(1.0, 0.93, 0.60, 0.95), false, 2.5)
		if has_arrow and arrow_from.distance_to(arrow_to) > 12.0:
			var alpha := 0.65 + 0.35 * pulse
			var col := Color(1.0, 0.84, 0.31, alpha)
			draw_line(arrow_from, arrow_to, col, 7.0, true)
			var dir := (arrow_to - arrow_from).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var base := arrow_to - dir * 24.0
			var tri := PackedVector2Array([arrow_to, base + perp * 15.0, base - perp * 15.0])
			draw_colored_polygon(tri, Color(1.0, 0.84, 0.31, minf(1.0, alpha + 0.1)))

enum Step {
	INTRO_MOVE1 = 0,         # 盤面第1手指示 (剣3個消し)
	ITEMS_SCORED = 1,        # アイテム値加算・4大リソース順次解説
	ATTACK_LANDED = 2,       # 敵への攻撃命中・ダメージ解説
	ENEMY_ATTACKED = 3,      # 敵の行動予兆(NEXT)と敵攻撃解説
	MOVE2_DEFEAT = 4,        # 盤面第2手指示 (剣3個消しで2ターン目敵撃破)
	RELIC_SELECTION = 5,     # レリック選択 (説明文・辞書単語・中央レリック選択)
	SHOP_COIN = 6,           # ショップ (コイン強化解説・スキルツリータブ誘導)
	SKILL_TREE = 7,          # スキルツリー解説 (+1000万ポーション付与・最左スキルLv10へ)
	SKILL_EVOLUTION = 8,     # スキル進化 (中間進化の選択と解説)
	PROCEED_STAGE = 9,       # 前に進むボタン押下指示
	STAGE2_SKILL_GEN = 10,   # 第2ステージ開始・ポーション4個消しで最左スキル生成指示
	ENEMY_SKILL = 11,        # 敵スキル発動解説・スキル使用指示
	VICTORY_COMPLETE = 12    # スキル発動・敵撃破・チュートリアル完了
}

## 行動待ち状態（解説表示中にゲーム側で完了を待つ行動）
enum ActState {
	NONE,   # 行動待ちなし
	ATTACK, # 「攻撃発射 ▶」押下済み・剣の着弾待ち
	ENEMY   # 敵の反撃が解説表示中に実行中
}

## 各ステップが「プレイヤーの行動待ち」か（最終ページでも次へ進まない＝盤面操作へ移行）
const STEP_WAITS: Dictionary = {
	0: true,   # INTRO_MOVE1: 1手目のスワップ待ち
	1: false,  # ITEMS_SCORED: 最終ページで攻撃発射
	2: false,  # ATTACK_LANDED: 最終ページで敵行動解説へ
	3: false,  # ENEMY_ATTACKED: 敵行動完了後、最終ページで第2手へ
	4: true,   # MOVE2_DEFEAT
	5: true,   # RELIC_SELECTION
	6: true,   # SHOP_COIN
	7: true,   # SKILL_TREE
	8: true,   # SKILL_EVOLUTION
	9: true,   # PROCEED_STAGE
	10: true,  # STAGE2_SKILL_GEN
	11: true,  # ENEMY_SKILL
	12: false, # VICTORY_COMPLETE: 完了ボタン専用
}

var current_step: int = 0
var current_page: int = 0
var is_minimized: bool = false
var step_wait_for_action: bool = false
var act_state: int = ActState.NONE
var is_waiting_for_steady: bool = false
var _items_scored_received: bool = false
var _enemy_acted_in_stage2: bool = false
var _skill_detonated_in_stage2: bool = false
var _saw_aqua_piece: bool = false

var overlay: SpotlightOverlay = null
var bubble: Panel = null
var instructor_box: Panel = null
var mini_bar: Panel = null

var avatar_rect: TextureRect = null
var avatar_fallback_label: RichTextLabel = null
var instructor_tex: Texture2D = null

var step_badge_lbl: RichTextLabel = null
var step_title_lbl: RichTextLabel = null
var content_lbl: RichTextLabel = null

var prev_btn: Button = null
var next_btn: Button = null
var minimize_btn: Button = null
var complete_btn: Button = null
var return_to_title_btn: Button = null

var mini_title_lbl: RichTextLabel = null
var mini_expand_btn: Button = null

var _bb_re: RegEx = null
var _bub_h_cache_key: int = -1
var _bub_h_cache: float = 300.0

# チュートリアル全13ステップ データ（「」内の台詞のみを簡潔・大文字で表示）
const TUTORIAL_STEPS: Array[Dictionary] = [
	{
		"badge": "ステップ 1 / 13：目的と第1手",
		"title": "【ゲームの目的】パズルで敵を討伐しよう！",
		"pages": [
			"[color=#FFD54F]「ようこそ！パズルで力を引き出し、敵を討伐することがあなたの目的です！」[/color]",
			"[color=#FFD54F]「光っている剣の駒を右に動かして、3つ並べてみましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 2 / 13：アイテム効果の解説",
		"title": "【主要ルール】消去で獲得できる4つの基本アイテム",
		"pages": [
			"[color=#64FFDA]「見事です！駒を3つ揃えるとアイテムを獲得できます！」[/color]",
			"[color=#FF5252]「⚔️ 剣：敵に直接物理ダメージを与えます！」[/color]",
			"[color=#40C4FF]「🛡️ 盾：シールドを獲得し、敵の攻撃を防ぎます！」[/color]",
			"[color=#FFD700]「💰 コイン：ショップで強化やアイテム購入に使えます！」[/color]",
			"[color=#69F0AE]「🧪 ポーション：HPを回復し、スキルの強化に使えます！」[/color]",
			"[color=#FFD54F]「準備ができたら、『攻撃発射』を押して攻撃しましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 3 / 13：攻撃命中とダメージ",
		"title": "【攻撃命中】敵の体力を削ろう！",
		"pages": [
			"[color=#64FFDA]「ナイスショット！敵のHPバーに注目してください。体力が減少しています！」[/color]",
			"[color=#FFD54F]「敵のHPを0にすると討伐できます！次は敵の反撃を見守りましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 4 / 13：敵の行動予兆と攻撃",
		"title": "【失敗条件と判断のポイント】敵の予兆を見極めよう！",
		"pages": [
			"[color=#FF5252]「敵が反撃してきます！頭上の『次の行動 (NEXT)』で攻撃の予兆を見極めましょう！」[/color]",
			"[color=#40C4FF]「強力な攻撃が迫るターンには、盾を揃えてシールドを張ることが判断のポイントです！」[/color]",
			"[color=#FF8A80]「味方のHPが0になるとゲームオーバーです！耐えきったらトドメを刺しましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 5 / 13：第2手・敵討伐",
		"title": "【第2手】2ターン目で敵を撃破しよう！",
		"pages": [
			"[color=#FFD54F]「光っている剣の駒を右へ動かして、敵を撃破しましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 6 / 13：レリック選択",
		"title": "【レリック選択】冒険を支える秘宝を獲得！",
		"pages": [
			"[color=#64FFDA]「敵の撃破に成功しました！勝利報酬として【レリック（秘宝）】が手に入ります！」[/color]",
			"[color=#00E5FF]「下線付きの単語にマウスを合わせると、用語解説がポップアップします！」[/color]",
			"[color=#FFD700]「真ん中の【自然・生命系スキル解放権】をクリックして選択してください！」[/color]"
		]
	},
	{
		"badge": "ステップ 7 / 13：ショップ（コイン強化）",
		"title": "【ショップ】コインで能力を恒久強化！",
		"pages": [
			"[color=#64FFDA]「集めたコインを使って、ステータスを恒久強化できるショップです！」[/color]",
			"[color=#00E5FF]「上部の『🌿 スキルツリー』タブをクリックしてスキル画面へ移動しましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 8 / 13：スキルツリーとLv.10強化",
		"title": "【スキルツリー】固有スキルの習得と強化！",
		"pages": [
			"[color=#64FFDA]「ここがスキルツリーです！強化用ポーションを10,000,000付与しました！」[/color]",
			"[color=#00E5FF]「左端のスキル『清流展開』の強化ボタンを押して、Lv.10まで上げてください！」[/color]"
		]
	},
	{
		"badge": "ステップ 9 / 13：スキル進化（中間進化）",
		"title": "【スキル進化】スキルの聖像に新たな効果を付与！",
		"pages": [
			"[color=#64FFDA]「Lv.10に達して【スキル進化】が可能になりました！新たな効果が付与されます！」[/color]",
			"[color=#FFD700]「好きな進化カードを1枚クリックして決定してください！」[/color]"
		]
	},
	{
		"badge": "ステップ 10 / 13：次のステージへ進む",
		"title": "【ステージ進行】強化完了！次なる戦場へ！",
		"pages": [
			"[color=#FFD700]「右下の『⚔️ 前に進む』ボタンを押して、第2ステージへ出陣しましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 11 / 13：スキルの盤面生成",
		"title": "【第2ステージ】レシピを揃えてスキル駒を生成しよう！",
		"pages": [
			"[color=#FF5252]「第2ステージです！『清流展開』は【ポーション4個消し】で盤面に生成されます！」[/color]",
			"[color=#69F0AE]「光っている駒を下へスワップして、ポーションを横に4個揃えてみましょう！」[/color]"
		]
	},
	{
		"badge": "ステップ 12 / 13：敵スキルと自軍スキル発動",
		"title": "【敵スキル襲来】水属性スキルを発動して敵を一掃せよ！",
		"pages": [
			"[color=#FF5252]「敵がスキルで攻撃してきました！手元に生成された水スキル駒で対抗しましょう！」[/color]",
			"[color=#00E5FF]「盤面の水属性スキル駒をクリックして発動し、敵を一掃してください！」[/color]"
		]
	},
	{
		"badge": "チュートリアル完了！",
		"title": "【完全制覇】冒険の基礎をすべてマスター！",
		"pages": [
			"[b][color=#64FFDA]「お見事です！冒険の基礎をすべて習得しました！『完了（タイトルへ戻る）』を押して、新たな冒険へ旅立ちましょう！」[/color][/b]"
		]
	}
]

func _ready() -> void:
	layer = 120
	set_process_input(true) # クリックによる説明ページ送りを受け取る
	_load_instructor_texture()
	_setup_ui()
	_update_step_content()
	_update_layout()

	if get_viewport():
		get_viewport().size_changed.connect(_update_layout)

	call_deferred("_connect_game_signals")
	call_deferred("_start_current_step_logic")

func _load_instructor_texture() -> void:
	if ResourceLoader.exists(INSTRUCTOR_PATH):
		instructor_tex = load(INSTRUCTOR_PATH) as Texture2D

func _setup_ui() -> void:
	overlay = SpotlightOverlay.new()
	overlay.name = "TutorialSpotlight"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	bubble = Panel.new()
	bubble.name = "TutorialBubble"
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.05, 0.07, 0.13, 0.96)
	b_style.border_color = Color(0.92, 0.76, 0.25, 1.0)
	b_style.set_border_width_all(3)
	b_style.set_corner_radius_all(16)
	b_style.shadow_color = Color(0, 0, 0, 0.7)
	b_style.shadow_size = 14
	bubble.add_theme_stylebox_override("panel", b_style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)

	step_badge_lbl = RichTextLabel.new()
	step_badge_lbl.name = "StepBadge"
	step_badge_lbl.bbcode_enabled = true
	step_badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CUSTOM_FONT:
		step_badge_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
		step_badge_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
	bubble.add_child(step_badge_lbl)

	step_title_lbl = RichTextLabel.new()
	step_title_lbl.name = "StepTitle"
	step_title_lbl.bbcode_enabled = true
	step_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CUSTOM_FONT:
		step_title_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
		step_title_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
	bubble.add_child(step_title_lbl)

	content_lbl = RichTextLabel.new()
	content_lbl.name = "StepContent"
	content_lbl.bbcode_enabled = true
	content_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_lbl.scroll_active = true
	var sys_jp = SystemFont.new()
	sys_jp.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "sans-serif"])
	content_lbl.add_theme_font_override("normal_font", sys_jp)
	content_lbl.add_theme_font_override("bold_font", sys_jp)
	content_lbl.add_theme_font_size_override("normal_font_size", 24)
	content_lbl.add_theme_font_size_override("bold_font_size", 24)
	content_lbl.add_theme_constant_override("line_separation", 6)
	bubble.add_child(content_lbl)

	instructor_box = Panel.new()
	instructor_box.name = "InstructorBox"
	var av_style = StyleBoxFlat.new()
	av_style.bg_color = Color(0.03, 0.04, 0.08, 0.90)
	av_style.border_color = Color(0.4, 0.75, 0.65, 0.9)
	av_style.set_border_width_all(2)
	av_style.set_corner_radius_all(12)
	av_style.shadow_color = Color(0, 0, 0, 0.6)
	av_style.shadow_size = 8
	instructor_box.add_theme_stylebox_override("panel", av_style)
	instructor_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(instructor_box)

	avatar_rect = TextureRect.new()
	avatar_rect.name = "InstructorAvatar"
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if instructor_tex != null:
		avatar_rect.texture = instructor_tex
		avatar_rect.visible = true
	else:
		avatar_rect.visible = false
	instructor_box.add_child(avatar_rect)

	avatar_fallback_label = RichTextLabel.new()
	avatar_fallback_label.name = "AvatarFallback"
	avatar_fallback_label.bbcode_enabled = true
	avatar_fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CUSTOM_FONT:
		avatar_fallback_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		avatar_fallback_label.add_theme_font_override("bold_font", CUSTOM_FONT)
	avatar_fallback_label.text = "[center][font_size=44]🎓[/font_size]\n\n[b][color=#FFD700]INSTRUCTOR[/color][/b]\n[color=#80CBC4]案内役[/color][/center]"
	avatar_fallback_label.visible = (instructor_tex == null)
	instructor_box.add_child(avatar_fallback_label)

	prev_btn = _create_btn("◀ 前へ", Color(0.12, 0.14, 0.22, 0.95), Color(0.4, 0.6, 0.8, 1.0))
	prev_btn.pressed.connect(_on_prev_pressed)
	add_child(prev_btn)

	next_btn = _create_btn("次へ ▶", Color(0.12, 0.28, 0.20, 0.95), Color(0.3, 0.9, 0.5, 1.0))
	next_btn.pressed.connect(_on_next_pressed)
	add_child(next_btn)

	minimize_btn = _create_btn("👁 盤面を操作", Color(0.14, 0.16, 0.26, 0.95), Color(0.4, 0.8, 1.0, 1.0))
	minimize_btn.name = "MinimizeButton"
	minimize_btn.pressed.connect(_toggle_minimize)
	add_child(minimize_btn)

	complete_btn = _create_btn("🏠 タイトルへ戻る", Color(0.12, 0.28, 0.20, 0.95), Color(0.3, 0.9, 0.5, 1.0))
	complete_btn.name = "TitleReturnButton"
	complete_btn.pressed.connect(_return_to_title)
	add_child(complete_btn)
	return_to_title_btn = complete_btn

	mini_bar = Panel.new()
	mini_bar.name = "TutorialMiniBar"
	var mb_style = StyleBoxFlat.new()
	mb_style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	mb_style.border_color = Color(0.92, 0.76, 0.25, 1.0)
	mb_style.set_border_width_all(2)
	mb_style.set_corner_radius_all(10)
	mini_bar.add_theme_stylebox_override("panel", mb_style)
	mini_bar.visible = false
	add_child(mini_bar)

	mini_title_lbl = RichTextLabel.new()
	mini_title_lbl.bbcode_enabled = true
	mini_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_title_lbl.position = Vector2(20, 8)
	mini_title_lbl.size = Vector2(580, 32)
	if CUSTOM_FONT: mini_title_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
	mini_bar.add_child(mini_title_lbl)

	mini_expand_btn = _create_btn("📖 解説を開く", Color(0.12, 0.28, 0.20, 0.95), Color(0.3, 0.9, 0.5, 1.0))
	mini_expand_btn.position = Vector2(610, 6)
	mini_expand_btn.size = Vector2(170, 40)
	mini_expand_btn.pressed.connect(_toggle_minimize)
	mini_bar.add_child(mini_expand_btn)

func _create_btn(text_val: String, bg_c: Color, border_c: Color) -> Button:
	var btn = Button.new()
	btn.text = text_val
	if CUSTOM_FONT:
		btn.add_theme_font_override("font", CUSTOM_FONT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))

	var st = StyleBoxFlat.new()
	st.bg_color = bg_c
	st.border_color = border_c
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", st)

	var h_st = st.duplicate()
	h_st.bg_color = bg_c.lightened(0.18)
	btn.add_theme_stylebox_override("hover", h_st)

	var d_st = st.duplicate()
	d_st.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	d_st.border_color = Color(0.3, 0.3, 0.3, 0.5)
	btn.add_theme_stylebox_override("disabled", d_st)
	return btn

func _estimate_content_height(txt: String) -> float:
	if _bb_re == null:
		_bb_re = RegEx.new()
		_bb_re.compile("\\[[^\\]]*\\]")
	var plain: String = _bb_re.sub(txt, "", true)
	var lines: float = 0.0
	for ln in plain.split("\n"):
		lines += maxf(1.0, ceilf(float(ln.length()) / 24.0))
	return clampf(lines * 34.0 + 30.0, 90.0, 360.0)

## ゲームオブジェクト（盤面・ステージ等）のシグナル連携
func _connect_game_signals() -> void:
	var parent = get_parent()
	if parent == null: return

	var pb = parent.get_node_or_null("PuzzleBoard")
	if pb:
		if pb.has_signal("tutorial_swap_completed") and not pb.tutorial_swap_completed.is_connected(_on_pb_swap_completed):
			pb.tutorial_swap_completed.connect(_on_pb_swap_completed)
		if pb.has_signal("tutorial_items_scored") and not pb.tutorial_items_scored.is_connected(_on_pb_items_scored):
			pb.tutorial_items_scored.connect(_on_pb_items_scored)
		if pb.has_signal("tutorial_attack_landed") and not pb.tutorial_attack_landed.is_connected(_on_pb_attack_landed):
			pb.tutorial_attack_landed.connect(_on_pb_attack_landed)
		if pb.has_signal("tutorial_enemy_acted") and not pb.tutorial_enemy_acted.is_connected(_on_pb_enemy_acted):
			pb.tutorial_enemy_acted.connect(_on_pb_enemy_acted)
		if pb.has_signal("tutorial_special_detonated") and not pb.tutorial_special_detonated.is_connected(_on_pb_special_detonated):
			pb.tutorial_special_detonated.connect(_on_pb_special_detonated)

## PuzzleBoard への参照（未接続時は null）
func _get_pb() -> Node:
	var parent = get_parent()
	if parent == null: return null
	return parent.get_node_or_null("PuzzleBoard")

## StageManager への参照（未接続時は null）
func _get_sm() -> Node:
	var parent = get_parent()
	if parent == null: return null
	return parent.get_node_or_null("StageManager")

## 指定ステップの解説ページ一覧
func _step_page_list(step_idx: int) -> Array:
	var out: Array = []
	if step_idx >= 0 and step_idx < TUTORIAL_STEPS.size():
		var pgs = TUTORIAL_STEPS[step_idx].get("pages")
		if pgs is Array and not pgs.is_empty():
			out = pgs
	if out.is_empty():
		out = [""]
	return out

## 現在ステップの解説ページ一覧
func _step_pages() -> Array:
	return _step_page_list(current_step)

## 現在の解説が最終ページか
func _is_on_last_page() -> bool:
	return current_page >= _step_pages().size() - 1

## 次へ/前へボタンの文言・有効状態を「ページ位置×行動待ち」から再計算
func _refresh_next_button() -> void:
	var pages := _step_pages()
	var on_last := current_page >= pages.size() - 1
	if act_state != ActState.NONE:
		if next_btn:
			next_btn.disabled = true
			next_btn.text = "攻撃発射中…" if act_state == ActState.ATTACK else "敵の行動中…"
	elif not on_last:
		if next_btn:
			next_btn.disabled = false
			next_btn.text = "次へ ▶"
	elif current_step == Step.ITEMS_SCORED:
		if next_btn:
			next_btn.disabled = false
			next_btn.text = "攻撃発射 ▶"
	elif current_step >= TUTORIAL_STEPS.size() - 1:
		if next_btn:
			next_btn.disabled = false
			next_btn.text = "✓ 完了（タイトルへ戻る）"
		if complete_btn:
			complete_btn.disabled = false
			complete_btn.text = "🏠 タイトルへ戻る"
	else:
		if next_btn:
			next_btn.text = "次へ ▶"
			next_btn.disabled = step_wait_for_action
	if prev_btn:
		prev_btn.disabled = act_state != ActState.NONE or (current_step == 0 and current_page == 0)

## ステップ遷移（ページ先頭に戻して内容更新＋ゲーム側ロジック実行）
func _goto_step(step_idx: int) -> void:
	is_waiting_for_steady = false
	current_step = clampi(step_idx, 0, TUTORIAL_STEPS.size() - 1)
	current_page = 0
	if current_step == Step.ENEMY_SKILL:
		_saw_aqua_piece = false
		_skill_detonated_in_stage2 = false
	_update_step_content()
	_start_current_step_logic()

## 画面クリックによる説明送り・行動開始（自前ボタン上は GUI に委譲）
func _input(event: InputEvent) -> void:
	if is_minimized or is_waiting_for_steady: return
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed: return

	# 行動待ち中は入力を封鎖（最小化ボタンのみ利用可能）
	if act_state != ActState.NONE:
		if minimize_btn and minimize_btn.visible and minimize_btn.get_global_rect().has_point(mb.position):
			return
		_consume_input(event)
		return

	# 有効な自前ボタン上は通常の GUI 処理へ委譲（二重発火防止）
	if _is_over_enabled_button(mb.position): return

	var pages := _step_pages()
	if current_page < pages.size() - 1:
		# どこをクリックしても説明の次のページへ
		current_page += 1
		_update_step_content()
		_consume_input(event)
		return
	if current_step >= TUTORIAL_STEPS.size() - 1:
		# 最終ステップの最終ページは完了ボタン専用（誤タップで実戦へ進まない）
		_consume_input(event)
		return
	if step_wait_for_action:
		# 行動待ちステップの最終ページ：クリックは盤面・ゲームUIへそのまま渡す
		# ただし吹き出し・案内役の上では誤操作で盤面へ抜けないよう消費する
		if _is_over_own_panel(mb.position):
			_consume_input(event)
		return
	# 通常ステップの最終ページ：クリックでも「次へ」と同じ遷移を行う
	_on_next_pressed()
	_consume_input(event)

func _consume_input(event: InputEvent) -> void:
	var vp := get_viewport()
	if vp: vp.set_input_as_handled()

## 有効な自前ボタンにマウスが乗っているか
func _is_over_enabled_button(pos: Vector2) -> bool:
	for b in [prev_btn, next_btn, minimize_btn, complete_btn, mini_expand_btn]:
		if b is Button and (b as Button).visible and not (b as Button).disabled and (b as Button).get_global_rect().has_point(pos):
			return true
	return false

## 吹き出し・案内役パネルにマウスが乗っているか
func _is_over_own_panel(pos: Vector2) -> bool:
	for b in [bubble, instructor_box]:
		if b is Control and (b as Control).visible and (b as Control).get_global_rect().has_point(pos):
			return true
	return false

## 各ステップごとの制御ロジック実行
func _start_current_step_logic() -> void:
	var parent = get_parent()
	var pb = parent.get_node_or_null("PuzzleBoard") if parent else null
	var score_mgr = parent.get_node_or_null("ScoreManager") if parent else null

	match current_step:
		Step.INTRO_MOVE1:
			# 第1手：(0, 2) の剣を右 (0, 3) へスワップして3個消し（ページ1以降のみ操作許可）
			if pb:
				if current_page > 0:
					pb.set_tutorial_allowed_swap(Vector2i(0, 2), Vector2i(0, 3))
				else:
					pb.clear_tutorial_allowed_swap()
				if pb.is_turn_sequence_running():
					# 前のステップから巻き戻った場合：進行中のターンを走らせて待機状態へ戻す
					pb.resume_tutorial_turn()

		Step.ITEMS_SCORED:
			# 攻撃は説明の最終ページから発射。それまではターンを止めて解説に集中させる
			if pb: pb.pause_tutorial_turn()

		Step.ATTACK_LANDED:
			# 着弾結果の確認中はターンを停止。敵の反撃は次のステップで解説表示中に実行する
			if pb: pb.pause_tutorial_turn()

		Step.ENEMY_ATTACKED:
			# 遷移時に act_state == ENEMY でターンが進行中（resume は遷移側で実施）
			pass

		Step.MOVE2_DEFEAT:
			# 第2手：(0, 9) の剣を右 (0, 10) へスワップして3個消し、敵を撃破！
			if pb:
				pb.resume_tutorial_turn()
				if pb.has_method("setup_tutorial_move2_board"):
					pb.setup_tutorial_move2_board()
				else:
					pb.set_tutorial_allowed_swap(Vector2i(0, 9), Vector2i(0, 10))

		Step.SKILL_TREE:
			# ポーションを10,000,000加算！
			if score_mgr and "divscore" in score_mgr and score_mgr.divscore.size() > 3:
				score_mgr.divscore[3] += 10000000
				if score_mgr.has_method("_update_buff_button_labels"):
					score_mgr._update_buff_button_labels()

		Step.STAGE2_SKILL_GEN:
			# 第2ステージ：(1, 4) のポーションを下 (2, 4) へスワップしてポーション4個消し！
			if pb:
				pb.setup_tutorial_stage2_board()

		Step.VICTORY_COMPLETE:
			# チュートリアル完了：敵撃破後の実戦進行・ショップ出現を阻止し、タイトル帰還を待機
			var sm_stage = _get_sm()
			if sm_stage:
				if sm_stage.choose_buff_rect: sm_stage.choose_buff_rect.visible = false
				if sm_stage.move_front_btn: sm_stage.move_front_btn.visible = false
				if sm_stage.has_method("_set_buff_buttons_visible"):
					sm_stage._set_buff_buttons_visible(false)
			var pb_fin = _get_pb()
			if pb_fin and pb_fin.has_method("clear_tutorial_allowed_swap"):
				pb_fin.clear_tutorial_allowed_swap()

		_:
			pass

	_refresh_next_button()
	_update_layout()

## プレイヤー行動（スワイプ・スキル発動等）開始時に案内一式を一時的に隠す
func _hide_guidance_for_action() -> void:
	is_waiting_for_steady = true
	_set_column_visible(false)
	if overlay: overlay.visible = false
	if mini_bar: mini_bar.visible = false

## 盤面が定常状態（静止・連鎖終了・演出完了）にあるか判定
func _is_board_settled(pb: Node) -> bool:
	if pb == null or not is_instance_valid(pb):
		return true
	if pb.has_method("is_steady_state") and pb.is_steady_state():
		return true
	var falling = pb.get("falling_pieces")
	if falling is Array and not falling.is_empty():
		return false
	var flying = pb.get("flying_cells")
	if flying is Array and not flying.is_empty():
		return false
	var is_sw = pb.get("isswap")
	if is_sw == true:
		return false
	var is_brk = pb.get("isbreak")
	if is_brk == true:
		return false
	var is_paused = pb.get("is_tutorial_paused")
	if is_paused == true:
		return true
	for proj_name in ["flying_swords", "flying_foods", "flying_potions", "active_shields"]:
		var projs = pb.get(proj_name)
		if projs is Array and not projs.is_empty():
			return false
	var is_en_turn = pb.get("is_enemy_turn_in_progress")
	if is_en_turn == true:
		return false
	var b_state = pb.get("current_state")
	if b_state != null and int(b_state) == 0:
		return true
	return false

## 盤面スワップ完了受信（次シグナル：ターン開始時の tutorial_items_scored 等を待つ）
func _on_pb_swap_completed(_c1: Vector2i, _c2: Vector2i) -> void:
	_hide_guidance_for_action()
	if current_step == Step.MOVE2_DEFEAT:
		if content_lbl:
			content_lbl.text = "[color=#64FFDA]「ナイススワップ！ 剣が敵へ向かって飛んでいきます！」[/color]"

## アイテム加算受信（ターン開始時）→ アイテム解説へ遷移
func _on_pb_items_scored() -> void:
	if current_step == Step.INTRO_MOVE1:
		var pb = _get_pb()
		if pb:
			pb.pause_tutorial_turn()
		_items_scored_received = false
		is_waiting_for_steady = false
		_goto_step(Step.ITEMS_SCORED)

## 攻撃着弾受信 → 「着弾済み」の事後解説へ遷移（攻撃は解説表示中に完了している）
func _on_pb_attack_landed() -> void:
	if current_step == Step.ITEMS_SCORED:
		act_state = ActState.NONE
		_goto_step(Step.ATTACK_LANDED)
	elif current_step == Step.MOVE2_DEFEAT:
		if content_lbl:
			content_lbl.text = "[color=#64FFDA]「大ダメージ命中！ 敵を撃破しました！」[/color]"

## 敵行動完了受信
func _on_pb_enemy_acted() -> void:
	if current_step == Step.STAGE2_SKILL_GEN:
		act_state = ActState.NONE
		var pb = _get_pb()
		if pb == null or _is_board_settled(pb):
			is_waiting_for_steady = false
			_goto_step(Step.ENEMY_SKILL)
		else:
			_enemy_acted_in_stage2 = true
			_hide_guidance_for_action()
		return
	if act_state == ActState.ATTACK:
		# 着弾通知が届かないままターンが終了した場合の保険：待ちを解除して再発射可能に戻す
		act_state = ActState.NONE
		var pb0 = _get_pb()
		if pb0: pb0.pause_tutorial_turn()
		_refresh_next_button()
		return
	if current_step == Step.ENEMY_ATTACKED:
		# 解説表示中に敵の反撃が完了 → 待ちを解除（ステップは進めない＝読み終えるまで次へ進まない）
		act_state = ActState.NONE
		var pb1 = _get_pb()
		if pb1: pb1.pause_tutorial_turn()
		_refresh_next_button()

## 特殊アイテム発動受信（水スキルで敵撃破）
func _on_pb_special_detonated(_sp_type: int) -> void:
	if current_step == Step.ENEMY_SKILL or current_step == Step.STAGE2_SKILL_GEN:
		_skill_detonated_in_stage2 = true
		var pb = _get_pb()
		if pb == null or _is_board_settled(pb):
			is_waiting_for_steady = false
			_goto_step(Step.VICTORY_COMPLETE)
		else:
			_hide_guidance_for_action()

## レリック選択UIの検出ヘルパー（RelicUIManager は除外）
func _find_relic_ui(parent_node: Node) -> Node:
	if parent_node == null: return null
	var r = parent_node.find_child("RelicSelectionUI", true, false)
	if r != null and is_instance_valid(r) and not r.is_queued_for_deletion() and not (r is RelicUIManager) and r.name != "RelicUIManager":
		return r
	if is_inside_tree() and get_tree() and get_tree().get_root():
		var r_root = get_tree().get_root().find_child("RelicSelectionUI", true, false)
		if r_root != null and is_instance_valid(r_root) and not r_root.is_queued_for_deletion() and not (r_root is RelicUIManager) and r_root.name != "RelicUIManager":
			return r_root
	for ch in parent_node.get_children():
		if not is_instance_valid(ch) or ch.is_queued_for_deletion():
			continue
		if ch is RelicUIManager or ch.name == "RelicUIManager":
			continue
		if ch is RelicSelectionUI or ch.name == "RelicSelectionUI" or ch.name.begins_with("RelicSelection"):
			return ch
	return null

func _process(_delta: float) -> void:
	var parent = get_parent()
	if parent == null: return
	var sm = parent.get_node_or_null("StageManager")
	var score_mgr = parent.get_node_or_null("ScoreManager")

	# 行動待ちのままターンが進行不能（盤面が停止・未接続）なら詰まり防止のため待ち解除
	if act_state != ActState.NONE:
		var pbw = _get_pb()
		if pbw == null or not pbw.is_turn_sequence_running():
			act_state = ActState.NONE
			_refresh_next_button()

	# ステップ進行の監視
	if current_step == Step.INTRO_MOVE1:
		if _items_scored_received:
			var pb_node = _get_pb()
			if pb_node == null or _is_board_settled(pb_node):
				_items_scored_received = false
				is_waiting_for_steady = false
				_goto_step(Step.ITEMS_SCORED)
		elif is_waiting_for_steady:
			var pb_node = _get_pb()
			if pb_node != null and _is_board_settled(pb_node) and pb_node.is_turn_sequence_running():
				is_waiting_for_steady = false
				_goto_step(Step.ITEMS_SCORED)

	elif current_step == Step.MOVE2_DEFEAT:
		# レリック選択UIが開いたか監視（ショップ先行開放時はフォールバックで遷移）
		var r_ui = _find_relic_ui(parent)
		var shop_open = (score_mgr and "is_shop_open" in score_mgr and score_mgr.is_shop_open)
		if r_ui != null or shop_open:
			var pb_node = _get_pb()
			if pb_node == null or _is_board_settled(pb_node):
				is_waiting_for_steady = false
				_goto_step(Step.RELIC_SELECTION)

	elif current_step == Step.RELIC_SELECTION:
		# レリック選択UIが閉じ、ショップが開いたか監視
		var r_ui2 = _find_relic_ui(parent)
		if r_ui2 == null and score_mgr and "is_shop_open" in score_mgr and score_mgr.is_shop_open:
			_goto_step(Step.SHOP_COIN)

	elif current_step == Step.SHOP_COIN:
		# スキルツリータブ（view_mode == 1）に切り替わったか監視
		if score_mgr and "current_view_mode" in score_mgr and score_mgr.current_view_mode == 1:
			_goto_step(Step.SKILL_TREE)

	elif current_step == Step.SKILL_TREE:
		# 進化モーダルが開いたか監視
		var tarot_modal = parent.find_child("TarotEvolutionModal", true, false)
		if tarot_modal != null:
			_goto_step(Step.SKILL_EVOLUTION)

	elif current_step == Step.SKILL_EVOLUTION:
		# 進化モーダルが閉じたか監視
		var tarot_modal2 = parent.find_child("TarotEvolutionModal", true, false)
		if tarot_modal2 == null:
			_goto_step(Step.PROCEED_STAGE)

	elif current_step == Step.PROCEED_STAGE:
		# ステージ2へ突入したか監視
		if sm and "stage" in sm and sm.stage >= 2:
			_goto_step(Step.STAGE2_SKILL_GEN)

	elif current_step == Step.STAGE2_SKILL_GEN:
		if _enemy_acted_in_stage2:
			var pb_node = _get_pb()
			if pb_node == null or _is_board_settled(pb_node):
				_enemy_acted_in_stage2 = false
				is_waiting_for_steady = false
				_goto_step(Step.ENEMY_SKILL)

	elif current_step == Step.ENEMY_SKILL:
		var pb_node = _get_pb()
		var has_aqua = false
		if pb_node:
			var aqua_rect = _aqua_piece_rect(pb_node)
			if aqua_rect.size.x >= 2.0:
				_saw_aqua_piece = true
				has_aqua = true

		# スキル駒が消去されたか（発動シグナル受信、盤面から消滅、または敵撃破）
		var skill_cleared = _skill_detonated_in_stage2
		if _saw_aqua_piece and not has_aqua:
			skill_cleared = true
		if sm and (("ehp" in sm and sm.ehp <= 0.0) or ("isdeadf" in sm and sm.isdeadf)):
			skill_cleared = true

		if skill_cleared:
			if not _is_board_settled(pb_node):
				_hide_guidance_for_action()
			else:
				is_waiting_for_steady = false
				_skill_detonated_in_stage2 = false
				_goto_step(Step.VICTORY_COMPLETE)

	# 行動完了後の定常状態復帰（スワップ後等でステップが進まない場合の案内復帰）
	if is_waiting_for_steady:
		var pb_check = _get_pb()
		if pb_check != null and _is_board_settled(pb_check):
			if current_step != Step.INTRO_MOVE1 and current_step != Step.MOVE2_DEFEAT and current_step != Step.STAGE2_SKILL_GEN:
				var has_aqua_check = (_aqua_piece_rect(pb_check).size.x >= 2.0)
				if current_step == Step.ENEMY_SKILL and has_aqua_check and not _skill_detonated_in_stage2:
					is_waiting_for_steady = false
					_update_layout()

	# 対象の出現・移動に追従して注目演出を毎フレーム更新
	_update_layout()

## ステップ内容の表示更新
func _update_step_content() -> void:
	if current_step < 0: current_step = 0
	if current_step >= TUTORIAL_STEPS.size(): current_step = TUTORIAL_STEPS.size() - 1

	var data = TUTORIAL_STEPS[current_step]
	var pages := _step_pages()
	current_page = clampi(current_page, 0, pages.size() - 1)
	step_wait_for_action = bool(STEP_WAITS.get(current_step, true))

	var badge_txt := str(data["badge"])
	if pages.size() > 1:
		badge_txt += "[color=#B0BEC5]　（%d / %d ページ）[/color]" % [current_page + 1, pages.size()]
	if step_badge_lbl:
		step_badge_lbl.text = "[color=#FFD54F][font_size=18]◆ " + badge_txt + "[/font_size][/color]"
	if step_title_lbl:
		step_title_lbl.text = "[b][font_size=22][color=#FFFFFF]" + str(data["title"]) + "[/color][/font_size][/b]"
	if content_lbl:
		content_lbl.text = str(pages[current_page])

	if current_step == Step.INTRO_MOVE1:
		var pb_sw = _get_pb()
		if pb_sw:
			if current_page > 0:
				pb_sw.set_tutorial_allowed_swap(Vector2i(0, 2), Vector2i(0, 3))
			else:
				pb_sw.clear_tutorial_allowed_swap()

	_refresh_next_button()

	if mini_title_lbl:
		mini_title_lbl.text = "[color=#FFD54F]📖 チュートリアル：[/color] [b]" + str(data["title"]) + "[/b]"

	_update_layout()

func _on_prev_pressed() -> void:
	if act_state != ActState.NONE: return
	if current_page > 0:
		current_page -= 1
		_update_step_content()
		return
	if current_step > 0:
		_goto_step(current_step - 1)

func _on_next_pressed() -> void:
	if act_state != ActState.NONE: return
	var pages := _step_pages()
	if current_page < pages.size() - 1:
		# まずは説明の次のページへ（行動は最終ページまで進まない）
		current_page += 1
		_update_step_content()
		return

	if current_step == Step.ITEMS_SCORED:
		# 剣の攻撃を発射 → 着弾まで act_state = ATTACK。その間もこの解説は表示したまま
		var pb = _get_pb()
		if pb != null and not pb.is_turn_sequence_running():
			# ターンが既に終了している（巻き戻り移動後）場合は着弾を待てないため直接事後解説へ
			_goto_step(Step.ATTACK_LANDED)
			return
		if pb: pb.resume_tutorial_turn()
		act_state = ActState.ATTACK
		_refresh_next_button()
		return

	if current_step == Step.ATTACK_LANDED:
		# 敵の反撃を「敵の行動」解説の表示中に実行させる
		var pb2 = _get_pb()
		var turn_live: bool = pb2 == null or pb2.is_turn_sequence_running()
		act_state = ActState.ENEMY if turn_live else ActState.NONE
		_goto_step(Step.ENEMY_ATTACKED)
		if pb2 and turn_live: pb2.resume_tutorial_turn()
		_refresh_next_button()
		return

	if current_step >= TUTORIAL_STEPS.size() - 1:
		_return_to_title()
		return

	if step_wait_for_action: return
	_goto_step(current_step + 1)

## 最小化トグル切り替え
func _toggle_minimize() -> void:
	is_minimized = !is_minimized
	_update_layout()

## タイトル画面へ戻る（チュートリアル終了時・実戦継続の防止）
func _return_to_title() -> void:
	emit_signal("tutorial_completed")
	emit_signal("tutorial_returned_to_title")

	var sm: Node = null
	if is_inside_tree() and get_tree() and get_tree().get_root():
		sm = get_tree().get_root().find_child("SettingsManager", true, false)
	if not sm:
		sm = get_node_or_null("/root/SettingsManager")
	if sm and "is_tutorial_mode" in sm:
		sm.is_tutorial_mode = false

	var parent = get_parent()
	var pb = parent.get_node_or_null("PuzzleBoard") if parent else null
	if pb:
		if pb.has_method("clear_tutorial_allowed_swap"):
			pb.clear_tutorial_allowed_swap()
		pb.is_tutorial_mode = false

	Engine.time_scale = 1.0

	var tree = get_tree()
	if tree:
		var title_packed = load("res://title_screen.tscn")
		if title_packed:
			tree.change_scene_to_packed(title_packed)
		else:
			tree.change_scene_to_file("res://title_screen.tscn")
	else:
		queue_free()

## 互換用：実戦への継続を防止し、確実にタイトルへ戻る
func _on_complete_tutorial() -> void:
	_return_to_title()

## ノードのローカルRectをスクリーン座標Rectへ変換
func _screen_rect(item: CanvasItem, local_rect: Rect2) -> Rect2:
	if item == null or not is_instance_valid(item): return Rect2()
	if not item.is_inside_tree():
		return Rect2(item.position + local_rect.position, local_rect.size)
	var t: Transform2D = item.get_global_transform_with_canvas()
	var p1: Vector2 = t * local_rect.position
	var p2: Vector2 = t * (local_rect.position + local_rect.size)
	return Rect2(p1, p2 - p1).abs()

func _control_rect(c: Control) -> Rect2:
	if c == null or not is_instance_valid(c): return Rect2()
	if not c.visible: return Rect2()
	var s: Vector2 = c.size
	if s.x < 2.0 or s.y < 2.0:
		s = c.get_combined_minimum_size()
	if s.x < 2.0 or s.y < 2.0: return Rect2()
	return _screen_rect(c, Rect2(Vector2.ZERO, s))

## 複数セルの統合Rect（盤面スクリーン座標）
func _cells_rect(pb: Node, cells: Array) -> Rect2:
	if pb == null or not is_instance_valid(pb): return Rect2()
	if not pb.has_method("get_cell_position"): return Rect2()
	var pitch: float = float(pb.CELL_PITCH)
	var acc := Rect2()
	var found := false
	for cell in cells:
		var center: Vector2 = pb.get_cell_position(cell.x, cell.y)
		var r := _screen_rect(pb, Rect2(center - Vector2(pitch, pitch) * 0.5, Vector2(pitch, pitch)))
		if r.size.x < 2.0: continue
		if not found:
			acc = r
			found = true
		else:
			acc = acc.merge(r)
	return acc

## 4大リソース表示パネル（4大基本アイテム行全体）
func _resources_rect(scm: Node) -> Rect2:
	if scm == null or not is_instance_valid(scm): return Rect2()
	var st := scm.get_node_or_null("status2")
	if st is Control:
		var rr := _control_rect(st as Control)
		if rr.size.x >= 10.0 and rr.size.x <= 500.0:
			return Rect2(rr.position.x + 2.0, rr.position.y + 2.0, rr.size.x - 4.0, minf(rr.size.y - 4.0, 79.2 * 4.0 + 4.0))
	return Rect2(1194.0, 548.0, 417.0, 314.8)

## 4大リソースの個別アイテム行のRect（盾=0, 剣=1, コイン=2, ポーション=3, フード=4）
func _resource_item_rect(scm: Node, row_idx: int) -> Rect2:
	if scm == null or not is_instance_valid(scm): return Rect2()
	# score_manager で各行に配置されている item_hover_X を優先取得
	var h_ctrl = scm.get_node_or_null("item_hover_%d" % row_idx) as Control
	if h_ctrl != null and is_instance_valid(h_ctrl) and h_ctrl.size.x >= 10.0:
		var r := _control_rect(h_ctrl)
		if r.size.x >= 10.0 and r.size.y >= 10.0 and r.size.x <= 500.0:
			return Rect2(r.position.x + 2.0, r.position.y + 2.0, r.size.x - 4.0, r.size.y - 4.0)
	# フォールバック：status2_rect (1192.0, 546.0, 421.0, 396.0) 内の各行
	var row_y := 546.0 + 79.2 * float(row_idx)
	return Rect2(1194.0, row_y + 2.0, 417.0, 75.2)

## プレイヤー（味方）HPバーのRect
func _player_hp_rect(scm: Node) -> Rect2:
	if scm == null or not is_instance_valid(scm): return Rect2()
	var acc := Rect2()
	var found := false
	for nm in ["hpbar", "hpbar1", "player_hp_delay_bar"]:
		var n := scm.get_node_or_null(nm)
		if n is CanvasItem and (n as CanvasItem).visible and n is Control:
			var r := _control_rect(n as Control)
			if r.size.x < 2.0: continue
			if not found:
				acc = r
				found = true
			else:
				acc = acc.merge(r)
	if found: return acc.grow(6.0)
	return Rect2(1190.0, 412.0, 725.0, 26.0)

## 敵HPバー（StageManager の active_enemies[0] 内の bar_bg, bar_green, hp_lbl）
func _enemy_hp_rect(stm: Node) -> Rect2:
	if stm == null or not is_instance_valid(stm): return Rect2()
	if not ("active_enemies" in stm): return Rect2()
	var enemies = stm.get("active_enemies")
	if typeof(enemies) != TYPE_ARRAY or enemies.is_empty(): return Rect2()
	var e = enemies[0]
	if typeof(e) != TYPE_DICTIONARY: return Rect2()
	var acc := Rect2()
	var found := false
	for key in ["bar_bg", "bar_green", "bar_red", "hp_lbl", "target_frame"]:
		var n = e.get(key)
		if n is CanvasItem and is_instance_valid(n) and (n as CanvasItem).visible and n is Control:
			var r := _control_rect(n as Control)
			if r.size.x < 2.0: continue
			if not found:
				acc = r
				found = true
			else:
				acc = acc.merge(r)
	if found: return acc.grow(6.0)
	return Rect2()

## 敵スプライトのRect
func _enemy_sprite_rect(stm: Node) -> Rect2:
	if stm == null or not is_instance_valid(stm): return Rect2()
	if not ("active_enemies" in stm): return Rect2()
	var enemies = stm.get("active_enemies")
	if typeof(enemies) != TYPE_ARRAY or enemies.is_empty(): return Rect2()
	var e = enemies[0]
	if typeof(e) != TYPE_DICTIONARY: return Rect2()
	var spr = e.get("sprite")
	if spr == null or not is_instance_valid(spr): return Rect2()
	if spr is Sprite2D:
		var tex: Texture2D = (spr as Sprite2D).texture
		var sz := Vector2(180.0, 180.0)
		if tex != null and tex.get_size().x > 0.0:
			sz = tex.get_size()
		return _screen_rect(spr as CanvasItem, Rect2(-sz * 0.5, sz))
	if spr is CanvasItem:
		return _screen_rect(spr as CanvasItem, Rect2(-90.0, -90.0, 180.0, 180.0))
	return Rect2()

## 敵の行動予兆パネル（NEXT表示）
func _intent_rect(stm: Node) -> Rect2:
	if stm == null or not is_instance_valid(stm): return Rect2()
	if not ("active_enemies" in stm): return Rect2()
	var enemies = stm.get("active_enemies")
	if typeof(enemies) != TYPE_ARRAY or enemies.is_empty(): return Rect2()
	var e = enemies[0]
	if typeof(e) != TYPE_DICTIONARY: return Rect2()
	var panel = e.get("intent_panel")
	if panel is Control:
		var r := _control_rect(panel as Control)
		if r.size.x >= 2.0: return r
	var badge = e.get("intent_badge")
	if badge is Control:
		var r2 := _control_rect(badge as Control)
		if r2.size.x >= 2.0: return r2
	return _enemy_sprite_rect(stm)

## レリック選択カード（中央）
func _relic_card_rect(parent: Node) -> Rect2:
	if parent == null: return Rect2()
	var r_ui = _find_relic_ui(parent)
	if r_ui == null: return Rect2()
	if "hbox" in r_ui:
		var hbox = r_ui.get("hbox")
		if hbox is Container and hbox.get_child_count() > 0:
			var idx: int = 1 if hbox.get_child_count() >= 3 else hbox.get_child_count() / 2
			var mid: Node = hbox.get_child(idx)
			if mid is Control:
				var r := _control_rect(mid as Control)
				if r.size.x >= 2.0: return r
	if "panel" in r_ui:
		var pnl = r_ui.get("panel")
		if pnl is Control:
			var r2 := _control_rect(pnl as Control)
			if r2.size.x >= 2.0: return r2
	return Rect2()

## スキルツリータブボタン
func _skill_tab_rect(scm: Node) -> Rect2:
	if scm == null or not is_instance_valid(scm): return Rect2()
	if "skill_tab_btn" in scm:
		var b = scm.get("skill_tab_btn")
		if b is Control:
			var r := _control_rect(b as Control)
			if r.size.x >= 2.0: return r
	if "shop_root_panel" in scm:
		var p = scm.get("shop_root_panel")
		if p is Control:
			var r2 := _control_rect(p as Control)
			if r2.size.x >= 2.0: return r2
	return Rect2()

## スキルツリー最左スキルカード（清流展開=water_1）
func _skill_card_rect(scm: Node) -> Rect2:
	if scm == null or not is_instance_valid(scm): return Rect2()
	if not ("skill_tree_container" in scm): return Rect2()
	var stc = scm.get("skill_tree_container")
	if stc is Node:
		var card: Node = (stc as Node).get_node_or_null("MasterSkillCard_water_1")
		if card == null:
			for ch in (stc as Node).get_children():
				if String(ch.name).begins_with("MasterSkillCard_"):
					card = ch
					break
		if card is Control:
			var r := _control_rect(card as Control)
			if r.size.x >= 2.0: return r
		if stc is Control:
			var r2 := _control_rect(stc as Control)
			if r2.size.x >= 2.0: return r2
	return Rect2()

## 進化カード（モーダル中央）
func _evolution_card_rect(parent: Node) -> Rect2:
	if parent == null: return Rect2()
	var modal = parent.find_child("TarotEvolutionModal", true, false)
	if modal == null: return Rect2()
	var card: Node = modal.get_node_or_null("TarotCard_1")
	if card == null:
		for ch in modal.get_children():
			if String(ch.name).begins_with("TarotCard_"):
				card = ch
				break
	if card is Control:
		var r := _control_rect(card as Control)
		if r.size.x >= 2.0: return r
	if modal is Control:
		return _control_rect(modal as Control)
	return Rect2()

## 前に進むボタン
func _proceed_rect(stm: Node) -> Rect2:
	if stm != null and is_instance_valid(stm):
		var mv := stm.get_node_or_null("movefront")
		if mv is Control:
			var r := _control_rect(mv as Control)
			if r.size.x >= 2.0: return r
	return Rect2(1480.0, 974.0, 400.0, 76.0)

## 盤面上の水スキル駒（アクアスプラッシュ）
func _aqua_piece_rect(pb: Node) -> Rect2:
	if pb == null or not is_instance_valid(pb): return Rect2()
	if not ("special_item" in pb): return Rect2()
	var grid = pb.get("special_item")
	if typeof(grid) != TYPE_ARRAY: return Rect2()
	var rows: int = grid.size()
	if rows <= 0: return Rect2()
	var cols: int = pb.GRID_COLUMNS
	for r in range(rows):
		var row = grid[r]
		if typeof(row) != TYPE_ARRAY: continue
		for c in range(mini(cols, row.size())):
			if int(row[c]) == 8:
				return _cells_rect(pb, [Vector2i(r, c)])
	return Rect2()

## 現在ステップの注目対象をスクリーンRectで解決
func _resolve_focus() -> Rect2:
	var parent = get_parent()
	if parent == null: return Rect2()
	var pb = parent.get_node_or_null("PuzzleBoard")
	var stm = parent.get_node_or_null("StageManager")
	var scm = parent.get_node_or_null("ScoreManager")
	var rect := Rect2()
	match current_step:
		Step.INTRO_MOVE1:
			if current_page > 0:
				rect = _cells_rect(pb, [Vector2i(0, 2), Vector2i(0, 3)])
			else:
				rect = Rect2()
		Step.ITEMS_SCORED:
			if current_page == 1:
				# ⚔️ 剣: 行1 (SWORD)
				rect = _resource_item_rect(scm, 1)
			elif current_page == 2:
				# 🛡️ 盾: 行0 (SHIELD)
				rect = _resource_item_rect(scm, 0)
			elif current_page == 3:
				# 💰 コイン: 行2 (COIN)
				rect = _resource_item_rect(scm, 2)
			elif current_page == 4:
				# 🧪 ポーション: 行3 (POTION)
				rect = _resource_item_rect(scm, 3)
			else:
				# 0ページ目（概要）および5ページ目（発射準備）：4大アイテム行全体
				rect = _resources_rect(scm)
		Step.ATTACK_LANDED:
			rect = _enemy_hp_rect(stm)
			if rect.size.x < 2.0:
				rect = _enemy_sprite_rect(stm)
		Step.ENEMY_ATTACKED:
			if current_page == 2:
				rect = _player_hp_rect(scm)
			else:
				rect = _intent_rect(stm)
		Step.MOVE2_DEFEAT:
			rect = _cells_rect(pb, [Vector2i(0, 9), Vector2i(0, 10)])
		Step.RELIC_SELECTION:
			rect = _relic_card_rect(parent)
		Step.SHOP_COIN:
			rect = _skill_tab_rect(scm)
		Step.SKILL_TREE:
			rect = _skill_card_rect(scm)
		Step.SKILL_EVOLUTION:
			rect = _evolution_card_rect(parent)
		Step.PROCEED_STAGE:
			rect = _proceed_rect(stm)
		Step.STAGE2_SKILL_GEN:
			rect = _cells_rect(pb, [Vector2i(1, 4), Vector2i(2, 4)])
		Step.ENEMY_SKILL:
			rect = _aqua_piece_rect(pb)
			if rect.size.x < 2.0:
				rect = _enemy_sprite_rect(stm)
		Step.VICTORY_COMPLETE:
			rect = _enemy_sprite_rect(stm)
			if rect.size.x < 2.0:
				rect = _enemy_hp_rect(stm)
	return rect

func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp:
		var vr := vp.get_visible_rect()
		if vr.size.x >= 320.0 and vr.size.y >= 240.0:
			return vr.size
	return Vector2(1920, 1080)

func _set_column_visible(v: bool) -> void:
	if bubble: bubble.visible = v
	if instructor_box: instructor_box.visible = v
	if prev_btn: prev_btn.visible = v
	if next_btn: next_btn.visible = v
	var is_final_step := current_step >= TUTORIAL_STEPS.size() - 1
	if is_final_step:
		if complete_btn: complete_btn.visible = false
		if minimize_btn: minimize_btn.visible = false
	else:
		if minimize_btn: minimize_btn.visible = v
		if complete_btn: complete_btn.visible = false

## レイアウト計算（注目対象の解決・吹き出し/案内役/ボタン配置）
func _update_layout() -> void:
	var vp_sz := _viewport_size()
	if overlay:
		overlay.position = Vector2.ZERO
		overlay.size = vp_sz
	if mini_bar:
		var mb_w := 800.0
		var mb_h := 52.0
		mini_bar.position = Vector2((vp_sz.x - mb_w) * 0.5, 16.0)
		mini_bar.size = Vector2(mb_w, mb_h)
		mini_bar.visible = is_minimized

	if is_waiting_for_steady:
		_set_column_visible(false)
		if overlay: overlay.visible = false
		if mini_bar: mini_bar.visible = false
		return

	if is_minimized:
		_set_column_visible(false)
		if overlay: overlay.visible = false
		return

	_set_column_visible(true)
	if overlay: overlay.visible = true

	var step_idx := clampi(current_step, 0, TUTORIAL_STEPS.size() - 1)
	var step_pages := _step_page_list(step_idx)
	var page_idx := clampi(current_page, 0, step_pages.size() - 1)
	var cache_key := step_idx * 100 + page_idx
	if _bub_h_cache_key != cache_key:
		_bub_h_cache_key = cache_key
		_bub_h_cache = 90.0 + _estimate_content_height(str(step_pages[page_idx]))
	var bub_h := _bub_h_cache

	# [案内役][間隔][吹き出し] をひとつの横並びユニットとして配置する
	var row_w := INS_W + BUBBLE_GAP + BUBBLE_W
	var row_h := maxf(INS_H, bub_h)

	var focus := _resolve_focus()
	var has_focus := focus.size.x >= 2.0 and focus.size.y >= 2.0

	var unit_pos := Vector2.ZERO
	var btn_pos := Vector2.ZERO
	var btn_above := false
	var side := 0

	if has_focus:
		if focus.size.x > vp_sz.x - 2.0 * MARGIN:
			focus.size.x = maxf(60.0, vp_sz.x - 2.0 * MARGIN)
		if focus.size.y > vp_sz.y - 2.0 * MARGIN:
			focus.size.y = maxf(40.0, vp_sz.y - 2.0 * MARGIN)
		focus.position.x = clampf(focus.position.x, MARGIN, maxf(MARGIN, vp_sz.x - focus.size.x - MARGIN))
		focus.position.y = clampf(focus.position.y, MARGIN, maxf(MARGIN, vp_sz.y - focus.size.y - MARGIN))

		if current_step == Step.RELIC_SELECTION:
			# レリック選択モーダル：カードの下に配置し、カードと説明の重なりを完全防止
			side = 1
		else:
			# 対象の真横に配置（画面右側の対象には左側、画面左側の対象には右側を最優先）
			side = 3
			var fits_left := focus.position.x - SIDE_GAP - row_w >= MARGIN
			var fits_right := focus.position.x + focus.size.x + SIDE_GAP + row_w <= vp_sz.x - MARGIN
			var fits_down := focus.position.y + focus.size.y + ROW_GAP_Y + row_h + 10.0 + BTN_H <= vp_sz.y - MARGIN
			var fits_up := focus.position.y - ROW_GAP_Y - row_h - 10.0 - BTN_H >= MARGIN

			if focus.position.x > vp_sz.x * 0.5:
				# 右半面の対象（アイテム値、敵HP等）：左側真横を最優先
				if fits_left:
					side = 3
				elif fits_right:
					side = 0
				elif fits_down:
					side = 1
				elif fits_up:
					side = 2
			else:
				# 左半面の対象（盤面マス等）：右側真横を最優先
				if fits_right:
					side = 0
				elif fits_left:
					side = 3
				elif fits_down:
					side = 1
				elif fits_up:
					side = 2

		match side:
			0:
				# 右：[注目対象] [間隔] [案内役] [間隔] [吹き出し]
				unit_pos = Vector2(focus.position.x + focus.size.x + SIDE_GAP, focus.position.y + focus.size.y * 0.5 - row_h * 0.5)
			1:
				# 下：[注目対象] の真下に配置
				var ux1 := (vp_sz.x - row_w) * 0.5 if current_step == Step.RELIC_SELECTION else focus.position.x + focus.size.x * 0.5 - row_w * 0.5
				unit_pos = Vector2(clampf(ux1, MARGIN, maxf(MARGIN, vp_sz.x - row_w - MARGIN)), focus.position.y + focus.size.y + 16.0)
			2:
				# 上：[注目対象] の上に配置
				var ux2 := focus.position.x + focus.size.x * 0.5 - row_w * 0.5
				unit_pos = Vector2(clampf(ux2, MARGIN, maxf(MARGIN, vp_sz.x - row_w - MARGIN)), focus.position.y - ROW_GAP_Y - row_h)
				btn_above = true
			3:
				# 左：[吹き出し] [間隔] [案内役] [間隔] [注目対象]
				# 案内役が注目対象のすぐ左脇（真横）に立ち、右を向いて直接指差す！
				unit_pos = Vector2(focus.position.x - SIDE_GAP - row_w, focus.position.y + focus.size.y * 0.5 - row_h * 0.5)
		unit_pos.x = clampf(unit_pos.x, MARGIN, maxf(MARGIN, vp_sz.x - row_w - MARGIN))
		unit_pos.y = clampf(unit_pos.y, MARGIN, maxf(MARGIN, vp_sz.y - row_h - MARGIN - (BTN_H + 10.0 if not btn_above else 0.0)))

		btn_pos = Vector2(unit_pos.x + (row_w - BTN_ROW_W) * 0.5, unit_pos.y - BTN_H - 10.0 if btn_above else unit_pos.y + row_h + 10.0)
		if not btn_above and btn_pos.y + BTN_H > vp_sz.y - MARGIN:
			btn_pos.y = unit_pos.y - BTN_H - 10.0
		if btn_pos.y < MARGIN:
			btn_pos.y = vp_sz.y - BTN_H - MARGIN
		btn_pos.x = clampf(btn_pos.x, MARGIN, maxf(MARGIN, vp_sz.x - BTN_ROW_W - MARGIN))
	else:
		var cx2 := vp_sz.x * 0.5
		btn_pos = Vector2(cx2 - BTN_ROW_W * 0.5, vp_sz.y - BTN_H - 24.0)
		var ux0 := clampf(cx2 - row_w * 0.5, MARGIN, maxf(MARGIN, vp_sz.x - row_w - MARGIN))
		unit_pos = Vector2(ux0, maxf(MARGIN, btn_pos.y - 10.0 - row_h))

	# 案内役と吹き出しの位置決定：
	# side == 3（対象の左側配置）のときは、案内役を対象のすぐ真横（右側）に置き、吹き出しを左側に配置する
	var ins_pos := Vector2.ZERO
	var bub_pos := Vector2.ZERO
	if side == 3:
		# [吹き出し] [BUBBLE_GAP] [案内役] [SIDE_GAP] [注目対象]
		bub_pos = Vector2(unit_pos.x, unit_pos.y + (row_h - bub_h) * 0.5)
		ins_pos = Vector2(unit_pos.x + BUBBLE_W + BUBBLE_GAP, unit_pos.y + (row_h - INS_H) * 0.5)
	else:
		# [案内役] [BUBBLE_GAP] [吹き出し]
		ins_pos = Vector2(unit_pos.x, unit_pos.y + (row_h - INS_H) * 0.5)
		bub_pos = Vector2(unit_pos.x + INS_W + BUBBLE_GAP, unit_pos.y + (row_h - bub_h) * 0.5)

	if bubble:
		bubble.position = bub_pos
		bubble.size = Vector2(BUBBLE_W, bub_h)
		var inner_w := BUBBLE_W - 28.0
		if step_badge_lbl:
			step_badge_lbl.position = Vector2(14, 12)
			step_badge_lbl.size = Vector2(inner_w, 24)
		if step_title_lbl:
			step_title_lbl.position = Vector2(14, 40)
			step_title_lbl.size = Vector2(inner_w, 34)
		if content_lbl:
			content_lbl.position = Vector2(14, 82)
			content_lbl.size = Vector2(inner_w, bub_h - 94.0)
	if instructor_box:
		instructor_box.position = ins_pos
		instructor_box.size = Vector2(INS_W, INS_H)
		if avatar_rect:
			avatar_rect.position = Vector2(6, 6)
			avatar_rect.size = Vector2(INS_W - 12.0, INS_H - 12.0)
		if avatar_fallback_label:
			avatar_fallback_label.position = Vector2(6, 36)
			avatar_fallback_label.size = Vector2(INS_W - 12.0, INS_H - 48.0)
	var is_final_step := current_step >= TUTORIAL_STEPS.size() - 1
	if is_final_step:
		if prev_btn:
			prev_btn.visible = true
			prev_btn.position = btn_pos
			prev_btn.size = Vector2(110, BTN_H)
		if next_btn:
			next_btn.visible = true
			next_btn.position = btn_pos + Vector2(118, 0)
			next_btn.size = Vector2(280, BTN_H)
		if complete_btn:
			complete_btn.visible = false
		if minimize_btn:
			minimize_btn.visible = false
	else:
		if prev_btn:
			prev_btn.visible = true
			prev_btn.position = btn_pos
			prev_btn.size = Vector2(110, BTN_H)
		if next_btn:
			next_btn.visible = true
			next_btn.position = btn_pos + Vector2(118, 0)
			next_btn.size = Vector2(156, BTN_H)
		if minimize_btn:
			minimize_btn.visible = true
			minimize_btn.position = btn_pos + Vector2(282, 0)
			minimize_btn.size = Vector2(156, BTN_H)
		if complete_btn:
			complete_btn.visible = false

	if overlay:
		overlay.has_focus = has_focus
		overlay.has_arrow = false
		if has_focus:
			if avatar_rect:
				avatar_rect.flip_h = (ins_pos.x + INS_W * 0.5) > (focus.position.x + focus.size.x * 0.5)
			var hand_off: Vector2
			if avatar_rect and avatar_rect.flip_h:
				hand_off = Vector2(INS_W * 0.14, INS_H * 0.34)
			else:
				hand_off = Vector2(INS_W * 0.86, INS_H * 0.34)
			var arrow_from := ins_pos + hand_off
			var cp: Vector2
			if side == 1:
				cp = Vector2(clampf(arrow_from.x, focus.position.x + 20.0, focus.position.x + focus.size.x - 20.0), focus.position.y + focus.size.y)
			elif side == 2:
				cp = Vector2(clampf(arrow_from.x, focus.position.x + 20.0, focus.position.x + focus.size.x - 20.0), focus.position.y)
			elif side == 3:
				cp = Vector2(focus.position.x, clampf(arrow_from.y, focus.position.y + 10.0, focus.position.y + focus.size.y - 10.0))
			else:
				cp = Vector2(focus.position.x + focus.size.x, clampf(arrow_from.y, focus.position.y + 10.0, focus.position.y + focus.size.y - 10.0))

			if arrow_from.distance_to(cp) > 12.0:
				overlay.arrow_from = arrow_from + (cp - arrow_from).normalized() * 10.0
				overlay.arrow_to = cp
				overlay.has_arrow = true
			overlay.focus_rect = focus
		overlay.queue_redraw()
