import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re
old_code = r'var start_x = float\(randi\(\) % 15000\)\s*var start_y = 5300\.0'
new_code = r'''var start_x = 12300.0
		var start_y = 5300.0'''

text = re.sub(old_code, new_code, text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
