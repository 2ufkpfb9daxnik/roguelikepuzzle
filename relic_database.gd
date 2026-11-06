class_name RelicDatabase
extends RefCounted

const RARITY_WEIGHTS: Dictionary = {
	"common": 40,
	"uncommon": 28,
	"rare": 16,
	"epic": 8,
	"legendary": 3,
	"cursed": 5
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
		"desc": "水属性・氷属性・木属性・風属性の系統。生命回復や凍結防御、不利益な効果を浄化する力を持つ。"
	},
	"force": {
		"key": "force",
		"name": "元素・破壊",
		"icon": "🔥",
		"color": Color("#FF3D00"),
		"elements": ["fire", "thunder", "earth"],
		"relic_id": "relic_cat_force",
		"desc": "火属性・雷属性・地属性の系統。爆炎と落雷、岩盤破砕の圧倒的な瞬間火力を誇る。"
	},
	"mystic": {
		"key": "mystic",
		"name": "神秘・冥術",
		"icon": "🔮",
		"color": Color("#E040FB"),
		"elements": ["poison", "light", "dark"],
		"relic_id": "relic_cat_mystic",
		"desc": "毒属性・光属性・闇属性の系統。猛毒の侵食、聖像の加護、虚無の重力吸引を操る。"
	}
}

