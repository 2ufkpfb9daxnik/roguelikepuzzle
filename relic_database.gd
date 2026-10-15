class_name RelicDatabase
extends RefCounted

const RARITY_WEIGHTS: Dictionary = {
	"common": 60,
	"uncommon": 30,
	"rare": 10
}

const RARITY_MAX_LEVELS: Dictionary = {
	"common": 5,
	"uncommon": 4,
	"rare": 3
}

const RELICS: Dictionary = {
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
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": true,
		"description": "そのターンに消えた属性剣の70%以上が単一属性のとき、その属性の与ダメージ +25%",
		"levels": [
			{"min_ratio": 0.70, "damage_bonus": 0.25},
			{"min_ratio": 0.70, "damage_bonus": 0.35},
			{"min_ratio": 0.60, "damage_bonus": 0.45},
			{"min_ratio": 0.60, "damage_bonus": 0.55}
		]
	},
	"tome_of_four_elements": {
		"id": "tome_of_four_elements",
		"name": "四象の書",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "1ターン内に消えた剣の属性（炎・水・風・雷）が3種で与ダメージ +25%、4種で +45%",
		"levels": [
			{"bonus_3": 0.25, "bonus_4": 0.45},
			{"bonus_3": 0.32, "bonus_4": 0.58},
			{"bonus_3": 0.40, "bonus_4": 0.70}
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
			var b3 = int(round(float(p.get("bonus_3", 0.25)) * 100.0))
			var b4 = int(round(float(p.get("bonus_4", 0.45)) * 100.0))
			return "1ターン内に消えた剣の属性（炎・水・風・雷）が3種で与ダメージ +%d%%、4種で +%d%%" % [b3, b4]
		_:
			return r.get("description", "")
