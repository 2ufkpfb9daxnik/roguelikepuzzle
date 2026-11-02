extends SceneTree

## 氷・木の属性アイコンテクスチャ生成（スキル駒の幾何学マークに準拠）
func _init() -> void:
	_generate_ice_icon()
	_generate_wood_icon()
	quit(0)

func _generate_ice_icon() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(32, 32)
	# 六角氷晶のアーム（6方向）
	for k in range(6):
		var ang := k * PI / 3.0
		var dir := Vector2(cos(ang), sin(ang))
		_draw_thick_line(img, center, center + dir * 22.0, Color(0.7, 0.95, 1.0, 1.0), 3.0)
		var branch_pos := center + dir * 13.0
		var b1 := Vector2(cos(ang + PI / 4.0), sin(ang + PI / 4.0)) * 7.0
		var b2 := Vector2(cos(ang - PI / 4.0), sin(ang - PI / 4.0)) * 7.0
		_draw_thick_line(img, branch_pos, branch_pos + b1, Color(0.85, 1.0, 1.0, 1.0), 2.0)
		_draw_thick_line(img, branch_pos, branch_pos + b2, Color(0.85, 1.0, 1.0, 1.0), 2.0)
	# 中心の白いコア
	_draw_filled_circle(img, center, 5.0, Color.WHITE)
	# 外周の淡いシアンリング
	_draw_ring(img, center, 28.0, Color(0.3, 0.9, 1.0, 0.9), 2.0)
	img.save_png("res://Texture/element/ice.png")
	print("Generated ice.png")

func _generate_wood_icon() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(32, 32)
	# 茎
	_draw_thick_line(img, center + Vector2(0, 22), center + Vector2(0, 4), Color(0.4, 0.85, 0.3, 1.0), 4.0)
	_draw_thick_line(img, center + Vector2(0, 4), center + Vector2(-1, -5), Color(0.4, 0.85, 0.3, 1.0), 3.0)
	# 左の葉
	var leaf_l := PackedVector2Array([
		center + Vector2(0, 0),
		center + Vector2(-10, -6),
		center + Vector2(-22, -8),
		center + Vector2(-17, 2),
		center + Vector2(-6, 4)
	])
	_draw_filled_polygon(img, leaf_l, Color(0.28, 0.95, 0.38, 1.0))
	# 右の葉
	var leaf_r := PackedVector2Array([
		center + Vector2(0, -2),
		center + Vector2(10, -8),
		center + Vector2(22, -10),
		center + Vector2(17, 0),
		center + Vector2(6, 2)
	])
	_draw_filled_polygon(img, leaf_r, Color(0.42, 1.0, 0.52, 1.0))
	# 外周の緑リング
	_draw_ring(img, center, 28.0, Color(0.3, 1.0, 0.4, 0.9), 2.0)
	img.save_png("res://Texture/element/wood.png")
	print("Generated wood.png")

func _draw_thick_line(img: Image, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var steps := int(max(absf(to.x - from.x), absf(to.y - from.y))) + 1
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		_draw_filled_circle(img, p, width * 0.5, color)

func _draw_filled_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r := int(ceil(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= radius * radius:
				var px := int(center.x) + dx
				var py := int(center.y) + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)

func _draw_ring(img: Image, center: Vector2, radius: float, color: Color, thickness: float) -> void:
	var r_out := radius + thickness * 0.5
	var r_in := radius - thickness * 0.5
	var r := int(ceil(r_out))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= r_in and dist <= r_out:
				var px := int(center.x) + dx
				var py := int(center.y) + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)

func _draw_filled_polygon(img: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for p in points:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for py in range(int(floor(min_y)), int(ceil(max_y)) + 1):
		for px in range(int(floor(min_x)), int(ceil(max_x)) + 1):
			if _point_in_polygon(Vector2(px, py), points):
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)

func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var pi := polygon[i]
		var pj := polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside
