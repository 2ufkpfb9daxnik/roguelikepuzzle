import os
import re

files_to_check = [
    'puzzle_board.gd', 'stage_manager.gd', 'score_manager.gd',
    'board_background.gd', 'board_overlay.gd', 'skill_vfx_node.gd', 'buff_manager.gd'
]

patterns = {
    'get_node_in_process': r'func _process.*?get_node',
    'load_in_func': r'func .*?[\s=]load\(',
    'preload_in_func': r'func .*?[\s=]preload\(',
    'queue_redraw_in_process': r'func _process.*?queue_redraw',
    'frequent_instantiation': r'func .*?\.new\(',
    'nested_loops': r'for .*?:.*?for .*?:.*?for .*?:',
}

results = []

for file_name in files_to_check:
    if not os.path.exists(file_name): continue
    with open(file_name, 'r', encoding='utf-8') as f:
        content = f.read()
        
    lines = content.splitlines()
    in_process = False
    
    for i, line in enumerate(lines):
        if 'func _process' in line:
            in_process = True
        elif 'func ' in line:
            in_process = False
            
        if in_process and 'get_node' in line:
            results.append(f"{file_name}:{i+1}: get_node in _process -> {line.strip()}")
            
        if in_process and 'queue_redraw' in line:
            results.append(f"{file_name}:{i+1}: queue_redraw in _process -> {line.strip()}")
            
        if ' load(' in line or '=load(' in line or '= load(' in line:
            # load は関数外（メンバ初期化）ならOK、関数内だと重い
            if not line.strip().startswith('var'):
                results.append(f"{file_name}:{i+1}: dynamic load() -> {line.strip()}")
                
        if ' preload(' in line or '=preload(' in line or '= preload(' in line:
            # preload はパース時なのでそこまで重くないが、関数内でやると気になる
            pass
            
        if '.new()' in line and ('Sprite' in line or 'Node' in line or 'Audio' in line):
            results.append(f"{file_name}:{i+1}: Instance .new() -> {line.strip()}")
            
        if 'get_tree().call_group' in line:
            results.append(f"{file_name}:{i+1}: call_group (can be slow if frequent) -> {line.strip()}")

print('\n'.join(results))
