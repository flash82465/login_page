extends Node
## Tests de gameplay du prototype (mission 003), exécutés en CI sans affichage :
##   godot --headless --path game --fixed-fps 60 res://tests/test_runner.tscn
## Chaque test crée une scène de combat neuve et la fait avancer frame par frame.
## Sortie : une ligne « TEST OK » ou « TEST ÉCHEC » par test, puis « TESTS OK n/n » et code 0,
## ou « TESTS ÉCHEC » et code 1.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const ScriptedController := preload("res://tests/scripted_controller.gd")
const LIGHT_DAMAGE := 7.5
const HEAVY_DAMAGE := 17.5

var _name: String = ""
var _ok: bool = true
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var size := get_viewport().get_visible_rect().size
	print("TEST INFO viewport %s, fenêtre %s" % [size, DisplayServer.window_get_size()])
	await _test_touch_hold_moves_and_position_persists()
	await _test_touch_tap_triggers_attack()
	await _test_free_movement_within_arena()
	await _test_bodies_push_and_never_overlap()
	await _test_camera_does_not_drag_player_back()
	await _test_light_attack_hits_once_and_reacts()
	await _test_heavy_attack_stronger()
	await _test_missed_attack_does_nothing()
	await _test_block_reduces_damage()
	await _test_parry_negates_and_staggers()
	await _test_dodge_evades_attack()
	await _test_ko_victory_and_restart()
	await _test_time_out_victory()
	await _test_ai_approaches_and_attacks()
	# Mission 004 — stabilisation
	await _test_simultaneous_hits_trade()
	await _test_double_ko_is_a_draw()
	await _test_ai_side_ko_names_ai_winner()
	await _test_restart_by_touch_any_finger_without_phantom_attack()
	await _test_parry_mashing_does_not_rearm()
	await _test_multitouch_move_attack_and_guard()
	await _test_slide_between_arrows_switches_direction()
	await _test_ai_balance()
	# Mission 005 — générations visuelles
	await _test_capsule_visual_identical_to_v041()
	var total := _passed + _failed
	if _failed == 0:
		print("TESTS OK %d/%d" % [_passed, total])
		get_tree().quit(0)
	else:
		printerr("TESTS ÉCHEC %d/%d en échec" % [_failed, total])
		get_tree().quit(1)


# --- Outils ------------------------------------------------------------------------------

func _begin(test_name: String) -> void:
	_name = test_name
	_ok = true


func _end() -> void:
	if _ok:
		_passed += 1
		print("TEST OK     ", _name)
	else:
		_failed += 1
		printerr("TEST ÉCHEC  ", _name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_ok = false
		printerr("    ✗ ", message)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _new_match(scripted_a: bool, scripted_b: bool):
	var m = MAIN_SCENE.instantiate()
	add_child(m)
	await _frames(1)
	if scripted_a:
		var ca := ScriptedController.new()
		m.add_child(ca)
		m.fighter_a.controller = ca
	if scripted_b:
		var cb := ScriptedController.new()
		m.add_child(cb)
		m.fighter_b.controller = cb
	return m


## Contrôleur de test d'un combattant (accès dynamique à ses commandes).
func _ctrl(fighter: Fighter):
	return fighter.controller


func _close(m: Node3D) -> void:
	m.queue_free()
	await _frames(2)


func _place(fighter: Fighter, x: float) -> void:
	fighter.global_position = Vector3(x, 0.0, 0.0)
	fighter.velocity = Vector3.ZERO


func _button_center(button: TouchScreenButton) -> Vector2:
	var local := button.texture_normal.get_size() * 0.5
	return button.get_viewport().get_final_transform() * (button.get_global_transform_with_canvas() * local)


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)


func _control_center(control: Control) -> Vector2:
	return control.get_viewport().get_final_transform() * control.get_global_rect().get_center()


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	Input.parse_input_event(event)


func _tap(index: int, position: Vector2) -> void:
	_touch(index, position, true)
	await _frames(2)
	_touch(index, position, false)
	await _frames(2)


func _states_during(fighter: Fighter, frames: int) -> Array:
	var seen: Array = []
	for i in frames:
		await get_tree().physics_frame
		if not seen.has(fighter.state):
			seen.append(fighter.state)
	return seen


# --- Déplacement -------------------------------------------------------------------------

