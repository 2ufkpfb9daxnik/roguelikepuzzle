extends Node2D

## ステージ進行、敵の生成・戦闘状態、HP/フィーバーゲージを管理するクラス

signal stage_clear

# --- ステージ＆敵データテーブル ---
const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")
const RELIC_SELECTION_UI_SCRIPT = preload("res://relic_selection_ui.gd")
const RELIC_OFFER_BATTLE_INDICES: Array[int] = [1, 2, 3, 4, 5]
const STAGE_BACKGROUNDS: Array[String] = ["plane", "cave", "desert", "snow field", "castle"]
const STAGE_BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://Texture/plane.jpeg"),
	preload("res://Texture/haikei/cave2.jpg"),
	preload("res://Texture/haikei/desert.jpg"),
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

# 各ステージごとの敵定義 (初期実装時の設定に完全準拠)
const STAGE_ENEMIES: Array[Dictionary] = [
	{ # Stage 1 (草原)
		"names": ["enemy4", "enemy5", "enemy8", "enemy12", "enemy15", "enemy24"],
		"hp": [10000, 3000, 4000, 7500, 6000, 20000],
		"atk": [1500, 1000, 1500, 2000, 1700, 1900]
	},
	{ # Stage 2 (洞窟)
		"names": ["enemy2", "enemy3", "enemy6", "enemy10", "enemy5", "enemy14"],
		"hp": [3000, 8000, 7000, 6000, 3000, 15000],
		"atk": [2500, 1500, 1000, 2000, 1000, 3000]
	},
	{ # Stage 3 (砂漠)
		"names": ["enemy22", "enemy7", "enemy19", "enemy20", "enemy21", "enemy11"],
		"hp": [3000, 5000, 9000, 4000, 3000, 30000],
		"atk": [2500, 2000, 2000, 2500, 2000, 1500]
	},
	{ # Stage 4 (雪原・氷結界)
		"names": ["enemy3", "enemy5", "enemy13", "enemy16", "enemy23", "enemy17"],
		"hp": [8000, 3000, 5000, 7000, 12000, 25000],
		"atk": [1500, 1000, 2000, 2000, 1000, 3500]
	},
	{ # Stage 5 (魔王城・決戦)
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
	"enemy22": {"name": "ヴェノムバイパー", "element": "地属性", "race": "地属性", "color": "#76FF03"},
	"enemy23": {"name": "エルダートレント", "element": "木属性", "race": "木属性", "color": "#8BC34A"},
	"enemy24": {"name": "冥狼フェンリル", "element": "雷属性", "race": "雷属性", "color": "#FFD700"},
}

# 敵の連番スプライトシート定義（全24キャラの攻撃・スキル・待機・被弾アニメーション）
const ENEMY_ANIMATION_SHEETS: Dictionary = EnemyAnimationData.SHEETS

var _cached_anim_textures: Dictionary = {}

func _get_anim_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cached_anim_textures.has(path):
		return _cached_anim_textures[path]
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		_cached_anim_textures[path] = tex
		return tex
	return null

var _anim_original_texture: Texture2D = null
var _anim_original_scale: Vector2 = Vector2.ONE
var _anim_original_position: Vector2 = Vector2(1550, 250)
var _anim_tween: Tween = null
var _rush_tween: Tween = null
var _idle_tween: Tween = null
var is_playing_custom_animation: bool = false
var _current_custom_anim: String = ""
var _active_single_anims: Dictionary = {}
var _edge_fade_material: ShaderMaterial = null
var _battle_camera: Camera2D = null
var _zoom_tween: Tween = null
var _damaged_anim_timer: float = 0.0
const DAMAGED_ANIM_INTERVAL: float = 0.26  # 被弾アニメーションの最小再開インターバル（約0.26秒）

const STAGE_STANDARD: Array[int] = [1000, 2000, 30000, 50000, 9223372036854775807]

# --- 公開プロパティ ---
var stage: int = 0
var stage_enemy: int = 1
var is_current_boss: bool = false
var score: int = 0
var enemycount: int = 0

var enemy: Sprite2D = null
var active_enemies: Array = []
var initial_spawn_count: int = 1
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
	if _cached_settings_manager and is_instance_valid(_cached_settings_manager):
		if "game_speed" in _cached_settings_manager:
			return _cached_settings_manager.game_speed
	
	var root_node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	if root_node:
		var sm_autoload = root_node.get_node_or_null("SettingsManager")
		if sm_autoload:
			_cached_settings_manager = sm_autoload
			if "game_speed" in sm_autoload:
				return sm_autoload.game_speed
	return Engine.time_scale

var facearr: Array[Node2D] = []

# HP・ゲージ数値ラベル
var player_hp_lbl: RichTextLabel = null
var enemy_hp_lbl: RichTextLabel = null
var enemy_race_lbl: RichTextLabel = null
var current_enemy_key: String = ""
var fever_bar_lbl: RichTextLabel = null

# パフォーマンス最適化用キャッシュ変数
var _last_ehp: int = -999999
var _last_ehpmax: int = -999999
var _last_myhp: int = -999999
var _last_myhpmax: int = -999999
var _last_displayed_enemy_key: String = ""
var _last_is_boss: bool = false
var _last_fever_pct: int = -999999
var _last_fever_count: int = -999999
var _cached_hp_bar: ColorRect = null
var _cached_fever_bar: ColorRect = null
var _cached_fever_count_lbl = null
var _last_updated_bg_stage: int = -1
var _cached_casino_bg: Texture2D = preload("res://Texture/haikei/casino_bg.jpg")
const ACCEL_RUSH_SE: AudioStream = preload("res://Sound/se/patinko/acceleration_15_demo.mp3")
const TARGET_LOCK_SE: AudioStream = preload("res://Sound/se/kurikku/cursor_14_demo.mp3")
const TARGET_UNLOCK_SE: AudioStream = preload("res://Sound/se/kurikku/cancel_24.mp3")
var _target_se_player: AudioStreamPlayer = null
var _cached_enemy_textures: Dictionary = {}
var _rush_se_player: AudioStreamPlayer = null

func _play_target_se(is_lock: bool) -> void:
	if _target_se_player == null:
		_target_se_player = AudioStreamPlayer.new()
		_target_se_player.name = "TargetSEPlayer"
		add_child(_target_se_player)
	_target_se_player.stream = TARGET_LOCK_SE if is_lock else TARGET_UNLOCK_SE
	_target_se_player.pitch_scale = 1.05 if is_lock else 1.15
	var se_vol: float = 0.6
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	if sm_autoload and "se_volume" in sm_autoload:
		se_vol = clampf(sm_autoload.se_volume * 0.7, 0.001, 1.0)
	_target_se_player.volume_db = linear_to_db(se_vol)
	_target_se_player.play()
var _cached_settings_manager: Node = null
var _cached_score_manager: Node2D = null
var _cached_puzzle_board: Node2D = null
var _vfx_container: Node2D = null
var _enemy_viewport_clip: Control = null
var _enemy_zoom_root: Node2D = null
var _enemy_zoom_tween: Tween = null
var target_enemy_index: int = 0

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
	if not is_instance_valid(_cached_score_manager):
		_cached_score_manager = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	return _cached_score_manager

func _get_puzzle_board() -> Node2D:
	if not is_instance_valid(_cached_puzzle_board):
		_cached_puzzle_board = get_parent().get_node_or_null("PuzzleBoard") if get_parent() else null
	return _cached_puzzle_board

func _setup_enemy_viewport_container() -> void:
	if _enemy_viewport_clip != null and is_instance_valid(_enemy_viewport_clip):
		return
	_enemy_viewport_clip = Control.new()
	_enemy_viewport_clip.name = "EnemyViewportClip"
	_enemy_viewport_clip.position = Vector2(1194, 13)
	_enemy_viewport_clip.size = Vector2(717, 394)
	_enemy_viewport_clip.clip_contents = true
	_enemy_viewport_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_viewport_clip)

	_enemy_zoom_root = Node2D.new()
	_enemy_zoom_root.name = "EnemyZoomRoot"
	_enemy_zoom_root.position = Vector2(-1194, -13)
	_enemy_zoom_root.scale = Vector2.ONE
	_enemy_viewport_clip.add_child(_enemy_zoom_root)

	for bg_name in STAGE_BACKGROUNDS:
		var bg_node = get_node_or_null(bg_name)
		if bg_node and bg_node.get_parent() == self:
			bg_node.reparent(_enemy_zoom_root)

	var p = get_parent()
	if p:
		var base_k = p.get_node_or_null("kemuri")
		if base_k and base_k.get_parent() != _enemy_zoom_root:
			base_k.reparent(_enemy_zoom_root)
			base_k.visible = false
			base_k.stop()
			base_k.position = Vector2(-1e9, -1e9)
			if not base_k.animation_finished.is_connected(_on_kemuri_finished):
				base_k.animation_finished.connect(_on_kemuri_finished)

func _on_kemuri_finished() -> void:
	var kemuri = _enemy_zoom_root.get_node_or_null("kemuri") if _enemy_zoom_root else (get_parent().get_node_or_null("kemuri") if get_parent() else null)
	if kemuri:
		kemuri.visible = false
		kemuri.stop()
		kemuri.position = Vector2(-1e9, -1e9)

## 召喚時の煙エフェクト（敵画面枠内に収め、黒画面で止まることなく綺麗に消滅）
func _play_summon_smoke(chosen_x: float, chosen_y: float = 240.0) -> void:
	var base_kemuri: AnimatedSprite2D = null
	if _enemy_zoom_root:
		base_kemuri = _enemy_zoom_root.get_node_or_null("kemuri") as AnimatedSprite2D
	if base_kemuri == null and get_parent():
		base_kemuri = get_parent().get_node_or_null("kemuri") as AnimatedSprite2D
	if base_kemuri == null:
		return
	
	var smoke = base_kemuri.duplicate() as AnimatedSprite2D
	smoke.name = "SummonSmoke_" + str(Time.get_ticks_msec())
	smoke.visible = true
	smoke.position = Vector2(chosen_x, chosen_y)
	# 召喚されたモンスターに合わせた適切なスケール（敵画面枠内に収まるサイズ）
	smoke.scale = Vector2(0.26, 0.26)
	smoke.z_index = 20
	smoke.modulate = Color.WHITE
	smoke.frame = 0
	
	var parent_target = _enemy_zoom_root if _enemy_zoom_root != null else self
	parent_target.add_child(smoke)
	smoke.play("new_animation")
	
	# 煙エフェクトのアニメーション末尾（黒画面フレーム）に入る前にスムーズにフェードアウトさせて完全消去
	var tw = smoke.create_tween()
	tw.tween_interval(0.55)
	tw.tween_property(smoke, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(smoke):
			smoke.stop()
			smoke.queue_free()
	)

