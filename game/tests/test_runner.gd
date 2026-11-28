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
## Génération visuelle appliquée par _new_match : aucune (capsules, passe par défaut) ou les pantins
## animés (passe lancée avec « -- --generation=silhouette », mission 006).
var _generation = null
var _ok: bool = true
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--generation=silhouette"):
		_generation = load("res://assets/visual/generation_silhouette_v05.tres")
		print("TEST INFO passe « pantins animés » : tous les scénarios de jeu sont rejoués avec la génération silhouette")
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
	if _generation == null:  # test propre aux capsules
		await _test_capsule_visual_identical_to_v041()
	await _test_silhouette_proportions_and_zones()
	await _test_silhouette_mirror()
	await _test_combat_identical_across_generations()
	# Mission 005, étape 3 — animations des silhouettes
	await _test_silhouette_strikes_in_hitbox()
	await _test_silhouette_animation_fluid_and_deterministic()
	await _test_silhouette_walk_feet_planted()
	# Mission 006 — intégration jouable
	await _test_game_starts_with_pantins_and_toggles()
	# Mission 006 / V0.6-A, étape 0 — option « Profondeur » (désactivée par défaut, sans effet)
	await _test_depth_setting_defaults_and_invalid_values()
	await _test_depth_setting_saved_alongside_visual()
	await _test_depth_toggle_switches_and_restarts()
	await _test_depth_option_has_no_effect_at_step_0()
	await _test_place_xz_tool_and_v05_depth_lock()
	# Correctif de l'essai Android de l'étape 0 (bouton Profondeur au doigt)
	await _test_depth_toggle_single_finger_tap()
	await _test_depth_toggle_ignores_double_tap()
	# Mission 009 / V0.6-A, étape 1 — déplacement en profondeur (axe Z) et espacement XZ
	await _test_depth_move_negative_z()
	await _test_depth_move_positive_z()
	await _test_depth_combined_xz_movement()
	await _test_depth_max_speed_and_inertia()
	await _test_depth_arena_limits()
	await _test_depth_locked_when_disabled()
	await _test_depth_spacing_disabled_vs_enabled()
	await _test_depth_diagonal_normalization()
	# Mission 010 / V0.6-A — contrôles tactiles de déplacement en profondeur (axe Z)
	await _test_touch_depth_up_down_hold_release_and_limits()
	await _test_touch_depth_diagonal_and_normalization()
	await _test_touch_depth_multitouch_combat()
	await _test_touch_depth_disabled_hides_and_preserves_layout()
	await _test_touch_depth_toggle_integration()
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
	if _generation != null:
		_generation.apply_to(m)
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


# --- Mission 005, étape 2 : génération silhouette (environnement de revue) ----------------

const SILHOUETTE_GENERATION := preload("res://assets/visual/generation_silhouette_v05.tres")


func _new_match_with(generation):
	var m = MAIN_SCENE.instantiate()
	if generation != null:
		generation.apply_to(m)
	add_child(m)
	await _frames(1)
	var ca := ScriptedController.new()
	m.add_child(ca)
	m.fighter_a.controller = ca
	var cb := ScriptedController.new()
	m.add_child(cb)
	m.fighter_b.controller = cb
	return m


func _test_silhouette_proportions_and_zones() -> void:
	_begin("Silhouettes : tête à 8 cm au plus de sa zone, pieds au sol, torse dans sa zone ; silhouettes distinctes d'au moins 15 %")
	var m = await _new_match_with(SILHOUETTE_GENERATION)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -1.0)
	_place(b, 1.0)
	var ratios := {}
	for pose: StringName in [&"attente", &"garde"]:
		_ctrl(a).block = pose == &"garde"
		_ctrl(b).block = pose == &"garde"
		await _frames(6)
		for f: Fighter in [a, b]:
			var v := f.get_node("Visual") as SilhouetteVisual
			_check(v != null, "%s : la génération silhouette n'est pas appliquée" % f.display_name)
			if v == null:
				continue
			_check(v.current_pose() == pose, "%s : pose %s au lieu de %s" % [f.display_name, v.current_pose(), pose])
			var head := v.joint_global(&"head")
			var zone := (f.get_node("Hurtboxes/Head/CollisionShape3D") as Node3D).global_position
			var offset := Vector2(head.x - zone.x, head.y - zone.y).length()
			_check(offset <= 0.08, "%s (%s) : tête à %.1f cm du centre de sa zone" % [f.display_name, pose, offset * 100.0])
			var feet := v.lowest_point_global()
			_check(feet >= -0.01 and feet <= 0.02, "%s (%s) : pieds à %.1f cm du sol" % [f.display_name, pose, feet * 100.0])
			var torso := f.get_node("Hurtboxes/Torso/CollisionShape3D") as CollisionShape3D
			var half := (torso.shape as BoxShape3D).size * 0.5
			for joint: StringName in [&"waist", &"chest"]:
				var p := v.joint_global(joint) - torso.global_position
				_check(absf(p.x) <= half.x and absf(p.y) <= half.y, "%s (%s) : %s hors de la zone du torse" % [f.display_name, pose, joint])
			var ratio := v.extent_ratio()
			ratios["%s/%s" % [f.display_name, pose]] = ratio
			print("    SILHOUETTE %s, %s : tête à %.1f cm de sa zone, pieds à %+.1f cm, largeur/hauteur %.3f" % [f.display_name, pose, offset * 100.0, feet * 100.0, ratio])
		if ratios.has("%s/%s" % [a.display_name, pose]) and ratios.has("%s/%s" % [b.display_name, pose]):
			var diff: float = float(ratios["%s/%s" % [b.display_name, pose]]) / float(ratios["%s/%s" % [a.display_name, pose]]) - 1.0
			_check(diff >= 0.15, "silhouettes trop proches (%s) : écart %.0f %%" % [pose, diff * 100.0])
			print("    SILHOUETTE écart Mabé / Tandé (%s) : %.0f %%" % [pose, diff * 100.0])
	await _close(m)
	_end()


func _test_silhouette_mirror() -> void:
	_begin("Silhouettes : miroir 2D, le bras avant reste devant et le poing avant vers l'adversaire, dans les deux orientations")
	var m = await _new_match_with(SILHOUETTE_GENERATION)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	for side: float in [1.0, -1.0]:
		_place(a, -1.0 * side)
		_place(b, 1.0 * side)
		await _frames(6)
		for f: Fighter in [a, b]:
			var v := f.get_node("Visual") as SilhouetteVisual
			if v == null:
				_check(false, "%s : la génération silhouette n'est pas appliquée" % f.display_name)
				continue
			var chest := v.joint_global(&"chest")
			var near := v.joint_global(&"wrist_n")
			var far := v.joint_global(&"wrist_f")
			var looking := "à droite" if f.facing > 0.0 else "à gauche"
			_check(near.z > chest.z and far.z < chest.z, "%s regardant %s : bras avant et bras arrière inversés" % [f.display_name, looking])
			_check((near.x - f.global_position.x) * f.facing > 0.0, "%s regardant %s : poing avant du mauvais côté" % [f.display_name, looking])
	await _close(m)
	_end()


func _test_combat_identical_across_generations() -> void:
	_begin("Combat identique quelle que soit la génération visuelle (capsule ou silhouette) : positions, états et vie, frame par frame")
	var with_capsule: PackedStringArray = await _record_fight(null)
	var with_silhouette: PackedStringArray = await _record_fight(SILHOUETTE_GENERATION)
	var first := -1
	for i in mini(with_capsule.size(), with_silhouette.size()):
		if with_capsule[i] != with_silhouette[i]:
			first = i
			break
	_check(with_capsule.size() == with_silhouette.size() and first == -1,
		"première différence à la frame %d : « %s » / « %s »" % [first, with_capsule[maxi(first, 0)], with_silhouette[maxi(first, 0)]])
	print("    GÉNÉRATIONS : %d frames comparées, %s" % [with_capsule.size(), "identiques" if first == -1 else "différentes"])
	_end()


func _record_fight(generation) -> PackedStringArray:
	var m = await _new_match_with(generation)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	var ca = _ctrl(a)
	var cb = _ctrl(b)
	var trace := PackedStringArray()
	_place(a, -1.2)
	_place(b, 1.2)
	for frame in 480:
		match frame:
			5:
				ca.move_axis = 1.0
			30:
				ca.move_axis = 0.0
			40:
				ca.press_light()
			90:
				cb.move_axis = -1.0
			110:
				cb.move_axis = 0.0
			115:
				cb.press_heavy()
			118:
				ca.block = true
			200:
				ca.block = false
			210:
				ca.press_dodge()
			250:
				cb.press_light()
			300:
				ca.move_axis = 1.0
			330:
				ca.move_axis = 0.0
			335:
				ca.press_heavy()
			400:
				cb.block = true
			405:
				ca.press_light()
			440:
				cb.block = false
		await _frames(1)
		trace.append("%d %d %d %.5f %.5f %.3f %.3f %d %d" % [frame, a.state, b.state, a.global_position.x, b.global_position.x,
			a.health, b.health, a.get_state_frame(), b.get_state_frame()])
	await _close(m)
	return trace


