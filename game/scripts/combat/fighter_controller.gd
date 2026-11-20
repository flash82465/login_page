class_name FighterController
extends Node
## Source d'intentions d'un combattant.
## Sous-classes : PlayerInputController (écran tactile ou clavier) et AIController.


func read_intent(_fighter: Fighter, intent: FighterIntent) -> void:
	intent.clear()


## Appelé au début de chaque manche (après « Rejouer »).
func reset() -> void:
	pass
