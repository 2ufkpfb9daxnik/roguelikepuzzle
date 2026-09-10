extends Node2D

## ステージ進行、敵の生成・戦闘状態、HP/フィーバーゲージを管理するクラス

signal stage_clear

# --- ステージ＆敵データテーブル ---
const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")
const STAGE_BACKGROUNDS: Array[String] = ["plane", "cave", "desert", "snow field", "castle"]
const STAGE_BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://Texture/plane.jpeg"),
	preload("res://Texture/haikei/desert.jpg"),
	preload("res://Texture/haikei/cave2.jpg"),
	preload("res://Texture/haikei/snowfield.jpg"),
	preload("res://Texture/haikei/demonkingscastle.jpg"),
]

# 各敵テクスチャのパス定義
const ENEMY_TEXTURES: Dictionary = {
	"enemy1": "res://Texture/enemy/2CDF0D54-BB4C-40BC-9FDA-BFFC9BE514ED-preview.png",
	"enemy2": "res://Texture/enemy/7CD13BE7-4A80-4A6A-9B38-8CF11176BBB6-preview.png",
	"enemy3": "res://Texture/enemy/62FC0C59-C06A-4F2D-8F45-8B97FAF6CE0D-preview.png",
	"enemy4": "res://Texture/enemy/89B867BC-A9EC-41CA-91B8-842173054CE6-preview.png",
	"enemy5": "res://Texture/enemy/431C5D5B-E03A-4132-944F-BCB9280B9E02-preview.png",
	"enemy6": "res://Texture/enemy/486F2D2A-3A64-45B7-AE33-84043A25886C-preview.png",
	"enemy7": "res://Texture/enemy/9177DE2B-8D99-49E6-8727-6A1B5B82C46D-preview.png",
	"enemy8": "res://Texture/enemy/62397D94-819D-406D-AB2E-14CF147E67A0-preview.png",
	"enemy9": "res://Texture/enemy/95682DCB-962F-40A4-8FC3-78D5221F1151-preview.png",
	"enemy10": "res://Texture/enemy/373044AA-CAA2-40DE-A003-FBF746BF58B9-preview.png",
	"enemy11": "res://Texture/enemy/88129345-4E97-4A28-8DE9-267163178C79-preview.png",
	"enemy12": "res://Texture/enemy/A28C2F4D-FB65-4B73-963C-3956F9D5FAAC-preview.png",
	"enemy13": "res://Texture/enemy/AE3D90A3-3C62-4DEE-A714-D850BE8EE2F7-preview.png",
	"enemy14": "res://Texture/enemy/bat_preview_rev_1.png",
	"enemy15": "res://Texture/enemy/BE12CB2A-9B00-4FA7-A1B2-76B518633DCD-preview.png",
	"enemy16": "res://Texture/enemy/C9EA8ED3-6BE0-4403-AE61-266042825A48-preview.png",
	"enemy17": "res://Texture/enemy/dragon_preview_rev_1.png",
	"enemy18": "res://Texture/enemy/F2724454-974E-419C-944E-C63884AE593E-preview.png",
	"enemy19": "res://Texture/enemy/octopus_preview_rev_1.png",
	"enemy20": "res://Texture/enemy/sasori_preview_rev_1.png",
	"enemy21": "res://Texture/enemy/snake_preview_rev_1.png",
	"enemy22": "res://Texture/enemy/snake_preview_rev_1.png",
	"enemy23": "res://Texture/enemy/treeman_preview_rev_1.png",
	"enemy24": "res://Texture/enemy/wolf_preview_rev_1.png",
}

# 各ステージごとの敵定義 (通常敵5種 + ボス1種)
const STAGE_ENEMIES: Array[Dictionary] = [
	{ # Stage 1
		"names": ["enemy4", "enemy5", "enemy8", "enemy12", "enemy15", "enemy24"],
		"hp": [10000, 3000, 4000, 7500, 6000, 20000],
		"atk": [1500, 1000, 1500, 2000, 1700, 1900]
	},
	{ # Stage 2
		"names": ["enemy2", "enemy3", "enemy6", "enemy10", "enemy5", "enemy14"],
		"hp": [3000, 8000, 7000, 6000, 3000, 15000],
		"atk": [2500, 1500, 1000, 2000, 1000, 3000]
	},
	{ # Stage 3
		"names": ["enemy2", "enemy7", "enemy19", "enemy20", "enemy21", "enemy11"],
		"hp": [3000, 5000, 9000, 4000, 3000, 30000],
		"atk": [2500, 2000, 2000, 2500, 2000, 1500]
	},
	{ # Stage 4
		"names": ["enemy3", "enemy5", "enemy13", "enemy16", "enemy23", "enemy17"],
		"hp": [8000, 3000, 5000, 7000, 12000, 25000],
		"atk": [1500, 1000, 2000, 2000, 1000, 3500]
	},
	{ # Stage 5
		"names": ["enemy1", "enemy7", "enemy9", "enemy19", "enemy12", "enemy18"],
		"hp": [7000, 5000, 7000, 9000, 7500, 50000],
		"atk": [2000, 2000, 3000, 2000, 2000, 4000]
	}
]

