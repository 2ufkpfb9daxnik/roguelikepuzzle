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

signal skill_upgraded(skill_id: String, sp_type: int, new_level: int)

# --- 公開プロパティ（他ノードから参照される変数） ---
var totalScore: int = 0
var divscore: Array = [0, 0, 0, 0, 0] # [SHIELD, SWORD, COIN, POTION, FOOD]
var combocount: int = 0
var iscombo: bool = false
var gridscore: Array = []

# バフ購入に必要なコインコスト（後方互換用）
var currentshieldcoin: int = 3000
var currentswordcoin: int = 3000
var currentcoincoin: int = 3000
var currentfoodcoin: int = 3000
var currentfevercoin: int = 3000
var currenthpcoin: int = 4000
var currentbombcoin: int = 5000
var fever_boost_level: int = 0
var hp_boost_level: int = 0
var bomb_buff_level: int = 0

# ショップ＆スキルツリーUI管理
var current_shop_page: int = 0
var current_view_mode: int = 0 # 0: ショップ(コイン購入), 1: スキルツリー(余剰ポーション)
var is_shop_open: bool = false
var shop_page_container: HBoxContainer = null
var prev_page_btn: Button = null
var next_page_btn: Button = null
var page_indicator_lbl: Label = null

var shop_root_panel: Panel = null
var shop_tab_btn: Button = null
var skill_tab_btn: Button = null
var coin_currency_lbl: RichTextLabel = null
var potion_currency_lbl: RichTextLabel = null
var shop_view_container: Control = null
var skill_tree_container: Control = null
var shop_card_refs: Array[Dictionary] = []
var skill_node_refs: Array[Dictionary] = []

# パフォーマンス最適化用キャッシュ変数
var _cached_jp_font: SystemFont = null
func _get_jp_font() -> SystemFont:
	if _cached_jp_font == null:
		_cached_jp_font = SystemFont.new()
		_cached_jp_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		_cached_jp_font.font_weight = 700
	return _cached_jp_font

var _last_total_score: int = -999999
var _last_divscore: Array = [-1, -1, -1, -1, -1]
var _last_combocount: int = -999999
var _shop_ui_dirty: bool = true
var _last_shop_open_state: bool = false
var _last_shop_page: int = -1

# 全バフ・特殊アイテムのカタログ定義
var stat_levels: Array[int] = [0, 0, 0, 0, 0] # 属性ごとのレベル [SHIELD, SWORD, COIN, POTION, FOOD]

# ショップ購入アイテム（コイン使用：獲得スコア強化・体力強化）
var shop_items: Array[Dictionary] = [
	{
		"id": "shield",
		"type": "stat_shield",
		"name": "シールド強化",
		"subtitle": "獲得スコア上昇",
		"desc": "シールド消去時の基礎獲得スコアが1コマあたり+100上昇します。",
		"icon_path": "res://Texture/shield/shield_cut.png",
		"color": Color("#00E5FF"),
		"cost": 3000,
		"level": 0
	},
	{
		"id": "sword",
		"type": "stat_sword",
		"name": "攻撃スコア強化",
		"subtitle": "獲得スコア上昇",
		"desc": "剣消去時の基礎獲得スコア（攻撃力）が1コマあたり+100上昇します。",
		"icon_path": "res://Texture/sword/sword_cut.png",
		"color": Color("#FF5252"),
		"cost": 3000,
		"level": 0
	},
	{
		"id": "food",
		"type": "stat_food",
		"name": "回復スコア強化",
		"subtitle": "獲得スコア上昇",
		"desc": "パン消去時の基礎獲得スコア（HP回復量）が1コマあたり+100上昇します。",
		"icon_path": "res://Texture/food/bread_cut.png",
		"color": Color("#76FF03"),
		"cost": 3000,
		"level": 0
	},
	{
		"id": "coin",
		"type": "stat_coin",
		"name": "コイン獲得強化",
		"subtitle": "獲得スコア上昇",
		"desc": "コイン消去時の基礎獲得スコア（獲得資金）が1コマあたり+100上昇します。",
		"icon_path": "res://Texture/coin/coin_cut.png",
		"color": Color("#FFD700"),
		"cost": 3000,
		"level": 0
	},
	{
		"id": "fever",
		"type": "stat_fever",
		"name": "フィーバー強化",
		"subtitle": "獲得スコア倍率上昇",
		"desc": "フィーバータイム中の全属性獲得スコア倍率が+0.5倍上昇します。",
		"icon_path": "res://Texture/potion/potion_cut.png",
		"color": Color("#FF2E93"),
		"cost": 3000,
		"level": 0
	},
	{
		"id": "max_hp",
		"type": "stat_hp",
		"name": "最大体力強化",
		"subtitle": "体力上限＆即時回復",
		"desc": "プレイヤーの最大HPを大幅に増加させ、増加分だけ即座に回復します。",
		"icon_path": "res://Texture/food/bread_cut.png",
		"color": Color("#00E676"),
		"cost": 2000,
		"level": 0
	}
]

# 属性カテゴリー別ツリー定義（全属性を3分類）
const CATEGORY_TREE_DEFS: Dictionary = {
	"nature": {
		"title": "🌿 自然・生命系スキルツリー (水・氷・木・風)",
		"banner": "🌿 【自然・生命】水・氷・木・風のスキルを解放・強化します。ポーションを消費して解放・強化できます。",
		"branch_titles": ["💧 水・清流系", "🌱 木・自然系", "🌪️ 風・浄化系"],
		"branch_colors": [Color("#00B0FF"), Color("#76FF03"), Color("#00E676")]
	},
	"force": {
		"title": "🔥 元素・破壊系スキルツリー (火・雷・地)",
		"banner": "🔥 【元素・破壊】火・雷・地のスキルを解放・強化します。ポーションを消費して解放・強化できます。",
		"branch_titles": ["🔥 炎・爆破系", "⚡ 雷・電磁系", "💎 地・蓄撃系"],
		"branch_colors": [Color("#FF6D00"), Color("#FFD600"), Color("#FFAB00")]
	},
	"mystic": {
		"title": "🔮 神秘・冥術系スキルツリー (毒・光・闇)",
		"banner": "🔮 【神秘・冥術】毒・光・闇のスキルを解放・強化します。ポーションを消費して解放・強化できます。",
		"branch_titles": ["✨ 光・聖像系", "🌙 闇・重力系", "🧪 毒・冥瘴系"],
		"branch_colors": [Color("#FFF176"), Color("#BA68C8"), Color("#00E5FF")]
	}
}