# --- Mission 005, étape 3 : animations des silhouettes -------------------------------------

func _inside_hitbox(f: Fighter, p: Vector3) -> bool:
	var shape := f.hitbox.get_node("CollisionShape3D") as CollisionShape3D
	var half := (shape.shape as BoxShape3D).size * 0.5
	var d := p - shape.global_position
	return absf(d.x) <= half.x and absf(d.y) <= half.y and absf(d.z) <= half.z


func _test_silhouette_strikes_in_hitbox() -> void:
	_begin("Animations : le poing qui frappe est dans la zone de frappe à chaque image active et le coup part à la première (Tandé, Mabé, légère, lourde, deux orientations)")
	for side: float in [1.0, -1.0]:
		var m = await _new_match_with(SILHOUETTE_GENERATION)
		var a: Fighter = m.fighter_a
		var b: Fighter = m.fighter_b
		_place(a, -1.2 * side)
		_place(b, 1.2 * side)
		await _frames(8)
		for f: Fighter in [a, b]:
			var v := f.get_node("Visual") as SilhouetteVisual
			for heavy: bool in [false, true]:
				var attack: AttackData = f.heavy_attack if heavy else f.light_attack
				var wrist: StringName = &"wrist_f" if heavy else &"wrist_n"
				if heavy:
					_ctrl(f).press_heavy()
				else:
					_ctrl(f).press_light()
				var active := 0
				var inside := 0
				var before := -INF
				var contact := -INF
				for i in 90:
					await _frames(1)
					if i > 2 and f.state != Fighter.State.ATTACK:
						break
					var fist := v.joint_global(wrist)
					var reach := (fist.x - f.global_position.x) * f.facing
					if f.get_state_frame() == attack.startup_frames:
						before = reach
					if f.hitbox.is_active():
						active += 1
						if f.get_state_frame() == attack.startup_frames + 1:
							contact = reach
						if _inside_hitbox(f, fist):
							inside += 1
				var label := "%s, %s, regard %s" % [f.display_name, "lourde" if heavy else "légère", "à droite" if f.facing > 0.0 else "à gauche"]
				_check(active == attack.active_frames, "%s : %d images actives au lieu de %d" % [label, active, attack.active_frames])
				_check(inside == active, "%s : poing hors de la zone de frappe sur %d image(s) active(s)" % [label, active - inside])
				_check(contact > before + 0.01, "%s : l'allonge maximale n'est pas atteinte à la première image active (%.2f m puis %.2f m)" % [label, before, contact])
				if side > 0.0:
					print("    COUP %s : %d/%d images actives avec le poing dans la zone ; allonge %.2f m à la fin de la préparation, %.2f m à l'impact" % [label, inside, active, before, contact])
				await _frames(12)
		await _close(m)
	_end()


func _test_silhouette_animation_fluid_and_deterministic() -> void:
	_begin("Animations : déterministes (deux combats identiques donnent les mêmes poses) et fluides (aucun saut de plus de 25 cm ni de 40° d'une image à l'autre)")
	var first: Dictionary = await _animation_trace()
	var second: Dictionary = await _animation_trace()
	_check(first["trace"] == second["trace"], "les poses diffèrent entre deux combats identiques")
	_check(float(first["step"]) <= 0.25, "saut d'articulation de %.1f cm en une image (%s)" % [float(first["step"]) * 100.0, first["step_at"]])
	_check(float(first["turn"]) <= deg_to_rad(40.0), "rotation d'os de %.0f° en une image (%s)" % [rad_to_deg(float(first["turn"])), first["turn_at"]])
	var seen: Dictionary = first["seen"]
	var first_trace: PackedStringArray = first["trace"]
	for anim: StringName in [&"locomotion", &"garde", &"coup_bloque", &"legere", &"lourde", &"recul", &"esquive", &"ko"]:
		_check(seen.has(anim), "animation %s jamais jouée par la séquence" % anim)
	print("    ANIMATIONS : %d poses comparées entre deux combats, identiques : %s ; plus grand déplacement d'articulation en une image %.1f cm (%s) ; plus grande rotation %.0f° (%s)" % [
		first_trace.size(), "oui" if first["trace"] == second["trace"] else "non",
		float(first["step"]) * 100.0, first["step_at"], rad_to_deg(float(first["turn"])), first["turn_at"]])
	_end()


func _animation_trace() -> Dictionary:
	var m = await _new_match_with(SILHOUETTE_GENERATION)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	var ca = _ctrl(a)
	var cb = _ctrl(b)
	var trace := PackedStringArray()
	var seen := {}
	var last := {}
	var step := 0.0
	var turn := 0.0
	var step_at := ""
	var turn_at := ""
	_place(a, -1.2)
	_place(b, 1.2)
	for frame in 560:
		match frame:
			0:
				ca.move_axis = 1.0  # marche avant
			25:
				ca.move_axis = -1.0  # marche arrière
			45:
				ca.move_axis = 0.0
			70, 130, 230, 270, 330, 400:
				_place(a, -0.45)
				_place(b, 0.45)
			75:
				ca.press_light()  # coup reçu par Mabé
			132:
				ca.block = true  # garde...
			160:
				cb.press_heavy()  # ... coup bloqué
			220:
				ca.block = false
			235:
				ca.press_dodge()  # esquive
			275:
				cb.press_light()
			277:
				ca.block = true  # parade : Mabé déséquilibré
			320:
				ca.block = false
			335:
				cb.press_heavy()  # coup lourd reçu par Tandé
			402:
				b.health = 1.0
			404:
				ca.press_heavy()  # K.O.
		await _frames(1)
		for f: Fighter in [a, b]:
			var v := f.get_node("Visual") as SilhouetteVisual
			seen[v.current_animation()] = true
			var joints := PackedVector2Array()
			var row := PackedStringArray()
			for joint in SilhouetteVisual.JOINTS:
				var p := v.joint_local(joint)
				joints.append(p)
				row.append("%.5f,%.5f" % [p.x, p.y])
			var angles := v.bone_angles()
			trace.append("%d %s %s" % [frame, f.name, " ".join(row)])
			if last.has(f.name):
				var prev: Dictionary = last[f.name]
				var prev_joints: PackedVector2Array = prev["joints"]
				var prev_angles: PackedFloat64Array = prev["angles"]
				for i in joints.size():
					var d := joints[i].distance_to(prev_joints[i])
					if d > step:
						step = d
						step_at = "%s, %s, %s, image %d" % [f.display_name, v.current_animation(), SilhouetteVisual.JOINTS[i], frame]
				for i in angles.size():
					var t := absf(wrapf(angles[i] - prev_angles[i], -PI, PI))
					if t > turn:
						turn = t
						turn_at = "%s, %s, os %d, image %d" % [f.display_name, v.current_animation(), i, frame]
			last[f.name] = {"joints": joints, "angles": angles}
	await _close(m)
	return {"trace": trace, "seen": seen, "step": step, "turn": turn, "step_at": step_at, "turn_at": turn_at}


func _test_silhouette_walk_feet_planted() -> void:
	_begin("Marche avant et arrière : un pied en appui ne glisse pas de plus de 2 cm (Tandé et Mabé)")
	var m = await _new_match_with(SILHOUETTE_GENERATION)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_place(a, -3.0)
	_place(b, 3.0)
	await _frames(4)
	var worst := 0.0
	var stances := 0
	for f: Fighter in [a, b]:
		var v := f.get_node("Visual") as SilhouetteVisual
		var c = _ctrl(f)
		for direction: float in [1.0, -1.0]:
			c.move_axis = direction * f.facing
			var tracks := {&"n": PackedFloat64Array(), &"f": PackedFloat64Array()}
			for i in 45:
				await _frames(1)
				for side: StringName in [&"n", &"f"]:
					var x := v.joint_global(&"ankle_n" if side == &"n" else &"ankle_f").x
					var track: PackedFloat64Array = tracks[side]
					if v.foot_planted(side):
						track.append(x)
					else:
						if track.size() >= 3:
							var lo := INF
							var hi := -INF
							for value in track:
								lo = minf(lo, value)
								hi = maxf(hi, value)
							worst = maxf(worst, hi - lo)
							stances += 1
						track = PackedFloat64Array()
					tracks[side] = track
			c.move_axis = 0.0
			await _frames(20)
	_check(stances >= 8, "trop peu d'appuis observés (%d)" % stances)
	_check(worst <= 0.02, "un pied en appui glisse de %.1f cm" % (worst * 100.0))
	print("    MARCHE : %d appuis observés, glissement maximal d'un pied posé %.2f cm" % [stances, worst * 100.0])
	await _close(m)
	_end()


# --- Mission 006 : intégration jouable ----------------------------------------------------

const GAME_SCENE := preload("res://scenes/main/game.tscn")


