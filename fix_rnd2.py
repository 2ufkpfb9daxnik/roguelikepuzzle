import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 's.position.x += 10.0 + rnd' in lines[i]:
        lines[i] = lines[i].replace('rnd', 'item.get("rnd", 0.0)')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
