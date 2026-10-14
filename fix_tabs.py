import codecs
import re

def fix_tabs(file_path):
    with codecs.open(file_path, 'r', 'utf-8') as f:
        lines = f.readlines()
    
    # Simple fix: any sequence of 4 spaces at the START of a line becomes 1 tab
    for i in range(len(lines)):
        # Calculate leading spaces
        l = lines[i]
        match = re.match(r'^( +)', l)
        if match:
            spaces = match.group(1)
            # Replace every 4 spaces with a tab
            num_tabs = len(spaces) // 4
            rem_spaces = len(spaces) % 4
            lines[i] = '\t' * num_tabs + ' ' * rem_spaces + l[len(spaces):]
            
    with codecs.open(file_path, 'w', 'utf-8') as f:
        f.writelines(lines)

fix_tabs('puzzle_board.gd')
fix_tabs('stage_manager.gd')
print("SUCCESS")