# スキルツリー定義（余剰ポーション使用：スキル獲得・生成能力解放・強化）
var skill_tree_items: Array[Dictionary] = [
	# === 1. 元素・破壊系 (Force: 火・雷・地) ===
	{
		"id": "bomb",
		"sp_type": 1,
		"category": "force",
		"branch": 0,
		"tier": 0,
		"req_id": "",
		"name": "フレイムボム",
		"short_label": "爆",
		"desc_lv": [
			"【剣の4個消しで生成】周囲3×3マスを業火で爆破消去",
			"周囲5×5マスを大爆破＋爆破ダメージ1.5倍",
			"周囲7×7マスを超広範囲爆破＋【剣4消しで2個同時生成】解放！"
		],
		"color": Color("#FF9100"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "cross_bomb",
		"sp_type": 2,
		"category": "force",
		"branch": 0,
		"tier": 1,
		"req_id": "bomb",
		"name": "クロスブレイズ",
		"short_label": "十",
		"desc_lv": [
			"【交差消し(T/L/十字)で生成】縦横1列を貫通する十文字火柱",
			"縦横3列の極太火柱で一掃＋交差消去スコア2倍",
			"画面端まで全貫通の巨大十文字火柱＋【交差消しで2個同時生成】解放！"
		],
		"color": Color("#FF3D00"),
		"cost": 2500,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "gemini_bomb",
		"sp_type": 12,
		"category": "force",
		"branch": 0,
		"tier": 2,
		"req_id": "cross_bomb",
		"name": "ジェミニボム",
		"short_label": "双",
		"desc_lv": [
			"【6個同時消しで生成】双子爆弾が半径1マスを共鳴爆破",
			"共鳴爆破(半径2)＋双子間を結ぶ直線上コマを完全消去",
			"超共鳴爆破(半径3)＋極太レーザー＋【6消しで2個同時生成】解放！"
		],
		"color": Color("#FF1744"),
		"cost": 5000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "lightning",
		"sp_type": 5,
		"category": "force",
		"branch": 1,
		"tier": 0,
		"req_id": "",
		"name": "ライトニング",
		"short_label": "雷",
		"desc_lv": [
			"【剣の5個直線消しで生成】盤面3箇所に落雷(水たまり感電連鎖)",
			"5箇所落雷＋着弾点周囲に感電衝撃波拡散",
			"8箇所超落雷＋全水たまり同時誘爆＋【剣5消しで2個同時生成】解放！"
		],
		"color": Color("#FFEA00"),
		"cost": 2000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "magnet",
		"sp_type": 10,
		"category": "force",
		"branch": 1,
		"tier": 1,
		"req_id": "lightning",
		"name": "マグネットストーム",
		"short_label": "磁",
		"desc_lv": [
			"【コイン5個直線消しで生成】同種コマ8個を中央へ引き寄せ大連結",
			"同種コマ12個を強力吸引＋一斉4マッチ化",
			"画面内の同種コマ18個を超磁力で集結＋【コイン5消しで2個同時生成】解放！"
		],
		"color": Color("#40C4FF"),
		"cost": 4000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "charge_bomb",
		"sp_type": 11,
		"category": "force",
		"branch": 2,
		"tier": 0,
		"req_id": "",
		"name": "チャージボム",
		"short_label": "蓄",
		"desc_lv": [
			"【盾の4個消しで生成】隣接消去で蓄電し3段階チャージ後大爆発",
			"蓄電チャージ速度2倍＆爆発範囲が5×5マスへ拡大",
			"超蓄電ギガバースト(画面半面大掃討)＋【盾4消しで2個同時生成】解放！"
		],
		"color": Color("#FFAB00"),
		"cost": 1500,
		"level": 0,
		"max_level": 20
	},

	# === 2. 自然・生命系 (Nature: 水・氷・木・風) ===
	{
		"id": "aqua_splash",
		"sp_type": 8,
		"category": "nature",
		"branch": 0,
		"tier": 0,
		"req_id": "",
		"name": "アクアスプラッシュ",
		"short_label": "水",
		"desc_lv": [
			"【ポーション4個消しで生成】周囲3×3マスを水浸し展開",
			"広範囲(半径2)を水浸し＆消去＋ポーション回復量+50%",
			"超広範囲(半径3)大洪水展開＋【ポーション4消しで2個同時生成】解放！"
		],
		"color": Color("#00B0FF"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "tree_sprout",
		"sp_type": 9,
		"category": "nature",
		"branch": 1,
		"tier": 0,
		"req_id": "",
		"name": "生命の苗木",
		"short_label": "樹",
		"desc_lv": [
			"【パン4個消しで生成】生命の苗木出現・吸水で3×3大木へ進化",
			"大木進化時の毎ターンHP回復量2倍＋果実スコア大幅UP",
			"神聖なる世界樹へ超進化！毎ターン広域大回復＋【パン4消しで2個同時生成】！"
		],
		"color": Color("#76FF03"),
		"cost": 2500,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "color_converter",
		"sp_type": 4,
		"category": "nature",
		"branch": 1,
		"tier": 1,
		"req_id": "tree_sprout",
		"name": "フローラスプレー",
		"short_label": "染",
		"desc_lv": [
			"【パン/盾の5個直線消しで生成】周囲8マスを盤面最多属性に変換",
			"周囲5×5マスを最多属性に一括変換＋大量連鎖誘発",
			"周囲7×7マス超広域属性変換＋【5消しで2個同時生成】解放！"
		],
		"color": Color("#69F0AE"),
		"cost": 5000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "tornado",
		"sp_type": 7,
		"category": "nature",
		"branch": 2,
		"tier": 0,
		"req_id": "",
		"name": "つむじ風・竜巻",
		"short_label": "風",
		"desc_lv": [
			"【コイン4個消しで生成】直進する竜巻で1列を一掃",
			"幅3マスの巨大竜巻に拡大＋コイン獲得数1.5倍",
			"縦横2方向へ巨大竜巻が同時突進＋【コイン4消しで2個同時生成】解放！"
		],
		"color": Color("#00E676"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},

	# === 3. 神秘・冥術系 (Mystic: 毒・光・闇) ===
	{
		"id": "disco_ball",
		"sp_type": 3,
		"category": "mystic",
		"branch": 0,
		"tier": 0,
		"req_id": "",
		"name": "スターオーブ",
		"short_label": "光",
		"desc_lv": [
			"【7個以上同時消しで生成】画面内の最多属性コマを一斉破壊",
			"最多属性を一斉破壊＋消去スコア＆攻撃力2倍",
			"画面内の最多2属性を一斉破壊する奇跡＋【7個消しで2個同時生成】解放！"
		],
		"color": Color("#FFF176"),
		"cost": 2500,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "black_hole",
		"sp_type": 6,
		"category": "mystic",
		"branch": 1,
		"tier": 0,
		"req_id": "",
		"name": "ブラックホール",
		"short_label": "闇",
		"desc_lv": [
			"【ポーション5個直線消しで生成】周囲5×5マスを重力渦に吸引消滅",
			"周囲7×7マスを重力渦に吸引＋敵の行動カウントを1遅延",
			"周囲9×9マス超重力吸引＋【ポーション5消しで2個同時生成】解放！"
		],
		"color": Color("#BA68C8"),
		"cost": 3000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "poison_mist",
		"sp_type": 0,
		"category": "mystic",
		"branch": 2,
		"tier": 0,
		"req_id": "",
		"name": "薬毒散布・深淵",
		"short_label": "毒",
		"desc_lv": [
			"【毒消し・マッチで生成】敵盤面へ猛毒沼を散布し持続ダメージ",
			"毒ダメージ1.5倍＋水たまり接触時に拡散速度2倍",
			"超猛毒拡散＋敵への持続ダメージ加速！"
		],
		"color": Color("#00E5FF"),
		"cost": 1500,
		"level": 0,
		"max_level": 20
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
@onready var elem_status_rect: Control = get_node_or_null("elem_status")
@onready var elem_status2_rect: Control = get_node_or_null("elem_status2")
@onready var combo_label: RichTextLabel = get_node_or_null("combo")
@onready var combocount_label: RichTextLabel = get_node_or_null("combocount")
@onready var template_score_label: RichTextLabel = get_node_or_null("RichTextLabel3")

const ELEM_KEYS: Array[String] = ["fire", "water", "wind", "thunder", "light", "dark"]
const ELEM_COLORS: Array[String] = ["FF6633", "4C99FF", "66E666", "E6E633", "FFE699", "B34CE6"]

var divscorelabel: Array[RichTextLabel] = []
var turn_element_counts: Dictionary = {}
var turn_element_gain: Dictionary = {}
var turn_sword_element_counts: Dictionary = {}
var elem_labels: Array[RichTextLabel] = []
var _popup_pool: Array[RichTextLabel] = []
const MAX_POOLED_POPUPS: int = 16

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

func _init() -> void:
	for s_item in skill_tree_items:
		s_item["max_level"] = 20
		s_item["desc_lv"] = get_skill_descriptions(s_item["id"])

## スキルごとのLv1〜20の詳細効果テキスト生成
static func get_skill_descriptions(skill_id: String) -> Array[String]:
	match skill_id:
		"bomb":
			return [
				"【剣4個消しで生成】周囲3×3マスを業火で爆破消去",
				"周囲5×5マスを大爆破＋爆破ダメージ1.5倍",
				"周囲7×7マス超広範囲爆破＋【2個同時生成】解放！",
				"周囲7×7爆破＋石貫通ダメージ+1",
				"爆破威力2.0倍＋炎属性追撃ダメージ付与",
				"爆破範囲拡大＋隣接する水たまりを完全蒸発",
				"石貫通ダメージ+2＋爆破スコア1.5倍",
				"周囲9×9マス爆破＋連鎖誘発力UP",
				"爆破威力2.5倍＋炎上マスの即時誘爆",
				"【3個同時生成】解放！＋爆破範囲超拡大",
				"石貫通ダメージ+3＋爆破ダメージ3.0倍",
				"爆破時に周囲の障害物を完全粉砕",
				"爆破スコア2.0倍＋フィーバーゲージ獲得量UP",
				"爆破威力3.5倍＋広域画面揺動衝撃波",
				"石貫通ダメージ+4＋全域連鎖爆破",
				"爆破威力4.0倍＋敵への特大炎ダメージ",
				"超広域爆破＋水蒸気大爆発ボーナス",
				"【4個同時生成】解放！＋神速起爆",
				"爆破威力5.0倍＋石貫通ダメージ+5",
				"【神格解放】画面全域を焼き尽くす究極爆破！石完全粉砕＆確定超連鎖！"
			]
		"cross_bomb":
			return [
				"【交差消し(T/L/十字)で生成】縦横1列を貫通する十文字火柱",
				"縦横3列の極太火柱で一掃＋交差消去スコア2倍",
				"画面端まで全貫通の巨大十文字火柱＋【2個同時生成】解放！",
				"全貫通火柱＋石貫通ダメージ+1",
				"火柱ダメージ1.5倍＋貫通ライン上の水蒸発",
				"斜めX字方向への火柱拡散を追加",
				"石貫通ダメージ+2＋十文字消去スコア2.5倍",
				"火柱ダメージ2.0倍＋極太火柱へ拡大",
				"十文字＋X字の8方向レーザー照射",
				"【3個同時生成】解放！＋8方向全画面一掃",
				"石貫通ダメージ+3＋火柱ダメージ2.5倍",
				"火柱接触マスの障害物を完全消滅",
				"貫通消去スコア3.0倍＋フィーバー加速",
				"火柱ダメージ3.0倍＋敵装甲貫通効果",
				"石貫通ダメージ+4＋超極太8方向紅蓮火柱",
				"火柱ダメージ3.5倍＋敵へ直接大炎上ダメージ",
				"火柱全域貫通＋周囲2マス巻き込み",
				"【4個同時生成】解放！＋瞬時全域掃討",
				"火柱ダメージ4.5倍＋石貫通ダメージ+5",
				"【神格解放】天を穿つ神聖十字砲！全方位完全貫通＆石粉砕＆超ダメージ！"
			]
		"gemini_bomb":
			return [
				"【6個同時消しで生成】双子爆弾が半径1マスを共鳴爆破",
				"共鳴爆破(半径2)＋双子間を結ぶ直線上コマを完全消去",
				"超共鳴爆破(半径3)＋極太レーザー＋【2個同時生成】解放！",
				"共鳴爆破＋石貫通ダメージ+1",
				"分裂爆弾数+1（計3箇所同時爆破）",
				"共鳴レーザー威力1.5倍＋結線爆破",
				"石貫通ダメージ+2＋共鳴爆破半径拡大",
				"分裂爆弾数+2（計4箇所同時爆破）",
				"共鳴爆破威力2.0倍＋レーザー極太化",
				"【3個同時生成】解放！＋分裂爆破計5箇所",
				"石貫通ダメージ+3＋共鳴爆破威力2.5倍",
				"爆破箇所間を網羅する幾何学レーザー網",
				"共鳴消去スコア2.5倍＋フィーバー蓄積UP",
				"分裂爆破計6箇所＋石貫通ダメージ+4",
				"共鳴爆破威力3.0倍＋超高密度プラズマ",
				"分裂爆破計7箇所＋全ライン消滅",
				"共鳴爆破威力3.5倍＋敵への共鳴衝撃波",
				"【4個同時生成】解放！＋分裂爆破計8箇所",
				"石貫通ダメージ+5＋共鳴威力4.0倍",
				"【神格解放】盤面全域を網羅する双子星超共鳴！全障害物粉砕＆極限連鎖！"
			]
		"aqua_splash":
			return [
				"【ポーション4個消しで生成】周囲3×3マスを水浸し展開",
				"広範囲(半径2)を水浸し＆消去＋ポーション回復量+50%",
				"超広範囲(半径3)大洪水展開＋【2個同時生成】解放！",
				"水浸し展開時に盤面の炎上マスを完全消火",
				"ポーション回復量+100%＋苗木への成長促進ボーナス",
				"水浸し範囲拡大(半径4)＋落雷感電範囲拡大",
				"展開時にHPを即座に最大値の10%回復",
				"大洪水範囲拡大＋盤面の氷を融解・浄化",
				"ポーション回復量+150%＋感電ダメージ2倍",
				"【3個同時生成】解放！＋盤面半面大洪水",
				"展開時にHPを最大値の20%即時回復",
				"水たまりマス上の苗木が即座に大木へ急成長",
				"ポーション回復量+200%＋水浸し消去スコア2倍",
				"水浸し範囲が盤面全域へ拡大",
				"展開時にHPを最大値の30%即時回復",
				"水流による敵行動遅延効果付与",
				"全水たまり感電時の衝撃波威力3倍",
				"【4個同時生成】解放！＋無限清流",
				"展開時にHPを最大値の50%即時回復",
				"【神格解放】神聖なる大瀑布！盤面全域浄化＆HP超大回復＆苗木即時世界樹化！"
			]
		"tree_sprout":
			return [
				"【パン4個消しで生成】生命の苗木出現・吸水で3×3大木へ進化",
				"大木進化時の毎ターンHP回復量2倍＋果実スコア大幅UP",
				"神聖なる世界樹へ超進化！毎ターン広域大回復＋【2個同時生成】！",
				"耐雷耐久値+1（雷の直撃を2回まで防御）",
				"【若木スタート】生成時に最初から若木(Stage 1)として出現！",
				"毎ターンHP自動回復量+50%＋パン効果2倍",
				"耐雷耐久値+2＋敵の風吹き飛ばし耐性獲得",
				"果実スコア3倍＋毎ターンシールド自動生成",
				"毎ターンHP自動回復量+100%",
				"【3個同時生成】解放！＋複数苗木の共鳴回復",
				"耐雷耐久値+3（雷直撃にほぼ無敵）",
				"【世界樹スタート】生成時から直接3×3世界樹として盤面に出現！",
				"毎ターンHP自動回復量+150%＋状態異常解除",
				"世界樹の果実が毎ターン攻撃コマへ変化",
				"耐雷耐久値+4＋炎延焼耐性獲得",
				"毎ターンHP自動回復量+200%",
				"世界樹の枝葉が盤面外周へ拡大",
				"【4個同時生成】解放！＋生命の森形成",
				"毎ターンHP自動回復量+300%＋超絶防御",
				"【神格解放】始原のユグドラシル降臨！盤面を覆う絶対生命領域＆不滅の自動超回復！"
			]
		"color_converter":
			return [
				"【パン/盾の5個直線消しで生成】周囲8マスを盤面最多属性に変換",
				"周囲5×5マスを最多属性に一括変換＋大量連鎖誘発",
				"周囲7×7マス超広域属性変換＋【2個同時生成】解放！",
				"変換時に石マスを同一属性コマへ直接置換",
				"変換範囲拡大＋連鎖スコア1.5倍",
				"盤面の毒沼や呪いマスを同一属性コマへ浄化変換",
				"変換範囲周囲9×9マス＋確実な5マッチ誘発",
				"変換コマ消去時の攻撃力＆防御力2倍",
				"変換対象が盤面の最多2属性から最適選択",
				"【3個同時生成】解放！＋盤面半面完全統一",
				"変換時に黄金像を同一属性コマへ粉砕置換",
				"変換範囲超拡大＋連鎖スコア2.5倍",
				"変換コマ消去時のポーション＆コイン獲得量2倍",
				"盤面全域の80%を一括で最多属性に変換",
				"変換時にフィーバーゲージ+25%即時チャージ",
				"変換コマ消去時のダメージ3倍",
				"盤面のあらゆる障害物を完全上書き変換",
				"【4個同時生成】解放！＋極大連鎖確定",
				"連鎖スコア4.0倍＋盤面全域90%変換",
				"【神格解放】万物を塗り替える原初の虹！盤面全域完全同色化＆神話級超特大連鎖！"
			]
		"tornado":
			return [
				"【コイン4個消しで生成】直進する竜巻で1列を一掃",
				"幅3マスの巨大竜巻に拡大＋コイン獲得数1.5倍",
				"縦横2方向へ巨大竜巻が同時突進＋【2個同時生成】解放！",
				"竜巻の石貫通ダメージ+1（石マスを粉砕）",
				"コイン獲得数2.0倍＋突進速度上昇",
				"竜巻通過列の全障害物を一掃消滅",
				"石貫通ダメージ+2＋幅5マス超大竜巻",
				"【双竜巻】縦2列へ巨大竜巻が平行突撃",
				"竜巻ダメージ2倍＋コイン獲得数2.5倍",
				"【3個同時生成】解放！＋竜巻が縦横全方位へ乱舞",
				"石貫通ダメージ+3＋竜巻通過跡が最多属性化",
				"コイン獲得数3.0倍＋フィーバー蓄積UP",
				"竜巻の吸引力で隣接列のコマも巻き込み消去",
				"石貫通ダメージ+4＋敵行動を1ターン遅延",
				"【四神竜巻】盤面全域を4本の暴風が縦断",
				"竜巻ダメージ3倍＋コイン獲得数4.0倍",
				"竜巻通過列の石・氷・黄金像を完全粉砕",
				"【4個同時生成】解放！＋疾風怒濤",
				"石貫通ダメージ+5＋コイン獲得数5.0倍",
				"【神格解放】天変地異の超神嵐！盤面全域の全障害物を粉砕し無尽蔵のコイン獲得！"
			]
		"lightning":
			return [
				"【剣の5個直線消しで生成】盤面3箇所に落雷(水たまり感電連鎖)",
				"5箇所落雷＋着弾点周囲に感電衝撃波拡散",
				"8箇所超落雷＋全水たまり同時誘爆＋【2個同時生成】解放！",
				"落雷の石貫通ダメージ+1（石マス粉砕）",
				"落雷数10発＋感電ダメージ1.5倍",
				"水たまりへの感電連鎖範囲が全画面へ拡大",
				"石貫通ダメージ+2＋落雷数12発",
				"落雷ダメージ2倍＋敵全体に感電麻痺",
				"落雷数14発＋落雷着弾点周囲の氷を完全融解",
				"【3個同時生成】解放！＋落雷数16発",
				"石貫通ダメージ+3＋落雷ダメージ2.5倍",
				"落雷数18発＋水蒸発時にプラズマ爆発",
				"落雷スコア2.5倍＋フィーバー大幅チャージ",
				"石貫通ダメージ+4＋落雷数20発",
				"落雷ダメージ3倍＋敵への特大雷属性追撃",
				"落雷数22発＋盤面の石・像を一網打尽",
				"落雷ダメージ3.5倍＋全域感電プラズマ",
				"【4個同時生成】解放！＋天罰雷撃",
				"落雷数25発＋石貫通ダメージ+5",
				"【神格解放】天帝の雷神撃！盤面全域へ無数の神雷が降り注ぎ全敵＆障害物完全粉砕！"
			]
		"magnet":
			return [
				"【コイン5個直線消しで生成】同種コマ8個を中央へ引き寄せ大連結",
				"同種コマ12個を強力吸引＋一斉4マッチ化",
				"画面内の同種コマ18個を超磁力で集結＋【2個同時生成】解放！",
				"引き寄せ時に石マスを砕いてコマを救出",
				"同種コマ22個吸引＋自動5マッチ形成",
				"コインコマを最優先吸引＋コイン獲得量2倍",
				"画面内の同種全コマを完全集結",
				"吸引時の石貫通力+2＋連鎖ボーナス2倍",
				"最多属性コマも同時に引き寄せ超連結",
				"【3個同時生成】解放！＋盤面2属性を一括集結",
				"吸引時の石貫通力+3＋障害物消滅",
				"集結コマ消去時のスコア3倍",
				"画面内の全コインコマを一点集中吸引",
				"引き寄せ時に盤面の氷や黄金像を粉砕",
				"超磁力フィールド展開＋フィーバー瞬時蓄積",
				"吸引時の石貫通力+4＋連鎖ボーナス3倍",
				"全コマを属性ごとに整列結合",
				"【4個同時生成】解放！＋絶対引力",
				"吸引時の石貫通力+5＋コイン獲得4倍",
				"【神格解放】ブラックマグネティズム！全コマを整列集結させ神速コンボ＆巨万の富！"
			]
		"charge_bomb":
			return [
				"【盾の4個消しで生成】隣接消去で蓄電し3段階チャージ後大爆発",
				"蓄電チャージ速度2倍＆爆発範囲が5×5マスへ拡大",
				"超蓄電ギガバースト(画面半面大掃討)＋【2個同時生成】解放！",
				"ギガバーストの石貫通ダメージ+1",
				"チャージ完了時の爆発威力2倍＋シールド獲得",
				"初期チャージカウント+1状態で生成",
				"石貫通ダメージ+2＋爆発範囲が7×7マスへ拡大",
				"爆発時の盾効果2倍＋敵攻撃を完全遮断",
				"ギガバースト威力2.5倍＋電磁衝撃波",
				"【3個同時生成】解放！＋最初からLv2チャージで出現",
				"石貫通ダメージ+3＋爆発威力3倍",
				"爆発時に盤面の全障害物を蒸発粉砕",
				"爆発スコア3倍＋最大シールド値一時増加",
				"石貫通ダメージ+4＋爆発範囲9×9マス",
				"爆発威力3.5倍＋超電磁シールド展開",
				"最初から最大チャージ状態で即時起爆可能",
				"石貫通ダメージ+5＋画面全域バースト",
				"【4個同時生成】解放！＋連続超放電",
				"爆発威力4.5倍＋究極電磁パルス",
				"【神格解放】反物質メガトロンバースト！全域完全蒸発＆鉄壁の絶対防壁＆敵粉砕！"
			]
		"black_hole":
			return [
				"【ポーション5個直線消しで生成】周囲5×5マスを重力渦に吸引消滅",
				"周囲7×7マスを重力渦に吸引＋敵の行動カウントを1遅延",
				"周囲9×9マス超重力吸引＋【2個同時生成】解放！",
				"重力吸引の石貫通ダメージ+1（石マス消滅）",
				"吸引範囲内の水・氷・炎・毒沼を一括吸引消滅",
				"敵の行動カウントを確実に1ターン遅延",
				"石貫通ダメージ+2＋吸引範囲拡大",
				"重力渦消去スコア2.5倍＋ポーション吸引ボーナス",
				"周囲全域の障害物を中心点へ強制吸引",
				"【3個同時生成】解放！＋複数特異点の共鳴吸引",
				"石貫通ダメージ+3＋敵行動遅延確率上昇",
				"盤面のあらゆるデバフマスを完全消滅",
				"敵の行動カウントを2ターン遅延",
				"石貫通ダメージ+4＋重力波ダメージ2倍",
				"吸引したコマ数に応じて大ダメージ追撃",
				"画面全域を包み込む超巨大ブラックホール",
				"石貫通ダメージ+5＋全障害物完全分解",
				"【4個同時生成】解放！＋事象の地平面",
				"重力波ダメージ3倍＋敵行動2ターン完全停止",
				"【神格解放】時空を呑み込む真性特異点！盤面全域完全消滅＆敵行動永久凍結＆超撃滅！"
			]
		"disco_ball":
			return [
				"【7個以上同時消しで生成】画面内の最多属性コマを一斉破壊",
				"最多属性を一斉破壊＋消去スコア＆攻撃力2倍",
				"画面内の最多2属性を一斉破壊する奇跡＋【2個同時生成】解放！",
				"一斉破壊時の石貫通ダメージ+1",
				"最多属性の周囲1マスも巻き込み破壊",
				"破壊コマ消去時の攻撃力＆スコア2.5倍",
				"石貫通ダメージ+2＋最多2属性完全掃討",
				"一斉破壊時にフィーバーゲージ+30%チャージ",
				"周囲2マス巻き込み大爆発",
				"【3個同時生成】解放！＋盤面3属性一斉消滅",
				"石貫通ダメージ+3＋消去攻撃力3倍",
				"盤面の全属性障害物（石・氷・像）を同時粉砕",
				"消去スコア4倍＋全敵へスターダスト照射",
				"石貫通ダメージ+4＋最多3属性完全掃討",
				"破壊コマ数に応じた超弩級星屑ダメージ",
				"盤面全域の85%のコマを一斉消滅",
				"石貫通ダメージ+5＋スターオーブ起爆で確定フィーバー",
				"【4個同時生成】解放！＋超新星爆発",
				"消去攻撃力5倍＋盤面全域95%消滅",
				"【神格解放】銀河を統べるステラオーブ！盤面全コマ一斉完全消滅＆銀河崩壊の究極ダメージ！"
			]
		"poison_mist":
			return [
				"【毒消し・マッチで生成】敵盤面へ猛毒沼を散布し毎ターンダメージ",
				"毒ダメージ1.5倍＋水たまり接触時に拡散速度2倍",
				"超猛毒拡散＋【2個同時生成】解放！",
				"毒ダメージ2.0倍＋敵行動カウント遅延確率UP",
				"散布範囲拡大＋味方HP吸収効果付与",
				"毒ダメージ2.5倍＋盤面の障害物を腐食劣化",
				"敵全体への腐食毒素付与＋持続ターン延長",
				"毒ダメージ3.0倍＋水たまり全域即時毒沼化",
				"毒マス消去時に追加スコア＆フィーバー蓄積",
				"【3個同時生成】解放！＋広域猛毒散布",
				"毒ダメージ3.5倍＋敵の攻撃力10%減少",
				"毒素爆発＋周囲の石・氷を腐食粉砕",
				"HP吸収率2倍＋持続ダメージ加速",
				"毒ダメージ4.0倍＋盤面半面毒沼化",
				"敵攻撃力20%減少＋毒素侵食",
				"毒ダメージ4.5倍＋即死級持続毒",
				"全域毒沼化＋水×毒連鎖大拡散",
				"【4個同時生成】解放！＋超速腐食",
				"毒ダメージ5.0倍＋敵防御力半減",
				"【神格解放】万物を融解する神毒の霧！敵の全ステータス大幅低下＆超猛毒殲滅！"
			]
		_:
			return [
				"特殊能力を発動",
				"効果範囲と威力が上昇",
				"【2個同時生成】解放！"
			]

func _ready() -> void:
	# フォントにシステム日本語フォールバックを設定（あらゆる漢字の確実な描画を保証）
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	# スコアラベルの非表示化（得点表示消去）
	if label != null:
		label.text = ""
		label.visible = false
	if label2 != null:
		label2.text = ""
		label2.visible = false

	for i in range(5):
		var score_lbl = get_node_or_null("score" + str(i)) as RichTextLabel
		if score_lbl:
			score_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			score_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			score_lbl.add_theme_constant_override("outline_size", 8)
			score_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			divscorelabel.append(score_lbl)
	

	# 各値ステータスパネルの初期化（敵の画面左端 x: 1190.0 を基準に固定幅340.0、高さ275.0）
	if status_rect != null:
		status_rect.position = Vector2(1190.0, 472.0)
		status_rect.size = Vector2(340.0, 275.0)
	if status2_rect != null:
		status2_rect.position = Vector2(1192.0, 474.0)
		status2_rect.size = Vector2(336.0, 271.0)

	# 各値アイコン（左セル x: 1192..1250 の中央に独立配置）
	for i in range(5):
		var icn_name = "score_icon" + str(i)
		var icn = get_node_or_null(icn_name) as TextureRect
		if icn == null:
			icn = TextureRect.new()
			icn.name = icn_name
			icn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			add_child(icn)
		var tex_path = "res://Texture/%s/%s.png" % [TEXTURE_DIR[i], TEXTURE_FILE[i]]
		if ResourceLoader.exists(tex_path):
			icn.texture = load(tex_path)
		icn.position = Vector2(1203.0, 474.0 + 54.0 * float(i) + 9.0)
		icn.size = Vector2(36.0, 36.0)
		icn.z_index = 2

	for i in range(mini(5, divscorelabel.size())):
		var sc_lbl = divscorelabel[i]
		sc_lbl.position = Vector2(1256.0, 476.0 + 54.0 * float(i))
		sc_lbl.scale = Vector2(0.5, 0.5)

	# 属性ステータスパネルの初期化（敵の画面中央 x: 1553.0 を基準に固定幅340.0、高さ275.0）
	if elem_status_rect == null:
		elem_status_rect = ColorRect.new()
		elem_status_rect.name = "elem_status"
		elem_status_rect.z_index = -10
		elem_status_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elem_status_rect.color = Color(0.960784, 1, 0.0901961, 1)
		add_child(elem_status_rect)
	elem_status_rect.position = Vector2(1553.0, 472.0)
	elem_status_rect.size = Vector2(340.0, 275.0)

	if elem_status2_rect == null:
		elem_status2_rect = ColorRect.new()
		elem_status2_rect.name = "elem_status2"
		elem_status2_rect.z_index = -10
		elem_status2_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elem_status2_rect.color = Color(0, 0, 0, 1)
		add_child(elem_status2_rect)
	elem_status2_rect.position = Vector2(1555.0, 474.0)
	elem_status2_rect.size = Vector2(336.0, 271.0)

	# 属性アイコン（左セル x: 1555..1613 の中央に独立配置）
	for k in range(6):
		var el_icn_name = "elem_icon" + str(k + 1)
		var el_icn = get_node_or_null(el_icn_name) as TextureRect
		if el_icn == null:
			el_icn = TextureRect.new()
			el_icn.name = el_icn_name
			el_icn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			el_icn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			el_icn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			add_child(el_icn)
		var el_tex_path = "res://Texture/element/%s.png" % ELEM_KEYS[k]
		if ResourceLoader.exists(el_tex_path):
			el_icn.texture = load(el_tex_path)
		el_icn.position = Vector2(1568.0, 474.0 + 45.16 * float(k) + 6.5)
		el_icn.size = Vector2(32.0, 32.0)
		el_icn.z_index = 2

	if divscorelabel.size() > 0:
		for k in range(6):
			var el_lbl = divscorelabel[0].duplicate()
			el_lbl.name = "elem_score" + str(k + 1)
			el_lbl.position = Vector2(1619.0, 478.0 + float(k) * 45.16)
			el_lbl.scale = Vector2(0.5, 0.5)
			el_lbl.text = ""
			add_child(el_lbl)
			elem_labels.append(el_lbl)
		update_elem_labels()

	_setup_grid_lines()

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
		combocount_label.add_theme_font_size_override("normal_font_size", 60)
		combocount_label.add_theme_font_size_override("bold_font_size", 60)
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

	# フィーバータイム欄をコンボ欄（x: 26..216, y: 166..346）の真下（x: 26..216, y: 358..590）に美しく配置
	var fv_rect = get_node_or_null("feverrect") as ColorRect
	if fv_rect:
		fv_rect.position = Vector2(26, 358)
		fv_rect.size = Vector2(190, 232)
	var fv_rect2 = get_node_or_null("feverrect2") as ColorRect
	if fv_rect2:
		fv_rect2.position = Vector2(30, 362)
		fv_rect2.size = Vector2(182, 224)

	var fv_lbl2 = get_node_or_null("feverlabel2") as RichTextLabel
	if fv_lbl2:
		fv_lbl2.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_lbl2.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_lbl2.add_theme_constant_override("outline_size", 6)
		fv_lbl2.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_lbl2.add_theme_font_size_override("normal_font_size", 18)
		fv_lbl2.add_theme_font_size_override("bold_font_size", 18)
		fv_lbl2.position = Vector2(30, 368)
		fv_lbl2.size = Vector2(182, 40)
		fv_lbl2.text = "[center][b][rainbow freq=0.8 sat=2 val=20]★ FEVER ★[/rainbow][/b][/center]"

	var fv_lbl3 = get_node_or_null("feverlabel3") as RichTextLabel
	if fv_lbl3:
		fv_lbl3.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_lbl3.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_lbl3.add_theme_constant_override("outline_size", 6)
		fv_lbl3.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_lbl3.add_theme_font_size_override("normal_font_size", 20)
		fv_lbl3.add_theme_font_size_override("bold_font_size", 20)
		fv_lbl3.position = Vector2(30, 408)
		fv_lbl3.size = Vector2(182, 40)
		update_fever_label3()

	var fv_time = get_node_or_null("fevertime") as RichTextLabel
	if fv_time:
		fv_time.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_time.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_time.add_theme_constant_override("outline_size", 6)
		fv_time.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_time.add_theme_font_size_override("normal_font_size", 18)
		fv_time.add_theme_font_size_override("bold_font_size", 18)
		fv_time.position = Vector2(30, 448)
		fv_time.size = Vector2(182, 40)
		fv_time.text = "[center][b][color=#FFFFFF]残り手数[/color][/b][/center]"

	var fv_cnt = get_node_or_null("fevertimecount") as RichTextLabel
	if fv_cnt:
		fv_cnt.add_theme_font_override("normal_font", CUSTOM_FONT)
		fv_cnt.add_theme_font_override("bold_font", CUSTOM_FONT)
		fv_cnt.add_theme_constant_override("outline_size", 8)
		fv_cnt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		fv_cnt.add_theme_font_size_override("normal_font_size", 46)
		fv_cnt.add_theme_font_size_override("bold_font_size", 46)
		fv_cnt.position = Vector2(30, 488)
		fv_cnt.size = Vector2(182, 96)

	var sc_btn = get_node_or_null("stagechangeb") as Button
	if sc_btn:
		sc_btn.add_theme_font_override("font", CUSTOM_FONT)
		sc_btn.add_theme_font_size_override("font_size", 30)
		sc_btn.add_theme_constant_override("outline_size", 6)
		sc_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))


	update_score_label()
	_setup_shop_page_controls()
	_update_buff_button_labels()
	_init_score_popup_pool()

func damage() -> float:
	return float(divscore[PieceType.SHIELD])

## スコア表示と各属性ポイント表示の更新
func update_score_label() -> void:
	if label == null:
		return

	var divscore_changed: bool = false
	for i in range(5):
		if i < divscore.size() and divscore[i] != _last_divscore[i]:
			divscore_changed = true
			break

	if totalScore == _last_total_score and not divscore_changed and combocount == _last_combocount:
		return

	_last_total_score = totalScore
	_last_combocount = combocount
	for i in range(mini(5, divscore.size())):
		_last_divscore[i] = divscore[i]
		
	# 得点表示は消去・非表示
	label.text = ""
	label.visible = false
	if label2 != null:
		label2.text = ""
		label2.visible = false
	
	var max_len: int = 0
	for i in range(mini(5, divscorelabel.size())):
		var formatted_val = _format_comma(divscore[i])
		max_len = maxi(max_len, formatted_val.length())
		var breakdown_text = ""
		if i == 0 and turn_element_gain.has(0): # PieceType.SHIELD = 0
			for el in turn_element_gain[0]:
				var el_score = turn_element_gain[0][el]
				if el_score > 0 and el != 0:
					var el_color = ElementData.ELEMENT_COLORS[el].to_html(false)
					breakdown_text += " [color=#%s]%s[/color]" % [el_color, _format_comma(el_score)]
		divscorelabel[i].text = "[b][color=%s]%s[/color][/b][font_size=20]%s[/font_size]" % [
			ATT_COLORS[i], formatted_val, breakdown_text
		]

	# 欄の横幅は固定（ユーザー要望に完全準拠: 340.0px / 内枠 336.0px）
	if status_rect != null:
		status_rect.size = Vector2(340.0, 275.0)
	if status2_rect != null:
		status2_rect.size = Vector2(336.0, 271.0)

	if combocount_label != null:
		combocount_label.text = "[center][b][color=#FFD700]%d[/color][/b][/center]" % combocount
	if combo_label != null:
		combo_label.text = "[center][b][color=#00E5FF]COMBO[/color][/b][/center]"

	if is_shop_open:
		_update_buff_button_labels()

## スコアポップアップのオブジェクトプール初期化（実行時の動的生成・破棄スパイク完全排除）
func _init_score_popup_pool() -> void:
	if template_score_label == null:
		template_score_label = get_node_or_null("RichTextLabel3")
	if template_score_label == null:
		return
	for i in range(12):
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
		popup.size = Vector2(300.0, 100.0)
		popup.pivot_offset = Vector2(150.0, 50.0)
		popup.z_index = 25
		popup.visible = false
		add_child(popup)
		_popup_pool.append(popup)

func _get_or_create_popup() -> RichTextLabel:
	for popup in _popup_pool:
		if not popup.visible:
			return popup
	if _popup_pool.size() < MAX_POOLED_POPUPS and template_score_label != null:
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
		popup.size = Vector2(300.0, 100.0)
		popup.pivot_offset = Vector2(150.0, 50.0)
		popup.z_index = 25
		popup.visible = false
		add_child(popup)
		_popup_pool.append(popup)
		return popup
	elif not _popup_pool.is_empty():
		return _popup_pool[0]
	return null

## マッチしたセルにポップアップスコア表示を生成 (Tweenによる自律アニメーション)
func display_score_label() -> void:
	# calcscore 内の _spawn_score_popup で直接スタイリッシュに生成するため互換維持
	pass

## マッチした駒グループにスタイリッシュなスコアポップアップを生成（プール再利用でゼロアロケーション化）
func _spawn_score_popup(component_cells: Array[Vector2i], att_type: int, earned_score: int, count: int, is_fever: bool) -> void:
	var popup: RichTextLabel = _get_or_create_popup()
	if popup == null:
		return

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
	popup.scale = Vector2(0.2, 0.2)
	popup.modulate.a = 1.0
	popup.visible = true

	# ポップアップ・Tweenアニメーション（勢いよく飛び出してフワッと消える）
	var p_tween = create_tween()
	p_tween.tween_property(popup, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p_tween.parallel().tween_property(popup, "position:y", popup.position.y - 20.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p_tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.08)

	p_tween.chain().tween_interval(0.35)
	p_tween.tween_property(popup, "position:y", popup.position.y - 45.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p_tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.22)
	p_tween.chain().tween_callback(func(): popup.visible = false)

## マッチした駒のスコアおよび属性ポイントを計算
func calcscore(match_index: Array, grid_att: Array, grid_element: Array = []) -> void:
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
				if att_type < 0 or att_type >= 5:
					visited[i][j] = true
					continue
				var component_cells: Array[Vector2i] = []
				
				# BFSで同じ属性の連結マッチ駒を収集
				_collect_connected_match_cells(i, j, att_type, match_index, grid_att, visited, component_cells)
				
				var count: int = component_cells.size()
				if count <= 0:
					continue
					
				var rm = null
				if get_tree() and get_tree().get_root():
					rm = get_tree().get_root().find_child("RelicManager", true, false)
				if rm:
					rm.on_match(count)
					if att_type == PieceType.POTION:
						rm.on_potions_cleared(count)

				var base_score: int = maxi(count * 100, count * (count - 2) * 100)
				
				# レベルに応じて+〇 (1レベルにつき +100 * 消去コマ数の固定加算ボーナス)
				var bonus_add: int = (stat_levels[att_type] * 100 * count) if att_type < stat_levels.size() else 0
				var mult: float = multipliers[att_type] if att_type < multipliers.size() else 1.0
				# コンボ倍率ボーナス (連鎖が続くほど指数的に大逆転ボーナス！中毒性UP)
				var combo_mult: float = 1.0 + maxf(0.0, float(combocount - 1)) * 0.25
				var earned_score: int = maxi(100 * count, int((int(base_score * mult) + bonus_add) * combo_mult))
				
				totalScore += earned_score
				
				for cell in component_cells:
					if grid_element.size() > cell.x and grid_element[cell.x].size() > cell.y:
						var el = grid_element[cell.x][cell.y]
						if el != 0:
							turn_element_counts[el] = turn_element_counts.get(el, 0) + 1
				update_elem_labels()

				_spawn_score_popup(component_cells, att_type, earned_score, count, is_fever)
				
				# フィーバータイム時は属性獲得量が倍率アップ（通常2倍 ＋ バフによるボーナス）
				var fv_rate: float = (2.0 + fever_boost_level * 0.5) if is_fever else 1.0
				var gain: int = int(earned_score * fv_rate)
				if att_type == PieceType.COIN and rm and rm.has_method("modify_coin_gain"):
					gain = int(rm.modify_coin_gain(float(gain)))
				if att_type < divscore.size():
					divscore[att_type] += gain
		
				if not turn_element_gain.has(att_type):
					turn_element_gain[att_type] = {}

				var total_pieces = component_cells.size()
				var element_piece_counts = {}
				var has_element = false

				for cell in component_cells:
					if grid_element.size() > cell.x and grid_element[cell.x].size() > cell.y:
						var el = grid_element[cell.x][cell.y]
						if el != 0:
							element_piece_counts[el] = element_piece_counts.get(el, 0) + 1
							has_element = true

				if has_element:
					for el in element_piece_counts:
						var ratio = float(element_piece_counts[el]) / float(total_pieces)
						var el_gain = int(gain * ratio)
						turn_element_gain[att_type][el] = turn_element_gain[att_type].get(el, 0) + el_gain
						if att_type == PieceType.SWORD:
							turn_sword_element_counts[el] = int(turn_sword_element_counts.get(el, 0)) + int(element_piece_counts[el])

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
			combo_label.position.y = 176.0 + bounce * 0.6
		if combocount_label != null:
			combocount_label.position.y = 236.0 + bounce * 0.6
	else:
		iscombo = false
		interval = 0
		if combo_label != null: combo_label.position.y = 176.0
		if combocount_label != null: combocount_label.position.y = 236.0
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
	var tp_b = tw.tween_property(burst_lbl, "modulate:a", 0.0, 0.35)
	if tp_b != null:
		tp_b.set_delay(0.4)
	tw.chain().tween_callback(burst_lbl.queue_free)

func _process(_delta: float) -> void:
	update_score_label()
	display_score_label()
	combo()
	_update_popup_labels()

## 獲得済みスキル一覧を返すヘルパー（画面下部UI等で利用）
func get_unlocked_skills() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for s in skill_tree_items:
		if int(s.get("level", 0)) > 0:
			res.append(s)
	return res

func get_skill_by_id(skill_id: String) -> Dictionary:
	for s in skill_tree_items:
		if s.get("id", "") == skill_id:
			return s
	return {}

## リッチな大型ショップ＆スキルツリーUIの生成 (1696 x 874)
func _setup_shop_page_controls() -> void:
	var parent = get_parent()
	if parent == null:
		return

	# 旧バフボタン群を常時非表示に固定
	for i in range(6):
		var old_btn = parent.get_node_or_null("buffselectbutton" + str(i))
		if old_btn:
			old_btn.visible = false

	var sc_btn = get_node_or_null("stagechangeb") as Button
	if sc_btn:
		sc_btn.position = Vector2(1724, 770)
		sc_btn.size = Vector2(188, 77)
		sc_btn.z_index = 35

	if shop_root_panel != null:
		return

	var jp_font = _get_jp_font()

	shop_root_panel = Panel.new()
	shop_root_panel.name = "ShopAndSkillTreePanel"
	shop_root_panel.position = Vector2(16, 10)
	shop_root_panel.size = Vector2(1696, 874)
	shop_root_panel.z_index = 30
	shop_root_panel.visible = false

	var root_style = StyleBoxFlat.new()
	root_style.bg_color = Color(0.06, 0.08, 0.14, 0.98)
	root_style.border_color = Color(0.88, 0.72, 0.28, 0.98)
	root_style.set_border_width_all(3)
	root_style.set_corner_radius_all(18)
	root_style.shadow_color = Color(0, 0, 0, 0.72)
	root_style.shadow_size = 18
	shop_root_panel.add_theme_stylebox_override("panel", root_style)
	parent.add_child.call_deferred(shop_root_panel)

	# --- 上部ヘッダーバー ---
	var header_bg = Panel.new()
	header_bg.position = Vector2(18, 12)
	header_bg.size = Vector2(1660, 80)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.10, 0.13, 0.22, 0.96)
	hdr_style.border_color = Color(0.35, 0.42, 0.62, 0.75)
	hdr_style.set_border_width_all(2)
	hdr_style.set_corner_radius_all(14)
	header_bg.add_theme_stylebox_override("panel", hdr_style)
	shop_root_panel.add_child(header_bg)

	shop_tab_btn = Button.new()
	shop_tab_btn.position = Vector2(32, 20)
	shop_tab_btn.size = Vector2(450, 64)
	shop_tab_btn.text = "🪙 ショップ (コイン購入)"
	shop_tab_btn.add_theme_font_override("font", jp_font)
	shop_tab_btn.add_theme_font_size_override("font_size", 26)
	shop_tab_btn.pressed.connect(func(): _switch_shop_view_mode(0))
	shop_root_panel.add_child(shop_tab_btn)

	skill_tab_btn = Button.new()
	skill_tab_btn.position = Vector2(498, 20)
	skill_tab_btn.size = Vector2(470, 64)
	skill_tab_btn.text = "🌿 スキルツリー (余剰ポーション)"
	skill_tab_btn.add_theme_font_override("font", jp_font)
	skill_tab_btn.add_theme_font_size_override("font_size", 26)
	skill_tab_btn.pressed.connect(func(): _switch_shop_view_mode(1))
	shop_root_panel.add_child(skill_tab_btn)

	# 所持コイン＆余剰ポーション表示ボックス
	var coin_box = Panel.new()
	coin_box.position = Vector2(990, 20)
	coin_box.size = Vector2(332, 64)
	var cbox_style = StyleBoxFlat.new()
	cbox_style.bg_color = Color(0.14, 0.12, 0.05, 0.96)
	cbox_style.border_color = Color(1.0, 0.84, 0.0, 0.9)
	cbox_style.set_border_width_all(2)
	cbox_style.set_corner_radius_all(12)
	coin_box.add_theme_stylebox_override("panel", cbox_style)
	shop_root_panel.add_child(coin_box)

	coin_currency_lbl = RichTextLabel.new()
	coin_currency_lbl.bbcode_enabled = true
	coin_currency_lbl.scroll_active = false
	coin_currency_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	coin_currency_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_currency_lbl.position = Vector2(8, 12)
	coin_currency_lbl.size = Vector2(316, 40)
	coin_currency_lbl.add_theme_font_override("normal_font", jp_font)
	coin_currency_lbl.add_theme_font_override("bold_font", jp_font)
	coin_currency_lbl.add_theme_font_size_override("normal_font_size", 20)
	coin_currency_lbl.add_theme_font_size_override("bold_font_size", 24)
	coin_box.add_child(coin_currency_lbl)

	var potion_box = Panel.new()
	potion_box.position = Vector2(1334, 20)
	potion_box.size = Vector2(332, 64)
	var pbox_style = StyleBoxFlat.new()
	pbox_style.bg_color = Color(0.16, 0.06, 0.14, 0.96)
	pbox_style.border_color = Color(1.0, 0.25, 0.65, 0.9)
	pbox_style.set_border_width_all(2)
	pbox_style.set_corner_radius_all(12)
	potion_box.add_theme_stylebox_override("panel", pbox_style)
	shop_root_panel.add_child(potion_box)

	potion_currency_lbl = RichTextLabel.new()
	potion_currency_lbl.bbcode_enabled = true
	potion_currency_lbl.scroll_active = false
	potion_currency_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	potion_currency_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_currency_lbl.position = Vector2(8, 12)
	potion_currency_lbl.size = Vector2(316, 40)
	potion_currency_lbl.add_theme_font_override("normal_font", jp_font)
	potion_currency_lbl.add_theme_font_override("bold_font", jp_font)
	potion_currency_lbl.add_theme_font_size_override("normal_font_size", 20)
	potion_currency_lbl.add_theme_font_size_override("bold_font_size", 24)
	potion_box.add_child(potion_currency_lbl)

	# --- 1. ショップビュー（コイン購入：獲得スコア・体力強化） ---
	shop_view_container = Control.new()
	shop_view_container.position = Vector2(18, 98)
	shop_view_container.size = Vector2(1660, 764)
	shop_root_panel.add_child(shop_view_container)

	var shop_banner = Label.new()
	shop_banner.position = Vector2(8, 0)
	shop_banner.size = Vector2(1644, 32)
	shop_banner.text = "✨ コインを消費して、各属性の獲得スコアや最大HP（体力上限）を永続強化します"
	shop_banner.add_theme_font_override("font", jp_font)
	shop_banner.add_theme_font_size_override("font_size", 21)
	shop_banner.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	shop_view_container.add_child(shop_banner)

	shop_card_refs.clear()
	var card_w: float = 538.0
	var card_h: float = 350.0
	var gap_x: float = 23.0
	var gap_y: float = 20.0

	for i in range(shop_items.size()):
		var item = shop_items[i]
		var col_idx: int = i % 3
		var row_idx: int = int(i / 3)
		var card = Panel.new()
		card.position = Vector2(col_idx * (card_w + gap_x), 36.0 + row_idx * (card_h + gap_y))
		card.size = Vector2(card_w, card_h)

		var c_style = StyleBoxFlat.new()
		c_style.bg_color = Color(0.11, 0.14, 0.22, 0.98)
		c_style.border_color = item["color"].darkened(0.12)
		c_style.set_border_width_all(2)
		c_style.border_width_top = 7
		c_style.set_corner_radius_all(16)
		c_style.shadow_color = Color(0, 0, 0, 0.45)
		c_style.shadow_size = 8
		card.add_theme_stylebox_override("panel", c_style)
		shop_view_container.add_child(card)

		# アイコン背景枠
		var icon_frame = Panel.new()
		icon_frame.position = Vector2(22, 20)
		icon_frame.size = Vector2(86, 86)
		var if_style = StyleBoxFlat.new()
		if_style.bg_color = item["color"].darkened(0.72)
		if_style.border_color = item["color"]
		if_style.set_border_width_all(2)
		if_style.set_corner_radius_all(14)
		icon_frame.add_theme_stylebox_override("panel", if_style)
		card.add_child(icon_frame)

		var tex_rect = TextureRect.new()
		tex_rect.position = Vector2(9, 9)
		tex_rect.size = Vector2(68, 68)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(item.get("icon_path", "")):
			tex_rect.texture = load(item["icon_path"])
		icon_frame.add_child(tex_rect)

		var sub_lbl = Label.new()
		sub_lbl.position = Vector2(124, 20)
		sub_lbl.size = Vector2(240, 26)
		sub_lbl.text = item.get("subtitle", "ステータス強化")
		sub_lbl.add_theme_font_override("font", jp_font)
		sub_lbl.add_theme_font_size_override("font_size", 17)
		sub_lbl.add_theme_color_override("font_color", Color(0.74, 0.80, 0.92))
		card.add_child(sub_lbl)

		var lvl_badge = Label.new()
		lvl_badge.position = Vector2(390, 18)
		lvl_badge.size = Vector2(126, 32)
		lvl_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lvl_badge.add_theme_font_override("font", jp_font)
		lvl_badge.add_theme_font_size_override("font_size", 24)
		lvl_badge.add_theme_color_override("font_color", Color("#FFD700"))
		lvl_badge.add_theme_constant_override("outline_size", 5)
		lvl_badge.add_theme_color_override("font_outline_color", Color.BLACK)
		card.add_child(lvl_badge)

		var title_lbl = Label.new()
		title_lbl.position = Vector2(124, 48)
		title_lbl.size = Vector2(392, 48)
		title_lbl.text = item["name"]
		title_lbl.add_theme_font_override("font", jp_font)
		title_lbl.add_theme_font_size_override("font_size", 30)
		title_lbl.add_theme_color_override("font_color", item["color"].lightened(0.25))
		title_lbl.add_theme_constant_override("outline_size", 6)
		title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		card.add_child(title_lbl)

		var desc_lbl = Label.new()
		desc_lbl.position = Vector2(22, 114)
		desc_lbl.size = Vector2(494, 52)
		desc_lbl.text = item["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_override("font", jp_font)
		desc_lbl.add_theme_font_size_override("font_size", 18)
		desc_lbl.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
		card.add_child(desc_lbl)

		var stat_box = Panel.new()
		stat_box.position = Vector2(22, 170)
		stat_box.size = Vector2(494, 88)
		var sb_style = StyleBoxFlat.new()
		sb_style.bg_color = Color(0.06, 0.08, 0.13, 0.94)
		sb_style.border_color = Color(0.28, 0.36, 0.52, 0.85)
		sb_style.set_border_width_all(1)
		sb_style.set_corner_radius_all(10)
		stat_box.add_theme_stylebox_override("panel", sb_style)
		card.add_child(stat_box)

		var stat_lbl = RichTextLabel.new()
		stat_lbl.bbcode_enabled = true
		stat_lbl.scroll_active = false
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_lbl.position = Vector2(14, 10)
		stat_lbl.size = Vector2(466, 70)
		stat_lbl.add_theme_font_override("normal_font", jp_font)
		stat_lbl.add_theme_font_override("bold_font", jp_font)
		stat_lbl.add_theme_font_size_override("normal_font_size", 20)
		stat_lbl.add_theme_font_size_override("bold_font_size", 21)
		stat_box.add_child(stat_lbl)

		var buy_btn = Button.new()
		buy_btn.position = Vector2(22, 268)
		buy_btn.size = Vector2(494, 66)
		buy_btn.add_theme_font_override("font", jp_font)
		buy_btn.add_theme_font_size_override("font_size", 24)
		buy_btn.add_theme_constant_override("outline_size", 5)
		buy_btn.add_theme_color_override("font_outline_color", Color.BLACK)
		var slot_idx = i
		buy_btn.pressed.connect(func(): _purchase_buff(slot_idx))
		card.add_child(buy_btn)

		shop_card_refs.append({
			"card": card,
			"lvl_badge": lvl_badge,
			"stat_lbl": stat_lbl,
			"buy_btn": buy_btn
		})

	# --- 2. スキルツリービュー（余剰ポーション使用：スキル獲得・強化） ---
	skill_tree_container = Control.new()
	skill_tree_container.position = Vector2(18, 98)
	skill_tree_container.size = Vector2(1660, 764)
	skill_tree_container.visible = false
	shop_root_panel.add_child(skill_tree_container)

	rebuild_skill_tree_ui()
	_switch_shop_view_mode(0)

func _get_relic_manager() -> Node:
	if not is_inside_tree() or get_tree() == null:
		var p = get_parent()
		if p: return p.get_node_or_null("RelicManager")
		return null
	var root = get_tree().get_root()
	if root == null: return null
	return root.find_child("RelicManager", true, false)

var _rendered_skill_category: String = "__unset__"

func on_element_category_chosen(_cat_key: String) -> void:
	rebuild_skill_tree_ui()

## 選択された属性カテゴリーに応じてスキルツリーUIを動的に構築
func rebuild_skill_tree_ui() -> void:
	if skill_tree_container == null or not is_instance_valid(skill_tree_container):
		return

	var jp_font = _get_jp_font()
	var rm = _get_relic_manager()
	var cat_key: String = rm.get_chosen_element_category() if (rm and rm.has_method("get_chosen_element_category")) else ""

	_rendered_skill_category = cat_key

	for ch in skill_tree_container.get_children():
		ch.queue_free()
	skill_node_refs.clear()

	# カテゴリー未選択時（最初の敵を倒す前）
	if cat_key == "" or not CATEGORY_TREE_DEFS.has(cat_key):
		var banner = Label.new()
		banner.position = Vector2(8, 20)
		banner.size = Vector2(1644, 40)
		banner.text = "⚔️ 最初の敵を撃破すると【3つの属性カテゴリー】から1つ選択できます。選択した系統のスキルツリーが解放・表示されます。"
		banner.add_theme_font_override("font", jp_font)
		banner.add_theme_font_size_override("font_size", 22)
		banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_tree_container.add_child(banner)

		# 3つのカテゴリーの概要カードを表示
		var preview_cats = ["nature", "force", "mystic"]
		var c_w = 480.0
		var c_gap = 40.0
		var start_x = (1660.0 - (3.0 * c_w + 2.0 * c_gap)) / 2.0
		for i in range(3):
			var c_k = preview_cats[i]
			var c_info = CATEGORY_TREE_DEFS[c_k]
			var card = Panel.new()
			card.position = Vector2(start_x + i * (c_w + c_gap), 90.0)
			card.size = Vector2(c_w, 580.0)
			var c_style = StyleBoxFlat.new()
			c_style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
			c_style.border_color = c_info["branch_colors"][0]
			c_style.set_border_width_all(3)
			c_style.set_corner_radius_all(16)
			card.add_theme_stylebox_override("panel", c_style)
			skill_tree_container.add_child(card)

			var c_lbl = Label.new()
			c_lbl.position = Vector2(16, 24)
			c_lbl.size = Vector2(c_w - 32, 40)
			c_lbl.text = c_info["title"]
			c_lbl.add_theme_font_override("font", jp_font)
			c_lbl.add_theme_font_size_override("font_size", 24)
			c_lbl.add_theme_color_override("font_color", c_info["branch_colors"][0].lightened(0.3))
			c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(c_lbl)

			var c_desc = RichTextLabel.new()
			c_desc.position = Vector2(24, 80)
			c_desc.size = Vector2(c_w - 48, 460)
			c_desc.bbcode_enabled = true
			var desc_text = "[font_size=19][color=#CCCCCC]系統特徴:[/color]\n" + c_info["banner"] + "\n\n[color=#FFD54F]含まれるスキル系列:[/color]\n"
			for b_t in c_info["branch_titles"]:
				desc_text += "・" + b_t + "\n"
			desc_text += "\n[color=#888888]※最初の戦闘勝利時に選択可能[/color][/font_size]"
			c_desc.text = desc_text
			c_desc.add_theme_font_override("normal_font", jp_font)
			card.add_child(c_desc)
		return

	# カテゴリー選択済みの場合：選択されたカテゴリーのツリーを表示！
	var cat_data = CATEGORY_TREE_DEFS[cat_key]
	var banner = Label.new()
	banner.position = Vector2(8, 0)
	banner.size = Vector2(1644, 32)
	banner.text = cat_data["banner"]
	banner.add_theme_font_override("font", jp_font)
	banner.add_theme_font_size_override("font_size", 21)
	banner.add_theme_color_override("font_color", Color(0.95, 0.65, 1.0))
	skill_tree_container.add_child(banner)

	var branch_titles: Array = cat_data["branch_titles"]
	var branch_colors: Array = cat_data["branch_colors"]

	var col_w: float = 520.0
	var col_gap: float = 36.0
	var offset_x: float = (1660.0 - (3.0 * col_w + 2.0 * col_gap)) / 2.0

	for b in range(3):
		var bx: float = offset_x + b * (col_w + col_gap)
		var bhdr = Panel.new()
		bhdr.position = Vector2(bx, 34)
		bhdr.size = Vector2(col_w, 42)
		var bh_style = StyleBoxFlat.new()
		bh_style.bg_color = branch_colors[b].darkened(0.68)
		bh_style.border_color = branch_colors[b]
		bh_style.set_border_width_all(2)
		bh_style.set_corner_radius_all(10)
		bhdr.add_theme_stylebox_override("panel", bh_style)
		skill_tree_container.add_child(bhdr)

		var b_lbl = Label.new()
		b_lbl.size = Vector2(col_w, 42)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b_lbl.text = branch_titles[b]
		b_lbl.add_theme_font_override("font", jp_font)
		b_lbl.add_theme_font_size_override("font_size", 22)
		b_lbl.add_theme_color_override("font_color", branch_colors[b].lightened(0.35))
		b_lbl.add_theme_constant_override("outline_size", 5)
		b_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		bhdr.add_child(b_lbl)

		# ツリー接続矢印 (Tier 0->1, Tier 1->2)
		for t in range(2):
			var arrow_lbl = Label.new()
			arrow_lbl.position = Vector2(bx, 286 + t * 232)
			arrow_lbl.size = Vector2(col_w, 24)
			arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arrow_lbl.text = "▼"
			arrow_lbl.add_theme_font_override("font", jp_font)
			arrow_lbl.add_theme_font_size_override("font_size", 20)
			arrow_lbl.add_theme_color_override("font_color", branch_colors[b].lightened(0.25))
			skill_tree_container.add_child(arrow_lbl)

	for s_idx in range(skill_tree_items.size()):
		var s_item = skill_tree_items[s_idx]
		if s_item.get("category", "") != cat_key:
			continue

		var branch: int = int(s_item["branch"])
		var tier: int = int(s_item["tier"])
		var nx: float = offset_x + branch * (col_w + col_gap)
		var ny: float = 82.0 + tier * 232.0

		var node_card = Panel.new()
		node_card.position = Vector2(nx, ny)
		node_card.size = Vector2(col_w, 204)
		skill_tree_container.add_child(node_card)

		# スキル象徴アイコン枠
		var badge = Panel.new()
		badge.position = Vector2(14, 14)
		badge.size = Vector2(54, 54)
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = s_item["color"].darkened(0.55)
		b_style.border_color = s_item["color"]
		b_style.set_border_width_all(2)
		b_style.set_corner_radius_all(12)
		badge.add_theme_stylebox_override("panel", b_style)
		node_card.add_child(badge)

		var badge_lbl = Label.new()
		badge_lbl.size = Vector2(54, 54)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_lbl.text = s_item.get("short_label", "技")
		badge_lbl.add_theme_font_override("font", jp_font)
		badge_lbl.add_theme_font_size_override("font_size", 28)
		badge_lbl.add_theme_color_override("font_color", Color.WHITE)
		badge_lbl.add_theme_constant_override("outline_size", 5)
		badge_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_child(badge_lbl)

		var s_title = Label.new()
		s_title.position = Vector2(78, 12)
		s_title.size = Vector2(col_w - 90, 30)
		s_title.text = s_item["name"]
		s_title.add_theme_font_override("font", jp_font)
		s_title.add_theme_font_size_override("font_size", 22)
		s_title.add_theme_color_override("font_color", s_item["color"].lightened(0.25))
		s_title.add_theme_constant_override("outline_size", 5)
		s_title.add_theme_color_override("font_outline_color", Color.BLACK)
		node_card.add_child(s_title)

		var s_lvl = Label.new()
		s_lvl.position = Vector2(78, 42)
		s_lvl.size = Vector2(col_w - 90, 26)
		s_lvl.add_theme_font_override("font", jp_font)
		s_lvl.add_theme_font_size_override("font_size", 17)
		s_lvl.add_theme_constant_override("outline_size", 4)
		s_lvl.add_theme_color_override("font_outline_color", Color.BLACK)
		node_card.add_child(s_lvl)

		var s_desc = RichTextLabel.new()
		s_desc.bbcode_enabled = true
		s_desc.scroll_active = false
		s_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_desc.position = Vector2(14, 72)
		s_desc.size = Vector2(col_w - 28, 72)
		s_desc.add_theme_font_override("normal_font", jp_font)
		s_desc.add_theme_font_override("bold_font", jp_font)
		s_desc.add_theme_font_size_override("normal_font_size", 16)
		s_desc.add_theme_font_size_override("bold_font_size", 16)
		node_card.add_child(s_desc)

		var s_btn = Button.new()
		s_btn.position = Vector2(14, 146)
		s_btn.size = Vector2(col_w - 28, 46)
		s_btn.add_theme_font_override("font", jp_font)
		s_btn.add_theme_font_size_override("font_size", 19)
		s_btn.add_theme_constant_override("outline_size", 4)
		s_btn.add_theme_color_override("font_outline_color", Color.BLACK)
		var bind_idx = s_idx
		s_btn.pressed.connect(func(): _purchase_skill(bind_idx))
		node_card.add_child(s_btn)

		var card_skill_id = s_item["id"]
		node_card.mouse_filter = Control.MOUSE_FILTER_PASS
		node_card.mouse_entered.connect(func():
			var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
			if r_ui and r_ui.has_method("show_custom_tooltip"):
				var c_lvl = int(s_item.get("level", 0))
				var m_lvl = int(s_item.get("max_level", 3))
				var col_hex = s_item.get("color", Color.WHITE).to_html(false)
				var t_str = "[b][color=#%s]🌿 %s (Lv%d/%d)[/color][/b]" % [col_hex, s_item.get("name", "Skill"), c_lvl, m_lvl]
				var d_arr: Array = s_item.get("desc_lv", [])
				var cur_d = d_arr[clampi(c_lvl - 1, 0, d_arr.size() - 1)] if c_lvl > 0 and not d_arr.is_empty() else (d_arr[0] if not d_arr.is_empty() else "")
				var next_d = d_arr[clampi(c_lvl, 0, d_arr.size() - 1)] if c_lvl < m_lvl and not d_arr.is_empty() else ""
				var d_str = ""
				if c_lvl >= m_lvl:
					d_str = "[font_size=19][color=#FFD700]【最大レベル】[/color]\n%s[/font_size]" % cur_d
				elif c_lvl == 0:
					d_str = "[font_size=19][color=#AAAAAA]【未習得】[/color]\n習得効果 (Lv1): %s[/font_size]" % next_d
				else:
					d_str = "[font_size=19]現在 (Lv%d): %s\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [c_lvl, cur_d, c_lvl + 1, next_d]
				r_ui.show_custom_tooltip(t_str, d_str, node_card.get_global_mouse_position(), "shop_skill:" + card_skill_id)
		)
		node_card.mouse_exited.connect(func():
			var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
			if r_ui and r_ui.has_method("hide_custom_tooltip"):
				r_ui.hide_custom_tooltip("shop_skill:" + card_skill_id)
		)

		skill_node_refs.append({
			"s_idx": s_idx,
			"card": node_card,
			"s_lvl": s_lvl,
			"s_desc": s_desc,
			"s_btn": s_btn
		})

	_update_buff_button_labels()

func _switch_shop_view_mode(mode: int) -> void:
	current_view_mode = mode
	if shop_view_container:
		shop_view_container.visible = (mode == 0)
	if skill_tree_container:
		skill_tree_container.visible = (mode == 1)
		if mode == 1:
			var rm = _get_relic_manager()
			var cur_cat: String = rm.get_chosen_element_category() if (rm and rm.has_method("get_chosen_element_category")) else ""
			if cur_cat != _rendered_skill_category:
				rebuild_skill_tree_ui()

	var click_se = get_parent().get_node_or_null("click") if get_parent() else null
	if click_se and is_shop_open:
		click_se.play()
	_update_buff_button_labels()

func _on_prev_page_pressed() -> void:
	_switch_shop_view_mode(0)

func _on_next_page_pressed() -> void:
	_switch_shop_view_mode(1)

func set_shop_ui_visible(is_vis: bool) -> void:
	is_shop_open = is_vis
	if shop_root_panel == null:
		_setup_shop_page_controls()
	if shop_root_panel:
		shop_root_panel.visible = is_vis
	var parent = get_parent()
	if parent:
		for i in range(6):
			var btn = parent.get_node_or_null("buffselectbutton" + str(i))
			if btn:
				btn.visible = false
	_update_buff_button_labels()

## ショップ＆スキルツリーUIの表示内容を最新状態に更新
func _update_buff_button_labels() -> void:
	var parent = get_parent()
	if parent:
		for i in range(6):
			var btn = parent.get_node_or_null("buffselectbutton" + str(i))
			if btn:
				btn.visible = false

	if not is_shop_open or shop_root_panel == null:
		return

	var coins: int = int(divscore[PieceType.COIN]) if divscore.size() > PieceType.COIN else 0
	var potions: int = int(divscore[PieceType.POTION]) if divscore.size() > PieceType.POTION else 0

	if coin_currency_lbl:
		coin_currency_lbl.text = "[center][img=30]res://Texture/coin/coin_cut.png[/img] [color=#CCCCCC][font_size=18]所持コイン:[/font_size][/color] [b][color=#FFD700][font_size=24]%s[/font_size][/color][/b][/center]" % _format_comma(coins)
	if potion_currency_lbl:
		potion_currency_lbl.text = "[center][img=30]res://Texture/potion/potion_cut.png[/img] [color=#CCCCCC][font_size=18]余剰ポーション:[/font_size][/color] [b][color=#FF66B3][font_size=24]%s[/font_size][/color][/b][/center]" % _format_comma(potions)

	# タブボタンのスタイル更新
	if shop_tab_btn and skill_tab_btn:
		var active_shop = (current_view_mode == 0)
		var st_shop = StyleBoxFlat.new()
		st_shop.bg_color = Color(0.24, 0.20, 0.06, 1.0) if active_shop else Color(0.10, 0.12, 0.18, 0.85)
		st_shop.border_color = Color(1.0, 0.84, 0.0, 1.0) if active_shop else Color(0.3, 0.35, 0.45, 0.6)
		st_shop.set_border_width_all(3 if active_shop else 1)
		st_shop.set_corner_radius_all(10)
		shop_tab_btn.add_theme_stylebox_override("normal", st_shop)
		shop_tab_btn.add_theme_stylebox_override("hover", st_shop)
		shop_tab_btn.add_theme_color_override("font_color", Color("#FFD700") if active_shop else Color(0.7, 0.75, 0.85))

		var st_skill = StyleBoxFlat.new()
		st_skill.bg_color = Color(0.24, 0.08, 0.22, 1.0) if not active_shop else Color(0.10, 0.12, 0.18, 0.85)
		st_skill.border_color = Color(1.0, 0.35, 0.75, 1.0) if not active_shop else Color(0.3, 0.35, 0.45, 0.6)
		st_skill.set_border_width_all(3 if not active_shop else 1)
		st_skill.set_corner_radius_all(10)
		skill_tab_btn.add_theme_stylebox_override("normal", st_skill)
		skill_tab_btn.add_theme_stylebox_override("hover", st_skill)
		skill_tab_btn.add_theme_color_override("font_color", Color("#FF80CC") if not active_shop else Color(0.7, 0.75, 0.85))

	# 1. ショップカードの更新
	var sm = _get_stage_manager()
	var stage_num: int = sm.stage if sm and "stage" in sm else 1
	var hp_step: int = int(2500.0 * pow(10.0, maxf(0.0, float(stage_num - 1))))

	for i in range(mini(shop_items.size(), shop_card_refs.size())):
		var item = shop_items[i]
		var ref = shop_card_refs[i]
		var cur_lvl: int = int(item["level"])
		var cost_val: int = int(item["cost"])
		var can_buy: bool = (coins >= cost_val)

		ref["lvl_badge"].text = "Lv.%d" % cur_lvl

		var stat_text = ""
		match item["id"]:
			"shield", "sword", "food", "coin":
				var cur_bonus = cur_lvl * 100
				var next_bonus = (cur_lvl + 1) * 100
				stat_text = "[color=#B0BEC5]現在ボーナス:[/color] [b][color=#FFFFFF]+%s / 1コマ[/color][/b]\n[color=#FFD700]強化後 (Lv.%d):[/color] [b][color=#00E676]+%s / 1コマ[/color][/b]" % [
					_format_comma(cur_bonus), cur_lvl + 1, _format_comma(next_bonus)
				]
			"fever":
				var cur_m: float = 2.0 + cur_lvl * 0.5
				var next_m: float = 2.0 + (cur_lvl + 1) * 0.5
				stat_text = "[color=#B0BEC5]現在倍率:[/color] [b][color=#FFFFFF]%.1f倍[/color][/b]\n[color=#FFD700]強化後 (Lv.%d):[/color] [b][color=#00E676]%.1f倍[/color][/b]" % [
					cur_m, cur_lvl + 1, next_m
				]
			"max_hp":
				var cur_max_hp: int = int(sm.myhpmax) if sm and "myhpmax" in sm else 5000
				stat_text = "[color=#B0BEC5]現在最大HP:[/color] [b][color=#FFFFFF]%s[/color][/b]\n[color=#FFD700]強化効果:[/color] [b][color=#00E676]最大HP +%s ＆ 即回復[/color][/b]" % [
					_format_comma(cur_max_hp), _format_comma(hp_step)
				]
		ref["stat_lbl"].text = stat_text

		var btn: Button = ref["buy_btn"]
		btn.disabled = not can_buy
		btn.text = "🪙 %s コインで強化" % _format_comma(cost_val)

		var btn_style = StyleBoxFlat.new()
		if can_buy:
			btn_style.bg_color = Color(0.16, 0.36, 0.20, 0.98)
			btn_style.border_color = Color(1.0, 0.84, 0.2, 1.0)
			btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.75))
		else:
			btn_style.bg_color = Color(0.15, 0.16, 0.20, 0.85)
			btn_style.border_color = Color(0.35, 0.38, 0.45, 0.6)
			btn.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_style = btn_style.duplicate()
		if can_buy:
			hover_style.bg_color = Color(0.22, 0.48, 0.28, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("disabled", btn_style)

	# 2. スキルツリーノードの更新
	for s_ref in skill_node_refs:
		var s_idx = int(s_ref.get("s_idx", -1))
		if s_idx < 0 or s_idx >= skill_tree_items.size():
			continue
		var s_item = skill_tree_items[s_idx]
		var cur_lvl: int = int(s_item["level"])
		var max_lvl: int = int(s_item.get("max_level", 3))
		var is_max: bool = (cur_lvl >= max_lvl)
		var cost_val: int = int(s_item["cost"])

		var req_id: String = s_item.get("req_id", "")
		var req_met: bool = true
		var req_name: String = ""
		if req_id != "":
			var req_skill = get_skill_by_id(req_id)
			req_met = (int(req_skill.get("level", 0)) > 0)
			req_name = req_skill.get("name", "")

		var card_style = StyleBoxFlat.new()
		if cur_lvl > 0:
			card_style.bg_color = Color(0.13, 0.16, 0.26, 0.98)
			card_style.border_color = s_item["color"] if not is_max else Color("#FFD700")
			card_style.set_border_width_all(2)
			card_style.border_width_left = 6
		elif req_met:
			card_style.bg_color = Color(0.10, 0.12, 0.19, 0.95)
			card_style.border_color = s_item["color"].darkened(0.35)
			card_style.set_border_width_all(2)
		else:
			card_style.bg_color = Color(0.07, 0.08, 0.12, 0.88)
			card_style.border_color = Color(0.28, 0.30, 0.38, 0.6)
			card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(12)
		s_ref["card"].add_theme_stylebox_override("panel", card_style)

		if is_max:
			s_ref["s_lvl"].text = "★ Lv.%d / %d (MAX)" % [cur_lvl, max_lvl]
			s_ref["s_lvl"].add_theme_color_override("font_color", Color("#FFD700"))
		elif cur_lvl > 0:
			s_ref["s_lvl"].text = "習得済: Lv.%d / %d" % [cur_lvl, max_lvl]
			s_ref["s_lvl"].add_theme_color_override("font_color", Color("#00E676"))
		elif req_met:
			s_ref["s_lvl"].text = "未習得 (解放可能)"
			s_ref["s_lvl"].add_theme_color_override("font_color", Color("#80D8FF"))
		else:
			s_ref["s_lvl"].text = "🔒 未解禁 (要:%s)" % req_name
			s_ref["s_lvl"].add_theme_color_override("font_color", Color("#9E9E9E"))

		var desc_arr: Array = s_item["desc_lv"]
		if is_max:
			s_ref["s_desc"].text = "[color=#FFD700][b]【最大強化】[/b][/color]\n[color=#FFFFFF]%s[/color]" % desc_arr[clampi(max_lvl - 1, 0, desc_arr.size() - 1)]
		elif cur_lvl == 0:
			s_ref["s_desc"].text = "[color=#B0BEC5]解放効果 (Lv.1):[/color]\n[color=#FFFFFF]%s[/color]" % desc_arr[0]
		else:
			var cur_txt = desc_arr[clampi(cur_lvl - 1, 0, desc_arr.size() - 1)]
			var next_txt = desc_arr[clampi(cur_lvl, 0, desc_arr.size() - 1)]
			s_ref["s_desc"].text = "[color=#B0BEC5]現在: %s[/color]\n[color=#FFD700]次(Lv.%d): %s[/color]" % [
				cur_txt, cur_lvl + 1, next_txt
			]

		var s_btn: Button = s_ref["s_btn"]
		var can_upgrade: bool = (not is_max) and req_met and (potions >= cost_val)
		s_btn.disabled = not can_upgrade

		var sb_style = StyleBoxFlat.new()
		sb_style.set_corner_radius_all(8)
		sb_style.set_border_width_all(2)

		if is_max:
			s_btn.text = "★ MAX (Lv.%d) ★" % max_lvl
			sb_style.bg_color = Color(0.28, 0.22, 0.06, 0.95)
			sb_style.border_color = Color("#FFD700")
			s_btn.add_theme_color_override("font_color", Color("#FFD700"))
		elif not req_met:
			s_btn.text = "🔒 前提スキル未習得"
			sb_style.bg_color = Color(0.12, 0.12, 0.16, 0.85)
			sb_style.border_color = Color(0.3, 0.3, 0.38, 0.6)
			s_btn.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))
		else:
			var act_word = "スキル解放" if cur_lvl == 0 else ("Lv.%dへ強化" % (cur_lvl + 1))
			s_btn.text = "🧪 %s で%s" % [_format_comma(cost_val), act_word]
			if can_upgrade:
				sb_style.bg_color = Color(0.32, 0.10, 0.28, 0.98)
				sb_style.border_color = Color(1.0, 0.4, 0.8, 1.0)
				s_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.98))
			else:
				sb_style.bg_color = Color(0.15, 0.14, 0.18, 0.85)
				sb_style.border_color = Color(0.38, 0.32, 0.42, 0.6)
				s_btn.add_theme_color_override("font_color", Color(0.58, 0.55, 0.62))

		s_btn.add_theme_stylebox_override("normal", sb_style)
		var sb_hover = sb_style.duplicate()
		if can_upgrade:
			sb_hover.bg_color = Color(0.45, 0.14, 0.38, 1.0)
		s_btn.add_theme_stylebox_override("hover", sb_hover)
		s_btn.add_theme_stylebox_override("disabled", sb_style)

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