func _test_game_starts_with_pantins_and_toggles() -> void:
	_begin("Jeu : démarre en pantins animés ; le bouton Visuel (2e doigt pendant qu'une flèche est tenue) passe aux capsules, le choix est conservé, puis retour aux pantins")
	VisualSettings.clear()
	var game = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(3)
	var m = game.match_scene
	_check(m.fighter_a.get_node("Visual") is SilhouetteVisual and m.fighter_b.get_node("Visual") is SilhouetteVisual, "le jeu ne démarre pas en pantins animés")
	var toggle := m.get_node_or_null("Interface/VisualToggle") as VisualToggle
	_check(toggle != null, "bouton Visuel absent")
	if toggle != null:
		var arrow: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveRight")
		var arrow_position := _button_center(arrow)  # le bouton disparaît avec l'ancien combat
		_touch(0, arrow_position, true)
		await _frames(2)
		var center := _control_center(toggle.button())
		_touch(1, center, true)
		await _frames(1)
		_touch(1, center, false)
		await _frames(3)
		_touch(0, arrow_position, false)
		await _frames(10)
	m = game.match_scene
	_check(absf(m.fighter_a.velocity.x) < 0.05 and m.fighter_a.state == Fighter.State.IDLE, "après le changement de visuel, un déplacement reste bloqué")
	_check(m.fighter_a.get_node("Visual") is CapsuleVisual and m.fighter_b.get_node("Visual") is CapsuleVisual, "le bouton Visuel ne passe pas aux capsules")
	_check(VisualSettings.load_choice() == &"capsules", "choix des capsules non enregistré")
	_check(m.fighter_a.health == m.fighter_a.max_health and not m.match_over, "le changement de visuel ne relance pas un combat neuf")
	game.queue_free()
	await _frames(2)
	var again = GAME_SCENE.instantiate()
	add_child(again)
	await _frames(3)
	m = again.match_scene
	_check(m.fighter_a.get_node("Visual") is CapsuleVisual, "le choix des capsules n'est pas conservé au relancement")
	(m.get_node("Interface/VisualToggle") as VisualToggle).button().pressed.emit()
	await _frames(3)
	m = again.match_scene
	_check(m.fighter_a.get_node("Visual") is SilhouetteVisual, "retour aux pantins impossible")
	_check(VisualSettings.load_choice() == &"pantins", "retour aux pantins non enregistré")
	again.queue_free()
	VisualSettings.clear()
	await _frames(2)
	_end()


# --- Mission 006 / V0.6-A, étape 0 : option « Profondeur » ----------------------------------
# L'option est désactivée par défaut et, à cette étape, aucun code de combat ne la lit : ces tests
# vérifient le réglage, son bouton et l'outil de placement en X et Z, sans rien changer au combat.

const AI_SCRIPT := preload("res://scripts/ai/ai_controller.gd")


## Place un combattant en X et en profondeur (Z), à l'arrêt (outil des tests de la V0.6).
func _place_xz(fighter: Fighter, x: float, z: float) -> void:
	fighter.global_position = Vector3(x, 0.0, z)
	fighter.velocity = Vector3.ZERO


func _write_config(text: String) -> void:
	var file := FileAccess.open(DepthSettings.CONFIG_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_depth_setting_defaults_and_invalid_values() -> void:
	_begin("Profondeur : désactivée sans fichier, sans valeur, avec une valeur invalide ou un fichier illisible ; jamais activée au démarrage")
	VisualSettings.clear()
	_check(not DepthSettings.load_enabled(), "sans fichier de réglages, l'option n'est pas désactivée")
	VisualSettings.save_choice(&"capsules")
	_check(not DepthSettings.load_enabled(), "fichier sans valeur Profondeur : l'option n'est pas désactivée")
	for raw in ["\"true\"", "1", "\"oui\"", "[true]", "null"]:
		_write_config("[combat]\nprofondeur=%s\n" % raw)
		_check(not DepthSettings.load_enabled(), "valeur invalide %s : l'option n'est pas désactivée" % raw)
	print("    (l'erreur « ConfigFile parse error » qui suit est attendue : fichier volontairement illisible)")
	_write_config("ceci n'est pas un fichier de réglages [[[ = =\n")
	_check(not DepthSettings.load_enabled(), "fichier illisible : l'option n'est pas désactivée")
	# Démarrage du vrai jeu sans réglage : option désactivée dans le point d'entrée et dans le combat.
	VisualSettings.clear()
	var game = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(3)
	_check(not game.depth_enabled and not game.match_scene.depth_enabled, "l'option est active au démarrage du jeu")
	var toggle := game.match_scene.get_node_or_null("Interface/DepthToggle") as DepthToggle
	_check(toggle != null and not toggle.enabled and toggle.button().text == DepthToggle.LABELS[false], "le bouton n'indique pas « Profondeur : NON » au démarrage")
	_check(not FileAccess.file_exists(DepthSettings.CONFIG_PATH), "le démarrage écrit un réglage sans action du joueur")
	game.queue_free()
	await _frames(2)
	_end()


func _test_depth_setting_saved_alongside_visual() -> void:
	_begin("Profondeur : le choix est enregistré et relu ; il coexiste avec le choix du visuel sans l'écraser, et inversement")
	VisualSettings.clear()
	DepthSettings.save_enabled(true)
	_check(DepthSettings.load_enabled(), "activation non relue")
	_check(VisualSettings.load_choice() == &"pantins", "enregistrer la profondeur modifie le visuel")
	VisualSettings.save_choice(&"capsules")
	_check(DepthSettings.load_enabled(), "enregistrer le visuel efface la profondeur")
	_check(VisualSettings.load_choice() == &"capsules", "choix du visuel non relu")
	DepthSettings.save_enabled(false)
	_check(not DepthSettings.load_enabled(), "désactivation non relue")
	_check(VisualSettings.load_choice() == &"capsules", "désactiver la profondeur modifie le visuel")
	DepthSettings.save_enabled(true)
	DepthSettings.clear()
	_check(not DepthSettings.load_enabled(), "après effacement, l'option n'est pas revenue à désactivée")
	_check(VisualSettings.load_choice() == &"capsules", "effacer la profondeur efface aussi le visuel")
	VisualSettings.clear()
	_end()


func _touch_rect(button: TouchScreenButton) -> Rect2:
	return button.get_global_transform() * Rect2(Vector2.ZERO, button.texture_normal.get_size())


func _label_width(text: String) -> float:
	var probe := Button.new()
	probe.add_theme_font_size_override(&"font_size", 20)
	probe.text = text
	var width := probe.get_combined_minimum_size().x
	probe.free()
	return width


func _test_depth_toggle_switches_and_restarts() -> void:
	_begin("Profondeur : bouton sous « Visuel », sans chevauchement ; un 2e doigt (flèche tenue) l'active, combat neuf, choix conservé au relancement, indépendant du visuel")
	VisualSettings.clear()
	var game = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(3)
	var m = game.match_scene
	var depth := m.get_node_or_null("Interface/DepthToggle") as DepthToggle
	var visual := m.get_node_or_null("Interface/VisualToggle") as VisualToggle
	_check(depth != null and visual != null, "bouton Profondeur ou Visuel absent")
	if depth != null and visual != null:
		# Zones déclarées des boutons (celles du rendu réel ; sans affichage, la police de secours
		# agrandit les boutons, d'où la vérification du rendu réel dans la revue visuelle).
		var d_rect := depth.get_global_rect()
		var v_rect := visual.get_global_rect()
		_check(d_rect.position.y >= v_rect.end.y and absf(d_rect.get_center().x - v_rect.get_center().x) < 1.0,
			"le bouton Profondeur n'est pas centré sous le bouton Visuel")
		_check(not d_rect.intersects(v_rect), "les boutons Visuel et Profondeur se chevauchent")
		_check(d_rect.size == v_rect.size, "les deux boutons n'ont pas la même taille")
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(d_rect), "le bouton Profondeur dépasse de l'écran de référence 1280 × 720")
		_check(not d_rect.intersects((m.get_node("Interface/HUD/TopBar") as Control).get_global_rect()), "le bouton recouvre la barre de vie")
		for path in ["LeftPad/MoveLeft", "LeftPad/MoveRight", "RightPad/Block", "RightPad/LightAttack", "RightPad/HeavyAttack", "RightPad/Dodge"]:
			var b := m.get_node("Interface/TouchControls/" + path) as TouchScreenButton
			_check(not d_rect.intersects(_touch_rect(b)), "le bouton Profondeur recouvre la commande %s" % path)
		# Texte : jamais plus large que le plus long texte du bouton Visuel (qui tient dans le rendu réel).
		var widest := 0.0
		for label in VisualToggle.LABELS.values():
			widest = maxf(widest, _label_width(label))
		for value in [false, true]:
			_check(_label_width(DepthToggle.LABELS[value]) <= widest, "texte plus long que celui du bouton Visuel : « %s »" % DepthToggle.LABELS[value])
		var arrow: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveRight")
		var arrow_position := _button_center(arrow)  # le bouton disparaît avec l'ancien combat
		_touch(0, arrow_position, true)
		await _frames(2)
		var center := _control_center(depth.button())
		_touch(1, center, true)
		await _frames(1)
		_touch(1, center, false)
		await _frames(3)
		_touch(0, arrow_position, false)
		await _frames(10)
	m = game.match_scene
	_check(m.depth_enabled and game.depth_enabled, "le bouton n'active pas l'option")
	_check(DepthSettings.load_enabled(), "activation non enregistrée")
	_check(absf(m.fighter_a.velocity.x) < 0.05 and m.fighter_a.state == Fighter.State.IDLE, "après la bascule, un déplacement reste bloqué")
	_check(m.fighter_a.health == m.fighter_a.max_health and not m.match_over, "la bascule ne relance pas un combat neuf")
	_check(m.fighter_a.get_node("Visual") is SilhouetteVisual and VisualSettings.load_choice() == &"pantins", "la bascule Profondeur change le visuel")
	_check((m.get_node("Interface/DepthToggle") as DepthToggle).button().text == DepthToggle.LABELS[true], "le bouton n'indique pas « Profondeur : OUI (à venir) »")
	game.queue_free()
	await _frames(2)
	var again = GAME_SCENE.instantiate()
	add_child(again)
	await _frames(3)
	m = again.match_scene
	_check(m.depth_enabled, "le choix « activée » n'est pas conservé au relancement")
	(m.get_node("Interface/VisualToggle") as VisualToggle).button().pressed.emit()
	await _frames(3)
	m = again.match_scene
	_check(m.fighter_a.get_node("Visual") is CapsuleVisual and m.depth_enabled, "changer de visuel désactive la profondeur")
	(m.get_node("Interface/DepthToggle") as DepthToggle).button().pressed.emit()
	await _frames(3)
	m = again.match_scene
	_check(not m.depth_enabled and not DepthSettings.load_enabled(), "désactivation impossible ou non enregistrée")
	_check(m.fighter_a.get_node("Visual") is CapsuleVisual, "désactiver la profondeur change le visuel")
	again.queue_free()
	VisualSettings.clear()
	await _frames(2)
	_end()