# 敵の属性・名称・カラー定義マスターテーブル（画像グラフィックと属性に完全一致）
const ENEMY_SPECIES: Dictionary = {
	"enemy1": {"name": "グリムリーパー", "element": "闇属性", "race": "闇属性", "color": "#E040FB"},
	"enemy2": {"name": "カースドマミー", "element": "地属性", "race": "地属性", "color": "#FFB74D"},
	"enemy3": {"name": "ポイズントード", "element": "水属性", "race": "水属性", "color": "#00E5FF"},
	"enemy4": {"name": "マグマゴーレム", "element": "地属性", "race": "地属性", "color": "#FF9800"},
	"enemy5": {"name": "ディープサハギン", "element": "水属性", "race": "水属性", "color": "#00E5FF"},
	"enemy6": {"name": "ファンガスロード", "element": "木属性", "race": "木属性", "color": "#69F0AE"},
	"enemy7": {"name": "スケルトンナイト", "element": "闇属性", "race": "闇属性", "color": "#B0BEC5"},
	"enemy8": {"name": "キラーホーネット", "element": "風属性", "race": "風属性", "color": "#64FFDA"},
	"enemy9": {"name": "クリムゾンウォーロック", "element": "火属性", "race": "火属性", "color": "#FF1744"},
	"enemy10": {"name": "ジュエルアラクネ", "element": "闇属性", "race": "闇属性", "color": "#B388FF"},
	"enemy11": {"name": "グランドラゴン", "element": "火属性", "race": "火属性", "color": "#FF6D00"},
	"enemy12": {"name": "ワーウルフ", "element": "風属性", "race": "風属性", "color": "#80D8FF"},
	"enemy13": {"name": "ダークピクシー", "element": "闇属性", "race": "闇属性", "color": "#EA80FC"},
	"enemy14": {"name": "グランガーゴイル", "element": "地属性", "race": "地属性", "color": "#D7CCC8"},
	"enemy15": {"name": "レインボーサーペント", "element": "光属性", "race": "光属性", "color": "#FFD700"},
	"enemy16": {"name": "アビスリザード", "element": "水属性", "race": "水属性", "color": "#40C4FF"},
	"enemy17": {"name": "フロストドラゴン", "element": "氷属性", "race": "氷属性", "color": "#80DEEA"},
	"enemy18": {"name": "冥王デモニアス", "element": "闇属性", "race": "闇属性", "color": "#D500F9"},
	"enemy19": {"name": "アビスクラーケン", "element": "水属性", "race": "水属性", "color": "#00E676"},
	"enemy20": {"name": "デスクラウンサソリ", "element": "地属性", "race": "地属性", "color": "#FF6D00"},
	"enemy21": {"name": "ブラックバイパー", "element": "地属性", "race": "地属性", "color": "#76FF03"},
	"enemy22": {"name": "ブラックバイパー", "element": "地属性", "race": "地属性", "color": "#76FF03"},
	"enemy23": {"name": "エルダートレント", "element": "木属性", "race": "木属性", "color": "#8BC34A"},
	"enemy24": {"name": "冥狼フェンリル", "element": "雷属性", "race": "雷属性", "color": "#FFD700"},
}

# 敵の連番スプライトシート定義（攻撃・スキル等のアニメーション）
const ENEMY_ANIMATION_SHEETS: Dictionary = {
	"enemy24": { # 冥狼フェンリル
		"attack": {
			"path": "res://Texture/enemy/wolf-attack.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.55
		},
		"skill": {
			"path": "res://Texture/enemy/wolf-skill.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.88
		}
	},
	"enemy14": { # グランガーゴイル (demon)
		"attack": {
			"path": "res://Texture/enemy/demon-attack.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 2.15
		},
		"skill": {
			"path": "res://Texture/enemy/demon-skill.png",
			"hframes": 5, "vframes": 5, "total_frames": 25, "fps": 24.0,
			"flip_h": true,
			"scale_mult": 1.50
		}
	}
}

var _anim_original_texture: Texture2D = null
var _anim_original_scale: Vector2 = Vector2.ONE
var _anim_original_position: Vector2 = Vector2(1550, 250)
var _anim_tween: Tween = null
var is_playing_custom_animation: bool = false

const STAGE_STANDARD: Array[int] = [1000, 2000, 30000, 50000, 9223372036854775807]

# --- 公開プロパティ ---
var stage: int = 0
var stage_enemy: int = 1
var is_current_boss: bool = false
var score: int = 0
var enemycount: int = 0

var enemy: Sprite2D = null
var ehpbar: ColorRect = null
var ehpbar1: ColorRect = null
var ehppar: float = 1.0
var ehp: float = 0.0
var ehpmax: float = 0.0
var enemyat: float = 0.0

var myhp: float = 5000.0
var myhpmax: float = 5000.0
var myhppar: float = 1.0

var fevergage: float = 0.0
var feverpar: float = 0.0
var isfevertime: bool = false
var fevercount: int = 0

var isstageclear: bool = false
var isdeadf: bool = false
var isdanger: bool = false
var islastboss: bool = false
var clicked: bool = false

var interval: int = 0
var appeartime: int = int(1e9)
var clearinterval: int = 0
var deadinterval: int = 0
var dangerinterval: int = 0
var lastbossinterval: int = 0

# フィーバー突入時の大文字表示待機フレーム数 (等速1.0xで約1.0秒、速度設定に完全連動)
const FEVER_INTRO_FRAMES: int = 60

# 速度シミュレーション累積
var _sim_accumulator: float = 0.0

## 現在のゲーム設定速度を取得
func _get_game_speed() -> float:
	var root_node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	if root_node:
		var sm_autoload = root_node.get_node_or_null("SettingsManager")
		if sm_autoload and "game_speed" in sm_autoload:
			return sm_autoload.game_speed
	return Engine.time_scale

var facearr: Array[Node2D] = []

