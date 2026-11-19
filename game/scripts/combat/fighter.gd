class_name Fighter
extends CharacterBody3D
## Combattant du prototype : machine à états à pas fixe (60 Hz), déplacement 2,5D sur l'axe X.
##
## États : IDLE / WALK (libre), ATTACK (démarrage → frames actives → récupération),
## BLOCK (garde tenue ; parade si la garde vient d'être levée), DODGE (pas d'esquive avec
## frames d'invulnérabilité), HITSTUN / BLOCKSTUN (réaction à un coup), KO.
## Les animations sont provisoires : poses du bras, inclinaison du corps, bouclier, éclat rouge.

enum State { IDLE, WALK, ATTACK, BLOCK, DODGE, HITSTUN, BLOCKSTUN, KO }

signal health_changed(current: float, maximum: float)
signal state_changed(previous: State, current: State)
signal knocked_out(fighter: Fighter)
signal attack_started(fighter: Fighter, attack: AttackData)

const INPUT_BUFFER_FRAMES := 6
const PARRY_WINDOW_FRAMES := 8
const DODGE_FRAMES := 20
const DODGE_INVULNERABLE_FROM := 2
const DODGE_INVULNERABLE_TO := 14
const DODGE_SPEED := 5.5
const DODGE_COOLDOWN_FRAMES := 30
const FLASH_FRAMES := 6
## Pendant un étourdissement, le corps glisse davantage : le recul reste visible.
const STUN_FRICTION_FACTOR := 0.35

@export var display_name: String = "Combattant"
@export var max_health: float = 100.0
@export var mass_kg: float = 80.0
@export var body_color: Color = Color(0.55, 0.42, 0.3)
@export var light_attack: AttackData
@export var heavy_attack: AttackData

var controller: FighterController
var opponent: Fighter
var health: float = 0.0
var state: State = State.IDLE
var facing: float = 1.0  ## +1 = regarde vers +X, -1 = regarde vers -X.
var input_enabled: bool = true
var current_attack: AttackData
var current_attack_id: int = 0

var _intent := FighterIntent.new()
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _frame: int = 0
var _state_frame: int = 0
var _freeze_frames: int = 0
var _stun_frames: int = 0
var _dodge_dir: float = 0.0
var _dodge_cooldown: int = 0
var _block_started_frame: int = -1000
var _buffered_attack: AttackData
var _buffer_frames: int = 0
var _flash_frames: int = 0
var _flash_color: Color = Color(1.0, 0.3, 0.25)
var _spawn_position: Vector3
var _material: StandardMaterial3D

@onready var motor: FighterMotor = $Motor
@onready var hitbox: Hitbox = $Hitbox
@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _arm_pivot: Node3D = $Visual/ArmPivot
@onready var _arm_mesh: MeshInstance3D = $Visual/ArmPivot/Arm
@onready var _shield: MeshInstance3D = $Visual/Shield


func _ready() -> void:
	_spawn_position = global_position
	health = max_health
	add_to_group(&"fighters")
	hitbox.owner_fighter = self
	for child in $Hurtboxes.get_children():
		if child is Hurtbox:
			(child as Hurtbox).owner_fighter = self
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_body_mesh.material_override = _material
	_arm_mesh.material_override = _material
	_update_visuals()


## Remet le combattant à neuf pour une nouvelle manche (restauration prévue par le mode, docs §48).
func reset_for_round() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	health = max_health
	input_enabled = true
	current_attack = null
	_buffered_attack = null
	_buffer_frames = 0
	_freeze_frames = 0
	_stun_frames = 0
	_dodge_cooldown = 0
	_flash_frames = 0
	_block_started_frame = -1000
	hitbox.deactivate()
	_enter(State.IDLE)
	health_changed.emit(health, max_health)
	_update_visuals()


func _physics_process(delta: float) -> void:
	_frame += 1
	if _freeze_frames > 0:
		_freeze_frames -= 1
		return
	if controller != null and input_enabled:
		controller.read_intent(self, _intent)
	else:
		_intent.clear()
	if _dodge_cooldown > 0:
		_dodge_cooldown -= 1
	_capture_buffered_attack()
	_state_frame += 1

	match state:
		State.IDLE, State.WALK:
			_update_facing()
			_process_free(delta)
		State.ATTACK:
			_process_attack(delta)
		State.BLOCK:
			_update_facing()
			_process_block(delta)
		State.DODGE:
			_process_dodge()
		State.HITSTUN, State.BLOCKSTUN:
			_process_stun(delta)
		State.KO:
			velocity.x = motor.compute_velocity_x(velocity.x, 0.0, delta, mass_kg)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0
	_update_visuals()


# --- Questions posées par le système de dégâts -------------------------------------------

func is_invulnerable() -> bool:
	if state == State.KO:
		return true
	return state == State.DODGE and _state_frame >= DODGE_INVULNERABLE_FROM and _state_frame <= DODGE_INVULNERABLE_TO


func is_blocking() -> bool:
	return state == State.BLOCK or state == State.BLOCKSTUN


func is_parrying() -> bool:
	return state == State.BLOCK and _frame - _block_started_frame <= PARRY_WINDOW_FRAMES


func is_attacking() -> bool:
	return state == State.ATTACK


# --- Conséquences appliquées par le système de dégâts ------------------------------------

func apply_hit(damage: float, stun_frames: int, knockback_velocity: float, blocked: bool) -> void:
	if state == State.KO:
		return
	health = maxf(0.0, health - damage)
	health_changed.emit(health, max_health)
	hitbox.deactivate()
	current_attack = null
	velocity.x = knockback_velocity
	if not blocked:
		_flash(Color(1.0, 0.3, 0.25))
	if health <= 0.0:
		velocity.x = knockback_velocity * 1.5
		_enter(State.KO)
		knocked_out.emit(self)
		return
	_stun_frames = stun_frames
	_enter(State.BLOCKSTUN if blocked else State.HITSTUN)


