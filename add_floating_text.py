import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Add _spawn_floating_text if not exists
if 'func _spawn_floating_text' not in content:
    func_code = '''
func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var effects_parent = get_node_or_null("Effects")
	if effects_parent == null: effects_parent = self

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 45)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 1.0))
	lbl.add_theme_constant_override("outline_size", 6)
	
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	lbl.position = pos - Vector2(100.0, 50.0)
	lbl.custom_minimum_size = Vector2(200.0, 100.0)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	Profiler.add_child_count += 1; effects_parent.add_child(lbl)

	var tw = create_tween().set_parallel(true)
	lbl.scale = Vector2(0.5, 0.5)
	lbl.pivot_offset = lbl.custom_minimum_size / 2.0
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", pos.y - 150.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)
'''
    # insert before func _spawn_heal_number_effect
    content = content.replace('func _spawn_heal_number_effect', func_code + '\nfunc _spawn_heal_number_effect')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")
