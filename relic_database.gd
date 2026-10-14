class_name RelicDatabase
extends RefCounted

const RELICS: Dictionary = {
	"chain_ring": {
		"id": "chain_ring",
		"name": "連鎖の指輪",
		"description": "連鎖が3回以上続いたターン、与ダメージ +20%",
		"rarity": "uncommon",
		"requires_element": false,
		"params": {"min_cascade": 3, "damage_bonus": 0.20}
	},
	"four_orb": {
		"id": "four_orb",
		"name": "4連の宝珠",
		"description": "4個以上のマッチで、追加ダメージ（固定値）",
		"rarity": "common",
		"requires_element": false,
		"params": {"min_match": 4, "flat_damage": 500.0}
	},
	"old_shield": {
		"id": "old_shield",
		"name": "古びた盾",
		"description": "敵から受けるダメージ -10%",
		"rarity": "common",
		"requires_element": false,
		"params": {"damage_reduction": 0.10}
	},
	"healing_drop": {
		"id": "healing_drop",
		"name": "癒しの雫",
		"description": "ターン開始時に最大HPの2%回復",
		"rarity": "common",
		"requires_element": false,
		"params": {"heal_percent": 0.02}
	},
	"indomitable_heart": {
		"id": "indomitable_heart",
		"name": "不屈の心",
		"description": "戦闘（1ステージ）中に1回だけ、致死ダメージをHP1で耐える",
		"rarity": "rare",
		"requires_element": false,
		"params": {"revives": 1}
	},
	"fire_shard": {
		"id": "fire_shard",
		"name": "炎のかけら",
		"description": "炎属性の与ダメージ +15%",
		"rarity": "common",
		"requires_element": true,
		"params": {"element": 1, "damage_bonus": 0.15} # 1 = FIRE
	}
}

static func get_relic(id: String) -> Dictionary:
	return RELICS.get(id, {})
