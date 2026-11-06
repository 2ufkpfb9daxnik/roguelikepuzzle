extends Node2D
const GlossaryDatabase = preload("res://glossary_database.gd")

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
signal shop_purchased

# --- 公開プロパティ（他ノードから参照される変数） ---
var totalScore: int = 0
var divscore: Array = [0, 0, 0, 0, 0] # [SHIELD, SWORD, COIN, POTION, FOOD]
var combocount: int = 0
var iscombo: bool = false
var gridscore: Array = []
var skill_levels: Dictionary = {}

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
const HP_SHOP_FLAT_GAIN: float = 5000.0
const HP_SHOP_PERCENT_GAIN: float = 0.10
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
var shop_content_bg: Panel = null
var shop_tab_btn: Button = null
var skill_tab_btn: Button = null
var coin_currency_lbl: RichTextLabel = null
var potion_currency_lbl: RichTextLabel = null
var shop_view_container: Control = null
var skill_tree_container: Control = null
var shop_card_refs: Array[Dictionary] = []
var skill_node_refs: Array[Dictionary] = []

# パフォーマンス最適化用キャッシュ変数
var _cached_jp_font: Font = null
func _get_difficulty_reward_mult() -> float:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("get_difficulty_reward_mult"):
		return float(sm.get_difficulty_reward_mult())
	return 1.0

func _get_jp_font() -> Font:
	if _cached_jp_font == null:
		_cached_jp_font = load("res://font/NotoSansJP.ttf")
		_cached_jp_font.set_fallbacks([load("res://font/NotoEmoji.ttf")])
	return _cached_jp_font

