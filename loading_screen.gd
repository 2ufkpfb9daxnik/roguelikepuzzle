extends Control

## ゲーム本編（current_stage.tscn）の読み込み中に表示する専用画面。
## 読み込み完了後、自動的に本編へ遷移する。

const TARGET_SCENE: String = "res://current_stage.tscn"
const MIN_DISPLAY_TIME: float = 0.25

var _status_lbl: Label = null
var _percent_lbl: Label = null
var _progress_bar: ProgressBar = null
var _title_lbl: Label = null

var _dot_time: float = 0.0
var _elapsed: float = 0.0
var _retry_timer: float = 0.0
var _finished: bool = false
var _web_sync_started: bool = false
var _packed_scene: PackedScene = null
var _progress: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	# タイトル画面側で開始済みの読み込みをそのまま引き継ぐ。
	# 未開始・失敗時のみ新規にリクエストする。
	var status: int = ResourceLoader.load_threaded_get_status(TARGET_SCENE)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
		ResourceLoader.load_threaded_request(TARGET_SCENE)

func _make_jp_font() -> Font:
	var f = load("res://font/NotoSansJP.ttf")
	f.set_fallbacks([load("res://font/NotoEmoji.ttf")])
	return f

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.012, 0.016, 0.028, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box = VBoxContainer.new()
	box.name = "LoadingBox"
	box.custom_minimum_size = Vector2(640.0, 0.0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var jp_font = _make_jp_font()

	_title_lbl = Label.new()
	_title_lbl.name = "Title"
	_title_lbl.text = "ROGUELIKE PUZZLE"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", jp_font)
	_title_lbl.add_theme_font_size_override("font_size", 40)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	_title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_lbl.add_theme_constant_override("outline_size", 8)
	box.add_child(_title_lbl)

	_status_lbl = Label.new()
	_status_lbl.name = "Status"
	_status_lbl.text = "NOW LOADING"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_override("font", jp_font)
	_status_lbl.add_theme_font_size_override("font_size", 26)
	_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	_status_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_lbl.add_theme_constant_override("outline_size", 6)
	box.add_child(_status_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.custom_minimum_size = Vector2(640.0, 28.0)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.08, 0.12, 1.0)
	bg_style.border_color = Color(0.45, 0.40, 0.20, 1.0)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(12)
	_progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.82, 0.25, 1.0)
	fill_style.set_corner_radius_all(10)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	box.add_child(_progress_bar)

	_percent_lbl = Label.new()
	_percent_lbl.name = "Percent"
	_percent_lbl.text = "0%"
	_percent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent_lbl.add_theme_font_override("font", jp_font)
	_percent_lbl.add_theme_font_size_override("font_size", 22)
	_percent_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	box.add_child(_percent_lbl)

	var hint = Label.new()
	hint.name = "Hint"
	hint.text = "読み込みが完了すると自動的にゲームが始まります"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", jp_font)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
	box.add_child(hint)

func _process(delta: float) -> void:
	if _finished:
		return

	# Webではスレッド読み込みが完了しない環境があるため、同期読み込みへ切り替える
	if OS.has_feature("web"):
		if not _web_sync_started:
			_web_sync_started = true
			set_process(false)
			_status_lbl.text = "NOW LOADING..."
			_load_web_sync.call_deferred()
		return

	_elapsed += delta
	_dot_time += delta
	_retry_timer = maxf(0.0, _retry_timer - delta)

	_progress.clear()
	var status: int = ResourceLoader.load_threaded_get_status(TARGET_SCENE, _progress)

	var pct: float = 0.0
	if not _progress.is_empty():
		pct = clampf(float(_progress[0]), 0.0, 1.0) * 100.0
	_progress_bar.value = pct
	_percent_lbl.text = "%d%%" % int(pct)

	var dot_count: int = int(_dot_time * 2.0) % 4
	_status_lbl.text = "NOW LOADING" + ".".repeat(dot_count)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if _packed_scene == null:
			_packed_scene = ResourceLoader.load_threaded_get(TARGET_SCENE) as PackedScene
		_progress_bar.value = 100.0
		_percent_lbl.text = "100%"
		_status_lbl.text = "COMPLETE!"
		if _packed_scene != null and _elapsed >= MIN_DISPLAY_TIME:
			_go_to_game()
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
		# 読み込みが開始されていない・失敗した場合は少し間隔を空けて再リクエスト
		if _retry_timer <= 0.0:
			_retry_timer = 0.5
			ResourceLoader.load_threaded_request(TARGET_SCENE)

func _go_to_game() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	get_tree().change_scene_to_packed(_packed_scene)

func _load_web_sync() -> void:
	# 1フレーム描画してから同期ロードする
	await get_tree().process_frame
	var packed = load(TARGET_SCENE) as PackedScene
	if packed != null:
		_packed_scene = packed
		_go_to_game()
	else:
		_status_lbl.text = "読み込みに失敗しました"
		set_process(true)
		_web_sync_started = false
