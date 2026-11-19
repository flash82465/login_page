class_name FighterIntent
extends RefCounted
## Ce qu'un contrôleur (joueur ou IA) demande à un combattant pour la frame courante.
## Le combattant décide ensuite, selon son état, de ce qu'il peut réellement faire.

var move_axis: float = 0.0  ## -1 = vers la gauche de l'écran, +1 = vers la droite.
var attack_light: bool = false
var attack_heavy: bool = false
var block: bool = false
var dodge: bool = false


func clear() -> void:
	move_axis = 0.0
	attack_light = false
	attack_heavy = false
	block = false
	dodge = false
