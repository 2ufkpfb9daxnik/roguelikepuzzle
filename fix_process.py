import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Add to _process
tick_code = '''	Profiler.tick(delta)
	if delta > 0.03:
		var sp_cnt = 0
		for child in get_children():
			if child is Sprite2D: sp_cnt += 1
		var st_str = str(current_state)
		if "BoardState" in self and current_state >= 0 and current_state < BoardState.size():
			st_str = BoardState.keys()[current_state]
		print("[SLOW FRAME] delta: %.1fms | State: %s | Add: %d | Free: %d | Falling: %d | Sprites: %d" % [
			delta * 1000.0, st_str, Profiler.add_child_count, Profiler.queue_free_count, falling_pieces.size(), sp_cnt
		])
'''

# Find the start of _process
content = content.replace('func _process(delta: float) -> void:\n\tvar _prof = Profiler.begin("puzzle_board::_process")\n', 
'func _process(delta: float) -> void:\n\tvar _prof = Profiler.begin("puzzle_board::_process")\n' + tick_code)

# Let's count add_child and queue_free easily by regex
content = re.sub(r'(?<!Profiler\.)\badd_child\(', r'Profiler.add_child_count += 1; add_child(', content)
content = re.sub(r'(?<!Profiler\.)\bqueue_free\(\)', r'queue_free(); Profiler.queue_free_count += 1', content)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")
