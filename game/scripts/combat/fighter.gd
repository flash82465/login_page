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
## Une nouvelle fenêtre de parade ne s'ouvre pas avant ce délai : marteler le bouclier
## ne rend pas invulnérable.
const PARRY_REARM_FRAMES := 30
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
## Génération visuelle (mission 005). Vide : le visuel de la scène (capsule, comme V0.4.1).
@export var visual_scene: PackedScene

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
var _parry_armed: bool = false
var _next_parry_frame: int = 0
var _buffered_attack: AttackData
var _buffer_frames: int = 0
var _spawn_position: Vector3
var _visual: FighterVisual

@onready var motor: FighterMotor = $Motor
@onready var hitbox: Hitbox = $Hitbox


func _ready() -> void:
	_spawn_position = global_position
	health = max_health
	add_to_group(&"fighters")
	hitbox.owner_fighter = self
	for child in $Hurtboxes.get_children():
		if child is Hurtbox:
			(child as Hurtbox).owner_fighter = self
	_setup_visual()
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
	if _visual != null:
		_visual.reset_visual()
	_block_started_frame = -1000
	_parry_armed = false
	_next_parry_frame = 0
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
	return state == State.BLOCK and _parry_armed and _frame - _block_started_frame <= PARRY_WINDOW_FRAMES


func is_attacking() -> bool:
	return state == State.ATTACK


## Vrai pendant la récupération d'une attaque : le combattant est punissable.
func is_recovering() -> bool:
	return state == State.ATTACK and current_attack != null \
		and _state_frame > current_attack.startup_frames + current_attack.active_frames


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
	_parry_armed = _frame >= _next_parry_frame
	if _parry_armed:
		_next_parry_frame = _frame + PARRY_REARM_FRAMES
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
	if _visual != null:
		_visual.flash(color, FLASH_FRAMES)


# --- Affichage : délégué à la génération visuelle (mission 005) ---------------------------

## Frame courante dans l'état (lecture seule, pour les visuels).
func get_state_frame() -> int:
	return _state_frame


func _setup_visual() -> void:
	if visual_scene != null:
		var previous := get_node_or_null("Visual")
		if previous != null:
			remove_child(previous)
			previous.queue_free()
		var replacement := visual_scene.instantiate()
		replacement.name = "Visual"
		add_child(replacement)
	_visual = get_node_or_null("Visual") as FighterVisual
	if _visual != null:
		_visual.bind(self)


func _update_visuals() -> void:
	if _visual != null:
		_visual.update_visual(self)