## Web環境でも日本語が文字化けしないよう、コントロールに日本語フォントを適用
func _apply_jp_font_to_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	var f: Font = _get_jp_font()
	if ctrl is RichTextLabel:
		ctrl.add_theme_font_override("normal_font", f)
		ctrl.add_theme_font_override("bold_font", f)
		ctrl.add_theme_font_override("italics_font", f)
		ctrl.add_theme_font_override("bold_italics_font", f)
		ctrl.add_theme_font_override("mono_font", f)
	else:
		ctrl.add_theme_font_override("font", f)

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
		"desc": "プレイヤーの最大HPを最大HPの10%（最低5000×ステージ倍率）増加させ、増加分だけ即座に回復します。",
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
# 🌟 スキル正当進化レジストリ（3分岐＆2択階層構造）
# 各属性ごとに中間進化（Lv.5 / 第1覚醒）と最終進化（Lv.20 / 極限神格化）の選択肢を定義
# ※氷の行動スキップは強大スキルのため、必ず最終進化（Lv.20）にのみ配置
# ---------------------------------------------------------
const SKILL_EVOLUTION_REGISTRY: Dictionary = {
	"water": {
		"mid": [
			{"id": "water_mid_a", "branch": "A", "name": "生命の清流", "role": "毎ターン水マス比例HP回復", "desc": "ターン終了時、自陣の水マス1個につき（20＋スキルLv×5）のHPを回復する。"},
			{"id": "water_mid_b", "branch": "B", "name": "水華の防壁", "role": "毎ターン水マス比例シールド", "desc": "ターン終了時、自陣の水マス1個につき（30＋スキルLv×8）のシールドを獲得する。"},
			{"id": "water_mid_c", "branch": "C", "name": "激流の怒涛", "role": "毎ターン水マス比例水サージ", "desc": "ターン終了時、自陣の水マス1個につき（50＋スキルLv×12）の水サージ追撃ダメージを与える。"}
		],
		"final": {
			"water_mid_a": [
				{"id": "water_final_a1", "name": "癒しの雨", "role": "自陣水上マッチ即時回復", "desc": "自陣の水マス上で駒がマッチするたび、即座に（30＋スキルLv×5）のHPを回復する。"},
				{"id": "water_final_a2", "name": "溢れる泉", "role": "超過HP回復シールド変換", "desc": "ターン終了時の回復でHPが最大値を超えた分を、自身のシールドに変換する。"}
			],
			"water_mid_b": [
				{"id": "water_final_b1", "name": "水鏡", "role": "自陣水上マッチ追加シールド", "desc": "自陣の水マス上で駒がマッチするたび、（40＋スキルLv×8）の追加シールドを獲得する。"},
				{"id": "water_final_b2", "name": "水の結界", "role": "自陣水上毒伝染防止", "desc": "自陣の水マス上では相手の毒が広がらない（毒の伝染を防止する）。"}
			],
			"water_mid_c": [
				{"id": "water_final_c1", "name": "水撃", "role": "自陣水マス上マッチ時追撃", "desc": "自陣の水マス上で駒をマッチ消去した際、敵に（40＋スキルLv×10）の水撃追撃ダメージを与える。"},
				{"id": "water_final_c2", "name": "渦潮", "role": "水マス最多列流し＆連鎖追撃", "desc": "ターン終了時の水サージ発動時、自陣の水マスが最も多い縦列の駒を押し流して消去し落下連鎖を起こす。その列の水マス数×（200＋スキルLv×40）の追加ダメージを与える（水マスは消費しない）。"}
			]
		}
	},
	"wood": {
		"mid": [
			{"id": "wood_mid_a", "branch": "A", "name": "共生", "role": "隣接マッチ時植物即時成長", "desc": "自陣の植物の隣接マスで駒がマッチするたび、その植物が1段階即座に成長する。"},
			{"id": "wood_mid_b", "branch": "B", "name": "茨", "role": "被弾時植物本数比例反射", "desc": "相手から攻撃を受けるたび、自陣の植物1本につき相手に反射ダメージを与える。"},
			{"id": "wood_mid_c", "branch": "C", "name": "実り", "role": "成長完了時ポーション結実", "desc": "自陣の植物が大木に成長した時、隣接する駒1個を即座にポーション駒に変化させる（敵所持時はHP回復）。"}
		],
		"final": {
			"wood_mid_a": [
				{"id": "wood_final_a1", "name": "株分け", "role": "大木成長時苗木植樹", "desc": "自陣の植物が大木に成長した瞬間、ランダムな空きマスに自陣の苗木を1本植える。"},
				{"id": "wood_final_a2", "name": "深い根", "role": "植物破壊時1段階縮小耐性", "desc": "自陣の植物が火や相手の効果で壊される時、消滅せずに1段階だけ小さくなる（苗木の場合は消滅）。"}
			],
			"wood_mid_b": [
				{"id": "wood_final_b1", "name": "森の加護", "role": "植物1本につき被ダメ5%軽減(最大40%)", "desc": "自陣の植物1本につき、受けるダメージを5%軽減する（最大40%）。"},
				{"id": "wood_final_b2", "name": "毒棘", "role": "ターン終了時植物周囲に毒マス配置", "desc": "ターン終了時、ランダムな自陣の植物1本の周囲1マスに自陣の毒マスを1個置く。"}
			],
			"wood_mid_c": [
				{"id": "wood_final_c1", "name": "豊穣", "role": "植物消去時周囲ポーション一斉発動", "desc": "自陣の植物をマッチで消去すると、周囲のポーション駒が一斉に効果を発動（回復＆消去）する。"},
				{"id": "wood_final_c2", "name": "神樹", "role": "ターン終了時特殊スキル駒結実", "desc": "ターン終了時、自陣の大木の隣接マスにランダムな特殊スキル駒が結実・生成される。"}
			]
		}
	},
	"wind": {
		"mid": [
			{"id": "wind_mid_a", "branch": "A", "name": "旋風", "role": "竜巻通過列の駒横ずらし", "desc": "竜巻が通過した縦列の駒が、横方向に1マスずれて盤面をダイナミックに組み替える。"},
			{"id": "wind_mid_b", "branch": "B", "name": "突風", "role": "通過列駒巻き込み消去＆追撃", "desc": "竜巻が通過した列の駒も巻き込んで消去するようになり、消した駒の数に応じて相手に追加ダメージを与える。"},
			{"id": "wind_mid_c", "branch": "C", "name": "奪取", "role": "接触した相手石・氷の自陣反転", "desc": "竜巻が相手の石や氷に接触した時、それらを自陣の石や自陣の氷に置き換える。"}
		],
		"final": {
			"wind_mid_a": [
				{"id": "wind_final_a1", "name": "疾風怒濤", "role": "コンボ数×15%ダメージ増傷", "desc": "スキル発動時、現在のコンボ数に応じてスキル直接ダメージが1コンボにつき15%増加する。"},
				{"id": "wind_final_a2", "name": "横風", "role": "竜巻が横1行も通過し十字走行", "desc": "竜巻が縦列に加えて通過点の横1行も駆け抜け、十字に走って巻き込む。"}
			],
			"wind_mid_b": [
				{"id": "wind_final_b1", "name": "大竜巻", "role": "竜巻上下2往復走破", "desc": "竜巻が上下に2往復して列の駒と障害物を徹底的に巻き込み消去する。"},
				{"id": "wind_final_b2", "name": "暴風圏", "role": "通過列で2ターンマッチ時追撃", "desc": "竜巻が通過した列に2ターンの間暴風圏が発生し、その列でマッチするたびに相手へ風ダメージを与える。"}
			],
			"wind_mid_c": [
				{"id": "wind_final_c1", "name": "風の守り", "role": "通過列に2ターン妨害マス設置阻止", "desc": "竜巻が通過した列には、2ターンの間相手の妨害マスが置かれなくなる。"},
				{"id": "wind_final_c2", "name": "追い風の恵み", "role": "奪取マス数比例でHP回復 (+60/マス)", "desc": "自陣へと奪取・変換したマス1つにつき、HPを60回復する（ステージ倍率適用）。"}
			]
		}
	},
	"thunder": {
		"mid": [
			{"id": "thunder_mid_a", "branch": "A", "name": "反射雷", "role": "障害物激突時隣接駒1個破壊", "desc": "雷が盤面の障害物（石・氷・木・像）に当たると、ランダムな隣接1マスの駒を跳ね返って破壊する。"},
			{"id": "thunder_mid_b", "branch": "B", "name": "帯電", "role": "帯電コイン消去時隣接連鎖スパーク", "desc": "自陣の帯電コインを消去すると、隣接する他の帯電コインへと電撃スパークが連鎖して相手に感電ダメージを与える。"},
			{"id": "thunder_mid_c", "branch": "C", "name": "感電", "role": "雷ダメで相手へ感電スタック付与(最大5)", "desc": "雷属性ダメージを与えるたびに相手へ感電スタックを付与する（最大5スタック）。"}
		],
		"final": {
			"thunder_mid_a": [
				{"id": "thunder_final_a1", "name": "雷網", "role": "障害物連鎖反射(最大3回)", "desc": "反射先のマスにさらに障害物がある場合、次々に雷が跳ね返り最大3回まで連鎖反射する。"},
				{"id": "thunder_final_a2", "name": "乱反射", "role": "跳ね返り方向に盤端まで貫通破壊", "desc": "跳ね返った雷が、その方向に盤の端まで一直線に突き抜けて駒を破壊する。"}
			],
			"thunder_mid_b": [
				{"id": "thunder_final_b1", "name": "放電", "role": "ターン終了時帯電マス数比例自動放電", "desc": "毎ターン終了時、自陣の帯電マス1個が自動で放電する。放電ダメージは自陣の帯電マス数に比例する。"},
				{"id": "thunder_final_b2", "name": "雷雨", "role": "毎ターン開始時駒2個に落雷帯電化", "desc": "毎ターン開始時、盤面にある駒（味方はコイン優先）のうちランダムな2個に雷が落ちて自陣の帯電マスにする。"}
			],
			"thunder_mid_c": [
				{"id": "thunder_final_c1", "name": "解放", "role": "5スタック到達時一斉解放大ダメージ", "desc": "感電が5スタックに達した瞬間、すべての電荷が一斉解放され特大放電を叩き込む。"},
				{"id": "thunder_final_c2", "name": "静電気", "role": "相手攻撃時スタック比例自傷ダメージ", "desc": "感電スタックを持つ相手が攻撃行動を行うたび、スタック数に応じた強烈な自傷ダメージを受ける。"}
			]
		}
	},
	"ice": {
		"mid": [
			{"id": "ice_mid_a", "branch": "A", "name": "持ち越し", "role": "シールド次ターン蓄積・持ち越し", "desc": "獲得したシールドがターン終了時に消えず、次ターン以降へと引き継がれて蓄積していく。"},
			{"id": "ice_mid_b", "branch": "B", "name": "砕氷", "role": "氷上マッチ時氷破壊＆隣接駒消去", "desc": "自陣の氷マス上で駒をマッチさせると氷が砕け散り、隣接する駒1個を追加で巻き込み消去する。"},
			{"id": "ice_mid_c", "branch": "C", "name": "永久凍土", "role": "自陣氷マスの耐久値減少しなくなる", "desc": "自陣の氷マスの耐久値がターン経過で減少しなくなる。"}
		],
		"final": {
			"ice_mid_a": [
				{"id": "ice_final_a1", "name": "氷塊", "role": "持ち越しシールド500ごとに氷生成", "desc": "蓄積・持ち越したシールドが500を超えるごとに、盤面に自陣の氷マスが1個生成される（最大8個）。"},
				{"id": "ice_final_a2", "name": "氷柱反撃", "role": "シールド吸収ダメージを氷反撃", "desc": "シールドが相手の攻撃を受け止めて軽減・吸収したダメージと同等の氷属性ダメージを相手に跳ね返す。"}
			],
			"ice_mid_b": [
				{"id": "ice_final_b1", "name": "破砕起爆", "role": "周囲3×3破壊＆石即座破壊", "desc": "砕けた氷が激しい衝撃波を生み出し、周囲3×3マスの駒を一掃して石も即座に破壊する。"},
				{"id": "ice_final_b2", "name": "霜の連鎖", "role": "氷破砕時隣接2マスを自陣氷に変化", "desc": "氷が砕けるたびに冷気が飛び散り、隣接する2マスが新たな自陣氷マスへと凍結する。"}
			],
			"ice_mid_c": [
				{"id": "ice_final_c1", "name": "寒気", "role": "氷マス1個につき相手攻撃力-3%(最大30%)", "desc": "盤面の自陣氷マス1個につき、相手の攻撃力を3%低下させる（最大30%）。"},
				{"id": "ice_final_c2", "name": "氷原", "role": "ターン終了時氷マスが隣接空きマスへ拡大", "desc": "ターン終了時、自陣の氷マスが隣接する空きマス1つへ広がる（自陣の氷マスが盤面全体で最大10個まで）。"}
			]
		}
	},
	"fire": {
		"mid": [
			{"id": "fire_mid_a", "branch": "A", "name": "飛び火", "role": "燃え尽き時周囲48マスへ飛び火", "desc": "火が燃え尽きて消える時、周囲48マス（7×7）のランダムなマスを炎上させて駒を消去する。"},
			{"id": "fire_mid_b", "branch": "B", "name": "延焼", "role": "火マスが毎ターン隣へ拡大(上限12)", "desc": "自陣の火マスが1ターンごとに隣接する空きマスの1つへ燃え広がる（盤面最大12マスまで）。"},
			{"id": "fire_mid_c", "branch": "C", "name": "破片", "role": "爆発巻き込み駒破片で隣接駒1個消去", "desc": "火が燃え広がる時、火花が飛び散りランダムな隣接1マスの駒を消去する。"}
		],
		"final": {
			"fire_mid_a": [
				{"id": "fire_final_a1", "name": "大飛び火", "role": "飛び火発生時に追加で飛び火", "desc": "火が燃え尽きる時、周囲48マスの中から2マス同時に飛び火して炎上させる。"},
				{"id": "fire_final_a2", "name": "火種", "role": "飛び火の寿命+1ターン", "desc": "飛び火によって発生した火の寿命が1ターン延長される。"}
			],
			"fire_mid_b": [
				{"id": "fire_final_b1", "name": "蒸気爆発", "role": "火×水接触時3×3消去＆ダメージ", "desc": "自陣の火マスと水マスが接触した瞬間、強烈な蒸気爆発が発生し、周囲3×3の駒を消去して相手に大ダメージを与える。"},
				{"id": "fire_final_b2", "name": "焼き払い", "role": "延焼先の相手妨害マス・石を火マスに置換", "desc": "延焼先が相手の妨害マス（毒・暗雲）や相手の石だった場合、それを焼き払って自陣の火マスに置き換える。"}
			],
			"fire_mid_c": [
				{"id": "fire_final_c1", "name": "榴弾", "role": "破片が相手ダメージ＆着弾マス炎上", "desc": "飛び散った破片が相手にも直撃してダメージを与え、破片の着弾したマスが自陣火マスへと変化する。"},
				{"id": "fire_final_c2", "name": "十字炎", "role": "爆発が十字方向に盤端まで延伸", "desc": "爆発の炎が上下左右の十字方向に盤端まで突き抜け、直線上の駒を一網打尽にする。"}
			]
		}
	},
	"poison": {
		"mid": [
			{"id": "poison_mid_a", "branch": "A", "name": "濃縮", "role": "毒マス段階化(1〜3)・重ね掛け強化", "desc": "自陣の毒マスに段階（1〜3）を持たせ表示する。毒スキルを既存の自陣毒マスに重ねると段階が1上がり、毒ダメージは段階に比例する。"},
			{"id": "poison_mid_b", "branch": "B", "name": "伝染", "role": "毎ターン拡大(上限12)＆相手妨害塗り替え", "desc": "自陣の毒マスが毎ターン隣接空きマス1つへ広がり（上限12）、相手の妨害マスに触れると自陣の毒マスに塗り替える。"},
			{"id": "poison_mid_c", "branch": "C", "name": "弱体", "role": "毒マス1個につき相手攻撃力-3%(最大30%)", "desc": "盤面の自陣毒マス1個につき、相手の攻撃力を3%低下させる（最大30%）。"}
		],
		"final": {
			"poison_mid_a": [
				{"id": "poison_final_a1", "name": "破裂", "role": "段階3毒マッチ消去時周囲4マスに毒散布", "desc": "段階3の自陣毒マスがマッチで消去されると、周囲4マスに段階1の自陣毒マスをまき散らす。"},
				{"id": "poison_final_a2", "name": "熟毒", "role": "ターン終了時毒ダメ発動で段階+1", "desc": "自陣の毒マスがターン終了時にダメージを与えるたびに、その毒マスの段階が1上がる（最大3）。"}
			],
			"poison_mid_b": [
				{"id": "poison_final_b1", "name": "腐食", "role": "毒マス上相手障害物耐久毎ターン-1", "desc": "自陣毒マス上に存在する相手の石や黄金像などの障害物の耐久値を、毎ターン終了時に自動で-1ずつ削剥する。"},
				{"id": "poison_final_b2", "name": "蝕み", "role": "伝染時相手に蝕みスタック(毒ダメ+10%/個)", "desc": "伝染で自陣の毒マスが増えるたび、相手に「蝕み」スタックを付与する（最大5）。1スタックにつき相手の被毒ダメージ+10%。"}
			],
			"poison_mid_c": [
				{"id": "poison_final_c1", "name": "麻痺毒", "role": "相手行動時毒マス数×3%で行動停止(最大30%)", "desc": "相手が行動するとき、自陣の毒マス1個につき3%の確率でその行動を麻痺させて停止させる（最大30%）。"},
				{"id": "poison_final_c2", "name": "毒の種", "role": "毒マス上マッチ時毒スキル駒/毒マス生成", "desc": "自陣毒マスの上の駒がマッチ消去されると、味方なら毒スキル駒が1個出現し、敵なら空きマスに毒マスが1個生成される（1ターン最大1回）。"}
			]
		}
	},
	"earth": {
		"mid": [
			{"id": "earth_mid_a", "branch": "A", "name": "要塞", "role": "石周囲8マス妨害阻止(防ぐたび石耐久-1)", "desc": "自陣の石（輝石）の周囲8マスには相手の妨害マスが置かれない。妨害を1回防ぐたびにその石の耐久値が1減る。"},
			{"id": "earth_mid_b", "branch": "B", "name": "鉱山", "role": "石隣接マッチ時コイン直接獲得(敵はシールド)", "desc": "自陣の石の隣接マスでマッチが起きるたび、味方はコインを直接獲得し、敵はシールドを獲得する。"},
			{"id": "earth_mid_c", "branch": "C", "name": "砕石", "role": "石破壊時耐久比例破片全体ダメージ", "desc": "自陣の石が破壊された時、破片が激しく飛散してその耐久値に応じたダメージを相手に与える。"}
		],
		"final": {
			"earth_mid_a": [
				{"id": "earth_final_a1", "name": "城壁", "role": "自陣石1個につき被ダメ5%軽減(最大40%)", "desc": "自陣の石1個につき、受けるダメージを5%軽減する（最大40%）。"},
				{"id": "earth_final_a2", "name": "飛礫", "role": "石破壊時周囲2マスに耐久1の小石生成", "desc": "自陣の石が壊れると破片が飛び散り、ランダムな周囲2マスに耐久値1の自陣の小石を置く。"}
			],
			"earth_mid_b": [
				{"id": "earth_final_b1", "name": "黄金化", "role": "ターン終了時石1個を黄金像に変化", "desc": "ターン終了時、ランダムな自陣の石1個を自陣の黄金像に変える。"},
				{"id": "earth_final_b2", "name": "金剛", "role": "2ターン残存でダイヤ化＆割ると大量報酬", "desc": "2ターン破壊されずに残った自陣の石がダイヤ輝石へと昇華し、割った時に大量のシールドとコインを獲得できる。"}
			],
			"earth_mid_c": [
				{"id": "earth_final_c1", "name": "連鎖崩落", "role": "破壊時隣接石連鎖粉砕＆合算ダメ", "desc": "自陣の石が破壊された時、隣接する他の石も連鎖して一斉に砕け散り、すべての破壊ダメージが合算されて相手に炸裂する。"},
				{"id": "earth_final_c2", "name": "地割れ", "role": "石破壊時隣接相手妨害マスも破壊", "desc": "自陣の石が壊れると、隣接する相手の妨害マス（石・氷・毒）も一緒に破壊する。"}
			]
		}
	},
	"light": {
		"mid": [
			{"id": "light_mid_a", "branch": "A", "name": "光輝の像", "role": "聖像が毎ターン敵へ聖光自動斉射", "desc": "自陣の聖像（黄金像）が神聖な光を宿し、毎ターン終了時に盤面の全聖像から敵へ聖光弾を自動斉射して追撃する（聖像数×80ダメージ）。"},
			{"id": "light_mid_b", "branch": "B", "name": "聖域の像", "role": "聖像周囲が聖域化(被ダメ25%減&妨害耐性)", "desc": "聖像が神聖な結界を形成し、発動ターンの被ダメージを25%軽減するとともに、聖域内マスへの敵妨害（毒・火・氷・呪い）侵入を防ぐ。"},
			{"id": "light_mid_c", "branch": "C", "name": "共鳴の像", "role": "聖像マッチ時シールド獲得(+200×ステージ倍率)", "desc": "自陣の聖像（黄金像）をマッチ・消去した時、聖なる光が共鳴してシールドを獲得する（200×ステージ倍率）。"}
		],
		"final": {
			"light_mid_a": [
				{"id": "light_final_a1", "name": "黄金郷", "role": "聖像マッチ時超特大聖光追撃＆+1000G", "desc": "自陣の聖像（黄金像）をマッチ・消去した時、黄金郷の祝福が炸裂して敵へ超特大ダメージを与え、獲得コインが2倍(+1000G)になる。"},
				{"id": "light_final_a2", "name": "聖像共振", "role": "全聖像がレーザー連結・ライン一掃", "desc": "光スキル発動時、盤面にある全聖像が共鳴レーザーで相互に連結し、ライン上のコマを一掃消滅させて敵へ貫通大ダメージを与える。"}
			],
			"light_mid_b": [
				{"id": "light_final_b1", "name": "後光の像", "role": "聖像の周囲4マスへの敵妨害設置を無効化", "desc": "自陣の聖像の周囲4マス（上下左右）は、敵スキルの妨害マス設置を無効化する。敵スキル全体は無効化しない。"},
				{"id": "light_final_b2", "name": "加護の像", "role": "毎Tターン終了時HP回復(聖像数×120HP)", "desc": "自陣の聖像が盤面に存在する限り、ターン終了時に自身のHPを持続回復する（聖像数×120 HP）。"}
			],
			"light_mid_c": [
				{"id": "light_final_c1", "name": "起爆の像", "role": "聖像消去時周囲8マス聖光爆発一掃", "desc": "聖像を消去した時、聖なる衝撃波が周囲8マスに広がり、障害物や妨害マスごとコマを一掃消滅させる。"},
				{"id": "light_final_c2", "name": "昇天の像", "role": "聖像消去時スターオーブ確定生成", "desc": "聖像を消去した時、聖像が天へ昇天してそのセルにスターオーブ（特殊アイテム）を生成し、さらなる連鎖を誘発する。"}
			]
		}
	},
	"dark": {
		"mid": [
			{"id": "dark_mid_a", "branch": "A", "name": "歪曲", "role": "闇スキル後1ターン自由スワップ", "desc": "闇スキル発動後1ターンの間、盤面のどの位置にある離れた駒同士でも自由にスワップ交換できる。"},
			{"id": "dark_mid_b", "branch": "B", "name": "代償", "role": "HP消費(8%)で吸引範囲拡大", "desc": "ブラックホール（闇スキル）発動時に自身の現在HPの8%を代償として支払う代わりに、吸引範囲が3×3から5×5へと拡大する。"},
			{"id": "dark_mid_c", "branch": "C", "name": "反動", "role": "被ダメ50%蓄積(上限5000・発動時0リセット)", "desc": "相手から受けたダメージの50%を体内に闇のエネルギーとして蓄積する（最大5000まで蓄積、ブラックホール（闇スキル）発動時に蓄積値は0に戻る）。"}
		],
		"final": {
			"dark_mid_a": [
				{"id": "dark_final_a1", "name": "重力崩壊", "role": "盤面中央3×3を特異点消去", "desc": "闇スキル発動時、盤面中央3×3の駒を特異点へ吸引し、まとめて消去する。"},
				{"id": "dark_final_a2", "name": "空間転移", "role": "闇スキル後3ターン自由スワップ", "desc": "闇スキル発動後3ターンの間、離れた駒同士を自由に交換できる。"}
			],
			"dark_mid_b": [
				{"id": "dark_final_b1", "name": "飽食", "role": "範囲内の敵の石・像・植物を無条件消去", "desc": "吸引範囲内に存在する相手の石・黄金像・植物などの障害物を、耐久値に関係なくすべて呑み込んで完全消滅させる。"},
				{"id": "dark_final_b2", "name": "事象の地平", "role": "吸い込み数比例の闇追撃", "desc": "ブラックホールが呑み込んだ駒・障害物1個につき、相手へ闇属性の追撃ダメージを与える。"}
			],
			"dark_mid_c": [
				{"id": "dark_final_c1", "name": "暗黒の解放", "role": "発動時蓄積ダメージの50%を解放", "desc": "ブラックホール（闇スキル）発動時、これまでに蓄積したダメージの50%を一気に相手へ解放し、追加ダメージとして叩き込む。"},
				{"id": "dark_final_c2", "name": "吸命", "role": "発動時蓄積ダメージの35%をHP回復", "desc": "ブラックホール（闇スキル）発動時、蓄積したダメージの35%を生命力へと反転・転換して自身のHPを回復する。"}
			]
		}
	}
}

