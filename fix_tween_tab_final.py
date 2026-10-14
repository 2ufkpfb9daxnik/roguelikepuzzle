import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'var _t_aw_tween_finished' in lines[i]:
        # we can just use 1 tab if it's around 775, and 3 tabs if it's around 2989
        if i < 1000:
            lines[i] = '\t' + lines[i].lstrip()
            lines[i+1] = '\t' + lines[i+1].lstrip()
            lines[i+2] = '\t' + lines[i+2].lstrip()
        else:
            lines[i] = '\t\t\t' + lines[i].lstrip()
            lines[i+1] = '\t\t\t' + lines[i+1].lstrip()
            lines[i+2] = '\t\t\t' + lines[i+2].lstrip()

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
