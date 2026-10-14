import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

text = text.replace('ElementData.', 'ElementDataScript.')

lines = text.split('\n')
for i in range(len(lines)):
    if 'extends Node2D' in lines[i]:
        lines.insert(i+1, 'const ElementDataScript = preload("res://element_data.gd")')
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