func _test_touch_hold_moves_and_position_persists() -> void:
	_begin("Tactile : doigt maintenu = déplacement continu ; relâché = le combattant reste où il est")
	var m = await _new_match(false, true)
	var a: Fighter = m.fighter_a
	var button: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveLeft")
	var start := a.global_position.x
	_touch(0, _button_center(button), true)
	await _frames(10)
	_check(button.is_pressed(), "le bouton gauche n'est pas enfoncé par le toucher simulé")
	var mid := a.global_position.x
	await _frames(35)
	var held := a.global_position.x
	_check(mid < start - 0.05, "aucun déplacement après 10 frames (%.2f → %.2f)" % [start, mid])
	_check(held < mid - 0.5, "le déplacement ne continue pas tant que le doigt est posé (%.2f → %.2f)" % [mid, held])
	_touch(0, _button_center(button), false)
	await _frames(60)
	var after := a.global_position.x
	_check(not Input.is_action_pressed(&"move_left"), "l'action reste enfoncée après le relâchement")
	_check(after <= held + 0.01, "le combattant est revenu en arrière (%.2f → %.2f)" % [held, after])
	_check(after < start - 1.0, "la position finale n'est pas conservée (%.2f)" % after)
	await _close(m)
	_end()


func _test_touch_tap_triggers_attack() -> void:
	_begin("Tactile : un appui bref sur attaque légère déclenche une attaque")
	var m = await _new_match(false, true)
	var a: Fighter = m.fighter_a
	var button: TouchScreenButton = m.get_node("Interface/TouchControls/RightPad/LightAttack")
	_touch(1, _button_center(button), true)
	await _frames(2)
	_touch(1, _button_center(button), false)
	await _frames(2)
	_check(a.current_attack_id == 1, "aucune attaque déclenchée (id %d)" % a.current_attack_id)
	await _close(m)
	_end()


func _test_free_movement_within_arena() -> void:
	_begin("Déplacement libre dans les deux sens, arrêté aux limites de l'arène")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	_place(m.fighter_b, 6.0)
	_ctrl(a).move_axis = -1.0
	await _frames(400)
	_check(a.global_position.x >= -8.16 and a.global_position.x <= -8.0, "limite gauche non respectée (x = %.2f)" % a.global_position.x)
	_ctrl(a).move_axis = 1.0
	await _frames(120)
	_check(a.global_position.x > -4.0, "le retour vers la droite ne fonctionne pas (x = %.2f)" % a.global_position.x)
	_ctrl(a).move_axis = 0.0
	var stopped := a.global_position.x
	await _frames(60)
	_check(absf(a.global_position.x - stopped) < 0.3, "le combattant ne s'arrête pas (%.2f → %.2f)" % [stopped, a.global_position.x])
	await _close(m)
	_end()


func _test_bodies_push_and_never_overlap() -> void:
	_begin("Les corps ne se traversent pas : avancer pousse l'adversaire")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.5)
	_place(b, 0.5)
	_ctrl(a).move_axis = 1.0
	var min_distance := 99.0
	for i in 90:
		await _frames(1)
		min_distance = minf(min_distance, absf(b.global_position.x - a.global_position.x))
	_check(min_distance >= 0.69, "chevauchement des corps (distance min %.2f m)" % min_distance)
	_check(b.global_position.x > 1.0, "l'adversaire n'a pas été poussé (x = %.2f)" % b.global_position.x)
	await _close(m)
	_end()


func _test_camera_does_not_drag_player_back() -> void:
	_begin("Caméra : après un pas puis l'arrêt, le combattant ne glisse pas à l'écran")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var camera: Camera3D = m.camera
	_ctrl(a).move_axis = 1.0
	await _frames(20)
	_ctrl(a).move_axis = 0.0
	await _frames(15)
	var screen_stop := camera.unproject_position(a.global_position + Vector3(0, 0.9, 0)).x
	await _frames(90)
	var screen_later := camera.unproject_position(a.global_position + Vector3(0, 0.9, 0)).x
	_check(absf(screen_later - screen_stop) < 25.0, "le combattant glisse de %.0f px à l'écran après l'arrêt" % (screen_later - screen_stop))
	await _close(m)
	_end()


# --- Attaques et réactions ----------------------------------------------------------------

