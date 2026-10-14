import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re
text = re.sub(r'var progress = clampf\(t / 50\.0, 0\.0, 1\.0\)', r'var progress = t / 50.0', text)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")
