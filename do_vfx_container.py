import codecs
import re

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

# Add _vfx_container
vars_insert = '''var _vfx_container: Node2D = null\n'''
content = content.replace('var _cached_puzzle_board: Node2D = null\n', 'var _cached_puzzle_board: Node2D = null\n' + vars_insert)

ready_insert = '''
	_vfx_container = Node2D.new()
	_vfx_container.name = "VFXContainer"
	add_child(_vfx_container)
'''
content = content.replace('func _ready() -> void:', 'func _ready() -> void:' + ready_insert)

# Replace call_group
content = content.replace('get_tree().call_group("enemy_skill_vfx", "queue_free")', '''if is_instance_valid(_vfx_container):
		for child in _vfx_container.get_children():
			child.queue_free()''')

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    pb_content = f.read()

pb_content = pb_content.replace('get_tree().call_group("enemy_skill_vfx", "queue_free")', '''var p = get_parent()
	if p and "vfx_container" in p: # Wait, I made it private _vfx_container. Let's use get_node_or_null("VFXContainer")!
		var vc = p.get_node_or_null("VFXContainer")
		if vc:
			for child in vc.get_children():
				child.queue_free()''')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(pb_content)

print("SUCCESS")