## Combat enregistré frame par frame (positions et vitesses en X, Y, Z, état, vie, orientation) :
## une séquence scriptée puis un combat IA contre IA, avec l'option Profondeur donnée.
func _record_depth_fight(depth: bool) -> PackedStringArray:
	var trace := PackedStringArray()
	for part in ["script", "ia"]:
		var m = MAIN_SCENE.instantiate()
		if _generation != null:
			_generation.apply_to(m)
		m.depth_enabled = depth
		add_child(m)
		await _frames(1)
		var a: Fighter = m.fighter_a
		var b: Fighter = m.fighter_b
		var ca = null
		var cb = null
		if part == "script":
			ca = ScriptedController.new()
			m.add_child(ca)
			a.controller = ca
			cb = ScriptedController.new()
			m.add_child(cb)
			b.controller = cb
			_place(a, -1.4)
			_place(b, 1.4)
		else:
			var ai = AI_SCRIPT.new()
			ai.rng_seed = 7
			m.add_child(ai)
			ai.reset()
			a.controller = ai
		for frame in 600:
			if part == "script":
				match frame:
					5: ca.move_axis = 1.0
					25: ca.move_axis = 0.0
					30: ca.press_light()
					70: cb.press_heavy()
					72: ca.block = true
					150: ca.block = false
					160: cb.move_axis = -1.0
					200: cb.move_axis = 0.0
					205: ca.press_dodge()
					240: cb.press_light()
					241: ca.press_light()
					300: ca.move_axis = -1.0
					420: ca.move_axis = 1.0
					520: ca.move_axis = 0.0
					530: ca.press_heavy()
			await _frames(1)
			var line := "%s %d" % [part, frame]
			for f: Fighter in [a, b]:
				line += " | %d %d %.6f %.6f %.6f %.6f %.6f %.6f %.4f %.1f %.6f" % [f.state, f.get_state_frame(),
					f.global_position.x, f.global_position.y, f.global_position.z, f.velocity.x, f.velocity.y, f.velocity.z,
					f.health, f.facing, f.rotation.y]
			trace.append(line + " | %s" % m.match_over)
		await _close(m)
	return trace


func _test_depth_option_has_no_effect_at_step_0() -> void:
	_begin("Étape 0 : l'option Profondeur ne change encore rien au combat (séquence scriptée et IA contre IA identiques, frame par frame)")
	var off: PackedStringArray = await _record_depth_fight(false)
	var on: PackedStringArray = await _record_depth_fight(true)
	var first := -1
	for i in mini(off.size(), on.size()):
		if off[i] != on[i]:
			first = i
			break
	_check(off.size() == on.size() and off.size() == 1200 and first == -1,
		"première différence à la ligne %d : « %s » / « %s »" % [first, off[maxi(first, 0)], on[maxi(first, 0)]])
	print("    PROFONDEUR (étape 0) : %d frames comparées, %s" % [off.size(), "identiques" if first == -1 else "différentes"])
	_end()


func _test_place_xz_tool_and_v05_depth_lock() -> void:
	_begin("Outil de placement X/Z : position exacte ; option désactivée, Z est ramené à 0 dès la frame suivante (couloir de V0.5 intact)")
	var m = await _new_match(true, true)
	var a: Fighter = m.fighter_a
	var b: Fighter = m.fighter_b
	_check(not m.depth_enabled, "option active dans une scène de combat neuve")
	_place_xz(a, -1.25, 0.8)
	_place_xz(b, 1.5, -0.6)
	_check(a.global_position.is_equal_approx(Vector3(-1.25, 0.0, 0.8)) and b.global_position.is_equal_approx(Vector3(1.5, 0.0, -0.6)),
		"placement en X et Z inexact")
	_check(a.velocity == Vector3.ZERO and b.velocity == Vector3.ZERO, "le placement ne remet pas la vitesse à zéro")
	await _frames(1)
	_check(a.global_position.z == 0.0 and b.global_position.z == 0.0, "Z n'est pas ramené à 0 (z = %.3f / %.3f)" % [a.global_position.z, b.global_position.z])
	_check(is_equal_approx(a.global_position.x, -1.25) and is_equal_approx(b.global_position.x, 1.5), "X modifié par le retour en Z = 0")
	await _frames(30)
	_check(a.global_position.z == 0.0 and b.global_position.z == 0.0 and a.velocity.z == 0.0, "un combattant quitte Z = 0")
	await _close(m)
	_end()



# --- Tests 36 et 37 : correctif de l'essai Android de l'étape 0 (bouton « Profondeur ») -----

## Toucher d'un seul doigt tel qu'Android le livre (appui, quelques images, relâchement) : c'est
## le cas réel du téléphone, où Godot émule aussi un clic de souris (le test 33 utilisait un 2e
## doigt, sans émulation).
func _finger_tap(position: Vector2, hold_frames: int = 4) -> void:
	_touch(0, position, true)
	await _frames(hold_frames)
	_touch(0, position, false)


func _test_depth_toggle_single_finger_tap() -> void:
	_begin("Profondeur au doigt seul (cas du téléphone) : bascule, nouveau texte immédiat, réglage enregistré et conservé au relancement")
	VisualSettings.clear()
	var game = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(3)
	var before = game.match_scene
	await _finger_tap(_control_center((before.get_node("Interface/DepthToggle") as DepthToggle).button()))
	await _frames(2)
	var m = game.match_scene
	_check(m != before, "le combat n'est pas relancé")
	_check(m.depth_enabled and DepthSettings.load_enabled(), "le toucher n'active pas l'option ou ne l'enregistre pas")
	_check((m.get_node("Interface/DepthToggle") as DepthToggle).button().text == DepthToggle.LABELS[true], "le nouveau texte « Profondeur : OUI (à venir) » n'est pas affiché")
	_check(m.fighter_a.get_node("Visual") is SilhouetteVisual, "le visuel a changé")
	game.queue_free()
	await _frames(2)
	var again = GAME_SCENE.instantiate()
	add_child(again)
	await _frames(3)
	_check(again.match_scene.depth_enabled, "le choix n'est pas conservé après relancement")
	_check((again.match_scene.get_node("Interface/DepthToggle") as DepthToggle).button().text == DepthToggle.LABELS[true], "texte incorrect après relancement")
	again.queue_free()
	VisualSettings.clear()
	await _frames(2)
	_end()