func _test_light_attack_hits_once_and_reacts() -> void:
	_begin("Attaque légère : touche une seule fois, réaction, recul et effet d'impact")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	await _frames(1)
	_ctrl(a).press_light()
	var states := []
	var fx_seen := false
	for i in 30:
		await _frames(1)
		if not states.has(b.state):
			states.append(b.state)
		fx_seen = fx_seen or get_tree().get_nodes_in_group(&"impact_fx").size() > 0
	_check(is_equal_approx(b.health, b.max_health - LIGHT_DAMAGE), "vie attendue %.1f, obtenue %.1f" % [b.max_health - LIGHT_DAMAGE, b.health])
	_check(states.has(Fighter.State.HITSTUN), "aucune réaction (états vus : %s)" % [states])
	_check(b.global_position.x > 0.6, "aucun recul (x = %.2f)" % b.global_position.x)
	_check(fx_seen, "aucun effet visuel d'impact")
	await _frames(30)
	_check(get_tree().get_nodes_in_group(&"impact_fx").size() == 0, "l'effet d'impact ne disparaît pas")
	_check(b.state == Fighter.State.IDLE, "l'adversaire ne récupère pas après l'étourdissement")
	await _close(m)
	_end()


func _test_heavy_attack_stronger() -> void:
	_begin("Attaque lourde : plus de dégâts et plus de recul que la légère")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	await _frames(1)
	_ctrl(a).press_heavy()
	await _frames(50)
	_check(is_equal_approx(b.health, b.max_health - HEAVY_DAMAGE), "vie attendue %.1f, obtenue %.1f" % [b.max_health - HEAVY_DAMAGE, b.health])
	_check(b.global_position.x > 1.0, "recul de l'attaque lourde trop faible (x = %.2f)" % b.global_position.x)
	await _close(m)
	_end()


func _test_missed_attack_does_nothing() -> void:
	_begin("Attaque hors de portée : aucun dégât")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -1.5)
	_place(b, 1.5)
	await _frames(1)
	_ctrl(a).press_heavy()
	await _frames(50)
	_check(a.current_attack_id == 1, "l'attaque n'a pas été lancée")
	_check(b.health == b.max_health, "dégâts à distance (vie %.1f)" % b.health)
	await _close(m)
	_end()


# --- Défense -----------------------------------------------------------------------------

func _test_block_reduces_damage() -> void:
	_begin("Garde (bouclier maintenu) : dégâts réduits à 20 %, étourdissement de garde")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	_ctrl(b).block = true
	await _frames(20)
	_ctrl(a).press_light()
	var states: Array = await _states_during(b, 30)
	_check(is_equal_approx(b.health, b.max_health - LIGHT_DAMAGE * 0.2), "vie attendue %.1f, obtenue %.1f" % [b.max_health - LIGHT_DAMAGE * 0.2, b.health])
	_check(states.has(Fighter.State.BLOCKSTUN), "pas d'étourdissement de garde (états : %s)" % [states])
	await _close(m)
	_end()


func _test_parry_negates_and_staggers() -> void:
	_begin("Parade (garde levée juste avant l'impact) : aucun dégât, l'attaquant est déséquilibré")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	await _frames(1)
	_ctrl(a).press_light()
	_ctrl(b).block = true
	var states: Array = await _states_during(a, 30)
	_check(b.health == b.max_health, "la parade n'a pas annulé les dégâts (vie %.1f)" % b.health)
	_check(states.has(Fighter.State.HITSTUN), "l'attaquant n'est pas déséquilibré (états : %s)" % [states])
	await _close(m)
	_end()


func _test_dodge_evades_attack() -> void:
	_begin("Esquive (double flèche) : un pas de côté invulnérable évite le coup")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	await _frames(1)
	_ctrl(a).press_heavy()
	await _frames(8)
	var before_x := b.global_position.x
	_ctrl(b).press_dodge()
	var states: Array = await _states_during(b, 40)
	_check(states.has(Fighter.State.DODGE), "l'esquive ne s'est pas déclenchée (états : %s)" % [states])
	_check(b.health == b.max_health, "l'esquive n'a pas évité le coup (vie %.1f)" % b.health)
	_check(b.global_position.x > before_x + 0.5, "aucun déplacement d'esquive (%.2f → %.2f)" % [before_x, b.global_position.x])
	await _close(m)
	_end()


# --- Fin de combat -----------------------------------------------------------------------

