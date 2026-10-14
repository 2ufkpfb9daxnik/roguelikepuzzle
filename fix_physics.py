import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

old_physics = '''func _update_falling_physics(delta: float) -> void:
	var all_landed: bool = true

	for item in falling_pieces:
		if item["landed"]:
			continue

		all_landed = false
		var s: Sprite2D = item["sprite"]
		var waypoints: Array[Vector2] = item["waypoints"]
		var wp_idx: int = item["wp_idx"]
		var target_pos: Vector2 = waypoints[wp_idx]
		var start_pos: Vector2 = item["current_start_pos"]

		item["velocity_y"] = minf(item["velocity_y"] + GRAVITY * delta, MAX_FALL_SPEED)
		var dy = item["velocity_y"] * delta

		if target_pos.y > start_pos.y:
			s.position.y += dy
			var total_dy = target_pos.y - start_pos.y
			var t = clampf((s.position.y - start_pos.y) / maxf(1.0, total_dy), 0.0, 1.0)
			s.position.x = lerpf(start_pos.x, target_pos.x, t)

			if s.position.y >= target_pos.y:
				s.position = target_pos
				item["wp_idx"] += 1
				if item["wp_idx"] < waypoints.size():
					item["current_start_pos"] = target_pos
				else:
					item["landed"] = true
					var bounce_tween = create_tween()
					bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
					bounce_tween.tween_property(s, "scale", cellsize, 0.08)
		else:
			var speed_h = 7500.0 * delta
			s.position = s.position.move_toward(target_pos, speed_h)
			if s.position.distance_to(target_pos) < 4.0:
				s.position = target_pos
				item["wp_idx"] += 1
				if item["wp_idx"] < waypoints.size():
					item["current_start_pos"] = target_pos
				else:
					item["landed"] = true
					var bounce_tween = create_tween()
					bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
					bounce_tween.tween_property(s, "scale", cellsize, 0.08)'''

new_physics = '''func _update_falling_physics(delta: float) -> void:
	var all_landed: bool = true

	for item in falling_pieces:
		if item["landed"]:
			continue

		all_landed = false
		var s: Sprite2D = item["sprite"]
		var waypoints: Array[Vector2] = item["waypoints"]
		var wp_idx: int = item["wp_idx"]
		var target_pos: Vector2 = waypoints[wp_idx]

		# なめらかにターゲットへ向かって直進させる
		item["velocity_y"] = minf(item["velocity_y"] + GRAVITY * delta, MAX_FALL_SPEED)
		var current_speed = item["velocity_y"]
		
		var dist = s.position.distance_to(target_pos)
		var step = current_speed * delta

		if dist <= step:
			s.position = target_pos
			item["wp_idx"] += 1
			if item["wp_idx"] < waypoints.size():
				item["current_start_pos"] = target_pos
				# 曲がるときに速度を少し落とすとなめらかに見える
				item["velocity_y"] = maxf(8000.0, item["velocity_y"] * 0.8)
			else:
				item["landed"] = true
				var bounce_tween = create_tween()
				bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
				bounce_tween.tween_property(s, "scale", cellsize, 0.08)
		else:
			s.position = s.position.move_toward(target_pos, step)'''

if old_physics in content:
    content = content.replace(old_physics, new_physics)
    with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
        f.write(content)
    print('SUCCESS')
else:
    print('FAIL')