# HP・ゲージ数値ラベル
var player_hp_lbl: RichTextLabel = null
var enemy_hp_lbl: RichTextLabel = null
var enemy_race_lbl: RichTextLabel = null
var current_enemy_key: String = ""
var fever_bar_lbl: RichTextLabel = null

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

# ノード参照
@onready var label: RichTextLabel = get_node_or_null("StageLabel")
@onready var label2: RichTextLabel = get_node_or_null("StageLabel2")
@onready var danger_label: Control = get_node_or_null("dangerlabel")
@onready var danger_rect: Control = get_node_or_null("dangerrect")
@onready var move_front_btn: Control = get_node_or_null("movefront")
@onready var choose_buff_rect: Control = get_node_or_null("choosebuff")
@onready var fever_face_template: Node2D = get_node_or_null("feverface")

# 外部ノード参照ヘルパー
func _get_score_manager() -> Node2D:
	return get_parent().get_node_or_null("ScoreManager")

func _get_puzzle_board() -> Node2D:
	return get_parent().get_node_or_null("PuzzleBoard")

func _ready() -> void:
	# フォントにシステム日本語フォールバックを設定（漢字の確実な描画を保証）
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	myhp = 5000.0 * pow(10, max(0, stage - 1))
	myhpmax = myhp

	if label != null:
		label.add_theme_font_override("normal_font", CUSTOM_FONT)
		label.add_theme_font_override("bold_font", CUSTOM_FONT)
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	if label2 != null:
		label2.text = ""

	if danger_label != null:
		danger_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		danger_label.add_theme_font_override("bold_font", CUSTOM_FONT)
		danger_label.add_theme_constant_override("outline_size", 10)
		danger_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		danger_label.text = "[center][b][color=#FF1744]⚠ 危険 ⚠[/color][/b][/center]"

	if move_front_btn != null:
		move_front_btn.add_theme_font_override("font", CUSTOM_FONT)
		move_front_btn.add_theme_font_size_override("font_size", 30)
		move_front_btn.add_theme_constant_override("outline_size", 6)
		move_front_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	if label != null and label2 != null:
		stage_enemy = 1
		stage += 1
		is_current_boss = false
		label_control()
		emit_signal("stage_clear")

## ステージラベル・表示の更新
func label_control() -> void:
	if label:
		label.text = "[b][color=#00E5FF]STAGE[/color] [color=#FFD700]%d[/color][/b]" % stage
	if label2:
		label2.text = ""

## 敵の撃破または前進によるカウント加算
func add_stage_label() -> void:
	if stage_enemy == 5 and stage == 5:
		islastboss = true
		lastbossinterval = 0
	elif stage_enemy == 5:
		isstageclear = true
		clearinterval = 0
	else:
		stage_enemy += 1

## スコア基準チェック
func score_check() -> void:
	var sm = _get_score_manager()
	if sm and "totalScore" in sm:
		if stage - 1 < STAGE_STANDARD.size() and sm.totalScore > STAGE_STANDARD[stage - 1]:
			add_stage_label()

## ボス戦中か否かの判定（全ステージ共通）
func is_boss_battle() -> bool:
	return is_current_boss or stage_enemy == 5 or isdanger or islastboss

func is_boss_monster() -> bool:
	return is_boss_battle()

func get_current_enemy_element() -> String:
	var sp_data = ENEMY_SPECIES.get(current_enemy_key, {})
	return sp_data.get("element", sp_data.get("race", "無属性"))

## 敵キャラクターの生成
func make_enemy(spawn_as_boss: bool = false) -> void:
	if enemycount != 0:
		return
		
	stop_enemy_animation()
	_anim_original_texture = null

	var is_boss: bool = spawn_as_boss or (stage_enemy == 5)
	is_current_boss = is_boss
	if is_boss:
		stage_enemy = 5

	# 戦闘開始時はショップ・バフ選択を完全に閉じる
	_set_buff_buttons_visible(false)
	if choose_buff_rect: choose_buff_rect.visible = false
	if move_front_btn: move_front_btn.visible = false
		
	# BGM 再生（戦闘開始時に最初から再生）
	var boss_bgm = get_node_or_null("bossbgm")
	var maou_bgm = get_node_or_null("maoubgm")
	var field_bgm = get_node_or_null("fieldbgm")
	
	if is_boss and stage == 5:
		if maou_bgm:
			maou_bgm.seek(0.0)
			maou_bgm.play()
	elif is_boss:
		if boss_bgm:
			boss_bgm.seek(0.0)
			boss_bgm.play()
	else:
		if field_bgm:
			field_bgm.seek(0.0)
			field_bgm.play()
		
	interval = 0
	var kemuri = get_parent().get_node_or_null("kemuri")
	if kemuri:
		kemuri.position = Vector2(1552.375, 210.125)
		kemuri.play()

	# ステージ・敵インデックス決定 (通常は0~4のランダム、ボス時は確実に5)
	var stage_idx: int = clampi(stage - 1, 0, STAGE_ENEMIES.size() - 1)
	var enemy_info = STAGE_ENEMIES[stage_idx]
	var enemy_idx: int = 5 if is_boss else (randi() % 5)

	var enemy_name: String = enemy_info["names"][enemy_idx]
	current_enemy_key = enemy_name
	var raw_hp: int = enemy_info["hp"][enemy_idx]
	var raw_atk: int = enemy_info["atk"][enemy_idx]

	# 敵スプライトの生成（テクスチャから直接生成、または既存ノードから複製）
	if enemy_name in ENEMY_TEXTURES:
		var tex = load(ENEMY_TEXTURES[enemy_name]) as Texture2D
		enemy = Sprite2D.new()
		enemy.name = "Enemy"
		enemy.texture = tex
		enemy.scale = Vector2(0.5, 0.5)
	else:
		# フォールバック
		var template_enemy = get_parent().get_child(0).get_node_or_null(enemy_name)
		if template_enemy:
			enemy = template_enemy.duplicate()

	if enemy:
		enemy.set_meta("base_scale", enemy.scale)
		enemy.position = Vector2(1550, 250)
		add_child(enemy)
		
		var pb = _get_puzzle_board()
		if pb:
			pb.encolor = enemy.modulate.r

	# HPバーの生成
	var sm = _get_score_manager()
	if sm:
		var bar_template = sm.get_node_or_null("ehpbar")
		var bar1_template = sm.get_node_or_null("ehpbar1")
		if bar_template and bar1_template:
			ehpbar = bar_template.duplicate()
			ehpbar1 = bar1_template.duplicate()
			ehpbar.visible = true
			ehpbar1.visible = true
			ehpbar.position = Vector2(1475, 145)
			ehpbar1.position = Vector2(1475, 145)
			add_child(ehpbar)
			add_child(ehpbar1)

	ehppar = 1.0
	var stage_mult: float = pow(10.0, max(0, stage - 1))
	ehp = raw_hp * stage_mult
	enemyat = raw_atk * stage_mult
	ehpmax = ehp

	enemycount += 1

