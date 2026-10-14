import codecs
with codecs.open('board_overlay.gd', 'r', 'utf-8') as f:
    lines = f.readlines()
with codecs.open('board_overlay.gd', 'w', 'utf-8') as f:
    for i, line in enumerate(lines):
        if 'if board.grid_cursed[r][c]:' in line:
            f.write(line)
            f.write(lines[i+1])
            f.write('\n\tif \"grid_poison\" in board and board.grid_poison.size() == GRID_ROWS:\n')
            f.write('\t\tfor r in range(GRID_ROWS):\n')
            f.write('\t\t\tfor c in range(GRID_COLS):\n')
            f.write('\t\t\t\tif board.grid_poison[r][c]:\n')
            f.write('\t\t\t\t\t_draw_poison_tile(r, c, pulse)\n')
        elif '_draw_cursed_tile(r, c, pulse)' in line and 'if board.grid_cursed[r][c]:' in lines[i-1]:
            continue
        else:
            f.write(line)