func _test_depth_toggle_ignores_double_tap() -> void:
	_begin("Profondeur : un second toucher juste après la bascule (double toucher, rebond du doigt) ne l'annule pas ; un toucher volontaire ensuite désactive")
	VisualSettings.clear()
	var game = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(3)
	var center := _control_center((game.match_scene.get_node("Interface/DepthToggle") as DepthToggle).button())
	await _finger_tap(center, 3)
	await _frames(10)  # second toucher environ 0,2 s après le relâchement du premier
	await _finger_tap(center, 3)
	await _frames(4)
	var m = game.match_scene
	_check(m.depth_enabled and DepthSettings.load_enabled(), "le second toucher rapproché a annulé la bascule (option revenue à désactivée)")
	_check((m.get_node("Interface/DepthToggle") as DepthToggle).button().text == DepthToggle.LABELS[true], "le texte est revenu à « Profondeur : NON »")
	await _frames(30)  # plus tard, un toucher volontaire
	await _finger_tap(_control_center((game.match_scene.get_node("Interface/DepthToggle") as DepthToggle).button()), 3)
	await _frames(3)
	_check(not game.match_scene.depth_enabled and not DepthSettings.load_enabled(), "un toucher volontaire plus tard ne désactive pas l'option")
	game.queue_free()
	VisualSettings.clear()
	await _frames(2)
	_end()


# --- Tests 38 à 44 : Mission 009 / V0.6-A, étape 1 (déplacement Z et espacement XZ) ----------

func _new_depth_match(depth: bool, scripted_a: bool, scripted_b: bool):
	var m = MAIN_SCENE.instantiate()
	if _generation != null:
		_generation.apply_to(m)
	m.depth_enabled = depth
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


func _has_key_binding(action: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k != null and k.physical_keycode == keycode:
			return true
	return false


func _test_depth_move_negative_z() -> void:
	_begin("Profondeur (-Z) : W/UP mappés sur move_up ; depth_enabled = true déplace le combattant vers le fond (-Z)")
	_check(_has_key_binding(&"move_up", KEY_W) and _has_key_binding(&"move_up", KEY_UP), "W et UP ne sont pas mappés sur move_up")
	var m = await _new_depth_match(true, false, true)
	var a: Fighter = m.fighter_a
	_place_xz(a, -1.5, 0.0)
	_place_xz(m.fighter_b, 1.5, 0.0)
	Input.action_press(&"move_up")
	await _frames(30)
	var z_keyboard := a.global_position.z
	var vz_keyboard := a.velocity.z
	Input.action_release(&"move_up")
	_check(z_keyboard < -0.5, "move_up n'a pas déplacé vers -Z (z = %.3f)" % z_keyboard)
	_check(vz_keyboard < -1.5, "vitesse Z négative insuffisante avec move_up (vz = %.3f)" % vz_keyboard)
	await _close(m)
	_end()


func _test_depth_move_positive_z() -> void:
	_begin("Profondeur (+Z) : S/DOWN mappés sur move_down ; depth_enabled = true déplace le combattant vers la caméra (+Z)")
	_check(_has_key_binding(&"move_down", KEY_S) and _has_key_binding(&"move_down", KEY_DOWN), "S et DOWN ne sont pas mappés sur move_down")
	var m = await _new_depth_match(true, false, true)
	var a: Fighter = m.fighter_a
	_place_xz(a, -1.5, 0.0)
	_place_xz(m.fighter_b, 1.5, 0.0)
	Input.action_press(&"move_down")
	await _frames(30)
	var z_keyboard := a.global_position.z
	var vz_keyboard := a.velocity.z
	Input.action_release(&"move_down")
	_check(z_keyboard > 0.5, "move_down n'a pas déplacé vers +Z (z = %.3f)" % z_keyboard)
	_check(vz_keyboard > 1.5, "vitesse Z positive insuffisante avec move_down (vz = %.3f)" % vz_keyboard)
	await _close(m)
	_end()


func _test_depth_combined_xz_movement() -> void:
	_begin("Profondeur (X + Z) : déplacement combiné sur X et Z simultanément")
	var m = await _new_depth_match(true, true, true)
	var a: Fighter = m.fighter_a
	_place_xz(a, -2.5, 0.0)
	_place_xz(m.fighter_b, 3.0, 0.0)
	var ca = _ctrl(a)
	ca.move_axis = 1.0
	ca.depth_axis = -1.0
	await _frames(30)
	var pos_1 := a.global_position
	_check(pos_1.x > -1.7 and pos_1.z < -0.5, "déplacement (+X, -Z) insuffisant : %s" % pos_1)
	_check(a.state == Fighter.State.WALK, "le combattant n'est pas en état WALK pendant un déplacement X+Z")
	ca.move_axis = -1.0
	ca.depth_axis = 1.0
	await _frames(50)
	var pos_2 := a.global_position
	_check(pos_2.x < pos_1.x - 1.0 and pos_2.z > pos_1.z + 0.9, "inversion (-X, +Z) inopérante : %s -> %s" % [pos_1, pos_2])
	_check(a.velocity.x < -2.0 and a.velocity.z > 1.5, "vitesses inversées X+Z insuffisantes : %s" % a.velocity)
	ca.move_axis = 0.0
	ca.depth_axis = 0.0
	await _close(m)
	_end()


func _test_depth_max_speed_and_inertia() -> void:
	_begin("Profondeur (vitesse max et inertie) : vitesse Z bornée à 2,2 m/s, accélération et freinage progressifs selon la masse")
	var m = await _new_depth_match(true, true, true)
	var a: Fighter = m.fighter_a  # Tandé : 92 kg
	var b: Fighter = m.fighter_b  # Mabé : 110 kg
	_place_xz(a, -2.0, -1.2)
	_place_xz(b, 2.0, -1.2)
	var ca = _ctrl(a)
	var cb = _ctrl(b)
	ca.depth_axis = 1.0
	cb.depth_axis = 1.0
	var max_vz_a := 0.0
	var max_vz_b := 0.0
	var vz_a_f3 := 0.0
	var vz_b_f3 := 0.0
	for frame in 40:
		await _frames(1)
		max_vz_a = maxf(max_vz_a, absf(a.velocity.z))
		max_vz_b = maxf(max_vz_b, absf(b.velocity.z))
		if frame == 2:
			vz_a_f3 = a.velocity.z
			vz_b_f3 = b.velocity.z
	_check(vz_a_f3 > 0.1 and vz_a_f3 < 2.0, "accélération Z non progressive (frame 3 : %.3f)" % vz_a_f3)
	_check(vz_a_f3 > vz_b_f3 + 0.05, "la masse n'influence pas l'accélération Z (Tandé %.3f vs Mabé %.3f)" % [vz_a_f3, vz_b_f3])
	_check(max_vz_a <= 2.2001 and max_vz_b <= 2.2001, "vitesse Z supérieure à 2,2 m/s (Tandé %.4f, Mabé %.4f)" % [max_vz_a, max_vz_b])
	_check(absf(max_vz_a - 2.2) < 0.02 and absf(max_vz_b - 2.2) < 0.02, "vitesse max 2,2 m/s non atteinte (Tandé %.4f, Mabé %.4f)" % [max_vz_a, max_vz_b])
	# Décélération au relâchement : progressive (pas d'arrêt instantané) puis arrêt complet.
	ca.depth_axis = 0.0
	cb.depth_axis = 0.0
	await _frames(2)
	var decel_a := a.velocity.z
	var decel_b := b.velocity.z
	_check(decel_a > 0.2 and decel_a < 2.1, "décélération Z absente ou instantanée (Tandé : %.3f)" % decel_a)
	_check(decel_a < decel_b - 0.05, "la masse n'influence pas la décélération Z (Tandé %.3f vs Mabé %.3f)" % [decel_a, decel_b])
	await _frames(20)
	_check(absf(a.velocity.z) < 0.001 and absf(b.velocity.z) < 0.001, "le combattant ne s'arrête pas en Z après relâchement")
	_check(a.state == Fighter.State.IDLE and b.state == Fighter.State.IDLE, "retour à IDLE non effectué après arrêt Z")
	await _close(m)
	_end()


func _test_depth_arena_limits() -> void:
	_begin("Profondeur (limites ±1,5 m) : bornage strict à Z = -1,5 et Z = +1,5 sans dépassement ni blocage au demi-tour")
	var m = await _new_depth_match(true, true, true)
	var a: Fighter = m.fighter_a
	_place_xz(a, -2.0, 0.0)
	_place_xz(m.fighter_b, 2.0, 0.0)
	var ca = _ctrl(a)
	ca.depth_axis = -1.0
	var min_z := 0.0
	for _i in 90:
		await _frames(1)
		min_z = minf(min_z, a.global_position.z)
	_check(min_z >= -1.5001 and absf(a.global_position.z - (-1.5)) < 0.01, "limite Z = -1,5 non respectée (z = %.4f, min = %.4f)" % [a.global_position.z, min_z])
	_check(absf(a.velocity.z) < 0.001, "vitesse Z non annulée contre la limite -1,5 (vz = %.4f)" % a.velocity.z)
	ca.depth_axis = 1.0
	await _frames(5)
	_check(a.global_position.z > -1.49 and a.velocity.z > 0.0, "demi-tour depuis Z = -1,5 bloqué")
	var max_z := -1.5
	for _i in 120:
		await _frames(1)
		max_z = maxf(max_z, a.global_position.z)
	_check(max_z <= 1.5001 and absf(a.global_position.z - 1.5) < 0.01, "limite Z = +1,5 non respectée (z = %.4f, max = %.4f)" % [a.global_position.z, max_z])
	_check(absf(a.velocity.z) < 0.001, "vitesse Z non annulée contre la limite +1,5 (vz = %.4f)" % a.velocity.z)
	ca.depth_axis = 0.0
	await _close(m)
	_end()


func _test_depth_locked_when_disabled() -> void:
	_begin("Profondeur désactivée : move_up/move_down et depth_axis sont sans effet, Z reste strictement à 0")
	var m = await _new_depth_match(false, true, true)
	var a: Fighter = m.fighter_a
	_place_xz(a, -1.5, 0.0)
	_place_xz(m.fighter_b, 1.5, 0.0)
	var ca = _ctrl(a)
	ca.depth_axis = -1.0
	for _i in 20:
		await _frames(1)
		_check(a.global_position.z == 0.0 and a.velocity.z == 0.0, "Z a bougé malgré depth_enabled = false (scripté -Z)")
	ca.depth_axis = 1.0
	for _i in 20:
		await _frames(1)
		_check(a.global_position.z == 0.0 and a.velocity.z == 0.0, "Z a bougé malgré depth_enabled = false (scripté +Z)")
	await _close(m)
	# Vérification également avec le vrai contrôleur clavier PlayerInputController.
	var m2 = await _new_depth_match(false, false, true)
	var a2: Fighter = m2.fighter_a
	Input.action_press(&"move_up")
	await _frames(20)
	_check(a2.global_position.z == 0.0 and a2.velocity.z == 0.0, "move_up a déplacé Z malgré depth_enabled = false")
	Input.action_release(&"move_up")
	Input.action_press(&"move_down")
	await _frames(20)
	_check(a2.global_position.z == 0.0 and a2.velocity.z == 0.0, "move_down a déplacé Z malgré depth_enabled = false")
	Input.action_release(&"move_down")
	await _close(m2)
	_end()


func _test_depth_spacing_disabled_vs_enabled() -> void:
	_begin("Espacement : 1D historique quand depth_enabled = false ; 2D XZ quand depth_enabled = true (croisement libre si décalé en Z, séparation maintenue sinon)")
	# 1. depth_enabled == false : blocage/poussée historique sur X, Z reste 0.
	var m_off = await _new_depth_match(false, true, true)
	_place_xz(m_off.fighter_a, -0.5, 0.0)
	_place_xz(m_off.fighter_b, 0.5, 0.0)
	_ctrl(m_off.fighter_a).move_axis = 1.0
	await _frames(45)
	_check(m_off.fighter_b.global_position.x - m_off.fighter_a.global_position.x >= 0.69, "espacement X non maintenu quand depth_enabled = false")
	_check(m_off.fighter_b.global_position.x > 0.7, "poussée historique en X absente quand depth_enabled = false")
	_check(m_off.fighter_a.global_position.z == 0.0 and m_off.fighter_b.global_position.z == 0.0, "Z non nul quand depth_enabled = false")
	await _close(m_off)

	# 2. depth_enabled == true : suffisamment décalés en Z, ils se croisent en X sans blocage ni poussée.
	var m_on = await _new_depth_match(true, true, true)
	var a: Fighter = m_on.fighter_a
	var b: Fighter = m_on.fighter_b
	_place_xz(a, -1.0, -1.0)
	_place_xz(b, 0.0, 1.0)
	_ctrl(a).move_axis = 1.0
	await _frames(45)
	_check(a.global_position.x > 0.5, "A n'a pas pu croiser B en X malgré un écart de 2 m en Z (a.x = %.3f)" % a.global_position.x)
	_check(absf(b.global_position.x) < 0.01 and absf(b.global_position.z - 1.0) < 0.01, "B a été poussé artificiellement malgré l'écart en Z (%s)" % b.global_position)
	_ctrl(a).move_axis = 0.0

	# 3. depth_enabled == true : proches dans le plan XZ, la distance 2D reste >= 0,7 m (y compris contre Z = +1,5).
	_place_xz(a, 0.0, 0.6)
	_place_xz(b, 0.0, 1.5)
	_ctrl(a).depth_axis = 1.0
	await _frames(45)
	var dist_xz := Vector2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z).length()
	_check(dist_xz >= 0.69, "chevauchement dans le plan XZ contre la limite Z (dist = %.3f)" % dist_xz)
	_check(absf(a.global_position.z) <= 1.5001 and absf(b.global_position.z) <= 1.5001, "dépassement des limites Z lors de la séparation XZ")
	_check(absf(a.global_position.x) <= 8.1501 and absf(b.global_position.x) <= 8.1501, "dépassement des limites X lors de la séparation XZ")
	_ctrl(a).depth_axis = 0.0
	await _close(m_on)
	_end()


