class_name AIController
extends FighterController
## IA de base de Mabé : s'approche, attaque, se met en garde ou esquive, recule parfois.
##
## Elle réagit aux attaques adverses avec un temps de réaction humain (10 frames) : les
## attaques légères, rapides, la surprennent souvent ; les lourdes peuvent être parées.
## Les choix sont aléatoires mais reproductibles (graine fixe), ce qui permet de la tester.

enum Plan { APPROACH, ATTACK, RETREAT, WAIT }

@export var attack_range: float = 0.95
@export var reaction_frames: int = 10
@export_range(0.0, 1.0) var block_chance: float = 0.3
@export_range(0.0, 1.0) var dodge_chance: float = 0.12
@export_range(0.0, 1.0) var heavy_chance: float = 0.3
@export var rng_seed: int = 20261119

var _rng := RandomNumberGenerator.new()
var _plan: Plan = Plan.APPROACH
var _plan_frames: int = 0
var _last_seen_attack_id: int = -1
var _pending_defense: int = 0  # 0 aucune, 1 garde, 2 esquive
var _defense_delay: int = 0
var _block_hold: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	_rng.seed = rng_seed
	_plan = Plan.APPROACH
	_plan_frames = 0
	_last_seen_attack_id = -1
	_pending_defense = 0
	_defense_delay = 0
	_block_hold = 0


func read_intent(fighter: Fighter, intent: FighterIntent) -> void:
	intent.clear()
	var opponent := fighter.opponent
	if opponent == null or fighter.state == Fighter.State.KO or opponent.state == Fighter.State.KO:
		return
	var dx := opponent.global_position.x - fighter.global_position.x
	var distance := absf(dx)
	var toward := signf(dx)

	# Défense : une nouvelle attaque adverse à portée déclenche, après un temps de réaction,
	# une garde ou une esquive (ou rien).
	if opponent.is_attacking() and opponent.current_attack_id != _last_seen_attack_id:
		_last_seen_attack_id = opponent.current_attack_id
		if distance < attack_range + 0.5:
			var roll := _rng.randf()
			if roll < block_chance:
				_pending_defense = 1
				_defense_delay = reaction_frames
			elif roll < block_chance + dodge_chance:
				_pending_defense = 2
				_defense_delay = reaction_frames
	if _pending_defense != 0:
		if _defense_delay > 0:
			_defense_delay -= 1
		else:
			if _pending_defense == 1:
				_block_hold = 24
			else:
				intent.dodge = true
				_pending_defense = 0
				return
			_pending_defense = 0
	if _block_hold > 0:
		_block_hold -= 1
		intent.block = true
		return

	# Attaque : approcher, frapper, puis laisser une ouverture.
	if _plan_frames > 0:
		_plan_frames -= 1
	else:
		_choose_plan(distance)
	match _plan:
		Plan.APPROACH:
			if distance > attack_range * 0.9:
				intent.move_axis = toward
			else:
				_plan_frames = 0
		Plan.ATTACK:
			if distance > attack_range:
				intent.move_axis = toward
			elif fighter.state == Fighter.State.IDLE or fighter.state == Fighter.State.WALK:
				if _rng.randf() < heavy_chance:
					intent.attack_heavy = true
				else:
					intent.attack_light = true
				_plan = Plan.WAIT
				_plan_frames = _rng.randi_range(18, 40)
		Plan.RETREAT:
			intent.move_axis = -toward
		Plan.WAIT:
			pass


func _choose_plan(distance: float) -> void:
	if distance > attack_range:
		_plan = Plan.APPROACH
		_plan_frames = 20
		return
	var roll := _rng.randf()
	if roll < 0.65:
		_plan = Plan.ATTACK
		_plan_frames = 30
	elif roll < 0.82:
		_plan = Plan.RETREAT
		_plan_frames = 12
	else:
		_plan = Plan.WAIT
		_plan_frames = 10