const RELICS: Dictionary = {
	"relic_cat_nature": {
		"id": "relic_cat_nature",
		"name": "【スキル解放権】自然・生命系統 (水属性・氷属性・木属性・風属性)",
		"rarity": "legendary",
		"max_level": 1,
		"category": "category_starter",
		"element_category": "nature",
		"description": "水属性・氷属性・木属性・風属性の系統。該当属性の与ダメージ+30%。ショップでポーションを消費してスキルを習得可能になります。",
		"levels": [
			{"damage_bonus": 0.30}
		]
	},
	"relic_cat_force": {
		"id": "relic_cat_force",
		"name": "【スキル解放権】元素・破壊系統 (火属性・雷属性・地属性)",
		"rarity": "legendary",
		"max_level": 1,
		"category": "category_starter",
		"element_category": "force",
		"description": "火属性・雷属性・地属性の系統。該当属性の与ダメージ+30%。ショップでポーションを消費してスキルを習得可能になります。",
		"levels": [
			{"damage_bonus": 0.30}
		]
	},
	"relic_cat_mystic": {
		"id": "relic_cat_mystic",
		"name": "【スキル解放権】神秘・冥術系統 (毒属性・光属性・闇属性)",
		"rarity": "legendary",
		"max_level": 1,
		"category": "category_starter",
		"element_category": "mystic",
		"description": "毒属性・光属性・闇属性の系統。該当属性の与ダメージ+30%。ショップでポーションを消費してスキルを習得可能になります。",
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
		"description": "連鎖数4以上またはコンボ4以上のとき、全剣攻撃が弱点属性化し与ダメージ +60%",
		"levels": [
			{"min_threshold": 4, "damage_bonus": 0.60},
			{"min_threshold": 3, "damage_bonus": 1.00}
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
			{"sword_multiplier": 2.5, "hp_multiplier": 0.50},
			{"sword_multiplier": 3.2, "hp_multiplier": 0.40},
			{"sword_multiplier": 4.0, "hp_multiplier": 0.30}
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
			{"heal_multiplier": 4.0, "hazard_count": 2},
			{"heal_multiplier": 5.0, "hazard_count": 3}
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
			{"coin_multiplier": 3.0, "enemy_atk_mult": 1.30},
			{"coin_multiplier": 4.0, "enemy_atk_mult": 1.50},
			{"coin_multiplier": 5.0, "enemy_atk_mult": 1.75}
		]
	},
	# ===== 専門性レリック（自然・生命系統：水・氷・木・風） =====
	"water_sacred_crown": {
		"id": "water_sacred_crown",
		"element_category": "nature",
		"name": "水神の聖杯",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "水スキル【命の湧水】のHP回復量+50%。水マスの隣接拡大数+1",
		"levels": [
			{"heal_bonus": 0.50, "spread_bonus": 1},
			{"heal_bonus": 0.70, "spread_bonus": 1},
			{"heal_bonus": 0.90, "spread_bonus": 2}
		]
	},
	"ice_crystal_crown": {
		"id": "ice_crystal_crown",
		"element_category": "nature",
		"name": "氷晶の王冠",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "氷スキル生成の耐久値+1。雷による氷破壊ダメージ+100%",
		"levels": [
			{"durability_bonus": 1, "shatter_bonus": 0.50},
			{"durability_bonus": 1, "shatter_bonus": 0.75},
			{"durability_bonus": 2, "shatter_bonus": 1.00}
		]
	},
	"world_tree_seed": {
		"id": "world_tree_seed",
		"element_category": "nature",
		"name": "世界樹の種",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": true,
		"description": "木スキルで苗木を2本同時に植樹。成長速度2倍",
		"levels": [
			{"extra_plants": 1, "growth_mult": 2.0},
			{"extra_plants": 1, "growth_mult": 2.5},
			{"extra_plants": 2, "growth_mult": 3.0}
		]
	},
	"swift_wind_feather": {
		"id": "swift_wind_feather",
		"element_category": "nature",
		"name": "疾風の羽根",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": true,
		"description": "風スキルの突風で消去する駒数+2。列竜巻の幅+1列",
		"levels": [
			{"sweep_bonus": 1, "width_bonus": 0},
			{"sweep_bonus": 2, "width_bonus": 0},
			{"sweep_bonus": 2, "width_bonus": 1},
			{"sweep_bonus": 3, "width_bonus": 1}
		]
	},
	"flowing_water_charm": {
		"id": "flowing_water_charm",
		"element_category": "nature",
		"name": "流水の護符",
		"rarity": "common",
		"max_level": 5,
		"requires_element": true,
		"description": "水マスが1つでも存在するとき、プレイヤーが受けるダメージ-10%。水+火シナジー威力+10%（Lvに応じて強化）",
		"levels": [
			{"water_reduction": 0.10, "synergy_bonus": 0.10},
			{"water_reduction": 0.14, "synergy_bonus": 0.15},
			{"water_reduction": 0.18, "synergy_bonus": 0.20},
			{"water_reduction": 0.22, "synergy_bonus": 0.25},
			{"water_reduction": 0.26, "synergy_bonus": 0.30}
		]
	},
	"frozen_earth_oath": {
		"id": "frozen_earth_oath",
		"element_category": "nature",
		"name": "凍土の誓約",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": true,
		"description": "ターン開始時、盤面のランダム2マスに氷マス生成",
		"levels": [
			{"ice_count": 1},
			{"ice_count": 2},
			{"ice_count": 2},
			{"ice_count": 3}
		]
	},
	"vine_binding": {
		"id": "vine_binding",
		"element_category": "nature",
		"name": "藤蔓の拘束",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "木スキル発動時、敵の行動を1ターン遅延",
		"levels": [
			{"delay_turns": 1},
			{"delay_turns": 1},
			{"delay_turns": 2}
		]
	},
	"tide_ring": {
		"id": "tide_ring",
		"element_category": "nature",
		"name": "潮汐の指輪",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": true,
		"description": "水マス数×1.5%の全属性与ダメージボーナス（上限+30%、Lvに応じて強化）",
		"levels": [
			{"per_water": 0.015, "max_bonus": 0.30},
			{"per_water": 0.020, "max_bonus": 0.40},
			{"per_water": 0.025, "max_bonus": 0.50}
		]
	},
	# ===== 専門性レリック（元素・破壊系統：火・雷・地） =====
	"blazing_fire_orb": {
		"id": "blazing_fire_orb",
		"element_category": "force",
		"name": "業炎の宝珠",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "火スキルの燃焼範囲+2マス。延焼確率100%",
		"levels": [
			{"range_bonus": 1, "spread_chance": 0.50},
			{"range_bonus": 2, "spread_chance": 0.75},
			{"range_bonus": 2, "spread_chance": 1.00}
		]
	},
	"thunder_god_bracelet": {
		"id": "thunder_god_bracelet",
		"element_category": "force",
		"name": "雷神の腕輪",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "雷スキルの連鎖数+2。水マス上の感電範囲+1マス",
		"levels": [
			{"chain_bonus": 1, "range_bonus": 0},
			{"chain_bonus": 2, "range_bonus": 1},
			{"chain_bonus": 2, "range_bonus": 1}
		]
	},
	"earth_heart": {
		"id": "earth_heart",
		"element_category": "force",
		"name": "大地の心臓",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": true,
		"description": "石スキルの耐久値+2。大地の激震の破壊範囲3x3化",
		"levels": [
			{"durability_bonus": 1, "quake_radius": 1},
			{"durability_bonus": 2, "quake_radius": 2},
			{"durability_bonus": 2, "quake_radius": 2}
		]
	},
	"demolition_book": {
		"id": "demolition_book",
		"element_category": "force",
		"name": "爆破の書",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "爆弾系特殊駒のダメージ+40%。起爆範囲+1マス",
		"levels": [
			{"bomb_damage": 0.20, "blast_range": 0},
			{"bomb_damage": 0.30, "blast_range": 0},
			{"bomb_damage": 0.40, "blast_range": 1},
			{"bomb_damage": 0.50, "blast_range": 1}
		]
	},
	"molten_iron_armor": {
		"id": "molten_iron_armor",
		"element_category": "force",
		"name": "熔鉄の甲冑",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": true,
		"description": "火マス上の敵に毎ターン最大HP2%の継続ダメージ",
		"levels": [
			{"dot_percent": 0.010},
			{"dot_percent": 0.015},
			{"dot_percent": 0.020},
			{"dot_percent": 0.025}
		]
	},
	"magnet_charm": {
		"id": "magnet_charm",
		"element_category": "force",
		"name": "磁石の护符",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "雷スキル発動時、盤面の水マスを全範囲感電",
		"levels": [
			{"thunder_bonus": 0.15},
			{"thunder_bonus": 0.25},
			{"thunder_bonus": 0.35}
		]
	},
	"rock_fortress": {
		"id": "rock_fortress",
		"element_category": "force",
		"name": "岩塊の要塞",
		"rarity": "common",
		"max_level": 5,
		"requires_element": true,
		"description": "石マス隣接の自駒が受けるダメージ-25%",
		"levels": [
			{"reduction": 0.10},
			{"reduction": 0.14},
			{"reduction": 0.18},
			{"reduction": 0.22},
			{"reduction": 0.26}
		]
	},
	"superconduct_ring": {
		"id": "superconduct_ring",
		"element_category": "force",
		"name": "超電導の指輪",
		"rarity": "legendary",
		"max_level": 3,
		"requires_element": true,
		"description": "雷スキルダメージ+15〜35%",
		"levels": [
			{"damage_bonus": 0.15},
			{"damage_bonus": 0.25},
			{"damage_bonus": 0.35}
		]
	},
	# ===== 専門性レリック（神秘・冥術系統：毒・光・闇） =====
	"venom_crown": {
		"id": "venom_crown",
		"element_category": "mystic",
		"name": "猛毒の王冠",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "毒スキルの初期段階+1。毒マスの伝染速度2倍",
		"levels": [
			{"stage_bonus": 1, "spread_mult": 1.5},
			{"stage_bonus": 1, "spread_mult": 2.0},
			{"stage_bonus": 2, "spread_mult": 2.5}
		]
	},
	"holy_lighthouse": {
		"id": "holy_lighthouse",
		"element_category": "mystic",
		"name": "聖光の灯台",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": true,
		"description": "光スキルの聖像ダメージ+50%。聖光レーザー貫通数+2",
		"levels": [
			{"statue_damage": 0.25, "pierce_bonus": 1},
			{"statue_damage": 0.37, "pierce_bonus": 2},
			{"statue_damage": 0.50, "pierce_bonus": 2}
		]
	},
	"void_ring": {
		"id": "void_ring",
		"element_category": "mystic",
		"name": "虚無の指環",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": true,
		"description": "闇スキルの吸引範囲3x3化。HP吸収率50%→75%",
		"levels": [
			{"pull_radius": 1, "drain_rate": 0.60},
			{"pull_radius": 1, "drain_rate": 0.67},
			{"pull_radius": 2, "drain_rate": 0.75}
		]
	},
	"underworld_contract": {
		"id": "underworld_contract",
		"element_category": "mystic",
		"name": "冥府の契約",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": true,
		"description": "闇スキルで自由スワップ1ターン追加",
		"levels": [
			{"swap_bonus": 1},
			{"swap_bonus": 1},
			{"swap_bonus": 2},
			{"swap_bonus": 2}
		]
	},
	"corrosion_charm": {
		"id": "corrosion_charm",
		"element_category": "mystic",
		"name": "腐蝕の护符",
		"rarity": "common",
		"max_level": 5,
		"requires_element": true,
		"description": "毒マス上の敵が受ける与ダメージ+20%",
		"levels": [
			{"damage_bonus": 0.10},
			{"damage_bonus": 0.14},
			{"damage_bonus": 0.18},
			{"damage_bonus": 0.22},
			{"damage_bonus": 0.26}
		]
	},
	"sanctuary_lamp": {
		"id": "sanctuary_lamp",
		"element_category": "mystic",
		"name": "聖域の灯",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": true,
		"description": "光スキル発動時、全聖像の被ダメージ-50%（1ターン）",
		"levels": [
			{"damage_reduction": 0.25},
			{"damage_reduction": 0.35},
			{"damage_reduction": 0.42},
			{"damage_reduction": 0.50}
		]
	},
		"shadow_pin": {
			"id": "shadow_pin",
			"element_category": "mystic",
			"name": "影縫いの杭",
			"rarity": "rare",
			"max_level": 3,
			"requires_element": true,
			"description": "闇スキルの与ダメージ+10〜20%",
			"levels": [
				{"dark_damage": 0.10},
				{"dark_damage": 0.15},
				{"dark_damage": 0.20}
			]
		},
	"underworld_scale": {
		"id": "underworld_scale",
		"element_category": "mystic",
		"name": "黄泉の秤",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": false,
		"description": "敵撃破時、撃破ダメージの30%をHP吸収",
		"levels": [
			{"heal_rate": 0.20},
			{"heal_rate": 0.25},
			{"heal_rate": 0.30}
		]
	},
	# ===== 専門性レリック（クロスカテゴリー） =====
	"elemental_affinity_ring": {
		"id": "elemental_affinity_ring",
		"element_category": "all",
		"name": "属性親和の指輪",
		"rarity": "epic",
		"max_level": 3,
		"requires_element": false,
		"description": "選択カテゴリーのスキルダメージ+8〜16%",
		"levels": [
			{"skill_damage": 0.08},
			{"skill_damage": 0.12},
			{"skill_damage": 0.16}
		]
	},
	"spirit_blessing": {
		"id": "spirit_blessing",
		"element_category": "all",
		"name": "精霊の祝福",
		"rarity": "rare",
		"max_level": 3,
		"requires_element": false,
		"description": "スキル発動後、最大HPの3〜7%のシールドを獲得",
		"levels": [
			{"shield_ratio": 0.03},
			{"shield_ratio": 0.05},
			{"shield_ratio": 0.07}
		]
	},
	"magic_crystal": {
		"id": "magic_crystal",
		"element_category": "all",
		"name": "魔力結晶",
		"rarity": "uncommon",
		"max_level": 4,
		"requires_element": false,
		"description": "スキルダメージ+25%。スキル発動後の次のマッチダメージ+15%",
		"levels": [
			{"skill_damage": 0.15, "next_match_bonus": 0.10},
			{"skill_damage": 0.20, "next_match_bonus": 0.12},
			{"skill_damage": 0.25, "next_match_bonus": 0.15},
			{"skill_damage": 0.30, "next_match_bonus": 0.20}
		]
	},
	"ancient_dragon_scale": {
		"id": "ancient_dragon_scale",
		"element_category": "all",
		"name": "古龍の鱗",
		"rarity": "legendary",
		"max_level": 3,
		"requires_element": false,
		"description": "カテゴリー全スキルのダメージ+40%",
		"levels": [
			{"category_skill_damage": 0.20},
			{"category_skill_damage": 0.30},
			{"category_skill_damage": 0.40}
		]
	}
}

