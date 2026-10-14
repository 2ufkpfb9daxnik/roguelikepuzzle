import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('	_redraw_board_effects()\n\n## 4.', '	_redraw_board_effects()\n\treturn _targets\n\n## 4.')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")
