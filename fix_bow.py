import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re
old_code = r'var start_x = 12300\.0\s*var start_y = 5300\.0\s*var cp_x = \(start_x \+ target_pos\.x\) / 2\.0 \+ float\(randi\(\) % 6000 - 3000\)\s*var cp_y = min\(start_y, target_pos\.y\) - float\(randi\(\) % 2000\)'

new_code = r'''var start_x = 12300.0
		var start_y = 5300.0
		var start_p = Vector2(start_x, start_y)
		var mid = (start_p + target_pos) / 2.0
		var diff = target_pos - start_p
		# diff is roughly (-9300, -2600).
		# We want the normal pointing towards bottom-left, so (-y, x) -> (2600, -9300) is top-right.
		# (y, -x) -> (-2600, 9300) is bottom-left.
		var normal = Vector2(diff.y, -diff.x).normalized()
		var bow_distance = 2000.0 + float(randi() % 3000)
		var cp = mid + normal * bow_distance
		var cp_x = cp.x
		var cp_y = cp.y'''

text = re.sub(old_code, new_code, text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
