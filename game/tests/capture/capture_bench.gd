extends Node
## Banc de capture visuelle (mission 005).
##
## Rejoue des situations de combat scriptées, photographie le rendu réel et assemble des
## planches et des séquences lisibles sur téléphone. Il n'utilise que l'API déjà présente dans
## V0.4.1 (scène principale, contrôleur scripté, état des combattants) : le même banc tourne sur
## le code d'une version de référence, ce qui permet une comparaison pixel à pixel.
## Exclu de l'APK (dossier tests/). Lancement (affichage requis, par exemple xvfb-run) :
##   godot --path game --resolution 1920x1080 --fixed-fps 60 res://tests/capture/capture_bench.tscn -- --out=DOSSIER --title=TEXTE

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const ScriptedController := preload("res://tests/scripted_controller.gd")

const TILE := Vector2i(480, 600)
const PLANCHE_WIDTH := 1080
const MARGIN := 40
const HEADER_HEIGHT := 170
const ROW_LABEL_HEIGHT := 58
const ROW_GAP := 30
const FIGHTERS := ["tande", "mabe"]
const FIGHTER_NAMES := ["Tandé", "Mabé"]
const SIDES := ["droite", "gauche"]

var _out := "user://capture"
var _title := "OKÉLUN"
var _scale := 1.0
var _tiles := {}
var _labels := {}
var _manifest := {"planches": [], "sequences": [], "raw": 0}
var _failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--title="):
			_title = arg.substr(8)
	for sub in ["raw", "planches", "sequences"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join(sub))
	await _step()
	var api := "Vulkan" if RenderingServer.get_rendering_device() != null else "OpenGL"
	_manifest["renderer"] = "%s (%s)" % [api, RenderingServer.get_video_adapter_name()]
	_manifest["title"] = _title
	print("CAPTURE rendu %s ; fenêtre %s ; viewport %s" % [_manifest["renderer"], DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])
	await _warm_up()
	for fighter_index in 2:
		for facing_right in [true, false]:
			await _capture_states(fighter_index, facing_right)
			if _failed:
				return
	for fighter_index in 2:
		await _build_planches(fighter_index)
	await _sequence_combat()
	await _sequence_light_attack_slow()
	if _failed:
		return
	var file := FileAccess.open(_out.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "  "))
	file.close()
	print("CAPTURE OK : %d images brutes, %d planches, %d séquences" % [_manifest["raw"], _manifest["planches"].size(), _manifest["sequences"].size()])
	get_tree().quit(0)


# --- Outils ------------------------------------------------------------------------------

## Avance d'une frame de logique et attend qu'elle soit dessinée : l'image et l'état lus ensuite
## correspondent à la même frame.
func _step() -> void:
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw


func _fail(message: String) -> void:
	_failed = true
	printerr("CAPTURE ÉCHEC : ", message)
	get_tree().quit(1)


func _grab() -> Image:
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	_scale = float(img.get_width()) / get_viewport().get_visible_rect().size.x
	return img


func _crop(img: Image, camera: Camera3D, world: Vector3, size: Vector2i) -> Image:
	var p := camera.unproject_position(world) * _scale
	var x := clampi(int(p.x) - size.x / 2, 0, img.get_width() - size.x)
	var y := clampi(int(p.y) - size.y / 2, 0, img.get_height() - size.y)
	return img.get_region(Rect2i(x, y, size.x, size.y))


func _place(fighter: Fighter, x: float) -> void:
	fighter.global_position = Vector3(x, 0.0, 0.0)
	fighter.velocity = Vector3.ZERO


## Nouvelle scène de combat : le combattant étudié (0 = Tandé, 1 = Mabé) regarde vers la droite
## ou vers la gauche, à la distance donnée de son adversaire. Les deux sont pilotés par script.
func _setup(fighter_index: int, facing_right: bool, distance: float) -> Dictionary:
	var m = MAIN_SCENE.instantiate()
	add_child(m)
	await _step()
	var ca := ScriptedController.new()
	m.add_child(ca)
	m.fighter_a.controller = ca
	var cb := ScriptedController.new()
	m.add_child(cb)
	m.fighter_b.controller = cb
	(m.get_node("Interface") as CanvasLayer).visible = false
	var actor: Fighter = m.fighter_a if fighter_index == 0 else m.fighter_b
	var other: Fighter = m.fighter_b if fighter_index == 0 else m.fighter_a
	var dir := 1.0 if facing_right else -1.0
	_place(actor, -dir * distance * 0.5)
	_place(other, dir * distance * 0.5)
	m.camera.set_targets(m.fighter_a, m.fighter_b)
	for i in 8:
		await _step()
	return {
		"m": m, "actor": actor, "other": other, "dir": dir,
		"me": ca if fighter_index == 0 else cb, "them": cb if fighter_index == 0 else ca,
		"who": FIGHTERS[fighter_index], "side": SIDES[0] if facing_right else SIDES[1],
	}