## 敵が特定のアニメーションスプライトシートを持っているか判定
func has_enemy_animation(anim_name: String) -> bool:
	var enemy_anims = ENEMY_ANIMATION_SHEETS.get(current_enemy_key, {})
	return enemy_anims.has(anim_name)

## 敵の連番スプライトシートアニメーションを再生
func play_enemy_animation(anim_name: String, on_complete: Callable = Callable()) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var enemy_anims = ENEMY_ANIMATION_SHEETS.get(current_enemy_key, {})
	if not enemy_anims.has(anim_name):
		return false

	var anim_info = enemy_anims[anim_name]
	var sheet_path = anim_info.get("path", "")
	var sheet_tex: Texture2D = anim_info.get("texture", null)
	if sheet_tex == null and ResourceLoader.exists(sheet_path):
		sheet_tex = load(sheet_path) as Texture2D
	if sheet_tex == null:
		return false

	# 実行中のアニメーションTweenがあれば停止
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	# 初回なら元テクスチャとスケール、位置を退避
	if not is_playing_custom_animation:
		_anim_original_texture = enemy.texture
		_anim_original_scale = enemy.get_meta("base_scale", enemy.scale)
		_anim_original_position = enemy.position
		is_playing_custom_animation = true

	var hf: int = anim_info["hframes"]
	var vf: int = anim_info["vframes"]
	var total_f: int = anim_info["total_frames"]
	var fps: float = anim_info["fps"]
	var should_flip: bool = anim_info.get("flip_h", false)
	var scale_mult: float = anim_info.get("scale_mult", 1.0)
	var offset_pos: Vector2 = anim_info.get("offset", Vector2.ZERO)

	var frame_w = sheet_tex.get_size().x / float(hf)
	var orig_w = _anim_original_texture.get_size().x if _anim_original_texture else frame_w
	var target_scale = _anim_original_scale * (float(orig_w) / float(frame_w)) * scale_mult

	enemy.texture = sheet_tex
	enemy.hframes = hf
	enemy.vframes = vf
	enemy.frame = 0
	enemy.scale = target_scale
	enemy.flip_h = should_flip
	enemy.position = _anim_original_position + offset_pos

	var duration = float(total_f) / maxf(1.0, fps)
	_anim_tween = create_tween()
	_anim_tween.tween_method(func(f_idx: int):
		if enemy and is_instance_valid(enemy):
			enemy.frame = clampi(f_idx, 0, total_f - 1)
	, 0, total_f - 1, duration)

	_anim_tween.tween_callback(func():
		stop_enemy_animation()
		if on_complete.is_valid():
			on_complete.call()
	)
	return true

## 再生中のアニメーションを停止し、元の通常画像・スケールに即時復元
func stop_enemy_animation() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
	if enemy and is_instance_valid(enemy) and is_playing_custom_animation:
		if _anim_original_texture:
			enemy.texture = _anim_original_texture
		enemy.hframes = 1
		enemy.vframes = 1
		enemy.frame = 0
		enemy.scale = _anim_original_scale
		enemy.flip_h = false
		enemy.position = _anim_original_position
	is_playing_custom_animation = false

## HP計算（ダメージ適用）
func calchp(damage_to_enemy: float, damage_to_player: float) -> void:
	ehp = maxf(0.0, ehp - damage_to_enemy)
	myhp = clampf(myhp - damage_to_player, 0.0, myhpmax)
	ehppar = ehp / ehpmax if ehpmax > 0 else 0.0
	myhppar = myhp / myhpmax if myhpmax > 0 else 0.0
	
	if ehp <= 0 and not isdeadf:
		isdead()

## フィーバーゲージ蓄積
func calcgage(potion: float) -> void:
	fevergage += potion
	feverpar = fevergage / 7000.0

