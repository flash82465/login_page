extends Node
## Déclare les actions d'entrée au démarrage (chargé en autoload).
## Les boutons tactiles (scenes/interface/touch_controls.tscn) déclenchent ces mêmes actions ;
## le clavier sert uniquement aux tests sur ordinateur.

const ACTIONS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"attack_light": [KEY_J],
	&"attack_heavy": [KEY_K],
	&"block": [KEY_L],
	&"dodge": [KEY_SPACE],
}


func _enter_tree() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
