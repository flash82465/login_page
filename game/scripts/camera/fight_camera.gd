class_name FightCamera
extends Camera3D
## Caméra latérale de combat : garde les deux combattants entiers à l'écran et recule
## quand ils s'éloignent (docs/gameplay/systeme-combat.md §10).

@export var height: float = 1.3
@export var min_distance: float = 4.0
@export var distance_per_meter: float = 0.8
@export var smoothing: float = 6.0

var _a: Node3D
var _b: Node3D


func set_targets(a: Node3D, b: Node3D) -> void:
	_a = a
	_b = b
	global_position = _target_position()


func _process(delta: float) -> void:
	if _a == null or _b == null:
		return
	global_position = global_position.lerp(_target_position(), 1.0 - exp(-smoothing * delta))
	var mid_x := (_a.global_position.x + _b.global_position.x) * 0.5
	look_at(Vector3(mid_x, height - 0.25, 0.0), Vector3.UP)


func _target_position() -> Vector3:
	var mid_x := (_a.global_position.x + _b.global_position.x) * 0.5
	var separation := absf(_a.global_position.x - _b.global_position.x)
	return Vector3(mid_x, height, maxf(min_distance, separation * distance_per_meter + 2.5))
