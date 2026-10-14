import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
for i in range(len(lines)):
    if 'match item_type:' in lines[i] and 'SpecialItemType.BOMB:' in lines[i+1]:
        start = i
        break

if start != -1:
    log_code = '''		var s_name = ""
		var s_elem = ""
		match item_type:
			SpecialItemType.BOMB, SpecialItemType.CHARGE_BOMB, SpecialItemType.GEMINI_BOMB, SpecialItemType.CROSS_BOMB:
				s_name = "bomb"
				s_elem = "fire"
			SpecialItemType.TORNADO, SpecialItemType.TREE_SPROUT:
				s_name = "tornado"
				s_elem = "wind"
			SpecialItemType.LIGHTNING, SpecialItemType.MAGNET:
				s_name = "lightning"
				s_elem = "thunder"
			SpecialItemType.AQUA_SPLASH:
				s_name = "aqua_splash"
				s_elem = "water"
			SpecialItemType.DISCO_BALL, SpecialItemType.COLOR_CONVERTER:
				s_name = "disco_ball"
				s_elem = "light"
			SpecialItemType.BLACK_HOLE:
				s_name = "black_hole"
				s_elem = "dark"
		if s_name != "":
			turn_skill_log.append({
				"name": s_name,
				"element": s_elem,
				"source": Vector2(b.x, b.y),
				"target": "all"
			})'''
    lines = lines[:start] + log_code.split('\n') + lines[start:]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
