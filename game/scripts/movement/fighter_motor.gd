class_name FighterMotor
extends Node
## Déplacement latéral avec inertie : un combattant lourd accélère et freine moins vite
## qu'un combattant léger (cahier des charges A§7).

@export var max_speed: float = 3.0  ## m/s
@export var max_depth_speed: float = 2.2  ## m/s (axe Z, option Profondeur)
@export var acceleration: float = 18.0  ## m/s² pour un combattant de 80 kg
@export var deceleration: float = 24.0  ## m/s² pour un combattant de 80 kg
@export var reference_mass_kg: float = 80.0


func compute_velocity_x(current: float, axis: float, delta: float, mass_kg: float) -> float:
	var mass_factor := clampf(reference_mass_kg / maxf(mass_kg, 1.0), 0.5, 1.5)
	var target := clampf(axis, -1.0, 1.0) * max_speed
	var rate := (acceleration if absf(axis) > 0.01 else deceleration) * mass_factor
	return move_toward(current, target, rate * delta)


func compute_velocity_z(current: float, axis: float, delta: float, mass_kg: float) -> float:
	var mass_factor := clampf(reference_mass_kg / maxf(mass_kg, 1.0), 0.5, 1.5)
	var target := clampf(axis, -1.0, 1.0) * max_depth_speed
	var rate := (acceleration if absf(axis) > 0.01 else deceleration) * mass_factor
	return move_toward(current, target, rate * delta)


func compute_velocity_xz(current: Vector2, axis_x: float, axis_z: float, delta: float, mass_kg: float) -> Vector2:
	if axis_z == 0.0:
		return Vector2(
			compute_velocity_x(current.x, axis_x, delta, mass_kg),
			compute_velocity_z(current.y, 0.0, delta, mass_kg)
		)
	var input := Vector2(clampf(axis_x, -1.0, 1.0), clampf(axis_z, -1.0, 1.0))
	if input.length_squared() > 1.0:
		input = input.normalized()
	return Vector2(
		compute_velocity_x(current.x, input.x, delta, mass_kg),
		compute_velocity_z(current.y, input.y, delta, mass_kg)
	)