## HPバー表示の更新
func displayhp() -> void:
	if ehpbar1 != null and is_instance_valid(ehpbar1):
		ehpbar1.size = Vector2(ehppar * 150.0, 10.0)
		
		# 敵種族・名称ラベル（HPバー上部に配置）
		if enemy_race_lbl == null or not is_instance_valid(enemy_race_lbl):
			enemy_race_lbl = RichTextLabel.new()
			enemy_race_lbl.bbcode_enabled = true
			enemy_race_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_race_lbl.fit_content = false
			enemy_race_lbl.scroll_active = false
			enemy_race_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			enemy_race_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			enemy_race_lbl.add_theme_constant_override("outline_size", 8)
			enemy_race_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			enemy_race_lbl.add_theme_font_size_override("normal_font_size", 18)
			enemy_race_lbl.add_theme_font_size_override("bold_font_size", 18)
			enemy_race_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			enemy_race_lbl.position = Vector2(1250, 95)
			enemy_race_lbl.size = Vector2(600, 28)
			enemy_race_lbl.z_index = 13
			add_child(enemy_race_lbl)

		var sp_data = ENEMY_SPECIES.get(current_enemy_key, {"name": "モンスター", "element": "無属性", "race": "無属性", "color": "#FFD700"})
		var is_boss_enemy: bool = is_current_boss or (stage_enemy == 5)
		var boss_tag = "[color=#FF1744]☠ BOSS ☠[/color] " if is_boss_enemy else ""
		var name_str: String = sp_data["name"]
		var font_sz: int = 15 if name_str.length() > 10 else 18
		enemy_race_lbl.add_theme_font_size_override("normal_font_size", font_sz)
		enemy_race_lbl.add_theme_font_size_override("bold_font_size", font_sz)
		var elem_name: String = sp_data.get("element", sp_data.get("race", "無属性"))
		enemy_race_lbl.text = "[center][b]%s[color=%s]【%s】[/color] [color=#FFFFFF]%s[/color][/b][/center]" % [
			boss_tag, sp_data["color"], elem_name, sp_data["name"]
		]
		enemy_race_lbl.visible = true

		# 敵HP数値ラベル
		if enemy_hp_lbl == null or not is_instance_valid(enemy_hp_lbl):
			enemy_hp_lbl = RichTextLabel.new()
			enemy_hp_lbl.bbcode_enabled = true
			enemy_hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_hp_lbl.fit_content = false
			enemy_hp_lbl.scroll_active = false
			enemy_hp_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			enemy_hp_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			enemy_hp_lbl.add_theme_constant_override("outline_size", 6)
			enemy_hp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			enemy_hp_lbl.add_theme_font_size_override("normal_font_size", 16)
			enemy_hp_lbl.add_theme_font_size_override("bold_font_size", 16)
			enemy_hp_lbl.position = Vector2(1475, 122)
			enemy_hp_lbl.size = Vector2(250, 22)
			enemy_hp_lbl.z_index = 12
			add_child(enemy_hp_lbl)
		
		enemy_hp_lbl.visible = true
		enemy_hp_lbl.text = "[b][color=#FF5252]HP[/color] [color=#FFFFFF]%s / %s[/color][/b]" % [
			_format_comma(int(ehp)), _format_comma(int(ehpmax))
		]
	elif enemy_hp_lbl != null and is_instance_valid(enemy_hp_lbl):
		enemy_hp_lbl.visible = false
		if enemy_race_lbl != null and is_instance_valid(enemy_race_lbl):
			enemy_race_lbl.visible = false

	var hp_bar = get_parent().get_node_or_null("ScoreManager/hpbar1")
	if hp_bar:
		hp_bar.size = Vector2(min(int(myhppar * 725.0), 725), 26.0)
		
		# プレイヤーHP数値ラベル（HPバー内部に中央配置）
		if player_hp_lbl == null or not is_instance_valid(player_hp_lbl):
			player_hp_lbl = RichTextLabel.new()
			player_hp_lbl.bbcode_enabled = true
			player_hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			player_hp_lbl.fit_content = false
			player_hp_lbl.scroll_active = false
			player_hp_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			player_hp_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			player_hp_lbl.add_theme_constant_override("outline_size", 5)
			player_hp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			player_hp_lbl.add_theme_font_size_override("normal_font_size", 16)
			player_hp_lbl.add_theme_font_size_override("bold_font_size", 16)
			player_hp_lbl.position = Vector2(1190, 412)
			player_hp_lbl.size = Vector2(725, 26)
			player_hp_lbl.z_index = 15
			var sm = _get_score_manager()
			if sm:
				sm.add_child(player_hp_lbl)
			else:
				add_child(player_hp_lbl)
		
		var hp_col = "#FFFFFF"
		player_hp_lbl.text = "[center][b][color=#FFFF00]PLAYER HP[/color] [color=%s]%s / %s[/color][/b][/center]" % [
			hp_col, _format_comma(int(myhp)), _format_comma(int(myhpmax))
		]