func _test_depth_diagonal_normalization() -> void:
	_begin("Profondeur (normalisation diagonale) : X seul = 3,0 m/s, Z seul = 2,2 m/s, diagonale normalisée (≈ 2,63 m/s ≤ 3,0 m/s), masses respectées, V0.5 intact si désactivée")
	var expected_vx := 3.0 / sqrt(2.0)
	var expected_vz := 2.2 / sqrt(2.0)
	var expected_diag := Vector2(expected_vx, expected_vz).length()

	# 1. X seul conserve 3,0 m/s ; 2. Z seul conserve 2,2 m/s.
	var m = await _new_depth_match(true, true, true)
	var a: Fighter = m.fighter_a  # Tandé : 92 kg
	var b: Fighter = m.fighter_b  # Mabé : 110 kg
	var ca = _ctrl(a)
	var cb = _ctrl(b)
	_place_xz(a, -5.0, -1.2)
	_place_xz(b, 5.0, -1.2)
	ca.move_axis = 1.0
	ca.depth_axis = 0.0
	cb.move_axis = 0.0
	cb.depth_axis = 1.0
	await _frames(35)
	_check(absf(a.velocity.x - 3.0) < 0.02 and a.velocity.z == 0.0, "X seul ne conserve pas 3,0 m/s (%s)" % a.velocity)
	_check(absf(b.velocity.z - 2.2) < 0.02 and b.velocity.x == 0.0, "Z seul ne conserve pas 2,2 m/s (%s)" % b.velocity)

	# 3, 4 et 5. Diagonale normalisée sur Tandé (92 kg) et Mabé (110 kg).
	_place_xz(a, -5.0, -1.3)
	_place_xz(b, 2.0, -1.3)
	ca.move_axis = 1.0
	ca.depth_axis = 1.0
	cb.move_axis = 1.0
	cb.depth_axis = 1.0
	var max_diag_a := 0.0
	var max_diag_b := 0.0
	var speed_a_f3 := 0.0
	var speed_b_f3 := 0.0
	for frame in 35:
		await _frames(1)
		var sa := Vector2(a.velocity.x, a.velocity.z).length()
		var sb := Vector2(b.velocity.x, b.velocity.z).length()
		max_diag_a = maxf(max_diag_a, sa)
		max_diag_b = maxf(max_diag_b, sb)
		if frame == 2:
			speed_a_f3 = sa
			speed_b_f3 = sb
	_check(speed_a_f3 > speed_b_f3 + 0.05, "la masse n'influence pas l'accélération diagonale (Tandé %.3f vs Mabé %.3f)" % [speed_a_f3, speed_b_f3])
	_check(absf(a.velocity.x - expected_vx) < 0.03 and absf(a.velocity.z - expected_vz) < 0.03,
		"composantes diagonales Tandé non normalisées (vx=%.3f, vz=%.3f, attendu %.3f / %.3f)" % [a.velocity.x, a.velocity.z, expected_vx, expected_vz])
	_check(absf(b.velocity.x - expected_vx) < 0.03 and absf(b.velocity.z - expected_vz) < 0.03,
		"composantes diagonales Mabé non normalisées (vx=%.3f, vz=%.3f, attendu %.3f / %.3f)" % [b.velocity.x, b.velocity.z, expected_vx, expected_vz])
	_check(max_diag_a <= expected_diag + 0.02 and max_diag_b <= expected_diag + 0.02 and max_diag_a <= 3.0 and max_diag_b <= 3.0,
		"vitesse diagonale résultante excessive (Tandé %.3f, Mabé %.3f, limite attendue %.3f)" % [max_diag_a, max_diag_b, expected_diag])
	_check(absf(max_diag_a - expected_diag) < 0.03 and absf(max_diag_b - expected_diag) < 0.03,
		"vitesse diagonale normalisée non atteinte (Tandé %.3f, Mabé %.3f, attendu %.3f)" % [max_diag_a, max_diag_b, expected_diag])
	# Décélération diagonale : Tandé (plus léger) freine plus vite que Mabé.
	ca.move_axis = 0.0
	ca.depth_axis = 0.0
	cb.move_axis = 0.0
	cb.depth_axis = 0.0
	await _frames(2)
	var decel_a := Vector2(a.velocity.x, a.velocity.z).length()
	var decel_b := Vector2(b.velocity.x, b.velocity.z).length()
	_check(decel_a > 0.2 and decel_a < decel_b - 0.05, "freinage diagonal incohérent avec la masse (Tandé %.3f vs Mabé %.3f)" % [decel_a, decel_b])
	await _close(m)

	# 6. Profondeur désactivée : maintenir X + Z ne réduit pas la vitesse X historique (3,0 m/s) et garde Z = 0.
	var m_off = await _new_depth_match(false, true, true)
	var a_off: Fighter = m_off.fighter_a
	_place_xz(a_off, -4.0, 0.0)
	_place_xz(m_off.fighter_b, 4.0, 0.0)
	_ctrl(a_off).move_axis = 1.0
	_ctrl(a_off).depth_axis = 1.0
	await _frames(35)
	_check(absf(a_off.velocity.x - 3.0) < 0.02, "profondeur désactivée : une entrée Z a ralenti le déplacement X (vx = %.3f)" % a_off.velocity.x)
	_check(a_off.global_position.z == 0.0 and a_off.velocity.z == 0.0, "profondeur désactivée : Z non nul (%s, %s)" % [a_off.global_position, a_off.velocity])
	await _close(m_off)
	_end()


