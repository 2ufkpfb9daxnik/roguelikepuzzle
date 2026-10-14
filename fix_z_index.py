import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('s.rotation = 0.0\n\t\t\ts.scale = Vector2.ONE', 's.rotation = 0.0\n\t\t\ts.scale = Vector2.ONE\n\t\t\ts.z_index = 0')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")
