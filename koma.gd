extends Node2D

# 駒の種類を定義（整数や文字列などで種類を区別）
var koma_type: int
var textures = {}  # 駒の種類に対応するテクスチャ（画像ファイル）

# 初期化関数
func _ready():
	# 駒の種類に応じてテクスチャを設定
	match koma_type:
		0:
			$Sprite2D.texture = textures[0]  # 駒タイプ0用のテクスチャ
		1:
			$Sprite2D.texture = textures[1]  # 駒タイプ1用のテクスチャ
		# 他の駒の種類にも対応
		_:
			$Sprite2D.texture = textures.get(koma_type, textures[0])  # デフォルトテクスチャ
	
	# 駒の当たり判定用の初期化など（今後拡張可能）
	$CollisionShape2D.shape = RectangleShape2D.new()
	$CollisionShape2D.shape.extents = Vector2(32, 32)  # 駒のサイズに応じた当たり判定

# 駒の種類を設定する関数
func set_koma_type(type_id: int):
	koma_type = type_id
	_update_texture()

# 駒のテクスチャを更新する内部関数
func _update_texture():
	if textures.has(koma_type):
		$Sprite2D.texture = textures[koma_type]

# 駒のテクスチャを設定する関数（外部から呼ばれる）
func set_textures(texture_map: Dictionary):
	textures = texture_map
	_update_texture()