func _test_ko_victory_and_restart() -> void:
	_begin("K.O. : vainqueur affiché, puis « Rejouer » relance un combat neuf")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	b.health = 5.0
	await _frames(1)
	_ctrl(a).press_light()
	await _frames(30)
	var overlay: ResultOverlay = m.result_overlay
	_check(b.state == Fighter.State.KO, "l'adversaire n'est pas K.O. (état %s)" % b.state)
	_check(m.match_over, "le combat n'est pas terminé")
	_check(m.winner == a, "mauvais vainqueur")
	_check(overlay.visible, "l'écran de victoire n'est pas affiché")
	_check(overlay.result_text().contains(a.display_name), "le nom du vainqueur n'est pas affiché (« %s »)" % overlay.result_text())
	_ctrl(a).press_light()
	await _frames(30)
	_check(a.current_attack_id == 1, "le combattant agit encore après la fin du combat")
	overlay.restart_button().pressed.emit()
	await _frames(2)
	_check(not overlay.visible, "l'écran de victoire reste affiché après « Rejouer »")
	_check(not m.match_over, "le combat ne redémarre pas")
	_check(a.health == a.max_health and b.health == b.max_health, "les vies ne sont pas remises à neuf")
	_check(b.state == Fighter.State.IDLE, "l'adversaire est toujours K.O.")
	_check(is_equal_approx(a.global_position.x, -1.5) and is_equal_approx(b.global_position.x, 1.5), "positions de départ non restaurées")
	_ctrl(a).press_light()
	await _frames(3)
	_check(a.current_attack_id == 2, "le joueur ne peut plus agir après « Rejouer »")
	await _close(m)
	_end()


func _test_time_out_victory() -> void:
	_begin("Fin du temps : le combattant le plus en vie l'emporte")
	var m = await _new_match(true, true)
	m.fighter_b.health = 60.0
	m._time_left = 0.05
	await _frames(5)
	_check(m.match_over, "le combat ne se termine pas à la fin du temps")
	_check(m.winner == m.fighter_a, "mauvais vainqueur au temps")
	_check(m.result_overlay.result_text().contains(m.fighter_a.display_name), "vainqueur non affiché")
	await _close(m)
	_end()


# --- IA ----------------------------------------------------------------------------------

func _test_ai_approaches_and_attacks() -> void:
	_begin("IA : Mabé s'approche, attaque et touche Tandé ; elle n'est pas immobile")
	var m = await _new_match(true, false)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	var idle_frames := 0
	var idle_run := 0
	var longest_idle := 0
	var moved := 0.0
	var last_x := b.global_position.x
	for i in 600:
		await _frames(1)
		if b.state == Fighter.State.IDLE:
			idle_frames += 1
			idle_run += 1
			longest_idle = maxi(longest_idle, idle_run)
		else:
			idle_run = 0
		moved += absf(b.global_position.x - last_x)
		last_x = b.global_position.x
	_check(b.current_attack_id >= 3, "l'IA attaque trop peu (%d attaques en 10 s)" % b.current_attack_id)
	_check(a.health < a.max_health, "l'IA n'a jamais touché Tandé")
	_check(moved > 1.0, "l'IA ne se déplace pas (%.2f m parcourus)" % moved)
	_check(longest_idle < 120, "l'IA reste immobile %d frames d'affilée (plus de 2 s)" % longest_idle)
	print("    IA : %d attaques, Tandé à %.1f PV, %.1f m parcourus, %d frames immobile (au plus %d d'affilée)" % [b.current_attack_id, a.health, moved, idle_frames, longest_idle])
	await _close(m)
	_end()


# --- Mission 004 : cohérence de fin de combat ----------------------------------------------

func _test_simultaneous_hits_trade() -> void:
	_begin("Coups simultanés : les deux combattants sont touchés (aucun avantage lié à l'ordre)")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	await _frames(1)
	_ctrl(a).press_light()
	_ctrl(b).press_light()
	await _frames(30)
	_check(is_equal_approx(a.health, a.max_health - LIGHT_DAMAGE), "Tandé n'a pas été touché (vie %.1f)" % a.health)
	_check(is_equal_approx(b.health, b.max_health - LIGHT_DAMAGE), "Mabé n'a pas été touchée (vie %.1f)" % b.health)
	await _close(m)
	_end()


