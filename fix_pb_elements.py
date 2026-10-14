import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

# Insert element pool logic
old_logic = r'(var raw_sword_cnt: int = min\(int\(\(sm\.ehp if sm else 0\) / swordt\), int\(score_mgr\.divscore\[PieceType\.SWORD\] / \(swordt \* 100\.0\)\)\))'

new_logic = r'''	var original_sword_score = score_mgr.divscore[PieceType.SWORD]
	var sword_element_pool = []
	if "turn_element_gain" in score_mgr and score_mgr.turn_element_gain.has(PieceType.SWORD):
		var total_allocated = 0
		if original_sword_score > 0:
			for el in score_mgr.turn_element_gain[PieceType.SWORD]:
				var el_score = score_mgr.turn_element_gain[PieceType.SWORD][el]
				var expected_cnt = min(int(sm.ehp / swordt), int(el_score / (swordt * 100.0))) if sm else 0
				# Approximate proportion for visually spawning
				var count = int(round(float(min(int(original_sword_score / (swordt * 100.0)), MAX_COMBAT_PROJECTILES)) * (float(el_score) / float(original_sword_score))))
				for j in range(count):
					sword_element_pool.append(el)
				total_allocated += count
	
	\1'''

text = re.sub(old_logic, new_logic, text)

# Insert element into sword dictionary
old_dict = r'("damage": dmg_per_sword\s*\})'
new_dict = r'''"damage": dmg_per_sword,
			"element": sword_element_pool[i] if i < sword_element_pool.size() else 0
		}'''
text = re.sub(old_dict, new_dict, text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
