class_name AIController
extends FighterController
## IA basique — À DÉVELOPPER.
## Comportement actuel : s'approche jusqu'à une distance de garde, puis attend.
## Prévu : attaques, parades et esquives selon la distance et l'état de l'adversaire.

@export var preferred_distance: float = 1.6


func read_intent(fighter: Fighter, intent: FighterIntent) -> void:
	intent.clear()
	if fighter.opponent == null:
		return
	var dx := fighter.opponent.global_position.x - fighter.global_position.x
	if absf(dx) > preferred_distance:
		intent.move_axis = signf(dx)
