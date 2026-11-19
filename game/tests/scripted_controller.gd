extends FighterController
## Contrôleur piloté par les tests : maintient un axe et une garde, envoie des appuis brefs.

var move_axis: float = 0.0
var block: bool = false
var _light: bool = false
var _heavy: bool = false
var _dodge: bool = false


func press_light() -> void:
	_light = true


func press_heavy() -> void:
	_heavy = true


func press_dodge() -> void:
	_dodge = true


func read_intent(_fighter: Fighter, intent: FighterIntent) -> void:
	intent.clear()
	intent.move_axis = move_axis
	intent.block = block
	intent.attack_light = _light
	intent.attack_heavy = _heavy
	intent.dodge = _dodge
	_light = false
	_heavy = false
	_dodge = false
