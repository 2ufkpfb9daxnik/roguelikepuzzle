import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
for i in range(len(lines)):
    if 'var script_src = """' in lines[i]:
        start = i
        break

if start != -1:
    end = -1
    for i in range(start, start + 30):
        if 'var life_time = 0.0' in lines[i]:
            end = i
            break
    
    if end != -1:
        del lines[start+2:end]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
