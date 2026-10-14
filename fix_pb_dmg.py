import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

# Modify _emit_combat_event signature
old_sig = r'func _emit_combat_event\(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false\) -> void:'
new_sig = r'func _emit_combat_event(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false, effectiveness: String = "normal") -> void:'
text = re.sub(old_sig, new_sig, text)

# Add effectiveness to dictionary
old_dict = r'("is_critical": is_critical\s*\})'
new_dict = r'"is_critical": is_critical,\n\t\t"effectiveness": effectiveness\n\t}'
text = re.sub(old_dict, new_dict, text)

# Modify the hit logic to calculate damage
old_hit = r'(if sm:\s*var dmg: float = item\.get\("damage", 100\.0 \* swordt\)\s*sm\.calchp\(dmg, 0\)\s*_emit_combat_event\("damage", "ally", "enemy", dmg\))'
new_hit = r'''if sm:
					var base_dmg: float = item.get("damage", 100.0 * swordt)
					var atk_el = item.get("element", 0)
					var def_el = 0
					if sm.has_method("get_current_enemy_element"):
						var jp_el = sm.get_current_enemy_element()
						def_el = ElementDataScript.get_element_from_enemy_string(jp_el)
						
					var mult = ElementDataScript.get_damage_multiplier(atk_el, def_el)
					var final_dmg = base_dmg * mult
					sm.calchp(final_dmg, 0)
					
					var eff_str = "normal"
					if mult >= 1.2: eff_str = "weak"
					elif mult <= 0.8: eff_str = "resist"
					
					var el_str = ElementDataScript.get_element_name(atk_el)
					_emit_combat_event("damage", "ally", "enemy", final_dmg, el_str, false, eff_str)'''
text = re.sub(old_hit, new_hit, text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
