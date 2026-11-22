class_name DepthToggle
extends Control
## Bouton « Profondeur » (V0.6, étape 0), sous le bouton « Visuel » : active ou désactive l'option,
## l'enregistre, puis relance un combat neuf. Répond à n'importe quel doigt (le premier peut tenir
## une flèche) et à la souris ; une seule demande par affichage, comme le bouton « Visuel ».
## À l'étape 0, l'option ne change encore rien au combat (d'où « à venir »).

signal depth_requested(enabled: bool)

const LABELS := {
	false: "Profondeur : désactivée  (toucher pour l'activer)",
	true: "Profondeur : activée, à venir  (toucher pour désactiver)",
}

var enabled: bool = false
var _touch_index: int = -1
var _sent: bool = false

@onready var _button: Button = $Button


func _ready() -> void:
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
	if _sent:
		return
	_sent = true
	depth_requested.emit(not enabled)
