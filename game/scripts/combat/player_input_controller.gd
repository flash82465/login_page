class_name PlayerInputController
extends FighterController
## Traduit les actions d'entrée (boutons tactiles ou clavier) en intentions.


func read_intent(_fighter: Fighter, intent: FighterIntent) -> void:
	intent.move_axis = Input.get_axis(&"move_left", &"move_right")
	intent.attack_light = Input.is_action_just_pressed(&"attack_light")
	intent.attack_heavy = Input.is_action_just_pressed(&"attack_heavy")
	intent.block = Input.is_action_pressed(&"block")
	intent.dodge = Input.is_action_just_pressed(&"dodge")
