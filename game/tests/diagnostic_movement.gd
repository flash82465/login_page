extends Node
## Diagnostic du bug « le combattant revient à sa position initiale » (mission 003).
## Simule un vrai toucher maintenu sur les boutons fléchés, puis le relâchement,
## et journalise la position monde du combattant, sa position à l'écran et la caméra.
## Lancement : godot --headless --path game --fixed-fps 60 res://tests/diagnostic_movement.tscn

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func _ready() -> void:
	await _scenario("MoveRight", 90, 90)
	await _scenario("MoveLeft", 90, 90)
	print("DIAG FIN")
	get_tree().quit(0)


func _scenario(button_name: String, hold_frames: int, release_frames: int) -> void:
	var m: Node3D = MAIN_SCENE.instantiate()
	add_child(m)
	await get_tree().physics_frame
	var a: Node3D = m.get_node("Fighters/FighterA")
	var b: Node3D = m.get_node("Fighters/FighterB")
	var cam: Camera3D = m.get_node("FightCamera")
	var btn: TouchScreenButton = m.get_node("Interface/TouchControls/LeftPad/" + button_name)
	var center: Vector2 = btn.get_global_transform_with_canvas() * (btn.texture_normal.get_size() * 0.5)
	print("DIAG %s : bouton au point %s" % [button_name, center])
	_touch(center, true)
	for i in hold_frames:
		await get_tree().physics_frame
		if i % 15 == 0:
			_log("maintien", i, a, b, cam, btn)
	_touch(center, false)
	for i in release_frames:
		await get_tree().physics_frame
		if i % 15 == 0:
			_log("relâché", i, a, b, cam, btn)
	m.queue_free()
	await get_tree().physics_frame


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _log(phase: String, i: int, a: Node3D, b: Node3D, cam: Camera3D, btn: TouchScreenButton) -> void:
	var screen := cam.unproject_position(a.global_position + Vector3(0, 0.9, 0))
	print("DIAG %-8s f=%3d  A.x=%6.2f  B.x=%6.2f  cam.x=%6.2f  A.ecran.x=%6.0f  bouton=%s  axe=%.2f" % [
		phase, i, a.global_position.x, b.global_position.x, cam.global_position.x, screen.x,
		btn.is_pressed(), Input.get_axis(&"move_left", &"move_right")])
