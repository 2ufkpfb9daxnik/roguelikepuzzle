import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

def replace_func(content, func_name, new_body):
    pattern = r'(func ' + func_name + r'\b.*?\n)(?:(?:[ \t].*\n)|(?:^\s*\n))*'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return content[:match.start()] + new_body + '\n' + content[match.end():]
    return content

new_detonate_specials = '''func _detonate_specials(start_items: Array) -> void:
	var queue: Array = []
	var queued_set: Dictionary = {}
	
	for b in start_items:
		queue.append(b)
		queued_set[b] = true
		
	var exploded_items: Dictionary = {}

	while queue.size() > 0:
		var b = queue.pop_front()
		if b in exploded_items:
			continue
		exploded_items[b] = true

		var item_type: int = SpecialItemType.BOMB
		if special_item.size() == GRID_ROWS:
			item_type = special_item[b.x][b.y]
			if item_type == SpecialItemType.NONE and is_bomb.size() == GRID_ROWS and is_bomb[b.x][b.y]:
				item_type = SpecialItemType.BOMB
			special_item[b.x][b.y] = SpecialItemType.NONE
		if is_bomb.size() == GRID_ROWS:
			is_bomb[b.x][b.y] = false

		var pos = get_cell_position(b.x, b.y)

		# queued_setを利用するように変更することも可能ですが、
		# 既存のヘルパー関数を再利用するためそのままqueueを渡します。
		match item_type:
			SpecialItemType.BOMB:
				_trigger_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.CROSS_BOMB:
				_trigger_cross_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.TORNADO:
				_trigger_tornado(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.LIGHTNING:
				_trigger_lightning(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.BLACK_HOLE:
				_trigger_black_hole(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.GEMINI_BOMB:
				_trigger_gemini_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.MAGNET:
				_trigger_magnet(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.COLOR_CONVERTER:
				_trigger_color_converter(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.CHARGE_BOMB:
				_trigger_charge_bomb(b.x, b.y, pos, queue, exploded_items)

	for e in exploded_items.keys():
		ismatched[e.x][e.y] = true'''

content = replace_func(content, '_detonate_specials', new_detonate_specials)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
