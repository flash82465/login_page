class_name FighterController
extends Node
## Source d'intentions d'un combattant.
## Sous-classes : PlayerInputController (écran tactile ou clavier) et AIController.


func read_intent(_fighter: Fighter, intent: FighterIntent) -> void:
	intent.clear()
