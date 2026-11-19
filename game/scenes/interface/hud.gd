class_name Hud
extends Control
## Interface de combat minimaliste : vie des deux combattants et timer (cahier des charges A§28).
## L'énergie (Souffle), la jauge spéciale (Kalé) et le statut sont prévus mais pas encore affichés.

var _bound: bool = false

@onready var _left_name: Label = $TopBar/Left/Name
@onready var _left_bar: ProgressBar = $TopBar/Left/Health
@onready var _right_name: Label = $TopBar/Right/Name
@onready var _right_bar: ProgressBar = $TopBar/Right/Health
@onready var _timer: Label = $TopBar/Timer


func bind(left: Fighter, right: Fighter) -> void:
	_bind_fighter(left, _left_name, _left_bar)
	_bind_fighter(right, _right_name, _right_bar)
	_bound = true


func set_time(seconds: int) -> void:
	_timer.text = str(seconds)


func is_bound() -> bool:
	return _bound


func _bind_fighter(fighter: Fighter, label: Label, bar: ProgressBar) -> void:
	label.text = fighter.display_name
	bar.max_value = fighter.max_health
	bar.value = fighter.health
	fighter.health_changed.connect(
		func(current: float, maximum: float) -> void:
			bar.max_value = maximum
			bar.value = current
	)