func _teardown(ctx: Dictionary) -> void:
	ctx["m"].queue_free()
	await _step()
	await _step()


func _state_frame(fighter: Fighter) -> int:
	return int(fighter.get("_state_frame"))


## Avance jusqu'à ce que le combattant soit dans l'état voulu depuis `frame` frames.
func _until(fighter: Fighter, state: int, frame: int, limit: int = 120) -> bool:
	for i in limit:
		await _step()
		if fighter.state == state and _state_frame(fighter) == frame:
			return true
	return false


## Cadrages : « avant » (attaques, garde : cadre décalé vers l'adversaire), « corps » (réactions :
## centré sur le corps qui recule), « ko » (corps au sol, cadre élargi aux proportions de la vignette).
func _shot(ctx: Dictionary, key: String, label: String, framing: String = "avant") -> void:
	var img := _grab()
	img.save_png(_out.path_join("raw").path_join("%s_%s_%s.png" % [ctx["who"], ctx["side"], key]))
	_manifest["raw"] += 1
	var actor: Fighter = ctx["actor"]
	var dir: float = ctx["dir"]
	var tile: Image
	match framing:
		"ko":
			tile = _crop(img, ctx["m"].camera, actor.global_position + Vector3(-dir * 0.95, 0.9, 0.0), Vector2i(720, 900))
			tile.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		"corps":
			tile = _crop(img, ctx["m"].camera, actor.global_position + Vector3(-dir * 0.15, 0.95, 0.0), TILE)
		_:
			tile = _crop(img, ctx["m"].camera, actor.global_position + Vector3(dir * 0.3, 0.95, 0.0), TILE)
	_tiles["%s/%s/%s" % [ctx["who"], ctx["side"], key]] = tile
	_labels[key] = label


# --- Préchauffage : compile tous les matériaux avant la première capture ----------------

func _warm_up() -> void:
	var ctx := await _setup(0, true, 0.9)
	ctx["me"].press_light()
	for i in 40:
		await _step()
	ctx["them"].block = true
	for i in 20:
		await _step()
	ctx["me"].press_heavy()
	for i in 70:
		await _step()
	await _teardown(ctx)


# --- Planches : tous les états, dans les deux orientations -------------------------------

