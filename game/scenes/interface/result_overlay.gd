class_name ResultOverlay
extends Control
## Écran de fin de combat : annonce le vainqueur et propose une revanche.
##
## « Rejouer » répond à la souris et à n'importe quel doigt : Android ne convertit en clic
## que le premier doigt posé, or le joueur garde souvent un doigt sur une flèche quand le
## combat se termine. Une seule revanche est demandée par affichage de l'écran.

signal restart_requested

var _restart_sent: bool = false
var _touch_index: int = -1

@onready var _title: Label = $Center/Box/Title
@onready var _restart: Button = $Center/Box/Restart


func _ready() -> void:
	visible = false
	_restart.pressed.connect(_request_restart)


func show_result(text: String) -> void:
	_title.text = text
	_restart_sent = false
	_touch_index = -1
	visible = true


func hide_result() -> void:
	visible = false


func result_text() -> String:
	return _title.text


func restart_button() -> Button:
	return _restart


func _input(event: InputEvent) -> void:
	if not visible or _restart_sent:
		return
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	var inside := _restart.get_global_rect().has_point(touch.position)
	if touch.pressed:
		if inside:
			_touch_index = touch.index
	elif touch.index == _touch_index:
		_touch_index = -1
		if inside:
			_request_restart()


func _request_restart() -> void:
	if _restart_sent or not visible:
		return
	_restart_sent = true
	restart_requested.emit()
