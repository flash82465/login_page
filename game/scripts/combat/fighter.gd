class_name Fighter
extends CharacterBody3D
## Combattant du prototype : machine à états, déplacement 2,5D sur l'axe X, vie, zones de frappe.
##
## IMPLÉMENTÉ : déplacement avec inertie, gravité, orientation vers l'adversaire, verrouillage
## du couloir de combat (Z = 0), vie et K.O., câblage des hitbox et hurtbox.
## À DÉVELOPPER : attaques, parade, esquive, étourdissement (voir game/README.md). Les
## méthodes request_* sont les points d'entrée prévus ; elles ne font encore rien.

enum State { IDLE, WALK, ATTACK, BLOCK, DODGE, HITSTUN, KO }

signal health_changed(current: float, maximum: float)
signal state_changed(previous: State, current: State)
signal knocked_out(fighter: Fighter)

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

var _intent := FighterIntent.new()
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

@onready var motor: FighterMotor = $Motor
@onready var hitbox: Hitbox = $Hitbox
@onready var _body_mesh: MeshInstance3D = $Visual/Body


func _ready() -> void:
	health = max_health
	add_to_group(&"fighters")
	hitbox.owner_fighter = self
	for child in $Hurtboxes.get_children():
		if child is Hurtbox:
			(child as Hurtbox).owner_fighter = self
	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	_body_mesh.material_override = material


func _physics_process(delta: float) -> void:
	if controller != null:
		controller.read_intent(self, _intent)
	else:
		_intent.clear()

	_update_facing()

	match state:
		State.IDLE, State.WALK:
			_process_free_movement(delta)
		_:
			# États d'action pas encore implémentés : le combattant freine sur place.
			velocity.x = motor.compute_velocity_x(velocity.x, 0.0, delta, mass_kg)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


func receive_damage(amount: float) -> void:
	if state == State.KO:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_set_state(State.KO)
		knocked_out.emit(self)


## Points d'entrée prévus pour les actions de combat (non implémentés dans ce socle).
func request_attack(_attack: AttackData) -> void:
	pass


func request_block(_active: bool) -> void:
	pass


func request_dodge(_direction: float) -> void:
	pass


func _process_free_movement(delta: float) -> void:
	velocity.x = motor.compute_velocity_x(velocity.x, _intent.move_axis, delta, mass_kg)
	_set_state(State.WALK if absf(velocity.x) > 0.05 else State.IDLE)
	if _intent.attack_light and light_attack != null:
		request_attack(light_attack)
	elif _intent.attack_heavy and heavy_attack != null:
		request_attack(heavy_attack)
	if _intent.dodge:
		request_dodge(_intent.move_axis)
	request_block(_intent.block)


func _update_facing() -> void:
	if opponent == null:
		return
	var dx := opponent.global_position.x - global_position.x
	if absf(dx) > 0.01:
		facing = signf(dx)
	rotation.y = 0.0 if facing > 0.0 else PI


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	state_changed.emit(previous, next)
