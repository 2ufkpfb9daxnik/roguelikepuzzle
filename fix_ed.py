import codecs

with codecs.open('element_data.gd', 'r', 'utf-8') as f:
    text = f.read()

new_func = '''
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
'''

text += new_func

with codecs.open('element_data.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