func _test_double_ko_is_a_draw() -> void:
	_begin("Double K.O. simultané : égalité, aucun vainqueur")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	a.health = 5.0
	b.health = 5.0
	await _frames(1)
	_ctrl(a).press_light()
	_ctrl(b).press_light()
	await _frames(30)
	_check(a.state == Fighter.State.KO and b.state == Fighter.State.KO, "les deux ne sont pas K.O. (états %s / %s)" % [a.state, b.state])
	_check(m.match_over and m.winner == null, "un vainqueur a été désigné pour un double K.O.")
	_check(m.result_overlay.result_text().contains("égalité"), "égalité non affichée (« %s »)" % m.result_overlay.result_text())
	await _close(m)
	_end()


func _test_ai_side_ko_names_ai_winner() -> void:
	_begin("K.O. infligé par Mabé : Mabé est désignée vainqueur")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	a.health = 5.0
	await _frames(1)
	_ctrl(b).press_light()
	await _frames(30)
	_check(m.winner == b, "mauvais vainqueur")
	_check(m.result_overlay.result_text().contains(b.display_name), "nom de Mabé absent (« %s »)" % m.result_overlay.result_text())
	await _close(m)
	_end()


func _test_restart_by_touch_any_finger_without_phantom_attack() -> void:
	_begin("« Rejouer » au doigt (1er ou 2e doigt), deux revanches de suite, sans attaque fantôme")
	var m = await _new_match(false, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	var overlay: ResultOverlay = m.result_overlay
	var light: TouchScreenButton = m.get_node("Interface/TouchControls/RightPad/LightAttack")
	var left: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveLeft")
	var restarts := [0]
	overlay.restart_requested.connect(func() -> void: restarts[0] += 1)
	# Manche 1 : K.O. au doigt, tap pendant l'écran de victoire, doigt posé sur une flèche,
	# puis « Rejouer » avec un deuxième doigt.
	_place(a, -0.45)
	_place(b, 0.45)
	b.health = 5.0
	await _tap(1, _button_center(light))
	await _frames(30)
	_check(overlay.visible, "écran de victoire absent après le K.O.")
	await _tap(1, _button_center(light))
	_touch(0, _button_center(left), true)
	await _frames(5)
	await _tap(1, _control_center(overlay.restart_button()))
	_check(restarts[0] == 1, "« Rejouer » (2e doigt) : %d revanche(s) demandée(s) au lieu de 1" % restarts[0])
	_check(not m.match_over and not overlay.visible, "le combat n'a pas redémarré")
	var attacks_before := a.current_attack_id
	var x_before := a.global_position.x
	await _frames(15)
	_check(a.current_attack_id == attacks_before, "attaque fantôme après la revanche (tap fait pendant l'écran de victoire)")
	_check(a.global_position.x < x_before - 0.2, "le doigt resté sur la flèche ne déplace pas le combattant après la revanche")
	_touch(0, _button_center(left), false)
	await _frames(5)
	# Manche 2 : nouveau K.O., « Rejouer » avec le premier doigt (clic émulé par Android).
	_place(a, -0.45)
	_place(b, 0.45)
	b.health = 5.0
	await _frames(2)
	await _tap(1, _button_center(light))
	await _frames(30)
	_check(overlay.visible, "écran de victoire absent au 2e K.O.")
	await _tap(0, _control_center(overlay.restart_button()))
	_check(restarts[0] == 2, "« Rejouer » (1er doigt) : %d revanche(s) au total au lieu de 2" % restarts[0])
	_check(not m.match_over and b.health == b.max_health and b.state == Fighter.State.IDLE, "la 2e revanche ne remet pas le combat à neuf")
	await _close(m)
	_end()


# --- Mission 004 : parade et commandes tactiles -------------------------------------------

func _test_parry_mashing_does_not_rearm() -> void:
	_begin("Parade : marteler le bouclier ne rouvre pas la fenêtre (simple garde)")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -0.45)
	_place(b, 0.45)
	await _frames(1)
	_ctrl(a).press_heavy()
	_ctrl(b).block = true
	await _frames(3)
	_ctrl(b).block = false
	await _frames(6)
	_ctrl(b).block = true
	var states: Array = await _states_during(a, 40)
	_check(is_equal_approx(b.health, b.max_health - HEAVY_DAMAGE * 0.2), "attendu une garde simple (vie %.1f), obtenu %.1f" % [b.max_health - HEAVY_DAMAGE * 0.2, b.health])
	_check(not states.has(Fighter.State.HITSTUN), "l'attaquant a été déséquilibré : la parade s'est rouverte")
	await _close(m)
	_end()


