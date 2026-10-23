class_name RelicDatabase
extends RefCounted

const RARITY_WEIGHTS: Dictionary = {
	"common": 38,
	"uncommon": 25,
	"rare": 15,
	"epic": 10,
	"legendary": 4,
	"cursed": 8
}

const RARITY_MAX_LEVELS: Dictionary = {
	"common": 5,
	"uncommon": 4,
	"rare": 3,
	"epic": 3,
	"legendary": 2,
	"cursed": 3
}

## 10属性を3つに分類した属性カテゴリー定義
const ELEMENT_CATEGORIES: Dictionary = {
	"nature": {
		"key": "nature",
		"name": "自然・生命",
		"icon": "🌿",
		"color": Color("#00E676"),
		"elements": ["water", "ice", "wood", "wind"],
		"relic_id": "relic_cat_nature",
		"desc": "水・氷・木・風の属性。生命回復や凍結防御、不利益な効果を浄化する力を持つ。"
	},
	"force": {
		"key": "force",
		"name": "元素・破壊",
		"icon": "🔥",
		"color": Color("#FF3D00"),
		"elements": ["fire", "thunder", "earth"],
		"relic_id": "relic_cat_force",
		"desc": "火・雷・地の属性。爆炎と落雷、岩盤破砕の圧倒的な瞬間火力を誇る。"
	},
	"mystic": {
		"key": "mystic",
		"name": "神秘・冥術",
		"icon": "🔮",
		"color": Color("#E040FB"),
		"elements": ["poison", "light", "dark"],
		"relic_id": "relic_cat_mystic",
		"desc": "毒・光・闇の属性。猛毒の侵食、聖像の加護、虚無の重力吸引を操る。"
	}
}

