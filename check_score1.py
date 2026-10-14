import codecs

with codecs.open('current_stage.tscn', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'name="score1"' in lines[i]:
        for j in range(i, i+15):
            if 'offset_top' in lines[j] or 'offset_left' in lines[j]:
                print(str(j+1) + ': ' + lines[j].strip())
        break