# スキル／進化アイコンの割り当て（Texture/skill_icons/skill001.png ～ skill100.png）
# 各属性ごとに「基本 → 中間A/B/C → 最終A1/A2/B1/B2/C1/C2」の順で生成されたアイコンに対応。
# 未生成の進化は同系統の基本スキルアイコン、それも無い属性は元素アイコンへフォールバックする。
const SKILL_ICON_DIR: String = "res://Texture/skill_icons/"
const SKILL_ICON_SOURCE_DIR: String = "res://Texture/skill/"
const SKILL_ICON_INDEX: Dictionary = {
	# --- 水 ---
	"water_1": 1,
	"water_mid_a": 2,
	"water_mid_b": 3,
	"water_mid_c": 4,
	"water_final_a1": 5,
	"water_final_a2": 6,
	"water_final_b1": 7,
	"water_final_b2": 8,
	"water_final_c1": 9,
	"water_final_c2": 10,
	# --- 氷 ---
	"ice_1": 11,
	"ice_mid_a": 12,
	"ice_mid_b": 13,
	"ice_mid_c": 14,
	"ice_final_a1": 15,
	"ice_final_a2": 16,
	"ice_final_b1": 17,
	"ice_final_b2": 18,
	"ice_final_c1": 19,
	"ice_final_c2": 20,
	# --- 木 ---
	"wood_1": 21,
	"wood_mid_a": 22,
	"wood_mid_b": 23,
	"wood_mid_c": 24,
	"wood_final_a1": 25,
	"wood_final_a2": 26,
	"wood_final_b1": 27,
	"wood_final_b2": 28,
	"wood_final_c1": 29,
	"wood_final_c2": 30,
	# --- 風 ---
	"wind_1": 31,
	"wind_mid_a": 32,
	"wind_mid_b": 33,
	"wind_mid_c": 34,
	"wind_final_a1": 35,
	"wind_final_a2": 36,
	"wind_final_b1": 37,
	"wind_final_b2": 38,
	"wind_final_c1": 39,
	"wind_final_c2": 40,
	# --- 火 ---
	"fire_1": 41,
	"fire_mid_a": 42,
	"fire_mid_b": 43,
	"fire_mid_c": 44,
	"fire_final_a1": 45,
	"fire_final_a2": 46,
	"fire_final_b1": 47,
	"fire_final_b2": 48,
	"fire_final_c1": 49,
	"fire_final_c2": 50,
	# --- 雷 ---
	"thunder_1": 51,
	"thunder_mid_a": 52,
	"thunder_mid_b": 53,
	"thunder_mid_c": 54,
	"thunder_final_a1": 55,
	"thunder_final_a2": 56,
	"thunder_final_b1": 57,
	"thunder_final_b2": 58,
	"thunder_final_c1": 59,
	"thunder_final_c2": 60,
	# --- 地 ---
	"earth_1": 61,
	"earth_mid_a": 62,
	"earth_mid_b": 63,
	"earth_mid_c": 64,
	"earth_final_a1": 65,
	"earth_final_a2": 66,
	"earth_final_b1": 67,
	"earth_final_b2": 68,
	"earth_final_c1": 69,
	"earth_final_c2": 70,
	# --- 毒 ---
	"poison_1": 71,
	"poison_mid_a": 72,
	"poison_mid_b": 73,
	"poison_mid_c": 74,
	"poison_final_a1": 75,
	"poison_final_a2": 76,
	"poison_final_b1": 77,
	"poison_final_b2": 78,
	"poison_final_c1": 79,
	"poison_final_c2": 80,
	# --- 光 ---
	"light_1": 81,
	"light_mid_a": 82,
	"light_mid_b": 83,
	"light_mid_c": 84,
	"light_final_a1": 85,
	"light_final_a2": 86,
	"light_final_b1": 87,
	"light_final_b2": 88,
	"light_final_c1": 89,
	"light_final_c2": 90,
	# --- 闇 ---
	"dark_1": 91,
	"dark_mid_a": 92,
	"dark_mid_b": 93,
	"dark_mid_c": 94,
	"dark_final_a1": 95,
	"dark_final_a2": 96,
	"dark_final_b1": 97,
	"dark_final_b2": 98,
	"dark_final_c1": 99,
	"dark_final_c2": 100,
}

## スキルまたは進化IDに対応するアイコンパスを返す。
## evo_id が空なら基本スキルのアイコン。未生成アイコンは同系統の基本アイコン→元素アイコンへ退避。
func get_skill_icon_path(skill_id: String, evo_id: String = "") -> String:
	var icon_key: String = evo_id if evo_id != "" else skill_id
	var icon_idx: int = int(SKILL_ICON_INDEX.get(icon_key, 0))
	if icon_idx <= 0:
		var element_key: String = skill_id.split("_")[0]
		icon_idx = int(SKILL_ICON_INDEX.get(element_key + "_1", 0))
	if icon_idx > 0:
		# 表示用の軽量PNG（円形マスク済み）を優先し、未インポート時は元JPGへ退避
		var icon_path: String = "%sskill%03d.png" % [SKILL_ICON_DIR, icon_idx]
		if ResourceLoader.exists(icon_path):
			return icon_path
		var source_path: String = "%sskill%03d.jpg" % [SKILL_ICON_SOURCE_DIR, icon_idx]
		if ResourceLoader.exists(source_path):
			return source_path

	var element: String = skill_id.split("_")[0]
	var fallback_paths: Array[String] = [
		"res://Texture/element/%s.png" % element,
		"res://Texture/element/%s_tile_dry.png" % element,
	]
	for fallback_path in fallback_paths:
		if ResourceLoader.exists(fallback_path):
			return fallback_path
	return ""

## 現在選択中の進化を反映した表示用アイコン（最終進化 > 中間進化 > 基本）を返す。
func get_skill_display_icon_path(skill_id: String) -> String:
	var final_evo: String = get_chosen_evolution(skill_id, 20)
	if final_evo == "":
		final_evo = get_chosen_evolution(skill_id, 15)
	if final_evo != "":
		return get_skill_icon_path(skill_id, final_evo)
	var mid_evo: String = get_chosen_evolution(skill_id, 10)
	if mid_evo == "":
		mid_evo = get_chosen_evolution(skill_id, 5)
	if mid_evo != "":
		return get_skill_icon_path(skill_id, mid_evo)
	return get_skill_icon_path(skill_id)

