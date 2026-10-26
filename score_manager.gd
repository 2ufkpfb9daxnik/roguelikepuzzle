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
		"branch_titles": ["💧 水・清流系", "❄️ 氷・凍結系", "🌱 木・自然系", "🌪️ 風・翠嵐系"],
		"branch_colors": [Color("#00B0FF"), Color("#40C4FF"), Color("#76FF03"), Color("#00E676")]
	},
	"force": {
		"title": "🔥 元素・破壊系スキルツリー (火・雷・地)",
		"banner": "🔥 【元素・破壊】火・雷・地のスキルを解放・強化します。ポーションを消費して解放・強化できます。",
		"branch_titles": ["🔥 炎・爆破系", "⚡ 雷・電磁系", "💎 地・岩晶系"],
		"branch_colors": [Color("#FF6D00"), Color("#FFD600"), Color("#FFAB00")]
	},
	"mystic": {
		"title": "🔮 神秘・冥術系スキルツリー (毒・光・闇)",
		"banner": "🔮 【神秘・冥術】毒・光・闇のスキルを解放・強化します。ポーションを消費して解放・強化できます。",
		"branch_titles": ["🧪 毒・冥瘴系", "✨ 光・聖像系", "🌙 闇・重力系"],
		"branch_colors": [Color("#00E5FF"), Color("#FFF176"), Color("#BA68C8")]
	}
}


# ---------------------------------------------------------
# 🌟 スキル正当進化レジストリ（タロットカード選択式）
# 各属性ごとに中間進化（Lv.5 / 第1覚醒）と最終進化（Lv.20 / 極限神格化）の選択肢を定義
# ※氷の行動スキップは強大スキルのため、必ず最終進化（Lv.20）にのみ配置
# ---------------------------------------------------------
const SKILL_EVOLUTION_REGISTRY: Dictionary = {
	"ice": {
		"mid": [
			{
				"id": "ice_mid_wall",
				"numeral": "Ⅰ",
				"name": "白銀の氷壁",
				"role": "極厚氷盾 ＆ 冷気反撃",
				"desc": "シールド展開量が+50%増加。さらにシールド被弾時に、砕けた氷が敵へ強力な冷気反撃ダメージを与える。"
			},
			{
				"id": "ice_mid_permafrost",
				"numeral": "Ⅱ",
				"name": "永久凍土",
				"role": "持続延長 ＆ 状態変換",
				"desc": "氷マスの持続ターン+1。敵の炎・毒マスと氷マスが接触した時、無効化して即座に氷結させる。"
			},
			{
				"id": "ice_mid_pierce",
				"numeral": "Ⅲ",
				"name": "氷槍穿孔",
				"role": "防御無視冷気特攻",
				"desc": "氷破壊時の冷気ダメージ+40%。凍結状態の敵へのダメージが防御力無視となる。"
			}
		],
		"final": [
			{
				"id": "ice_final_skip",
				"numeral": "Ⅰ",
				"name": "絶対零度・完全凍結",
				"role": "極限神格：時間停止",
				"desc": "【敵の行動を1ターン完全スキップ！】極限の零度で敵の時を凍てつかせ、反撃の隙を一切与えない。（※氷の最終進化限定）"
			},
			{
				"id": "ice_final_avalanche",
				"numeral": "Ⅱ",
				"name": "天氷大崩落",
				"role": "盤面全凍結共鳴爆砕",
				"desc": "盤面上の全氷マスが一斉共鳴連鎖爆砕し、敵全体に特大全体冷気ダメージを与える。"
			},
			{
				"id": "ice_final_mirror",
				"numeral": "Ⅲ",
				"name": "氷華鏡面結界",
				"role": "ダメージ吸収 ＆ 完全反射",
				"desc": "氷盾展開中、受けるダメージの50%をHP回復に変換し、残り50%を冷気反射ダメージとして敵に跳ね返す。"
			}
		]
	},
	"fire": {
		"mid": [
			{
				"id": "fire_mid_inferno",
				"numeral": "Ⅰ",
				"name": "業火の余燼",
				"role": "残存マグマ ＆ 継続炎上",
				"desc": "爆発したマスに高熱のマグマ炎が残り、毎ターン敵に追加継続炎ダメージを与える。"
			},
			{
				"id": "fire_mid_chain",
				"numeral": "Ⅱ",
				"name": "連鎖誘爆",
				"role": "爆風拡大 ＆ 障害物誘爆",
				"desc": "爆風範囲が拡大し、周囲の障害物や敵の毒・氷を誘爆させて追加炎ダメージを与える。"
			},
			{
				"id": "fire_mid_strike",
				"numeral": "Ⅲ",
				"name": "紅蓮の剛撃",
				"role": "剣直撃ダメージ超強化",
				"desc": "剣マッチによる基本火力が大幅上昇（直撃ダメージ+50%）。"
			}
		],
		"final": [
			{
				"id": "fire_final_prominence",
				"numeral": "Ⅰ",
				"name": "プロミネンス・フレア",
				"role": "極限神格：装甲融解蒸発",
				"desc": "灼熱の太陽フレアを放ち、敵のシールドと防御バフを完全蒸発・粉砕する。"
			},
			{
				"id": "fire_final_purgatory",
				"numeral": "Ⅱ",
				"name": "煉獄焦土",
				"role": "永続猛火 ＆ 攻撃力減衰",
				"desc": "敵に消えることのない猛火の烙印を刻み、敵の攻撃力を永続で30%ダウンさせる。"
			},
			{
				"id": "fire_final_supernova",
				"numeral": "Ⅲ",
				"name": "超新星爆発",
				"role": "全爆弾融合極限一撃",
				"desc": "剣マッチ6個以上時、全爆弾が一斉に融合爆発して単体に究極の一撃を与える。"
			}
		]
	},
	"water": {
		"mid": [
			{
				"id": "water_mid_spring",
				"numeral": "Ⅰ",
				"name": "聖水の癒し手",
				"role": "HP回復強化 ＆ 浄化",
				"desc": "ポーション消去時のHP回復量+40%。さらに盤面上の有害状態異常マスを浄化する。"
			},
			{
				"id": "water_mid_pressure",
				"numeral": "Ⅱ",
				"name": "激流圧力",
				"role": "敵行動減退 ＆ 威力削ぎ",
				"desc": "水マス上のマッチで敵を押し戻し、敵の次攻撃の威力を25%削ぐ。"
			},
			{
				"id": "water_mid_resonance",
				"numeral": "Ⅲ",
				"name": "水鏡共鳴",
				"role": "連鎖誘発 ＆ コンボ加算",
				"desc": "水マスが消えた時、追加で同属性ピースを巻き込んでコンボ数を+2加算する。"
			}
		],
		"final": [
			{
				"id": "water_final_deluge",
				"numeral": "Ⅰ",
				"name": "大海嘯・万象呑流",
				"role": "極限神格：行動リセット",
				"desc": "巨大津波が盤面を一掃し、敵の溜め行動・詠唱を完全リセット＆大ダメージ。"
			},
			{
				"id": "water_final_immortality",
				"numeral": "Ⅱ",
				"name": "生命の不滅泉",
				"role": "致命傷回避 ＆ 完全復活",
				"desc": "HPが0になる致命傷を受けた時、水マスを全消費して1度だけHP全快で復活する。"
			},
			{
				"id": "water_final_maelstrom",
				"numeral": "Ⅲ",
				"name": "激動の渦潮",
				"role": "最大HP割合継続ダメージ",
				"desc": "水マス上の敵を渦潮に閉じ込め、毎ターン敵最大HPの5%の割合ダメージを与える。"
			}
		]
	},
	"thunder": {
		"mid": [
			{
				"id": "thunder_mid_voltage",
				"numeral": "Ⅰ",
				"name": "高圧放電",
				"role": "拡散連鎖電撃",
				"desc": "電撃が隣接マスへ連鎖放電し、複数の敵・部位へ拡散電撃ダメージ。"
			},
			{
				"id": "thunder_mid_magnetic",
				"numeral": "Ⅱ",
				"name": "磁場増幅",
				"role": "過負荷攻撃力蓄積",
				"desc": "コイン消去時に自身の攻撃力バフ（雷電過負荷）が蓄積する。"
			},
			{
				"id": "thunder_mid_flash",
				"numeral": "Ⅲ",
				"name": "瞬雷の一閃",
				"role": "会心撃 ＆ 電光石火",
				"desc": "クリティカル発生率+25%、クリティカルダメージ+50%。"
			}
		],
		"final": [
			{
				"id": "thunder_final_judgement",
				"numeral": "Ⅰ",
				"name": "天雷神罰・裁きの雷",
				"role": "極限神格：防御無視落雷",
				"desc": "敵の帯電状態を過負荷起爆し、防御無視の壊滅的落雷ダメージ。"
			},
			{
				"id": "thunder_final_hyperdrive",
				"numeral": "Ⅱ",
				"name": "超電導加速",
				"role": "ボーナスターン獲得",
				"desc": "ターン終了時、50%の確率で即座にボーナスターン（追加操作）を獲得。"
			},
			{
				"id": "thunder_final_catastrophe",
				"numeral": "Ⅲ",
				"name": "プラズマ・カタストロフ",
				"role": "全コイン帯電起爆",
				"desc": "盤面の全コインを一斉に帯電爆発させ、敵の攻撃ターンカウントを+2遅延させる。"
			}
		]
	},
	"wood": {
		"mid": [
			{
				"id": "wood_mid_roots",
				"numeral": "Ⅰ",
				"name": "深緑の根張り",
				"role": "急速成長 ＆ リジェネ倍増",
				"desc": "苗木が大木へ素早く進化し、毎ターンの自動HPリジェネが倍増。"
			},
			{
				"id": "wood_mid_thorns",
				"numeral": "Ⅱ",
				"name": "蔦の荊棘縛り",
				"role": "敵捕縛 ＆ 被ダメージ減退",
				"desc": "苗木の周囲の敵を棘で捕縛し、敵の与ダメージを20%減少させる。"
			},
			{
				"id": "wood_mid_harvest",
				"numeral": "Ⅲ",
				"name": "豊穣の恵み",
				"role": "食料共鳴資源獲得",
				"desc": "食料マッチ時に追加でポーションとコインを同時獲得。"
			}
		],
		"final": [
			{
				"id": "wood_final_yggdrasil",
				"numeral": "Ⅰ",
				"name": "世界樹ユグドラシル",
				"role": "極限神格：継続大再生 ＆ 浄化",
				"desc": "盤面に世界樹が顕現し、毎ターン全状態異常を解除＆最大HPの15%を継続回復。"
			},
			{
				"id": "wood_final_sealing",
				"numeral": "Ⅱ",
				"name": "霊木の樹縛陣",
				"role": "完全拘束 ＆ 追撃光線",
				"desc": "敵を完全に根で拘束し、敵の防御力を0にしつつ毎ターン大木から追撃光線を放つ。"
			},
			{
				"id": "wood_final_wrath",
				"numeral": "Ⅲ",
				"name": "大自然の怒り",
				"role": "生命爆発大破滅",
				"desc": "盤面の全木マスを一斉に生命爆発させ、累計回復量に応じた破滅的ダメージを与える。"
			}
		]
	},
	"wind": {
		"mid": [
			{
				"id": "wind_mid_slicer",
				"numeral": "Ⅰ",
				"name": "烈風刃",
				"role": "装甲切断 ＆ 防御力低下",
				"desc": "風の刃が敵を切り裂き、防御力を永続15%低下させる。"
			},
			{
				"id": "wind_mid_veil",
				"numeral": "Ⅱ",
				"name": "空蝉の風壁",
				"role": "回避率上昇 ＆ 旋風反撃",
				"desc": "敵の攻撃を回避する確率+20%。回避時に風の反撃刃を放つ。"
			},
			{
				"id": "wind_mid_cyclone",
				"numeral": "Ⅲ",
				"name": "サイクロン循環",
				"role": "連鎖率超向上",
				"desc": "風スキル発動時、落ちてくるピースの連鎖率が大幅に向上する。"
			}
		],
		"final": [
			{
				"id": "wind_final_tempest",
				"numeral": "Ⅰ",
				"name": "神嵐テンペスト",
				"role": "極限神格：バフ全消去嵐",
				"desc": "盤面全体を巨大竜巻が巻き込み、敵全体に多段猛嵐ダメージ＋敵の強化バフを全消去。"
			},
			{
				"id": "wind_final_vacuum",
				"numeral": "Ⅱ",
				"name": "真空崩壊",
				"role": "超圧縮吸引クリティカル",
				"desc": "風の刃が連続命中した敵を中心へ引きずり込み、超圧縮された風圧で即死級クリティカル。"
			},
			{
				"id": "wind_final_eternal",
				"numeral": "Ⅲ",
				"name": "常風の領域",
				"role": "制限時間延長 ＆ コンボ加速",
				"desc": "毎ターンの制限時間を+3秒延長し、コンボ倍率の上昇ペースを2倍にする。"
			}
		]
	},
	"earth": {
		"mid": [
			{
				"id": "earth_mid_bulwark",
				"numeral": "Ⅰ",
				"name": "金剛岩壁",
				"role": "シールド耐久上昇 ＆ 貫通無効",
				"desc": "シールドの耐久値+40%。さらに敵の貫通攻撃を無効化する。"
			},
			{
				"id": "earth_mid_tectonic",
				"numeral": "Ⅱ",
				"name": "地殻変動",
				"role": "下層震動 ＆ 連鎖誘発",
				"desc": "シールドマッチ時に下層ピースを激しく揺るがし、追加連鎖を誘発。"
			},
			{
				"id": "earth_mid_crush",
				"numeral": "Ⅲ",
				"name": "重力圧殺",
				"role": "盾耐久比例打撃",
				"desc": "シールド耐久値に比例した打撃ダメージを敵に叩きつける。"
			}
		],
		"final": [
			{
				"id": "earth_final_cataclysm",
				"numeral": "Ⅰ",
				"name": "ガイア・カタクリズム",
				"role": "極限神格：耐性粉砕隕石",
				"desc": "巨大な岩山が天より降り注ぎ、敵の全耐性を粉砕して壊滅的物理ダメージ。"
			},
			{
				"id": "earth_final_fortress",
				"numeral": "Ⅱ",
				"name": "不落の城塞",
				"role": "小ダメージ無効 ＆ デバフ遮絶",
				"desc": "一定値以下のダメージを完全に0化し、受けるあらゆるデバフを遮絶する。"
			},
			{
				"id": "earth_final_repulsion",
				"numeral": "Ⅲ",
				"name": "フォース・リパルジョン",
				"role": "蓄積ダメージ全反射波",
				"desc": "シールドが割れた瞬間、蓄積した全ダメージを2倍にして敵全体へ衝撃波として撃ち返す。"
			}
		]
	},
	"poison": {
		"mid": [
			{
				"id": "poison_mid_corrosive",
				"numeral": "Ⅰ",
				"name": "腐蝕猛毒",
				"role": "装甲直接融解 ＆ 毒強化",
				"desc": "毒のダメージが敵のシールド・装甲を直接溶かし、毎ターンの毒ダメージ+50%。"
			},
			{
				"id": "poison_mid_miasma",
				"numeral": "Ⅱ",
				"name": "冥瘴拡散",
				"role": "自動侵食 ＆ 行動鈍化",
				"desc": "毒マスが周囲のマスへ自動で侵食拡大し、敵の行動を鈍らせる。"
			},
			{
				"id": "poison_mid_extraction",
				"numeral": "Ⅲ",
				"name": "死霊抽出",
				"role": "毒吸血HP回復",
				"desc": "毒状態の敵にダメージを与えた時、そのダメージの20%をHPとして吸収。"
			}
		],
		"final": [
			{
				"id": "poison_final_lethal",
				"numeral": "Ⅰ",
				"name": "即死劇毒・致死臨界",
				"role": "極限神格：毒精算即座起爆",
				"desc": "敵の毒スタックが一定以上に達した時、残りの全毒ダメージを一瞬で即座に精算起爆する。"
			},
			{
				"id": "poison_final_pandemic",
				"numeral": "Ⅱ",
				"name": "パンデミック・エンド",
				"role": "全ステータス半減紫煙",
				"desc": "盤面全体を致死の紫煙で覆い尽くし、敵の全ステータスを半減させる。"
			},
			{
				"id": "poison_final_undying",
				"numeral": "Ⅲ",
				"name": "不死の瘴気肉体",
				"role": "不死結界 ＆ 無限シールド",
				"desc": "毒マスがある限りプレイヤーは死亡せず、毒ダメージ発生ごとにシールドが無限自動生成される。"
			}
		]
	},
	"light": {
		"mid": [
			{
				"id": "light_mid_aurora",
				"numeral": "Ⅰ",
				"name": "聖光のオーラ",
				"role": "被ダメージ軽減 ＆ 守護",
				"desc": "光スキル発動時に聖なる輝きで味方を守護し、被ダメージを30%軽減。"
			},
			{
				"id": "light_mid_purify",
				"numeral": "Ⅱ",
				"name": "浄化の閃光",
				"role": "状態異常即時消滅",
				"desc": "敵のデバフや盤面の有害マスを即座に光に変換して消滅させる。"
			},
			{
				"id": "light_mid_splendor",
				"numeral": "Ⅲ",
				"name": "黄金の光彩",
				"role": "獲得資金 ＆ スコア激増",
				"desc": "光スキル発動時に獲得コインとスコアが+50%増加。"
			}
		],
		"final": [
			{
				"id": "light_final_sanctuary",
				"numeral": "Ⅰ",
				"name": "エルドラド・サンクチュアリ",
				"role": "極限神格：聖域HP全快 ＆ 攻撃2倍",
				"desc": "聖域を展開し、毎ターンプレイヤーのHP全快＆攻撃力2倍の神聖オーラ付与。"
			},
			{
				"id": "light_final_excalibur",
				"numeral": "Ⅱ",
				"name": "天翔ける神光剣",
				"role": "破邪特効500%極大光線",
				"desc": "闇・魔族系敵に特効500%の破邪の極大光線を放ち、敵のHPバーを消滅させる。"
			},
			{
				"id": "light_final_radiance",
				"numeral": "Ⅲ",
				"name": "万物照覧",
				"role": "全マッチ自動大昇格",
				"desc": "盤面のあらゆるマッチが自動的に4マッチ以上の強力マッチに昇格する。"
			}
		]
	},
	"dark": {
		"mid": [
			{
				"id": "dark_mid_bind",
				"numeral": "Ⅰ",
				"name": "影縫いの呪詛",
				"role": "敵攻撃力強奪 ＆ 自強化",
				"desc": "敵の攻撃力を25%奪い、自分の攻撃力に加算する。"
			},
			{
				"id": "dark_mid_attraction",
				"numeral": "Ⅱ",
				"name": "虚無の引力",
				"role": "ピース吸引 ＆ 大連鎖",
				"desc": "闇の重力で周囲のピースを引き寄せ、大連鎖を発生させやすくする。"
			},
			{
				"id": "dark_mid_drain",
				"numeral": "Ⅲ",
				"name": "暗黒吸魂",
				"role": "剣闇ダメージHP吸収",
				"desc": "剣マッチによる闇ダメージの30%をHPとして吸収する。"
			}
		],
		"final": [
			{
				"id": "dark_final_blackhole",
				"numeral": "Ⅰ",
				"name": "アビス・ブラックホール",
				"role": "極限神格：事象の地平線消滅",
				"desc": "事象の地平線を開き、敵の攻撃・弾幕・デバフをすべて事象の彼方へ吸い込み消滅させる。"
			},
			{
				"id": "dark_final_executioner",
				"numeral": "Ⅱ",
				"name": "冥界の執行者",
				"role": "瀕死敵即座執行",
				"desc": "敵のHPが25%以下になった時、即死させる（ボスにも有効）。"
			},
			{
				"id": "dark_final_incarnate",
				"numeral": "Ⅲ",
				"name": "混沌の暗黒神",
				"role": "全攻撃相性無視2.5倍",
				"desc": "プレイヤーの与ダメージがすべて暗黒混沌ダメージとなり、属性相性を無視して2.5倍化する。"
			}
		]
	}
}