const RELICS: Dictionary = {
	"relic_cat_nature": {
		"id": "relic_cat_nature",
		"name": "【天恵】自然の福音",
		"rarity": "legendary",
		"max_level": 1,
		"category": "category_starter",
		"element_category": "nature",
		"description": "【属性：自然・生命】水・氷・木・風属性を解放。該当属性の与ダメージ+30%、自然系スキルツリーを解放。",
		"levels": [
			{"damage_bonus": 0.30}
		]
	},
	"relic_cat_force": {
		"id": "relic_cat_force",
		"name": "【天恵】破壊の劫火",
		"rarity": "legendary",
		"max_level": 1,
		"category": "category_starter",
		"element_category": "force",
		"description": "【属性：元素・破壊】火・雷・地属性を解放。該当属性の与ダメージ+30%、破壊系スキルツリーを解放。",
		"levels": [
			{"damage_bonus": 0.30}
		]
	},
	"relic_cat_mystic": {
		"id": "relic_cat_mystic",
		"name": "【天恵】神秘の冥光",
		"rarity": "legendary",
		"max_level": 1,
		"category": "category_starter",
		"element_category": "mystic",
		"description": "【属性：神秘・冥術】毒・光・闇属性を解放。該当属性の与ダメージ+30%、神秘系スキルツリーを解放。",
		"levels": [
			{"damage_bonus": 0.30}
		]
	},
	"chain_ring": {
		"id": "chain_ring",
		"name": "連鎖の指輪",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "連鎖が3回以上続いたターン、与ダメージ +20%",
		"levels": [
			{"min_cascade": 3, "damage_bonus": 0.20},
			{"min_cascade": 3, "damage_bonus": 0.28},
			{"min_cascade": 2, "damage_bonus": 0.36},
			{"min_cascade": 2, "damage_bonus": 0.45}
		]
	},
	"four_orb": {
		"id": "four_orb",
		"name": "4連の宝珠",
		"rarity": "common",
		"max_level": 5,
		"requires_element": false,
		"description": "4個以上のマッチで、追加ダメージ（固定値 +500 × ステージ倍率）",
		"levels": [
			{"min_match": 4, "base_damage": 500.0, "mult": 1.0},
			{"min_match": 4, "base_damage": 500.0, "mult": 1.5},
			{"min_match": 4, "base_damage": 500.0, "mult": 2.0},
			{"min_match": 4, "base_damage": 500.0, "mult": 2.5},
			{"min_match": 4, "base_damage": 500.0, "mult": 3.0}
		]
	},
	"old_shield": {
		"id": "old_shield",
		"name": "古びた盾",
		"rarity": "common",
		"max_level": 5,
		"requires_element": false,
		"description": "敵から受けるダメージ -10%",
		"levels": [
			{"damage_reduction": 0.10},
			{"damage_reduction": 0.15},
			{"damage_reduction": 0.19},
			{"damage_reduction": 0.22},
			{"damage_reduction": 0.25}
		]
	},
	"healing_drop": {
		"id": "healing_drop",
		"name": "癒しの雫",
		"rarity": "common",
		"max_level": 5,
		"requires_element": false,
		"description": "ターン開始時に最大HPの2%回復",
		"levels": [
			{"heal_percent": 0.02},
			{"heal_percent": 0.03},
			{"heal_percent": 0.04},
			{"heal_percent": 0.05},
			{"heal_percent": 0.06}
		]
	},
	"indomitable_heart": {
		"id": "indomitable_heart",
		"name": "不屈の心",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": false,
		"description": "戦闘（1ステージ）中に1回だけ、致死ダメージをHP1で耐える",
		"levels": [
			{"revives": 1, "survive_hp_ratio": 0.0},
			{"revives": 1, "survive_hp_ratio": 0.10},
			{"revives": 2, "survive_hp_ratio": 0.10}
		]
	},
	"fire_shard": {
		"id": "fire_shard",
		"name": "炎のかけら",
		"rarity": "common",
		"max_level": 5,
		"requires_element": true,
		"description": "炎属性の与ダメージ +15%",
		"levels": [
			{"element": 1, "damage_bonus": 0.15},
			{"element": 1, "damage_bonus": 0.22},
			{"element": 1, "damage_bonus": 0.29},
			{"element": 1, "damage_bonus": 0.36},
			{"element": 1, "damage_bonus": 0.43}
		]
	},
	"wetland_crown": {
		"id": "wetland_crown",
		"name": "湿地の王冠",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": true,
		"description": "盤面の水たまり1マスにつき、雷属性与ダメージ +1.5%（上限 +30%）",
		"levels": [
			{"element": 4, "per_water": 0.015, "max_bonus": 0.30},
			{"element": 4, "per_water": 0.020, "max_bonus": 0.40},
			{"element": 4, "per_water": 0.025, "max_bonus": 0.50},
			{"element": 4, "per_water": 0.030, "max_bonus": 0.60}
		]
	},
	"ruins_collector": {
		"id": "ruins_collector",
		"name": "廃墟の収集家",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "妨害タイル（石・氷・黄金像）1個破壊につき、そのターンの与ダメージ +3%（上限 +30%）",
		"levels": [
			{"per_hazard": 0.03, "max_bonus": 0.30},
			{"per_hazard": 0.04, "max_bonus": 0.40},
			{"per_hazard": 0.05, "max_bonus": 0.50},
			{"per_hazard": 0.06, "max_bonus": 0.60}
		]
	},
	"resonant_explosive": {
		"id": "resonant_explosive",
		"name": "共鳴する爆薬",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "同一ターン内の特殊駒起爆2個目以降、1個につき与ダメージ +10%（上限 +40%）",
		"levels": [
			{"per_extra_detonation": 0.10, "max_bonus": 0.40},
			{"per_extra_detonation": 0.13, "max_bonus": 0.50},
			{"per_extra_detonation": 0.16, "max_bonus": 0.60},
			{"per_extra_detonation": 0.20, "max_bonus": 0.80}
		]
	},
	"bloodstained_sword": {
		"id": "bloodstained_sword",
		"name": "血塗られた剣",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": false,
		"description": "与ダメージ +30%。毎ターン開始時に最大HPの3%を失う（HP1で止まる）",
		"levels": [
			{"damage_bonus": 0.30, "self_damage_percent": 0.03},
			{"damage_bonus": 0.42, "self_damage_percent": 0.03},
			{"damage_bonus": 0.55, "self_damage_percent": 0.03}
		]
	},
	"desperate_banner": {
		"id": "desperate_banner",
		"name": "背水の旗",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "自分のHPが30%以下のとき、与ダメージ +35%",
		"levels": [
			{"hp_threshold": 0.30, "damage_bonus": 0.35},
			{"hp_threshold": 0.30, "damage_bonus": 0.45},
			{"hp_threshold": 0.35, "damage_bonus": 0.55},
			{"hp_threshold": 0.40, "damage_bonus": 0.65}
		]
	},
	"excavator_pickaxe": {
		"id": "excavator_pickaxe",
		"name": "掘削者の鶴嘴",
		"rarity": "common",
		"max_level": 5,
		"requires_element": false,
		"description": "地・木・氷属性の敵に対する与ダメージ +20%",
		"levels": [
			{"damage_bonus": 0.20},
			{"damage_bonus": 0.28},
			{"damage_bonus": 0.36},
			{"damage_bonus": 0.44},
			{"damage_bonus": 0.52}
		]
	},
	"pure_oath": {
		"id": "pure_oath",
		"name": "純色の誓い",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "そのターンに消えた属性剣の70%以上が単一属性のとき、その属性の与ダメージ +30%",
		"levels": [
			{"min_ratio": 0.70, "damage_bonus": 0.30},
			{"min_ratio": 0.65, "damage_bonus": 0.45},
			{"min_ratio": 0.60, "damage_bonus": 0.60}
		]
	},
	"tome_of_four_elements": {
		"id": "tome_of_four_elements",
		"name": "四象の書",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": true,
		"description": "1ターン内に消えた剣の属性（炎・水・風・雷）が3種で与ダメージ +30%、4種で +60%",
		"levels": [
			{"bonus_3": 0.30, "bonus_4": 0.60},
			{"bonus_3": 0.40, "bonus_4": 0.80},
			{"bonus_3": 0.55, "bonus_4": 1.05}
		]
	},
	"counter_blade": {
		"id": "counter_blade",
		"name": "反撃の刃",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "ターン開始時やマッチで所持しているシールド1個につき、そのターンの与ダメージ +2%（上限 +30%）",
		"levels": [
			{"per_shield": 0.02, "max_bonus": 0.30},
			{"per_shield": 0.025, "max_bonus": 0.40},
			{"per_shield": 0.03, "max_bonus": 0.50},
			{"per_shield": 0.04, "max_bonus": 0.65}
		]
	},
	"alchemy_flask": {
		"id": "alchemy_flask",
		"name": "錬金術のフラスコ",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "消去したポーション駒1個につき、そのターンの与ダメージ +1.5%（上限 +30%）",
		"levels": [
			{"per_potion": 0.015, "max_bonus": 0.30},
			{"per_potion": 0.020, "max_bonus": 0.40},
			{"per_potion": 0.025, "max_bonus": 0.50},
			{"per_potion": 0.030, "max_bonus": 0.60}
		]
	},
	"executioner_brand": {
		"id": "executioner_brand",
		"name": "断罪の刻印",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": false,
		"description": "狙っているターゲット敵のHPが50%以下のとき、与ダメージ +30%",
		"levels": [
			{"hp_threshold": 0.50, "damage_bonus": 0.30},
			{"hp_threshold": 0.50, "damage_bonus": 0.45},
			{"hp_threshold": 0.55, "damage_bonus": 0.65}
		]
	},
	"soul_harvester": {
		"id": "soul_harvester",
		"name": "魂の刈り取り",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": false,
		"description": "敵撃破時、最大HPの10%回復＆戦闘中の与ダメージ +15%（累積可、上限+90%）",
		"levels": [
			{"heal_pct": 0.10, "stack_bonus": 0.15, "max_bonus": 0.90},
			{"heal_pct": 0.15, "stack_bonus": 0.22, "max_bonus": 0.90},
			{"heal_pct": 0.20, "stack_bonus": 0.30, "max_bonus": 0.90}
		]
	},
	"fever_overdrive": {
		"id": "fever_overdrive",
		"name": "狂熱の心臓",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": false,
		"description": "フィーバータイム中、与ダメージ +40%。さらにフィーバー突入時に残り手数 +1回",
		"levels": [
			{"fever_damage_bonus": 0.40, "extra_fever_turns": 1},
			{"fever_damage_bonus": 0.60, "extra_fever_turns": 2},
			{"fever_damage_bonus": 0.85, "extra_fever_turns": 3}
		]
	},
	"prismatic_resonator": {
		"id": "prismatic_resonator",
		"name": "万象の共鳴器",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": true,
		"description": "1ターン内に2種類以上の属性マッチを達成したとき、与ダメージ +35%",
		"levels": [
			{"min_elements": 2, "damage_bonus": 0.35},
			{"min_elements": 2, "damage_bonus": 0.55},
			{"min_elements": 2, "damage_bonus": 0.75}
		]
	},
	"crown_of_origin": {
		"id": "crown_of_origin",
		"name": "始源の神冠",
		"rarity": "legendary",
		"max_level": 2,
		"requires_element": false,
		"description": "連鎖数5以上またはコンボ5以上のとき、全剣攻撃が弱点属性化し与ダメージ +50%",
		"levels": [
			{"min_threshold": 5, "damage_bonus": 0.50},
			{"min_threshold": 4, "damage_bonus": 0.85}
		]
	},
	"midas_chalice": {
		"id": "midas_chalice",
		"name": "ミダスの杯",
		"rarity": "legendary",
		"max_level": 2,
		"requires_element": false,
		"description": "コイン獲得スコア +50%。累計スコア10,000ごとに与ダメージ +1%（上限 +50%）",
		"levels": [
			{"coin_bonus": 0.50, "per_score": 10000, "dmg_per_step": 0.01, "max_dmg_bonus": 0.50},
			{"coin_bonus": 1.00, "per_score": 10000, "dmg_per_step": 0.015, "max_dmg_bonus": 1.00}
		]
	},
	"resonant_spark": {
		"id": "resonant_spark",
		"name": "共鳴の点火石",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": false,
		"description": "連鎖終了の定常状態に入った時、場にあるランダムなスキルコマを自動起爆する",
		"levels": [
			{"detonate_count": 1},
			{"detonate_count": 2},
			{"detonate_count": 3}
		]
	},
	"cursed_shura_sword": {
		"id": "cursed_shura_sword",
		"name": "修羅の魔剣",
		"rarity": "cursed",
		"max_level": 3,
		"requires_element": false,
		"description": "【呪い】剣攻撃力が2.5倍になるが、最大HPが半分になる",
		"levels": [
			{"sword_multiplier": 2.5, "hp_multiplier": 0.5},
			{"sword_multiplier": 3.0, "hp_multiplier": 0.5},
			{"sword_multiplier": 3.5, "hp_multiplier": 0.5}
		]
	},
	"cursed_gluttony_grail": {
		"id": "cursed_gluttony_grail",
		"name": "暴食の聖杯",
		"rarity": "cursed",
		"max_level": 3,
		"requires_element": false,
		"description": "【呪い】回復量が3倍になるが、毎ターン盤面1マスに動かせない障害物が発生する",
		"levels": [
			{"heal_multiplier": 3.0, "hazard_count": 1},
			{"heal_multiplier": 3.5, "hazard_count": 1},
			{"heal_multiplier": 4.0, "hazard_count": 1}
		]
	},
	"cursed_midas_touch": {
		"id": "cursed_midas_touch",
		"name": "黄金のミダスタッチ",
		"rarity": "cursed",
		"max_level": 3,
		"requires_element": false,
		"description": "【呪い】コイン獲得量が3倍になるが、敵の攻撃力も+30%上昇する",
		"levels": [
			{"coin_multiplier": 3.0, "enemy_atk_mult": 1.3},
			{"coin_multiplier": 3.5, "enemy_atk_mult": 1.3},
			{"coin_multiplier": 4.0, "enemy_atk_mult": 1.3}
		]
	}
}