## アイコンをTexture2Dとして取得（存在しなければ null）。
func get_skill_icon_texture(skill_id: String, evo_id: String = "") -> Texture2D:
	var icon_path: String = get_skill_icon_path(skill_id, evo_id)
	if icon_path == "":
		return null
	return load(icon_path) as Texture2D

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
		"name": "聖像降臨",
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
		"name": "星影の帳",
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
			{"key": "ice", "name": "氷", "color": "80D8FF", "icon": "res://Texture/element/ice.png", "emoji": "❄️"},
			{"key": "wood", "name": "木", "color": "76FF03", "icon": "res://Texture/element/wood.png", "emoji": "🌱"},
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
	if milestone_lvl <= 10:
		var res: Array[Dictionary] = []
		for item in SKILL_EVOLUTION_REGISTRY[element].get("mid", []):
			res.append(item)
		return res
	elif milestone_lvl > 10:
		var mid_evo = get_chosen_evolution(skill_id, 10)
		if mid_evo == "":
			mid_evo = get_chosen_evolution(skill_id, 5)
		var final_dict = SKILL_EVOLUTION_REGISTRY[element].get("final", {})
		if final_dict is Dictionary and mid_evo != "" and final_dict.has(mid_evo):
			var res: Array[Dictionary] = []
			for item in final_dict[mid_evo]:
				res.append(item)
			return res
		return []
	return []

## スキルの進化特性を選択・記録
func choose_skill_evolution(skill_id: String, milestone_lvl: int, evo_id: String) -> void:
	if not skill_evolutions.has(skill_id):
		skill_evolutions[skill_id] = {}
	var evo_slot = "mid" if milestone_lvl <= 10 else "final"
	skill_evolutions[skill_id][evo_slot] = evo_id
	var cur_lvl: int = 1
	var sp_type: int = 0
	for s_item in skill_tree_items:
		if s_item.get("id") == skill_id:
			s_item["evolution_" + evo_slot] = evo_id
			cur_lvl = int(s_item.get("level", 1))
			sp_type = int(s_item.get("sp_type", 0))
			break
	# スキル欄UIと盤面スキルUIの即時更新
	emit_signal("skill_upgraded", skill_id, sp_type, cur_lvl)
	var pb = _get_puzzle_board()
	if pb and pb.has_method("_update_player_skill_ui"):
		pb._update_player_skill_ui()
	# 属性値欄のアイコンも選択中の進化へ即時追従させる
	update_elem_labels()

## 選択された進化IDを取得
func get_chosen_evolution(skill_id: String, milestone_lvl: int) -> String:
	if not skill_evolutions.has(skill_id):
		return ""
	var evo_slot = "mid" if milestone_lvl <= 10 else "final"
	return skill_evolutions[skill_id].get(evo_slot, "")

## 選択済みの進化を持っているか判定
func has_chosen_evolution(skill_id: String, milestone_lvl: int) -> bool:
	return get_chosen_evolution(skill_id, milestone_lvl) != ""

## 進化データ辞書の取得（name, role, desc等）
func get_evolution_data(skill_id: String, milestone_lvl: int, evo_id: String) -> Dictionary:
	var element = skill_id.split("_")[0]
	if not SKILL_EVOLUTION_REGISTRY.has(element):
		return {}
	for m in SKILL_EVOLUTION_REGISTRY[element].get("mid", []):
		if m.get("id") == evo_id:
			return m
	var fin_dict = SKILL_EVOLUTION_REGISTRY[element].get("final", {})
	if fin_dict is Dictionary:
		for p_id in fin_dict:
			for f in fin_dict[p_id]:
				if f.get("id") == evo_id:
					return f
	return {}

## 進化名の取得
func _get_evolution_name(skill_id: String, milestone_lvl: int, evo_id: String) -> String:
	var d = get_evolution_data(skill_id, milestone_lvl, evo_id)
	return d.get("name", evo_id)

## 指定特性を習得しているか判定（skill_idまたは系統プレフィックス）
func has_skill_trait(skill_id: String, evo_id: String) -> bool:
	if skill_evolutions.has(skill_id):
		var mid_evo = skill_evolutions[skill_id].get("mid", "")
		var fin_evo = skill_evolutions[skill_id].get("final", "")
		if mid_evo == evo_id or fin_evo == evo_id:
			return true
	var el_prefix = skill_id.split("_")[0]
	for sk in skill_evolutions:
		if sk.begins_with(el_prefix):
			var mid_evo = skill_evolutions[sk].get("mid", "")
			var fin_evo = skill_evolutions[sk].get("final", "")
			if mid_evo == evo_id or fin_evo == evo_id:
				return true
	return false


func _init() -> void:
	for s_item in skill_tree_items:
		s_item["max_level"] = 20
		s_item["desc_lv"] = get_skill_descriptions(s_item["id"])
	_register_skill_glossary_terms()

## スキル名・進化名を用語辞書へ登録し、スキルツリーや説明文からホバー解説できるようにする。
func _register_skill_glossary_terms() -> void:
	var elem_colors: Dictionary = {
		"water": "00B0FF", "ice": "80D8FF", "wood": "76FF03", "wind": "69F0AE",
		"fire": "FF3D00", "thunder": "FFD600", "earth": "D7CCC8",
		"poison": "B388FF", "light": "FFF59D", "dark": "EA80FC"
	}
	for s_item in skill_tree_items:
		var desc_arr: Array = s_item.get("desc_lv", [])
		var desc: String = str(desc_arr[0]) if not desc_arr.is_empty() else ""
		var col: String = "#" + str(elem_colors.get(str(s_item["id"]).split("_")[0], "FFD54F"))
		GlossaryDatabase.register_term(str(s_item.get("name", "")), str(s_item.get("name", "")), desc, col)

	for elem in SKILL_EVOLUTION_REGISTRY:
		var col: String = "#" + str(elem_colors.get(elem, "FFD54F"))
		for mid_evo in SKILL_EVOLUTION_REGISTRY[elem].get("mid", []):
			GlossaryDatabase.register_term(str(mid_evo.get("name", "")), str(mid_evo.get("name", "")), str(mid_evo.get("desc", "")), col)
		var final_map = SKILL_EVOLUTION_REGISTRY[elem].get("final", {})
		if final_map is Dictionary:
			for mid_id in final_map:
				for fin_evo in final_map[mid_id]:
					GlossaryDatabase.register_term(str(fin_evo.get("name", "")), str(fin_evo.get("name", "")), str(fin_evo.get("desc", "")), col)

## スキルごとのLv1〜20の詳細効果テキスト生成
## 実際の戦闘処理（puzzle_board.gd の cast_player_skill）の数値に合わせて生成する。
static func get_skill_descriptions(skill_id: String) -> Array[String]:
	var legacy_map: Dictionary = {
		"bomb": "fire_1", "cross_bomb": "fire_2", "gemini_bomb": "fire_3",
		"lightning": "thunder_1", "charge_bomb": "thunder_3",
		"aqua_splash": "water_1", "tree_sprout": "wood_1", "color_converter": "wood_2",
		"tornado": "wind_1", "disco_ball": "light_3", "holy_star": "light_1", "holy_light": "light_1", "magnet": "light_1", "black_hole": "dark_3",
		"poison_mist": "poison_1"
	}
	var real_id = legacy_map.get(skill_id, skill_id)
	var elem: String = str(real_id).split("_")[0]
	if not str(real_id).ends_with("_1") or not ["water", "ice", "wood", "wind", "fire", "thunder", "earth", "poison", "light", "dark"].has(elem):
		return ["効果強化 (Lv1)"]

	var arr: Array[String] = []
	for lvl in range(1, 21):
		var text: String = _base_skill_description(elem, lvl)
		if lvl == 10:
			text += _evolution_note(elem, 10)
		elif lvl == 20:
			text += _evolution_note(elem, 20)
		arr.append(text)
	return arr

static func _base_skill_description(elem: String, lvl: int) -> String:
	match elem:
		"water":
			return "【清流展開】中心から円形範囲に水マスを最大%d個生成し、そのマス上の駒を消去。直撃威力%d。" % [2 + lvl / 2, 80 + lvl * 15]
		"ice":
			return "【氷盾付与】氷マスを最大%d個生成（耐久3）。隣接する敵効果マスの進行・拡散を無効化。そのマス上でマッチすると耐久-1。炎で融解、雷で破砕。直撃威力%d。" % [2 + lvl / 2, 80 + lvl * 15]
		"wood":
			return "【命の萌芽】苗木を1本植樹。苗木は毎ターンHPを回復し、水を吸うと成長。直撃威力%d。" % [60 + lvl * 12]
		"wind":
			return "【疾風突風】盤面全体の敵効果マスを一掃し、縦%d列に竜巻を放つ。直撃威力%d。3レベルごとに列数が増加し、それ以外のレベルでは威力が上昇する。（突風進化で通過列の駒も消去、レリック/進化で列数拡張）" % [1 + lvl / 3, 80 + lvl * 15]
		"fire":
			return "【紅蓮爆破】炎マスを最大%d個生成し、そのマス上の駒を消去。直撃威力%d。" % [2 + lvl / 2, 100 + lvl * 20]
		"thunder":
			return "【雷電連鎖】帯電マスを最大%d個生成し、ランダムな1列に落雷。直撃威力%d。（レリックで帯電数増加）" % [2 + lvl / 2, 90 + lvl * 18]
		"earth":
			return "【岩盤崩落】味方の輝石マスを最大%d個生成（耐久2）。マッチまたは雷で破砕。発動時シールド+%d。直撃威力%d。" % [2 + lvl / 3, 150 + lvl * 30, 80 + lvl * 15]
		"poison":
			return "【瘴気毒霧】毒マスを最大%d個生成し、その上の駒を消去。毎ターン毒ダメージを与え、隣接マスへ伝染。直撃威力%d。" % [2 + lvl / 2, 80 + lvl * 15]
		"light":
			return "【聖像降臨】聖像を最大%d体召喚（耐久2）。破壊時に+500G獲得＆敵へ光ダメージ。発動時シールド+%d。直撃威力%d。" % [2 + lvl / 2, 80 + lvl * 15, 100 + lvl * 20]
		"dark":
			return "【星影の帳】2×2の星影の霧を3ターン生成し、影護マスを最大%d個生成。影護マスをマッチで消すと敵へ闇ダメージ＆自身回復。直撃威力%d。" % [2 + lvl / 2, 80 + lvl * 15]
	return "効果強化 (Lv1)"

static func _evolution_note(elem: String, lvl: int) -> String:
	if lvl == 10:
		var names: Array[String] = []
		var elem_data: Dictionary = SKILL_EVOLUTION_REGISTRY.get(elem, {})
		for m in elem_data.get("mid", []):
			names.append(str(m.get("name", "")))
		if not names.is_empty():
			return "\n【中間進化開放 (Lv.10)】" + " / ".join(names) + " から1つ選択。"
	if lvl == 20:
		return "\n【最終進化開放 (Lv.20)】選択した中間進化に応じた2つの大技特性から1つ選択。"
	return ""