# 選択済み進化の保存辞書: skill_id -> {"mid": "evo_id", "final": "evo_id"}
var skill_evolutions: Dictionary = {}
var tarot_modal_panel: Panel = null

var skill_tree_items: Array[Dictionary] = [
	# --- Nature (自然・生命系: 水・氷・木・風) ---
	{
		"id": "water_1",
		"sp_type": 8,
		"match_recipe": "ポーション 4個消し",
		"category": "nature",
		"branch": 0,
		"tier": 0,
		"req_id": "",
		"name": "清流展開",
		"short_label": "水",
		"desc_lv": [],
		"color": Color("#00B0FF"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "ice_1",
		"sp_type": 13,
		"match_recipe": "シールド 4個消し",
		"category": "nature",
		"branch": 1,
		"tier": 0,
		"req_id": "",
		"name": "氷盾付与",
		"short_label": "氷",
		"desc_lv": [],
		"color": Color("#80D8FF"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "wood_1",
		"sp_type": 9,
		"match_recipe": "パン 4個消し",
		"category": "nature",
		"branch": 2,
		"tier": 0,
		"req_id": "",
		"name": "命の萌芽",
		"short_label": "木",
		"desc_lv": [],
		"color": Color("#76FF03"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "wind_1",
		"sp_type": 7,
		"match_recipe": "コイン 4個消し",
		"category": "nature",
		"branch": 3,
		"tier": 0,
		"req_id": "",
		"name": "疾風突風",
		"short_label": "風",
		"desc_lv": [],
		"color": Color("#00E676"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},

	# --- Force (元素・破壊系: 火・雷・地) ---
	{
		"id": "fire_1",
		"sp_type": 1,
		"match_recipe": "ソード 4個消し",
		"category": "force",
		"branch": 0,
		"tier": 0,
		"req_id": "",
		"name": "紅蓮爆破",
		"short_label": "火",
		"desc_lv": [],
		"color": Color("#FF6D00"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "thunder_1",
		"sp_type": 5,
		"match_recipe": "コイン 4個消し",
		"category": "force",
		"branch": 1,
		"tier": 0,
		"req_id": "",
		"name": "雷電連鎖",
		"short_label": "雷",
		"desc_lv": [],
		"color": Color("#FFD600"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "earth_1",
		"sp_type": 11,
		"match_recipe": "シールド 4個消し",
		"category": "force",
		"branch": 2,
		"tier": 0,
		"req_id": "",
		"name": "岩盤崩落",
		"short_label": "地",
		"desc_lv": [],
		"color": Color("#FFAB00"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},

	# --- Mystic (神秘・冥術系: 毒・光・闇) ---
	{
		"id": "poison_1",
		"sp_type": 14,
		"match_recipe": "ポーション 4個消し",
		"category": "mystic",
		"branch": 0,
		"tier": 0,
		"req_id": "",
		"name": "瘴気毒霧",
		"short_label": "毒",
		"desc_lv": [],
		"color": Color("#00E5FF"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "light_1",
		"sp_type": 10,
		"match_recipe": "コイン 4個消し",
		"category": "mystic",
		"branch": 1,
		"tier": 0,
		"req_id": "",
		"name": "聖光浄化",
		"short_label": "光",
		"desc_lv": [],
		"color": Color("#FFF176"),
		"cost": 1000,
		"level": 0,
		"max_level": 20
	},
	{
		"id": "dark_1",
		"sp_type": 6,
		"match_recipe": "ソード 4個消し",
		"category": "mystic",
		"branch": 2,
		"tier": 0,
		"req_id": "",
		"name": "虚無の特異点",
		"short_label": "闇",
		"desc_lv": [],
		"color": Color("#BA68C8"),
		"cost": 1000,
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
var _rendered_elem_category: String = "__unset__"
var elem_category_header_label: RichTextLabel = null
var elem_category_elements: Array = []
var relic_manager_ref: Node = null

const CATEGORY_ELEMENT_DEFS: Dictionary = {
	"nature": {
		"title": "🌿 自然・生命",
		"color": "00E676",
		"elements": [
			{"key": "water", "name": "水", "color": "00B0FF", "icon": "res://Texture/element/water.png", "emoji": "💧"},
			{"key": "ice", "name": "氷", "color": "80D8FF", "icon": "res://Texture/element/water.png", "emoji": "❄️"},
			{"key": "wood", "name": "木", "color": "76FF03", "icon": "", "emoji": "🌱"},
			{"key": "wind", "name": "風", "color": "69F0AE", "icon": "res://Texture/element/wind.png", "emoji": "🌪️"}
		]
	},
	"force": {
		"title": "🔥 元素・破壊",
		"color": "FF3D00",
		"elements": [
			{"key": "fire", "name": "火", "color": "FF3D00", "icon": "res://Texture/element/fire.png", "emoji": "🔥"},
			{"key": "thunder", "name": "雷", "color": "FFD600", "icon": "res://Texture/element/thunder.png", "emoji": "⚡"},
			{"key": "earth", "name": "地", "color": "D7CCC8", "icon": "", "emoji": "🪨"}
		]
	},
	"mystic": {
		"title": "🔮 神秘・冥術",
		"color": "E040FB",
		"elements": [
			{"key": "poison", "name": "毒", "color": "B388FF", "icon": "res://Texture/element/poison_tile_dry.png", "emoji": "🧪"},
			{"key": "light", "name": "光", "color": "FFF59D", "icon": "res://Texture/element/light.png", "emoji": "✨"},
			{"key": "dark", "name": "闇", "color": "EA80FC", "icon": "res://Texture/element/dark.png", "emoji": "🌙"}
		]
	}
}

func _get_chosen_element_category() -> String:
	var rm = _get_relic_manager()
	if rm and rm.has_method("get_chosen_element_category"):
		return rm.get_chosen_element_category()
	return ""

func get_element_count(elem_key: String) -> int:
	var total: int = int(turn_element_counts.get(elem_key, 0))
	var e_enum = ElementData.get_element_from_name(elem_key)
	if e_enum != ElementData.Element.NONE:
		total += int(turn_element_counts.get(e_enum, 0))
	return total
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
	if p:
		var node = p.get_node_or_null("PuzzleBoard")
		if node: return node
	if is_inside_tree() and get_tree() and get_tree().get_root():
		return get_tree().get_root().find_child("PuzzleBoard", true, false)
	return null

func _get_stage_manager() -> Node2D:
	var p = get_parent()
	return p.get_node_or_null("StageManager") if p else null


## 指定スキルの進化選択肢を取得
func get_evolution_choices(skill_id: String, milestone_lvl: int) -> Array[Dictionary]:
	var element = skill_id.split("_")[0]
	if not SKILL_EVOLUTION_REGISTRY.has(element):
		return []
	var pool_key = "mid" if milestone_lvl == 5 else ("final" if milestone_lvl == 20 else "")
	if pool_key == "":
		return []
	var res: Array[Dictionary] = []
	for item in SKILL_EVOLUTION_REGISTRY[element].get(pool_key, []):
		res.append(item)
	return res

## スキルの進化特性を選択・記録
func choose_skill_evolution(skill_id: String, milestone_lvl: int, evo_id: String) -> void:
	if not skill_evolutions.has(skill_id):
		skill_evolutions[skill_id] = {}
	var evo_slot = "mid" if milestone_lvl == 5 else "final"
	skill_evolutions[skill_id][evo_slot] = evo_id
	for s_item in skill_tree_items:
		if s_item.get("id") == skill_id:
			s_item["evolution_" + evo_slot] = evo_id
			break

## 選択された進化IDを取得
func get_chosen_evolution(skill_id: String, milestone_lvl: int) -> String:
	if not skill_evolutions.has(skill_id):
		return ""
	var evo_slot = "mid" if milestone_lvl == 5 else "final"
	return skill_evolutions[skill_id].get(evo_slot, "")

## 選択済みの進化を持っているか判定
func has_chosen_evolution(skill_id: String, milestone_lvl: int) -> bool:
	return get_chosen_evolution(skill_id, milestone_lvl) != ""

## 進化名の取得
func _get_evolution_name(skill_id: String, milestone_lvl: int, evo_id: String) -> String:
	var choices = get_evolution_choices(skill_id, milestone_lvl)
	for ch in choices:
		if ch.get("id") == evo_id:
			return ch.get("name", "")
	return evo_id

## 進化データ辞書の取得（numeral, name, role, desc）
func get_evolution_data(skill_id: String, milestone_lvl: int, evo_id: String) -> Dictionary:
	var choices = get_evolution_choices(skill_id, milestone_lvl)
	for ch in choices:
		if ch.get("id") == evo_id:
			return ch
	return {}

## 指定特性を習得しているか判定（skill_idまたは系統プレフィックス）
func has_skill_trait(skill_id: String, evo_id: String) -> bool:
	if skill_evolutions.has(skill_id):
		if skill_evolutions[skill_id].get("mid", "") == evo_id or skill_evolutions[skill_id].get("final", "") == evo_id:
			return true
	var el_prefix = skill_id.split("_")[0]
	for sk in skill_evolutions:
		if sk.begins_with(el_prefix):
			if skill_evolutions[sk].get("mid", "") == evo_id or skill_evolutions[sk].get("final", "") == evo_id:
				return true
	return false


func _init() -> void:
	for s_item in skill_tree_items:
		s_item["max_level"] = 20
		s_item["desc_lv"] = get_skill_descriptions(s_item["id"])

## スキルごとのLv1〜20の詳細効果テキスト生成
## スキルごとのLv1〜20の詳細効果テキスト生成
static func get_skill_descriptions(skill_id: String) -> Array[String]:
	var legacy_map: Dictionary = {
		"bomb": "fire_1", "cross_bomb": "fire_2", "gemini_bomb": "fire_3",
		"lightning": "thunder_1", "charge_bomb": "thunder_3",
		"aqua_splash": "water_1", "tree_sprout": "wood_1", "color_converter": "wood_2",
		"tornado": "wind_1", "disco_ball": "light_3", "holy_star": "light_1", "holy_light": "light_1", "magnet": "light_1", "black_hole": "dark_3",
		"poison_mist": "poison_1"
	}
	var real_id = legacy_map.get(skill_id, skill_id)
	match real_id:
		"water_1":
			return [
				"【水マス2個生成】火と隣接で蒸気消去・水流ダメージ+15%",
				"【水マス3個生成】火と隣接で蒸気消去・水流ダメージ+30%",
				"【水マス3個生成】火と隣接で蒸気消去・水流ダメージ+45%",
				"【水マス4個生成】火と隣接で蒸気消去・水流ダメージ+60%",
				"【水マス4個生成】火と隣接で蒸気消去・水流ダメージ+75%",
				"【水マス5個生成】火と隣接で蒸気消去・水流ダメージ+90%",
				"【水マス5個生成】火と隣接で蒸気消去・水流ダメージ+105%",
				"【水マス6個生成】火と隣接で蒸気消去・水流ダメージ+120%",
				"【水マス6個生成】火と隣接で蒸気消去・水流ダメージ+135%",
				"【水マス7個生成】火と隣接で蒸気消去・水流ダメージ+150%",
				"【水マス7個生成】火と隣接で蒸気消去・水流ダメージ+165%",
				"【水マス8個生成】火と隣接で蒸気消去・水流ダメージ+180%",
				"【水マス8個生成】火と隣接で蒸気消去・水流ダメージ+195%",
				"【水マス9個生成】火と隣接で蒸気消去・水流ダメージ+210%",
				"【水マス9個生成】火と隣接で蒸気消去・水流ダメージ+225%",
				"【水マス10個生成】火と隣接で蒸気消去・水流ダメージ+240%",
				"【水マス10個生成】火と隣接で蒸気消去・水流ダメージ+255%",
				"【水マス11個生成】火と隣接で蒸気消去・水流ダメージ+270%",
				"【水マス11個生成】火と隣接で蒸気消去・水流ダメージ+285%",
				"【水マス12個生成】火と隣接で蒸気消去・水流ダメージ+300%【神格解放】"
			]
		"water_2":
			return [
				"【水マス共鳴回復】盤面の水マス数×180HP回復＋隣接2マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×210HP回復＋隣接2マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×240HP回復＋隣接3マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×270HP回復＋隣接3マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×300HP回復＋隣接3マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×330HP回復＋隣接4マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×360HP回復＋隣接4マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×390HP回復＋隣接4マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×420HP回復＋隣接5マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×450HP回復＋隣接5マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×480HP回復＋隣接5マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×510HP回復＋隣接6マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×540HP回復＋隣接6マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×570HP回復＋隣接6マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×600HP回復＋隣接7マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×630HP回復＋隣接7マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×660HP回復＋隣接7マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×690HP回復＋隣接8マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×720HP回復＋隣接8マスへ浸水拡大",
				"【水マス共鳴回復】盤面の水マス数×750HP回復＋隣接8マスへ浸水拡大【神格解放】"
			]
		"water_3":
			return [
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+20%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+40%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+60%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+80%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+100%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+120%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+140%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+160%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+180%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+200%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+220%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+240%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+260%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+280%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+300%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+320%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+340%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+360%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+380%",
				"【大海嘯・駒変換】水マス上の駒を同色変換し大マッチ確定＋水流ダメージ+400%【神格解放】"
			]
		"ice_1":
			return [
				"【氷マス2個生成＆シールド180】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス3個生成＆シールド210】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス3個生成＆シールド240】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス4個生成＆シールド270】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス4個生成＆シールド300】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス5個生成＆シールド330】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス5個生成＆シールド360】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス6個生成＆シールド390】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス6個生成＆シールド420】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス7個生成＆シールド450】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス7個生成＆シールド480】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス8個生成＆シールド510】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス8個生成＆シールド540】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス9個生成＆シールド570】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス9個生成＆シールド600】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス10個生成＆シールド630】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス10個生成＆シールド660】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス11個生成＆シールド690】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス11個生成＆シールド720】隣接効果の進行停止・炎で融解(氷→水→消える)",
				"【氷マス12個生成＆シールド750】隣接効果の進行停止・炎で融解(氷→水→消える)【神格解放】"
			]
		"ice_2":
			return [
				"【連鎖氷結】水マスや敵効果マス2個を強制氷結＋冷気ダメージ+15%",
				"【連鎖氷結】水マスや敵効果マス3個を強制氷結＋冷気ダメージ+30%",
				"【連鎖氷結】水マスや敵効果マス3個を強制氷結＋冷気ダメージ+45%",
				"【連鎖氷結】水マスや敵効果マス4個を強制氷結＋冷気ダメージ+60%",
				"【連鎖氷結】水マスや敵効果マス4個を強制氷結＋冷気ダメージ+75%",
				"【連鎖氷結】水マスや敵効果マス5個を強制氷結＋冷気ダメージ+90%",
				"【連鎖氷結】水マスや敵効果マス5個を強制氷結＋冷気ダメージ+105%",
				"【連鎖氷結】水マスや敵効果マス6個を強制氷結＋冷気ダメージ+120%",
				"【連鎖氷結】水マスや敵効果マス6個を強制氷結＋冷気ダメージ+135%",
				"【連鎖氷結】水マスや敵効果マス7個を強制氷結＋冷気ダメージ+150%",
				"【連鎖氷結】水マスや敵効果マス7個を強制氷結＋冷気ダメージ+165%",
				"【連鎖氷結】水マスや敵効果マス8個を強制氷結＋冷気ダメージ+180%",
				"【連鎖氷結】水マスや敵効果マス8個を強制氷結＋冷気ダメージ+195%",
				"【連鎖氷結】水マスや敵効果マス9個を強制氷結＋冷気ダメージ+210%",
				"【連鎖氷結】水マスや敵効果マス9個を強制氷結＋冷気ダメージ+225%",
				"【連鎖氷結】水マスや敵効果マス10個を強制氷結＋冷気ダメージ+240%",
				"【連鎖氷結】水マスや敵効果マス10個を強制氷結＋冷気ダメージ+255%",
				"【連鎖氷結】水マスや敵効果マス11個を強制氷結＋冷気ダメージ+270%",
				"【連鎖氷結】水マスや敵効果マス11個を強制氷結＋冷気ダメージ+285%",
				"【連鎖氷結】水マスや敵効果マス12個を強制氷結＋冷気ダメージ+300%【神格解放】"
			]
		"ice_3":
			return [
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+25%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+50%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+75%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+100%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+125%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+150%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+175%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+200%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+225%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+250%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+275%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+300%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+325%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+350%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+375%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+400%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+425%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+450%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+475%",
				"【氷晶共鳴爆砕】全氷マスを一斉3×3破砕・敵効果を粉砕消滅＋特大冷気+500%【神格解放】"
			]
		"wood_1":
			return [
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+100回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+120回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+140回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+160回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+180回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+200回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+220回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+240回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+260回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+280回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+300回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+320回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+340回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+360回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+380回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+400回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+420回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+440回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+460回復＋自然追撃",
				"【苗木植樹】水吸収で3×3大木へ進化・毎ターンHP+480回復＋自然追撃【神格解放】"
			]
		"wood_2":
			return [
				"【根張り吸水】離れた水マス1個を吸い上げ即成長段階+1＋HP+300即時回復",
				"【根張り吸水】離れた水マス1個を吸い上げ即成長段階+1＋HP+350即時回復",
				"【根張り吸水】離れた水マス2個を吸い上げ即成長段階+1＋HP+400即時回復",
				"【根張り吸水】離れた水マス2個を吸い上げ即成長段階+1＋HP+450即時回復",
				"【根張り吸水】離れた水マス2個を吸い上げ即成長段階+1＋HP+500即時回復",
				"【根張り吸水】離れた水マス3個を吸い上げ即成長段階+1＋HP+550即時回復",
				"【根張り吸水】離れた水マス3個を吸い上げ即成長段階+1＋HP+600即時回復",
				"【根張り吸水】離れた水マス3個を吸い上げ即成長段階+1＋HP+650即時回復",
				"【根張り吸水】離れた水マス4個を吸い上げ即成長段階+1＋HP+700即時回復",
				"【根張り吸水】離れた水マス4個を吸い上げ即成長段階+1＋HP+750即時回復",
				"【根張り吸水】離れた水マス4個を吸い上げ即成長段階+1＋HP+800即時回復",
				"【根張り吸水】離れた水マス5個を吸い上げ即成長段階+1＋HP+850即時回復",
				"【根張り吸水】離れた水マス5個を吸い上げ即成長段階+1＋HP+900即時回復",
				"【根張り吸水】離れた水マス5個を吸い上げ即成長段階+1＋HP+950即時回復",
				"【根張り吸水】離れた水マス6個を吸い上げ即成長段階+1＋HP+1000即時回復",
				"【根張り吸水】離れた水マス6個を吸い上げ即成長段階+1＋HP+1050即時回復",
				"【根張り吸水】離れた水マス6個を吸い上げ即成長段階+1＋HP+1100即時回復",
				"【根張り吸水】離れた水マス7個を吸い上げ即成長段階+1＋HP+1150即時回復",
				"【根張り吸水】離れた水マス7個を吸い上げ即成長段階+1＋HP+1200即時回復",
				"【根張り吸水】離れた水マス7個を吸い上げ即成長段階+1＋HP+1250即時回復【神格解放】"
			]
		"wood_3":
			return [
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+25%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+50%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+75%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+100%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+125%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+150%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+175%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+200%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+225%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+250%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+275%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+300%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+325%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+350%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+375%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+400%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+425%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+450%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+475%",
				"【世界樹結実】木の周囲マスをパン駒(回復)に一斉結実させ大連鎖＋自然追撃+500%【神格解放】"
			]
		"wind_1":
			return [
				"【直線突風・敵効果消滅】縦1列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦1列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦2列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦2列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦2列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦3列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦3列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦3列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦4列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦4列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦4列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦5列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦5列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦5列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦6列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦6列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦6列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦7列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦7列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)",
				"【直線突風・敵効果消滅】縦7列に竜巻を放ち敵所有効果のみを一掃(駒は無傷)【神格解放】"
			]
		"wind_2":
			return [
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+15%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+30%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+45%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+60%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+75%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+90%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+105%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+120%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+135%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+150%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+165%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+180%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+195%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+210%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+225%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+240%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+255%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+270%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+285%",
				"【風向き操作】自軍効果マスを風下へシフト移動させ属性シナジー誘発＋風撃+300%【神格解放】"
			]
		"wind_3":
			return [
				"【廻風所有権反転】敵所有の効果マス2個を自軍所有へ完全強奪・反転＋風嵐+20%",
				"【廻風所有権反転】敵所有の効果マス3個を自軍所有へ完全強奪・反転＋風嵐+40%",
				"【廻風所有権反転】敵所有の効果マス3個を自軍所有へ完全強奪・反転＋風嵐+60%",
				"【廻風所有権反転】敵所有の効果マス4個を自軍所有へ完全強奪・反転＋風嵐+80%",
				"【廻風所有権反転】敵所有の効果マス4個を自軍所有へ完全強奪・反転＋風嵐+100%",
				"【廻風所有権反転】敵所有の効果マス5個を自軍所有へ完全強奪・反転＋風嵐+120%",
				"【廻風所有権反転】敵所有の効果マス5個を自軍所有へ完全強奪・反転＋風嵐+140%",
				"【廻風所有権反転】敵所有の効果マス6個を自軍所有へ完全強奪・反転＋風嵐+160%",
				"【廻風所有権反転】敵所有の効果マス6個を自軍所有へ完全強奪・反転＋風嵐+180%",
				"【廻風所有権反転】敵所有の効果マス7個を自軍所有へ完全強奪・反転＋風嵐+200%",
				"【廻風所有権反転】敵所有の効果マス7個を自軍所有へ完全強奪・反転＋風嵐+220%",
				"【廻風所有権反転】敵所有の効果マス8個を自軍所有へ完全強奪・反転＋風嵐+240%",
				"【廻風所有権反転】敵所有の効果マス8個を自軍所有へ完全強奪・反転＋風嵐+260%",
				"【廻風所有権反転】敵所有の効果マス9個を自軍所有へ完全強奪・反転＋風嵐+280%",
				"【廻風所有権反転】敵所有の効果マス9個を自軍所有へ完全強奪・反転＋風嵐+300%",
				"【廻風所有権反転】敵所有の効果マス10個を自軍所有へ完全強奪・反転＋風嵐+320%",
				"【廻風所有権反転】敵所有の効果マス10個を自軍所有へ完全強奪・反転＋風嵐+340%",
				"【廻風所有権反転】敵所有の効果マス11個を自軍所有へ完全強奪・反転＋風嵐+360%",
				"【廻風所有権反転】敵所有の効果マス11個を自軍所有へ完全強奪・反転＋風嵐+380%",
				"【廻風所有権反転】敵所有の効果マス12個を自軍所有へ完全強奪・反転＋風嵐+400%【神格解放】"
			]
		"fire_1":
			return [
				"【分散着火】離れたマスへ炎2箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎3箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎3箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎4箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎4箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎5箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎5箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎6箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎6箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎7箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎7箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎8箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎8箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎9箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎9箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎10箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎10箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎11箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎11箇所着火(延焼最大化)・火傷＋氷融解",
				"【分散着火】離れたマスへ炎12箇所着火(延焼最大化)・火傷＋氷融解【神格解放】"
			]
		"fire_2":
			return [
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+15%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+30%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+45%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+60%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+75%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+90%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+105%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+120%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+135%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+150%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+165%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+180%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+195%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+210%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+225%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+240%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+255%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+270%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+285%",
				"【爆燃加速】全炎マスを強制延焼・氷融解＆蒸気消去即時発動＋炎爆+300%【神格解放】"
			]
		"fire_3":
			return [
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+25%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+50%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+75%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+100%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+125%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+150%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+175%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+200%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+225%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+250%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+275%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+300%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+325%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+350%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+375%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+400%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+425%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+450%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+475%",
				"【焦土大爆破】全炎マスを一斉起爆(各3×3消去)・炎数×紅蓮特大ダメージ+500%【神格解放】"
			]
		"thunder_1":
			return [
				"【落雷帯電】落雷2発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+15%",
				"【落雷帯電】落雷3発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+30%",
				"【落雷帯電】落雷3発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+45%",
				"【落雷帯電】落雷4発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+60%",
				"【落雷帯電】落雷4発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+75%",
				"【落雷帯電】落雷5発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+90%",
				"【落雷帯電】落雷5発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+105%",
				"【落雷帯電】落雷6発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+120%",
				"【落雷帯電】落雷6発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+135%",
				"【落雷帯電】落雷7発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+150%",
				"【落雷帯電】落雷7発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+165%",
				"【落雷帯電】落雷8発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+180%",
				"【落雷帯電】落雷8発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+195%",
				"【落雷帯電】落雷9発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+210%",
				"【落雷帯電】落雷9発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+225%",
				"【落雷帯電】落雷10発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+240%",
				"【落雷帯電】落雷10発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+255%",
				"【落雷帯電】落雷11発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+270%",
				"【落雷帯電】落雷11発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+285%",
				"【落雷帯電】落雷12発・着弾点帯電・氷/石直撃で3×3破砕＋雷撃+300%【神格解放】"
			]
		"thunder_2":
			return [
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+18%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+36%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+54%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+72%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+90%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+108%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+126%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+144%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+162%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+180%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+198%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+216%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+234%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+252%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+270%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+288%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+306%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+324%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+342%",
				"【感電網電導】帯電マスと水マスを雷ラインで結び一斉感電消去＋電撃+360%【神格解放】"
			]
		"thunder_3":
			return [
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+25%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+50%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+75%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+100%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+125%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+150%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+175%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+200%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+225%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+250%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+275%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+300%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+325%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+350%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+375%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+400%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+425%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+450%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+475%",
				"【超電磁砲】全帯電・石・氷を一斉3×3過負荷爆砕＋極太貫通雷撃+500%【神格解放】"
			]
		"earth_1":
			return [
				"【輝石生成】移動可能石2個生成・マッチ/雷で3×3破砕・シールド+180",
				"【輝石生成】移動可能石3個生成・マッチ/雷で3×3破砕・シールド+210",
				"【輝石生成】移動可能石3個生成・マッチ/雷で3×3破砕・シールド+240",
				"【輝石生成】移動可能石4個生成・マッチ/雷で3×3破砕・シールド+270",
				"【輝石生成】移動可能石4個生成・マッチ/雷で3×3破砕・シールド+300",
				"【輝石生成】移動可能石5個生成・マッチ/雷で3×3破砕・シールド+330",
				"【輝石生成】移動可能石5個生成・マッチ/雷で3×3破砕・シールド+360",
				"【輝石生成】移動可能石6個生成・マッチ/雷で3×3破砕・シールド+390",
				"【輝石生成】移動可能石6個生成・マッチ/雷で3×3破砕・シールド+420",
				"【輝石生成】移動可能石7個生成・マッチ/雷で3×3破砕・シールド+450",
				"【輝石生成】移動可能石7個生成・マッチ/雷で3×3破砕・シールド+480",
				"【輝石生成】移動可能石8個生成・マッチ/雷で3×3破砕・シールド+510",
				"【輝石生成】移動可能石8個生成・マッチ/雷で3×3破砕・シールド+540",
				"【輝石生成】移動可能石9個生成・マッチ/雷で3×3破砕・シールド+570",
				"【輝石生成】移動可能石9個生成・マッチ/雷で3×3破砕・シールド+600",
				"【輝石生成】移動可能石10個生成・マッチ/雷で3×3破砕・シールド+630",
				"【輝石生成】移動可能石10個生成・マッチ/雷で3×3破砕・シールド+660",
				"【輝石生成】移動可能石11個生成・マッチ/雷で3×3破砕・シールド+690",
				"【輝石生成】移動可能石11個生成・マッチ/雷で3×3破砕・シールド+720",
				"【輝石生成】移動可能石12個生成・マッチ/雷で3×3破砕・シールド+750【神格解放】"
			]
		"earth_2":
			return [
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+155",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+190",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+225",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+260",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+295",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+330",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+365",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+400",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+435",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+470",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+505",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+540",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+575",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+610",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+645",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+680",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+715",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+750",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+785",
				"【地脈引力】輝石の磁力で同色駒を引き寄せ整列マッチ＋シールド+820【神格解放】"
			]
		"earth_3":
			return [
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+25%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+50%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+75%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+100%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+125%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+150%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+175%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+200%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+225%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+250%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+275%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+300%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+325%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+350%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+375%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+400%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+425%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+450%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+475%",
				"【大陸破砕】全石マスを一斉共振大爆発(周囲8マス消去)＋隕石ダメージ+500%【神格解放】"
			]
		"poison_1":
			return [
				"【薬毒散布】毒マス2個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス3個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス3個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス4個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス4個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス5個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス5個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス6個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス6個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス7個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス7個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス8個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス8個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス9個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス9個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス10個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス10個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス11個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス11個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃",
				"【薬毒散布】毒マス12個生成(水上で2倍速・氷隣接で停止)・毎ターン毒追撃【神格解放】"
			]
		"poison_2":
			return [
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+15%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+30%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+45%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+60%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+75%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+90%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+105%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+120%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+135%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+150%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+165%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+180%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+195%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+210%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+225%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+240%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+255%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+270%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+285%",
				"【腐食培養】全毒マスを即座に1歩伝染＋敵設置物を毒へ融解変換＋毒撃+300%【神格解放】"
			]
		"poison_3":
			return [
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+25%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+50%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+75%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+100%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+125%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+150%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+175%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+200%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+225%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+250%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+275%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+300%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+325%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+350%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+375%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+400%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+425%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+450%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+475%＋30%HP吸収",
				"【劇毒大爆発】全毒マスを一斉起爆・毒数×致死ダメージ+500%＋30%HP吸収【神格解放】"
			]
		"light_1":
			return [
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ70＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ85＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ100＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ115＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ130＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ145＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ160＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ175＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ190＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ205＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ220＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ235＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ250＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ265＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ280＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ295＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ310＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ325＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ340＋盤面浄化＆コイン獲得",
				"【聖光星】全方位へ聖なる光を放ち敵に光ダメージ355＋盤面浄化＆コイン獲得【神格解放】"
			]
		"light_2":
			return [
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+18%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+36%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+54%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+72%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+90%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+108%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+126%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+144%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+162%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+180%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+198%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+216%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+234%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+252%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+270%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+288%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+306%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+324%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+342%",
				"【聖光レーザー】聖像間の光線で妨害マス浄化＆同色変換確定マッチ＋光撃+360%【神格解放】"
			]
		"light_3":
			return [
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+25%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+50%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+75%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+100%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+125%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+150%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+175%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+200%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+225%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+250%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+275%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+300%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+325%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+350%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+375%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+400%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+425%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+450%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+475%",
				"【黄金郷変換】全敵妨害マスを聖像やコインへ黄金変換＋聖像数×聖光メテオ+500%【神格解放】"
			]
		"dark_1":
			return [
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス2個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス3個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス3個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス4個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス4個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス5個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス5個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス6個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス6個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス7個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス7個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス8個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス8個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス9個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス9個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス10個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス10個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス11個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス11個生成(マッチでHP吸収)",
				"【星影展開】暗雲生成(毎ターン敵HP削り)＆影護マス12個生成(マッチでHP吸収)【神格解放】"
			]
		"dark_2":
			return [
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+185＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+220＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+255＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+290＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+325＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+360＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+395＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+430＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+465＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+500＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+535＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+570＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+605＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+640＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+675＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+710＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+745＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+780＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+815＆敵有利マス消滅",
				"【領域浸食】暗雲領域を一気に影護マスへ侵食＋敵HP吸収+850＆敵有利マス消滅【神格解放】"
			]
		"dark_3":
			return [
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+25%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+50%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+75%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+100%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+125%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+150%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+175%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+200%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+225%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+250%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+275%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+300%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+325%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+350%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+375%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+400%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+425%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+450%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+475%＋50%HP吸収",
				"【虚無特異点】全影護マスと駒をブラックホールへ吸引消滅・超重力+500%＋50%HP吸収【神格解放】"
			]
		_:
			return ["効果強化 (Lv1)"]

func _ready() -> void:
	# フォントにシステム日本語フォールバックを設定（あらゆる漢字の確実な描画を保証）
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	# 0. レリックマネージャーのシグナル接続
	var rm = _get_relic_manager()
	if rm and rm.has_signal("element_category_chosen"):
		if not rm.is_connected("element_category_chosen", Callable(self, "on_element_category_chosen")):
			rm.connect("element_category_chosen", Callable(self, "on_element_category_chosen"))

	# 1. 敵画面の真下: スコア欄の初期化 (x: 1190.0, y: 472.0, w: 725.0, h: 66.0)
	var sc_rect = get_node_or_null("score_rect") as ColorRect
	if sc_rect == null:
		sc_rect = ColorRect.new()
		sc_rect.name = "score_rect"
		sc_rect.z_index = -10
		sc_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc_rect.color = Color(0.85, 0.72, 0.38, 1.0)
		add_child(sc_rect)
	sc_rect.position = Vector2(1190.0, 472.0)
	sc_rect.size = Vector2(725.0, 66.0)

	var sc2_rect = get_node_or_null("score2_rect") as ColorRect
	if sc2_rect == null:
		sc2_rect = ColorRect.new()
		sc2_rect.name = "score2_rect"
		sc2_rect.z_index = -10
		sc2_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc2_rect.color = Color(0.07, 0.09, 0.13, 0.96)
		add_child(sc2_rect)
	sc2_rect.position = Vector2(1192.0, 474.0)
	sc2_rect.size = Vector2(721.0, 62.0)

	if label != null:
		label.visible = true
		label.position = Vector2(1204.0, 478.0)
		label.size = Vector2(700.0, 54.0)
		label.z_index = 2
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("normal_font", CUSTOM_FONT)
		label.add_theme_font_override("bold_font", CUSTOM_FONT)
		label.add_theme_constant_override("outline_size", 8)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
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

	# 2. その下・左側: アイテム値パネルの初期化 (x: 1190.0, y: 544.0, w: 425.0, h: 400.0 -> 盤面下端 y=944 に完全一致)
	if status_rect != null:
		status_rect.position = Vector2(1190.0, 544.0)
		status_rect.size = Vector2(425.0, 400.0)
		if status_rect is ColorRect:
			status_rect.color = Color(0.85, 0.72, 0.38, 1.0)
	if status2_rect != null:
		status2_rect.position = Vector2(1192.0, 546.0)
		status2_rect.size = Vector2(421.0, 396.0)
		if status2_rect is ColorRect:
			status2_rect.color = Color(0.07, 0.09, 0.13, 0.96)

	# 各値アイコン（行 y: 546.0 + 79.2 * i に独立配置、特大46x46サイズ）
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
		var row_y = 546.0 + 79.2 * float(i)
		icn.position = Vector2(1204.0, row_y + 16.6)
		icn.size = Vector2(46.0, 46.0)
		icn.z_index = 2

	for i in range(mini(5, divscorelabel.size())):
		var sc_lbl = divscorelabel[i]
		var row_y = 546.0 + 79.2 * float(i)
		sc_lbl.position = Vector2(1276.0, row_y + 14.0)
		sc_lbl.scale = Vector2(0.50, 0.50)

		# アイテム値ホバーツールチップ領域（行全体）
	_setup_combat_hud_hover_tooltips()

	# 3. その下・右側: 選択した属性値パネルの初期化 (x: 1625.0, y: 544.0, w: 290.0, h: 400.0 -> 盤面下端 y=944 に完全一致)
	_setup_elem_status_panel()

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

	# コンボ欄・敵画面枠の初期化・スタイル統一 (x: 26..216, y: 166..346)
	var cb_rect1 = get_node_or_null("comborect1") as ColorRect
	if cb_rect1:
		cb_rect1.position = Vector2(26, 166)
		cb_rect1.size = Vector2(190, 180)
		cb_rect1.color = Color(0.85, 0.72, 0.38, 1.0)
	var cb_rect2 = get_node_or_null("comborect2") as ColorRect
	if cb_rect2:
		cb_rect2.position = Vector2(30, 170)
		cb_rect2.size = Vector2(182, 172)
		cb_rect2.color = Color(0.07, 0.09, 0.13, 0.96)

	var scn_rect2 = get_node_or_null("screen2") as ColorRect
	if scn_rect2:
		scn_rect2.color = Color(0.85, 0.72, 0.38, 1.0)
	var scn_rect = get_node_or_null("screen") as ColorRect
	if scn_rect:
		scn_rect.color = Color(0.07, 0.09, 0.13, 0.96)

	if combo_label != null:
		combo_label.z_index = 2
		combo_label.scroll_active = false
		combo_label.add_theme_font_override("normal_font", combo_font)
		combo_label.add_theme_font_override("bold_font", combo_font)
		combo_label.add_theme_font_size_override("normal_font_size", 34)
		combo_label.add_theme_font_size_override("bold_font_size", 34)
		combo_label.add_theme_constant_override("outline_size", 4)
		combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	if combocount_label != null:
		combocount_label.z_index = 2
		combocount_label.scroll_active = false
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
		fv_rect.color = Color(0.85, 0.72, 0.38, 1.0)
	var fv_rect2 = get_node_or_null("feverrect2") as ColorRect
	if fv_rect2:
		fv_rect2.position = Vector2(30, 362)
		fv_rect2.size = Vector2(182, 224)
		fv_rect2.color = Color(0.07, 0.09, 0.13, 0.96)

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
		
	# 敵画面真下のスコア欄更新
	if label != null:
		label.visible = true
		var combo_str = "  [color=#00E5FF](%d COMBO)[/color]" % combocount if combocount > 1 else ""
		label.text = "[font_size=36][b][color=#FFD700]SCORE :[/color]  [color=#FFFFFF]%s[/color][/b]%s[/font_size]" % [_format_comma(totalScore), combo_str]
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
		divscorelabel[i].text = "[b][color=%s]%s[/color][/b][font_size=24]%s[/font_size]" % [
			ATT_COLORS[i], formatted_val, breakdown_text
		]

	# アイテム値欄のサイズ維持 (横幅425.0px / 内枠421.0px / 高さ400.0px -> 盤面下端 y=944 に一致)
	if status_rect != null:
		status_rect.size = Vector2(425.0, 400.0)
	if status2_rect != null:
		status2_rect.size = Vector2(421.0, 396.0)

	if combocount_label != null:
		combocount_label.text = "[center][b][color=#FFD700]%d[/color][/b][/center]" % combocount
	if combo_label != null:
		combo_label.text = "[center][b][color=#FFD54F]◆ COMBO ◆[/color][/b][/center]"

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
	var legacy_map: Dictionary = {
		"bomb": "fire_1", "cross_bomb": "fire_2", "gemini_bomb": "fire_3",
		"lightning": "thunder_1", "charge_bomb": "thunder_3",
		"aqua_splash": "water_1", "tree_sprout": "wood_1", "color_converter": "wood_2",
		"tornado": "wind_1", "disco_ball": "light_3", "holy_star": "light_1", "holy_light": "light_1", "magnet": "light_1", "black_hole": "dark_3",
		"poison_mist": "poison_1"
	}
	var real_id = legacy_map.get(skill_id, skill_id)
	for s in skill_tree_items:
		if s.get("id", "") == real_id:
			return s
	var el_prefix = real_id.split("_")[0]
	for s in skill_tree_items:
		if s.get("id", "").begins_with(el_prefix + "_"):
			return s
	return {}

func get_skill_level(skill_id: String) -> int:
	var s = get_skill_by_id(skill_id)
	return int(s.get("level", 0))

## リッチな大型ショップ＆スキルツリーUIの生成 (1680 x 874) - 進むボタンと完全非干渉の本格RPGデザイン
func _setup_shop_page_controls() -> void:
	var parent = get_parent()
	if parent == null:
		return

	# 旧バフボタン群を常時非表示に固定
	for i in range(6):
		var old_btn = parent.get_node_or_null("buffselectbutton" + str(i))
		if old_btn:
			old_btn.visible = false

	# 前に進むボタン（ショップ枠 y=896 よりさらに下、空いている下部余白 x: 710..1210, y: 974..1050 に配置）
	var sc_btn = get_node_or_null("stagechangeb") as Button
	if sc_btn:
		sc_btn.position = Vector2(710, 974)
		sc_btn.size = Vector2(500, 76)
		sc_btn.custom_minimum_size = Vector2(500, 76)
		sc_btn.z_index = 35
		sc_btn.text = "⚔️ 次の戦いへ進む"
		sc_btn.add_theme_font_size_override("font_size", 26)
		var sc_style = StyleBoxFlat.new()
		sc_style.bg_color = Color(0.18, 0.44, 0.24, 1.0)
		sc_style.border_color = Color(0.95, 0.82, 0.35, 1.0)
		sc_style.set_border_width_all(2)
		sc_style.set_corner_radius_all(10)
		sc_style.shadow_color = Color(0, 0, 0, 0.6)
		sc_style.shadow_size = 6
		sc_btn.add_theme_stylebox_override("normal", sc_style)
		var sc_hov = sc_style.duplicate()
		sc_hov.bg_color = Color(0.24, 0.56, 0.30, 1.0)
		sc_btn.add_theme_stylebox_override("hover", sc_hov)
		var sc_press = sc_style.duplicate()
		sc_press.bg_color = Color(0.12, 0.32, 0.16, 1.0)
		sc_btn.add_theme_stylebox_override("pressed", sc_press)
		sc_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))

	if shop_root_panel != null:
		return

	var jp_font = _get_jp_font()

	# ショップウィンドウ本体 (x: 20..1900, y: 16..896) -> 右端を1880pxまで大幅拡張し、下部の進むボタン(y=924)と被らない独立配置
	shop_root_panel = Panel.new()
	shop_root_panel.name = "ShopAndSkillTreePanel"
	shop_root_panel.position = Vector2(20, 16)
	shop_root_panel.size = Vector2(1880, 880)
	shop_root_panel.z_index = 30
	shop_root_panel.visible = false

	# 重厚なアンティークゴールド外枠 ＆ オブシディアンベルベット調ベース
	var root_style = StyleBoxFlat.new()
	root_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	root_style.border_color = Color(0.85, 0.72, 0.38, 1.0)
	root_style.set_border_width_all(3)
	root_style.set_corner_radius_all(16)
	root_style.shadow_color = Color(0, 0, 0, 0.8)
	root_style.shadow_size = 20
	shop_root_panel.add_theme_stylebox_override("panel", root_style)
	parent.add_child.call_deferred(shop_root_panel)

	# --- 上部ヘッダーバー（ダークブロンズ調） ---
	var header_bg = Panel.new()
	header_bg.position = Vector2(16, 12)
	header_bg.size = Vector2(1848, 76)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.12, 0.15, 0.22, 0.98)
	hdr_style.border_color = Color(0.72, 0.60, 0.34, 0.6)
	hdr_style.set_border_width_all(2)
	hdr_style.set_corner_radius_all(12)
	header_bg.add_theme_stylebox_override("panel", hdr_style)
	shop_root_panel.add_child(header_bg)

	# 左端: 露店タイトルエンブレム
	var shop_emblem = RichTextLabel.new()
	shop_emblem.bbcode_enabled = true
	shop_emblem.scroll_active = false
	shop_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_emblem.position = Vector2(14, 10)
	shop_emblem.size = Vector2(210, 56)
	shop_emblem.add_theme_font_override("normal_font", jp_font)
	shop_emblem.add_theme_font_override("bold_font", jp_font)
	shop_emblem.text = "[center][font_size=19][b][color=#FFD54F]❖ 神秘の露店 ❖[/color][/b][/font_size]\n[font_size=11][color=#B0BEC5]MYSTIC BAZAAR[/color][/font_size][/center]"
	header_bg.add_child(shop_emblem)

	shop_tab_btn = Button.new()
	shop_tab_btn.position = Vector2(236, 10)
	shop_tab_btn.size = Vector2(340, 56)
	shop_tab_btn.text = "🪙 ショップ (コイン強化)"
	shop_tab_btn.add_theme_font_override("font", jp_font)
	shop_tab_btn.add_theme_font_size_override("font_size", 21)
	shop_tab_btn.pressed.connect(func(): _switch_shop_view_mode(0))
	header_bg.add_child(shop_tab_btn)

	skill_tab_btn = Button.new()
	skill_tab_btn.position = Vector2(588, 10)
	skill_tab_btn.size = Vector2(360, 56)
	skill_tab_btn.text = "🌿 スキルツリー (秘薬強化)"
	skill_tab_btn.add_theme_font_override("font", jp_font)
	skill_tab_btn.add_theme_font_size_override("font_size", 21)
	skill_tab_btn.pressed.connect(func(): _switch_shop_view_mode(1))
	header_bg.add_child(skill_tab_btn)

	# 所持コイン＆余剰ポーション表示ボックス（幅拡張に合わせてゆったり配置）
	var coin_box = Panel.new()
	coin_box.position = Vector2(1010, 10)
	coin_box.size = Vector2(400, 56)
	var cbox_style = StyleBoxFlat.new()
	cbox_style.bg_color = Color(0.14, 0.11, 0.04, 0.96)
	cbox_style.border_color = Color(0.90, 0.75, 0.20, 0.8)
	cbox_style.set_border_width_all(2)
	cbox_style.set_corner_radius_all(10)
	coin_box.add_theme_stylebox_override("panel", cbox_style)
	header_bg.add_child(coin_box)

	coin_currency_lbl = RichTextLabel.new()
	coin_currency_lbl.bbcode_enabled = true
	coin_currency_lbl.scroll_active = false
	coin_currency_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	coin_currency_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_currency_lbl.position = Vector2(10, 10)
	coin_currency_lbl.size = Vector2(380, 38)
	coin_currency_lbl.add_theme_font_override("normal_font", jp_font)
	coin_currency_lbl.add_theme_font_override("bold_font", jp_font)
	coin_currency_lbl.add_theme_font_size_override("normal_font_size", 18)
	coin_currency_lbl.add_theme_font_size_override("bold_font_size", 21)
	coin_box.add_child(coin_currency_lbl)

	var potion_box = Panel.new()
	potion_box.position = Vector2(1430, 10)
	potion_box.size = Vector2(400, 56)
	var pbox_style = StyleBoxFlat.new()
	pbox_style.bg_color = Color(0.14, 0.05, 0.13, 0.96)
	pbox_style.border_color = Color(0.90, 0.30, 0.70, 0.8)
	pbox_style.set_border_width_all(2)
	pbox_style.set_corner_radius_all(10)
	potion_box.add_theme_stylebox_override("panel", pbox_style)
	header_bg.add_child(potion_box)

	potion_currency_lbl = RichTextLabel.new()
	potion_currency_lbl.bbcode_enabled = true
	potion_currency_lbl.scroll_active = false
	potion_currency_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	potion_currency_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_currency_lbl.position = Vector2(10, 10)
	potion_currency_lbl.size = Vector2(380, 38)
	potion_currency_lbl.add_theme_font_override("normal_font", jp_font)
	potion_currency_lbl.add_theme_font_override("bold_font", jp_font)
	potion_currency_lbl.add_theme_font_size_override("normal_font_size", 18)
	potion_currency_lbl.add_theme_font_size_override("bold_font_size", 21)
	potion_box.add_child(potion_currency_lbl)

	# --- 1. ショップビュー（コイン購入：獲得スコア・体力強化） ---
	shop_view_container = Control.new()
	shop_view_container.position = Vector2(16, 96)
	shop_view_container.size = Vector2(1848, 770)
	shop_root_panel.add_child(shop_view_container)

	var shop_banner = Label.new()
	shop_banner.position = Vector2(8, 0)
	shop_banner.size = Vector2(1832, 30)
	shop_banner.text = "✨ コインを消費して、各アイテムの獲得スコアや最大HP（体力上限）を永続強化します"
	shop_banner.add_theme_font_override("font", jp_font)
	shop_banner.add_theme_font_size_override("font_size", 20)
	shop_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	shop_view_container.add_child(shop_banner)

	shop_card_refs.clear()
	var card_w: float = 590.0
	var card_h: float = 350.0
	var gap_x: float = 24.0
	var gap_y: float = 18.0
	var start_x: float = (1848.0 - (3.0 * card_w + 2.0 * gap_x)) / 2.0

	for i in range(shop_items.size()):
		var item = shop_items[i]
		var col_idx: int = i % 3
		var row_idx: int = int(i / 3)
		var card = Panel.new()
		card.position = Vector2(start_x + col_idx * (card_w + gap_x), 36.0 + row_idx * (card_h + gap_y))
		card.size = Vector2(card_w, card_h)

		var c_style = StyleBoxFlat.new()
		c_style.bg_color = Color(0.10, 0.12, 0.18, 0.98)
		c_style.border_color = Color(0.75, 0.64, 0.38, 0.90)
		c_style.set_border_width_all(2)
		c_style.set_corner_radius_all(14)
		c_style.shadow_color = Color(0, 0, 0, 0.5)
		c_style.shadow_size = 10
		card.add_theme_stylebox_override("panel", c_style)
		shop_view_container.add_child(card)

		# カード上部ヘッダーリボン（種別＆レベルバッジ）
		var header_ribbon = Panel.new()
		header_ribbon.position = Vector2(0, 0)
		header_ribbon.size = Vector2(card_w, 40)
		var hr_style = StyleBoxFlat.new()
		hr_style.bg_color = Color(0.14, 0.17, 0.25, 0.98)
		hr_style.border_color = item["color"].darkened(0.4)
		hr_style.set_border_width_all(1)
		hr_style.corner_radius_top_left = 14
		hr_style.corner_radius_top_right = 14
		header_ribbon.add_theme_stylebox_override("panel", hr_style)
		card.add_child(header_ribbon)

		var sub_lbl = Label.new()
		sub_lbl.position = Vector2(18, 8)
		sub_lbl.size = Vector2(300, 26)
		sub_lbl.text = "◆ %s ◆" % item.get("subtitle", "ステータス強化")
		sub_lbl.add_theme_font_override("font", jp_font)
		sub_lbl.add_theme_font_size_override("font_size", 16)
		sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		header_ribbon.add_child(sub_lbl)

		var lvl_badge = Label.new()
		lvl_badge.position = Vector2(card_w - 140, 6)
		lvl_badge.size = Vector2(124, 28)
		lvl_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lvl_badge.add_theme_font_override("font", jp_font)
		lvl_badge.add_theme_font_size_override("font_size", 22)
		lvl_badge.add_theme_color_override("font_color", Color("#FFD700"))
		lvl_badge.add_theme_constant_override("outline_size", 4)
		lvl_badge.add_theme_color_override("font_outline_color", Color.BLACK)
		header_ribbon.add_child(lvl_badge)

		# アイコンメダリオン枠
		var icon_frame = Panel.new()
		icon_frame.position = Vector2(20, 54)
		icon_frame.size = Vector2(76, 76)
		var if_style = StyleBoxFlat.new()
		if_style.bg_color = item["color"].darkened(0.75)
		if_style.border_color = item["color"]
		if_style.set_border_width_all(2)
		if_style.set_corner_radius_all(12)
		icon_frame.add_theme_stylebox_override("panel", if_style)
		card.add_child(icon_frame)

		var tex_rect = TextureRect.new()
		tex_rect.position = Vector2(8, 8)
		tex_rect.size = Vector2(60, 60)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(item.get("icon_path", "")):
			tex_rect.texture = load(item["icon_path"])
		icon_frame.add_child(tex_rect)

		var title_lbl = Label.new()
		title_lbl.position = Vector2(108, 52)
		title_lbl.size = Vector2(400, 40)
		title_lbl.text = item["name"]
		title_lbl.add_theme_font_override("font", jp_font)
		title_lbl.add_theme_font_size_override("font_size", 28)
		title_lbl.add_theme_color_override("font_color", item["color"].lightened(0.25))
		title_lbl.add_theme_constant_override("outline_size", 5)
		title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		card.add_child(title_lbl)

		var desc_lbl = Label.new()
		desc_lbl.position = Vector2(108, 94)
		desc_lbl.size = Vector2(400, 44)
		desc_lbl.text = item["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_override("font", jp_font)
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		card.add_child(desc_lbl)

		var stat_box = Panel.new()
		stat_box.position = Vector2(18, 146)
		stat_box.size = Vector2(494, 114)
		var sb_style = StyleBoxFlat.new()
		sb_style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
		sb_style.border_color = Color(0.24, 0.30, 0.42, 0.70)
		sb_style.set_border_width_all(1)
		sb_style.set_corner_radius_all(10)
		stat_box.add_theme_stylebox_override("panel", sb_style)
		card.add_child(stat_box)

		var stat_lbl = RichTextLabel.new()
		stat_lbl.bbcode_enabled = true
		stat_lbl.scroll_active = false
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_lbl.position = Vector2(14, 10)
		stat_lbl.size = Vector2(466, 94)
		stat_lbl.add_theme_font_override("normal_font", jp_font)
		stat_lbl.add_theme_font_override("bold_font", jp_font)
		stat_lbl.add_theme_font_size_override("normal_font_size", 19)
		stat_lbl.add_theme_font_size_override("bold_font_size", 20)
		stat_box.add_child(stat_lbl)

		var buy_btn = Button.new()
		buy_btn.position = Vector2(18, 274)
		buy_btn.size = Vector2(card_w - 36 - 96, 58)
		buy_btn.add_theme_font_override("font", jp_font)
		buy_btn.add_theme_font_size_override("font_size", 22)
		buy_btn.add_theme_constant_override("outline_size", 5)
		buy_btn.add_theme_color_override("font_outline_color", Color.BLACK)
		var slot_idx = i
		buy_btn.pressed.connect(func(): _purchase_buff(slot_idx))
		card.add_child(buy_btn)

		# 🛠️ デバッグ即時レベルアップボタン（コイン不要）
		var dbg_buff_btn = Button.new()
		dbg_buff_btn.name = "DebugBuffLevelUpBtn_%d" % i
		dbg_buff_btn.text = "🛠️+Lv"
		dbg_buff_btn.position = Vector2(card_w - 18 - 88, 274)
		dbg_buff_btn.size = Vector2(88, 58)
		dbg_buff_btn.add_theme_font_override("font", jp_font)
		dbg_buff_btn.add_theme_font_size_override("font_size", 18)
		var dbg_b_st = StyleBoxFlat.new()
		dbg_b_st.bg_color = Color(0.10, 0.26, 0.36, 0.95)
		dbg_b_st.border_color = Color(0.25, 0.85, 1.0, 0.9)
		dbg_b_st.set_border_width_all(2)
		dbg_b_st.set_corner_radius_all(8)
		dbg_buff_btn.add_theme_stylebox_override("normal", dbg_b_st)
		var dbg_b_hov = dbg_b_st.duplicate()
		dbg_b_hov.bg_color = Color(0.16, 0.38, 0.52, 1.0)
		dbg_buff_btn.add_theme_stylebox_override("hover", dbg_b_hov)
		dbg_buff_btn.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
		dbg_buff_btn.pressed.connect(func(): debug_level_up_shop_buff(slot_idx))
		card.add_child(dbg_buff_btn)

		shop_card_refs.append({
			"card": card,
			"lvl_badge": lvl_badge,
			"stat_lbl": stat_lbl,
			"buy_btn": buy_btn
		})

	# --- 2. スキルツリービュー（余剰ポーション使用：スキル獲得・強化） ---
	skill_tree_container = Control.new()
	skill_tree_container.position = Vector2(16, 96)
	skill_tree_container.size = Vector2(1848, 770)
	skill_tree_container.visible = false
	shop_root_panel.add_child(skill_tree_container)

	rebuild_skill_tree_ui()
	_switch_shop_view_mode(0)

func _get_relic_manager() -> Node:
	if relic_manager_ref != null and is_instance_valid(relic_manager_ref):
		return relic_manager_ref
	var p = get_parent()
	if p:
		var rm = p.get_node_or_null("RelicManager")
		if rm: return rm
		rm = p.find_child("RelicManager", true, false)
		if rm: return rm
	if is_inside_tree() and get_tree() != null:
		var root = get_tree().get_root()
		if root:
			var rm = root.find_child("RelicManager", true, false)
			if rm: return rm
	return null

var _rendered_skill_category: String = "__unset__"
var chosen_category: String = ""

func on_element_category_chosen(cat_key: String) -> void:
	chosen_category = cat_key
	rebuild_skill_tree_ui()
	_setup_elem_status_panel(cat_key)
	update_elem_labels()

func set_chosen_category(cat_key: String) -> void:
	on_element_category_chosen(cat_key)

## 選択された属性カテゴリーに応じてスキルツリーUIを動的に構築
func rebuild_skill_tree_ui() -> void:
	if skill_tree_container == null or not is_instance_valid(skill_tree_container):
		return

	var jp_font = _get_jp_font()
	var rm = _get_relic_manager()
	var cat_key: String = ""
	if rm and rm.has_method("get_chosen_element_category"):
		cat_key = rm.get_chosen_element_category()
	if cat_key == "":
		cat_key = chosen_category

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
		var c_w = 580.0
		var c_gap = 36.0
		var start_x = (1848.0 - (3.0 * c_w + 2.0 * c_gap)) / 2.0
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

			# 🛠️ デバッグ系統即時解放ボタン
			var c_dbg_btn = Button.new()
			c_dbg_btn.text = "🛠️ %s系統を選択 (デバッグ)" % c_info["title"]
			c_dbg_btn.position = Vector2(24, 510)
			c_dbg_btn.size = Vector2(c_w - 48, 48)
			c_dbg_btn.add_theme_font_override("font", jp_font)
			c_dbg_btn.add_theme_font_size_override("font_size", 17)
			var c_dbg_st = StyleBoxFlat.new()
			c_dbg_st.bg_color = Color(0.12, 0.28, 0.38, 0.95)
			c_dbg_st.border_color = Color(0.3, 0.85, 1.0, 0.9)
			c_dbg_st.set_border_width_all(2)
			c_dbg_st.set_corner_radius_all(10)
			c_dbg_btn.add_theme_stylebox_override("normal", c_dbg_st)
			var chosen_k_cap = c_k
			c_dbg_btn.pressed.connect(func(): on_element_category_chosen(chosen_k_cap))
			card.add_child(c_dbg_btn)
		return

	# カテゴリー選択済みの場合：選択されたカテゴリーのツリーを表示！
	var cat_data = CATEGORY_TREE_DEFS[cat_key]
	var banner = Label.new()
	banner.position = Vector2(8, 0)
	banner.size = Vector2(980, 32)
	banner.text = cat_data["banner"]

	# 🛠️ デバッグクイックバー
	var dbg_bar = HBoxContainer.new()
	dbg_bar.position = Vector2(1000, 0)
	dbg_bar.size = Vector2(840, 32)
	dbg_bar.add_theme_constant_override("separation", 10)
	skill_tree_container.add_child(dbg_bar)

	var btn_res = Button.new()
	btn_res.text = "🛠️ 資源+10万 (F6)"
	btn_res.add_theme_font_override("font", jp_font)
	btn_res.add_theme_font_size_override("font_size", 14)
	btn_res.pressed.connect(func(): debug_add_resources(100000))
	dbg_bar.add_child(btn_res)

	var btn_lv5 = Button.new()
	btn_lv5.text = "⚡ 全スキルLv.5 (F7)"
	btn_lv5.add_theme_font_override("font", jp_font)
	btn_lv5.add_theme_font_size_override("font_size", 14)
	btn_lv5.pressed.connect(func(): debug_set_all_skills_level(5))
	dbg_bar.add_child(btn_lv5)

	var btn_lv20 = Button.new()
	btn_lv20.text = "👑 全スキルLv.20 (F8)"
	btn_lv20.add_theme_font_override("font", jp_font)
	btn_lv20.add_theme_font_size_override("font_size", 14)
	btn_lv20.pressed.connect(func(): debug_set_all_skills_level(20))
	dbg_bar.add_child(btn_lv20)
	banner.add_theme_font_override("font", jp_font)
	banner.add_theme_font_size_override("font_size", 21)
	banner.add_theme_color_override("font_color", Color(0.95, 0.65, 1.0))
	skill_tree_container.add_child(banner)

	var branch_titles: Array = cat_data["branch_titles"]
	var branch_colors: Array = cat_data["branch_colors"]
	var num_branches: int = branch_titles.size()

	var col_gap: float = 24.0 if num_branches > 3 else 36.0
	var total_w: float = 1800.0
	var col_w: float = (total_w - float(num_branches - 1) * col_gap) / float(num_branches)
	var offset_x = (1848.0 - (float(num_branches) * col_w + float(num_branches - 1) * col_gap)) / 2.0

	for b in range(num_branches):
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

	# 1属性につき1つの大型マスタースキルカード（全10スキル・重厚RPGレイアウト）
	for s_idx in range(skill_tree_items.size()):
		var s_item = skill_tree_items[s_idx]
		if s_item.get("category", "") != cat_key:
			continue

		var branch: int = int(s_item["branch"])
		var nx: float = offset_x + branch * (col_w + col_gap)
		var ny: float = 84.0

		var node_card = Panel.new()
		node_card.position = Vector2(nx, ny)
		node_card.size = Vector2(col_w, 670.0)
		node_card.name = "MasterSkillCard_%s" % s_item["id"]
		skill_tree_container.add_child(node_card)

		# 1. ヘッダーアイコン枠
		var badge = Panel.new()
		badge.position = Vector2(14, 14)
		badge.size = Vector2(56, 56)
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = s_item["color"].darkened(0.55)
		b_style.border_color = s_item["color"]
		b_style.set_border_width_all(2)
		b_style.set_corner_radius_all(14)
		badge.add_theme_stylebox_override("panel", b_style)
		node_card.add_child(badge)

		var badge_lbl = Label.new()
		badge_lbl.size = Vector2(56, 56)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_lbl.text = s_item.get("short_label", "技")
		badge_lbl.add_theme_font_override("font", jp_font)
		badge_lbl.add_theme_font_size_override("font_size", 30)
		badge_lbl.add_theme_color_override("font_color", Color.WHITE)
		badge_lbl.add_theme_constant_override("outline_size", 5)
		badge_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_child(badge_lbl)

		# スキル名
		var s_title = Label.new()
		s_title.position = Vector2(78, 12)
		s_title.size = Vector2(col_w - 92, 30)
		s_title.text = s_item["name"]
		s_title.add_theme_font_override("font", jp_font)
		s_title.add_theme_font_size_override("font_size", 23)
		s_title.add_theme_color_override("font_color", s_item["color"].lightened(0.28))
		s_title.add_theme_constant_override("outline_size", 5)
		s_title.add_theme_color_override("font_outline_color", Color.BLACK)
		node_card.add_child(s_title)

		# 盤面マッチ条件ピル
		var recipe_pill = Panel.new()
		recipe_pill.position = Vector2(78, 44)
		recipe_pill.size = Vector2(col_w - 92, 26)
		var rp_style = StyleBoxFlat.new()
		rp_style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		rp_style.border_color = Color(0.85, 0.75, 0.35, 0.7)
		rp_style.set_border_width_all(1)
		rp_style.set_corner_radius_all(6)
		recipe_pill.add_theme_stylebox_override("panel", rp_style)
		node_card.add_child(recipe_pill)

		var recipe_lbl = Label.new()
		recipe_lbl.position = Vector2(6, 1)
		recipe_lbl.size = Vector2(col_w - 104, 24)
		recipe_lbl.text = "⚡ 盤面生成: %s" % str(s_item.get("match_recipe", ""))
		recipe_lbl.add_theme_font_override("font", jp_font)
		recipe_lbl.add_theme_font_size_override("font_size", 14)
		recipe_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		recipe_pill.add_child(recipe_lbl)

		# 2. レベル状態表示 & レベルプログレスバー
		var s_lvl = Label.new()
		s_lvl.position = Vector2(14, 76)
		s_lvl.size = Vector2(col_w - 28, 22)
		s_lvl.add_theme_font_override("font", jp_font)
		s_lvl.add_theme_font_size_override("font_size", 16)
		s_lvl.add_theme_constant_override("outline_size", 4)
		s_lvl.add_theme_color_override("font_outline_color", Color.BLACK)
		node_card.add_child(s_lvl)

		var progress_bar = ProgressBar.new()
		progress_bar.position = Vector2(14, 100)
		progress_bar.size = Vector2(col_w - 28, 12)
		progress_bar.min_value = 0.0
		progress_bar.max_value = 20.0
		progress_bar.show_percentage = false
		var pb_bg = StyleBoxFlat.new()
		pb_bg.bg_color = Color(0.05, 0.06, 0.09, 0.9)
		pb_bg.set_corner_radius_all(6)
		progress_bar.add_theme_stylebox_override("background", pb_bg)
		var pb_fill = StyleBoxFlat.new()
		pb_fill.bg_color = s_item["color"]
		pb_fill.set_corner_radius_all(6)
		progress_bar.add_theme_stylebox_override("fill", pb_fill)
		node_card.add_child(progress_bar)

		# 3. 基礎効果 & 成長プレビュー枠
		var desc_panel = Panel.new()
		desc_panel.position = Vector2(14, 118)
		desc_panel.size = Vector2(col_w - 28, 120)
		var dp_style = StyleBoxFlat.new()
		dp_style.bg_color = Color(0.06, 0.08, 0.12, 0.75)
		dp_style.border_color = Color(0.25, 0.30, 0.40, 0.5)
		dp_style.set_border_width_all(1)
		dp_style.set_corner_radius_all(8)
		desc_panel.add_theme_stylebox_override("panel", dp_style)
		node_card.add_child(desc_panel)

		var s_desc = RichTextLabel.new()
		s_desc.bbcode_enabled = true
		s_desc.scroll_active = false
		s_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_desc.position = Vector2(8, 6)
		s_desc.size = Vector2(col_w - 44, 108)
		s_desc.add_theme_font_override("normal_font", jp_font)
		s_desc.add_theme_font_override("bold_font", jp_font)
		s_desc.add_theme_font_size_override("normal_font_size", 14)
		s_desc.add_theme_font_size_override("bold_font_size", 14)
		desc_panel.add_child(s_desc)

		# 4. 【第1覚醒 (Lv.5)】タロット進化スロット
		var mid_evo_panel = Panel.new()
		mid_evo_panel.position = Vector2(14, 246)
		mid_evo_panel.size = Vector2(col_w - 28, 156)
		node_card.add_child(mid_evo_panel)

		var mid_evo_lbl = RichTextLabel.new()
		mid_evo_lbl.bbcode_enabled = true
		mid_evo_lbl.scroll_active = false
		mid_evo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid_evo_lbl.position = Vector2(10, 8)
		mid_evo_lbl.size = Vector2(col_w - 48, 140)
		mid_evo_lbl.add_theme_font_override("normal_font", jp_font)
		mid_evo_lbl.add_theme_font_override("bold_font", jp_font)
		mid_evo_panel.add_child(mid_evo_lbl)

		# 5. 【最終神格化 (Lv.20)】タロット極限覚醒スロット
		var final_evo_panel = Panel.new()
		final_evo_panel.position = Vector2(14, 410)
		final_evo_panel.size = Vector2(col_w - 28, 170)
		node_card.add_child(final_evo_panel)

		var final_evo_lbl = RichTextLabel.new()
		final_evo_lbl.bbcode_enabled = true
		final_evo_lbl.scroll_active = false
		final_evo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		final_evo_lbl.position = Vector2(10, 8)
		final_evo_lbl.size = Vector2(col_w - 48, 154)
		final_evo_lbl.add_theme_font_override("normal_font", jp_font)
		final_evo_lbl.add_theme_font_override("bold_font", jp_font)
		final_evo_panel.add_child(final_evo_lbl)

		# 6. 下部アクション操作部（強化ボタン & デバッグレベルアップ）
		var s_btn = Button.new()
		s_btn.position = Vector2(14, 592)
		s_btn.size = Vector2(col_w - 28 - 96, 62)
		s_btn.add_theme_font_override("font", jp_font)
		s_btn.add_theme_font_size_override("font_size", 18)
		s_btn.add_theme_constant_override("outline_size", 4)
		s_btn.add_theme_color_override("font_outline_color", Color.BLACK)
		var bind_idx = s_idx
		s_btn.pressed.connect(func(): _purchase_skill(bind_idx))
		node_card.add_child(s_btn)

		var dbg_btn = Button.new()
		dbg_btn.name = "DebugLevelUpBtn_%d" % s_idx
		dbg_btn.text = "🛠️+Lv"
		dbg_btn.position = Vector2(col_w - 14 - 86, 592)
		dbg_btn.size = Vector2(86, 62)
		dbg_btn.add_theme_font_override("font", jp_font)
		dbg_btn.add_theme_font_size_override("font_size", 16)
		var dbg_st = StyleBoxFlat.new()
		dbg_st.bg_color = Color(0.10, 0.26, 0.36, 0.95)
		dbg_st.border_color = Color(0.25, 0.85, 1.0, 0.9)
		dbg_st.set_border_width_all(2)
		dbg_st.set_corner_radius_all(8)
		dbg_btn.add_theme_stylebox_override("normal", dbg_st)
		var dbg_hov = dbg_st.duplicate()
		dbg_hov.bg_color = Color(0.16, 0.38, 0.52, 1.0)
		dbg_btn.add_theme_stylebox_override("hover", dbg_hov)
		dbg_btn.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
		dbg_btn.pressed.connect(func(): debug_level_up_skill(bind_idx))
		node_card.add_child(dbg_btn)

		var card_skill_id = s_item["id"]
		node_card.mouse_filter = Control.MOUSE_FILTER_PASS
		node_card.mouse_entered.connect(func():
			var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
			if r_ui and r_ui.has_method("show_custom_tooltip"):
				var c_lvl = int(s_item.get("level", 0))
				var m_lvl = int(s_item.get("max_level", 20))
				var col_hex = s_item.get("color", Color.WHITE).to_html(false)
				var t_str = "[b][color=#%s]🌿 %s (Lv%d/%d)[/color][/b]" % [col_hex, s_item.get("name", "Skill"), c_lvl, m_lvl]
				var d_arr: Array = s_item.get("desc_lv", [])
				var cur_d = d_arr[clampi(c_lvl - 1, 0, d_arr.size() - 1)] if c_lvl > 0 and not d_arr.is_empty() else (d_arr[0] if not d_arr.is_empty() else "")
				var next_d = d_arr[clampi(c_lvl, 0, d_arr.size() - 1)] if c_lvl < m_lvl and not d_arr.is_empty() else ""
				var recipe_str: String = str(s_item.get("match_recipe", ""))
				var recipe_info: String = "[font_size=20][b][color=#FFD54F]⚡【盤面生成マッチ条件】: %s[/color][/b][/font_size]\n\n" % recipe_str if recipe_str != "" else ""
				var d_str = ""
				if c_lvl >= m_lvl:
					d_str = recipe_info + "[font_size=19][color=#FFD700]【最大レベル】[/color]\n%s[/font_size]" % cur_d
				elif c_lvl == 0:
					d_str = recipe_info + "[font_size=19][color=#AAAAAA]【未習得】[/color]\n習得効果 (Lv1): %s[/font_size]" % next_d
				else:
					d_str = recipe_info + "[font_size=19]現在 (Lv%d): %s\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [c_lvl, cur_d, c_lvl + 1, next_d]
				var evo_mid = get_chosen_evolution(card_skill_id, 5)
				var evo_final = get_chosen_evolution(card_skill_id, 20)
				if evo_mid != "" or evo_final != "":
					d_str += "\n\n[color=#FFE082]"
					if evo_mid != "":
						var mid_name = _get_evolution_name(card_skill_id, 5, evo_mid)
						d_str += "【第1進化: %s】\n" % mid_name
					if evo_final != "":
						var final_name = _get_evolution_name(card_skill_id, 20, evo_final)
						d_str += "【最終進化: %s】\n" % final_name
					d_str += "[/color]"
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
			"progress_bar": progress_bar,
			"s_desc": s_desc,
			"mid_evo_panel": mid_evo_panel,
			"mid_evo_lbl": mid_evo_lbl,
			"final_evo_panel": final_evo_panel,
			"final_evo_lbl": final_evo_lbl,
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
			var cur_cat: String = ""
			if rm and rm.has_method("get_chosen_element_category"):
				cur_cat = rm.get_chosen_element_category()
			if cur_cat == "":
				cur_cat = chosen_category
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

	# タブボタンのスタイル更新（アンティークゴールドとアメジストの職人仕上げ）
	if shop_tab_btn and skill_tab_btn:
		var active_shop = (current_view_mode == 0)
		var st_shop = StyleBoxFlat.new()
		st_shop.bg_color = Color(0.26, 0.20, 0.08, 1.0) if active_shop else Color(0.09, 0.11, 0.16, 0.85)
		st_shop.border_color = Color(0.95, 0.82, 0.35, 1.0) if active_shop else Color(0.35, 0.38, 0.48, 0.6)
		st_shop.set_border_width_all(2 if active_shop else 1)
		st_shop.set_corner_radius_all(10)
		shop_tab_btn.add_theme_stylebox_override("normal", st_shop)
		var st_shop_hov = st_shop.duplicate()
		st_shop_hov.bg_color = Color(0.32, 0.25, 0.10, 1.0)
		shop_tab_btn.add_theme_stylebox_override("hover", st_shop_hov)
		shop_tab_btn.add_theme_color_override("font_color", Color("#FFE082") if active_shop else Color(0.70, 0.75, 0.85))

		var st_skill = StyleBoxFlat.new()
		st_skill.bg_color = Color(0.24, 0.08, 0.22, 1.0) if not active_shop else Color(0.09, 0.11, 0.16, 0.85)
		st_skill.border_color = Color(0.95, 0.45, 0.80, 1.0) if not active_shop else Color(0.35, 0.38, 0.48, 0.6)
		st_skill.set_border_width_all(2 if not active_shop else 1)
		st_skill.set_corner_radius_all(10)
		skill_tab_btn.add_theme_stylebox_override("normal", st_skill)
		var st_skill_hov = st_skill.duplicate()
		st_skill_hov.bg_color = Color(0.30, 0.12, 0.28, 1.0)
		skill_tab_btn.add_theme_stylebox_override("hover", st_skill_hov)
		skill_tab_btn.add_theme_color_override("font_color", Color("#FF99DD") if not active_shop else Color(0.70, 0.75, 0.85))

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
		var max_lvl: int = int(s_item.get("max_level", 20))
		var is_max: bool = (cur_lvl >= max_lvl)
		var cost_val: int = int(s_item["cost"])

		var card_style = StyleBoxFlat.new()
		if cur_lvl > 0:
			card_style.bg_color = Color(0.11, 0.14, 0.22, 0.98)
			card_style.border_color = s_item["color"] if not is_max else Color("#FFD700")
			card_style.set_border_width_all(2)
			card_style.border_width_left = 6
		else:
			card_style.bg_color = Color(0.08, 0.09, 0.14, 0.95)
			card_style.border_color = s_item["color"].darkened(0.35)
			card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(14)
		s_ref["card"].add_theme_stylebox_override("panel", card_style)

		# レベル表示
		if is_max:
			s_ref["s_lvl"].text = "★ Lv.%d / %d (MAX 神格到達)" % [cur_lvl, max_lvl]
			s_ref["s_lvl"].add_theme_color_override("font_color", Color("#FFD700"))
		elif cur_lvl > 0:
			s_ref["s_lvl"].text = "習得済: Lv.%d / %d" % [cur_lvl, max_lvl]
			s_ref["s_lvl"].add_theme_color_override("font_color", Color("#00E676"))
		else:
			s_ref["s_lvl"].text = "未習得 (ポーションで解放可能)"
			s_ref["s_lvl"].add_theme_color_override("font_color", Color("#80D8FF"))

		# プログレスバー
		var pbar: ProgressBar = s_ref.get("progress_bar")
		if pbar:
			pbar.value = cur_lvl

		# 基礎効果説明
		var desc_arr: Array = s_item.get("desc_lv", [])
		if is_max:
			s_ref["s_desc"].text = "[color=#FFD700][b]【最大神格強化】[/b][/color]\n%s" % (desc_arr[clampi(max_lvl - 1, 0, desc_arr.size() - 1)] if not desc_arr.is_empty() else "")
		elif cur_lvl == 0:
			s_ref["s_desc"].text = "[color=#B0BEC5]解放効果 (Lv.1):[/color]\n%s" % (desc_arr[0] if not desc_arr.is_empty() else "")
		else:
			var cur_txt = desc_arr[clampi(cur_lvl - 1, 0, desc_arr.size() - 1)] if not desc_arr.is_empty() else ""
			var next_txt = desc_arr[clampi(cur_lvl, 0, desc_arr.size() - 1)] if not desc_arr.is_empty() else ""
			s_ref["s_desc"].text = "[color=#B0BEC5]現在 (Lv.%d):[/color] %s\n[color=#FFD700]次 (Lv.%d):[/color] %s" % [
				cur_lvl, cur_txt, cur_lvl + 1, next_txt
			]
		var evo_mid = get_chosen_evolution(s_item["id"], 5)
		var evo_final = get_chosen_evolution(s_item["id"], 20)
		if evo_mid != "" or evo_final != "":
			var evo_info_str = "\n[color=#FFE082]"
			if evo_mid != "":
				var mid_name = _get_evolution_name(s_item["id"], 5, evo_mid)
				evo_info_str += "【第1進化: %s】 " % mid_name
			if evo_final != "":
				var final_name = _get_evolution_name(s_item["id"], 20, evo_final)
				evo_info_str += "【最終進化: %s】" % final_name
			evo_info_str += "[/color]"
			s_ref["s_desc"].text += evo_info_str

		# 第1覚醒 (Lv.5) スロット更新
		var mid_panel: Panel = s_ref.get("mid_evo_panel")
		var mid_lbl: RichTextLabel = s_ref.get("mid_evo_lbl")
		if mid_panel and mid_lbl:
			var mp_st = StyleBoxFlat.new()
			mp_st.set_corner_radius_all(10)
			mp_st.set_border_width_all(2)
			if evo_mid != "":
				var mid_data = get_evolution_data(s_item["id"], 5, evo_mid)
				mp_st.bg_color = Color(0.08, 0.16, 0.25, 0.92)
				mp_st.border_color = Color(0.3, 0.85, 1.0, 0.95)
				mid_lbl.text = "[b][color=#80D8FF]✨【第1覚醒・アルカナ %s: %s】[/color][/b] [color=#B0BEC5](%s)[/color]\n[font_size=13][color=#E0F7FA]%s[/color][/font_size]" % [
					mid_data.get("numeral", "Ⅰ"), mid_data.get("name", evo_mid), mid_data.get("role", "特性"), mid_data.get("desc", "")
				]
			else:
				mp_st.bg_color = Color(0.06, 0.07, 0.10, 0.65)
				mp_st.border_color = Color(0.25, 0.28, 0.35, 0.45)
				mid_lbl.text = "[b][color=#78909C]🔒 【第1覚醒】スキルLv.5 到達で解放[/color][/b]\n[font_size=13][color=#546E7A]Lv.5到達時にタロット大アルカナ（3択）が出現し、戦術の方向性を決定づける特性を選びます。[/color][/font_size]"
			mid_panel.add_theme_stylebox_override("panel", mp_st)

		# 最終神格化 (Lv.20) スロット更新
		var final_panel: Panel = s_ref.get("final_evo_panel")
		var final_lbl: RichTextLabel = s_ref.get("final_evo_lbl")
		if final_panel and final_lbl:
			var fp_st = StyleBoxFlat.new()
			fp_st.set_corner_radius_all(10)
			fp_st.set_border_width_all(2)
			if evo_final != "":
				var final_data = get_evolution_data(s_item["id"], 20, evo_final)
				fp_st.bg_color = Color(0.20, 0.16, 0.05, 0.95)
				fp_st.border_color = Color(1.0, 0.85, 0.2, 1.0)
				final_lbl.text = "[b][color=#FFD700]👑【最終神格・極限アルカナ %s: %s】[/color][/b] [color=#FFE082](%s)[/color]\n[font_size=13][color=#FFF8E1]%s[/color][/font_size]" % [
					final_data.get("numeral", "Ⅰ"), final_data.get("name", evo_final), final_data.get("role", "究極神格"), final_data.get("desc", "")
				]
			else:
				fp_st.bg_color = Color(0.06, 0.07, 0.10, 0.65)
				fp_st.border_color = Color(0.25, 0.28, 0.35, 0.45)
				var hint_text = "※氷属性：絶対零度による敵行動の完全スキップ等、究極神格特性が解禁されます。" if s_item["id"].begins_with("ice") else "スキルLv.20到達時に極限神格アルカナ（3択）が解放されます。"
				final_lbl.text = "[b][color=#78909C]🔒 【極限神格化】スキルLv.20 到達で解放[/color][/b]\n[font_size=13][color=#546E7A]%s[/color][/font_size]" % hint_text
			final_panel.add_theme_stylebox_override("panel", fp_st)

		# 強化ボタン更新
		var s_btn: Button = s_ref["s_btn"]
		var can_upgrade: bool = (not is_max) and (potions >= cost_val)
		s_btn.disabled = not can_upgrade

		var sb_style = StyleBoxFlat.new()
		sb_style.set_corner_radius_all(8)
		sb_style.set_border_width_all(2)

		if is_max:
			s_btn.text = "★ MAX (Lv.%d) 神格達成 ★" % max_lvl
			sb_style.bg_color = Color(0.28, 0.22, 0.06, 0.95)
			sb_style.border_color = Color("#FFD700")
			s_btn.add_theme_color_override("font_color", Color("#FFD700"))
		else:
			var act_word = "スキル解放" if cur_lvl == 0 else ("Lv.%dへ強化" % (cur_lvl + 1))
			if cur_lvl == 4:
				act_word = "第1覚醒・中間進化 (Lv.5)"
			elif cur_lvl == 19:
				act_word = "極限神格化・最終進化 (Lv.20)"
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
			sb_hover.bg_color = Color(0.42, 0.14, 0.36, 1.0)
		s_btn.add_theme_stylebox_override("hover", sb_hover)
		s_btn.add_theme_stylebox_override("disabled", sb_style)

## スコアポップアップのアニメーションおよびフェード処理
func _update_popup_labels() -> void:
	if labelarr.is_empty():
		return
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

## スキルツリーの解放・強化完了処理
func _complete_skill_upgrade(skill_idx: int, new_lvl: int, chosen_evo_id: String = "") -> void:
	if skill_idx < 0 or skill_idx >= skill_tree_items.size():
		return
	var s_item = skill_tree_items[skill_idx]
	var cost_ref: int = int(s_item["cost"])
	var parent = get_parent()
	divscore[PieceType.POTION] = maxi(0, int(divscore[PieceType.POTION]) - cost_ref)
	s_item["level"] = new_lvl
	s_item["cost"] = int(cost_ref * 1.30)

	if chosen_evo_id != "":
		choose_skill_evolution(s_item["id"], new_lvl, chosen_evo_id)

	var sp_type: int = int(s_item["sp_type"])
	var pb = _get_puzzle_board()
	if pb and "special_levels" in pb:
		pb.special_levels[sp_type] = new_lvl
		if sp_type == 9 and pb.has_method("_plant_sprout_on_board"):
			pb._plant_sprout_on_board()

	if s_item["id"] == "bomb":
		bomb_buff_level = new_lvl

	emit_signal("skill_upgraded", s_item["id"], sp_type, new_lvl)

	var sound = null
	if chosen_evo_id != "":
		sound = parent.get_node_or_null("stagekirikae") if parent else null
	if sound == null:
		sound = parent.get_node_or_null("coinsound") if parent else null
	if sound:
		sound.play()
	_update_buff_button_labels()

## タロットカード風の正当進化モーダルUIの表示
func _open_tarot_evolution_modal(skill_idx: int, milestone_lvl: int) -> void:
	if skill_idx < 0 or skill_idx >= skill_tree_items.size():
		return
	var s_item = skill_tree_items[skill_idx]
	var choices = get_evolution_choices(s_item["id"], milestone_lvl)
	if choices.is_empty():
		_complete_skill_upgrade(skill_idx, milestone_lvl, "")
		return

	if tarot_modal_panel and is_instance_valid(tarot_modal_panel):
		tarot_modal_panel.queue_free()
		tarot_modal_panel = null

	var modal = Panel.new()
	modal.name = "TarotEvolutionModal"
	tarot_modal_panel = modal
	modal.position = Vector2(0, 0)
	modal.size = Vector2(1880, 880)
	modal.z_index = 25

	var bg_st = StyleBoxFlat.new()
	bg_st.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	bg_st.border_color = Color(0.85, 0.72, 0.38, 0.9)
	bg_st.set_border_width_all(2)
	bg_st.set_corner_radius_all(14)
	modal.add_theme_stylebox_override("panel", bg_st)

	if shop_root_panel:
		shop_root_panel.add_child(modal)
	else:
		add_child(modal)

	# Close / Cancel button at top-right
	var close_btn = Button.new()
	close_btn.name = "ModalCloseBtn"
	close_btn.text = "✕ キャンセル"
	close_btn.position = Vector2(1720, 24)
	close_btn.size = Vector2(130, 40)
	var cl_st = StyleBoxFlat.new()
	cl_st.bg_color = Color(0.18, 0.12, 0.14, 0.9)
	cl_st.border_color = Color(0.85, 0.4, 0.4, 0.8)
	cl_st.set_border_width_all(1)
	cl_st.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", cl_st)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	close_btn.pressed.connect(func():
		if is_instance_valid(modal):
			modal.queue_free()
		tarot_modal_panel = null
	)
	modal.add_child(close_btn)

	# Header Title & Subtitle
	var title_lbl = RichTextLabel.new()
	title_lbl.name = "ModalTitle"
	title_lbl.bbcode_enabled = true
	title_lbl.position = Vector2(40, 30)
	title_lbl.size = Vector2(1460, 90)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var milestone_title = "【第1覚醒・中間進化】" if milestone_lvl == 5 else "【極限神格化・最終進化】"
	title_lbl.text = "[center][b][color=#FFD54F][font_size=32]✦ 運命のアルカナ・スキルの正当進化 ✦[/font_size][/color][/b]\n"
	title_lbl.text += "[color=#B0BEC5][font_size=18]スキル「[color=#FFE082]%s[/color]」が[color=#FFD700]%s[/color]に到達しました。歩むべき特性の進化を選択してください。[/font_size][/color][/center]" % [
		s_item.get("name", ""), milestone_title
	]
	modal.add_child(title_lbl)

	# Cards HBox Container
	var card_count = choices.size()
	var card_w: float = 440.0
	var card_h: float = 640.0
	var spacing: float = 44.0
	var total_w = float(card_count) * card_w + float(card_count - 1) * spacing
	var start_x = (1880.0 - total_w) / 2.0
	var start_y = 150.0

	var el_color = s_item.get("color", Color(0.85, 0.72, 0.38))

	for i in range(card_count):
		var choice = choices[i]
		var c_x = start_x + float(i) * (card_w + spacing)
		var c_y = start_y

		var card = Panel.new()
		card.name = "TarotCard_%d" % i
		card.position = Vector2(c_x, c_y)
		card.size = Vector2(card_w, card_h)

		var card_st = StyleBoxFlat.new()
		card_st.bg_color = Color(0.08, 0.10, 0.16, 0.98)
		card_st.border_color = Color(0.85, 0.72, 0.38, 1.0)
		card_st.set_border_width_all(2)
		card_st.set_corner_radius_all(16)
		card_st.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
		card_st.shadow_size = 8
		card.add_theme_stylebox_override("panel", card_st)
		modal.add_child(card)

		# タロットカードのホバー演出（浮遊リフト＆金枠グロー）
		var card_captured = card
		var normal_st = card_st
		var hov_st = card_st.duplicate()
		hov_st.border_color = Color(1.0, 0.88, 0.45, 1.0)
		hov_st.shadow_size = 14
		hov_st.bg_color = Color(0.10, 0.13, 0.20, 0.98)

		card.mouse_entered.connect(func():
			if is_instance_valid(card_captured):
				card_captured.add_theme_stylebox_override("panel", hov_st)
				var tw = card_captured.create_tween()
				tw.tween_property(card_captured, "position:y", start_y - 10.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
		card.mouse_exited.connect(func():
			if is_instance_valid(card_captured):
				card_captured.add_theme_stylebox_override("panel", normal_st)
				var tw = card_captured.create_tween()
				tw.tween_property(card_captured, "position:y", start_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)

		# Top Numeral (Roman)
		var num_lbl = RichTextLabel.new()
		num_lbl.bbcode_enabled = true
		num_lbl.position = Vector2(20, 24)
		num_lbl.size = Vector2(card_w - 40, 40)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_lbl.text = "[center][b][color=#D4AF37][font_size=28]── %s ──[/font_size][/color][/b][/center]" % str(choice.get("numeral", "Ⅰ"))
		card.add_child(num_lbl)

		# Card Title
		var name_lbl = RichTextLabel.new()
		name_lbl.bbcode_enabled = true
		name_lbl.position = Vector2(16, 75)
		name_lbl.size = Vector2(card_w - 32, 55)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.text = "[center][b][color=%s][font_size=24]%s[/font_size][/color][/b][/center]" % [
			el_color.to_html(), choice.get("name", "")
		]
		card.add_child(name_lbl)

		# Role Subtitle
		var role_lbl = RichTextLabel.new()
		role_lbl.bbcode_enabled = true
		role_lbl.position = Vector2(16, 135)
		role_lbl.size = Vector2(card_w - 32, 35)
		role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		role_lbl.text = "[center][color=#FFE082][font_size=15]《 %s 》[/font_size][/color][/center]" % choice.get("role", "")
		card.add_child(role_lbl)

		# Gold Filigree Divider
		var div = ColorRect.new()
		div.position = Vector2(30, 180)
		div.size = Vector2(card_w - 60, 2)
		div.color = Color(0.85, 0.72, 0.38, 0.6)
		card.add_child(div)

		# Decorative Emblem Frame / Icon
		var emblem_frame = Panel.new()
		emblem_frame.position = Vector2((card_w - 90) / 2.0, 200)
		emblem_frame.size = Vector2(90, 90)
		var emb_st = StyleBoxFlat.new()
		emb_st.bg_color = Color(el_color.r * 0.2, el_color.g * 0.2, el_color.b * 0.2, 0.8)
		emb_st.border_color = el_color
		emb_st.set_border_width_all(2)
		emb_st.set_corner_radius_all(45)
		emblem_frame.add_theme_stylebox_override("panel", emb_st)
		card.add_child(emblem_frame)

		var emblem_txt = RichTextLabel.new()
		emblem_txt.bbcode_enabled = true
		emblem_txt.position = Vector2(0, 20)
		emblem_txt.size = Vector2(90, 50)
		emblem_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem_txt.text = "[center][font_size=32]%s[/font_size][/center]" % s_item.get("short_label", "✦")
		emblem_frame.add_child(emblem_txt)

		# Description
		var desc_lbl = RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.position = Vector2(24, 310)
		desc_lbl.size = Vector2(card_w - 48, 220)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var desc_text = str(choice.get("desc", ""))
		desc_lbl.text = "[color=#ECEFF1][font_size=17]%s[/font_size][/color]" % desc_text
		card.add_child(desc_lbl)

		# "この運命を選択" Button
		var sel_btn = Button.new()
		sel_btn.name = "SelectBtn_%d" % i
		sel_btn.text = "✦ この運命を選択 ✦"
		sel_btn.position = Vector2(24, 550)
		sel_btn.size = Vector2(card_w - 48, 54)

		var btn_st = StyleBoxFlat.new()
		btn_st.bg_color = Color(0.26, 0.20, 0.08, 1.0)
		btn_st.border_color = Color(0.95, 0.82, 0.35, 1.0)
		btn_st.set_border_width_all(2)
		btn_st.set_corner_radius_all(10)
		sel_btn.add_theme_stylebox_override("normal", btn_st)

		var btn_st_hov = btn_st.duplicate()
		btn_st_hov.bg_color = Color(0.38, 0.30, 0.12, 1.0)
		btn_st_hov.border_color = Color(1.0, 0.9, 0.5, 1.0)
		sel_btn.add_theme_stylebox_override("hover", btn_st_hov)
		sel_btn.add_theme_color_override("font_color", Color("#FFF8E1"))
		sel_btn.add_theme_font_size_override("font_size", 18)

		var evo_id_captured = str(choice.get("id", ""))
		sel_btn.pressed.connect(func():
			if is_instance_valid(modal):
				modal.queue_free()
			tarot_modal_panel = null
			_complete_skill_upgrade(skill_idx, milestone_lvl, evo_id_captured)
		)
		card.add_child(sel_btn)

## =========================================================================
## 🛠️ デバッグ用レベルアップ＆リソース操作スイート
## =========================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F6:
				debug_add_resources(100000)
			KEY_F7:
				debug_set_all_skills_level(5)
			KEY_F8:
				debug_set_all_skills_level(20)
			KEY_F9:
				debug_toggle_shop()
			KEY_F10, KEY_K:
				var sm = get_parent().get_node_or_null("StageManager") if get_parent() else null
				if sm and sm.has_method("debug_kill_enemy"):
					sm.debug_kill_enemy()
					var vp = get_viewport()
					if vp: vp.set_input_as_handled()
					return

## デバッグ用：指定スキルの即時レベルアップ（コスト・前提条件完全無視）
func debug_level_up_skill(skill_idx: int, target_level: int = -1) -> void:
	if skill_idx < 0 or skill_idx >= skill_tree_items.size():
		return
	var s_item = skill_tree_items[skill_idx]
	var cur_lvl: int = int(s_item.get("level", 0))
	var max_lvl: int = int(s_item.get("max_level", 20))

	var next_lvl = cur_lvl + 1
	if target_level > 0:
		next_lvl = clampi(target_level, 1, max_lvl)
	elif next_lvl > max_lvl:
		# Lv20超過時はLv1へリセットし、進化をクリアして再テスト可能に
		s_item["level"] = 1
		if skill_evolutions.has(s_item["id"]):
			skill_evolutions.erase(s_item["id"])
		_complete_skill_upgrade(skill_idx, 1, "")
		_update_buff_button_labels()
		rebuild_skill_tree_ui()
		return

	# 進化マイルストーン（Lv.5またはLv.20）の判定：タロット選択モーダルを展開
	if (next_lvl == 5 or next_lvl == 20) and not has_chosen_evolution(s_item["id"], next_lvl):
		if not is_shop_open:
			set_shop_ui_visible(true)
		_open_tarot_evolution_modal(skill_idx, next_lvl)
		return

	# 無料レベルアップ
	var orig_p = divscore[PieceType.POTION] if divscore.size() > PieceType.POTION else 0
	_complete_skill_upgrade(skill_idx, next_lvl, "")
	divscore[PieceType.POTION] = orig_p
	_update_buff_button_labels()
	rebuild_skill_tree_ui()

## デバッグ用：ショップバフ（コイン強化）の即時レベルアップ
func debug_level_up_shop_buff(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= shop_items.size():
		return
	var item = shop_items[slot_idx]
	var cost_ref = int(item.get("cost", 0))
	var orig_c = divscore[PieceType.COIN] if divscore.size() > PieceType.COIN else 0
	divscore[PieceType.COIN] = orig_c + cost_ref
	_purchase_buff(slot_idx)
	divscore[PieceType.COIN] = orig_c
	_update_buff_button_labels()

## デバッグ用：コイン＆ポーションの大量付与
func debug_add_resources(amount: int = 100000) -> void:
	divscore[PieceType.COIN] += amount
	divscore[PieceType.POTION] += amount
	_update_buff_button_labels()
	var pb = _get_puzzle_board()
	if pb and pb.has_method("_spawn_floating_text"):
		pb._spawn_floating_text(Vector2(960, 420), "🛠️ デバッグ: コイン＆ポーション +%d！" % amount, Color(1.0, 0.85, 0.3))
	print("[DEBUG] Added %d coins & potions. Coins=%d, Potions=%d" % [amount, divscore[PieceType.COIN], divscore[PieceType.POTION]])

## デバッグ用：選択系統の全スキルを指定レベルに一括設定
func debug_set_all_skills_level(target_lvl: int) -> void:
	var cat_key = chosen_category
	var rm = _get_relic_manager()
	if rm and rm.has_method("get_chosen_element_category") and rm.get_chosen_element_category() != "":
		cat_key = rm.get_chosen_element_category()
	if cat_key == "":
		cat_key = "nature"
		on_element_category_chosen("nature")

	for s_idx in range(skill_tree_items.size()):
		var s_item = skill_tree_items[s_idx]
		if s_item.get("category", "") == cat_key:
			s_item["level"] = target_lvl
			var sp_type = int(s_item["sp_type"])
			var pb = _get_puzzle_board()
			if pb and "special_levels" in pb:
				pb.special_levels[sp_type] = target_lvl
			if s_item["id"] == "bomb":
				bomb_buff_level = target_lvl
			emit_signal("skill_upgraded", s_item["id"], sp_type, target_lvl)

			# Lv5およびLv20の進化特性が未選択なら、テスト用に第1候補を自動付与
			if target_lvl >= 5 and not has_chosen_evolution(s_item["id"], 5):
				var m_choices = get_evolution_choices(s_item["id"], 5)
				if not m_choices.is_empty():
					choose_skill_evolution(s_item["id"], 5, m_choices[0]["id"])
			if target_lvl >= 20 and not has_chosen_evolution(s_item["id"], 20):
				var f_choices = get_evolution_choices(s_item["id"], 20)
				if not f_choices.is_empty():
					choose_skill_evolution(s_item["id"], 20, f_choices[0]["id"])

	_update_buff_button_labels()
	rebuild_skill_tree_ui()
	var pb = _get_puzzle_board()
	if pb and pb.has_method("_spawn_floating_text"):
		pb._spawn_floating_text(Vector2(960, 460), "⚡ デバッグ: 全スキルを Lv.%d に一括設定！" % target_lvl, Color(0.4, 0.9, 1.0))
	print("[DEBUG] Set all skills in category %s to level %d" % [cat_key, target_lvl])

## デバッグ用：ショップ＆スキルツリーのトグル表示（戦闘中いつでも開閉可能）
func debug_toggle_shop() -> void:
	set_shop_ui_visible(!is_shop_open)

## スキルツリーの解放・強化処理（余剰ポーション使用）
func _purchase_skill(skill_idx: int) -> void:
	if skill_idx < 0 or skill_idx >= skill_tree_items.size():
		return

	var s_item = skill_tree_items[skill_idx]
	var cur_lvl: int = int(s_item["level"])
	var max_lvl: int = int(s_item.get("max_level", 20))
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
		var target_lvl = cur_lvl + 1
		# 進化マイルストーン（Lv.5またはLv.20）の判定
		if (target_lvl == 5 or target_lvl == 20) and not has_chosen_evolution(s_item["id"], target_lvl):
			_open_tarot_evolution_modal(skill_idx, target_lvl)
			return

		_complete_skill_upgrade(skill_idx, target_lvl, "")
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


func _setup_elem_status_panel(force_cat: String = "") -> void:
	var cat = force_cat if not force_cat.is_empty() else _get_chosen_element_category()
	_rendered_elem_category = cat

	if elem_status_rect == null:
		elem_status_rect = ColorRect.new()
		elem_status_rect.name = "elem_status"
		elem_status_rect.z_index = -10
		elem_status_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(elem_status_rect)
	elem_status_rect.color = Color(0.85, 0.72, 0.38, 1.0)
	elem_status_rect.position = Vector2(1625.0, 544.0)
	elem_status_rect.size = Vector2(290.0, 400.0)

	if elem_status2_rect == null:
		elem_status2_rect = ColorRect.new()
		elem_status2_rect.name = "elem_status2"
		elem_status2_rect.z_index = -10
		elem_status2_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(elem_status2_rect)
	elem_status2_rect.color = Color(0.07, 0.09, 0.13, 0.96)
	elem_status2_rect.position = Vector2(1627.0, 546.0)
	elem_status2_rect.size = Vector2(286.0, 396.0)

	# 属性カテゴリーヘッダーラベル
	if elem_category_header_label == null:
		elem_category_header_label = RichTextLabel.new()
		elem_category_header_label.name = "elem_category_header"
		elem_category_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elem_category_header_label.bbcode_enabled = true
		elem_category_header_label.scroll_active = false
		elem_category_header_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		elem_category_header_label.add_theme_font_override("bold_font", CUSTOM_FONT)
		elem_category_header_label.add_theme_constant_override("outline_size", 6)
		elem_category_header_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		add_child(elem_category_header_label)
	elem_category_header_label.position = Vector2(1632.0, 552.0)
	elem_category_header_label.size = Vector2(276.0, 34.0)

	# 既存のアイコン・ラベルのクリア
	for lbl in elem_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	elem_labels.clear()

	for k in range(12):
		var old_icn = get_node_or_null("elem_icon" + str(k + 1))
		if old_icn: old_icn.queue_free()
		var old_h = get_node_or_null("elem_hover_" + str(k + 1))
		if old_h: old_h.queue_free()

	# 属性値が未定の場合、その欄には何も表示してはいけない。線（外枠・内枠）だけでよい。
	if cat.is_empty() or not CATEGORY_ELEMENT_DEFS.has(cat):
		elem_category_elements = []
		elem_category_header_label.text = ""
		elem_category_header_label.visible = false
		_setup_grid_lines()
		return

	var cat_def = CATEGORY_ELEMENT_DEFS[cat]
	elem_category_elements = cat_def["elements"]
	elem_category_header_label.visible = true
	elem_category_header_label.text = "[center][font_size=18][b][color=#%s]◆ %s ◆[/color][/b][/font_size][/center]" % [cat_def["color"], cat_def["title"]]

	# 属性アイコンとラベルの生成（右側カラム内に配置）
	var num_elems = elem_category_elements.size()
	var start_y = 590.0
	var avail_h = 352.0
	var row_h = avail_h / float(maxi(1, num_elems))

	for k in range(num_elems):
		var elem_info = elem_category_elements[k]
		var el_y = start_y + row_h * float(k)

		var el_icn = TextureRect.new()
		el_icn.name = "elem_icon" + str(k + 1)
		el_icn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		el_icn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		el_icn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		el_icn.z_index = 2
		add_child(el_icn)
		if elem_info["icon"] != "" and ResourceLoader.exists(elem_info["icon"]):
			el_icn.texture = load(elem_info["icon"])
			if elem_info["key"] == "ice":
				el_icn.modulate = Color(0.5, 0.9, 1.0, 1.0)
		el_icn.position = Vector2(1637.0, el_y + (row_h - 36.0) / 2.0)
		el_icn.size = Vector2(36.0, 36.0)

		var el_lbl = RichTextLabel.new()
		el_lbl.name = "elem_score" + str(k + 1)
		el_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		el_lbl.bbcode_enabled = true
		el_lbl.scroll_active = false
		el_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
		el_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
		el_lbl.add_theme_constant_override("outline_size", 8)
		el_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		el_lbl.position = Vector2(1686.0, el_y + (row_h - 34.0) / 2.0)
		el_lbl.size = Vector2(450.0, 80.0)
		el_lbl.scale = Vector2(0.46, 0.46)
		add_child(el_lbl)
		elem_labels.append(el_lbl)

		# 属性値ホバーツールチップ領域（行全体）
		var el_h_name = "elem_hover_" + str(k + 1)
		var el_h_ctrl = get_node_or_null(el_h_name) as Control
		if el_h_ctrl == null:
			el_h_ctrl = Control.new()
			el_h_ctrl.name = el_h_name
			el_h_ctrl.z_index = 5
			el_h_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
			add_child(el_h_ctrl)
		el_h_ctrl.position = Vector2(1627.0, el_y)
		el_h_ctrl.size = Vector2(286.0, row_h)
		var bind_key = elem_info["key"]
		el_h_ctrl.mouse_entered.connect(func(): _show_elem_tooltip(bind_key))
		el_h_ctrl.mouse_exited.connect(func(): _hide_elem_tooltip(bind_key))

	_setup_grid_lines()
	update_elem_labels()

func update_elem_labels() -> void:
	var cur_cat = _get_chosen_element_category()
	if cur_cat != _rendered_elem_category:
		_setup_elem_status_panel(cur_cat)
		return

	if elem_labels.size() == 0 or elem_category_elements.size() == 0:
		return

	for k in range(mini(elem_labels.size(), elem_category_elements.size())):
		var elem_info = elem_category_elements[k]
		var count = get_element_count(elem_info["key"])
		var val_str = _format_comma(count)
		elem_labels[k].text = "[font_size=32][b][color=#%s]%s %s[/color] :  [color=#FFFFFF]%s[/color][/b][/font_size]" % [
			elem_info["color"], elem_info["emoji"], elem_info["name"], val_str
		]

	# 選択した属性値欄のサイズ維持 (横幅290.0px / 内枠286.0px / 高さ400.0px -> 盤面下端 y=944 に一致)
	if elem_status_rect != null:
		elem_status_rect.size = Vector2(290.0, 400.0)
	if elem_status2_rect != null:
		elem_status2_rect.size = Vector2(286.0, 396.0)

func reset_turn_elements() -> void:
	turn_element_counts.clear()
	turn_element_gain.clear()
	turn_sword_element_counts.clear()
	update_elem_labels()

func get_turn_sword_element_counts() -> Dictionary:
	return turn_sword_element_counts.duplicate()

func add_turn_element(el: Variant, amount: int) -> void:
	turn_element_counts[el] = turn_element_counts.get(el, 0) + amount
	update_elem_labels()

## シンボル同士・シンボルと値を区切るグリッド線のセットアップ
func _setup_grid_lines() -> void:
	var line_color = Color(0.72, 0.60, 0.34, 0.5)
	
	# --- 1. アイテム値の欄 (左側 x: 1192..1613, y: 546..942, 5行) ---
	# 垂直区切り線（シンボルと値の境界: x = 1266.0）
	var st_vline = get_node_or_null("status_v_line") as ColorRect
	if st_vline == null:
		st_vline = ColorRect.new()
		st_vline.name = "status_v_line"
		st_vline.z_index = -5
		st_vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(st_vline)
	st_vline.position = Vector2(1266.0, 546.0)
	st_vline.size = Vector2(2.0, 396.0)
	st_vline.color = line_color
	
	# 水平区切り線（アイテム行同士の境界: 4本）
	for idx in range(4):
		var line_name = "status_h_line_" + str(idx)
		var st_hline = get_node_or_null(line_name) as ColorRect
		if st_hline == null:
			st_hline = ColorRect.new()
			st_hline.name = line_name
			st_hline.z_index = -5
			st_hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(st_hline)
		st_hline.position = Vector2(1192.0, 546.0 + 79.2 * float(idx + 1))
		st_hline.size = Vector2(421.0, 2.0)
		st_hline.color = line_color

	# --- 2. 選択属性値の欄 (右側 x: 1627..1913, y: 546..942) ---
	var has_category = not elem_category_elements.is_empty()

	# 垂直区切り線（シンボルと値の境界: x = 1680.0）
	var el_vline = get_node_or_null("elem_v_line") as ColorRect
	if el_vline == null:
		el_vline = ColorRect.new()
		el_vline.name = "elem_v_line"
		el_vline.z_index = -5
		el_vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(el_vline)
	el_vline.position = Vector2(1680.0, 590.0)
	el_vline.size = Vector2(2.0, 352.0)
	el_vline.color = line_color
	el_vline.visible = has_category
	
	# ヘッダー下部区切り線
	var el_hdr_line = get_node_or_null("elem_h_line_hdr") as ColorRect
	if el_hdr_line == null:
		el_hdr_line = ColorRect.new()
		el_hdr_line.name = "elem_h_line_hdr"
		el_hdr_line.z_index = -5
		el_hdr_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(el_hdr_line)
	el_hdr_line.position = Vector2(1627.0, 590.0)
	el_hdr_line.size = Vector2(286.0, 2.0)
	el_hdr_line.color = line_color
	el_hdr_line.visible = has_category

	# 水平区切り線（属性行同士の境界）
	var num_elems = elem_category_elements.size()
	var row_h = 352.0 / float(maxi(1, num_elems))
	for idx in range(num_elems - 1):
		var line_name = "elem_h_line_" + str(idx)
		var el_hline = get_node_or_null(line_name) as ColorRect
		if el_hline == null:
			el_hline = ColorRect.new()
			el_hline.name = line_name
			el_hline.z_index = -5
			el_hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(el_hline)
		el_hline.position = Vector2(1627.0, 590.0 + row_h * float(idx + 1))
		el_hline.size = Vector2(286.0, 2.0)
		el_hline.color = line_color
		el_hline.visible = has_category
	
	# 余剰ラインがあれば非表示
	for idx in range(max(0, num_elems - 1), 8):
		var extra_line = get_node_or_null("elem_h_line_" + str(idx))
		if extra_line: extra_line.visible = false

## アイテム値のマウスホバーツールチップ表示
## 戦闘HUDアイテムホバー領域の初期化・セットアップ
func _setup_combat_hud_hover_tooltips() -> void:
	for i in range(5):
		var row_y = 546.0 + 79.2 * float(i)
		var h_name = "item_hover_" + str(i)
		var h_ctrl = get_node_or_null(h_name) as Control
		if h_ctrl == null:
			h_ctrl = Control.new()
			h_ctrl.name = h_name
			h_ctrl.z_index = 5
			h_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
			add_child(h_ctrl)
		h_ctrl.position = Vector2(1192.0, row_y)
		h_ctrl.size = Vector2(421.0, 79.2)
		var bind_i = i
		if not h_ctrl.mouse_entered.is_connected(_on_item_hover_entered.bind(bind_i)):
			h_ctrl.mouse_entered.connect(_on_item_hover_entered.bind(bind_i))
			h_ctrl.mouse_exited.connect(_on_item_hover_exited.bind(bind_i))

func _on_item_hover_entered(idx: int) -> void:
	_show_item_tooltip(idx)

func _on_item_hover_exited(idx: int) -> void:
	_hide_item_tooltip(idx)

func _show_item_tooltip(item_idx: int) -> void:
	var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
	if r_ui == null or not r_ui.has_method("show_custom_tooltip"):
		return
	var title = ""
	var desc = ""
	var cur_val: int = divscore[item_idx] if item_idx < divscore.size() else 0
	var val_str = _format_comma(cur_val)
	match item_idx:
		PieceType.SHIELD:
			title = "[b][color=#00E5FF]🛡️ シールド (防御値: %s)[/color][/b]" % val_str
			desc = "[font_size=17]盤面でシールド駒をマッチさせると蓄積される防御力です。\n[color=#FFD54F]【ターン終了時の効果】[/color]\n蓄積されたシールド値がプレイヤー前面にアーマーとして展開され、敵の物理攻撃やスキルの直撃ダメージを身代わりとなって防ぎます。[/font_size]"
		PieceType.SWORD:
			title = "[b][color=#FF3D3D]⚔️ ソード (物理攻撃力: %s)[/color][/b]" % val_str
			desc = "[font_size=17]盤面でソード駒をマッチさせると蓄積される直接攻撃力です。\n[color=#FFD54F]【ターン終了時の効果】[/color]\n蓄積された攻撃力に応じた数の飛翔剣が一斉に敵へ射出され、物理ダメージを与えます。敵が複数いる場合はターゲットした敵へ集中攻撃します。[/font_size]"
		PieceType.COIN:
			title = "[b][color=#FFD700]🪙 コイン (所持資金: %s)[/color][/b]" % val_str
			desc = "[font_size=17]盤面でコイン駒をマッチさせると獲得できるショップ用資金です。\n[color=#FFD54F]【戦闘終了後の使途】[/color]\nショップ画面でフィーバー倍率強化、最大HP上限増加、各属性の基礎ステータス強化を購入するために消費します。[/font_size]"
		PieceType.POTION:
			title = "[b][color=#FF2E93]🧪 ポーション (魔力薬: %s)[/color][/b]" % val_str
			desc = "[font_size=17]盤面でポーション駒をマッチさせると蓄積される魔力資源です。\n[color=#FFD54F]【戦闘中の効果】[/color]\nフィーバーゲージをチャージし、満タンでフィーバータイム（全獲得量2倍以上）を発動。\n[color=#69F0AE]【戦闘後の使途】[/color]\n余剰分は持ち越され、スキルツリーで全属性のスキル（Lv1〜20）を解放・進化させる最重要資源となります。[/font_size]"
		PieceType.FOOD:
			title = "[b][color=#76FF03]🍞 フード (回復値: %s)[/color][/b]" % val_str
			desc = "[font_size=17]盤面でフード駒をマッチさせると蓄積される体力回復源です。\n[color=#FFD54F]【ターン終了時の効果】[/color]\nプレイヤーの減少したHPを即座に回復します（最大HPまで）。消耗戦やボス戦でゲームオーバーを防ぐ生命線となります。[/font_size]"
	if title != "":
		r_ui.show_custom_tooltip(title, desc, get_global_mouse_position(), "item_stat_" + str(item_idx))

func _hide_item_tooltip(item_idx: int) -> void:
	var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
	if r_ui and r_ui.has_method("hide_custom_tooltip"):
		r_ui.hide_custom_tooltip("item_stat_" + str(item_idx))

## 属性値のマウスホバーツールチップ表示
func _show_elem_tooltip(elem_key: String) -> void:
	var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
	if r_ui == null or not r_ui.has_method("show_custom_tooltip"):
		return
	var title = ""
	var desc = ""
	var count = get_element_count(elem_key)
	var val_str = _format_comma(count)
	match elem_key:
		"water":
			title = "[b][color=#00B0FF]💧 水属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した水属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n水マスを生成・伝播。炎マスと隣接すると【蒸気消滅シナジー】が発生し、共通隣接マスを一掃消去します。水上の駒消去でHP回復効果も発動。[/font_size]"
		"ice":
			title = "[b][color=#80D8FF]❄️ 氷属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した氷属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n氷盾マスを展開し周囲の状態異常の侵攻を完全停止。雷属性が触れると【破砕シナジー】で周囲3×3を砕いて大ダメージを与えます。炎で融解。[/font_size]"
		"wood":
			title = "[b][color=#76FF03]🌱 木属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した木属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n盤面に生命の苗木を育成。水たまりを吸収して大木へと成長し、毎ターンプレイヤーのHPを自動回復します。炎接触で大炎上するため注意。[/font_size]"
		"wind":
			title = "[b][color=#69F0AE]🌪️ 風属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した風属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n竜巻を発生させて列全体を巻き上げ消去。敵の弾幕や障害物を押し流し、連鎖マッチを強制誘発します。[/font_size]"
		"fire":
			title = "[b][color=#FF3D00]🔥 火属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した火属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n紅蓮爆弾や炎上マスを生成。水マスと隣接で【蒸気消滅シナジー】、氷マスを融解して水に変換。敵へ継続炎上ダメージを与えます。[/font_size]"
		"thunder":
			title = "[b][color=#FFD600]⚡ 雷属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した雷属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n直線貫通レーザーや過充電マスを生成。氷や岩石に雷が接触すると【破砕爆縮シナジー】が発生し、周囲3×3マスを一瞬で消し飛ばします。[/font_size]"
		"earth":
			title = "[b][color=#D7CCC8]🪨 地属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した地属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n強固な岩盤崩落を引き起こし敵の装甲を粉砕。味方の輝石マスは自由に移動でき、雷接触で広範囲の破片破砕を引き起こします。[/font_size]"
		"poison":
			title = "[b][color=#B388FF]🧪 毒属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した毒属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n味方薬毒マスを展開。味方毒1マスごとに敵からの毒ダメージを軽減（免疫バリア）し、2ターンに1度敵マスへ侵攻して持続毒ダメージを与えます。[/font_size]"
		"light":
			title = "[b][color=#FFF59D]✨ 光属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した光属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n神聖な聖光星や聖像を召喚。盤面の悪性呪いや暗雲を瞬時に浄化消滅させ、敵全体へ聖なる拡散貫通ダメージを与えます。[/font_size]"
		"dark":
			title = "[b][color=#EA80FC]🌙 闇属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した闇属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n超重力ブラックホールを発生させ、周囲の全コマを強制吸引・消滅。味方の影護コマは反動を受けず敵のHPを吸収ドレインします。[/font_size]"
	if title != "":
		r_ui.show_custom_tooltip(title, desc, get_global_mouse_position(), "elem_stat_" + elem_key)

func _hide_elem_tooltip(elem_key: String) -> void:
	var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
	if r_ui and r_ui.has_method("hide_custom_tooltip"):
		r_ui.hide_custom_tooltip("elem_stat_" + elem_key)

