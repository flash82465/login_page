class_name FightCamera
extends Camera3D
## Caméra latérale de combat : garde les deux combattants entiers à l'écran et recule
## quand ils s'éloignent (docs/gameplay/systeme-combat.md §10).
##
## Correctif mission 003 : la caméra ne suit plus le milieu des combattants en continu.
## Elle ne se déplace que si ce milieu sort d'une zone morte, et reste dans les limites de
## l'arène. Sinon, un combattant qui avance puis s'arrête semblait « revenir » à l'écran
## pendant que la caméra finissait de se recentrer.

@export var height: float = 1.3
@export var min_distance: float = 4.0
@export var distance_per_meter: float = 0.8
@export var smoothing: float = 5.0
@export var dead_zone: float = 1.2
@export var arena_half_width: float = 8.15
@export var edge_margin: float = 2.5

var _a: Node3D
var _b: Node3D
var _focus_x: float = 0.0


func set_targets(a: Node3D, b: Node3D) -> void:
	_a = a
	_b = b
	_focus_x = _clamp_focus(_mid_x())
	global_position = _target_position()
	look_at(Vector3(_focus_x, height - 0.25, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _a == null or _b == null:
		return
	var mid := _mid_x()
	if mid > _focus_x + dead_zone:
		_focus_x = mid - dead_zone
	elif mid < _focus_x - dead_zone:
		_focus_x = mid + dead_zone
	_focus_x = _clamp_focus(_focus_x)
	global_position = global_position.lerp(_target_position(), 1.0 - exp(-smoothing * delta))
	look_at(Vector3(global_position.x, height - 0.25, 0.0), Vector3.UP)


func _mid_x() -> float:
	return (_a.global_position.x + _b.global_position.x) * 0.5


func _clamp_focus(x: float) -> float:
	var limit := maxf(0.0, arena_half_width - edge_margin)
	return clampf(x, -limit, limit)


func _target_position() -> Vector3:
	var separation := absf(_a.global_position.x - _b.global_position.x)
	return Vector3(_focus_x, height, maxf(min_distance, separation * distance_per_meter + 2.5))