func _ready() -> void:
	# フォントにシステム日本語フォールバックを設定（あらゆる漢字の確実な描画を保証）
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = load("res://font/NotoSansJP.ttf")
		CUSTOM_FONT.set_fallbacks([sys_font, load("res://font/NotoEmoji.ttf")])

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
		sc2_rect.color = Color(0.02, 0.02, 0.03, 0.70)
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
			status2_rect.color = Color(0.02, 0.02, 0.03, 0.70)

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
	var combo_font = load("res://font/NotoSansJP.ttf")

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
		cb_rect2.color = Color(0.02, 0.02, 0.03, 0.70)

	var scn_rect2 = get_node_or_null("screen2") as ColorRect
	if scn_rect2:
		scn_rect2.color = Color(0.85, 0.72, 0.38, 1.0)
	var scn_rect = get_node_or_null("screen") as ColorRect
	if scn_rect:
		scn_rect.color = Color(0.02, 0.02, 0.03, 0.70)

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
		fv_rect2.color = Color(0.02, 0.02, 0.03, 0.70)

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
func _is_pvp_mode() -> bool:
	var net = get_node_or_null("/root/NetworkManager")
	return net != null and "pvp_mode" in net and bool(net.pvp_mode)

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
		template_score_label = RichTextLabel.new()
		template_score_label.name = "RichTextLabel3"
		add_child(template_score_label)
	for i in range(12):
		var popup: RichTextLabel = template_score_label.duplicate()
		popup.bbcode_enabled = true
		popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_theme_font_override("normal_font", CUSTOM_FONT)
		popup.add_theme_font_override("bold_font", CUSTOM_FONT)
		popup.add_theme_constant_override("outline_size", 8)
		popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		popup.add_theme_font_size_override("normal_font_size", 32)
		popup.add_theme_font_size_override("bold_font_size", 36)
		popup.fit_content = false
		popup.autowrap_mode = TextServer.AUTOWRAP_OFF
		popup.size = Vector2(320.0, 80.0)
		popup.pivot_offset = Vector2(160.0, 40.0)
		popup.z_index = 35
		popup.visible = false
		add_child(popup)
		_popup_pool.append(popup)

func _get_or_create_popup() -> RichTextLabel:
	for popup in _popup_pool:
		if not popup.visible:
			return popup
	if _popup_pool.size() < MAX_POOLED_POPUPS:
		if template_score_label == null:
			template_score_label = get_node_or_null("RichTextLabel3")
		var popup: RichTextLabel = template_score_label.duplicate() if template_score_label != null else RichTextLabel.new()
		popup.bbcode_enabled = true
		popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_theme_font_override("normal_font", CUSTOM_FONT)
		popup.add_theme_font_override("bold_font", CUSTOM_FONT)
		popup.add_theme_constant_override("outline_size", 8)
		popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		popup.add_theme_font_size_override("normal_font_size", 32)
		popup.add_theme_font_size_override("bold_font_size", 36)
		popup.fit_content = false
		popup.autowrap_mode = TextServer.AUTOWRAP_OFF
		popup.size = Vector2(320.0, 80.0)
		popup.pivot_offset = Vector2(160.0, 40.0)
		popup.z_index = 35
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

## マッチした駒グループにスタイリッシュなスコアポップアップを生成（現在あるスコア欄の位置に加算値をポップアップ）
func _spawn_score_popup(component_cells: Array, att_type: int, earned_score: int, count: int, is_fever: bool) -> void:
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

	var score_text = "[center][b][color=%s]+%s[/color][/b][/center]" % [col, _format_comma(earned_score)]
	popup.text = header + score_text

	# 現在あるスコア欄 (score_rect: x: 1190.0, y: 472.0, w: 725.0, h: 66.0) の位置に合わせてポップアップ
	var base_x: float = 1520.0 + randf_range(-30.0, 30.0)
	var base_y: float = 465.0
	popup.position = Vector2(base_x, base_y)
	popup.scale = Vector2(0.3, 0.3)
	popup.modulate.a = 1.0
	popup.visible = true

	# ポップアップ・Tweenアニメーション（勢いよく飛び出してフワッと消える）
	var p_tween = create_tween()
	p_tween.tween_property(popup, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p_tween.parallel().tween_property(popup, "position:y", base_y - 20.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p_tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.08)

	p_tween.chain().tween_interval(0.35)
	p_tween.tween_property(popup, "position:y", base_y - 45.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p_tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.22)
	p_tween.chain().tween_callback(func(): popup.visible = false)

## マッチした駒のスコアおよび属性ポイントを計算
func calcscore(match_index: Array, grid_att: Array, grid_element: Array = [], source: String = "ally") -> void:
	if source == "enemy":
		return
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
				# Easyモードではコイン・ポーションの獲得量を増加
				if att_type == PieceType.COIN or att_type == PieceType.POTION:
					gain = int(round(float(gain) * _get_difficulty_reward_mult()))
				if att_type < divscore.size():
					divscore[att_type] += gain

				# 雷進化特性：コインを消去するたび敵に感電ダメージ
				if att_type == PieceType.COIN:
					if has_skill_trait("thunder_1", "thunder_mid_conduct") or has_skill_trait("thunder_1", "thunder_mid_magnetic"):
						var sk_lvl: int = maxi(1, get_skill_level("thunder_1"))
						var st_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))
						var zap_dmg: float = float(count) * (30.0 + sk_lvl * 8.0) * st_scale
						if sm and sm.ehp > 0 and not sm.isdeadf:
							sm.calchp(zap_dmg, 0.0)
							if pb and pb.has_method("_emit_combat_event"):
								pb._emit_combat_event("damage", "ally", "enemy", zap_dmg, "thunder_coin")
							if pb and not component_cells.is_empty():
								var coin_p = pb.get_cell_position(component_cells[0].x, component_cells[0].y)
								pb._spawn_shock_zap_effect(coin_p)
								pb._spawn_floating_text(coin_p, "⚡ 金貨感電 -%d!" % int(zap_dmg), Color(1.0, 0.95, 0.2))
		
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
	if skill_levels.has(skill_id):
		return int(skill_levels[skill_id])
	var s = get_skill_by_id(skill_id)
	return int(s.get("level", 0))

