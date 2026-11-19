class_name ResultOverlay
extends Control
## Écran de fin de combat : annonce le vainqueur et propose une revanche.

signal restart_requested

@onready var _title: Label = $Center/Box/Title
@onready var _restart: Button = $Center/Box/Restart


func _ready() -> void:
	visible = false
	_restart.pressed.connect(func() -> void: restart_requested.emit())


func show_result(text: String) -> void:
	_title.text = text
	visible = true


func hide_result() -> void:
	visible = false


func result_text() -> String:
	return _title.text


func restart_button() -> Button:
	return _restart