# --- Tests 46 à 50 : Mission 010 (contrôles tactiles de déplacement en profondeur) -----------

func _test_touch_depth_up_down_hold_release_and_limits() -> void:
	_begin("Tactile profondeur (-Z / +Z) : pression maintenue, relâchement avec inertie, limites Z = ±1,5 m")
	var m = await _new_depth_match(true, false, true)
	var a: Fighter = m.fighter_a
	_place_xz(a, -2.0, 0.0)
	_place_xz(m.fighter_b, 2.5, 0.0)
	var up: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveUp")
	var down: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveDown")
	_check(up.visible and down.visible, "MoveUp et MoveDown ne sont pas visibles quand depth_enabled = true")

	# 1. Pression maintenue sur MoveUp (-Z) puis relâchement avec inertie.
	var up_pos := _button_center(up)
	_touch(0, up_pos, true)
	await _frames(10)
	_check(up.is_pressed() and Input.is_action_pressed(&"move_up"), "MoveUp non activé par toucher")
	var z_mid := a.global_position.z
	await _frames(20)
	var z_held := a.global_position.z
	_check(z_mid < -0.05 and z_held < z_mid - 0.4, "déplacement continu vers -Z absent (%.3f -> %.3f)" % [z_mid, z_held])
	_touch(0, up_pos, false)
	await _frames(2)
	_check(not Input.is_action_pressed(&"move_up"), "move_up reste actif après relâchement")
	_check(a.velocity.z < -0.2 and a.velocity.z > -2.1, "décélération progressive absente après relâchement de MoveUp (vz = %.3f)" % a.velocity.z)
	await _frames(25)
	_check(absf(a.velocity.z) < 0.001 and a.state == Fighter.State.IDLE, "arrêt et retour IDLE incomplets après relâchement de MoveUp")
	var z_stopped := a.global_position.z
	_check(z_stopped < z_held, "inertie au relâchement non observée sur -Z")

	# 2. Maintien prolongé vers -Z -> limite exacte Z = -1,5 m.
	_touch(0, up_pos, true)
	var min_z := z_stopped
	for _i in 80:
		await _frames(1)
		min_z = minf(min_z, a.global_position.z)
	_touch(0, up_pos, false)
	await _frames(3)
	_check(min_z >= -1.5001 and absf(a.global_position.z - (-1.5)) < 0.01, "limite tactile Z = -1,5 non respectée (z=%.4f, min=%.4f)" % [a.global_position.z, min_z])

	# 3. Pression maintenue sur MoveDown (+Z) -> déplacement continu jusqu'à Z = +1,5 m puis relâchement.
	var down_pos := _button_center(down)
	_touch(0, down_pos, true)
	await _frames(15)
	_check(down.is_pressed() and Input.is_action_pressed(&"move_down"), "MoveDown non activé par toucher")
	_check(a.global_position.z > -1.3, "MoveDown ne déplace pas vers +Z depuis -1,5 (z=%.3f)" % a.global_position.z)
	var max_z := a.global_position.z
	for _i in 110:
		await _frames(1)
		max_z = maxf(max_z, a.global_position.z)
	_touch(0, down_pos, false)
	await _frames(15)
	_check(not Input.is_action_pressed(&"move_down"), "move_down reste actif après relâchement")
	_check(max_z <= 1.5001 and absf(a.global_position.z - 1.5) < 0.01, "limite tactile Z = +1,5 non respectée (z=%.4f, max=%.4f)" % [a.global_position.z, max_z])
	await _close(m)
	_end()


func _test_touch_depth_diagonal_and_normalization() -> void:
	_begin("Tactile profondeur (X + Z et normalisation) : déplacement diagonal tactile normalisé (≈ 2,63 m/s ≤ 3,0 m/s) à 2 doigts et au pouce unique")
	var expected_vx := 3.0 / sqrt(2.0)
	var expected_vz := 2.2 / sqrt(2.0)
	var expected_diag := Vector2(expected_vx, expected_vz).length()

	var m = await _new_depth_match(true, false, true)
	var a: Fighter = m.fighter_a
	var right: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveRight")
	var up: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveUp")
	var left: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveLeft")
	var down: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveDown")

	# 1. Diagonale tactile (+X, -Z) avec deux doigts (MoveRight + MoveUp).
	_place_xz(a, -4.5, 1.0)
	_place_xz(m.fighter_b, 5.0, 0.0)
	var right_pos := _button_center(right)
	var up_pos := _button_center(up)
	_touch(0, right_pos, true)
	_touch(1, up_pos, true)
	var max_diag := 0.0
	for _i in 35:
		await _frames(1)
		max_diag = maxf(max_diag, Vector2(a.velocity.x, a.velocity.z).length())
	_check(a.global_position.x > -3.5 and a.global_position.z < 0.2, "déplacement diagonal tactile (+X, -Z) insuffisant : %s" % a.global_position)
	_check(absf(a.velocity.x - expected_vx) < 0.03 and absf(a.velocity.z - (-expected_vz)) < 0.03,
		"diagonale tactile non normalisée (vx=%.3f, vz=%.3f)" % [a.velocity.x, a.velocity.z])
	_check(max_diag <= expected_diag + 0.02 and max_diag <= 3.0, "vitesse diagonale tactile excessive (%.3f m/s)" % max_diag)
	_touch(0, right_pos, false)
	_touch(1, up_pos, false)
	await _frames(20)

	# 2. Diagonale tactile (-X, +Z) au pouce unique dans la zone diagonale commune entre MoveLeft et MoveDown.
	_place_xz(a, 2.5, -1.0)
	var left_rect := _touch_rect(left)
	var down_rect := _touch_rect(down)
	var diag_zone := left_rect.intersection(down_rect)
	_check(diag_zone.size.x >= 20.0 and diag_zone.size.y >= 20.0, "zone diagonale commune MoveLeft/MoveDown trop petite (%s)" % diag_zone)
	var diag_pos := left.get_viewport().get_final_transform() * diag_zone.get_center()
	_touch(0, diag_pos, true)
	var max_diag_one := 0.0
	for _i in 35:
		await _frames(1)
		max_diag_one = maxf(max_diag_one, Vector2(a.velocity.x, a.velocity.z).length())
	_check(Input.is_action_pressed(&"move_left") and Input.is_action_pressed(&"move_down"), "un pouce dans la zone diagonale n'active pas move_left + move_down")
	_check(a.global_position.x < 1.5 and a.global_position.z > -0.2, "diagonale au pouce unique (-X, +Z) insuffisante : %s" % a.global_position)
	_check(max_diag_one <= expected_diag + 0.02 and max_diag_one <= 3.0, "vitesse diagonale au pouce unique excessive (%.3f m/s)" % max_diag_one)
	_touch(0, diag_pos, false)
	await _frames(5)
	_check(not Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"move_down"), "actions diagonales restées actives après relâchement")
	await _close(m)
	_end()


