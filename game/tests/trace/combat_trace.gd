extends Node
## Trace de combat de référence (V0.6-A, étape 0).
##
## Rejoue des combats entièrement déterministes et écrit, pour chaque frame de logique, l'état
## complet des deux combattants (état, frame d'état, position et vitesse en X, Y, Z, vie,
## orientation) et du combat (fin, vainqueur, chronomètre). La CI lance le même fichier sur le code
## actuel et sur une copie en lecture seule de version/v0.5.0 : les deux traces doivent être
## identiques au caractère près. Tant que l'option « Profondeur » est désactivée, le combat doit
## rester exactement celui de V0.5.0.
##
## N'utilise que ce qui existe déjà dans V0.5.0 (scènes, contrôleur scripté, IA, réglage du
## visuel) ; l'option Profondeur n'est forcée à « désactivée » que si elle existe.
## Exclu de l'APK (dossier tests/). Lancement :
##   godot --headless --path game --fixed-fps 60 res://tests/trace/combat_trace.tscn -- --out=FICHIER

const MAIN_SCENE := "res://scenes/main/main.tscn"
const GAME_SCENE := "res://scenes/main/game.tscn"
const SCRIPTED := "res://tests/scripted_controller.gd"
const AI := "res://scripts/ai/ai_controller.gd"
const SILHOUETTE := "res://assets/visual/generation_silhouette_v05.tres"
const VISUAL_SETTINGS := "res://scripts/visual/visual_settings.gd"

var _out := "user://trace-combat.txt"
var _lines := PackedStringArray()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	load(VISUAL_SETTINGS).clear()  # réglages par défaut (pantins, Profondeur désactivée)
	await _scenario_game_entry()
	await _scenario_scripted()
	await _scenario_ai(null, "ia-capsules")
	await _scenario_ai(load(SILHOUETTE), "ia-pantins")
	load(VISUAL_SETTINGS).clear()
	var file := FileAccess.open(_out, FileAccess.WRITE)
	if file == null:
		printerr("TRACE ÉCHEC : impossible d'écrire ", _out)
		get_tree().quit(1)
		return
	var text := "\n".join(_lines) + "\n"
	file.store_string(text)
	file.close()
	print("TRACE OK %d lignes, sha256 %s" % [_lines.size(), text.sha256_text()])
	get_tree().quit(0)


func _frame() -> void:
	await get_tree().physics_frame


func _record(tag: String, frame: int, m: Node) -> void:
	var line := "%s %d" % [tag, frame]
	for f in [m.fighter_a, m.fighter_b]:
		line += " | %d %d %.6f %.6f %.6f %.6f %.6f %.6f %.4f %.1f %.6f" % [f.state, f.get_state_frame(),
			f.global_position.x, f.global_position.y, f.global_position.z,
			f.velocity.x, f.velocity.y, f.velocity.z, f.health, f.facing, f.rotation.y]
	var winner: String = "-" if m.winner == null else m.winner.name
	line += " | %s %s %.4f" % [m.match_over, winner, float(m.get("_time_left"))]
	_lines.append(line)


func _force_depth_off(m: Node) -> void:
	if "depth_enabled" in m:
		m.depth_enabled = false


func _controller(m: Node, script_path: String, fighter: Node, seed_value: int = -1) -> Node:
	var c = load(script_path).new()
	if seed_value >= 0:
		c.rng_seed = seed_value
	m.add_child(c)
	if seed_value >= 0:
		c.reset()
	fighter.controller = c
	return c


func _place(fighter: Node, x: float) -> void:
	fighter.global_position = Vector3(x, 0.0, 0.0)
	fighter.velocity = Vector3.ZERO


## Le vrai point d'entrée du jeu, réglages par défaut ; Tandé piloté par une IA de démonstration.
func _scenario_game_entry() -> void:
	var game = load(GAME_SCENE).instantiate()
	add_child(game)
	await _frame()
	var m: Node = game.match_scene
	if "depth_enabled" in m and m.depth_enabled:
		printerr("TRACE ÉCHEC : l'option Profondeur est active au démarrage du jeu")
		get_tree().quit(1)
		return
	_controller(m, AI, m.fighter_a, 11)
	for frame in 3600:
		await _frame()
		_record("jeu", frame, m)
	game.queue_free()
	await _frame()
	await _frame()


## Séquence scriptée : marche jusqu'au mur, poussée, coups légers et lourds, garde, parade,
## esquive, échange simultané, K.O., puis revanche.
func _scenario_scripted() -> void:
	var m = load(MAIN_SCENE).instantiate()
	_force_depth_off(m)
	add_child(m)
	await _frame()
	var a = m.fighter_a
	var b = m.fighter_b
	var ca = _controller(m, SCRIPTED, a)
	var cb = _controller(m, SCRIPTED, b)
	_place(a, -0.5)
	_place(b, 0.5)
	for frame in 1500:
		match frame:
			5: ca.press_light()
			60: cb.press_heavy()
			62: ca.block = true
			140: ca.block = false
			150: cb.press_light()
			151: ca.block = true
			190: ca.block = false
			200: ca.press_dodge()
			205: cb.press_light()
			260: ca.move_axis = 1.0
			290: ca.move_axis = 0.0
			300: ca.press_heavy()
			301: cb.press_heavy()
			380: ca.move_axis = -1.0
			700: ca.move_axis = 0.0
			705: cb.move_axis = -1.0
			900: cb.move_axis = 0.0
			910:
				b.health = 6.0
				ca.press_light()
			1100: m.restart_match()
			1110: cb.move_axis = -1.0
			1150: cb.move_axis = 0.0
			1160: cb.press_light()
			1230: ca.press_dodge()
			1300: cb.move_axis = 1.0
			1400: cb.move_axis = 0.0
		await _frame()
		_record("script", frame, m)
	m.queue_free()
	await _frame()
	await _frame()


## IA contre IA sur la scène de combat, avec la génération visuelle donnée (sans effet sur le combat).
func _scenario_ai(generation, tag: String) -> void:
	var m = load(MAIN_SCENE).instantiate()
	if generation != null:
		generation.apply_to(m)
	_force_depth_off(m)
	add_child(m)
	await _frame()
	_controller(m, AI, m.fighter_a, 3)
	for frame in 2400:
		await _frame()
		_record(tag, frame, m)
	m.queue_free()
	await _frame()
	await _frame()
