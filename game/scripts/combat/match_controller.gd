extends Node3D
## Orchestration d'un combat : relie combattants, contrôleurs, caméra, interface et dégâts,
## maintient l'espacement des corps, gère le chronomètre, la victoire et la revanche.
## Lancé avec l'argument utilisateur --smoke-test, il vérifie le socle puis quitte
## avec un code de sortie (utilisé par la CI : voir .github/workflows/android-build.yml).

## Distance minimale entre les centres des deux combattants (rayon des capsules × 2).
const MIN_SEPARATION := 0.7
## Limite de déplacement : murs à ±8,5 m, moins le rayon d'un combattant.
const ARENA_HALF_WIDTH := 8.15

@export var round_seconds: int = 99
@export var smoke_test_frames: int = 120

var match_over: bool = false
var winner: Fighter = null

## Touches détectées pendant la frame, résolues ensemble après le passage des deux
## combattants : deux coups simultanés s'échangent (et peuvent finir en double K.O.),
## quel que soit l'ordre de traitement des nœuds.
var _pending_hits: Array[Dictionary] = []
var _time_left: float = 0.0
var _smoke_test: bool = false
var _frames: int = 0
var _start_distance: float = 0.0

@onready var fighter_a: Fighter = $Fighters/FighterA
@onready var fighter_b: Fighter = $Fighters/FighterB
@onready var camera: FightCamera = $FightCamera
@onready var hud: Hud = $Interface/HUD
@onready var result_overlay: ResultOverlay = $Interface/ResultOverlay


func _ready() -> void:
	# Après les combattants : l'espacement corrige leurs positions une fois qu'ils ont bougé.
	process_physics_priority = 10
	fighter_a.opponent = fighter_b
	fighter_b.opponent = fighter_a
	fighter_a.controller = $Controllers/Player
	fighter_b.controller = $Controllers/AI
	camera.set_targets(fighter_a, fighter_b)
	hud.bind(fighter_a, fighter_b)
	for fighter: Fighter in [fighter_a, fighter_b]:
		fighter.hitbox.hit_detected.connect(_on_hit_detected.bind(fighter))
	result_overlay.restart_requested.connect(restart_match)
	_start_round()
	_start_distance = absf(fighter_a.global_position.x - fighter_b.global_position.x)
	_smoke_test = OS.get_cmdline_user_args().has("--smoke-test")
	if _smoke_test:
		print("SMOKE TEST: démarrage")


func restart_match() -> void:
	_start_round()


func _start_round() -> void:
	match_over = false
	winner = null
	_pending_hits.clear()
	for child in $Fighters.get_children():
		if child is ImpactFx:
			child.queue_free()
	_time_left = float(round_seconds)
	hud.set_time(round_seconds)
	result_overlay.hide_result()
	for fighter: Fighter in [fighter_a, fighter_b]:
		fighter.reset_for_round()
		if fighter.controller != null:
			# Efface notamment les appuis faits pendant l'écran de victoire.
			fighter.controller.reset()
	camera.set_targets(fighter_a, fighter_b)


func _physics_process(delta: float) -> void:
	_resolve_pending_hits()
	_enforce_spacing()
	if not match_over:
		_check_knockouts()
	if not match_over:
		_time_left = maxf(0.0, _time_left - delta)
		hud.set_time(int(ceil(_time_left)))
		if _time_left <= 0.0:
			_finish_by_time()
	if _smoke_test:
		_frames += 1
		if _frames == smoke_test_frames:
			_finish_smoke_test()


## Les corps ne se traversent pas : avancer contre l'adversaire le pousse (à moitié de la
## vitesse), et personne ne sort de l'arène.
func _enforce_spacing() -> void:
	var a := fighter_a.global_position
	var b := fighter_b.global_position
	var dx := b.x - a.x
	if absf(dx) < MIN_SEPARATION:
		var dir := signf(dx) if dx != 0.0 else fighter_a.facing
		var overlap := MIN_SEPARATION - absf(dx)
		a.x -= dir * overlap * 0.5
		b.x += dir * overlap * 0.5
	a.x = clampf(a.x, -ARENA_HALF_WIDTH, ARENA_HALF_WIDTH)
	b.x = clampf(b.x, -ARENA_HALF_WIDTH, ARENA_HALF_WIDTH)
	if absf(b.x - a.x) < MIN_SEPARATION - 0.001:
		# Un des deux est contre un mur : l'autre est repoussé de l'autre côté.
		if absf(a.x) >= ARENA_HALF_WIDTH - 0.001:
			b.x = a.x + signf(-a.x) * MIN_SEPARATION
		else:
			a.x = b.x + signf(-b.x) * MIN_SEPARATION
	fighter_a.global_position = a
	fighter_b.global_position = b


func _on_hit_detected(hurtbox: Hurtbox, attack: AttackData, attack_id: int, attacker: Fighter) -> void:
	if match_over:
		return
	_pending_hits.append({"attacker": attacker, "hurtbox": hurtbox, "attack": attack, "attack_id": attack_id})


func _resolve_pending_hits() -> void:
	if _pending_hits.is_empty():
		return
	var hits := _pending_hits.duplicate()
	_pending_hits.clear()
	for hit in hits:
		var hurtbox: Hurtbox = hit["hurtbox"]
		DamageService.resolve_hit(hit["attacker"], hurtbox.owner_fighter, hurtbox, hit["attack"], hit["attack_id"])


## Évalué une fois par frame, après tous les coups : un double K.O. donne une égalité.
func _check_knockouts() -> void:
	var a_out := fighter_a.state == Fighter.State.KO
	var b_out := fighter_b.state == Fighter.State.KO
	if a_out and b_out:
		_finish(null, "Double K.O. : égalité")
	elif b_out:
		_finish(fighter_a, "%s l'emporte par K.O." % fighter_a.display_name)
	elif a_out:
		_finish(fighter_b, "%s l'emporte par K.O." % fighter_b.display_name)


func _finish_by_time() -> void:
	if fighter_a.health > fighter_b.health:
		_finish(fighter_a, "Temps écoulé : %s l'emporte" % fighter_a.display_name)
	elif fighter_b.health > fighter_a.health:
		_finish(fighter_b, "Temps écoulé : %s l'emporte" % fighter_b.display_name)
	else:
		_finish(null, "Temps écoulé : égalité")


func _finish(new_winner: Fighter, text: String) -> void:
	match_over = true
	winner = new_winner
	for fighter: Fighter in [fighter_a, fighter_b]:
		fighter.input_enabled = false
	result_overlay.show_result(text)


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
