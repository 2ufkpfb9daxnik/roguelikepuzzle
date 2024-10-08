extends Node2D

# 盤のサイズを設定（例として 5x5 の盤）
var grid_size = Vector2(5, 5)
var cell_size = Vector2(64, 64)  # 駒のサイズに基づく
var grid = []  # 2D配列として駒を格納

# 盤の形状を設定するためのマスの有効・無効リスト（例：無効な場所はfalse）
var valid_positions = [
	[true, true, true, true, true],
	[true, true, true, false, true],
	[true, true, true, true, true],
	[true, true, true, true, true],
	[true, true, true, true, true]
]

func _ready():
	create_grid()

# 盤を作成し、駒を配置する関数
func create_grid():
	# 配列の初期化
	grid.resize(grid_size.y)
	for y in range(grid_size.y):
		grid[y] = []
		for x in range(grid_size.x):
			if valid_positions[y][x]:  # 有効なマスなら駒を置く
				var koma = preload("res://path_to_koma_scene.tscn").instance()
				koma.position = Vector2(x * cell_size.x, y * cell_size.y)
				grid[y].append(koma)
				add_child(koma)
			else:
				grid[y].append(null)  # 無効な場所には駒を置かない

# 駒の再配置や盤のリセット処理を実装する関数
func reset_grid():
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if grid[y][x] != null:
				grid[y][x].queue_free()  # 既存の駒を削除
	create_grid()  # 盤を再生成