static func get_relic(id: String) -> Dictionary:
	return RELICS.get(id, {})

static func get_max_level(id: String) -> int:
	var r = get_relic(id)
	if r.has("max_level"):
		return int(r["max_level"])
	var rarity = r.get("rarity", "common")
	return RARITY_MAX_LEVELS.get(rarity, 3)

static func get_level_params(id: String, level: int) -> Dictionary:
	var r = get_relic(id)
	var levels = r.get("levels", []) as Array
	if levels.is_empty():
		return r.get("params", {})
	var idx = clampi(level - 1, 0, levels.size() - 1)
	return levels[idx]

static func get_description(id: String, level: int) -> String:
	var r = get_relic(id)
	if r.is_empty():
		return ""
	var p = get_level_params(id, level)
	var max_lvl = get_max_level(id)
	var cur_lvl = clampi(level, 1, max_lvl)
	
	match id:
		"chain_ring":
			var mc = int(p.get("min_cascade", 3))
			var db = int(round(float(p.get("damage_bonus", 0.20)) * 100.0))
			return "連鎖が%d回以上続いたターン、与ダメージ +%d%%" % [mc, db]
		"four_orb":
			var mult = float(p.get("mult", 1.0))
			var base_d = float(p.get("base_damage", 500.0))
			return "4個以上のマッチで、追加ダメージ +%d × ステージ倍率" % int(round(base_d * mult))
		"old_shield":
			var dr = int(round(float(p.get("damage_reduction", 0.10)) * 100.0))
			return "敵から受けるダメージ -%d%%" % [dr]
		"healing_drop":
			var hp = int(round(float(p.get("heal_percent", 0.02)) * 100.0))
			return "ターン開始時に最大HPの%d%%回復" % [hp]
		"indomitable_heart":
			var rev = int(p.get("revives", 1))
			var ratio = float(p.get("survive_hp_ratio", 0.0))
			var hp_text = "HP1" if ratio <= 0.001 else "最大HPの%d%%" % int(round(ratio * 100.0))
			var times_text = "1回だけ" if rev == 1 else "%d回まで" % rev
			return "1戦闘で%s、致死ダメージを%sで耐える" % [times_text, hp_text]
		"fire_shard":
			var db = int(round(float(p.get("damage_bonus", 0.15)) * 100.0))
			return "炎属性の与ダメージ +%d%%" % [db]
		"wetland_crown":
			var pw = float(p.get("per_water", 0.015)) * 100.0
			var mb = int(round(float(p.get("max_bonus", 0.30)) * 100.0))
			return "盤面の水たまり1マスにつき、雷属性与ダメージ +%.1f%%（上限 +%d%%）" % [pw, mb]
		"ruins_collector":
			var ph = int(round(float(p.get("per_hazard", 0.03)) * 100.0))
			var mb = int(round(float(p.get("max_bonus", 0.30)) * 100.0))
			return "妨害タイル（石・氷・黄金像）1個破壊につき、そのターンの与ダメージ +%d%%（上限 +%d%%）" % [ph, mb]
		"resonant_explosive":
			var ped = int(round(float(p.get("per_extra_detonation", 0.10)) * 100.0))
			var mb = int(round(float(p.get("max_bonus", 0.40)) * 100.0))
			return "同一ターン内の特殊駒起爆2個目以降、1個につき与ダメージ +%d%%（上限 +%d%%）" % [ped, mb]
		"bloodstained_sword":
			var db = int(round(float(p.get("damage_bonus", 0.30)) * 100.0))
			var sd = int(round(float(p.get("self_damage_percent", 0.03)) * 100.0))
			return "与ダメージ +%d%%。毎ターン開始時に最大HPの%d%%を失う（HP1で止まる）" % [db, sd]
		"desperate_banner":
			var th = int(round(float(p.get("hp_threshold", 0.30)) * 100.0))
			var db = int(round(float(p.get("damage_bonus", 0.35)) * 100.0))
			return "自分のHPが%d%%以下のとき、与ダメージ +%d%%" % [th, db]
		"excavator_pickaxe":
			var db = int(round(float(p.get("damage_bonus", 0.20)) * 100.0))
			return "地・木・氷属性の敵に対する与ダメージ +%d%%" % [db]
		"pure_oath":
			var mr = int(round(float(p.get("min_ratio", 0.70)) * 100.0))
			var db = int(round(float(p.get("damage_bonus", 0.25)) * 100.0))
			return "そのターンに消えた属性剣の%d%%以上が単一属性のとき、その属性の与ダメージ +%d%%" % [mr, db]
		"tome_of_four_elements":
			var b3 = int(round(float(p.get("bonus_3", 0.30)) * 100.0))
			var b4 = int(round(float(p.get("bonus_4", 0.60)) * 100.0))
			return "1ターン内に消えた剣の属性（炎・水・風・雷）が3種で与ダメージ +%d%%、4種で +%d%%" % [b3, b4]
		"counter_blade":
			var ps = float(p.get("per_shield", 0.02)) * 100.0
			var mb = int(round(float(p.get("max_bonus", 0.30)) * 100.0))
			return "所持シールド1個につき、そのターンの与ダメージ +%.1f%%（上限 +%d%%）" % [ps, mb]
		"alchemy_flask":
			var pp = float(p.get("per_potion", 0.015)) * 100.0
			var mb = int(round(float(p.get("max_bonus", 0.30)) * 100.0))
			return "消去したポーション駒1個につき、そのターンの与ダメージ +%.1f%%（上限 +%d%%）" % [pp, mb]
		"executioner_brand":
			var th = int(round(float(p.get("hp_threshold", 0.50)) * 100.0))
			var db = int(round(float(p.get("damage_bonus", 0.30)) * 100.0))
			return "ターゲット敵のHPが%d%%以下のとき、与ダメージ +%d%%" % [th, db]
		"soul_harvester":
			var hp = int(round(float(p.get("heal_pct", 0.10)) * 100.0))
			var sb = int(round(float(p.get("stack_bonus", 0.15)) * 100.0))
			return "敵撃破時、最大HPの%d%%回復＆戦闘中の与ダメージ +%d%%（累積可）" % [hp, sb]
		"fever_overdrive":
			var fdb = int(round(float(p.get("fever_damage_bonus", 0.40)) * 100.0))
			var ext = int(p.get("extra_fever_turns", 1))
			return "フィーバー中、与ダメージ +%d%%。突入時に残り手数 +%d回" % [fdb, ext]
		"prismatic_resonator":
			var db = int(round(float(p.get("damage_bonus", 0.35)) * 100.0))
			return "1ターン内に2属性以上のマッチ達成で、与ダメージ +%d%%" % [db]
		"crown_of_origin":
			var th = int(p.get("min_threshold", 5))
			var db = int(round(float(p.get("damage_bonus", 0.50)) * 100.0))
			return "連鎖数%d以上またはコンボ%d以上のとき、全攻撃が弱点化＆与ダメージ +%d%%" % [th, th, db]
		"midas_chalice":
			var cb = int(round(float(p.get("coin_bonus", 0.50)) * 100.0))
			var mb = int(round(float(p.get("max_dmg_bonus", 0.50)) * 100.0))
			return "コイン獲得スコア +%d%%。累計1万スコア毎に与ダメージ +1%%（上限 +%d%%）" % [cb, mb]
		"resonant_spark":
			var dc = int(p.get("detonate_count", 1))
			return "手番終了の定常状態に入った時、場にあるスキルコマをランダムに%d個自動起爆する" % [dc]
		"cursed_shura_sword":
			var sm = float(p.get("sword_multiplier", 2.5))
			return "【呪い】剣攻撃力が%.1f倍になるが、最大HPが半分（-50%%）になる" % [sm]
		"cursed_gluttony_grail":
			var hm = float(p.get("heal_multiplier", 3.0))
			return "【呪い】ポーション/パン回復量が%.1f倍になるが、毎ターン盤面に障害物（石・氷・呪い）が1マス発生する" % [hm]
		"cursed_midas_touch":
			var cm = float(p.get("coin_multiplier", 3.0))
			return "【呪い】コイン獲得量が%.1f倍になるが、敵の攻撃力も+30%%上昇する" % [cm]
		"relic_cat_nature":
			return "【属性：自然・生命】水・氷・木・風属性を解放。該当属性の与ダメージ+30%、自然系スキルツリーを解放。"
		"relic_cat_force":
			return "【属性：元素・破壊】火・雷・地属性を解放。該当属性の与ダメージ+30%、破壊系スキルツリーを解放。"
		"relic_cat_mystic":
			return "【属性：神秘・冥術】毒・光・闇属性を解放。該当属性の与ダメージ+30%、神秘系スキルツリーを解放。"
		_:
			return r.get("description", "")
