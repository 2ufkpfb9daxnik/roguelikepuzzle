extends CanvasLayer
class_name TutorialManager

## 初心者向けチュートリアル案内マネージャー
## instructor.png を案内役として使用し、基本操作・目的・主要ルール・失敗条件・判断のポイントを段階的に説明

const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")
const INSTRUCTOR_PATH: String = "res://Texture/instructor.png"

var current_step: int = 0
var is_minimized: bool = false

var dim_rect: ColorRect = null
var main_panel: Panel = null
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
var skip_btn: Button = null
var complete_btn: Button = null

var mini_title_lbl: RichTextLabel = null
var mini_expand_btn: Button = null

# チュートリアル全5ステップ（+完了）データ
const TUTORIAL_STEPS: Array[Dictionary] = [
	{
		"badge": "ステップ 1 / 5：ゲームの目的",
		"title": "【ゲームの目的】パズルで敵を討伐しよう！",
		"text": "[color=#FFD54F]「ようこそ、ローグライクパズルの世界へ！ 私が冒険の基本を案内します！」[/color]\n\n" +
			"[b][color=#64FFDA]◆ あなたの目的[/color][/b]\n" +
			"盤面のパズルを揃えて様々な力を引き出し、次々と現れるモンスターを討伐することです！\n" +
			"各ステージ5戦目に控える[color=#FF5252]『ステージボス』[/color]、そして最深部の[color=#FF1744]『魔王』[/color]を討伐すればダンジョン制覇となります。\n\n" +
			"[color=#B0BEC5]※まずは次のステップで、パズルの基本操作をマスターしていきましょう！[/color]"
	},
	{
		"badge": "ステップ 2 / 5：基本操作",
		"title": "【基本操作】駒を動かして3つ以上揃えよう！",
		"text": "[b][color=#64FFDA]◆ 駒の動かし方[/color][/b]\n" +
			"隣り合う2つの駒を[color=#FFD54F]『クリック＆ドラッグ』[/color]するか、駒をクリック選択した後に隣のマスをクリックすると位置が入れ替わります。\n" +
			"縦または横に[color=#00E5FF]同じ絵柄の駒を3つ以上並べる[/color]とマッチして消滅します！\n\n" +
			"[b][color=#64FFDA]◆ 特殊駒の生成（ボム・ディスコボール等）[/color][/b]\n" +
			"・[color=#FF8A80]4個消し[/color]：十字や周囲を巻き込む強力な『ボム』が出現！\n" +
			"・[color=#EA80FC]5個消し・十字消し[/color]：同色の全駒を一掃する『ディスコボール』が出現！\n" +
			"駒を消すと上から新たな駒が落下し、連続で消える[color=#FFD700]『連鎖（コンボ）』[/color]が発生します。"
	},
	{
		"badge": "ステップ 3 / 5：主要ルール",
		"title": "【主要ルール】盤面の5つの駒と役割",
		"text": "盤面には[b]5種類の基本駒[/b]が存在し、揃えることで戦局を大きく動かせます：\n\n" +
			"[color=#FF5252]⚔️ 剣 (SWORD)[/color]：敵へ直接物理ダメージ！連鎖するほど威力が爆発的に上昇します。\n" +
			"[color=#40C4FF]🛡️ 盾 (SHIELD)[/color]：シールドを獲得！敵のターン攻撃を身代わりとなって防ぎます。\n" +
			"[color=#FFD700]💰 コイン (COIN)[/color]：ゴールドを獲得！戦闘間のショップでアイテム購入やスキル強化に使用。\n" +
			"[color=#69F0AE]🍖 肉/ポーション (HEAL)[/color]：プレイヤーのHPを即座に回復します。\n" +
			"[color=#E040FB]🌟 属性スキル[/color]：マッチで属性ゲージを溜めると、画面下の固有スキルを発動可能！"
	},
	{
		"badge": "ステップ 4 / 5：失敗条件",
		"title": "【失敗条件】HPが0になると敗北！敵の予兆を見逃すな！",
		"text": "[b][color=#FF1744]◆ 失敗条件（ゲームオーバー）[/color][/b]\n" +
			"敵の攻撃を受け、プレイヤーの[color=#FF5252]HPが0になると戦闘不能（敗北）[/color]となります。\n" +
			"ローグライクのため、敗北すると最初からやり直しになります。HP管理は最優先です！\n\n" +
			"[b][color=#FFD54F]◆ 敵の行動予兆（NEXT表示）[/color][/b]\n" +
			"敵の頭上には[color=#64FFDA]『次の行動 (NEXT)』[/color]と技名が表示されています。\n" +
			"強力な攻撃が迫っているターンには、攻撃される前に[color=#40C4FF]🛡️ 盾[/color]を消してシールドを固めるか、肉でHPを満タン近くまで保つことが生存の鍵です！"
	},
	{
		"badge": "ステップ 5 / 5：判断のポイント",
		"title": "【判断のポイント】生き残るための4大戦術",
		"text": "初心者を脱出するための実践的な判断ポイントです：\n\n" +
			"[color=#FFD54F]① 盾は先手必勝で蓄える[/color]：敵の強攻撃直前だけでなく、平時からシールドを維持しましょう。\n" +
			"[color=#64FFDA]② 盤面の下部を消して落とし連鎖を狙う[/color]：下段を消すと上の駒が大きく雪崩れ込み、大連鎖が誘発されやすくなります。\n" +
			"[color=#B388FF]③ 妨害マスは放置しない[/color]：敵が配置する凍結・炎・毒・石などの状態異常マスは、隣接マッチで早めに除去しましょう。\n" +
			"[color=#FFD700]④ ショップでスキルツリーを強化[/color]：戦闘後のショップでコインを使い、HP上限UPや強力なスキル進化を解放しましょう！"
	},
	{
		"badge": "チュートリアル完了！",
		"title": "【準備完了】いざ、ダンジョンへ出陣！",
		"text": "[color=#64FFDA]「お見事です！ これで冒険に必要な知識はすべて伝授しました！」[/color]\n\n" +
			"この画面のまま[color=#FFD54F]『盤面を操作する』[/color]を押せば、固定シードの盤面で安全に駒の操作や消去を試すことができます。\n" +
			"準備ができたら[color=#00E5FF]『実戦へ進む』[/color]ボタンを押して、本番の冒険へと繰り出しましょう！\n\n" +
			"[b][color=#FFD700]あなたの健闘と勝利を心より応援しています！[/color][/b]"
	}
]

