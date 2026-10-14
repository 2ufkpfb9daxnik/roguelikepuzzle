import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'current_state = BoardState.IDLE' in lines[i]:
        if 'return' in lines[i+3]:
            # It's the messed up one
            tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
            lines[i+3] = '\t' * tabs + 'return'

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