func _ready() -> void:
	_setup_enemy_viewport_container()
	_vfx_container = Node2D.new()
	_vfx_container.name = "VFXContainer"
	if _enemy_zoom_root:
		_enemy_zoom_root.add_child(_vfx_container)
	else:
		add_child(_vfx_container)

	_cached_settings_manager = get_node_or_null("/root/SettingsManager")
	_cached_score_manager = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	_cached_puzzle_board = get_parent().get_node_or_null("PuzzleBoard") if get_parent() else null

	# タスク2-2: 敵テクスチャの事前非同期ロード
	for ename in ENEMY_TEXTURES:
		var path = ENEMY_TEXTURES[ename]
		if not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path)

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
		label.add_theme_font_size_override("normal_font_size", 48)
		label.add_theme_font_size_override("bold_font_size", 48)
		label.add_theme_constant_override("outline_size", 6)
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
		move_front_btn.z_index = 35
		move_front_btn.add_theme_font_override("font", CUSTOM_FONT)
		move_front_btn.add_theme_font_size_override("font_size", 30)
		move_front_btn.add_theme_constant_override("outline_size", 6)
		move_front_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		move_front_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
		var mf_style = StyleBoxFlat.new()
		mf_style.bg_color = Color(0.14, 0.36, 0.22, 0.96)
		mf_style.border_color = Color(0.4, 1.0, 0.6, 1.0)
		mf_style.set_border_width_all(3)
		mf_style.set_corner_radius_all(12)
		move_front_btn.add_theme_stylebox_override("normal", mf_style)
		var mf_hover = mf_style.duplicate()
		mf_hover.bg_color = Color(0.20, 0.48, 0.30, 1.0)
		move_front_btn.add_theme_stylebox_override("hover", mf_hover)

	if choose_buff_rect != null and choose_buff_rect is ColorRect:
		choose_buff_rect.color = Color(0, 0, 0, 0)
		choose_buff_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# デバッグ用ステージ5ボス戦突入ボタン
	var debug_s5_btn = Button.new()
	debug_s5_btn.name = "DebugStage5Button"
	debug_s5_btn.text = "☠ S5ボス戦 (F5)"
	debug_s5_btn.size = Vector2(170, 32)
	debug_s5_btn.position = Vector2(1730, 370)
	debug_s5_btn.z_index = 40
	debug_s5_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_s5_btn.add_theme_font_override("font", CUSTOM_FONT)
	debug_s5_btn.add_theme_font_size_override("font_size", 14)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.05, 0.1, 0.85)
	btn_style.border_color = Color(0.9, 0.2, 0.2, 0.9)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	debug_s5_btn.add_theme_stylebox_override("normal", btn_style)
	debug_s5_btn.pressed.connect(debug_start_stage5_boss)
	add_child(debug_s5_btn)

	if label != null and label2 != null:
		stage_enemy = 1
		stage += 1
		var rm = _get_relic_manager()
		if rm: rm.on_battle_start()
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
		var rm = _get_relic_manager()
		if rm: rm.on_stage_clear()
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

func get_focused_enemy_index() -> int:
	if active_enemies.is_empty():
		return -1
	return target_enemy_index

func get_focused_enemy() -> Dictionary:
	var idx = get_focused_enemy_index()
	if idx >= 0 and idx < active_enemies.size():
		return active_enemies[idx]
	elif not active_enemies.is_empty():
		return active_enemies[0]
	return {}

func set_focused_enemy_index(idx: int) -> void:
	if active_enemies.is_empty():
		target_enemy_index = -1
		return
	if idx < 0:
		target_enemy_index = -1
	else:
		target_enemy_index = clampi(idx, 0, active_enemies.size() - 1)
	_update_target_indicator()

func _update_target_indicator() -> void:
	var focused_idx = get_focused_enemy_index()
	for j in range(active_enemies.size()):
		var e = active_enemies[j]
		var is_focus = (j == focused_idx and focused_idx >= 0)
		if e.has("target_badge") and is_instance_valid(e["target_badge"]):
			e["target_badge"].visible = is_focus
		if e.has("target_frame") and is_instance_valid(e["target_frame"]):
			e["target_frame"].visible = is_focus
		if is_focus and is_instance_valid(e.get("sprite")):
			enemy = e["sprite"]
			current_enemy_key = e.get("key", "")
	if focused_idx < 0 and active_enemies.size() > 0:
		enemy = active_enemies[0]["sprite"]
		current_enemy_key = active_enemies[0].get("key", "")

func _get_relic_ui_manager() -> Node:
	if get_tree():
		var root = get_tree().root
		if root.has_node("RelicUIManager"):
			return root.get_node("RelicUIManager")
		var found = root.find_child("RelicUIManager", true, false)
		if found:
			return found
	var p = get_parent()
	while p:
		if p.has_node("RelicUIManager"):
			return p.get_node("RelicUIManager")
		p = p.get_parent()
	return null

var _last_hovered_enemy_idx: int = -1

## マウスカーソルが敵に重なった時の情報ツールチップ表示
func _update_enemy_hover_tooltip(mpos: Vector2) -> void:
	var rm_ui = _get_relic_ui_manager()
	if rm_ui == null or not rm_ui.has_method("show_custom_tooltip"):
		return

	# 敵表示エリア外ならツールチップを閉じる
	if mpos.x < 1190.0 or mpos.x > 1915.0 or mpos.y < 10.0 or mpos.y > 410.0 or active_enemies.is_empty():
		if _last_hovered_enemy_idx != -1:
			_last_hovered_enemy_idx = -1
			rm_ui.hide_custom_tooltip("enemy_hover")
		return

	var hovered_idx = -1
	var best_dist = 999999.0
	for j in range(active_enemies.size()):
		var spr = active_enemies[j].get("sprite")
		if is_instance_valid(spr):
			var spr_pos = spr.global_position if spr.is_inside_tree() else spr.position
			var dist_x = absf(spr_pos.x - mpos.x)
			var dist_y = absf(spr_pos.y - mpos.y)
			if dist_x <= 130.0 and dist_y <= 160.0:
				var dist = dist_x + dist_y
				if dist < best_dist:
					best_dist = dist
					hovered_idx = j

	if hovered_idx == -1:
		if _last_hovered_enemy_idx != -1:
			_last_hovered_enemy_idx = -1
			rm_ui.hide_custom_tooltip("enemy_hover")
		return

	_last_hovered_enemy_idx = hovered_idx
	var e = active_enemies[hovered_idx]
	var sp_data = e.get("sp_data", {})
	var ename = sp_data.get("name", e.get("key", "敵"))
	var elem_raw = sp_data.get("element", sp_data.get("race", "無属性"))
	var elem_str = "/".join(elem_raw) if typeof(elem_raw) == TYPE_ARRAY else elem_raw
	var c_color = sp_data.get("color", "#FFFFFF")
	
	var is_boss_b = is_boss_monster()
	var e_key = e.get("key", "")
	var is_5th_boss = is_boss_b and (
		stage == 5 or (islastboss == true) or (e_key == "enemy18") or (current_enemy_key == "enemy18")
	)

	var title = ""
	var desc = ""

	var cur_hp = int(e.get("hp", 0.0))
	var max_hp = int(e.get("max_hp", cur_hp))
	var cur_atk = int(e.get("atk", 0.0))

	if is_5th_boss:
		title = "[b][color=#FF1744]☠ BOSS ☠[/color] [color=%s]%s[/color] (属性: %s)[/b]" % [c_color, ename, elem_str]
		desc = "[font_size=19][color=#FF5252]【毎ターン2回行動】[/color]\n冥府を統べる破滅の魔王。1ターンに2回の行動をランダムに繰り出す！\n・[color=#FF5252]通常攻撃[/color]: 圧倒的破壊力の直接攻撃\n・[color=#E040FB]闇スキル[/color]: 暗雲（毎ターン瘴気ダメージ）＆呪いコマ配置\n・[color=#BA68C8]使徒召喚[/color]: 冥府より従者を召喚して盤石の陣を敷く\n\n[b]HP:[/b] %d / %d\n[b]攻撃力(ATK):[/b] %d[/font_size]" % [cur_hp, max_hp, cur_atk]
	elif is_boss_b:
		title = "[b][color=#FF1744]☠ BOSS ☠[/color] [color=%s]%s[/color] (属性: %s)[/b]" % [c_color, ename, elem_str]
		desc = "[font_size=19][color=#FFD700]【ステージボス】[/color]\n強力な属性スキルを確定発動してプレイヤーを阻む難敵！\n\n[b]HP:[/b] %d / %d\n[b]攻撃力(ATK):[/b] %d[/font_size]" % [cur_hp, max_hp, cur_atk]
	else:
		title = "[b][color=%s]%s[/color] (属性: %s)[/b]" % [c_color, ename, elem_str]
		var trait_desc = ""
		match elem_str:
			"水属性": trait_desc = "水たまりマスを生成して盤面を浸水させる"
			"氷属性": trait_desc = "コマを凍結させてスワップ移動を封じる"
			"風属性": trait_desc = "竜巻を発生させて列のコマを一掃・シャッフル"
			"木属性": trait_desc = "吸血苗木を植え付け、毎ターンプレイヤーHPを吸収"
			"地属性": trait_desc = "動かせない硬い岩石障害物を配置する"
			"雷属性": trait_desc = "落雷を落とし、動かすと反動を受ける帯電コマを生成"
			"闇属性": trait_desc = "暗雲（毎ターン瘴気ダメージ）と呪詛コマを展開"
			"光属性": trait_desc = "重要コマを黄金像に変化させて消去不可にする"
			"火属性": trait_desc = "周囲へ毎ターン延焼する炎上マスを生成"
			_: trait_desc = "通常攻撃や属性スキルで攻撃"
		desc = "[font_size=19]・[b]スキル特徴:[/b] %s\n・[b]行動:[/b] 毎ターン攻撃または属性スキル(50%%)\n\n[b]HP:[/b] %d / %d\n[b]攻撃力(ATK):[/b] %d[/font_size]" % [trait_desc, cur_hp, max_hp, cur_atk]

	rm_ui.show_custom_tooltip(title, desc, mpos, "enemy_hover")

func hide_enemy_hover_tooltip() -> void:
	if _last_hovered_enemy_idx != -1:
		_last_hovered_enemy_idx = -1
		var rm_ui = _get_relic_ui_manager()
		if rm_ui and rm_ui.has_method("hide_custom_tooltip"):
			rm_ui.hide_custom_tooltip("enemy_hover")