## ゲージ表示の更新
func displaygage() -> void:
	var fever_bar = get_parent().get_node_or_null("ScoreManager/feverbar2")
	if fever_bar:
		fever_bar.size = Vector2(int(feverpar * 725.0), 24.0)
		
		# フィーバーゲージ%ラベル（フィーバーバー内部に中央配置）
		if fever_bar_lbl == null or not is_instance_valid(fever_bar_lbl):
			fever_bar_lbl = RichTextLabel.new()
			fever_bar_lbl.bbcode_enabled = true
			fever_bar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fever_bar_lbl.fit_content = false
			fever_bar_lbl.scroll_active = false
			fever_bar_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			fever_bar_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			fever_bar_lbl.add_theme_constant_override("outline_size", 5)
			fever_bar_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			fever_bar_lbl.add_theme_font_size_override("normal_font_size", 15)
			fever_bar_lbl.add_theme_font_size_override("bold_font_size", 15)
			fever_bar_lbl.position = Vector2(1190, 442)
			fever_bar_lbl.size = Vector2(725, 24)
			fever_bar_lbl.z_index = 15
			var sm = _get_score_manager()
			if sm:
				sm.add_child(fever_bar_lbl)
			else:
				add_child(fever_bar_lbl)
				
		var pct = clampi(int(feverpar * 100.0), 0, 100)
		fever_bar_lbl.text = "[center][b][color=#FFD700]FEVER GAUGE[/color] [color=#FFFFFF]%d%%[/color][/b][/center]" % pct

	var fever_count_lbl = get_parent().get_node_or_null("ScoreManager/fevertimecount")
	if fever_count_lbl:
		if not fever_count_lbl.has_theme_font_override("normal_font"):
			fever_count_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			fever_count_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			fever_count_lbl.add_theme_constant_override("outline_size", 8)
			fever_count_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fever_count_lbl.text = "[center][b][color=#FFD700]%d[/color][/b][/center]" % fevercount

## 敵死亡時の処理
func isdead() -> void:
	stop_enemy_animation()
	var gekiha = get_parent().get_node_or_null("gekiha")
	if gekiha: gekiha.play()
	
	# スキル演出・マークなどのエフェクトノードを完全消去
	if get_tree():
		get_tree().call_group("enemy_skill_vfx", "queue_free")
	
	# 敵撃破時に戦闘BGMを停止
	for bgm_name in ["fieldbgm", "bossbgm", "maoubgm"]:
		var b = get_node_or_null(bgm_name)
		if b and b.playing:
			b.stop()
	
	if enemy:
		if enemy.has_meta("active_skill_tween"):
			var tw = enemy.get_meta("active_skill_tween")
			if is_instance_valid(tw) and tw is Tween:
				tw.kill()
		enemy.queue_free()
		enemy = null
	if ehpbar:
		ehpbar.queue_free()
		ehpbar = null
	if ehpbar1:
		ehpbar1.queue_free()
		ehpbar1 = null
	if enemy_hp_lbl != null and is_instance_valid(enemy_hp_lbl):
		enemy_hp_lbl.visible = false
	if enemy_race_lbl != null and is_instance_valid(enemy_race_lbl):
		enemy_race_lbl.visible = false
		
	enemycount = 0
	isdeadf = true
	
	if (is_current_boss or stage_enemy == 5) and stage == 5:
		islastboss = true
		lastbossinterval = 0
	elif is_current_boss or stage_enemy == 5:
		isstageclear = true
		clearinterval = 0

