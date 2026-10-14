import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Replace the 4 awaits to log their wall-clock time separately.
def replace_await(content, line_to_replace, name):
    replacement = f'''	var _t_aw_{name} = Time.get_ticks_usec()
	{line_to_replace}
	print("[AWAIT] {name} took %.2f ms" % ((Time.get_ticks_usec() - _t_aw_{name}) / 1000.0))'''
    return content.replace(line_to_replace, replacement)

content = replace_await(content, 'await tween.finished', 'tween_finished')
content = replace_await(content, 'await revert_tween.finished', 'revert_tween_finished')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")