## デバッグ用：ステージ5ボス（冥王デモニアス）との戦闘を即時開始
func debug_start_stage5_boss() -> void:
	stage = 5
	stage_enemy = 5
	_last_updated_bg_stage = -1 # 背景更新を強制
	isdanger = false
	dangerinterval = 0
	isstageclear = false
	clearinterval = 0
	islastboss = false
	lastbossinterval = 0
	isdeadf = false
	enemycount = 0
	
	hide_enemy_hover_tooltip()
	stop_enemy_animation()
	for e in active_enemies:
		if is_instance_valid(e.get("sprite")): e["sprite"].queue_free()
		if e.has("bar_bg") and is_instance_valid(e["bar_bg"]): e["bar_bg"].queue_free()
		if e.has("bar_red") and is_instance_valid(e["bar_red"]): e["bar_red"].queue_free()
		if e.has("bar_green") and is_instance_valid(e["bar_green"]): e["bar_green"].queue_free()
		if e.has("lbl") and is_instance_valid(e["lbl"]): e["lbl"].queue_free()
		if e.has("hp_lbl") and is_instance_valid(e["hp_lbl"]): e["hp_lbl"].queue_free()
		if e.has("target_badge") and is_instance_valid(e["target_badge"]): e["target_badge"].queue_free()
		if e.has("target_frame") and is_instance_valid(e["target_frame"]): e["target_frame"].queue_free()
	active_enemies.clear()
	enemy = null
	
	var base_k = _enemy_zoom_root.get_node_or_null("kemuri") if _enemy_zoom_root else (get_parent().get_node_or_null("kemuri") if get_parent() else null)
	if base_k:
		base_k.visible = false
		base_k.stop()
		base_k.position = Vector2(-1e9, -1e9)
	if _enemy_zoom_root:
		for child in _enemy_zoom_root.get_children():
			if child.name.begins_with("SummonSmoke_"):
				child.queue_free()
	
	label_control()
	_update_background()
	make_enemy(true)
	displayhp()
	displaygage()
	
	var pb = _get_puzzle_board()
	if pb:
		pb.interval = 0
		pb.isattack = 0
		pb.isblock = 0
		pb.has_enemy_attacked = false
		pb.has_enemy_skilled = false
		pb.is_casting_skill_turn = false
		pb.is_enemy_turn_in_progress = false
		if pb.has_method("clear_board_hazards"):
			pb.clear_board_hazards()
		pb._redraw_board_effects()
		pb._spawn_floating_text(Vector2(pb.BOARD_LEFT + pb.BOARD_WIDTH * 0.5, pb.BOARD_TOP + 120), "⚔️ STAGE 5 BOSS BATTLE! ⚔️", Color(1.0, 0.2, 0.2))
	print("DEBUG: Successfully jumped to Stage 5 Boss (冥王デモニアス)!")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			debug_start_stage5_boss()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		_update_enemy_hover_tooltip(event.position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos = event.position
		# 敵表示エリア枠: x in [1190, 1915], y in [10, 410]
		if mpos.x >= 1190.0 and mpos.x <= 1915.0 and mpos.y >= 10.0 and mpos.y <= 410.0:
			var best_idx = -1
			var best_dist = 999999.0
			for j in range(active_enemies.size()):
				var spr = active_enemies[j].get("sprite")
				if is_instance_valid(spr):
					var dist = absf(spr.global_position.x - mpos.x)
					if dist < best_dist and dist <= 160.0:
						best_dist = dist
						best_idx = j
			if best_idx != -1:
				if best_idx == target_enemy_index:
					# ターゲット中の敵をもう一度クリックすることでターゲット解除
					target_enemy_index = -1
					_update_target_indicator()
					_play_target_se(false)
				else:
					target_enemy_index = best_idx
					_update_target_indicator()
					_play_target_se(true)

func get_enemy_element(target_specifier = null) -> String:
	var target_dict = {}
	if target_specifier is Sprite2D:
		for e in active_enemies:
			if e.get("sprite") == target_specifier:
				target_dict = e
				break
	elif typeof(target_specifier) == TYPE_INT and target_specifier >= 0 and target_specifier < active_enemies.size():
		target_dict = active_enemies[target_specifier]
	elif target_specifier is Dictionary:
		target_dict = target_specifier
	
	if target_dict.is_empty():
		return get_current_enemy_element()

	var sp_data = target_dict.get("sp_data", {})
	if sp_data.is_empty():
		var e_key = target_dict.get("key", current_enemy_key)
		sp_data = ENEMY_SPECIES.get(e_key, {})
	var elem = sp_data.get("element", sp_data.get("race", "無属性"))
	if typeof(elem) == TYPE_ARRAY:
		if elem.size() > 0:
			return elem[0]
		else:
			return "無属性"
	return str(elem)

func get_current_enemy_element() -> String:
	var f_enemy = get_focused_enemy()
	var sp_data = f_enemy.get("sp_data", {})
	if sp_data.is_empty():
		sp_data = ENEMY_SPECIES.get(current_enemy_key, {})
	var elem = sp_data.get("element", sp_data.get("race", "無属性"))
	if typeof(elem) == TYPE_ARRAY:
		if elem.size() > 0:
			return elem[0]
		else:
			return "無属性"
	return str(elem)

## 敵キャラクターの生成
func make_enemy(spawn_as_boss: bool = false) -> void:
	if enemycount != 0: return
	stop_enemy_animation()
	_anim_original_texture = null
	_cleanup_battle_camera()
	_setup_enemy_viewport_container()
	reset_enemy_zoom(0.0)
	var is_boss: bool = spawn_as_boss or (stage_enemy == 5)
	is_current_boss = is_boss
	if is_boss: stage_enemy = 5
	_set_buff_buttons_visible(false)
	if choose_buff_rect: choose_buff_rect.visible = false
	if move_front_btn: move_front_btn.visible = false
	var boss_bgm = get_node_or_null("bossbgm")
	var maou_bgm = get_node_or_null("maoubgm")
	var field_bgm = get_node_or_null("fieldbgm")
	if is_boss and stage == 5:
		if maou_bgm: maou_bgm.seek(0.0); maou_bgm.play()
	elif is_boss:
		if boss_bgm: boss_bgm.seek(0.0); boss_bgm.play()
	else:
		if field_bgm: field_bgm.seek(0.0); field_bgm.play()
	interval = 0
	var kemuri = _enemy_zoom_root.get_node_or_null("kemuri") if _enemy_zoom_root else (get_parent().get_node_or_null("kemuri") if get_parent() else null)
	if kemuri:
		kemuri.visible = true
		kemuri.frame = 0
		kemuri.position = Vector2(1552.375, 210.125)
		kemuri.scale = Vector2(0.558789, 0.546875)
		kemuri.modulate = Color.WHITE
		kemuri.play()

	active_enemies.clear()
	ehp = 0.0
	ehpmax = 0.0
	enemyat = 0.0
	initial_spawn_count = 1 if is_boss else randi_range(1, 3)
	var pb = _get_puzzle_board()
	var first_color_set = false
	var stage_mult: float = pow(10.0, max(0, stage - 1))
	var stage_idx: int = clampi(stage - 1, 0, STAGE_ENEMIES.size() - 1)
	var enemy_info = STAGE_ENEMIES[stage_idx]
	var parent_node: Node = _enemy_zoom_root if _enemy_zoom_root != null else self
	
	for i in range(initial_spawn_count):
		var e_idx: int = 5 if is_boss else (randi() % 5)
		var ename: String = enemy_info["names"][e_idx]
		var r_hp: int = enemy_info["hp"][e_idx]
		var r_atk: int = enemy_info["atk"][e_idx]
		var sp_data = ENEMY_SPECIES.get(ename, {"name": ename, "element": "無属性", "race": "無属性", "color": "#FFFFFF"})
		var en: Sprite2D = null
		if ename in ENEMY_TEXTURES:
			var tex: Texture2D = _cached_enemy_textures.get(ename)
			if tex == null:
				var path = ENEMY_TEXTURES[ename]
				if ResourceLoader.has_cached(path):
					# 非同期ロードが完了していればブロックなしで即時取得
					var _t_load = Time.get_ticks_usec()
					tex = ResourceLoader.load_threaded_get(path) as Texture2D
					var _d_load = Time.get_ticks_usec() - _t_load
					if _d_load > 1000: print("[SPIKE] load_threaded_get blocked for %.2f ms" % (_d_load / 1000.0))
				if tex == null:
					# キャッシュミス時のフォールバック同期ロード
					tex = load(path) as Texture2D
				_cached_enemy_textures[ename] = tex
			en = Sprite2D.new()
			en.name = "Enemy_" + str(i)
			en.texture = tex
			en.scale = Vector2(0.5, 0.5)
		else:
			var template_enemy = get_parent().get_child(0).get_node_or_null(ename)
			if template_enemy: en = template_enemy.duplicate()
		if en:
			en.set_meta("base_scale", en.scale)
			var base_x = 1550
			if initial_spawn_count == 2: base_x = 1425 + i * 250
			if initial_spawn_count == 3: base_x = 1310 + i * 240
			en.position = Vector2(base_x, 250)
			parent_node.add_child(en)
			if ENEMY_ANIMATION_SHEETS.has(ename):
				var anims = ENEMY_ANIMATION_SHEETS[ename]
				for a_key in anims:
					var a_info = anims[a_key]
					var s_path = a_info.get("path", "")
					_get_anim_texture(s_path)
			if not first_color_set and pb:
				pb.set("encolor", en.modulate.r)
				current_enemy_key = ename
				first_color_set = true
			var e_hp = r_hp * stage_mult
			var e_atk = r_atk * stage_mult
			ehp += e_hp
			ehpmax += e_hp
			enemyat += e_atk
			
			var bar_bg = ColorRect.new()
			bar_bg.color = Color(0, 0, 0, 0.5)
			bar_bg.size = Vector2(100, 10)
			bar_bg.position = en.position + Vector2(-50, -100)
			parent_node.add_child(bar_bg)
			var bar_red = ColorRect.new()
			bar_red.color = Color(1.0, 0.2, 0.2, 1.0)
			bar_red.size = Vector2(100, 10)
			bar_red.position = bar_bg.position
			parent_node.add_child(bar_red)
			var bar_green = ColorRect.new()
			bar_green.color = Color(0.2, 1.0, 0.2, 1.0)
			bar_green.size = Vector2(100, 10)
			bar_green.position = bar_bg.position
			parent_node.add_child(bar_green)
			
			var target_frame = ReferenceRect.new()
			target_frame.size = Vector2(108, 18)
			target_frame.position = bar_bg.position + Vector2(-4, -4)
			target_frame.border_color = Color(1.0, 0.2, 0.2, 0.95)
			target_frame.border_width = 2.5
			target_frame.editor_only = false
			target_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			target_frame.visible = (i == 0)
			parent_node.add_child(target_frame)

			var target_badge = RichTextLabel.new()
			target_badge.bbcode_enabled = true
			target_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			target_badge.fit_content = true
			target_badge.scroll_active = false
			target_badge.add_theme_font_override("normal_font", CUSTOM_FONT)
			target_badge.add_theme_font_override("bold_font", CUSTOM_FONT)
			target_badge.add_theme_font_size_override("normal_font_size", 14)
			target_badge.add_theme_font_size_override("bold_font_size", 14)
			target_badge.add_theme_constant_override("outline_size", 4)
			target_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			target_badge.size = Vector2(160, 24)
			target_badge.position = bar_bg.position + Vector2(-30, -20)
			target_badge.text = "[center][b][color=#FF1744]🎯 TARGET[/color][/b][/center]"
			target_badge.visible = (i == 0)
			parent_node.add_child(target_badge)

			var lbl = RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.fit_content = true
			lbl.scroll_active = false
			lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			lbl.add_theme_font_size_override("normal_font_size", 16)
			lbl.add_theme_font_size_override("bold_font_size", 16)
			lbl.add_theme_constant_override("outline_size", 4)
			lbl.add_theme_color_override("font_outline_color", Color(0,0,0,1))
			lbl.size = Vector2(240, 50)
			lbl.position = bar_bg.position + Vector2(-70, -45)
			var elem_raw = sp_data.get("element", sp_data.get("race", "無属性"))
			var elem_str = "/".join(elem_raw) if typeof(elem_raw) == TYPE_ARRAY else elem_raw
			var c_color = sp_data.get("color", "#FFFFFF")
			var boss_tag = "[color=#FF1744]☠ BOSS ☠[/color]\n" if is_boss else ""
			lbl.text = "[center]" + boss_tag + "[color=" + c_color + "]" + elem_str + "[/color] " + sp_data["name"] + "[/center]"
			parent_node.add_child(lbl)
			var hp_lbl = RichTextLabel.new()
			hp_lbl.bbcode_enabled = true
			hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hp_lbl.fit_content = true
			hp_lbl.scroll_active = false
			hp_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			hp_lbl.add_theme_font_size_override("normal_font_size", 16)
			hp_lbl.add_theme_constant_override("outline_size", 4)
			hp_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,1))
			hp_lbl.size = Vector2(240, 20)
			hp_lbl.position = bar_bg.position + Vector2(-70, 12)
			hp_lbl.text = "[center][color=#FFFFFF]" + str(int(e_hp)) + " / " + str(int(e_hp)) + "[/color][/center]"
			parent_node.add_child(hp_lbl)
			
			active_enemies.append({
				"key": ename, "sprite": en, "hp": e_hp, "max_hp": e_hp, "atk": e_atk,
				"bar_bg": bar_bg, "bar_red": bar_red, "bar_green": bar_green, "lbl": lbl, "hp_lbl": hp_lbl,
				"target_badge": target_badge, "target_frame": target_frame, "sp_data": sp_data
			})

	target_enemy_index = 0
	_update_target_indicator()

	if active_enemies.size() > 0:
		enemy = active_enemies[0]["sprite"]
		start_enemy_idle_animation()
		
	if ehpbar != null and is_instance_valid(ehpbar): ehpbar.visible = false
	if ehpbar1 != null and is_instance_valid(ehpbar1): ehpbar1.visible = false

	ehppar = 1.0
	enemycount += 1