func _ready() -> void:
	layer = 85
	_load_instructor_texture()
	_setup_ui()
	_update_step_content()
	_update_layout()

	if get_viewport():
		get_viewport().size_changed.connect(_update_layout)

## instructor.png の安全な読み込み（存在しない・読めない場合でもクラッシュせず優雅にフォールバック）
func _load_instructor_texture() -> void:
	if ResourceLoader.exists(INSTRUCTOR_PATH):
		instructor_tex = load(INSTRUCTOR_PATH) as Texture2D

func _setup_ui() -> void:
	# 1. 背面の半透明オーバーレイ（盤面を見せつつ案内を強調）
	dim_rect = ColorRect.new()
	dim_rect.name = "TutorialDimBackdrop"
	dim_rect.color = Color(0.02, 0.03, 0.06, 0.45)
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dim_rect)

	# 2. メインカードパネル
	main_panel = Panel.new()
	main_panel.name = "TutorialMainPanel"
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	p_style.border_color = Color(0.92, 0.76, 0.25, 1.0)
	p_style.set_border_width_all(3)
	p_style.set_corner_radius_all(16)
	p_style.shadow_color = Color(0, 0, 0, 0.7)
	p_style.shadow_size = 14
	main_panel.add_theme_stylebox_override("panel", p_style)
	add_child(main_panel)

	# 3. アバター領域（左側）
	var avatar_box = Panel.new()
	avatar_box.name = "AvatarFrame"
	avatar_box.position = Vector2(28, 28)
	avatar_box.size = Vector2(260, 360)
	var av_style = StyleBoxFlat.new()
	av_style.bg_color = Color(0.03, 0.04, 0.08, 0.90)
	av_style.border_color = Color(0.4, 0.75, 0.65, 0.9)
	av_style.set_border_width_all(2)
	av_style.set_corner_radius_all(12)
	avatar_box.add_theme_stylebox_override("panel", av_style)
	main_panel.add_child(avatar_box)

	avatar_rect = TextureRect.new()
	avatar_rect.name = "InstructorAvatar"
	avatar_rect.position = Vector2(6, 6)
	avatar_rect.size = Vector2(248, 348)
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if instructor_tex != null:
		avatar_rect.texture = instructor_tex
		avatar_rect.visible = true
	else:
		avatar_rect.visible = false
	avatar_box.add_child(avatar_rect)

	# instructor.png が読み込めない場合のフォールバック表示
	avatar_fallback_label = RichTextLabel.new()
	avatar_fallback_label.name = "AvatarFallback"
	avatar_fallback_label.bbcode_enabled = true
	avatar_fallback_label.position = Vector2(10, 80)
	avatar_fallback_label.size = Vector2(240, 200)
	avatar_fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CUSTOM_FONT:
		avatar_fallback_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		avatar_fallback_label.add_theme_font_override("bold_font", CUSTOM_FONT)
	avatar_fallback_label.text = "[center][font_size=64]🎓[/font_size]\n\n[b][color=#FFD700]INSTRUCTOR[/color][/b]\n[color=#80CBC4]案内役[/color][/center]"
	avatar_fallback_label.visible = (instructor_tex == null)
	avatar_box.add_child(avatar_fallback_label)

	# アバター下部の名前バナー
	var name_tag = Label.new()
	name_tag.text = "案内役 (Instructor)"
	if CUSTOM_FONT: name_tag.add_theme_font_override("font", CUSTOM_FONT)
	name_tag.add_theme_font_size_override("font_size", 22)
	name_tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.position = Vector2(28, 396)
	name_tag.size = Vector2(260, 32)
	main_panel.add_child(name_tag)

	# 4. コンテンツ領域（右側）
	var content_x: float = 316.0
	var content_w: float = 840.0

	# ステップバッジ（ピル形状）
	step_badge_lbl = RichTextLabel.new()
	step_badge_lbl.name = "StepBadge"
	step_badge_lbl.bbcode_enabled = true
	step_badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_badge_lbl.fit_content = false
	step_badge_lbl.scroll_active = false
	step_badge_lbl.position = Vector2(content_x, 26)
	step_badge_lbl.size = Vector2(content_w, 32)
	if CUSTOM_FONT:
		step_badge_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
		step_badge_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
	main_panel.add_child(step_badge_lbl)

	# ステップ大見出し
	step_title_lbl = RichTextLabel.new()
	step_title_lbl.name = "StepTitle"
	step_title_lbl.bbcode_enabled = true
	step_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_title_lbl.fit_content = false
	step_title_lbl.scroll_active = false
	step_title_lbl.position = Vector2(content_x, 62)
	step_title_lbl.size = Vector2(content_w, 48)
	if CUSTOM_FONT:
		step_title_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
		step_title_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
	main_panel.add_child(step_title_lbl)

	# 説明テキスト本文
	content_lbl = RichTextLabel.new()
	content_lbl.name = "StepContent"
	content_lbl.bbcode_enabled = true
	content_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_lbl.fit_content = false
	content_lbl.scroll_active = true
	content_lbl.position = Vector2(content_x, 118)
	content_lbl.size = Vector2(content_w, 310)
	var sys_jp = SystemFont.new()
	sys_jp.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "sans-serif"])
	content_lbl.add_theme_font_override("normal_font", sys_jp)
	content_lbl.add_theme_font_override("bold_font", sys_jp)
	content_lbl.add_theme_font_size_override("normal_font_size", 20)
	content_lbl.add_theme_font_size_override("bold_font_size", 20)
	content_lbl.add_theme_constant_override("line_separation", 6)
	main_panel.add_child(content_lbl)

	# 5. ナビゲーション操作ボタンバー
	var btn_y: float = 442.0

	# 「前へ」ボタン
	prev_btn = _create_btn("◀ 前へ", Color(0.12, 0.14, 0.22, 0.95), Color(0.4, 0.6, 0.8, 1.0))
	prev_btn.position = Vector2(content_x, btn_y)
	prev_btn.size = Vector2(140, 52)
	prev_btn.pressed.connect(_on_prev_pressed)
	main_panel.add_child(prev_btn)

	# 「次へ」ボタン
	next_btn = _create_btn("次へ ▶", Color(0.12, 0.28, 0.20, 0.95), Color(0.3, 0.9, 0.5, 1.0))
	next_btn.position = Vector2(content_x + 154, btn_y)
	next_btn.size = Vector2(160, 52)
	next_btn.pressed.connect(_on_next_pressed)
	main_panel.add_child(next_btn)

	# 「盤面を操作する」トグルボタン
	minimize_btn = _create_btn("👁 盤面を操作", Color(0.14, 0.16, 0.26, 0.95), Color(0.4, 0.8, 1.0, 1.0))
	minimize_btn.position = Vector2(content_x + 328, btn_y)
	minimize_btn.size = Vector2(180, 52)
	minimize_btn.pressed.connect(_toggle_minimize)
	main_panel.add_child(minimize_btn)

	# 「実戦へ進む」ボタン（最終ステップ以外でもいつでも終了可能）
	complete_btn = _create_btn("⚔️ 実戦へ進む", Color(0.28, 0.18, 0.06, 0.95), Color(1.0, 0.84, 0.0, 1.0))
	complete_btn.position = Vector2(content_x + 522, btn_y)
	complete_btn.size = Vector2(180, 52)
	complete_btn.pressed.connect(_on_complete_tutorial)
	main_panel.add_child(complete_btn)

	# 「スキップ」ボタン
	skip_btn = _create_btn("✕ 閉じる", Color(0.20, 0.10, 0.12, 0.95), Color(0.9, 0.4, 0.4, 1.0))
	skip_btn.position = Vector2(content_x + 716, btn_y)
	skip_btn.size = Vector2(124, 52)
	skip_btn.pressed.connect(_on_complete_tutorial)
	main_panel.add_child(skip_btn)

	# 6. 最小化時のコンパクトバー（盤面操作中用）
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
	mini_title_lbl.position = Vector2(20, 10)
	mini_title_lbl.size = Vector2(560, 36)
	if CUSTOM_FONT: mini_title_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
	mini_bar.add_child(mini_title_lbl)

	mini_expand_btn = _create_btn("📖 解説を開く", Color(0.12, 0.28, 0.20, 0.95), Color(0.3, 0.9, 0.5, 1.0))
	mini_expand_btn.position = Vector2(590, 6)
	mini_expand_btn.size = Vector2(180, 44)
	mini_expand_btn.pressed.connect(_toggle_minimize)
	mini_bar.add_child(mini_expand_btn)

