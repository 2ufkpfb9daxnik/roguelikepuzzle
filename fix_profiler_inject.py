import codecs
import re

files = ['puzzle_board.gd', 'board_overlay.gd', 'stage_manager.gd', 'skill_vfx_node.gd']
for file in files:
    with codecs.open(file, 'r', 'utf-8') as f:
        content = f.read()

    # The issue is we have lines like:
    # func _process(_delta:
    # 	var _prof = Profiler.begin("stage_manager::_process") float) -> void:
    
    # Let's fix them with regex:
    # Find unc (name)([^:]*?):\n\tvar _prof = Profiler.begin(".*?").*?\n
    # Wait, the injected text is in the middle of the signature!
    # Let's just remove ALL ar _prof = Profiler.begin(...) lines, and stitch the broken lines back together!
    
    lines = content.split('\n')
    out_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if 'var _prof = Profiler.begin(' in line:
            # Check if previous line was a broken func signature
            if out_lines and out_lines[-1].strip().startswith('func '):
                if not out_lines[-1].endswith('void:') and not out_lines[-1].endswith('bool:') and not out_lines[-1].endswith('Array[Vector2]:') and not out_lines[-1].endswith(')'):
                    # It was broken!
                    # The remainder of the signature is ON THIS LINE after the injected code.
                    idx = line.find(')')
                    if idx != -1:
                        # Wait, the remainder might be  float) -> void:
                        remainder = line.split(')')[-1]
                        # Actually, it's safer to just extract what's after ) if it was Profiler.begin("...")
                        # Let's find the closing parenthesis of Profiler.begin
                        b_idx = line.find('Profiler.begin(')
                        e_idx = line.find(')', b_idx)
                        if e_idx != -1:
                            remainder = line[e_idx+1:]
                            out_lines[-1] = out_lines[-1] + remainder
                            i += 1
                            continue
        out_lines.append(line)
        i += 1
        
    # Now re-inject correctly!
    content2 = '\n'.join(out_lines)
    
    # Inject properly: find the full signature unc name(...)...:\n
    # We can do this by finding unc name and looking for the FIRST \n that comes AFTER the : which marks the end of the signature.
    # Actually, GDScript signatures can be multi-line. But in this codebase they are mostly single line.
    # Let's just do a simpler replace.
    with codecs.open(file, 'w', 'utf-8') as f:
        f.write(content2)

print("SUCCESS")
