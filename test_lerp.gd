
extends SceneTree
func _init():
    var v1 = Vector2(0, 0)
    var v2 = Vector2(100, 100)
    print(v1.lerp(v2, 1.5))
    quit()
