import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

def add_mark_func():
    return '''
func _add_element_mark_to_sprite(sprite: Sprite2D) -> void:
	if sprite.has_node("ElementMark"): return
	var mark = Polygon2D.new()
	mark.name = "ElementMark"
	var pts = PackedVector2Array()
	for p_i in range(16):
		var ang = p_i * TAU / 16.0
		pts.append(Vector2(cos(ang), sin(ang)) * 25.0)
	mark.polygon = pts
	mark.position = Vector2(20, -20)
	mark.visible = false
	mark.material = CanvasItemMaterial.new()
	mark.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.add_child(mark)

func _update_piece_element_mark(p_idx: int, el: int) -> void:
	if p_idx < 0 or p_idx >= piece.size(): return
	var sp = piece[p_idx]
	if not is_instance_valid(sp): return
	var mark = sp.get_node_or_null("ElementMark")
	if is_instance_valid(mark):
		if el == ElementData.Element.NONE:
			mark.visible = false
		else:
			mark.visible = true
			mark.color = ElementData.ELEMENT_COLORS.get(el, Color.WHITE)
'''

lines.append(add_mark_func())

# inject into init sprite
for i in range(len(lines)):
    if 'sprite.texture = PIECE_TEXTURES[chosen_kind]' in lines[i]:
        lines.insert(i+4, '\t\t\t_add_element_mark_to_sprite(sprite)')
        break

# inject into continuous falling sprite
for i in range(len(lines)):
    if 'new_sprite.texture = PIECE_TEXTURES[nval]' in lines[i]:
        lines.insert(i+4, '\t\t\t\t_add_element_mark_to_sprite(new_sprite)')
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")
