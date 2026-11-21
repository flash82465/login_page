class_name VisualToggle
extends Control
## Bouton « Visuel » (mission 006) : passe des pantins animés aux capsules historiques et
## inversement, puis relance le combat. Répond à n'importe quel doigt (le premier peut tenir une
## flèche), à la souris et au clavier ; une seule demande par affichage.

signal choice_requested(choice: StringName)

const LABELS := {
	&"pantins": "Visuel : pantins animés  (toucher pour les capsules)",
	&"capsules": "Visuel : capsules historiques  (toucher pour les pantins)",
}

var choice: StringName = &"pantins"
var _touch_index: int = -1
var _sent: bool = false

@onready var _button: Button = $Button


func _ready() -> void:
	_button.text = LABELS.get(choice, "Visuel")
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
	choice_requested.emit(VisualSettings.other(choice))