func _test_multitouch_move_attack_and_guard() -> void:
	_begin("Multitouch : flèche maintenue + attaque d'un autre doigt, puis + bouclier maintenu")
	var m = await _new_match(false, true)
	var a: Fighter = m.fighter_a
	var left: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveLeft")
	var light: TouchScreenButton = m.get_node("Interface/TouchControls/RightPad/LightAttack")
	var block: TouchScreenButton = m.get_node("Interface/TouchControls/RightPad/Block")
	_touch(0, _button_center(left), true)
	await _frames(10)
	await _tap(1, _button_center(light))
	_check(a.current_attack_id == 1, "l'attaque d'un 2e doigt n'est pas prise en compte pendant le déplacement")
	_check(Input.is_action_pressed(&"move_left"), "la flèche a été relâchée par le 2e doigt")
	await _frames(30)
	var x1 := a.global_position.x
	await _frames(10)
	_check(a.global_position.x < x1 - 0.2, "le déplacement ne reprend pas après l'attaque")
	_touch(2, _button_center(block), true)
	await _frames(10)
	_check(a.state == Fighter.State.BLOCK, "le bouclier maintenu par un autre doigt ne met pas en garde (état %s)" % a.state)
	var x2 := a.global_position.x
	await _frames(20)
	_check(absf(a.global_position.x - x2) < 0.2, "le combattant avance en garde")
	_touch(2, _button_center(block), false)
	await _frames(15)
	_check(a.state == Fighter.State.WALK, "le déplacement ne reprend pas après la garde (état %s)" % a.state)
	_touch(0, _button_center(left), false)
	await _frames(5)
	_check(not Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"block"), "des actions restent enfoncées après relâchement")
	await _close(m)
	_end()


func _test_slide_between_arrows_switches_direction() -> void:
	_begin("Glisser le doigt d'une flèche à l'autre change de direction sans relever le doigt")
	var m = await _new_match(false, true)
	var a: Fighter = m.fighter_a
	var left: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveLeft")
	var right: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveRight")
	var from := _button_center(left)
	var to := _button_center(right)
	_touch(0, from, true)
	await _frames(20)
	_drag(0, from, to)
	await _frames(3)
	_check(not Input.is_action_pressed(&"move_left") and Input.is_action_pressed(&"move_right"), "la flèche n'a pas changé en glissant")
	var x := a.global_position.x
	await _frames(35)
	_check(a.global_position.x > x + 0.2, "le combattant ne repart pas vers la droite")
	_touch(0, to, false)
	await _frames(3)
	_check(not Input.is_action_pressed(&"move_right"), "la flèche droite reste enfoncée")
	await _close(m)
	_end()


# --- Mission 004 : équilibrage de l'IA ----------------------------------------------------

func _simulate_round(seed_value: int, mode: String) -> Dictionary:
	var m = await _new_match(true, false)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	var ai: AIController = b.controller
	ai.rng_seed = seed_value
	ai.reset()
	var ctrl = _ctrl(a)
	var frames := 0
	var limit: int = m.round_seconds * 60 + 30
	while not m.match_over and frames < limit:
		if mode == "spam":
			var dx := b.global_position.x - a.global_position.x
			ctrl.move_axis = signf(dx) if absf(dx) > 0.9 else 0.0
			if absf(dx) <= 1.0 and (a.state == Fighter.State.IDLE or a.state == Fighter.State.WALK):
				ctrl.press_light()
		await _frames(1)
		frames += 1
	var winner := "égalité"
	if m.winner == a:
		winner = "Tandé"
	elif m.winner == b:
		winner = "Mabé"
	var result := {
		"winner": winner, "seconds": frames / 60.0, "ko": a.state == Fighter.State.KO or b.state == Fighter.State.KO,
		"tande": a.health, "mabe": b.health, "ai_attacks": b.current_attack_id, "player_attacks": a.current_attack_id,
	}
	await _close(m)
	return result