## フィーバータイム開始
func fevertime() -> void:
	if int(fevergage) >= 7000:
		fevercount = 5
		fevergage = 0
		appeartime = 0
		isfevertime = true
		
		var field_bgm = get_node_or_null("fieldbgm")
		if field_bgm: field_bgm.stop()
		var fever_se = get_parent().get_node_or_null("fevertime")
		if fever_se: fever_se.play()
		
		var fever_lbl = get_parent().get_node_or_null("ScoreManager/feverlabel")
		if fever_lbl:
			fever_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			fever_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			fever_lbl.add_theme_constant_override("outline_size", 12)
			fever_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			fever_lbl.add_theme_font_size_override("normal_font_size", 64)
			fever_lbl.add_theme_font_size_override("bold_font_size", 64)

			# 実際のショップバフ倍率（2.0 + fever_boost_level * 0.5）と完全連動
			var sm_node = _get_score_manager()
			var mult: float = 2.0
			if sm_node and "fever_boost_level" in sm_node:
				mult = 2.0 + sm_node.fever_boost_level * 0.5
			var mult_str: String = ("%.1f" % mult).trim_suffix(".0")
			fever_lbl.text = "[center][b][rainbow freq=0.8 sat=2 val=20]★ FEVER TIME!! ★[/rainbow]\n[color=#FFD700]スコア %s 倍[/color][/b][/center]" % mult_str

			# 画面中央（1920x1080）に大きく大迫力で配置
			fever_lbl.size = Vector2(1000, 300)
			fever_lbl.position = Vector2((1920.0 - 1000.0) / 2.0, (1080.0 - 300.0) / 2.0)
			fever_lbl.z_index = 30

			# ド派手なポップイン拡大アニメーション
			fever_lbl.scale = Vector2(0.4, 0.4)
			fever_lbl.pivot_offset = fever_lbl.size / 2.0
			var tw = fever_lbl.create_tween()
			tw.tween_property(fever_lbl, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(fever_lbl, "scale", Vector2(1.0, 1.0), 0.1)

			if sm_node and sm_node.has_method("update_fever_label3"):
				sm_node.update_fever_label3()

## フィーバータイム終了
func notfevertime() -> void:
	if not isfevertime:
		return
	isfevertime = false
	var fever_bgm = get_node_or_null("feverbgm")
	if fever_bgm: fever_bgm.stop()
	
	if is_current_boss or stage_enemy == 5:
		if stage == 5:
			var maou_bgm = get_node_or_null("maoubgm")
			if maou_bgm and not maou_bgm.playing: maou_bgm.play()
		else:
			var boss_bgm = get_node_or_null("bossbgm")
			if boss_bgm and not boss_bgm.playing: boss_bgm.play()
	else:
		var field_bgm = get_node_or_null("fieldbgm")
		if field_bgm and not field_bgm.playing: field_bgm.play()
		
	var sm = _get_score_manager()
	if sm:
		var fever_lbl = sm.get_node_or_null("feverlabel")
		if fever_lbl: fever_lbl.position = Vector2(-1e9, -1e9)
		for node_name in ["feverrect", "feverrect2", "feverlabel2", "feverlabel3", "fevertime", "fevertimecount"]:
			var n = sm.get_node_or_null(node_name)
			if n: n.visible = false

func _process(_delta: float) -> void:
	var spd: float = maxf(0.1, _get_game_speed())
	_sim_accumulator += spd
	var steps: int = 0
	while _sim_accumulator >= 1.0 and steps < 16:
		_sim_accumulator -= 1.0
		steps += 1
		_step_process()
	if steps >= 16:
		_sim_accumulator = 0.0

func _ensure_fever_bgm() -> void:
	var fever_se = get_parent().get_node_or_null("fevertime") if get_parent() else null
	if fever_se and fever_se.playing:
		fever_se.stop()
	var fever_bgm = get_node_or_null("feverbgm")
	if fever_bgm and not fever_bgm.playing:
		fever_bgm.play()

func _step_process() -> void:
	# フィーバータイム突入演出の更新（敵状態・クリア演出に関わらず速度連動で確実に進行）
	if isfevertime and appeartime < FEVER_INTRO_FRAMES + 10:
		appeartime += 1
		if appeartime >= FEVER_INTRO_FRAMES - 8:
			_ensure_fever_bgm()
		if appeartime >= FEVER_INTRO_FRAMES:
			_process_fever_effects()
	elif isfevertime:
		_ensure_fever_bgm()
		_process_fever_effects()

	# 1. ボス警告（デンジャー演出）処理
	if isdanger and not is_current_boss:
		_process_danger_sequence()
		return
		
	# 2. ラスボスクリア演出
	if islastboss:
		_process_last_boss_clear_sequence()
		return
		
	# 3. 通常ステージクリア演出
	if isstageclear and not islastboss:
		_process_stage_clear_sequence()
		return
		
	# 4. 敵撃破後の待機
	if isdeadf:
		if deadinterval == 100:
			# ボス戦突入前・ボス戦中は絶対にショップを開かない
			if not is_boss_battle():
				if move_front_btn: move_front_btn.visible = true
				if choose_buff_rect: choose_buff_rect.visible = true
				_set_buff_buttons_visible(true)
			clicked = false
		deadinterval += 1
		return

	# 5. 通常戦闘ループ（ボス戦中・戦闘中はショップUIを完全に非表示にする鉄壁フェイルセーフ）
	if is_boss_battle() or enemy != null:
		if choose_buff_rect and choose_buff_rect.visible: choose_buff_rect.visible = false
		if move_front_btn and move_front_btn.visible: move_front_btn.visible = false
		var sm_node = _get_score_manager()
		if sm_node and "is_shop_open" in sm_node and sm_node.is_shop_open:
			sm_node.set_shop_ui_visible(false)

	make_enemy(stage_enemy == 5)
	displayhp()
	displaygage()
	interval += 1
	
	if interval == 40:
		var se = get_parent().get_node_or_null("syutsugen")
		if se: se.play()
	elif interval == 105:
		var kemuri = get_parent().get_node_or_null("kemuri")
		if kemuri: kemuri.position = Vector2(-1e9, -1e9)

	# 背景の切り替え
	_update_background()

## 警告演出の更新
func _process_danger_sequence() -> void:
	if dangerinterval == 0:
		var f_bgm = get_node_or_null("fieldbgm")
		if f_bgm: f_bgm.stop()
		var fv_bgm = get_node_or_null("feverbgm")
		if fv_bgm: fv_bgm.stop()
		var danger_se = get_node_or_null("danger")
		if danger_se: danger_se.play()
		if move_front_btn: move_front_btn.visible = false
		if choose_buff_rect: choose_buff_rect.visible = false
		_set_buff_buttons_visible(false)
		if danger_label: danger_label.visible = true
		if danger_rect: danger_rect.visible = true
	elif dangerinterval in [42, 110, 178, 246]:
		if danger_label: danger_label.visible = false
	elif dangerinterval in [68, 136, 204]:
		if danger_label: danger_label.visible = true
	elif dangerinterval >= 260:
		if danger_rect: danger_rect.visible = false
		stage_enemy = 5
		make_enemy(true)
		isdeadf = false
		clicked = true
		deadinterval = 0
		isdanger = false
		dangerinterval = 0
		return
	dangerinterval += 1

## ラスボスクリア演出の更新
func _process_last_boss_clear_sequence() -> void:
	var sm = _get_score_manager()
	if lastbossinterval == 101:
		if sm:
			for n in ["GameClear2", "GameClear", "GameClearWhite"]:
				var node = sm.get_node_or_null(n)
				if node: node.visible = true
		for bgm_name in ["bossbgm", "maoubgm"]:
			var b = get_node_or_null(bgm_name)
			if b and b.playing: b.stop()
		var lb_clear = get_node_or_null("lastbossclear")
		if lb_clear: lb_clear.play()
	elif lastbossinterval == 121:
		var ending_se = get_node_or_null("ending")
		if ending_se: ending_se.play()
	elif lastbossinterval > 121:
		if sm:
			var btn = sm.get_node_or_null("gameclearbutton")
			if btn: btn.visible = true
	lastbossinterval += 1

## 通常ステージクリア演出の更新
func _process_stage_clear_sequence() -> void:
	var sm = _get_score_manager()
	if clearinterval == 101:
		if sm:
			for n in ["stageclear", "stageclearWhite2", "stageclearblack"]:
				var node = sm.get_node_or_null(n)
				if node: node.visible = true
		if choose_buff_rect: choose_buff_rect.visible = true
		_set_buff_buttons_visible(true)
		
		var b_bgm = get_node_or_null("bossbgm")
		if b_bgm: b_bgm.stop()
		var kirikae = get_parent().get_node_or_null("stagekirikae")
		if kirikae: kirikae.play()
	elif clearinterval > 160:
		if sm:
			var next_btn = sm.get_node_or_null("stagechangeb")
			if next_btn: next_btn.visible = true
	clearinterval += 1

## フィーバー時の顔パーティクル演出
func _process_fever_effects() -> void:
	var field_bgm = get_node_or_null("fieldbgm")
	if field_bgm: field_bgm.stop()
	
	var sm = _get_score_manager()
	if sm:
		var f_lbl = sm.get_node_or_null("feverlabel")
		if f_lbl: f_lbl.position = Vector2(-1e9, -1e9)
		for node_name in ["feverrect", "feverrect2", "feverlabel2", "feverlabel3", "fevertime", "fevertimecount"]:
			var n = sm.get_node_or_null(node_name)
			if n: n.visible = true
			
	# 顔アイコンの落下と生成
	var alive_faces: Array[Node2D] = []
	for face in facearr:
		if face != null and is_instance_valid(face):
			face.position.y += 10.0
			if face.position.y >= 4000.0:
				face.queue_free()
			else:
				alive_faces.append(face)
	facearr = alive_faces
	
	if fever_face_template:
		var new_face: Node2D = fever_face_template.duplicate()
		new_face.position = Vector2(randi() % 14000, 0)
		add_child(new_face)
		facearr.append(new_face)

## 背景画像の切り替え（敵背景・全画面背景・盤面背景の完全同期）
func _update_background() -> void:
	var cur_idx: int = clampi(stage - 1, 0, STAGE_BACKGROUND_TEXTURES.size() - 1)
	var cur_texture: Texture2D = STAGE_BACKGROUND_TEXTURES[cur_idx]

	# 1. 敵エリアの背景スプライト更新
	for i in range(STAGE_BACKGROUNDS.size()):
		var bg_node = get_node_or_null(STAGE_BACKGROUNDS[i])
		if bg_node:
			bg_node.visible = (i == cur_idx)
			bg_node.texture = cur_texture

	# 2. 全画面主背景スプライト（sougen2D）更新（敵がいる欄以外の全領域＝ゲーム主背景をカジノ風に維持）
	var p = get_parent()
	var fullscreen_bg = p.get_node_or_null("sougen2D") if p else null
	if fullscreen_bg:
		var casino_tex = load("res://Texture/haikei/casino_bg.jpg") as Texture2D
		if casino_tex and fullscreen_bg.texture != casino_tex:
			fullscreen_bg.texture = casino_tex
		if casino_tex:
			var tex_size = casino_tex.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_val = maxf(1920.0 / tex_size.x, 1080.0 / tex_size.y)
				fullscreen_bg.scale = Vector2(scale_val, scale_val)
				fullscreen_bg.position = Vector2(960, 540)

	# 3. パズル盤面背景（board_background）更新
	var pb = _get_puzzle_board()
	if pb:
		var board_bg = pb.get_node_or_null("BoardBackground")
		if board_bg:
			board_bg.background_texture = cur_texture
			board_bg.queue_redraw()

## バフボタンの一括表示切り替え
func _set_buff_buttons_visible(is_vis: bool) -> void:
	var parent = get_parent()
	if not parent: return
	for i in range(6):
		var btn = parent.get_node_or_null("buffselectbutton" + str(i))
		if btn: btn.visible = is_vis
	var sm = _get_score_manager()
	if sm and sm.has_method("set_shop_ui_visible"):
		sm.set_shop_ui_visible(is_vis)

## ステージ変更ボタン押下時
func _on_stagechangeb_pressed() -> void:
	if not isstageclear:
		return
		
	myhp *= 10.0
	myhpmax *= 10.0
	isstageclear = false
	stage_enemy = 1
	stage += 1
	is_current_boss = false
	
	label_control()
	emit_signal("stage_clear")
	
	for bgm_name in ["bossbgm", "maoubgm"]:
		var b = get_node_or_null(bgm_name)
		if b and b.playing: b.stop()
	
	var sm = _get_score_manager()
	if sm:
		for n in ["stageclear", "stagechangeb", "stageclearWhite2", "stageclearblack"]:
			var node = sm.get_node_or_null(n)
			if node: node.visible = false
			
	if choose_buff_rect: choose_buff_rect.visible = false
	_set_buff_buttons_visible(false)
	if move_front_btn: move_front_btn.visible = false
	
	make_enemy(false)
	isdeadf = false
	clicked = true
	deadinterval = 0
	clearinterval = 0

## 「次へ進む」ボタン押下時
func _on_movefront_pressed() -> void:
	if not clicked:
		# ボタン押下時に即座に「前に進む」ボタンとバフ選択画面を非表示化（ボス戦突入時も確実に消去）
		if move_front_btn: move_front_btn.visible = false
		if choose_buff_rect: choose_buff_rect.visible = false
		_set_buff_buttons_visible(false)

		if stage_enemy >= 4:
			isdanger = true
			dangerinterval = 0
			isdeadf = false
			clicked = true
			deadinterval = 0
		else:
			stage_enemy += 1
			make_enemy(false)
			isdeadf = false
			clicked = true
			deadinterval = 0
