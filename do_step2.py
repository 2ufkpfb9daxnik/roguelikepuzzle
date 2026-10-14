import codecs
import re

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

# 1. Update variables
vars_insert = '''var _cached_settings_manager: Node = null
var _cached_score_manager: Node2D = null
var _cached_puzzle_board: Node2D = null
'''
content = content.replace('var _rush_se_player: AudioStreamPlayer = null\n', 'var _rush_se_player: AudioStreamPlayer = null\n' + vars_insert)

# 2. Add to _ready
ready_insert = '''
	_cached_settings_manager = get_node_or_null("/root/SettingsManager")
	_cached_score_manager = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	_cached_puzzle_board = get_parent().get_node_or_null("PuzzleBoard") if get_parent() else null

	# タスク2-2: 敵テクスチャの事前非同期ロード
	for ename in ENEMY_TEXTURES:
		var path = ENEMY_TEXTURES[ename]
		if not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path)
'''
content = content.replace('func _ready() -> void:', 'func _ready() -> void:' + ready_insert)

# 3. Replace _get_game_speed
old_get_game_speed = '''func _get_game_speed() -> float:
	var root_node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	if root_node:
		var sm_autoload = root_node.get_node_or_null("SettingsManager")
		if sm_autoload and "game_speed" in sm_autoload:
			return sm_autoload.game_speed
	return Engine.time_scale'''

new_get_game_speed = '''func _get_game_speed() -> float:
	if _cached_settings_manager and is_instance_valid(_cached_settings_manager):
		if "game_speed" in _cached_settings_manager:
			return _cached_settings_manager.game_speed
	
	var root_node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	if root_node:
		var sm_autoload = root_node.get_node_or_null("SettingsManager")
		if sm_autoload:
			_cached_settings_manager = sm_autoload
			if "game_speed" in sm_autoload:
				return sm_autoload.game_speed
	return Engine.time_scale'''

content = content.replace(old_get_game_speed, new_get_game_speed)

# 4. Replace _get_score_manager and _get_puzzle_board
old_get_sm = '''func _get_score_manager() -> Node2D:
	return get_parent().get_node_or_null("ScoreManager")'''
new_get_sm = '''func _get_score_manager() -> Node2D:
	if not is_instance_valid(_cached_score_manager):
		_cached_score_manager = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	return _cached_score_manager'''
content = content.replace(old_get_sm, new_get_sm)

old_get_pb = '''func _get_puzzle_board() -> Node2D:
	return get_parent().get_node_or_null("PuzzleBoard")'''
new_get_pb = '''func _get_puzzle_board() -> Node2D:
	if not is_instance_valid(_cached_puzzle_board):
		_cached_puzzle_board = get_parent().get_node_or_null("PuzzleBoard") if get_parent() else null
	return _cached_puzzle_board'''
content = content.replace(old_get_pb, new_get_pb)

# 5. Modify texture loading in make_enemy to use load_threaded_get
# First we find the block
old_tex_load = '''			var tex: Texture2D = _cached_enemy_textures.get(ename)
			if tex == null:
				tex = load(ENEMY_TEXTURES[ename]) as Texture2D
				_cached_enemy_textures[ename] = tex'''
new_tex_load = '''			var tex: Texture2D = _cached_enemy_textures.get(ename)
			if tex == null:
				var path = ENEMY_TEXTURES[ename]
				if ResourceLoader.has_cached(path):
					# 非同期ロードが完了していればブロックなしで即時取得
					tex = ResourceLoader.load_threaded_get(path) as Texture2D
				if tex == null:
					# キャッシュミス時のフォールバック同期ロード
					tex = load(path) as Texture2D
				_cached_enemy_textures[ename] = tex'''
content = content.replace(old_tex_load, new_tex_load)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")