func apply_parry_stagger(stun_frames: int) -> void:
	hitbox.deactivate()
	current_attack = null
	_stun_frames = stun_frames
	velocity.x = -facing * 1.5
	_flash(Color(1.0, 1.0, 0.85))
	_enter(State.HITSTUN)


func apply_freeze(frames: int) -> void:
	_freeze_frames = maxi(_freeze_frames, frames)


# --- Traitement des états ----------------------------------------------------------------

func _capture_buffered_attack() -> void:
	if state == State.KO:
		return
	if _intent.attack_heavy and heavy_attack != null:
		_buffered_attack = heavy_attack
		_buffer_frames = INPUT_BUFFER_FRAMES
	elif _intent.attack_light and light_attack != null:
		_buffered_attack = light_attack
		_buffer_frames = INPUT_BUFFER_FRAMES
	elif _buffer_frames > 0:
		_buffer_frames -= 1
		if _buffer_frames == 0:
			_buffered_attack = null


func _process_free(delta: float) -> void:
	if _intent.dodge and _dodge_cooldown == 0:
		_start_dodge()
		return
	if _intent.block:
		_start_block()
		return
	if _buffered_attack != null:
		_start_attack(_buffered_attack)
		return
	velocity.x = motor.compute_velocity_x(velocity.x, _intent.move_axis, delta, mass_kg)
	_enter(State.WALK if absf(velocity.x) > 0.05 else State.IDLE)


func _start_attack(attack: AttackData) -> void:
	current_attack = attack
	current_attack_id += 1
	_buffered_attack = null
	_buffer_frames = 0
	_enter(State.ATTACK)
	attack_started.emit(self, attack)


func _process_attack(delta: float) -> void:
	velocity.x = motor.compute_velocity_x(velocity.x, 0.0, delta, mass_kg)
	var attack := current_attack
	if attack == null:
		_enter(State.IDLE)
		return
	var first_active := attack.startup_frames + 1
	var last_active := attack.startup_frames + attack.active_frames
	if _state_frame == first_active:
		hitbox.activate(attack, current_attack_id)
	if _state_frame >= first_active and _state_frame <= last_active:
		hitbox.scan()
	if _state_frame == last_active + 1:
		hitbox.deactivate()
	# hitbox.scan() peut avoir déclenché une parade adverse qui interrompt cette attaque.
	if state == State.ATTACK and _state_frame >= attack.total_frames():
		hitbox.deactivate()
		current_attack = null
		_enter(State.IDLE)


func _start_block() -> void:
	_block_started_frame = _frame
	_enter(State.BLOCK)


func _process_block(delta: float) -> void:
	velocity.x = motor.compute_velocity_x(velocity.x, 0.0, delta, mass_kg)
	if _intent.dodge and _dodge_cooldown == 0:
		_start_dodge()
	elif not _intent.block:
		_enter(State.IDLE)


func _start_dodge() -> void:
	_dodge_dir = signf(_intent.move_axis) if absf(_intent.move_axis) > 0.3 else -facing
	_dodge_cooldown = DODGE_COOLDOWN_FRAMES
	_enter(State.DODGE)


func _process_dodge() -> void:
	var t := float(_state_frame) / DODGE_FRAMES
	velocity.x = _dodge_dir * DODGE_SPEED * (1.0 - 0.7 * t)
	if _state_frame >= DODGE_FRAMES:
		_enter(State.IDLE)


func _process_stun(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, motor.deceleration * STUN_FRICTION_FACTOR * delta)
	if _state_frame >= _stun_frames:
		_enter(State.IDLE)


func _update_facing() -> void:
	if opponent == null:
		return
	var dx := opponent.global_position.x - global_position.x
	if absf(dx) > 0.01:
		facing = signf(dx)
	rotation.y = 0.0 if facing > 0.0 else PI


func _enter(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	_state_frame = 0
	state_changed.emit(previous, next)


func _flash(color: Color) -> void:
	_flash_color = color
	_flash_frames = FLASH_FRAMES


# --- Animation provisoire par la pose ----------------------------------------------------

func _update_visuals() -> void:
	var arm_x := 0.0
	var arm_scale := 1.0
	var lean := 0.0
	if state == State.ATTACK and current_attack != null:
		var attack := current_attack
		arm_scale = attack.arm_scale
		if _state_frame <= attack.startup_frames:
			var t := float(_state_frame) / attack.startup_frames
			arm_x = -0.15 * t
			lean = 0.08 * t
		elif _state_frame <= attack.startup_frames + attack.active_frames:
			arm_x = 0.32
			lean = -0.18 * arm_scale
		else:
			var t := float(_state_frame - attack.startup_frames - attack.active_frames) / attack.recovery_frames
			arm_x = 0.32 * (1.0 - t)
			lean = -0.18 * arm_scale * (1.0 - t)
	elif state == State.HITSTUN:
		lean = 0.25
	elif state == State.KO:
		lean = 1.35
	_arm_pivot.position.x = arm_x
	_arm_pivot.scale = Vector3(arm_scale, arm_scale, arm_scale)
	_visual.rotation.z = lean
	_visual.scale.y = 0.85 if is_invulnerable() and state == State.DODGE else 1.0
	_shield.visible = is_blocking()
	if _flash_frames > 0:
		_flash_frames -= 1
		_material.albedo_color = _flash_color
	else:
		_material.albedo_color = body_color
