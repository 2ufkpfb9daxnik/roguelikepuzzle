import codecs
import re

files = ['puzzle_board.gd', 'board_overlay.gd', 'stage_manager.gd', 'skill_vfx_node.gd']
for file in files:
    with codecs.open(file, 'r', 'utf-8') as f:
        lines = f.readlines()

    # Remove all lines with Profiler.begin
    out_lines = [l for l in lines if 'Profiler.begin' not in l]

    content = ''.join(out_lines)

    # Now carefully inject.
    def inject(content, class_name, func_names):
        for fn in func_names:
            # Capture indentation before func!
            pattern = r'^([ \t]*)func ' + fn + r'\b(.*?:\s*\n)'
            replacement = r'\1func ' + fn + r'\2\1\tvar _prof = Profiler.begin("' + class_name + '::' + fn + '")\n'
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        return content

    if file == 'puzzle_board.gd':
        content = inject(content, 'puzzle_board', ['_process', '_update_falling_physics', '_check_cascade', '_check_matches_exist', '_start_match', '_start_continuous_falling', '_draw'])
    elif file == 'board_overlay.gd':
        content = inject(content, 'board_overlay', ['_process', '_draw'])
    elif file == 'stage_manager.gd':
        content = inject(content, 'stage_manager', ['_process', '_step_process'])
    elif file == 'skill_vfx_node.gd':
        content = inject(content, 'skill_vfx_node', ['_process', '_draw'])

    with codecs.open(file, 'w', 'utf-8') as f:
        f.write(content)

print("SUCCESS")
