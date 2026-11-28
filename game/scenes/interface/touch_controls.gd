class_name TouchControls
extends Control
## Commandes tactiles Android.
##
## Lorsque l'option « Profondeur » est désactivée (défaut V0.5.0), les boutons Haut/Bas sont
## masqués et LeftPad reste à sa position historique exacte. Lorsque l'option est activée, les
## boutons Haut (-Z) et Bas (+Z) apparaissent en croix autour de Gauche/Droite.

const LEFT_PAD_TOP_2D := -200.0
const LEFT_PAD_BOTTOM_2D := -32.0
const LEFT_PAD_TOP_DEPTH := -276.0
const LEFT_PAD_BOTTOM_DEPTH := -108.0

var _depth_enabled: bool = false

@onready var _left_pad: Control = $LeftPad
@onready var _move_up: TouchScreenButton = $LeftPad/MoveUp
@onready var _move_down: TouchScreenButton = $LeftPad/MoveDown


func _ready() -> void:
	_apply_depth_mode()


func set_depth_enabled(enabled: bool) -> void:
	_depth_enabled = enabled
	if is_node_ready():
		_apply_depth_mode()


func is_depth_enabled() -> bool:
	return _depth_enabled


func _apply_depth_mode() -> void:
	_move_up.visible = _depth_enabled
	_move_down.visible = _depth_enabled
	if not _depth_enabled:
		if Input.is_action_pressed(&"move_up"):
			Input.action_release(&"move_up")
		if Input.is_action_pressed(&"move_down"):
			Input.action_release(&"move_down")
	_left_pad.offset_top = LEFT_PAD_TOP_DEPTH if _depth_enabled else LEFT_PAD_TOP_2D
	_left_pad.offset_bottom = LEFT_PAD_BOTTOM_DEPTH if _depth_enabled else LEFT_PAD_BOTTOM_2D
