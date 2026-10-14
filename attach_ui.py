import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'signal combat_event' in lines[i]:
        # Add class ref at the top
        lines.insert(i-1, 'var combat_ui_manager: Node2D')
        break

for i in range(len(lines)):
    if 'func _ready() -> void:' in lines[i]:
        insert_code = '''	var CombatUIManager = load("res://combat_ui_manager.gd")
	if CombatUIManager:
		combat_ui_manager = CombatUIManager.new()
		combat_ui_manager.name = "CombatUIManager"
		add_child(combat_ui_manager)
		combat_event.connect(combat_ui_manager._on_combat_event)'''
        lines.insert(i+1, insert_code)
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