func set_skill_level(skill_id: String, lvl: int) -> void:
	skill_levels[skill_id] = lvl
	var s = get_skill_by_id(skill_id)
	if not s.is_empty():
		s["level"] = lvl

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

	# 前に進むボタン（ショップ枠 y=896 より下、画面右側 x: 1480..1880, y: 974..1050 に配置）
	var sc_btn = get_node_or_null("stagechangeb") as Button
	if sc_btn:
		sc_btn.position = Vector2(1480, 974)
		sc_btn.size = Vector2(400, 76)
		sc_btn.custom_minimum_size = Vector2(400, 76)
		sc_btn.z_index = 100
		sc_btn.text = "⚔️ 次の戦いへ進む"
		sc_btn.add_theme_font_size_override("font_size", 26)
		var sc_style = StyleBoxFlat.new()
		sc_style.bg_color = Color(0.18, 0.44, 0.24, 0.90)
		sc_style.border_color = Color(0.95, 0.82, 0.35, 1.0)
		sc_style.set_border_width_all(2)
		sc_style.set_corner_radius_all(10)
		sc_style.shadow_color = Color(0, 0, 0, 0.6)
		sc_style.shadow_size = 6
		sc_btn.add_theme_stylebox_override("normal", sc_style)
		var sc_hov = sc_style.duplicate()
		sc_hov.bg_color = Color(0.24, 0.56, 0.30, 0.95)
		sc_btn.add_theme_stylebox_override("hover", sc_hov)
		var sc_press = sc_style.duplicate()
		sc_press.bg_color = Color(0.12, 0.32, 0.16, 0.95)
		sc_btn.add_theme_stylebox_override("pressed", sc_press)
		sc_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))

	if shop_root_panel != null:
		return

	var jp_font = _get_jp_font()

	# ショップウィンドウ本体 (x: 20..1900, y: 16..896) -> 右端を1880pxまで大幅拡張し、下部の進むボタン(y=974)と被らない独立配置
	shop_root_panel = Panel.new()
	shop_root_panel.name = "ShopAndSkillTreePanel"
	shop_root_panel.position = Vector2(20, 16)
	shop_root_panel.size = Vector2(1880, 880)
	shop_root_panel.z_index = 30
	shop_root_panel.visible = false

	# 重厚なアンティークゴールド外枠 ＆ 半透過オブシディアンベルベット調ベース
	var root_style = StyleBoxFlat.new()
	root_style.bg_color = Color(0.01, 0.01, 0.02, 0.72)
	root_style.border_color = Color(0.85, 0.72, 0.38, 0.95)
	root_style.set_border_width_all(3)
	root_style.set_corner_radius_all(16)
	root_style.shadow_color = Color(0, 0, 0, 0.8)
	root_style.shadow_size = 20
	shop_root_panel.add_theme_stylebox_override("panel", root_style)
	parent.add_child.call_deferred(shop_root_panel)

	# --- 上部ヘッダーバー（半透過ダークブロンズ調） ---
	var header_bg = Panel.new()
	header_bg.position = Vector2(16, 12)
	header_bg.size = Vector2(1848, 76)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.02, 0.02, 0.03, 0.65)
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
	shop_tab_btn.text = "ショップ (コイン強化)"
	shop_tab_btn.icon = load("res://Texture/coin/coin_cut.png")
	shop_tab_btn.expand_icon = true
	shop_tab_btn.add_theme_constant_override("icon_max_width", 24)
	shop_tab_btn.add_theme_constant_override("h_separation", 8)
	shop_tab_btn.add_theme_font_override("font", jp_font)
	shop_tab_btn.add_theme_font_size_override("font_size", 21)
	shop_tab_btn.focus_mode = Control.FOCUS_NONE
	shop_tab_btn.pressed.connect(func(): _switch_shop_view_mode(0))
	header_bg.add_child(shop_tab_btn)

	skill_tab_btn = Button.new()
	skill_tab_btn.position = Vector2(588, 10)
	skill_tab_btn.size = Vector2(360, 56)
	skill_tab_btn.text = "スキルツリー (秘薬強化)"
	skill_tab_btn.icon = load("res://Texture/potion/potion_cut.png")
	skill_tab_btn.expand_icon = true
	skill_tab_btn.add_theme_constant_override("icon_max_width", 24)
	skill_tab_btn.add_theme_constant_override("h_separation", 8)
	skill_tab_btn.add_theme_font_override("font", jp_font)
	skill_tab_btn.add_theme_font_size_override("font_size", 21)
	skill_tab_btn.focus_mode = Control.FOCUS_NONE
	skill_tab_btn.pressed.connect(func(): _switch_shop_view_mode(1))
	header_bg.add_child(skill_tab_btn)

	# 所持コイン＆余剰ポーション表示ボックス（数値が見切れないよう横に拡張）
	var coin_box = Panel.new()
	coin_box.position = Vector2(960, 10)
	coin_box.size = Vector2(420, 56)
	var cbox_style = StyleBoxFlat.new()
	cbox_style.bg_color = Color(0.02, 0.02, 0.03, 0.65)
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
	coin_currency_lbl.position = Vector2(8, 10)
	coin_currency_lbl.size = Vector2(404, 38)
	coin_currency_lbl.add_theme_font_override("normal_font", jp_font)
	coin_currency_lbl.add_theme_font_override("bold_font", jp_font)
	coin_currency_lbl.add_theme_font_size_override("normal_font_size", 18)
	coin_currency_lbl.add_theme_font_size_override("bold_font_size", 21)
	coin_box.add_child(coin_currency_lbl)

	var potion_box = Panel.new()
	potion_box.position = Vector2(1392, 10)
	potion_box.size = Vector2(420, 56)
	var pbox_style = StyleBoxFlat.new()
	pbox_style.bg_color = Color(0.02, 0.02, 0.03, 0.65)
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
	potion_currency_lbl.position = Vector2(8, 10)
	potion_currency_lbl.size = Vector2(404, 38)
	potion_currency_lbl.add_theme_font_override("normal_font", jp_font)
	potion_currency_lbl.add_theme_font_override("bold_font", jp_font)
	potion_currency_lbl.add_theme_font_size_override("normal_font_size", 18)
	potion_currency_lbl.add_theme_font_size_override("bold_font_size", 21)
	potion_box.add_child(potion_currency_lbl)

	# タブとコンテンツを地続きに見せる共通背景（選択中タブと同じ色で塗る）
	shop_content_bg = Panel.new()
	shop_content_bg.name = "ShopContentBackground"
	shop_content_bg.position = Vector2(16, 88)
	shop_content_bg.size = Vector2(1848, 778)
	shop_content_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_root_panel.add_child(shop_content_bg)

	# --- 1. ショップビュー（コイン購入：獲得スコア・体力強化） ---
	shop_view_container = Control.new()
	shop_view_container.position = Vector2(16, 88)
	shop_view_container.size = Vector2(1848, 778)
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
		c_style.bg_color = Color(0.02, 0.02, 0.04, 0.65)
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
		hr_style.bg_color = Color(0.03, 0.03, 0.05, 0.70)
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

		var desc_lbl = RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.scroll_active = false
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.position = Vector2(108, 94)
		desc_lbl.size = Vector2(400, 48)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		desc_lbl.add_theme_font_override("normal_font", jp_font)
		desc_lbl.add_theme_font_override("bold_font", jp_font)
		desc_lbl.add_theme_font_size_override("normal_font_size", 16)
		desc_lbl.add_theme_font_size_override("bold_font_size", 16)
		desc_lbl.text = GlossaryDatabase.format_text(item["desc"])
		GlossaryDatabase.bind_rich_text_label(desc_lbl)
		card.add_child(desc_lbl)

		var stat_box = Panel.new()
		stat_box.position = Vector2(18, 146)
		stat_box.size = Vector2(494, 114)
		var sb_style = StyleBoxFlat.new()
		sb_style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		sb_style.border_color = Color(0.24, 0.30, 0.42, 0.70)
		sb_style.set_border_width_all(1)
		sb_style.set_corner_radius_all(10)
		stat_box.add_theme_stylebox_override("panel", sb_style)
		card.add_child(stat_box)

		var stat_lbl = RichTextLabel.new()
		stat_lbl.bbcode_enabled = true
		stat_lbl.scroll_active = false
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		GlossaryDatabase.bind_rich_text_label(stat_lbl)
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
		buy_btn.icon = load("res://Texture/coin/coin_cut.png")
		buy_btn.expand_icon = true
		buy_btn.add_theme_constant_override("icon_max_width", 30)
		buy_btn.add_theme_constant_override("h_separation", 8)
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
			"desc_lbl": desc_lbl,
			"stat_lbl": stat_lbl,
			"buy_btn": buy_btn
		})

	# --- 2. スキルツリービュー（余剰ポーション使用：スキル獲得・強化） ---
	skill_tree_container = Control.new()
	skill_tree_container.position = Vector2(16, 88)
	skill_tree_container.size = Vector2(1848, 778)
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
	var rm = _get_relic_manager()
	if rm:
		if rm.chosen_element_category != cat_key:
			rm.chosen_element_category = cat_key
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
			c_style.bg_color = Color(0.02, 0.02, 0.04, 0.65)
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
			c_dbg_st.bg_color = Color(0.12, 0.28, 0.38, 0.85)
			c_dbg_st.border_color = Color(0.3, 0.85, 1.0, 0.9)
			c_dbg_st.set_border_width_all(2)
			c_dbg_st.set_corner_radius_all(10)
			c_dbg_btn.add_theme_stylebox_override("normal", c_dbg_st)
			var chosen_k_cap = c_k
			c_dbg_btn.pressed.connect(func(): on_element_category_chosen(chosen_k_cap))
			if OS.is_debug_build():
				card.add_child(c_dbg_btn)
		return

	# カテゴリー選択済みの場合：選択されたカテゴリーのツリーを表示！
	var cat_data = CATEGORY_TREE_DEFS[cat_key]
	var banner = Label.new()
	banner.position = Vector2(8, 0)
	banner.size = Vector2(980, 32)
	banner.text = cat_data["banner"]

	# 🛠️ デバッグクイックバー
	if OS.is_debug_build():
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

		var base_icon_path: String = get_skill_icon_path(s_item["id"])
		if base_icon_path != "":
			var badge_icon = TextureRect.new()
			badge_icon.position = Vector2(4, 4)
			badge_icon.size = Vector2(48, 48)
			badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge_icon.texture = load(base_icon_path)
			badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_child(badge_icon)
		else:
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
		s_title.add_theme_font_size_override("font_size", 26)
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
		recipe_lbl.add_theme_font_size_override("font_size", 16)
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
		s_desc.mouse_filter = Control.MOUSE_FILTER_PASS
		GlossaryDatabase.bind_rich_text_label(s_desc)
		s_desc.position = Vector2(8, 6)
		s_desc.size = Vector2(col_w - 44, 108)
		s_desc.add_theme_font_override("normal_font", jp_font)
		s_desc.add_theme_font_override("bold_font", jp_font)
		s_desc.add_theme_font_size_override("normal_font_size", 18)
		s_desc.add_theme_font_size_override("bold_font_size", 18)
		desc_panel.add_child(s_desc)

		# 4. 【中間進化 (Lv.5)】進化特性スロット
		var mid_evo_panel = Panel.new()
		mid_evo_panel.position = Vector2(14, 246)
		mid_evo_panel.size = Vector2(col_w - 28, 156)
		node_card.add_child(mid_evo_panel)

		var mid_evo_icon = TextureRect.new()
		mid_evo_icon.position = Vector2(10, 12)
		mid_evo_icon.size = Vector2(56, 56)
		mid_evo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mid_evo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mid_evo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid_evo_icon.texture = get_skill_icon_texture(s_item["id"])
		mid_evo_icon.modulate = Color(1, 1, 1, 0.42)
		mid_evo_panel.add_child(mid_evo_icon)

		var mid_evo_lbl = RichTextLabel.new()
		mid_evo_lbl.bbcode_enabled = true
		mid_evo_lbl.scroll_active = false
		mid_evo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid_evo_lbl.position = Vector2(76, 8)
		mid_evo_lbl.size = Vector2(col_w - 114, 140)
		mid_evo_lbl.add_theme_font_override("normal_font", jp_font)
		mid_evo_lbl.add_theme_font_override("bold_font", jp_font)
		GlossaryDatabase.bind_rich_text_label(mid_evo_lbl)
		mid_evo_panel.add_child(mid_evo_lbl)

		# 5. 【最終進化 (Lv.15)】最終進化特性スロット
		var final_evo_panel = Panel.new()
		final_evo_panel.position = Vector2(14, 410)
		final_evo_panel.size = Vector2(col_w - 28, 170)
		node_card.add_child(final_evo_panel)

		var final_evo_icon = TextureRect.new()
		final_evo_icon.position = Vector2(10, 12)
		final_evo_icon.size = Vector2(56, 56)
		final_evo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		final_evo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		final_evo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		final_evo_icon.texture = get_skill_icon_texture(s_item["id"])
		final_evo_icon.modulate = Color(1, 1, 1, 0.42)
		final_evo_panel.add_child(final_evo_icon)

		var final_evo_lbl = RichTextLabel.new()
		final_evo_lbl.bbcode_enabled = true
		final_evo_lbl.scroll_active = false
		final_evo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		final_evo_lbl.position = Vector2(76, 8)
		final_evo_lbl.size = Vector2(col_w - 114, 154)
		final_evo_lbl.add_theme_font_override("normal_font", jp_font)
		final_evo_lbl.add_theme_font_override("bold_font", jp_font)
		GlossaryDatabase.bind_rich_text_label(final_evo_lbl)
		final_evo_panel.add_child(final_evo_lbl)

		# 6. 下部アクション操作部（強化ボタン & デバッグレベルアップ）
		var s_btn = Button.new()
		s_btn.position = Vector2(14, 592)
		s_btn.size = Vector2(col_w - 28 - 96, 62)
		s_btn.icon = load("res://Texture/potion/potion_cut.png")
		s_btn.expand_icon = true
		s_btn.add_theme_constant_override("icon_max_width", 30)
		s_btn.add_theme_constant_override("h_separation", 8)
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
					d_str = recipe_info + "[font_size=22][color=#FFD700]【最大レベル】[/color]\n%s[/font_size]" % cur_d
				elif c_lvl == 0:
					d_str = recipe_info + "[font_size=22][color=#AAAAAA]【未習得】[/color]\n習得効果 (Lv1): %s[/font_size]" % next_d
				else:
					d_str = recipe_info + "[font_size=22]現在 (Lv%d): %s\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [c_lvl, cur_d, c_lvl + 1, next_d]
				var evo_mid = get_chosen_evolution(card_skill_id, 10)
				if evo_mid == "":
					evo_mid = get_chosen_evolution(card_skill_id, 5)
				var evo_final = get_chosen_evolution(card_skill_id, 20)
				if evo_mid != "" or evo_final != "":
					d_str += "\n\n[color=#FFE082]"
					if evo_mid != "":
						var mid_name = _get_evolution_name(card_skill_id, 10, evo_mid)
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
			"mid_evo_icon": mid_evo_icon,
			"mid_evo_lbl": mid_evo_lbl,
			"final_evo_panel": final_evo_panel,
			"final_evo_icon": final_evo_icon,
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
	_update_shop_tab_styles()
	_update_buff_button_labels()

func _on_prev_page_pressed() -> void:
	_switch_shop_view_mode(0)

func _on_next_page_pressed() -> void:
	_switch_shop_view_mode(1)

## ショップ内の「⚔️ 次に進む」ボタン押下時
func _on_shop_proceed_pressed() -> void:
	set_shop_ui_visible(false)
	var sm = _get_stage_manager()
	if sm:
		if "isstageclear" in sm and sm.isstageclear:
			sm._on_stagechangeb_pressed()
		elif sm.has_method("_on_movefront_pressed"):
			sm._on_movefront_pressed()

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
		var rm_ui = parent.get_node_or_null("RelicUIManager")
		if rm_ui and rm_ui.has_method("set_bottom_bars_visible"):
			rm_ui.set_bottom_bars_visible(!is_vis)
		var sm = parent.get_node_or_null("StageManager")
		if sm and "move_front_btn" in sm and sm.move_front_btn:
			sm.move_front_btn.z_index = 100
			if is_vis: sm.move_front_btn.visible = true
	_update_buff_button_labels()

