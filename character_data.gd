class_name CharacterData
extends RefCounted

## オンライン対戦で選択できるキャラクター定義。
const DEFAULT_ID: String = "enemy1"

## 旧バージョンのキャラクターIDとの互換用
const LEGACY_ALIASES: Dictionary = {
	"knight": "enemy1",
	"beast": "enemy2",
	"mage": "enemy3",
	"dragon": "enemy17"
}

static var _all_characters_cache: Dictionary = {}

## ステージに登場する全キャラクター（敵種族）を本名で返す。
static func get_all() -> Dictionary:
	if not _all_characters_cache.is_empty():
		return _all_characters_cache
	var out: Dictionary = {}
	var sm_script = load("res://stage_manager.gd")
	if sm_script != null:
		var species: Dictionary = sm_script.ENEMY_SPECIES
		var textures: Dictionary = sm_script.ENEMY_TEXTURES
		for key in species.keys():
			var sp: Dictionary = species[key]
			out[str(key)] = {
				"name": str(sp.get("name", key)),
				"element": str(sp.get("element", sp.get("race", "無属性"))),
				"color": str(sp.get("color", "#FFFFFF")),
				"texture": str(textures.get(key, "")),
				"anim_key": str(key)
			}
	_all_characters_cache = out
	return _all_characters_cache

static func get_character(id: String) -> Dictionary:
	var all := get_all()
	var resolved_id: String = str(LEGACY_ALIASES.get(id, id))
	if all.has(resolved_id):
		return all[resolved_id]
	if all.has(DEFAULT_ID):
		return all[DEFAULT_ID]
	return {}

static func get_ids() -> Array:
	return get_all().keys()