func _create_btn(text_val: String, bg_c: Color, border_c: Color) -> Button:
	var btn = Button.new()
	btn.text = text_val
	if CUSTOM_FONT:
		btn.add_theme_font_override("font", CUSTOM_FONT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_constant_override("outline_size", 5)
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

## ステップ内容の表示更新
func _update_step_content() -> void:
	if current_step < 0: current_step = 0
	if current_step >= TUTORIAL_STEPS.size(): current_step = TUTORIAL_STEPS.size() - 1

	var data = TUTORIAL_STEPS[current_step]
	if step_badge_lbl:
		step_badge_lbl.text = "[color=#FFD54F][font_size=18]◆ " + data["badge"] + "[/font_size][/color]"
	if step_title_lbl:
		step_title_lbl.text = "[b][font_size=24][color=#FFFFFF]" + data["title"] + "[/color][/font_size][/b]"
	if content_lbl:
		content_lbl.text = data["text"]

	if prev_btn:
		prev_btn.disabled = (current_step == 0)

	if next_btn:
		if current_step == TUTORIAL_STEPS.size() - 1:
			next_btn.text = "✓ 完了"
			next_btn.disabled = true
		else:
			next_btn.text = "次へ ▶"
			next_btn.disabled = false

	if mini_title_lbl:
		mini_title_lbl.text = "[color=#FFD54F]📖 チュートリアル：[/color] [b]" + data["title"] + "[/b]"

func _on_prev_pressed() -> void:
	if current_step > 0:
		current_step -= 1
		_update_step_content()

func _on_next_pressed() -> void:
	if current_step < TUTORIAL_STEPS.size() - 1:
		current_step += 1
		_update_step_content()
	else:
		_on_complete_tutorial()

## 最小化（盤面確認モード）のトグル切り替え
func _toggle_minimize() -> void:
	is_minimized = !is_minimized
	if main_panel: main_panel.visible = !is_minimized
	if dim_rect: dim_rect.visible = !is_minimized
	if mini_bar: mini_bar.visible = is_minimized

## チュートリアル終了・実戦移行
func _on_complete_tutorial() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and "is_tutorial_mode" in sm:
		sm.is_tutorial_mode = false
	queue_free()

## 画面リサイズ連動レイアウト計算
func _update_layout() -> void:
	var vp = get_viewport()
	var vp_sz = vp.get_visible_rect().size if vp else Vector2(1920, 1080)
	var vp_w = maxf(vp_sz.x, 1920.0)
	var vp_h = maxf(vp_sz.y, 1080.0)

	var panel_w = 1180.0
	var panel_h = 514.0
	var panel_x = (vp_w - panel_w) * 0.5
	var panel_y = (vp_h - panel_h) * 0.5 + 20.0 # 画面中央やや下に配置

	if main_panel:
		main_panel.position = Vector2(panel_x, panel_y)
		main_panel.size = Vector2(panel_w, panel_h)

	if mini_bar:
		var mb_w = 790.0
		var mb_h = 56.0
		mini_bar.position = Vector2((vp_w - mb_w) * 0.5, 16.0)
		mini_bar.size = Vector2(mb_w, mb_h)