## 選択中タブとコンテンツ背景を同じ色で地続きにし、非選択タブを奥に見せる
func _update_shop_tab_styles() -> void:
	if shop_tab_btn == null or skill_tab_btn == null:
		return

	var active_shop: bool = (current_view_mode == 0)
	var content_bg: Color = Color(0.075, 0.060, 0.028, 1.0) if active_shop else Color(0.070, 0.030, 0.075, 1.0)
	var accent: Color = Color(0.95, 0.82, 0.35, 1.0) if active_shop else Color(0.95, 0.45, 0.80, 1.0)

	# コンテンツ側は上辺の境界線を描かず、選択中タブと同じ背景色にする
	if shop_content_bg != null and is_instance_valid(shop_content_bg):
		var content_style = StyleBoxFlat.new()
		content_style.bg_color = content_bg
		content_style.border_color = accent
		content_style.border_width_left = 1
		content_style.border_width_right = 1
		content_style.border_width_top = 0
		content_style.border_width_bottom = 1
		content_style.corner_radius_bottom_left = 14
		content_style.corner_radius_bottom_right = 14
		shop_content_bg.add_theme_stylebox_override("panel", content_style)

	var active_btn: Button = shop_tab_btn if active_shop else skill_tab_btn
	var inactive_btn: Button = skill_tab_btn if active_shop else shop_tab_btn

	# 選択中タブ: 上端まで伸び、下端はコンテンツと同色・境界線なしで接続
	active_btn.position = Vector2(active_btn.position.x, 0)
	active_btn.size = Vector2(active_btn.size.x, 76)
	active_btn.z_index = 3
	var active_style = StyleBoxFlat.new()
	# 選択中タブも外側との境界が分かるよう、黄色い線で囲む
	active_style.bg_color = content_bg
	active_style.border_color = Color(1.0, 0.86, 0.22, 1.0)
	active_style.set_border_width_all(3)
	# 下側の線はコンテンツと繋がるため描かない
	active_style.border_width_bottom = 0
	active_style.corner_radius_top_left = 12
	active_style.corner_radius_top_right = 12
	active_btn.add_theme_stylebox_override("normal", active_style)
	active_btn.add_theme_stylebox_override("hover", active_style)
	active_btn.add_theme_stylebox_override("pressed", active_style)
	active_btn.add_theme_color_override("font_color", accent.lightened(0.22))

	# 非選択タブ: 高さを下げて暗い背景にし、一段奥にあるように見せる
	inactive_btn.position = Vector2(inactive_btn.position.x, 14)
	inactive_btn.size = Vector2(inactive_btn.size.x, 60)
	inactive_btn.z_index = 1
	var inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.035, 0.040, 0.055, 1.0)
	# 非選択タブも黄色い線で囲み、外側との境界を明確にする（選択中より少し暗い黄色）
	inactive_style.border_color = Color(0.82, 0.68, 0.20, 0.95)
	inactive_style.set_border_width_all(2)
	# 下側の線は描かない
	inactive_style.border_width_bottom = 0
	inactive_style.corner_radius_top_left = 10
	inactive_style.corner_radius_top_right = 10
	inactive_btn.add_theme_stylebox_override("normal", inactive_style)
	var inactive_hover = inactive_style.duplicate()
	inactive_hover.bg_color = Color(0.060, 0.070, 0.090, 1.0)
	inactive_btn.add_theme_stylebox_override("hover", inactive_hover)
	inactive_btn.add_theme_stylebox_override("pressed", inactive_style)
	inactive_btn.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))

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

	_update_shop_tab_styles()

	# 1. ショップカードの更新
	var sm = _get_stage_manager()
	var stage_num: int = sm.stage if sm and "stage" in sm else 1
	var hp_step: int = int(maxf(HP_SHOP_FLAT_GAIN * pow(10.0, maxf(0.0, float(stage_num - 1))), (sm.myhpmax if sm and "myhpmax" in sm else 5000.0) * HP_SHOP_PERCENT_GAIN))

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
		ref["stat_lbl"].text = GlossaryDatabase.format_text(stat_text)

		var btn: Button = ref["buy_btn"]
		btn.disabled = not can_buy
		btn.text = "%s コインで強化" % _format_comma(cost_val)

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
			card_style.bg_color = Color(0.02, 0.02, 0.04, 0.65)
			card_style.border_color = s_item["color"] if not is_max else Color("#FFD700")
			card_style.set_border_width_all(2)
			card_style.border_width_left = 6
		else:
			card_style.bg_color = Color(0.01, 0.01, 0.03, 0.65)
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
		# 進化バッジは用語リンク化せず、元の表記のまま表示する
		s_ref["s_desc"].text = GlossaryDatabase.format_text(s_ref["s_desc"].text)
		var evo_mid = get_chosen_evolution(s_item["id"], 10)
		if evo_mid == "":
			evo_mid = get_chosen_evolution(s_item["id"], 5)
		var evo_final = get_chosen_evolution(s_item["id"], 20)
		# 進化アイコンの更新（未選択時は基本スキルアイコンを暗く表示）
		var mid_icon: TextureRect = s_ref.get("mid_evo_icon")
		if mid_icon:
			var mid_icon_path: String = get_skill_icon_path(s_item["id"], evo_mid) if evo_mid != "" else get_skill_icon_path(s_item["id"])
			mid_icon.texture = load(mid_icon_path) if mid_icon_path != "" else null
			mid_icon.modulate = Color.WHITE if evo_mid != "" else Color(1, 1, 1, 0.35)
		var final_icon: TextureRect = s_ref.get("final_evo_icon")
		if final_icon:
			var final_evo_for_icon: String = evo_final if evo_final != "" else evo_mid
			var final_icon_path: String = get_skill_icon_path(s_item["id"], final_evo_for_icon) if final_evo_for_icon != "" else get_skill_icon_path(s_item["id"])
			final_icon.texture = load(final_icon_path) if final_icon_path != "" else null
			final_icon.modulate = Color.WHITE if evo_final != "" else Color(1, 1, 1, 0.35)

		if evo_mid != "" or evo_final != "":
			var evo_info_str = "\n"
			if evo_mid != "":
				var mid_name = _get_evolution_name(s_item["id"], 10, evo_mid)
				evo_info_str += "[url=%s][color=#FFE082]【第1進化: %s】[/color][/url] " % [mid_name, mid_name]
			if evo_final != "":
				var final_name = _get_evolution_name(s_item["id"], 20, evo_final)
				evo_info_str += "[url=%s][color=#FFE082]【最終進化: %s】[/color][/url]" % [final_name, final_name]
			s_ref["s_desc"].text += evo_info_str

		# 第1覚醒 (Lv.10) スロット更新
		var mid_panel: Panel = s_ref.get("mid_evo_panel")
		var mid_lbl: RichTextLabel = s_ref.get("mid_evo_lbl")
		if mid_panel and mid_lbl:
			var mp_st = StyleBoxFlat.new()
			mp_st.set_corner_radius_all(10)
			mp_st.set_border_width_all(2)
			if evo_mid != "":
				var mid_data = get_evolution_data(s_item["id"], 10, evo_mid)
				mp_st.bg_color = Color(0.04, 0.08, 0.12, 0.70)
				mp_st.border_color = Color(0.3, 0.85, 1.0, 0.95)
				mid_lbl.text = GlossaryDatabase.format_text("[font_size=17][b][color=#80D8FF]✨【中間進化・特性 %s: %s】[/color][/b] [color=#B0BEC5](%s)[/color][/font_size]\n[font_size=16][color=#E0F7FA]%s[/color][/font_size]" % [
					mid_data.get("branch", "A"), mid_data.get("name", evo_mid), mid_data.get("role", "特性"), mid_data.get("desc", "")
				])
			else:
				mp_st.bg_color = Color(0.02, 0.02, 0.04, 0.55)
				mp_st.border_color = Color(0.25, 0.28, 0.35, 0.45)
				mid_lbl.text = GlossaryDatabase.format_text("[font_size=17][b][color=#78909C]🔒 【中間進化】スキルLv.10 到達で解放[/color][/b][/font_size]\n[font_size=16][color=#546E7A]Lv.10到達時に3択の進化分岐が出現し、戦術の方向性を決定づける新たな挙動を選びます。[/color][/font_size]")
			mid_panel.add_theme_stylebox_override("panel", mp_st)

		# 最終進化 (Lv.20) スロット更新
		var final_panel: Panel = s_ref.get("final_evo_panel")
		var final_lbl: RichTextLabel = s_ref.get("final_evo_lbl")
		if final_panel and final_lbl:
			var fp_st = StyleBoxFlat.new()
			fp_st.set_corner_radius_all(10)
			fp_st.set_border_width_all(2)
			if evo_final != "":
				var final_data = get_evolution_data(s_item["id"], 20, evo_final)
				fp_st.bg_color = Color(0.10, 0.08, 0.02, 0.70)
				fp_st.border_color = Color(1.0, 0.85, 0.2, 1.0)
				final_lbl.text = GlossaryDatabase.format_text("[font_size=17][b][color=#FFD700]👑【最終進化・特性 %s: %s】[/color][/b] [color=#FFE082](%s)[/color][/font_size]\n[font_size=16][color=#FFF8E1]%s[/color][/font_size]" % [
					final_data.get("numeral", "Ⅰ"), final_data.get("name", evo_final), final_data.get("role", "最終特性"), final_data.get("desc", "")
				])
			else:
				fp_st.bg_color = Color(0.02, 0.02, 0.04, 0.55)
				fp_st.border_color = Color(0.25, 0.28, 0.35, 0.45)
				final_lbl.text = GlossaryDatabase.format_text("[font_size=17][b][color=#78909C]🔒 【最終進化】スキルLv.20 到達で解放[/color][/b][/font_size]\n[font_size=16][color=#546E7A]中間進化に応じた2択の最終進化が出現し、強力な大技や相互作用を開放します。[/color][/font_size]")
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
			s_btn.icon = null
			sb_style.bg_color = Color(0.28, 0.22, 0.06, 0.95)
			sb_style.border_color = Color("#FFD700")
			s_btn.add_theme_color_override("font_color", Color("#FFD700"))
		else:
			s_btn.icon = load("res://Texture/potion/potion_cut.png")
			var act_word = "スキル解放" if cur_lvl == 0 else ("Lv.%dへ強化" % (cur_lvl + 1))
			if cur_lvl == 9:
				act_word = "中間進化 (Lv.10)"
			elif cur_lvl == 19:
				act_word = "最終進化 (Lv.20)"
			s_btn.text = "%s ポーションで%s" % [_format_comma(cost_val), act_word]
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
					var hp_gain: float = maxf(HP_SHOP_FLAT_GAIN * stage_scale, sm.myhpmax * HP_SHOP_PERCENT_GAIN)
					sm.myhpmax += hp_gain
					sm.myhp = minf(sm.myhpmax, sm.myhp + hp_gain)

		var sound = parent.get_node_or_null("coinsound") if parent else null
		if sound:
			sound.play()
		_update_buff_button_labels()
		shop_purchased.emit()
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
	s_item["cost"] = int(cost_ref * 1.55)

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

