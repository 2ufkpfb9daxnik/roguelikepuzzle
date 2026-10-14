class_name ElementData
extends RefCounted

enum Element {
	NONE = 0,
	FIRE = 1,
	WATER = 2,
	WIND = 3,
	THUNDER = 4,
	LIGHT = 5,
	DARK = 6
}

const ELEMENT_COLORS = {
	Element.NONE: Color(1, 1, 1, 0),
	Element.FIRE: Color(1.0, 0.4, 0.2),
	Element.WATER: Color(0.3, 0.6, 1.0),
	Element.WIND: Color(0.4, 0.9, 0.4),
	Element.THUNDER: Color(0.9, 0.9, 0.2),
	Element.LIGHT: Color(1.0, 0.9, 0.6),
	Element.DARK: Color(0.7, 0.3, 0.9)
}

static func get_element_name(el: Element) -> String:
	match el:
		Element.FIRE: return "fire"
		Element.WATER: return "water"
		Element.WIND: return "wind"
		Element.THUNDER: return "thunder"
		Element.LIGHT: return "light"
		Element.DARK: return "dark"
		_: return "none"

static func get_element_from_name(name: String) -> Element:
	match name:
		"fire": return Element.FIRE
		"water": return Element.WATER
		"wind": return Element.WIND
		"thunder": return Element.THUNDER
		"light": return Element.LIGHT
		"dark": return Element.DARK
		_: return Element.NONE

static func get_element_from_enemy_string(jp_str: String) -> Element:
	if jp_str.contains("火"): return Element.FIRE
	if jp_str.contains("水") or jp_str.contains("氷"): return Element.WATER
	if jp_str.contains("風") or jp_str.contains("地"): return Element.WIND
	if jp_str.contains("雷"): return Element.THUNDER
	if jp_str.contains("精霊") or jp_str.contains("光"): return Element.LIGHT
	if jp_str.contains("魔") or jp_str.contains("闇"): return Element.DARK
	return Element.NONE

static func get_damage_multiplier(attack_el: Element, defense_el: Element) -> float:
	if attack_el == Element.NONE: return 1.0
	if defense_el == Element.NONE: return 1.0
	
	match attack_el:
		Element.FIRE:
			if defense_el == Element.WIND: return 1.5
			if defense_el == Element.WATER: return 0.5
		Element.WATER:
			if defense_el == Element.FIRE: return 1.5
			if defense_el == Element.THUNDER: return 0.5
		Element.WIND:
			if defense_el == Element.THUNDER: return 1.5
			if defense_el == Element.FIRE: return 0.5
		Element.THUNDER:
			if defense_el == Element.WATER: return 1.5
			if defense_el == Element.WIND: return 0.5
		Element.LIGHT:
			if defense_el == Element.DARK: return 1.5
		Element.DARK:
			if defense_el == Element.LIGHT: return 1.5
			
	return 1.0

static func get_element_from_enemy_name(ename: String, stage_mgr: Node) -> int:
	if "ENEMY_SPECIES" in stage_mgr:
		var sp_data = stage_mgr.ENEMY_SPECIES.get(ename, {})
		var jp_el = sp_data.get("element", sp_data.get("race", ""))
		return get_element_from_enemy_string(jp_el)
	return Element.NONE