func _test_ai_balance() -> void:
	_begin("Équilibrage IA (mesure) : un joueur passif tient au moins 12 s ; contre un joueur qui martèle, les deux combattants sont touchés")
	var seeds := [20261119, 7, 99]
	for seed_value in seeds:
		var r: Dictionary = await _simulate_round(seed_value, "idle")
		print("    BALANCE joueur passif   graine %8d : %s gagne en %5.1f s, Tandé %5.1f PV, Mabé %5.1f PV, %2d attaques IA" % [seed_value, r["winner"], r["seconds"], r["tande"], r["mabe"], r["ai_attacks"]])
		_check(r["winner"] == "Mabé" and r["ko"], "contre un joueur passif, l'IA doit gagner par K.O. (graine %d)" % seed_value)
		_check(r["seconds"] >= 12.0 and r["seconds"] <= 60.0, "K.O. d'un joueur passif en %.1f s, hors de la plage 12–60 s (graine %d)" % [r["seconds"], seed_value])
	for seed_value in seeds:
		var r: Dictionary = await _simulate_round(seed_value, "spam")
		print("    BALANCE joueur marteleur graine %8d : %s gagne en %5.1f s, Tandé %5.1f PV, Mabé %5.1f PV, %2d attaques IA, %3d attaques joueur" % [seed_value, r["winner"], r["seconds"], r["tande"], r["mabe"], r["ai_attacks"], r["player_attacks"]])
		_check(r["tande"] < 100.0, "le marteleur gagne sans être touché (graine %d) : l'IA ne se défend pas" % seed_value)
		_check(r["mabe"] < 100.0, "l'IA gagne sans être touchée par le marteleur (graine %d)" % seed_value)
	_end()


# --- Mission 005 : générations visuelles ---------------------------------------------------

const CAPSULE_VISUAL_SCENE := preload("res://scenes/fighters/visuals/capsule_v04.tscn")