## ショップ購入処理（コイン使用：獲得スコア強化・体力強化）
func _purchase_buff(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= shop_items.size():
		return

	var item = shop_items[slot_idx]
	var cost_ref: int = int(item["cost"])
	var coin_amount: int = int(divscore[PieceType.COIN])
	var parent = get_parent()
	var pb = _get_puzzle_board()

	if coin_amount >= cost_ref:
		divscore[PieceType.COIN] -= cost_ref
		item["cost"] = int(cost_ref * 1.35)
		item["level"] += 1

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
				if pb:
					pb.fever_bonus_multiplier = fever_boost_level * 0.5
				update_fever_label3()
			"stat_hp":
				currenthpcoin = item["cost"]
				hp_boost_level += 1
				var sm = _get_stage_manager()
				if sm:
					var stage_scale: float = pow(10.0, maxf(0.0, float(sm.stage - 1)))
					var hp_gain: float = 2500.0 * stage_scale
					sm.myhpmax += hp_gain
					sm.myhp = minf(sm.myhpmax, sm.myhp + hp_gain)

		var sound = parent.get_node_or_null("coinsound") if parent else null
		if sound:
			sound.play()
		_update_buff_button_labels()
	else:
		var cancel_sound = parent.get_node_or_null("cancel") if parent else null
		if cancel_sound:
			cancel_sound.play()

## スキルツリーの解放・強化処理（余剰ポーション使用）
func _purchase_skill(skill_idx: int) -> void:
	if skill_idx < 0 or skill_idx >= skill_tree_items.size():
		return

	var s_item = skill_tree_items[skill_idx]
	var cur_lvl: int = int(s_item["level"])
	var max_lvl: int = int(s_item.get("max_level", 3))
	var parent = get_parent()
	if cur_lvl >= max_lvl:
		var cancel_s = parent.get_node_or_null("cancel") if parent else null
		if cancel_s: cancel_s.play()
		return

	var req_id: String = s_item.get("req_id", "")
	if req_id != "":
		var req_skill = get_skill_by_id(req_id)
		if int(req_skill.get("level", 0)) <= 0:
			var cancel_s = parent.get_node_or_null("cancel") if parent else null
			if cancel_s: cancel_s.play()
			return

	var cost_ref: int = int(s_item["cost"])
	var potion_amount: int = int(divscore[PieceType.POTION])

	if potion_amount >= cost_ref:
		divscore[PieceType.POTION] -= cost_ref
		var new_lvl: int = cur_lvl + 1
		s_item["level"] = new_lvl
		s_item["cost"] = int(cost_ref * 1.30)

		var sp_type: int = int(s_item["sp_type"])
		var pb = _get_puzzle_board()
		if pb and "special_levels" in pb:
			pb.special_levels[sp_type] = new_lvl
			if sp_type == 9 and pb.has_method("_plant_sprout_on_board"):
				pb._plant_sprout_on_board()

		if s_item["id"] == "bomb":
			bomb_buff_level = new_lvl

		emit_signal("skill_upgraded", s_item["id"], sp_type, new_lvl)

		var sound = parent.get_node_or_null("coinsound") if parent else null
		if sound:
			sound.play()
		_update_buff_button_labels()
	else:
		var cancel_sound = parent.get_node_or_null("cancel") if parent else null
		if cancel_sound:
			cancel_sound.play()

func update_fever_label3() -> void:
	var fv_lbl3 = get_node_or_null("feverlabel3") as RichTextLabel
	if fv_lbl3:
		var mult: float = 2.0 + fever_boost_level * 0.5
		if fposmod(mult, 1.0) == 0.0:
			fv_lbl3.text = "[center][b][color=#FFD700]スコア%d倍[/color][/b][/center]" % int(mult)
		else:
			fv_lbl3.text = "[center][b][color=#FFD700]スコア%.1f倍[/color][/b][/center]" % mult

# シーン側から接続されるボタンイベントハンドラ（後方互換維持）
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


func update_elem_labels() -> void:
	if elem_labels.size() == 0: return
	for k in range(1, 7):
		var count = turn_element_counts.get(k, 0)
		var val_str = _format_comma(count)
		var c = ELEM_COLORS[k - 1]
		elem_labels[k - 1].text = "[b][color=#%s]%s[/color][/b]" % [c, val_str]

	# 欄の横幅は固定（ユーザー要望に完全準拠: 340.0px / 内枠 336.0px）
	if elem_status_rect != null:
		elem_status_rect.size = Vector2(340.0, 275.0)
	if elem_status2_rect != null:
		elem_status2_rect.size = Vector2(336.0, 271.0)

func reset_turn_elements() -> void:
	turn_element_counts.clear()
	turn_element_gain.clear()
	turn_sword_element_counts.clear()
	update_elem_labels()

func get_turn_sword_element_counts() -> Dictionary:
	return turn_sword_element_counts.duplicate()

func add_turn_element(el: int, amount: int) -> void:
	turn_element_counts[el] = turn_element_counts.get(el, 0) + amount
	update_elem_labels()

## シンボル同士・シンボルと値を区切るグリッド線のセットアップ
func _setup_grid_lines() -> void:
	var line_color = Color(0.960784, 1.0, 0.0901961, 0.75)
	
	# --- 1. 各値の欄 (敵画面左端 x: 1192..1528, y: 474..745, 5行) ---
	# 垂直区切り線（シンボルと値の境界: x = 1250.0）
	var st_vline = get_node_or_null("status_v_line") as ColorRect
	if st_vline == null:
		st_vline = ColorRect.new()
		st_vline.name = "status_v_line"
		st_vline.z_index = -5
		st_vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(st_vline)
	st_vline.position = Vector2(1250.0, 474.0)
	st_vline.size = Vector2(2.0, 271.0)
	st_vline.color = line_color
	
	# 水平区切り線（シンボル同士の境界: 4本）
	var st_h_ys = [528.0, 582.0, 636.0, 690.0]
	for idx in range(st_h_ys.size()):
		var line_name = "status_h_line_" + str(idx)
		var st_hline = get_node_or_null(line_name) as ColorRect
		if st_hline == null:
			st_hline = ColorRect.new()
			st_hline.name = line_name
			st_hline.z_index = -5
			st_hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(st_hline)
		st_hline.position = Vector2(1192.0, st_h_ys[idx])
		st_hline.size = Vector2(336.0, 2.0)
		st_hline.color = line_color

	# --- 2. 属性の値の欄 (敵画面中央 x: 1555..1891, y: 474..745, 6行) ---
	# 垂直区切り線（シンボルと値の境界: x = 1613.0）
	var el_vline = get_node_or_null("elem_v_line") as ColorRect
	if el_vline == null:
		el_vline = ColorRect.new()
		el_vline.name = "elem_v_line"
		el_vline.z_index = -5
		el_vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(el_vline)
	el_vline.position = Vector2(1613.0, 474.0)
	el_vline.size = Vector2(2.0, 271.0)
	el_vline.color = line_color
	
	# 水平区切り線（シンボル同士の境界: 5本）
	var el_h_ys = [519.0, 564.0, 609.0, 654.0, 700.0]
	for idx in range(el_h_ys.size()):
		var line_name = "elem_h_line_" + str(idx)
		var el_hline = get_node_or_null(line_name) as ColorRect
		if el_hline == null:
			el_hline = ColorRect.new()
			el_hline.name = line_name
			el_hline.z_index = -5
			el_hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(el_hline)
		el_hline.position = Vector2(1555.0, el_h_ys[idx])
		el_hline.size = Vector2(336.0, 2.0)
		el_hline.color = line_color