## 5番目のボス（冥王デモニアス等）による仲間召喚スキル
func summon_boss_minion(specific_ename: String = "") -> Dictionary:
	if active_enemies.size() >= 3:
		return {}

	# 1. 空いているスロット位置(X座標)を判定（標準スロット: 1310, 1790, 1550）
	var available_slots = [1310.0, 1790.0, 1550.0]
	var chosen_x = -1.0
	for slot_x in available_slots:
		var occupied = false
		for e in active_enemies:
			var spr = e.get("sprite")
			if is_instance_valid(spr) and absf(spr.position.x - slot_x) < 80.0:
				occupied = true
				break
		if not occupied:
			chosen_x = slot_x
			break
	if chosen_x < 0.0:
		return {}

	var stage_idx: int = clampi(stage - 1, 0, STAGE_ENEMIES.size() - 1)
	var enemy_info = STAGE_ENEMIES[stage_idx]
	var parent_node: Node = _enemy_zoom_root if _enemy_zoom_root != null else self
	var stage_mult: float = pow(10.0, max(0, stage - 1))

	# 2. 召喚する敵キャラクターの選定（デフォルトはステージ5の通常敵: グリムリーパーやスケルトンナイト等）
	var ename = specific_ename
	var e_idx = 0
	if ename.is_empty():
		e_idx = randi() % 5 # 0..4（通常敵からランダム選出）
		ename = enemy_info["names"][e_idx]
	else:
		e_idx = enemy_info["names"].find(ename)
		if e_idx == -1: e_idx = 0

	var r_hp: int = enemy_info["hp"][e_idx]
	var r_atk: int = enemy_info["atk"][e_idx]
	var sp_data = ENEMY_SPECIES.get(ename, {"name": ename, "element": "無属性", "race": "無属性", "color": "#FFFFFF"})

	# 3. Sprite2Dの生成
	var en: Sprite2D = null
	if ename in ENEMY_TEXTURES:
		var tex: Texture2D = _cached_enemy_textures.get(ename)
		if tex == null:
			var path = ENEMY_TEXTURES[ename]
			if ResourceLoader.has_cached(path):
				tex = ResourceLoader.load_threaded_get(path) as Texture2D
			if tex == null:
				tex = load(path) as Texture2D
			_cached_enemy_textures[ename] = tex
		en = Sprite2D.new()
		en.name = "Enemy_Summoned_" + str(active_enemies.size())
		en.texture = tex
		en.scale = Vector2.ZERO # 出現時に0から拡大
	else:
		var template_enemy = get_parent().get_child(0).get_node_or_null(ename) if (get_parent() and get_parent().get_child_count() > 0) else null
		if template_enemy: en = template_enemy.duplicate()

	if en == null:
		return {}

	en.set_meta("base_scale", Vector2(0.5, 0.5))
	en.position = Vector2(chosen_x, 250)
	parent_node.add_child(en)

	if ENEMY_ANIMATION_SHEETS.has(ename):
		var anims = ENEMY_ANIMATION_SHEETS[ename]
		for a_key in anims:
			var a_info = anims[a_key]
			var s_path = a_info.get("path", "")
			_get_anim_texture(s_path)

	# 4. ステータス加算（ボスの取り巻きとして適正なHP・ATK）
	var e_hp = r_hp * stage_mult
	var e_atk = r_atk * stage_mult
	ehp += e_hp
	ehpmax += e_hp
	enemyat += e_atk

	# 5. UI要素の生成
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.5)
	bar_bg.size = Vector2(100, 10)
	bar_bg.position = en.position + Vector2(-50, -100)
	parent_node.add_child(bar_bg)
	var bar_red = ColorRect.new()
	bar_red.color = Color(1.0, 0.2, 0.2, 1.0)
	bar_red.size = Vector2(100, 10)
	bar_red.position = bar_bg.position
	parent_node.add_child(bar_red)
	var bar_green = ColorRect.new()
	bar_green.color = Color(0.2, 1.0, 0.2, 1.0)
	bar_green.size = Vector2(100, 10)
	bar_green.position = bar_bg.position
	parent_node.add_child(bar_green)

	var target_frame = ReferenceRect.new()
	target_frame.size = Vector2(108, 18)
	target_frame.position = bar_bg.position + Vector2(-4, -4)
	target_frame.border_color = Color(1.0, 0.2, 0.2, 0.95)
	target_frame.border_width = 2.5
	target_frame.editor_only = false
	target_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_frame.visible = false
	parent_node.add_child(target_frame)

	var target_badge = RichTextLabel.new()
	target_badge.bbcode_enabled = true
	target_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_badge.fit_content = true
	target_badge.scroll_active = false
	target_badge.add_theme_font_override("normal_font", CUSTOM_FONT)
	target_badge.add_theme_font_override("bold_font", CUSTOM_FONT)
	target_badge.add_theme_font_size_override("normal_font_size", 14)
	target_badge.add_theme_font_size_override("bold_font_size", 14)
	target_badge.add_theme_constant_override("outline_size", 4)
	target_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	target_badge.size = Vector2(160, 24)
	target_badge.position = bar_bg.position + Vector2(-30, -20)
	target_badge.text = "[center][b][color=#FF1744]🎯 TARGET[/color][/b][/center]"
	target_badge.visible = false
	parent_node.add_child(target_badge)

	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
	lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
	lbl.add_theme_font_size_override("normal_font_size", 16)
	lbl.add_theme_font_size_override("bold_font_size", 16)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	lbl.size = Vector2(240, 50)
	lbl.position = bar_bg.position + Vector2(-70, -45)
	var elem_raw = sp_data.get("element", sp_data.get("race", "無属性"))
	var elem_str = "/".join(elem_raw) if typeof(elem_raw) == TYPE_ARRAY else elem_raw
	var c_color = sp_data.get("color", "#FFFFFF")
	lbl.text = "[center][color=" + c_color + "]" + elem_str + "[/color] " + sp_data["name"] + "[/center]"
	parent_node.add_child(lbl)

	var hp_lbl = RichTextLabel.new()
	hp_lbl.bbcode_enabled = true
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_lbl.fit_content = true
	hp_lbl.scroll_active = false
	hp_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
	hp_lbl.add_theme_font_size_override("normal_font_size", 16)
	hp_lbl.add_theme_constant_override("outline_size", 4)
	hp_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	hp_lbl.size = Vector2(240, 20)
	hp_lbl.position = bar_bg.position + Vector2(-70, 12)
	hp_lbl.text = "[center][color=#FFFFFF]" + str(int(e_hp)) + " / " + str(int(e_hp)) + "[/color][/center]"
	parent_node.add_child(hp_lbl)

	var new_e = {
		"key": ename, "sprite": en, "hp": e_hp, "max_hp": e_hp, "atk": e_atk,
		"bar_bg": bar_bg, "bar_red": bar_red, "bar_green": bar_green, "lbl": lbl, "hp_lbl": hp_lbl,
		"target_badge": target_badge, "target_frame": target_frame, "sp_data": sp_data,
		"just_summoned": true
	}
	active_enemies.append(new_e)

	# 6. 出現ポップ演出（0から跳ねるように拡大 & 妖気フラッシュ）
	var tw = create_tween().set_parallel(true)
	tw.tween_property(en, "scale", Vector2(0.5, 0.5), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	en.modulate = Color(2.5, 1.2, 3.0, 1.0)
	tw.tween_property(en, "modulate", Color.WHITE, 0.35)

	# 出現SE & 煙エフェクト再生（敵画面枠内に収め、黒画面で止まることなく綺麗に消滅）
	var p = get_parent()
	if p:
		var se = p.get_node_or_null("syutsugen")
		if se: se.play()
	_play_summon_smoke(chosen_x, 240.0)

	# 召喚テキスト表示
	var summon_lbl = Label.new()
	summon_lbl.text = "使徒召喚！"
	summon_lbl.add_theme_font_override("font", CUSTOM_FONT)
	summon_lbl.add_theme_font_size_override("font_size", 28)
	summon_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 1.0))
	summon_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	summon_lbl.add_theme_constant_override("outline_size", 6)
	summon_lbl.position = Vector2(chosen_x - 70, 160)
	parent_node.add_child(summon_lbl)
	var lbl_tw = create_tween()
	lbl_tw.tween_property(summon_lbl, "position:y", 120.0, 0.8).set_ease(Tween.EASE_OUT)
	lbl_tw.parallel().tween_property(summon_lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	lbl_tw.chain().tween_callback(summon_lbl.queue_free)

	_update_target_indicator()
	return new_e

## 敵スプライト外周の画面切れ・離散エッジを防止するソフトフェードシェーダーマテリアル
func _get_or_create_edge_fade_material() -> ShaderMaterial:
	if _edge_fade_material == null:
		var sh = Shader.new()
		sh.code = """
shader_type canvas_item;

uniform float hframes = 5.0;
uniform float vframes = 5.0;
uniform float margin : hint_range(0.0, 0.25) = 0.055;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 cell_uv = fract(UV * vec2(hframes, vframes));
	float dist_x = min(cell_uv.x, 1.0 - cell_uv.x);
	float dist_y = min(cell_uv.y, 1.0 - cell_uv.y);
	float edge_factor = smoothstep(0.0, margin, min(dist_x, dist_y));
	col.a *= edge_factor;
	COLOR = col;
}
"""
		_edge_fade_material = ShaderMaterial.new()
		_edge_fade_material.shader = sh
		_edge_fade_material.set_shader_parameter("hframes", 5.0)
		_edge_fade_material.set_shader_parameter("vframes", 5.0)
		_edge_fade_material.set_shader_parameter("margin", 0.055)
	return _edge_fade_material

## 既存Camera2Dノードがあれば初期位置にリセット・安全に無効化
func _cleanup_battle_camera() -> void:
	var p = get_parent()
	if p:
		var cam = p.get_node_or_null("BattleCamera2D") as Camera2D
		if cam:
			cam.queue_free()

## 敵が特定のアニメーションスプライトシートを持っているか判定
func has_enemy_animation(anim_name: String) -> bool:
	var enemy_anims = ENEMY_ANIMATION_SHEETS.get(current_enemy_key, {})
	return enemy_anims.has(anim_name)

## 敵の待機（Idle）アニメーションをループ再生開始
func start_enemy_idle_animation() -> void:
	if not has_enemy_animation("idle"):
		return
	if is_playing_custom_animation:
		return
	_play_idle_loop()
func _play_idle_loop() -> void:
	if active_enemies.size() == 0:
		return
	
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null
	if _rush_tween and _rush_tween.is_valid():
		_rush_tween.kill()
		_rush_tween = null

	var base_key = active_enemies[0]["key"]
	var base_anims = ENEMY_ANIMATION_SHEETS.get(base_key, {})
	var base_info = base_anims.get("idle", {"total_frames": 1, "fps": 1.0})
	var total_f: int = base_info.get("total_frames", 1)
	var fps: float = base_info.get("fps", 1.0)
	var duration = float(total_f) / maxf(1.0, fps)

	for e in active_enemies:
		var spr = e["sprite"]
		var e_key = e["key"]
		var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
		if not e_anims.has("idle"):
			continue
		
		var anim_info = e_anims["idle"]
		var sheet_path = anim_info.get("path", "")
		var sheet_tex: Texture2D = _get_anim_texture(sheet_path)
		if sheet_tex == null:
			continue

		var hf: int = anim_info["hframes"]
		var vf: int = anim_info["vframes"]
		var should_flip: bool = anim_info.get("flip_h", false)
		var scale_mult: float = anim_info.get("scale_mult", 1.0)
		var offset_pos: Vector2 = anim_info.get("offset", Vector2.ZERO)

		if is_instance_valid(spr):
			if not spr.has_meta("anim_orig_tex"):
				spr.set_meta("anim_orig_tex", spr.texture)
				spr.set_meta("anim_orig_scale", spr.get_meta("base_scale", spr.scale))
				spr.set_meta("anim_orig_pos", spr.position)
				
			var orig_tex = spr.get_meta("anim_orig_tex")
			var orig_s = spr.get_meta("anim_orig_scale")
			var orig_p = spr.get_meta("anim_orig_pos")
			
			var frame_w = sheet_tex.get_size().x / float(hf)
			var orig_w = orig_tex.get_size().x if orig_tex else frame_w
			var target_scale = orig_s * (float(orig_w) / float(frame_w)) * scale_mult
			
			spr.texture = sheet_tex
			spr.hframes = hf
			spr.vframes = vf
			spr.frame = 0
			spr.scale = target_scale
			spr.flip_h = should_flip
			spr.position = orig_p + offset_pos
			spr.material = _get_or_create_edge_fade_material()
			spr.set_meta("anim_total_f", anim_info.get("total_frames", 1))

	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_method(func(f_idx: int):
		if not is_playing_custom_animation:
			for e in active_enemies:
				var spr = e["sprite"]
				if _active_single_anims.has(spr):
					continue
				if is_instance_valid(spr) and spr.has_meta("anim_total_f"):
					var e_total_f = spr.get_meta("anim_total_f")
					# 各敵のフレーム数に合わせてループさせる（フレーム数が違っても対応）
					var e_frame = f_idx % e_total_f
					spr.frame = clampi(e_frame, 0, e_total_f - 1)
	, 0, total_f - 1, duration)
## 敵の連番スプライトシートアニメーションを再生
func play_enemy_animation(anim_name: String, on_complete: Callable = Callable()) -> bool:
	if active_enemies.size() == 0:
		return false

	var base_key = active_enemies[0]["key"]
	var base_anims = ENEMY_ANIMATION_SHEETS.get(base_key, {})
	if not base_anims.has(anim_name):
		# 代表の敵がそのアニメを持っていなければキャンセル
		return false

	if anim_name == "damaged" and is_playing_custom_animation:
		if _current_custom_anim == "attack" or _current_custom_anim == "skill":
			return false
		if _anim_tween and _anim_tween.is_valid():
			_anim_tween.kill()
			_anim_tween = null

	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
	if _rush_tween and _rush_tween.is_valid():
		_rush_tween.kill()
		_rush_tween = null

	is_playing_custom_animation = true
	_current_custom_anim = anim_name

	var base_info = base_anims[anim_name]
	var total_f: int = base_info.get("total_frames", 1)
	var fps: float = base_info.get("fps", 1.0)
	var duration = float(total_f) / maxf(1.0, fps)

	var rush_in_dur: float = minf(0.24, duration * 0.3)
	var rush_out_dur: float = minf(0.22, duration * 0.25)
	var hold_dur: float = maxf(0.0, duration - rush_in_dur - rush_out_dur)
	var first = true
	if anim_name == "attack":
		_rush_tween = create_tween()

	for e in active_enemies:
		var spr = e["sprite"]
		var e_key = e["key"]
		var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
		var anim_info = e_anims.get(anim_name, base_info) # 持ってなければ代表の動きの長さだけ合わせる
		
		var sheet_path = anim_info.get("path", "")
		var sheet_tex: Texture2D = _get_anim_texture(sheet_path)
		
		if is_instance_valid(spr) and sheet_tex != null:
			var hf: int = anim_info["hframes"]
			var vf: int = anim_info["vframes"]
			var should_flip: bool = anim_info.get("flip_h", false)
			var scale_mult: float = anim_info.get("scale_mult", 1.0)
			var offset_pos: Vector2 = anim_info.get("offset", Vector2.ZERO)

			if not spr.has_meta("anim_orig_tex"):
				spr.set_meta("anim_orig_tex", spr.texture)
				spr.set_meta("anim_orig_scale", spr.get_meta("base_scale", spr.scale))
				spr.set_meta("anim_orig_pos", spr.position)
			
			var orig_tex = spr.get_meta("anim_orig_tex")
			var orig_s = spr.get_meta("anim_orig_scale")
			var orig_p = spr.get_meta("anim_orig_pos")
			var frame_w = sheet_tex.get_size().x / float(hf)
			var orig_w = orig_tex.get_size().x if orig_tex else frame_w
			var target_scale = orig_s * (float(orig_w) / float(frame_w)) * scale_mult
			
			spr.texture = sheet_tex
			spr.hframes = hf
			spr.vframes = vf
			spr.frame = 0
			spr.scale = target_scale
			spr.flip_h = should_flip
			spr.position = orig_p + offset_pos
			spr.material = _get_or_create_edge_fade_material()
			spr.set_meta("anim_total_f", anim_info.get("total_frames", 1))
			
			if anim_name == "attack" and _rush_tween:
				if first:
					_rush_tween.tween_property(spr, "scale", target_scale * 1.45, rush_in_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					if hold_dur > 0.0: _rush_tween.tween_interval(hold_dur)
					_rush_tween.tween_property(spr, "scale", target_scale, rush_out_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
					first = false
				else:
					_rush_tween.parallel().tween_property(spr, "scale", target_scale * 1.45, rush_in_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					if hold_dur > 0.0: _rush_tween.parallel().tween_interval(hold_dur)
					_rush_tween.parallel().tween_property(spr, "scale", target_scale, rush_out_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	if anim_name == "attack":
		_play_enemy_attack_rush_se()

	_anim_tween = create_tween()
	_anim_tween.tween_method(func(f_idx: int):
		for e in active_enemies:
			var spr = e["sprite"]
			if is_instance_valid(spr) and spr.has_meta("anim_total_f"):
				var e_total_f = spr.get_meta("anim_total_f")
				var e_frame = f_idx % e_total_f
				spr.frame = clampi(e_frame, 0, e_total_f - 1)
	, 0, total_f - 1, duration)

	_anim_tween.tween_callback(func():
		stop_enemy_animation()
		if on_complete.is_valid():
			on_complete.call()
	)
	return true
func is_enemy_animating() -> bool:
	if active_enemies.is_empty():
		_active_single_anims.clear()
		is_playing_custom_animation = false
		_current_custom_anim = ""
		return false
	var invalid_keys = []
	for k in _active_single_anims.keys():
		if not is_instance_valid(k):
			invalid_keys.append(k)
	for k in invalid_keys:
		_active_single_anims.erase(k)
	if _active_single_anims.is_empty() and (_anim_tween == null or not _anim_tween.is_valid()):
		is_playing_custom_animation = false
		_current_custom_anim = ""
	return is_playing_custom_animation or _active_single_anims.size() > 0 or (_anim_tween != null and _anim_tween.is_valid())

## 敵攻撃時の疾走突進効果音の再生
func _play_enemy_attack_rush_se() -> void:
	if _rush_se_player == null:
		_rush_se_player = AudioStreamPlayer.new()
		_rush_se_player.name = "EnemyRushSE"
		_rush_se_player.stream = ACCEL_RUSH_SE
		_rush_se_player.pitch_scale = 1.15
		add_child(_rush_se_player)
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	var se_vol: float = 0.55
	if sm_autoload and "se_volume" in sm_autoload:
		se_vol = clampf(sm_autoload.se_volume * 0.55, 0.001, 1.0)
	_rush_se_player.volume_db = linear_to_db(se_vol)
	_rush_se_player.play()

## 再生中のアニメーションを停止し、元の待機アニメーションまたは通常画像・スケールに復帰
func stop_enemy_animation() -> void:
	is_playing_custom_animation = false
	_current_custom_anim = ""
	_active_single_anims.clear()
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null
	if _rush_tween and _rush_tween.is_valid():
		_rush_tween.kill()
		_rush_tween = null

	for e in active_enemies:
		var spr = e.get("sprite", null)
		if is_instance_valid(spr):
			if spr.has_meta("anim_tween"):
				var atw = spr.get_meta("anim_tween")
				if is_instance_valid(atw) and atw is Tween and atw.is_valid(): atw.kill()
			if spr.has_meta("rush_tween"):
				var rtw = spr.get_meta("rush_tween")
				if is_instance_valid(rtw) and rtw is Tween and rtw.is_valid(): rtw.kill()
			if spr.has_meta("anim_orig_tex"):
				spr.texture = spr.get_meta("anim_orig_tex")
				spr.hframes = 1
				spr.vframes = 1
				spr.frame = 0
				spr.scale = spr.get_meta("anim_orig_scale")
				spr.flip_h = false
				spr.position = spr.get_meta("anim_orig_pos")
				spr.material = null
			
	if not isdeadf:
		start_enemy_idle_animation()
## 敵攻撃時の敵エリア専用ズームイン演出（敵がいる画面だけ攻撃する敵にズーム）
func zoom_on_attacking_enemy(enemy_index: int, duration: float = 0.20) -> void:
	if _enemy_zoom_root == null or not is_instance_valid(_enemy_zoom_root):
		return
	if enemy_index < 0 or enemy_index >= active_enemies.size():
		return
		
	if _enemy_zoom_tween and _enemy_zoom_tween.is_valid():
		_enemy_zoom_tween.kill()
		_enemy_zoom_tween = null
		
	var attacking_e = active_enemies[enemy_index]
	var spr: Sprite2D = attacking_e.get("sprite")
	if not is_instance_valid(spr):
		return
		
	var focus_pos = spr.get_meta("anim_orig_pos", spr.position)
	var focus_center = Vector2(focus_pos.x, 215.0)
	var Z: float = 1.42
	var local_center = Vector2(717.0 * 0.5, 394.0 * 0.5)
	var unclamped_target_pos = local_center - focus_center * Z
	
	# 背景画像が敵ウィンドウ枠から外れないよう安全クランプ
	var min_x = 717.0 - 1920.0 * Z * 0.98
	var max_x = -1180.0 * Z * 1.01
	var target_x = clampf(unclamped_target_pos.x, min_x, max_x)
	var target_y = clampf(unclamped_target_pos.y, -360.0, -10.0)
	var target_pos = Vector2(target_x, target_y)
	
	if duration <= 0.0:
		_enemy_zoom_root.scale = Vector2(Z, Z)
		_enemy_zoom_root.position = target_pos
		for j in range(active_enemies.size()):
			var e_spr = active_enemies[j].get("sprite")
			if is_instance_valid(e_spr):
				if j == enemy_index:
					e_spr.z_index = 5
					e_spr.modulate = Color.WHITE
				else:
					e_spr.z_index = 0
					e_spr.modulate = Color(0.40, 0.40, 0.48, 0.50)
		return

	_enemy_zoom_tween = create_tween().set_parallel(true)
	_enemy_zoom_tween.tween_property(_enemy_zoom_root, "scale", Vector2(Z, Z), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_enemy_zoom_tween.tween_property(_enemy_zoom_root, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for j in range(active_enemies.size()):
		var e_spr = active_enemies[j].get("sprite")
		if is_instance_valid(e_spr):
			if j == enemy_index:
				e_spr.z_index = 5
				_enemy_zoom_tween.tween_property(e_spr, "modulate", Color.WHITE, duration * 0.8)
			else:
				e_spr.z_index = 0
				_enemy_zoom_tween.tween_property(e_spr, "modulate", Color(0.40, 0.40, 0.48, 0.50), duration * 0.8)

## 敵エリアズーム演出のリセット
func reset_enemy_zoom(duration: float = 0.18) -> void:
	if _enemy_zoom_root == null or not is_instance_valid(_enemy_zoom_root):
		return
	if _enemy_zoom_tween and _enemy_zoom_tween.is_valid():
		_enemy_zoom_tween.kill()
		_enemy_zoom_tween = null
		
	if duration <= 0.0:
		_enemy_zoom_root.scale = Vector2.ONE
		_enemy_zoom_root.position = Vector2(-1194, -13)
		for j in range(active_enemies.size()):
			var e_spr = active_enemies[j].get("sprite")
			if is_instance_valid(e_spr):
				e_spr.z_index = 0
				e_spr.modulate = Color.WHITE
		return

	_enemy_zoom_tween = create_tween().set_parallel(true)
	_enemy_zoom_tween.tween_property(_enemy_zoom_root, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_enemy_zoom_tween.tween_property(_enemy_zoom_root, "position", Vector2(-1194, -13), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for j in range(active_enemies.size()):
		var e_spr = active_enemies[j].get("sprite")
		if is_instance_valid(e_spr):
			e_spr.z_index = 0
			_enemy_zoom_tween.tween_property(e_spr, "modulate", Color.WHITE, duration)

## HP計算（ダメージ適用：指定された敵、または集中攻撃ターゲットへダメージを適用）
func calchp(damage_to_enemy: float, damage_to_player: float, target_specifier = null) -> void:
	myhp = clampf(myhp - damage_to_player, 0.0, myhpmax)
	myhppar = myhp / myhpmax if myhpmax > 0 else 0.0
	
	if damage_to_enemy > 0.0 and active_enemies.size() > 0:
		var target_idx: int = -1
		if target_specifier is Sprite2D:
			for idx in range(active_enemies.size()):
				if active_enemies[idx].get("sprite") == target_specifier:
					target_idx = idx
					break
		elif typeof(target_specifier) == TYPE_INT and target_specifier >= 0 and target_specifier < active_enemies.size():
			target_idx = target_specifier
		elif target_specifier is Dictionary:
			for idx in range(active_enemies.size()):
				if active_enemies[idx] == target_specifier:
					target_idx = idx
					break
		
		# 指定敵が見つからない場合は、フォーカス敵（または0番目）
		if target_idx < 0:
			target_idx = get_focused_enemy_index()
			if target_idx < 0 or target_idx >= active_enemies.size():
				target_idx = 0

		var e_data = active_enemies[target_idx]
		if e_data["hp"] > 0:
			e_data["hp"] -= damage_to_enemy
			if is_instance_valid(e_data.get("sprite")):
				var spr = e_data["sprite"]
				if spr.has_meta("dmg_tw"):
					var old_tw = spr.get_meta("dmg_tw")
					if is_instance_valid(old_tw) and old_tw is Tween:
						old_tw.kill()
				var tw = create_tween()
				spr.set_meta("dmg_tw", tw)
				spr.modulate = Color(2.0, 1.8, 1.8, 1.0)
				tw.tween_property(spr, "modulate", Color.WHITE, 0.12)
			if e_data["hp"] <= 0:
				if is_instance_valid(e_data.get("sprite")):
					var dead_spr = e_data["sprite"]
					if _active_single_anims.has(dead_spr):
						_active_single_anims.erase(dead_spr)
					var die_tw = create_tween()
					die_tw.tween_property(dead_spr, "scale", Vector2.ZERO, 0.2)
					die_tw.tween_callback(dead_spr.queue_free)
				if e_data.has("bar_bg") and is_instance_valid(e_data["bar_bg"]): e_data["bar_bg"].queue_free()
				if e_data.has("bar_red") and is_instance_valid(e_data["bar_red"]): e_data["bar_red"].queue_free()
				if e_data.has("bar_green") and is_instance_valid(e_data["bar_green"]): e_data["bar_green"].queue_free()
				if e_data.has("bar_fg") and is_instance_valid(e_data["bar_fg"]): e_data["bar_fg"].queue_free()
				if e_data.has("lbl") and is_instance_valid(e_data["lbl"]): e_data["lbl"].queue_free()
				if e_data.has("hp_lbl") and is_instance_valid(e_data["hp_lbl"]): e_data["hp_lbl"].queue_free()
				if e_data.has("target_badge") and is_instance_valid(e_data["target_badge"]): e_data["target_badge"].queue_free()
				if e_data.has("target_frame") and is_instance_valid(e_data["target_frame"]): e_data["target_frame"].queue_free()
				active_enemies.remove_at(target_idx)
				hide_enemy_hover_tooltip()
				if target_enemy_index >= 0:
					target_enemy_index = clampi(target_enemy_index, 0, max(0, active_enemies.size() - 1))
				_update_target_indicator()
				var rm = _get_relic_manager()
				if rm and rm.has_method("on_enemy_defeated"):
					rm.on_enemy_defeated()
		if active_enemies.size() > 0:
			var cur_focus = get_focused_enemy_index()
			if cur_focus >= 0 and cur_focus < active_enemies.size():
				enemy = active_enemies[cur_focus]["sprite"]
			else:
				enemy = active_enemies[0]["sprite"]
		else:
			enemy = null
			_active_single_anims.clear()
			is_playing_custom_animation = false
			_current_custom_anim = ""
		if target_idx < active_enemies.size() and active_enemies[target_idx]["hp"] > 0:
			var target_e = active_enemies[target_idx]
			var t_spr = target_e.get("sprite")
			if is_instance_valid(t_spr):
				var cur_anim = _active_single_anims.get(t_spr, "")
				if cur_anim != "attack" and cur_anim != "skill":
					play_single_enemy_animation(target_idx, "damaged")

	var sum_hp = 0.0
	for e in active_enemies:
		var cur_e_hp = float(e.get("hp", 0.0))
		if cur_e_hp > 0: sum_hp += cur_e_hp
	ehp = sum_hp
	ehppar = ehp / ehpmax if ehpmax > 0 else 0.0
	if ehp <= 0 and not isdeadf:
		isdead()
## フィーバーゲージ蓄積
func calcgage(potion: float) -> void:
	if isfevertime:
		return
	fevergage = minf(7000.0, fevergage + potion)
	feverpar = fevergage / 7000.0

## HPバー表示の更新
func displayhp() -> void:
	for e in active_enemies:
		var p = e["hp"] / e["max_hp"] if e["max_hp"] > 0 else 0
		var target_w = p * 100.0
		
		if is_instance_valid(e["bar_green"]):
			e["bar_green"].size = Vector2(target_w, 10.0)
			
		if is_instance_valid(e["bar_red"]):
			var cur_w = e["bar_red"].size.x
			if cur_w > target_w:
				e["bar_red"].size.x = max(target_w, cur_w - 0.75)
			else:
				e["bar_red"].size.x = target_w
				
		if is_instance_valid(e["hp_lbl"]):
			var cur_hp_int = int(e["hp"])
			var last_hp = e.get("last_hp_int", -1)
			if cur_hp_int != last_hp:
				e["last_hp_int"] = cur_hp_int
				e["hp_lbl"].text = "[center][color=#FFFFFF]" + str(cur_hp_int) + " / " + str(int(e["max_hp"])) + "[/color][/center]"
				
	if enemy_race_lbl != null and is_instance_valid(enemy_race_lbl):
		enemy_race_lbl.visible = false
	if enemy_hp_lbl != null and is_instance_valid(enemy_hp_lbl):
		enemy_hp_lbl.visible = false
	if ehpbar != null and is_instance_valid(ehpbar):
		ehpbar.visible = false
	if ehpbar1 != null and is_instance_valid(ehpbar1):
		ehpbar1.visible = false

	# プレイヤーHPの更新処理（復元）
	if _cached_hp_bar == null or not is_instance_valid(_cached_hp_bar):
		_cached_hp_bar = get_parent().get_node_or_null("ScoreManager/hpbar1") as ColorRect if get_parent() else null
	if _cached_hp_bar:
		_cached_hp_bar.size = Vector2(min(int(myhppar * 725.0), 725), 26.0)
		
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
			player_hp_lbl.z_index = 10
			var sm_node = _get_score_manager()
			if sm_node:
				sm_node.add_child(player_hp_lbl)
			else:
				add_child(player_hp_lbl)
		
		var cur_myhp_int: int = int(myhp)
		var cur_myhpmax_int: int = int(myhpmax)
		if cur_myhp_int != _last_myhp or cur_myhpmax_int != _last_myhpmax:
			_last_myhp = cur_myhp_int
			_last_myhpmax = cur_myhpmax_int
			
			var s_hp = str(absi(cur_myhp_int))
			var res_hp = ""
			for i in range(s_hp.length() - 1, -1, -1):
				res_hp = s_hp[i] + res_hp
				if (s_hp.length() - i) % 3 == 0 and i != 0: res_hp = "," + res_hp
				
			var s_max = str(absi(cur_myhpmax_int))
			var res_max = ""
			for i in range(s_max.length() - 1, -1, -1):
				res_max = s_max[i] + res_max
				if (s_max.length() - i) % 3 == 0 and i != 0: res_max = "," + res_max
				
			player_hp_lbl.text = "[center][b][color=#FFFF00]PLAYER HP[/color] [color=#FFFFFF]%s / %s[/color][/b][/center]" % [res_hp, res_max]

## ゲージ表示の更新
func displaygage() -> void:
	if _cached_fever_bar == null or not is_instance_valid(_cached_fever_bar):
		_cached_fever_bar = get_parent().get_node_or_null("ScoreManager/feverbar2") as ColorRect if get_parent() else null
	if _cached_fever_bar:
		var cur_par: float = (float(fevercount) / 5.0) if isfevertime else feverpar
		_cached_fever_bar.size = Vector2(int(cur_par * 725.0), 24.0)
		
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
				
		var pct = clampi(int(cur_par * 100.0), 0, 100)
		if pct != _last_fever_pct:
			_last_fever_pct = pct
			if isfevertime:
				fever_bar_lbl.text = "[center][b][rainbow freq=0.8 sat=2 val=20]★ FEVER TIME ★[/rainbow] [color=#FFFFFF]残り%dターン (%d%%)[/color][/b][/center]" % [fevercount, pct]
			else:
				fever_bar_lbl.text = "[center][b][color=#FFD700]FEVER GAUGE[/color] [color=#FFFFFF]%d%%[/color][/b][/center]" % pct

	if _cached_fever_count_lbl == null or not is_instance_valid(_cached_fever_count_lbl):
		_cached_fever_count_lbl = get_parent().get_node_or_null("ScoreManager/fevertimecount") if get_parent() else null
	if _cached_fever_count_lbl:
		if not _cached_fever_count_lbl.has_theme_font_override("normal_font"):
			_cached_fever_count_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			_cached_fever_count_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			_cached_fever_count_lbl.add_theme_constant_override("outline_size", 8)
			_cached_fever_count_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		if fevercount != _last_fever_count:
			_last_fever_count = fevercount
			_cached_fever_count_lbl.text = "[center][b][color=#FFD700]%d[/color][/b][/center]" % fevercount

## 敵死亡時の処理
func isdead() -> void:
	hide_enemy_hover_tooltip()
	stop_enemy_animation()
	var gekiha = get_parent().get_node_or_null("gekiha")
	if gekiha: gekiha.play()
	
	if get_tree():
		if is_instance_valid(_vfx_container):
			for child in _vfx_container.get_children():
				child.queue_free()
	
	for bgm_name in ["fieldbgm", "bossbgm", "maoubgm"]:
		var b = get_node_or_null(bgm_name)
		if b and b.playing:
			b.stop()
			
	for e in active_enemies:
		if is_instance_valid(e["sprite"]):
			if e["sprite"].has_meta("active_skill_tween"):
				var tw = e["sprite"].get_meta("active_skill_tween")
				if is_instance_valid(tw) and tw is Tween: tw.kill()
			e["sprite"].queue_free()
		if is_instance_valid(e["bar_bg"]): e["bar_bg"].queue_free()
		if e.has("bar_red") and is_instance_valid(e["bar_red"]): e["bar_red"].queue_free()
		if e.has("bar_green") and is_instance_valid(e["bar_green"]): e["bar_green"].queue_free()
		if e.has("bar_fg") and is_instance_valid(e["bar_fg"]): e["bar_fg"].queue_free()
		if is_instance_valid(e["lbl"]): e["lbl"].queue_free()
		if is_instance_valid(e["hp_lbl"]): e["hp_lbl"].queue_free()
	active_enemies.clear()
	enemy = null
		
	var pb = _get_puzzle_board()
	if pb and pb.has_method("_clear_board_hazards"):
		pb._clear_board_hazards()
		
	if ehpbar: ehpbar.queue_free(); ehpbar = null
	if ehpbar1: ehpbar1.queue_free(); ehpbar1 = null
	if enemy_hp_lbl != null and is_instance_valid(enemy_hp_lbl): enemy_hp_lbl.visible = false
	if enemy_race_lbl != null and is_instance_valid(enemy_race_lbl): enemy_race_lbl.visible = false
	
	enemycount = 0
	isdeadf = true
	
	if (is_current_boss or stage_enemy == 5) and stage == 5:
		islastboss = true
		lastbossinterval = 0
	elif is_current_boss or stage_enemy == 5:
		isstageclear = true
		clearinterval = 0
		var rm = _get_relic_manager()
		if rm: rm.on_stage_clear()
## フィーバータイム開始
func fevertime() -> void:
	if int(fevergage) >= 7000:
		fevercount = 5
		fevergage = 0.0
		feverpar = 1.0
		_last_fever_pct = -1
		appeartime = 0
		isfevertime = true
		
		var rm = _get_relic_manager()
		if rm and rm.has_method("on_fever_started"):
			rm.on_fever_started()
		
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
	fevergage = 0.0
	feverpar = 0.0
	_last_fever_pct = -1
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

	# フィーバー演出の顔パーティクルを全消去してメモリ解放
	for face in facearr:
		if face != null and is_instance_valid(face):
			face.queue_free()
	facearr.clear()

func _process(_delta: float) -> void:
	var _prof = Profiler.begin("stage_manager::_process")
	var spd: float = maxf(0.1, _get_game_speed())
	if _damaged_anim_timer > 0.0:
		_damaged_anim_timer = maxf(0.0, _damaged_anim_timer - _delta * spd)

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
	var _prof = Profiler.begin("stage_manager::_step_process")
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
				# RELIC_OFFER_BATTLE_INDICES (例: 2戦目) に該当する場合のみレリック選択画面を挟む
				if stage_enemy in RELIC_OFFER_BATTLE_INDICES:
					_open_relic_selection(func():
						if choose_buff_rect: choose_buff_rect.visible = true
						_set_buff_buttons_visible(true)
						if move_front_btn: move_front_btn.visible = true
						clicked = false
					)
				else:
					if choose_buff_rect: choose_buff_rect.visible = true
					_set_buff_buttons_visible(true)
					if move_front_btn: move_front_btn.visible = true
					clicked = false
			else:
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

	var _t_me = Time.get_ticks_usec()
	make_enemy(stage_enemy == 5)
	var _d_me = Time.get_ticks_usec() - _t_me
	if _d_me > 1000: print("[SPIKE] make_enemy took %.2f ms" % (_d_me / 1000.0))
	displayhp()
	displaygage()
	interval += 1
	
	if interval == 40:
		var se = get_parent().get_node_or_null("syutsugen")
		if se: se.play()
	elif interval == 105:
		var kemuri = _enemy_zoom_root.get_node_or_null("kemuri") if _enemy_zoom_root else (get_parent().get_node_or_null("kemuri") if get_parent() else null)
		if kemuri:
			kemuri.visible = false
			kemuri.stop()
			kemuri.position = Vector2(-1e9, -1e9)

	# 背景の切り替え（ステージ変更時のみ軽量実行）
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
	
		
		var b_bgm = get_node_or_null("bossbgm")
		if b_bgm: b_bgm.stop()
		var kirikae = get_parent().get_node_or_null("stagekirikae")
		if kirikae: kirikae.play()
	elif clearinterval == 161:
		if 5 in RELIC_OFFER_BATTLE_INDICES:
			_open_relic_selection(func():
				if choose_buff_rect: choose_buff_rect.visible = true
				_set_buff_buttons_visible(true)
				if sm:
					var next_btn = sm.get_node_or_null("stagechangeb")
					if next_btn: next_btn.visible = true
			)
		else:
			if choose_buff_rect: choose_buff_rect.visible = true
			_set_buff_buttons_visible(true)
			if sm:
				var next_btn = sm.get_node_or_null("stagechangeb")
				if next_btn: next_btn.visible = true
	clearinterval += 1

## レリック選択画面を開き、選択（またはスキップ）後に on_finished を呼ぶ
func _open_relic_selection(on_finished: Callable) -> void:
	var p = get_parent()
	if p == null:
		on_finished.call()
		return
	var r_ui = RELIC_SELECTION_UI_SCRIPT.new()
	r_ui.selection_finished.connect(on_finished, CONNECT_ONE_SHOT)
	p.add_child(r_ui)

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
			
	# 顔アイコンの落下と生成（毎フレーム無制限追加を防ぎ、最大24個に制限）
	var alive_faces: Array[Node2D] = []
	for face in facearr:
		if face != null and is_instance_valid(face):
			face.position.y += 24.0
			if face.position.y >= 4000.0:
				face.queue_free()
			else:
				alive_faces.append(face)
	facearr = alive_faces
	
	if fever_face_template and facearr.size() < 24:
		var new_face: Node2D = fever_face_template.duplicate()
		new_face.position = Vector2(randi() % 14000, 0)
		add_child(new_face)
		facearr.append(new_face)

## 背景画像の切り替え（敵背景・全画面背景・盤面背景の完全同期）
func _update_background() -> void:
	if _last_updated_bg_stage == stage:
		return
	_last_updated_bg_stage = stage

	var cur_idx: int = clampi(stage - 1, 0, STAGE_BACKGROUND_TEXTURES.size() - 1)
	var cur_texture: Texture2D = STAGE_BACKGROUND_TEXTURES[cur_idx]

	# 1. 敵エリアの背景スプライト更新
	for i in range(STAGE_BACKGROUNDS.size()):
		var bg_name = STAGE_BACKGROUNDS[i]
		var bg_node = _enemy_zoom_root.get_node_or_null(bg_name) if _enemy_zoom_root else get_node_or_null(bg_name)
		if bg_node == null:
			bg_node = get_node_or_null(bg_name)
		if bg_node:
			bg_node.visible = (i == cur_idx)
			bg_node.texture = cur_texture

	# 2. 全画面主背景スプライト（sougen2D）更新（敵がいる欄以外の全領域＝ゲーム主背景をカジノ風に維持）
	var p = get_parent()
	var fullscreen_bg = p.get_node_or_null("sougen2D") if p else null
	if fullscreen_bg and _cached_casino_bg:
		if fullscreen_bg.texture != _cached_casino_bg:
			fullscreen_bg.texture = _cached_casino_bg
		var tex_size = _cached_casino_bg.get_size()
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
	if parent:
		for i in range(6):
			var btn = parent.get_node_or_null("buffselectbutton" + str(i))
			if btn: btn.visible = false
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
	var rm = _get_relic_manager()
	if rm: rm.on_battle_start()
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

func play_single_enemy_animation(target, anim_name: String, on_complete: Callable = Callable()) -> bool:
	var e = null
	var enemy_index: int = -1
	if target is Sprite2D:
		for idx in range(active_enemies.size()):
			if active_enemies[idx].get("sprite") == target:
				e = active_enemies[idx]
				enemy_index = idx
				break
	elif typeof(target) == TYPE_INT:
		if target >= 0 and target < active_enemies.size():
			e = active_enemies[target]
			enemy_index = target
	elif target is Dictionary and target.has("sprite"):
		e = target
		for idx in range(active_enemies.size()):
			if active_enemies[idx] == target:
				enemy_index = idx
				break

	if e == null or not is_instance_valid(e.get("sprite")):
		return false
	var spr: Sprite2D = e["sprite"]
	var e_key = e["key"]
	var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
	if not e_anims.has(anim_name):
		return false

	if spr.has_meta("anim_tween"):
		var old_tw = spr.get_meta("anim_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()

	if spr.has_meta("rush_tween"):
		var old_tw = spr.get_meta("rush_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
			
	if spr.has_meta("idle_tween"):
		var old_tw = spr.get_meta("idle_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()

	var anim_info = e_anims[anim_name]
	var sheet_path = anim_info.get("path", "")
	var sheet_tex: Texture2D = _get_anim_texture(sheet_path)
	if sheet_tex == null or not is_instance_valid(spr):
		return false

	var hf: int = anim_info["hframes"]
	var vf: int = anim_info["vframes"]
	var total_f: int = anim_info.get("total_frames", 1)
	var fps: float = anim_info.get("fps", 1.0)
	var should_flip: bool = anim_info.get("flip_h", false)
	var scale_mult: float = anim_info.get("scale_mult", 1.0)
	var offset_pos: Vector2 = anim_info.get("offset", Vector2.ZERO)

	if not spr.has_meta("anim_orig_tex"):
		spr.set_meta("anim_orig_tex", spr.texture)
		spr.set_meta("anim_orig_scale", spr.get_meta("base_scale", spr.scale))
		spr.set_meta("anim_orig_pos", spr.position)

	var orig_tex = spr.get_meta("anim_orig_tex")
	var orig_s = spr.get_meta("anim_orig_scale")
	var orig_p = spr.get_meta("anim_orig_pos")
	var frame_w = sheet_tex.get_size().x / float(hf)
	var orig_w = orig_tex.get_size().x if orig_tex else frame_w
	var target_scale = orig_s * (float(orig_w) / float(frame_w)) * scale_mult

	spr.texture = sheet_tex
	spr.hframes = hf
	spr.vframes = vf
	spr.frame = 0
	spr.scale = target_scale
	spr.flip_h = should_flip
	spr.position = orig_p + offset_pos
	spr.material = _get_or_create_edge_fade_material()
	spr.set_meta("anim_total_f", total_f)

	_active_single_anims[spr] = anim_name
	is_playing_custom_animation = true
	_current_custom_anim = anim_name

	var duration = float(total_f) / maxf(1.0, fps)
	
	if anim_name == "attack":
		var rush_tw = create_tween()
		spr.set_meta("rush_tween", rush_tw)
		rush_tw.bind_node(spr)
		var rush_in_dur = minf(0.24, duration * 0.3)
		var rush_out_dur = minf(0.22, duration * 0.25)
		var hold_dur = maxf(0.0, duration - rush_in_dur - rush_out_dur)
		
		rush_tw.tween_property(spr, "position", orig_p + Vector2(-60, 0) + offset_pos, rush_in_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		rush_tw.tween_interval(hold_dur)
		rush_tw.tween_property(spr, "position", orig_p + offset_pos, rush_out_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tw = create_tween()
	spr.set_meta("anim_tween", tw)
	tw.bind_node(spr)
	tw.tween_method(func(f_idx: int):
		if is_instance_valid(spr):
			spr.frame = clampi(f_idx, 0, total_f - 1)
	, 0, total_f - 1, duration)
	
	tw.tween_callback(func():
		_active_single_anims.erase(spr)
		if _active_single_anims.is_empty():
			is_playing_custom_animation = false
			_current_custom_anim = ""
		else:
			_current_custom_anim = ""
			for a in _active_single_anims.values():
				if a == "attack" or a == "skill":
					_current_custom_anim = a
					break
			if _current_custom_anim == "":
				_current_custom_anim = _active_single_anims.values()[0]

		if is_instance_valid(spr):
			spr.texture = orig_tex
			spr.hframes = 1
			spr.vframes = 1
			spr.frame = 0
			spr.scale = orig_s
			spr.flip_h = false
			spr.position = orig_p
			spr.material = null
			play_single_idle_loop(spr)
		if on_complete:
			on_complete.call()
	)
	return true

## 敵のアニメーション所要時間（秒）を正確に取得（スプライトシートのアニメーション長さに完全準拠）
func get_enemy_animation_duration(target, anim_name: String) -> float:
	var e = null
	if target is Sprite2D:
		for item in active_enemies:
			if item.get("sprite") == target:
				e = item
				break
	elif typeof(target) == TYPE_INT and target >= 0 and target < active_enemies.size():
		e = active_enemies[target]
	elif target is Dictionary and target.has("sprite"):
		e = target
	if e == null:
		return 0.45

	var e_key = e.get("key", current_enemy_key)
	var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
	if not e_anims.has(anim_name):
		return 0.45

	var anim_info = e_anims[anim_name]
	var total_f: int = anim_info.get("total_frames", 1)
	var fps: float = anim_info.get("fps", 1.0)
	var duration = float(total_f) / maxf(1.0, fps)
	return maxf(0.45, duration)

func play_single_idle_loop(target) -> void:
	var e = null
	if target is Sprite2D:
		for item in active_enemies:
			if item.get("sprite") == target:
				e = item
				break
	elif typeof(target) == TYPE_INT:
		if target >= 0 and target < active_enemies.size():
			e = active_enemies[target]
	elif target is Dictionary and target.has("sprite"):
		e = target
	if e == null:
		return
	var spr: Sprite2D = e["sprite"]
	var e_key = e["key"]
	var e_anims = ENEMY_ANIMATION_SHEETS.get(e_key, {})
	if not e_anims.has("idle"):
		return
		
	if spr.has_meta("idle_tween"):
		var old_tw = spr.get_meta("idle_tween")
		if is_instance_valid(old_tw) and old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
			
	var anim_info = e_anims["idle"]
	var sheet_path = anim_info.get("path", "")
	var sheet_tex = _get_anim_texture(sheet_path)
	if not sheet_tex or not is_instance_valid(spr): return
	
	var hf: int = anim_info["hframes"]
	var vf: int = anim_info["vframes"]
	var total_f: int = anim_info["total_frames"]
	var fps: float = anim_info["fps"]
	var should_flip: bool = anim_info.get("flip_h", false)
	var scale_mult: float = anim_info.get("scale_mult", 1.0)
	var offset_pos: Vector2 = anim_info.get("offset", Vector2.ZERO)

	if not spr.has_meta("anim_orig_tex"):
		spr.set_meta("anim_orig_tex", spr.texture)
		spr.set_meta("anim_orig_scale", spr.get_meta("base_scale", spr.scale))
		spr.set_meta("anim_orig_pos", spr.position)

	var orig_tex = spr.get_meta("anim_orig_tex")
	var orig_s = spr.get_meta("anim_orig_scale")
	var orig_p = spr.get_meta("anim_orig_pos")
	var frame_w = sheet_tex.get_size().x / float(hf)
	var orig_w = orig_tex.get_size().x if orig_tex else frame_w
	var target_scale = orig_s * (float(orig_w) / float(frame_w)) * scale_mult

	spr.texture = sheet_tex
	spr.hframes = hf
	spr.vframes = vf
	spr.frame = 0
	spr.scale = target_scale
	spr.flip_h = should_flip
	spr.position = orig_p + offset_pos
	spr.material = _get_or_create_edge_fade_material()
	spr.set_meta("anim_total_f", total_f)

	var duration = float(total_f) / maxf(1.0, fps)
	var tw = create_tween().set_loops()
	spr.set_meta("idle_tween", tw)
	tw.bind_node(spr)
	tw.tween_method(func(f_idx: int):
		if is_instance_valid(spr):
			spr.frame = clampi(f_idx, 0, total_f - 1)
	, 0, total_f - 1, duration)

func _get_relic_manager() -> Node:
	if not is_inside_tree() or get_tree() == null:
		return null
	var r = get_tree().get_root()
	if r == null: return null
	return r.find_child("RelicManager", true, false)