func _test_touch_depth_multitouch_combat() -> void:
	_begin("Tactile profondeur (multitouch combat) : déplacement Z + attaque légère, puis Z + garde, puis esquive, reprise propre")
	var m = await _new_depth_match(true, false, true)
	var a: Fighter = m.fighter_a
	_place_xz(a, -2.5, 1.0)
	_place_xz(m.fighter_b, 2.5, 0.0)
	var up: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveUp")
	var down: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveDown")
	var light: TouchScreenButton = m.get_node("Interface/TouchControls/RightPad/LightAttack")
	var block: TouchScreenButton = m.get_node("Interface/TouchControls/RightPad/Block")
	var dodge: TouchScreenButton = m.get_node("Interface/TouchControls/RightPad/Dodge")

	# Déplacement -Z maintenu (doigt 0) + attaque légère (doigt 1).
	var up_pos := _button_center(up)
	_touch(0, up_pos, true)
	await _frames(10)
	await _tap(1, _button_center(light))
	_check(a.current_attack_id == 1, "attaque légère ignorée pendant un déplacement tactile Z")
	_check(Input.is_action_pressed(&"move_up"), "move_up relâché par le doigt d'attaque")
	await _frames(25)
	var z_after_attack := a.global_position.z
	await _frames(15)
	_check(a.global_position.z < z_after_attack - 0.2, "le déplacement -Z ne reprend pas après l'attaque (%.3f -> %.3f)" % [z_after_attack, a.global_position.z])
	_touch(0, up_pos, false)
	await _frames(5)

	# Déplacement +Z maintenu (doigt 0) + garde maintenue (doigt 2) + reprise +Z au relâchement du bouclier.
	var down_pos := _button_center(down)
	_touch(0, down_pos, true)
	await _frames(10)
	_touch(2, _button_center(block), true)
	await _frames(10)
	_check(a.state == Fighter.State.BLOCK, "garde impossible en multitouch pendant un déplacement Z (état %s)" % a.state)
	var z_guard := a.global_position.z
	await _frames(15)
	_check(absf(a.global_position.z - z_guard) < 0.1, "le combattant continue d'avancer en Z pendant la garde")
	_touch(2, _button_center(block), false)
	await _frames(15)
	_check(a.state == Fighter.State.WALK and a.global_position.z > z_guard + 0.15, "le déplacement +Z ne reprend pas après relâchement de la garde")

	# Esquive (doigt 1) pendant maintien de +Z.
	await _tap(1, _button_center(dodge))
	_check(a.state == Fighter.State.DODGE, "esquive impossible pendant un maintien tactile Z (état %s)" % a.state)
	_touch(0, down_pos, false)
	await _frames(5)
	_check(not Input.is_action_pressed(&"move_down") and not Input.is_action_pressed(&"block"), "actions restées actives après fin du test multitouch Z")
	await _close(m)
	_end()


func _test_touch_depth_disabled_hides_and_preserves_layout() -> void:
	_begin("Tactile profondeur (non-régression UI) : masqué et inactif si Profondeur = NON (layout V0.5 exact) ; aucun chevauchement ni gêne de glissé si OUI")
	# 1. Profondeur désactivée : MoveUp/MoveDown invisibles, toucher sans effet, positions V0.5.0 exactes.
	var m_off = await _new_depth_match(false, false, true)
	var a_off: Fighter = m_off.fighter_a
	var left_pad_off: Control = m_off.get_node("Interface/TouchControls/LeftPad")
	var left_off: TouchScreenButton = m_off.get_node("Interface/TouchControls/LeftPad/MoveLeft")
	var right_off: TouchScreenButton = m_off.get_node("Interface/TouchControls/LeftPad/MoveRight")
	var up_off: TouchScreenButton = m_off.get_node("Interface/TouchControls/LeftPad/MoveUp")
	var down_off: TouchScreenButton = m_off.get_node("Interface/TouchControls/LeftPad/MoveDown")
	_check(not up_off.visible and not down_off.visible, "MoveUp ou MoveDown visible alors que depth_enabled = false")
	_check(left_pad_off.offset_top == -200.0 and left_pad_off.offset_bottom == -32.0, "LeftPad déplacé alors que depth_enabled = false")
	_check(left_off.position == Vector2(0, 24) and right_off.position == Vector2(150, 24), "MoveLeft ou MoveRight déplacé en mode V0.5")
	_touch(0, _button_center(up_off), true)
	await _frames(15)
	_check(not Input.is_action_pressed(&"move_up") and a_off.global_position.z == 0.0 and a_off.velocity.z == 0.0,
		"toucher la zone MoveUp agit malgré depth_enabled = false")
	_touch(0, _button_center(up_off), false)
	_touch(0, _button_center(down_off), true)
	await _frames(15)
	_check(not Input.is_action_pressed(&"move_down") and a_off.global_position.z == 0.0 and a_off.velocity.z == 0.0,
		"toucher la zone MoveDown agit malgré depth_enabled = false")
	_touch(0, _button_center(down_off), false)
	await _close(m_off)

	# 2. Profondeur activée : boutons dans le cadre 1280×720, sans chevauchement HUD/RightPad ni cercles, glissé gauche->droite préservé.
	VisualSettings.clear()
	DepthSettings.save_enabled(true)
	var game = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(3)
	var m = game.match_scene
	var viewport_rect := get_viewport().get_visible_rect()
	var top_bar := (m.get_node("Interface/HUD/TopBar") as Control).get_global_rect()
	var visual_rect := (m.get_node("Interface/VisualToggle") as Control).get_global_rect()
	var depth_rect := (m.get_node("Interface/DepthToggle") as Control).get_global_rect()
	var left_pad: Control = m.get_node("Interface/TouchControls/LeftPad")
	var left: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveLeft")
	var right: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveRight")
	var up: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveUp")
	var down: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveDown")
	for btn: TouchScreenButton in [left, right, up, down]:
		var r := _touch_rect(btn)
		_check(viewport_rect.encloses(r), "%s dépasse du viewport courant %s (%s)" % [btn.name, viewport_rect, r])
		# Vérification également en hauteur de référence 720 px (LeftPad ancré en bas).
		var y_top_720 := 720.0 + left_pad.offset_top + btn.position.y
		var y_bot_720 := y_top_720 + btn.texture_normal.get_size().y
		_check(y_top_720 > depth_rect.end.y and y_bot_720 <= 720.0,
			"%s sort de la zone libre en 1280×720 (y = %.1f..%.1f)" % [btn.name, y_top_720, y_bot_720])
		_check(not r.intersects(top_bar) and not r.intersects(visual_rect) and not r.intersects(depth_rect),
			"%s chevauche le HUD ou les boutons de réglage (%s)" % [btn.name, r])
		for right_path in ["RightPad/Block", "RightPad/LightAttack", "RightPad/HeavyAttack", "RightPad/Dodge"]:
			var rb := m.get_node("Interface/TouchControls/" + right_path) as TouchScreenButton
			_check(not r.intersects(_touch_rect(rb)), "%s chevauche %s" % [btn.name, right_path])
	# Cercles visuels (rayon extérieur 56 px) séparés entre tous les boutons directionnels.
	var pads: Array[TouchScreenButton] = [left, right, up, down]
	for i in pads.size():
		for j in range(i + 1, pads.size()):
			var ci := _touch_rect(pads[i]).get_center()
			var cj := _touch_rect(pads[j]).get_center()
			_check(ci.distance_to(cj) >= 112.0, "cercles visuels de %s et %s trop proches (%.1f px)" % [pads[i].name, pads[j].name, ci.distance_to(cj)])
	# Glissé horizontal gauche -> droite ne déclenche pas move_up ni move_down.
	var from := _button_center(left)
	var to := _button_center(right)
	_touch(0, from, true)
	await _frames(10)
	_drag(0, from, to)
	await _frames(5)
	_check(Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"move_left"), "glissé gauche->droite cassé en mode profondeur")
	_check(not Input.is_action_pressed(&"move_up") and not Input.is_action_pressed(&"move_down"), "glissé gauche->droite a déclenché un bouton Z")
	_touch(0, to, false)
	await _frames(3)
	game.queue_free()
	VisualSettings.clear()
	await _frames(2)
	_end()


func _test_touch_depth_toggle_integration() -> void:
	_begin("Tactile profondeur (bascule Profondeur) : cachés au démarrage, visibles et actifs après bascule OUI, recachés après bascule NON")
	VisualSettings.clear()
	var game = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(3)
	var m = game.match_scene
	_check(not m.get_node("Interface/TouchControls/LeftPad/MoveUp").visible and not m.get_node("Interface/TouchControls/LeftPad/MoveDown").visible,
		"boutons Z visibles au démarrage par défaut")
	# Bascule vers Profondeur : OUI
	await _finger_tap(_control_center((m.get_node("Interface/DepthToggle") as DepthToggle).button()), 3)
	await _frames(3)
	m = game.match_scene
	var up: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveUp")
	var down: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/MoveDown")
	_check(m.depth_enabled and up.visible and down.visible, "boutons Z absents après activation de Profondeur")
	_touch(0, _button_center(up), true)
	await _frames(15)
	_check(m.fighter_a.global_position.z < -0.1, "MoveUp ne déplace pas en Z après activation via DepthToggle")
	_touch(0, _button_center(up), false)
	# Attendre la fin de la garde anti-double-tap (24 frames) puis désactiver.
	await _frames(20)
	await _finger_tap(_control_center((m.get_node("Interface/DepthToggle") as DepthToggle).button()), 3)
	await _frames(3)
	m = game.match_scene
	_check(not m.depth_enabled and not m.get_node("Interface/TouchControls/LeftPad/MoveUp").visible and not m.get_node("Interface/TouchControls/LeftPad/MoveDown").visible,
		"boutons Z restés visibles après désactivation de Profondeur")
	game.queue_free()
	VisualSettings.clear()
	await _frames(2)
	_end()



