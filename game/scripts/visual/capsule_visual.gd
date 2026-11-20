class_name CapsuleVisual
extends FighterVisual
## Génération visuelle « capsule » des versions 0.1 à 0.4.1 : corps en capsule, bras en boîte,
## bouclier bleu, marqueur d'orientation. Conservée à l'identique comme ancienne génération
## (mission 005, étape 1) : le code ci-dessous reprend ligne pour ligne la pose provisoire de
## Fighter._update_visuals() de V0.4.1.

var _material: StandardMaterial3D
var _body_color: Color = Color(0.55, 0.42, 0.3)
var _flash_frames: int = 0
var _flash_color: Color = Color(1.0, 0.3, 0.25)

@onready var _body_mesh: MeshInstance3D = $Body
@onready var _arm_pivot: Node3D = $ArmPivot
@onready var _arm_mesh: MeshInstance3D = $ArmPivot/Arm
@onready var _shield: MeshInstance3D = $Shield


func bind(fighter: Fighter) -> void:
	_body_color = fighter.body_color
	_material = StandardMaterial3D.new()
	_material.albedo_color = _body_color
	_body_mesh.material_override = _material
	_arm_mesh.material_override = _material


func flash(color: Color, frames: int) -> void:
	_flash_color = color
	_flash_frames = frames


func reset_visual() -> void:
	_flash_frames = 0


func update_visual(fighter: Fighter) -> void:
	var state_frame := fighter.get_state_frame()
	var arm_x := 0.0
	var arm_scale := 1.0
	var lean := 0.0
	if fighter.state == Fighter.State.ATTACK and fighter.current_attack != null:
		var attack := fighter.current_attack
		arm_scale = attack.arm_scale
		if state_frame <= attack.startup_frames:
			var t := float(state_frame) / attack.startup_frames
			arm_x = -0.15 * t
			lean = 0.08 * t
		elif state_frame <= attack.startup_frames + attack.active_frames:
			arm_x = 0.32
			lean = -0.18 * arm_scale
		else:
			var t := float(state_frame - attack.startup_frames - attack.active_frames) / attack.recovery_frames
			arm_x = 0.32 * (1.0 - t)
			lean = -0.18 * arm_scale * (1.0 - t)
	elif fighter.state == Fighter.State.HITSTUN:
		lean = 0.25
	elif fighter.state == Fighter.State.KO:
		lean = 1.35
	_arm_pivot.position.x = arm_x
	_arm_pivot.scale = Vector3(arm_scale, arm_scale, arm_scale)
	rotation.z = lean
	scale.y = 0.85 if fighter.is_invulnerable() and fighter.state == Fighter.State.DODGE else 1.0
	_shield.visible = fighter.is_blocking()
	if _flash_frames > 0:
		_flash_frames -= 1
		_material.albedo_color = _flash_color
	else:
		_material.albedo_color = _body_color
