class_name PlayerInputController
extends FighterController
## Traduit les actions d'entrée (boutons tactiles ou clavier) en intentions.
##
## Les appuis brefs (attaques, esquive) sont détectés à chaque image affichée dans _process,
## puis mémorisés jusqu'à la frame de physique suivante. Un tap tactile n'est donc jamais
## perdu entre deux frames de physique, quel que soit le rythme d'affichage du téléphone.
## Le déplacement et la garde, eux, restent actifs tant que le doigt est posé.

const TAP_ACTIONS: Array[StringName] = [&"attack_light", &"attack_heavy", &"dodge"]

var _latched: Dictionary = {}
var _was_pressed: Dictionary = {}


func _process(_delta: float) -> void:
	_detect_taps()


func read_intent(_fighter: Fighter, intent: FighterIntent) -> void:
	_detect_taps()
	intent.move_axis = Input.get_axis(&"move_left", &"move_right")
	intent.block = Input.is_action_pressed(&"block")
	intent.attack_light = _consume(&"attack_light")
	intent.attack_heavy = _consume(&"attack_heavy")
	intent.dodge = _consume(&"dodge")


## Oublie les appuis mémorisés (par exemple pendant l'écran de victoire). Un bouton encore
## tenu au moment de la revanche n'est pas compté comme un nouvel appui.
func reset() -> void:
	_latched.clear()
	for action in TAP_ACTIONS:
		_was_pressed[action] = Input.is_action_pressed(action)


func _detect_taps() -> void:
	for action in TAP_ACTIONS:
		var pressed := Input.is_action_pressed(action)
		if pressed and not _was_pressed.get(action, false):
			_latched[action] = true
		_was_pressed[action] = pressed


func _consume(action: StringName) -> bool:
	var value: bool = _latched.get(action, false)
	_latched[action] = false
	return value