## スキルの正当進化モーダルUIの表示
func _open_tarot_evolution_modal(skill_idx: int, milestone_lvl: int) -> void:
	if skill_idx < 0 or skill_idx >= skill_tree_items.size():
		return
	var s_item = skill_tree_items[skill_idx]
	var jp_font: Font = _get_jp_font()
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
	bg_st.bg_color = Color(0.01, 0.01, 0.02, 0.70)
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
	close_btn.text = "× キャンセル"
	close_btn.position = Vector2(1720, 24)
	close_btn.size = Vector2(130, 40)
	var cl_st = StyleBoxFlat.new()
	cl_st.bg_color = Color(0.18, 0.12, 0.14, 0.9)
	cl_st.border_color = Color(0.85, 0.4, 0.4, 0.8)
	cl_st.set_border_width_all(1)
	cl_st.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", cl_st)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	_apply_jp_font_to_control(close_btn)
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
	_apply_jp_font_to_control(title_lbl)
	var milestone_title = "【第1覚醒・中間進化 (Lv.10)】" if milestone_lvl <= 10 else "【極限覚醒・最終進化 (Lv.20)】"
	title_lbl.text = "[center][b][color=#FFD54F][font_size=34]✦ スキルの正当進化 ✦[/font_size][/color][/b]\n"
	title_lbl.text += "[color=#B0BEC5][font_size=22]スキル「[color=#FFE082]%s[/color]」が[color=#FFD700]%s[/color]に到達しました。歩むべき特性の進化を選択してください。[/font_size][/color][/center]" % [
		s_item.get("name", ""), milestone_title
	]
	modal.add_child(title_lbl)

	# Cards HBox Container
	var card_count = choices.size()
	var card_w: float = 480.0 if card_count == 2 else 440.0
	var card_h: float = 640.0
	var spacing: float = 60.0 if card_count == 2 else 44.0
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
		card_st.bg_color = Color(0.02, 0.02, 0.04, 0.65)
		card_st.border_color = Color(0.85, 0.72, 0.38, 1.0)
		card_st.set_border_width_all(2)
		card_st.set_corner_radius_all(16)
		card_st.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
		card_st.shadow_size = 8
		card.add_theme_stylebox_override("panel", card_st)
		modal.add_child(card)

		# 進化選択カードのホバー演出（浮遊リフト＆金枠グロー）
		var card_captured = card
		var normal_st = card_st
		var hov_st = card_st.duplicate()
		hov_st.border_color = Color(1.0, 0.88, 0.45, 1.0)
		hov_st.shadow_size = 14
		hov_st.bg_color = Color(0.04, 0.04, 0.08, 0.75)

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
		_apply_jp_font_to_control(num_lbl)
		num_lbl.text = "[center][b][color=#D4AF37][font_size=30]── %s ──[/font_size][/color][/b][/center]" % str(choice.get("numeral", "Ⅰ"))
		card.add_child(num_lbl)

		# Card Title
		var name_lbl = RichTextLabel.new()
		name_lbl.bbcode_enabled = true
		name_lbl.position = Vector2(16, 75)
		name_lbl.size = Vector2(card_w - 32, 55)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_jp_font_to_control(name_lbl)
		name_lbl.text = "[center][b][color=%s][font_size=28]%s[/font_size][/color][/b][/center]" % [
			el_color.to_html(), choice.get("name", "")
		]
		card.add_child(name_lbl)

		# Role Subtitle
		var role_lbl = RichTextLabel.new()
		role_lbl.bbcode_enabled = true
		role_lbl.position = Vector2(16, 135)
		role_lbl.size = Vector2(card_w - 32, 35)
		role_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_apply_jp_font_to_control(role_lbl)
		role_lbl.text = "[center][color=#FFE082][font_size=20]《 %s 》[/font_size][/color][/center]" % GlossaryDatabase.format_text(choice.get("role", ""))
		GlossaryDatabase.bind_rich_text_label(role_lbl)
		card.add_child(role_lbl)

		# Gold Filigree Divider
		var div = ColorRect.new()
		div.position = Vector2(30, 180)
		div.size = Vector2(card_w - 60, 2)
		div.color = Color(0.85, 0.72, 0.38, 0.6)
		card.add_child(div)

		# 進化先アイコン（進化ターゲットのスキルアイコンを表示）
		var emblem_frame = Panel.new()
		emblem_frame.name = "EvolutionEmblem"
		emblem_frame.position = Vector2((card_w - 156) / 2.0, 194)
		emblem_frame.size = Vector2(156, 156)
		emblem_frame.clip_contents = true
		emblem_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var emb_st = StyleBoxFlat.new()
		emb_st.bg_color = Color(el_color.r * 0.2, el_color.g * 0.2, el_color.b * 0.2, 0.85)
		emb_st.border_color = el_color
		emb_st.set_border_width_all(2)
		emb_st.set_corner_radius_all(20)
		emb_st.shadow_color = Color(el_color.r, el_color.g, el_color.b, 0.35)
		emb_st.shadow_size = 10
		emblem_frame.add_theme_stylebox_override("panel", emb_st)
		card.add_child(emblem_frame)

		var evo_icon_path: String = get_skill_icon_path(s_item["id"], str(choice.get("id", "")))
		var evo_icon = TextureRect.new()
		evo_icon.name = "EvolutionIcon"
		evo_icon.position = Vector2(4, 4)
		evo_icon.size = Vector2(148, 148)
		evo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		evo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		evo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if evo_icon_path != "":
			evo_icon.texture = load(evo_icon_path)
		emblem_frame.add_child(evo_icon)

		if evo_icon.texture == null:
			var emblem_txt = RichTextLabel.new()
			emblem_txt.bbcode_enabled = true
			emblem_txt.position = Vector2(0, 50)
			emblem_txt.size = Vector2(156, 56)
			emblem_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_jp_font_to_control(emblem_txt)
			emblem_txt.text = "[center][font_size=34]%s[/font_size][/center]" % s_item.get("short_label", "✦")
			emblem_frame.add_child(emblem_txt)

		# Description
		var desc_lbl = RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.position = Vector2(24, 366)
		desc_lbl.size = Vector2(card_w - 48, 170)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_apply_jp_font_to_control(desc_lbl)
		var desc_text = str(choice.get("desc", ""))
		desc_lbl.text = "[color=#ECEFF1][font_size=23]%s[/font_size][/color]" % GlossaryDatabase.format_text(desc_text)
		GlossaryDatabase.bind_rich_text_label(desc_lbl)
		card.add_child(desc_lbl)

		# "この運命を選択" Button
		var sel_btn = Button.new()
		sel_btn.name = "SelectBtn_%d" % i
		sel_btn.text = "✦ この特性を選択 ✦"
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
		sel_btn.add_theme_font_size_override("font_size", 22)
		_apply_jp_font_to_control(sel_btn)

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
	if not OS.is_debug_build():
		return
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

	# 進化マイルストーン（Lv.10またはLv.20）の判定：選択モーダルを展開
	if (next_lvl == 10 or next_lvl == 20) and not has_chosen_evolution(s_item["id"], next_lvl):
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

			# Lv10およびLv20の進化特性が未選択なら、テスト用に第1候補を自動付与
			if target_lvl >= 10 and not has_chosen_evolution(s_item["id"], 10):
				var m_choices = get_evolution_choices(s_item["id"], 10)
				if not m_choices.is_empty():
					choose_skill_evolution(s_item["id"], 10, m_choices[0]["id"])
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
		# 進化マイルストーン（Lv.10またはLv.20）の判定
		if (target_lvl == 10 or target_lvl == 20) and not has_chosen_evolution(s_item["id"], target_lvl):
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
	elem_status2_rect.color = Color(0.02, 0.02, 0.03, 0.70)
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
		var elem_skill_id: String = str(elem_info["key"]) + "_1"
		var elem_skill_icon: String = get_skill_display_icon_path(elem_skill_id)
		if elem_skill_icon != "" and ResourceLoader.exists(elem_skill_icon):
			el_icn.texture = load(elem_skill_icon)
		elif elem_info["icon"] != "" and ResourceLoader.exists(elem_info["icon"]):
			el_icn.texture = load(elem_info["icon"])
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
		# 絵文字ではなく、その属性の現在の進化アイコンを左側に表示する
		var icon_node = get_node_or_null("elem_icon" + str(k + 1)) as TextureRect
		if icon_node != null:
			var icon_path: String = get_skill_display_icon_path(str(elem_info["key"]) + "_1")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				icon_node.texture = load(icon_path)
		elem_labels[k].text = "[font_size=32][b][color=#%s]%s[/color] :  [color=#FFFFFF]%s[/color][/b][/font_size]" % [
			elem_info["color"], elem_info["name"], val_str
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
			desc = "[font_size=17]当ターン中に獲得した水属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n水マスを生成し、そのマス上の駒を消去して落下を誘発。直撃ダメージも与えます。T2では水マス数に応じたHP回復、T3では水マスを剣に変換して大連鎖を発生させます。中間進化ではHP回復・シールド獲得・水サージ追撃に分化します。炎マスと隣接すると【蒸気消滅シナジー】が発生し、共通隣接マスを一掃消去します。[/font_size]"
		"ice":
			title = "[b][color=#80D8FF]❄️ 氷属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した氷属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n氷マスを生成し、隣接する敵効果マスの進行・拡散を無効化。そのマス上でマッチすると耐久-1。炎で融解、雷で破砕。T2は水/毒/炎を凍結変換、T3は全氷マスを共鳴爆砕。中間進化でシールド蓄積・砕氷・永久凍土に分化。[/font_size]"
		"wood":
			title = "[b][color=#76FF03]🌱 木属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した木属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n苗木を植樹し、水を吸収して成長。毎ターンHPを回復。T2は全苗木を成長、T3は大木を降臨。中間進化で共生・茨・実りに分化。[/font_size]"
		"wind":
			title = "[b][color=#69F0AE]🌪️ 風属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した風属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n盤面の敵効果マスを一掃し、3レベルごとに竜巻の列数が増加。それ以外のレベルでは威力が上昇。T2は効果マスを風下へシフト、T3は敵効果マスを味方へ反転。中間進化で旋風・突風・奪取に分化。[/font_size]"
		"fire":
			title = "[b][color=#FF3D00]🔥 火属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した火属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n炎マスを生成し、そのマス上の駒を消去。水と隣接で蒸気消滅、氷を融解。T2は延焼、T3は焦土劫火。中間進化で飛び火・延焼・破片に分化。[/font_size]"
		"thunder":
			title = "[b][color=#FFD600]⚡ 雷属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した雷属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n帯電マスをレベルに応じて増加（上限なし）し、ランダムな1列に落雷。氷/石に当たると破砕。T2は帯電/水マスを雷ラインで感電、T3は帯電/石/氷を一斉爆砕。中間進化で反射雷・帯電・感電に分化。[/font_size]"
		"earth":
			title = "[b][color=#D7CCC8]🪨 地属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した地属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n味方の輝石マスを生成し、発動時シールドを獲得。マッチ/雷で破砕。T2は全石の耐久を削り周囲を一掃、T3は全石を粉砕して超巨大岩石落とし。中間進化で要塞・鉱山・砕石に分化。[/font_size]"
		"poison":
			title = "[b][color=#B388FF]🧪 毒属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した毒属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n毒マスを生成し、毎ターン毒ダメージと伝染。T2は即時伝染＋敵設置物を毒化、T3は全毒マスを起爆しHP吸収。中間進化で濃縮・伝染・弱体に分化。[/font_size]"
		"light":
			title = "[b][color=#FFF59D]✨ 光属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した光属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n聖像を召喚し、発動時シールド獲得。破壊時に+500G。T2は聖像間の妨害浄化、T3は全聖像を昇天させ極太レーザー。中間進化で光輝の像・聖域の像・共鳴の像に分化。[/font_size]"
		"dark":
			title = "[b][color=#EA80FC]🌙 闇属性 (当ターン蓄積: %s)[/color][/b]" % val_str
			desc = "[font_size=17]当ターン中に獲得した闇属性のエネルギーです。\n[color=#FFD54F]【特性とシナジー】[/color]\n星影の霧と影護マスを生成。影護マスは反動を受けず敵HPを吸収。T2は霧領域を影護化、T3は全影護を特異点へ吸引。中間進化で歪曲・代償・反動に分化。[/font_size]"
	if title != "":
		r_ui.show_custom_tooltip(title, desc, get_global_mouse_position(), "elem_stat_" + elem_key)

func _hide_elem_tooltip(elem_key: String) -> void:
	var r_ui = get_parent().get_node_or_null("RelicUIManager") if get_parent() else null
	if r_ui and r_ui.has_method("hide_custom_tooltip"):
		r_ui.hide_custom_tooltip("elem_stat_" + elem_key)

