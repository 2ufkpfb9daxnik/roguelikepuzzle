import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

pool_defs = '''
# --- POOLING ---
const SE_POOL_SIZE = 8
var _se_pool: Array[AudioStreamPlayer] = []

const SPRITE_POOL_SIZE = 64
var _sprite_pool: Array[Sprite2D] = []

func _init_pools() -> void:
	for i in range(SE_POOL_SIZE):
		var asp = AudioStreamPlayer.new()
		add_child(asp)
		_se_pool.append(asp)
	for i in range(SPRITE_POOL_SIZE):
		var sp = Sprite2D.new()
		sp.visible = false
		add_child(sp)
		_sprite_pool.append(sp)

func _play_pooled_se(stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null: return
	for asp in _se_pool:
		if not asp.playing:
			asp.stream = stream
			asp.volume_db = vol_db
			asp.pitch_scale = pitch
			asp.play()
			return
	var fallback = _se_pool[0]
	fallback.stream = stream
	fallback.volume_db = vol_db
	fallback.pitch_scale = pitch
	fallback.play()

func _get_sprite_from_pool() -> Sprite2D:
	for s in _sprite_pool:
		if not s.visible:
			s.visible = true
			s.modulate = Color.WHITE
			s.rotation = 0.0
			s.scale = Vector2.ONE
			s.texture = null
			return s
	var new_s = Sprite2D.new()
	add_child(new_s)
	_sprite_pool.append(new_s)
	return new_s

func _return_sprite_to_pool(s: Sprite2D) -> void:
	if is_instance_valid(s):
		s.visible = false
		s.position = Vector2(-1e9, -1e9)
		if s.get_parent() == null:
			add_child(s)

# --- POOLING END ---
'''

# insert pool defs
content = content.replace('func _ready() -> void:\n', pool_defs + 'func _ready() -> void:\n\t_init_pools()\n')

# Replace AudioStreamPlayer.new() usages for attack/heal/hit
# We have enemy_attack_se, enemy_hit_se, etc.
# Instead of replacing everything, let's target the exact ones.
with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")
