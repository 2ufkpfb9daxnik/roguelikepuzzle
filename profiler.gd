class_name Profiler
extends RefCounted

const PROFILE := true

static var records: Dictionary = {}
static var last_print_time: int = 0

static var max_frame_time: float = 0.0
static var frames_over_33ms: int = 0
static var add_child_count: int = 0
static var queue_free_count: int = 0

class Scope extends RefCounted:
	var func_name: String
	var start_time: int
	func _init(n: String):
		func_name = n
		start_time = Time.get_ticks_usec()
	func _notification(what):
		if what == NOTIFICATION_PREDELETE:
			var script = load("res://profiler.gd")
			if script:
				script.end(func_name, start_time)

static func begin(n: String) -> Scope:
	if not PROFILE: return null
	return Scope.new(n)

static func end(func_name: String, start_time: int, draws: int = 0) -> void:
	if not PROFILE: return
	var elapsed = Time.get_ticks_usec() - start_time
	if not records.has(func_name):
		records[func_name] = {"total_usec": 0, "count": 0, "max_usec": 0, "draws": 0}

	var r = records[func_name]
	r["total_usec"] += elapsed
	r["count"] += 1
	r["draws"] += draws
	if elapsed > r["max_usec"]:
		r["max_usec"] = elapsed

static func tick(delta: float) -> void:
	var d_ms = delta * 1000.0
	if d_ms > max_frame_time: max_frame_time = d_ms
	if d_ms > 33.0: frames_over_33ms += 1
		
	var now = Time.get_ticks_msec()
	if now - last_print_time >= 1000:
		print_stats()
		last_print_time = now
		max_frame_time = 0.0
		frames_over_33ms = 0
		add_child_count = 0
		queue_free_count = 0

static func print_stats() -> void:
	print("\n--- Profile Stats (1 Sec) ---")
	print("FPS: ", Performance.get_monitor(Performance.TIME_FPS))
	print("PROCESS_MS: %.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0))
	print("DRAW_CALLS: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("OBJECTS_IN_FRAME: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("NODE_COUNT: ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("VIDEO_MEM: %.2f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	print("Max Frame Time: %.2f ms" % max_frame_time)
	print("Frames > 33ms: ", frames_over_33ms)
	print("AddChild / 1s: ", add_child_count)
	print("QueueFree / 1s: ", queue_free_count)
	
	var sorted_keys = records.keys()
	sorted_keys.sort_custom(func(a, b): return records[a]["total_usec"] > records[b]["total_usec"])
	
	for k in sorted_keys:
		var r = records[k]
		var avg = (float(r["total_usec"]) / r["count"]) / 1000.0 if r["count"] > 0 else 0.0
		var mx = r["max_usec"] / 1000.0
		var tot = r["total_usec"] / 1000.0
		if r["draws"] > 0:
			print("%s: Total %.2fms | Count %d | Max %.2fms | Avg %.2fms | Draws %d" % [k, tot, r["count"], mx, avg, r["draws"]])
		else:
			print("%s: Total %.2fms | Count %d | Max %.2fms | Avg %.2fms" % [k, tot, r["count"], mx, avg])
		r["total_usec"] = 0
		r["count"] = 0
		r["max_usec"] = 0
		r["draws"] = 0
	print("-----------------------------\n")
