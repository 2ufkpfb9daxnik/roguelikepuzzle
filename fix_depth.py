import codecs
import re

def fix_depth(file_path):
    with codecs.open(file_path, 'r', 'utf-8') as f:
        lines = f.readlines()
    
    for i in range(len(lines)):
        if '_t_aw_' in lines[i]:
            # Replace multiple leading tabs with just 1 tab if the next line has 1 tab.
            pass # Just manual fix for the specific lines
            
    # Actually let's just strip leading whitespace and re-apply \t for those specific lines
    for i in range(len(lines)):
        if 'var _t_aw_' in lines[i] or '[AWAIT]' in lines[i] or '[SPIKE]' in lines[i] or 'var _d_' in lines[i]:
            lines[i] = '\t' + lines[i].lstrip()
            # wait, in make_enemy it's deeper.
            # Let's match the next line's depth!
        
    for i in range(len(lines)):
        if 'var _t_aw_' in lines[i]:
            # The next line is await
            l2 = lines[i+1]
            tabs = len(l2) - len(l2.lstrip('\t'))
            lines[i] = '\t'*tabs + lines[i].lstrip()
        elif '[AWAIT]' in lines[i]:
            # The prev line is await
            l2 = lines[i-1]
            tabs = len(l2) - len(l2.lstrip('\t'))
            lines[i] = '\t'*tabs + lines[i].lstrip()

        if 'var _d_me =' in lines[i] or '[SPIKE] make_enemy' in lines[i] or 'var _t_me =' in lines[i]:
            lines[i] = '\t' + lines[i].lstrip()
            
        if 'var _d_load =' in lines[i] or '[SPIKE] load_threaded_get' in lines[i] or 'var _t_load =' in lines[i]:
            lines[i] = '\t\t\t' + lines[i].lstrip()

    with codecs.open(file_path, 'w', 'utf-8') as f:
        f.writelines(lines)

fix_depth('puzzle_board.gd')
fix_depth('stage_manager.gd')
print("SUCCESS")
