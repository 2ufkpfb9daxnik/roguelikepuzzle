import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Fix effects_parent.Profiler.add_child_count += 1; add_child( -> Profiler.add_child_count += 1; effects_parent.add_child(
content = re.sub(r'(\w+)\.Profiler\.add_child_count \+= 1; add_child\(', r'Profiler.add_child_count += 1; \1.add_child(', content)

# Fix get_parent().Profiler.add_child_count += 1; add_child( -> Profiler.add_child_count += 1; get_parent().add_child(
content = content.replace('get_parent().Profiler.add_child_count += 1; add_child(', 'Profiler.add_child_count += 1; get_parent().add_child(')
content = content.replace('get_tree().Profiler.add_child_count += 1; add_child(', 'Profiler.add_child_count += 1; get_tree().add_child(')
content = content.replace('target_parent.Profiler.add_child_count += 1; add_child(', 'Profiler.add_child_count += 1; target_parent.add_child(')
content = content.replace('root_node.Profiler.add_child_count += 1; add_child(', 'Profiler.add_child_count += 1; root_node.add_child(')
content = content.replace('vc.Profiler.add_child_count += 1; add_child(', 'Profiler.add_child_count += 1; vc.add_child(')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")
