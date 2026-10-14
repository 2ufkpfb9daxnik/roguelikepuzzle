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
		"description": "4個以上のマッチで、追加ダメージ（固定値 +500）",
		"levels": [
			{"min_match": 4, "flat_damage": 500.0},
			{"min_match": 4, "flat_damage": 750.0},
			{"min_match": 4, "flat_damage": 1000.0},
			{"min_match": 4, "flat_damage": 1250.0},
			{"min_match": 4, "flat_damage": 1500.0}
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
			var fd = int(round(float(p.get("flat_damage", 500.0))))
			return "4個以上のマッチで、追加ダメージ +%d" % [fd]
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
		_:
			return r.get("description", "")