const RELIC_ICON_DIR: String = "res://Texture/relic"

static func get_relic(id: String) -> Dictionary:
	return RELICS.get(id, {})

static func get_icon_path(id: String) -> String:
	return "%s/%s.png" % [RELIC_ICON_DIR, id]

static func get_icon(id: String) -> Texture2D:
	var path := get_icon_path(id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

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
			var hp_pen = int(round((1.0 - float(p.get("hp_multiplier", 0.5))) * 100.0))
			return "【呪い】剣攻撃力が%.1f倍になるが、最大HPが-%d%%になる" % [sm, hp_pen]
		"cursed_gluttony_grail":
			var hm = float(p.get("heal_multiplier", 3.0))
			var hz_cnt = int(p.get("hazard_count", 1))
			return "【呪い】ポーション/パン回復量が%.1f倍になるが、毎ターン盤面に障害物（石・氷・呪い）が%dマス発生する" % [hm, hz_cnt]
		"cursed_midas_touch":
			var cm = float(p.get("coin_multiplier", 3.0))
			var eatk_pen = int(round((float(p.get("enemy_atk_mult", 1.3)) - 1.0) * 100.0))
			return "【呪い】コイン獲得量が%.1f倍になるが、敵の攻撃力も+%d%%上昇する" % [cm, eatk_pen]
		"relic_cat_nature":
			return "水属性・氷属性・木属性・風属性の系統。該当属性の与ダメージ+30%。ショップでポーションを消費してスキルを習得可能になります。"
		"relic_cat_force":
			return "火属性・雷属性・地属性の系統。該当属性の与ダメージ+30%。ショップでポーションを消費してスキルを習得可能になります。"
		"relic_cat_mystic":
			return "毒属性・光属性・闇属性の系統。該当属性の与ダメージ+30%。ショップでポーションを消費してスキルを習得可能になります。"
		# ===== 専門性レリック（自然・生命系統） =====
		"water_sacred_crown":
			var hb = int(round(float(p.get("heal_bonus", 0.50)) * 100.0))
			var sp = int(p.get("spread_bonus", 1))
			return "水スキル【命の湧水】のHP回復量+%d%%。水マスの隣接拡大数+%d" % [hb, sp]
		"ice_crystal_crown":
			var db = int(p.get("durability_bonus", 1))
			var sb = int(round(float(p.get("shatter_bonus", 0.50)) * 100.0))
			return "氷スキル生成の耐久値+%d。雷による氷破壊ダメージ+%d%%" % [db, sb]
		"world_tree_seed":
			var ep = int(p.get("extra_plants", 1))
			var gm = float(p.get("growth_mult", 2.0))
			return "木スキルで苗木を%d本同時に植樹。成長速度%.1f倍" % [ep + 1, gm]
		"swift_wind_feather":
			var sw = int(p.get("sweep_bonus", 1))
			var wd = int(p.get("width_bonus", 0))
			return "風スキルの突風で消去する駒数+%d。列竜巻の幅+%d列" % [sw, wd]
		"flowing_water_charm":
			var wr = int(round(float(p.get("water_reduction", 0.10)) * 100.0))
			var sb = int(round(float(p.get("synergy_bonus", 0.10)) * 100.0))
			return "水マスが1つでも存在するとき、受けるダメージ-%d%%。水+火シナジー威力+%d%%" % [wr, sb]
		"frozen_earth_oath":
			var ic = int(p.get("ice_count", 1))
			return "ターン開始時、盤面のランダム%dマスに氷マス生成" % ic
		"vine_binding":
			var dt = int(p.get("delay_turns", 1))
			return "木スキル発動時、敵の行動を%dターン遅延" % dt
		"tide_ring":
			var pw = float(p.get("per_water", 0.015)) * 100.0
			var mb = int(round(float(p.get("max_bonus", 0.30)) * 100.0))
			return "水マス数×%.1f%%の全属性与ダメージボーナス（上限+%d%%）" % [pw, mb]
		# ===== 専門性レリック（元素・破壊系統） =====
		"blazing_fire_orb":
			var rb = int(p.get("range_bonus", 1))
			var sc = int(round(float(p.get("spread_chance", 0.50)) * 100.0))
			return "火スキルの燃焼範囲+%dマス。延焼確率%d%%" % [rb, sc]
		"thunder_god_bracelet":
			var cb = int(p.get("chain_bonus", 1))
			var rb = int(p.get("range_bonus", 0))
			return "雷スキルの連鎖数+%d。水マス上の感電範囲+%dマス" % [cb, rb]
		"earth_heart":
			var db = int(p.get("durability_bonus", 1))
			var qr = int(p.get("quake_radius", 1))
			return "石スキルの耐久値+%d。大地の激震の破壊範囲%dマス化" % [db, qr * 2 + 1]
		"demolition_book":
			var bd = int(round(float(p.get("bomb_damage", 0.20)) * 100.0))
			var br = int(p.get("blast_range", 0))
			return "爆弾系特殊駒のダメージ+%d%%。起爆範囲+%dマス" % [bd, br]
		"molten_iron_armor":
			var dp = float(p.get("dot_percent", 0.010)) * 100.0
			return "火マス上の敵に毎ターン最大HP%.1f%%の継続ダメージ" % dp
		"magnet_charm":
			var tb = int(round(float(p.get("thunder_bonus", 0.15)) * 100.0))
			return "雷スキル発動時、盤面の水マスを全範囲感電。雷ダメージ+%d%%" % tb
		"rock_fortress":
			var red = int(round(float(p.get("reduction", 0.10)) * 100.0))
			return "石マス隣接の自駒が受けるダメージ-%d%%" % red
		"superconduct_ring":
			var db = int(round(float(p.get("damage_bonus", 0.15)) * 100.0))
			return "雷スキルダメージ+%d%%" % db
		# ===== 専門性レリック（神秘・冥術系統） =====
		"venom_crown":
			var sb = int(p.get("stage_bonus", 1))
			var sm = float(p.get("spread_mult", 1.5))
			return "毒スキルの初期段階+%d。毒マスの伝染速度%.1f倍" % [sb, sm]
		"holy_lighthouse":
			var sd = int(round(float(p.get("statue_damage", 0.25)) * 100.0))
			var pb = int(p.get("pierce_bonus", 1))
			return "光スキルの聖像ダメージ+%d%%。聖光レーザー貫通数+%d" % [sd, pb]
		"void_ring":
			var pr = int(p.get("pull_radius", 1))
			var dr = int(round(float(p.get("drain_rate", 0.60)) * 100.0))
			return "闇スキルの吸引範囲+%dマス化。HP吸収率%d%%" % [pr * 2 + 1, dr]
		"underworld_contract":
			var sb = int(p.get("swap_bonus", 1))
			return "闇スキルで自由スワップ+%dターン追加" % sb
		"corrosion_charm":
			var db = int(round(float(p.get("damage_bonus", 0.10)) * 100.0))
			return "毒マス上の敵が受ける与ダメージ+%d%%" % db
		"sanctuary_lamp":
			var dr = int(round(float(p.get("damage_reduction", 0.25)) * 100.0))
			return "光スキル発動時、全聖像の被ダメージ-%d%%（1ターン）" % dr
		"shadow_pin":
			var dd = int(round(float(p.get("dark_damage", 0.10)) * 100.0))
			return "闇スキルの与ダメージ+%d%%" % dd
		"underworld_scale":
			var hr = int(round(float(p.get("heal_rate", 0.20)) * 100.0))
			return "敵撃破時、撃破ダメージの%d%%をHP吸収" % hr
		# ===== 専門性レリック（クロスカテゴリー） =====
		"elemental_affinity_ring":
			var sd = int(round(float(p.get("skill_damage", 0.08)) * 100.0))
			return "選択カテゴリーのスキルダメージ+%d%%" % sd
		"spirit_blessing":
			var sr = int(round(float(p.get("shield_ratio", 0.03)) * 100.0))
			return "スキル発動後、最大HPの%d%%のシールドを獲得" % sr
		"magic_crystal":
			var sd = int(round(float(p.get("skill_damage", 0.15)) * 100.0))
			var nb = int(round(float(p.get("next_match_bonus", 0.10)) * 100.0))
			return "スキルダメージ+%d%%。スキル発動後の次のマッチダメージ+%d%%" % [sd, nb]
		"ancient_dragon_scale":
			var cs = int(round(float(p.get("category_skill_damage", 0.25)) * 100.0))
			return "カテゴリー全スキルのダメージ+%d%%" % cs
		_:
			return r.get("description", "")
