import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re

# Fix control point calculation
old_cp = r'var mid = \(start_p \+ target_pos\) / 2\.0\s*var diff = target_pos - start_p\s*# diff is roughly.*?\s*# We want the normal.*?\s*# \(y, -x\).*?\s*var normal = Vector2\(diff\.y, -diff\.x\)\.normalized\(\)\s*var bow_distance = 2000\.0 \+ float\(randi\(\) % 3000\)\s*var cp = mid \+ normal \* bow_distance'

new_cp = r'''var mid_x = (start_p.x + target_pos.x) / 2.0
		var mid_y = (start_p.y + target_pos.y) / 2.0
		var bow_distance = 1500.0 + float(randi() % 4000)
		var cp = Vector2(mid_x, mid_y + bow_distance)'''

text = re.sub(old_cp, new_cp, text, flags=re.DOTALL)

# Fix ease_p
old_ease = r'var ease_p = pow\(progress, 2\.0\)'
new_ease = r'var ease_p = progress'
text = re.sub(old_ease, new_ease, text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
