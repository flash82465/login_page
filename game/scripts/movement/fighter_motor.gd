class_name FighterMotor
extends Node
## Déplacement latéral avec inertie : un combattant lourd accélère et freine moins vite
## qu'un combattant léger (cahier des charges A§7).

@export var max_speed: float = 3.0  ## m/s
@export var acceleration: float = 18.0  ## m/s² pour un combattant de 80 kg
@export var deceleration: float = 24.0  ## m/s² pour un combattant de 80 kg
@export var reference_mass_kg: float = 80.0


func compute_velocity_x(current: float, axis: float, delta: float, mass_kg: float) -> float:
	var mass_factor := clampf(reference_mass_kg / maxf(mass_kg, 1.0), 0.5, 1.5)
	var target := clampf(axis, -1.0, 1.0) * max_speed
	var rate := (acceleration if absf(axis) > 0.01 else deceleration) * mass_factor
	return move_toward(current, target, rate * delta)