func _capture_states(fighter_index: int, facing_right: bool) -> void:
	# Attaques dans le vide : la pose seule, sans arrêt sur image.
	for heavy in [false, true]:
		var ctx := await _setup(fighter_index, facing_right, 2.4)
		var actor: Fighter = ctx["actor"]
		var attack: AttackData = actor.heavy_attack if heavy else actor.light_attack
		var prefix := "lourde" if heavy else "legere"
		var attack_name := "Attaque lourde" if heavy else "Attaque légère"
		var prep := int(ceil(attack.startup_frames * 0.6))
		var active := attack.startup_frames + 1
		var recovery := attack.startup_frames + attack.active_frames + int(ceil(attack.recovery_frames * 0.5))
		if heavy:
			ctx["me"].press_heavy()
		else:
			ctx["me"].press_light()
		var marks := {
			prep: ["%s-1-preparation" % prefix, "%s - préparation (frame %d/%d)" % [attack_name, prep, attack.startup_frames]],
			active: ["%s-2-coup-actif" % prefix, "%s - coup actif (frame %d)" % [attack_name, active]],
			recovery: ["%s-3-recuperation" % prefix, "%s - récupération (frame %d)" % [attack_name, recovery]],
		}
		var taken := 0
		for i in 90:
			await _step()
			if actor.state == Fighter.State.ATTACK and marks.has(_state_frame(actor)):
				var mark: Array = marks[_state_frame(actor)]
				_shot(ctx, mark[0], mark[1])
				taken += 1
		if taken != 3:
			_fail("%s : %d poses d'attaque capturées sur 3" % [prefix, taken])
			return
		await _teardown(ctx)

	var c := await _setup(fighter_index, facing_right, 2.0)
	for i in 20:
		await _step()
	_shot(c, "etat-1-attente", "Attente")
	await _teardown(c)

	c = await _setup(fighter_index, facing_right, 3.0)
	c["me"].move_axis = c["dir"]
	for i in 14:
		await _step()
	if c["actor"].state != Fighter.State.WALK:
		_fail("marche non atteinte")
		return
	_shot(c, "etat-2-marche", "Marche vers l'adversaire")
	await _teardown(c)

	c = await _setup(fighter_index, facing_right, 2.0)
	c["me"].block = true
	for i in 12:
		await _step()
	_shot(c, "etat-3-garde", "Garde (bouclier maintenu)")
	await _teardown(c)

	c = await _setup(fighter_index, facing_right, 2.0)
	c["me"].press_dodge()
	var reached_dodge: bool = await _until(c["actor"], Fighter.State.DODGE, 6)
	if not reached_dodge:
		_fail("esquive non atteinte")
		return
	_shot(c, "etat-4-esquive", "Esquive (invulnérable)")
	await _teardown(c)

	c = await _setup(fighter_index, facing_right, 0.9)
	c["them"].press_light()
	var reached_hit: bool = await _until(c["actor"], Fighter.State.HITSTUN, 1)
	if not reached_hit:
		_fail("coup reçu non atteint")
		return
	_shot(c, "etat-5-coup-recu", "Coup reçu (éclair rouge)", "corps")
	await _teardown(c)

	c = await _setup(fighter_index, facing_right, 0.9)
	c["me"].block = true
	for i in 20:
		await _step()
	c["them"].press_light()
	var reached_block: bool = await _until(c["actor"], Fighter.State.BLOCKSTUN, 1)
	if not reached_block:
		_fail("coup bloqué non atteint")
		return
	_shot(c, "etat-6-coup-bloque", "Coup bloqué")
	await _teardown(c)

	c = await _setup(fighter_index, facing_right, 0.9)
	c["me"].press_light()
	await _step()
	await _step()
	c["them"].block = true
	var reached_parry: bool = await _until(c["actor"], Fighter.State.HITSTUN, 1)
	if not reached_parry:
		_fail("parade adverse non atteinte")
		return
	_shot(c, "etat-7-parade-subie", "Déséquilibré par une parade adverse", "corps")
	await _teardown(c)

	c = await _setup(fighter_index, facing_right, 0.9)
	c["actor"].health = 5.0
	c["them"].press_light()
	var reached_ko: bool = await _until(c["actor"], Fighter.State.KO, 25)
	if not reached_ko:
		_fail("K.O. non atteint")
		return
	_shot(c, "etat-8-ko", "K.O.", "ko")
	await _teardown(c)


func _build_planches(fighter_index: int) -> void:
	var who: String = FIGHTERS[fighter_index]
	var groups := [
		["1-attaques", "attaques", ["legere-1-preparation", "legere-2-coup-actif", "legere-3-recuperation",
			"lourde-1-preparation", "lourde-2-coup-actif", "lourde-3-recuperation"]],
		["2-etats", "états et réactions", ["etat-1-attente", "etat-2-marche", "etat-3-garde", "etat-4-esquive",
			"etat-5-coup-recu", "etat-6-coup-bloque", "etat-7-parade-subie", "etat-8-ko"]],
	]
	for group in groups:
		var rows := []
		for key in group[2]:
			rows.append({"label": _labels[key], "left": _tiles["%s/droite/%s" % [who, key]], "right": _tiles["%s/gauche/%s" % [who, key]]})
		var file := "%s-%s.jpg" % [who, group[0]]
		var title := "%s - %s" % [FIGHTER_NAMES[fighter_index], group[1]]
		await _make_planche(file, title, rows)
		_manifest["planches"].append({"file": file, "title": title})