func _test_capsule_visual_identical_to_v041() -> void:
	_begin("Visuel capsule (ancienne génération) : structure et poses identiques à V0.4.1, génération sélectionnable")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	for f: Fighter in [a, b]:
		var v: Node3D = f.get_node("Visual")
		_check(v is CapsuleVisual, "%s : le visuel par défaut n'est pas la génération capsule" % f.display_name)
		_check(_same_v3((v.get_node("Body") as Node3D).position, Vector3(0, 0.9, 0))
			and _same_v3((v.get_node("FacingMarker") as Node3D).position, Vector3(0.32, 1.6, 0))
			and _same_v3((v.get_node("ArmPivot") as Node3D).position, Vector3(0, 1.3, 0.22))
			and _same_v3((v.get_node("ArmPivot/Arm") as Node3D).position, Vector3(0.25, 0, 0))
			and _same_v3((v.get_node("Shield") as Node3D).position, Vector3(0.48, 1.2, 0)),
			"%s : position des pièces différente de V0.4.1" % f.display_name)
		var body := (v.get_node("Body") as MeshInstance3D).mesh as CapsuleMesh
		_check(body != null and is_equal_approx(body.radius, 0.35) and is_equal_approx(body.height, 1.8), "%s : corps différent de V0.4.1" % f.display_name)
		_check(_same_v3(((v.get_node("ArmPivot/Arm") as MeshInstance3D).mesh as BoxMesh).size, Vector3(0.5, 0.13, 0.13)), "%s : bras différent de V0.4.1" % f.display_name)
		_check(_same_v3(((v.get_node("Shield") as MeshInstance3D).mesh as BoxMesh).size, Vector3(0.06, 0.75, 0.55)), "%s : bouclier différent de V0.4.1" % f.display_name)
		_check(_capsule_color(f).is_equal_approx(f.body_color), "%s : couleur du corps différente" % f.display_name)

	# Séquence couvrant tous les états ; chaque frame, la pose est comparée à la formule de V0.4.1.
	var ca = _ctrl(a)
	var cb = _ctrl(b)
	var red := Color(1.0, 0.3, 0.25)
	var parry_color := Color(1.0, 1.0, 0.85)
	var compared := 0
	var mismatches := 0
	var red_frames_b := 0
	var parry_frames_b := 0
	var states_seen := {}
	for frame in 420:
		match frame:
			0, 60, 170, 210, 270, 330:
				_place(a, -0.45)
				_place(b, 0.45)
			10:
				ca.press_light()  # A touche B : coup reçu, éclair rouge
			62:
				ca.block = true  # A garde depuis longtemps...
			100:
				cb.press_heavy()  # ... B frappe lourd : coup bloqué
			160:
				ca.block = false
			175:
				ca.press_dodge()  # esquive
			215:
				cb.press_light()  # B attaque...
			217:
				ca.block = true  # ... A lève la garde juste avant l'impact : parade, B déséquilibré
			260:
				ca.block = false
			275:
				ca.move_axis = -1.0  # marche
			290:
				ca.move_axis = 0.0
			332:
				b.health = 1.0
			333:
				ca.press_light()  # K.O.
		await _frames(1)
		for f: Fighter in [a, b]:
			states_seen[f.state] = true
			# Hors arrêt sur image et hors frame où le système de dégâts vient de changer l'état
			# (le visuel n'est alors pas encore mis à jour, dans V0.4.1 comme maintenant).
			if f.get_state_frame() >= 1 and int(f.get("_freeze_frames")) == 0:
				compared += 1
				if not _capsule_pose_matches_v041(f):
					mismatches += 1
		var color_b := _capsule_color(b)
		if frame < 60 and color_b.is_equal_approx(red):
			red_frames_b += 1
		if frame >= 210 and frame < 270 and color_b.is_equal_approx(parry_color):
			parry_frames_b += 1
	_check(mismatches == 0, "%d poses sur %d diffèrent de la formule de V0.4.1" % [mismatches, compared])
	_check(compared >= 600, "trop peu de frames comparées (%d)" % compared)
	for s in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.ATTACK, Fighter.State.BLOCK, Fighter.State.DODGE,
			Fighter.State.HITSTUN, Fighter.State.BLOCKSTUN, Fighter.State.KO]:
		_check(states_seen.has(s), "état %s non couvert par la séquence" % Fighter.State.keys()[s])
	_check(red_frames_b == 6, "éclair rouge du coup reçu : %d frames au lieu de 6" % red_frames_b)
	_check(parry_frames_b == 6, "éclair du déséquilibre après parade : %d frames au lieu de 6" % parry_frames_b)
	print("    VISUEL capsule : %d poses comparées à V0.4.1, %d différences ; éclairs %d et %d frames" % [compared, mismatches, red_frames_b, parry_frames_b])
	await _close(m)

	# La génération visuelle se choisit par la propriété visual_scene du combattant.
	var m2 = MAIN_SCENE.instantiate()
	(m2.get_node("Fighters/FighterA") as Fighter).visual_scene = CAPSULE_VISUAL_SCENE
	add_child(m2)
	await _frames(2)
	var fa: Fighter = m2.fighter_a
	var visuals := fa.get_children().filter(func(c: Node) -> bool: return c.name == "Visual")
	_check(visuals.size() == 1 and visuals[0] is CapsuleVisual, "visual_scene ne remplace pas proprement le visuel")
	await _close(m2)
	_end()


## Pose de la génération capsule selon la formule de Fighter._update_visuals() de V0.4.1,
## recopiée telle quelle comme référence.
func _capsule_pose_matches_v041(f: Fighter) -> bool:
	var state_frame := f.get_state_frame()
	var arm_x := 0.0
	var arm_scale := 1.0
	var lean := 0.0
	if f.state == Fighter.State.ATTACK and f.current_attack != null:
		var attack := f.current_attack
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
	elif f.state == Fighter.State.HITSTUN:
		lean = 0.25
	elif f.state == Fighter.State.KO:
		lean = 1.35
	var scale_y := 0.85 if f.is_invulnerable() and f.state == Fighter.State.DODGE else 1.0
	var v: Node3D = f.get_node("Visual")
	var pivot: Node3D = v.get_node("ArmPivot")
	return is_equal_approx(pivot.position.x, arm_x) \
		and pivot.scale.is_equal_approx(Vector3(arm_scale, arm_scale, arm_scale)) \
		and is_equal_approx(v.rotation.z, lean) \
		and is_equal_approx(v.scale.y, scale_y) \
		and (v.get_node("Shield") as Node3D).visible == f.is_blocking()


func _capsule_color(f: Fighter) -> Color:
	var mesh := f.get_node("Visual/Body") as MeshInstance3D
	return (mesh.material_override as StandardMaterial3D).albedo_color


func _same_v3(u: Vector3, w: Vector3) -> bool:
	return u.is_equal_approx(w)
