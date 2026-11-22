class_name DepthToggle
extends Control
## Bouton « Profondeur » (V0.6, étape 0), sous le bouton « Visuel » : active ou désactive l'option,
## l'enregistre, puis relance un combat neuf. Répond à n'importe quel doigt (le premier peut tenir
## une flèche) et à la souris ; une seule demande par affichage, comme le bouton « Visuel ».
## À l'étape 0, l'option ne change encore rien au combat (d'où « à venir »).
##
## Correctif (essai Android de l'étape 0) : après une bascule, le combat est relancé avec un
## nouveau bouton ; un second toucher arrivé aussitôt (double toucher, rebond du doigt sur l'écran)
## le rebasculait, d'où un double redémarrage et un état inchangé. Le nouveau bouton ignore donc
## les touchers pendant `guard_frames` images de logique (réglé par le point d'entrée). Libellés
## sans ambiguïté : « NON » / « OUI ».

signal depth_requested(enabled: bool)

const LABELS := {
	false: "Profondeur : NON",
	true: "Profondeur : OUI (à venir)",
}

var enabled: bool = false
## Images de logique pendant lesquelles le bouton ignore les touchers après son apparition (0 au
## démarrage du jeu ; 0,4 s après une bascule de la profondeur).
var guard_frames: int = 0
var _touch_index: int = -1
var _sent: bool = false
var _shown_frame: int = 0

@onready var _button: Button = $Button


func _ready() -> void:
	_shown_frame = Engine.get_physics_frames()
	_button.text = LABELS[enabled]
	_button.pressed.connect(_request)


func button() -> Button:
	return _button


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not is_visible_in_tree():
		return
	var rect := _button.get_global_rect()
	if touch.pressed and _touch_index == -1 and rect.has_point(touch.position):
		_touch_index = touch.index
	elif not touch.pressed and touch.index == _touch_index:
		_touch_index = -1
		if rect.has_point(touch.position):
			_request()


func _request() -> void:
	# Une demande ignorée pendant la garde ne bloque pas le bouton : un toucher volontaire ensuite
	# fonctionne.
	if _sent or Engine.get_physics_frames() - _shown_frame < guard_frames:
		return
	_sent = true
	depth_requested.emit(not enabled)