func _make_planche(file: String, title: String, rows: Array) -> void:
	var row_height := ROW_LABEL_HEIGHT + TILE.y + ROW_GAP
	var vp := SubViewport.new()
	vp.size = Vector2i(PLANCHE_WIDTH, HEADER_HEIGHT + rows.size() * row_height + MARGIN)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(vp.size)
	vp.add_child(root)
	_rect(root, Rect2(Vector2.ZERO, Vector2(vp.size)), Color(0.10, 0.09, 0.08))
	_text(root, title, Vector2(MARGIN, 22), 42, Color(0.96, 0.76, 0.42))
	_text(root, _title, Vector2(MARGIN, 82), 24, Color(0.82, 0.80, 0.76))
	_text(root, "Colonne de gauche : tourné vers la droite      Colonne de droite : tourné vers la gauche", Vector2(MARGIN, 118), 22, Color(0.66, 0.64, 0.6))
	var y := HEADER_HEIGHT
	for row in rows:
		_text(root, row["label"], Vector2(MARGIN, y + 10), 30, Color(1, 1, 1))
		var ty := y + ROW_LABEL_HEIGHT
		_tile(root, row["left"], Rect2(MARGIN, ty, TILE.x, TILE.y))
		_tile(root, row["right"], Rect2(PLANCHE_WIDTH - MARGIN - TILE.x, ty, TILE.x, TILE.y))
		y += row_height
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(_out.path_join("planches").path_join(file), 0.9)
	vp.queue_free()


func _rect(parent: Control, r: Rect2, color: Color) -> void:
	var c := ColorRect.new()
	c.color = color
	c.position = r.position
	c.size = r.size
	parent.add_child(c)


func _text(parent: Control, value: String, at: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _tile(parent: Control, img: Image, r: Rect2) -> void:
	_rect(parent, r.grow(2), Color(0.32, 0.29, 0.25))
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = r.position
	t.size = r.size
	parent.add_child(t)


# --- Séquences animées (GIF) -------------------------------------------------------------

func _sequence_combat() -> void:
	var folder := "combat"
	DirAccess.make_dir_recursive_absolute(_out.path_join("sequences").path_join(folder))
	var ctx := await _setup(0, true, 1.6)
	var tande = ctx["me"]
	var mabe = ctx["them"]
	var n := 0
	for t in 320:
		match t:
			0:
				tande.move_axis = 1.0  # Tandé avance au contact...
			20:
				tande.move_axis = 0.0
			26:
				tande.press_light()  # ... et frappe : Mabé est touché
			75:
				tande.block = true  # Tandé garde
			80:
				mabe.move_axis = -1.0  # Mabé revient au contact...
			100:
				mabe.move_axis = 0.0
			104:
				mabe.press_heavy()  # ... et frappe lourd : coup bloqué
			175:
				tande.block = false
			182:
				tande.press_dodge()  # Tandé esquive en arrière
			215:
				mabe.move_axis = -1.0  # Mabé revient au contact...
			240:
				mabe.move_axis = 0.0
			246:
				mabe.press_light()  # ... et attaque
			248:
				tande.block = true  # Tandé lève la garde juste avant l'impact : parade
			290:
				tande.block = false
		await _step()
		if t % 3 == 0:
			var img := _grab()
			img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			img.save_png(_out.path_join("sequences").path_join(folder).path_join("f_%04d.png" % n))
			n += 1
	await _teardown(ctx)
	_manifest["sequences"].append({"dir": folder, "fps": 20, "frames": n,
		"title": "Échange Tandé contre Mabé, vitesse réelle : approche, coup, garde contre coup lourd, esquive, parade"})


func _sequence_light_attack_slow() -> void:
	var folder := "attaque-legere-ralenti"
	DirAccess.make_dir_recursive_absolute(_out.path_join("sequences").path_join(folder))
	var ctx := await _setup(0, true, 0.9)
	var m = ctx["m"]
	var n := 0
	for t in 44:
		if t == 4:
			ctx["me"].press_light()
		await _step()
		var img := _grab()
		var mid: Vector3 = (ctx["actor"].global_position + ctx["other"].global_position) * 0.5 + Vector3(0.0, 0.95, 0.0)
		var tile := _crop(img, m.camera, mid, Vector2i(900, 600))
		tile.resize(720, 480, Image.INTERPOLATE_LANCZOS)
		tile.save_png(_out.path_join("sequences").path_join(folder).path_join("f_%04d.png" % n))
		n += 1
	await _teardown(ctx)
	_manifest["sequences"].append({"dir": folder, "fps": 15, "frames": n,
		"title": "Attaque légère de Tandé qui touche Mabé, ralenti x4 (une image par frame de jeu)"})
