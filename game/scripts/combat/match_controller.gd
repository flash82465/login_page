extends Node3D
## Orchestration d'un combat : relie combattants, contrôleurs, caméra, interface et dégâts.
## Lancé avec l'argument utilisateur --smoke-test, il vérifie le socle puis quitte
## avec un code de sortie (utilisé par la CI : voir .github/workflows/android-build.yml).

@export var round_seconds: int = 99
@export var smoke_test_frames: int = 120

var _time_left: float = 0.0
var _smoke_test: bool = false
var _frames: int = 0
var _start_distance: float = 0.0

@onready var fighter_a: Fighter = $Fighters/FighterA
@onready var fighter_b: Fighter = $Fighters/FighterB
@onready var camera: FightCamera = $FightCamera
@onready var hud: Hud = $Interface/HUD


func _ready() -> void:
	fighter_a.opponent = fighter_b
	fighter_b.opponent = fighter_a
	fighter_a.controller = $Controllers/Player
	fighter_b.controller = $Controllers/AI
	camera.set_targets(fighter_a, fighter_b)
	hud.bind(fighter_a, fighter_b)
	for fighter: Fighter in [fighter_a, fighter_b]:
		fighter.hitbox.hit_detected.connect(_on_hit_detected.bind(fighter))
	_time_left = float(round_seconds)
	hud.set_time(round_seconds)
	_start_distance = absf(fighter_a.global_position.x - fighter_b.global_position.x)
	_smoke_test = OS.get_cmdline_user_args().has("--smoke-test")
	if _smoke_test:
		print("SMOKE TEST: démarrage")


func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left = maxf(0.0, _time_left - delta)
		hud.set_time(int(ceil(_time_left)))


func _physics_process(_delta: float) -> void:
	if not _smoke_test:
		return
	_frames += 1
	if _frames == smoke_test_frames:
		_finish_smoke_test()


func _on_hit_detected(hurtbox: Hurtbox, attack: AttackData, attack_id: int, attacker: Fighter) -> void:
	DamageService.resolve_hit(attacker, hurtbox.owner_fighter, hurtbox, attack, attack_id)


func _finish_smoke_test() -> void:
	var failures: PackedStringArray = []
	if get_tree().get_nodes_in_group(&"fighters").size() != 2:
		failures.append("il faut exactement 2 combattants")
	for fighter: Fighter in [fighter_a, fighter_b]:
		if not fighter.is_on_floor():
			failures.append("%s n'est pas au sol" % fighter.name)
		if not fighter.global_position.is_finite():
			failures.append("%s a une position invalide" % fighter.name)
		if fighter.controller == null:
			failures.append("%s n'a pas de contrôleur" % fighter.name)
	var distance := absf(fighter_a.global_position.x - fighter_b.global_position.x)
	if distance >= _start_distance - 0.1:
		failures.append("l'IA ne s'est pas rapprochée (distance %.2f m)" % distance)
	if not hud.is_bound():
		failures.append("l'interface n'est pas reliée aux combattants")
	if failures.is_empty():
		print("SMOKE TEST OK: %d frames, distance %.2f m -> %.2f m" % [_frames, _start_distance, distance])
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("SMOKE TEST ÉCHEC: ", failure)
		get_tree().quit(1)
