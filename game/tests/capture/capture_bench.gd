extends Node
## Banc de capture visuelle (mission 005).
##
## Rejoue des situations de combat scriptées, photographie le rendu réel et assemble des
## planches et des séquences lisibles sur téléphone. Il n'utilise que l'API déjà présente dans
## V0.4.1 (scène principale, contrôleur scripté, état des combattants) : le même banc tourne sur
## le code d'une version de référence, ce qui permet une comparaison pixel à pixel.
## Exclu de l'APK (dossier tests/). Lancement (affichage requis, par exemple xvfb-run) :
##   godot --path game --resolution 1920x1080 --fixed-fps 60 res://tests/capture/capture_bench.tscn -- --out=DOSSIER --title=TEXTE [--generation=silhouette]
## Mode capsule (par défaut) : états et séquences de la génération capsule, comparables à V0.4.1.
## Mode silhouette : planches de la génération silhouette (étape 2), chargée à la demande.

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
const SILHOUETTE_GENERATION := "res://assets/visual/generation_silhouette_v05.tres"
const CAPTION_HEIGHT := 40
const ZONE_COLORS := {"Head": Color(0.2, 0.95, 0.45, 0.4), "Torso": Color(1.0, 0.85, 0.2, 0.4), "Legs": Color(0.3, 0.6, 1.0, 0.4)}

var _out := "user://capture"
var _title := "OKÉLUN"
var _scale := 1.0
var _tiles := {}
var _labels := {}
var _manifest := {"planches": [], "sequences": [], "raw": 0}
var _failed := false
var _mode := "capsule"
var _generation = null  # VisualGeneration, chargée seulement en mode silhouette


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--title="):
			_title = arg.substr(8)
		elif arg.begins_with("--generation="):
			_mode = arg.substr(13)
	if _mode == "silhouette" or _mode == "animations":
		_generation = load(SILHOUETTE_GENERATION)
	for sub in ["raw", "planches", "sequences"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join(sub))
	await _step()
	var api := "Vulkan" if RenderingServer.get_rendering_device() != null else "OpenGL"
	_manifest["renderer"] = "%s (%s)" % [api, RenderingServer.get_video_adapter_name()]
	_manifest["title"] = _title
	print("CAPTURE rendu %s ; fenêtre %s ; viewport %s" % [_manifest["renderer"], DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])
	await _warm_up()
	if _mode == "silhouette":
		await _capture_silhouettes()
		_finish()
		return
	if _mode == "animations":
		await _capture_animations()
		if not _failed:
			_finish()
		return
	if _mode == "integration":
		await _capture_integration()
		if not _failed:
			_finish()
		return
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
	_finish()


func _finish() -> void:
	var file := FileAccess.open(_out.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "  "))
	file.close()
	print("CAPTURE OK (%s) : %d images brutes, %d planches, %d séquences" % [_mode, _manifest["raw"], _manifest["planches"].size(), _manifest["sequences"].size()])
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
	if _generation != null:
		_generation.apply_to(m)
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


# --- Génération silhouette (étape 2) ------------------------------------------------------

func _steps(count: int) -> void:
	for i in count:
		await _step()


func _save_raw(img: Image, name: String) -> void:
	img.save_png(_out.path_join("raw").path_join(name + ".png"))
	_manifest["raw"] += 1


func _hide_visual(fighter: Fighter) -> void:
	(fighter.get_node("Visual") as Node3D).visible = false


## Noir pur : toutes les pièces du visuel en noir, sans liseré ni Marques.
func _force_black(fighter: Fighter) -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	black.cull_mode = BaseMaterial3D.CULL_DISABLED  # pièces plates : les deux faces
	for node in fighter.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = black


## Zones de touche superposées (tête en vert, torse en jaune, jambes en bleu), toujours visibles.
func _show_zones(fighter: Fighter) -> void:
	for zone in fighter.get_node("Hurtboxes").get_children():
		var shape_node := zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node == null or not ZONE_COLORS.has(String(zone.name)):
			continue
		var mesh: Mesh
		if shape_node.shape is SphereShape3D:
			var sphere := SphereMesh.new()
			sphere.radius = (shape_node.shape as SphereShape3D).radius
			sphere.height = sphere.radius * 2.0
			mesh = sphere
		elif shape_node.shape is BoxShape3D:
			var box := BoxMesh.new()
			box.size = (shape_node.shape as BoxShape3D).size
			mesh = box
		else:
			continue
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = true
		material.albedo_color = ZONE_COLORS[String(zone.name)]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shape_node.add_child(mi)


func _midpoint(ctx: Dictionary) -> Vector3:
	return (ctx["actor"].global_position + ctx["other"].global_position) * 0.5 + Vector3(0.0, 0.92, 0.0)


func _capture_silhouettes() -> void:
	var zones_legend := "Zones de touche : tête en vert, torse en jaune, jambes en bleu (inchangées)."
	# 1. Chaque combattant seul, dans les deux orientations.
	for fighter_index in 2:
		var rows := []
		for spec in [["Attente", false, false], ["Garde (blocage)", true, false], ["Zones de touche - attente", false, true], ["Zones de touche - garde", true, true]]:
			var images := []
			for facing_right in [true, false]:
				var c := await _setup(fighter_index, facing_right, 2.0)
				_hide_visual(c["other"])
				c["me"].block = spec[1]
				if spec[2]:
					_show_zones(c["actor"])
				await _steps(12)
				var img := _grab()
				_save_raw(img, "silhouette_%s_%s_%s" % [c["who"], c["side"], String(spec[0]).to_lower().replace(" ", "-")])
				images.append(_crop(img, c["m"].camera, c["actor"].global_position + Vector3(0.0, 0.92, 0.0), TILE))
				await _teardown(c)
			rows.append({"label": spec[0], "images": images, "captions": ["Tourné vers la droite", "Tourné vers la gauche"]})
		await _make_rows_planche("%s-1-seul.jpg" % FIGHTERS[fighter_index], "%s seul" % FIGHTER_NAMES[fighter_index],
			"Vignettes à l'échelle 1:1 d'un écran 1080p. " + zones_legend, rows)
	if _failed:
		return

	# 2. Les deux ensemble (2 m), 3. en noir pur, 4. au contact (0,7 m).
	var together := []
	var black := []
	var contact := []
	var specs := [
		[together, "Attente : Tandé à gauche, Mabé à droite", 2.0, true, false, false, false],
		[together, "Attente : côtés inversés", 2.0, false, false, false, false],
		[together, "Les deux en garde (blocage)", 2.0, true, true, false, false],
		[together, "Zones de touche", 2.0, true, false, true, false],
		[black, "Noir pur : attente", 2.0, true, false, false, true],
		[black, "Noir pur : côtés inversés", 2.0, false, false, false, true],
		[black, "Noir pur : les deux en garde", 2.0, true, true, false, true],
		[black, "Noir pur : au contact (0,7 m)", 0.7, true, false, false, true],
		[contact, "Au contact (0,7 m) : attente", 0.7, true, false, false, false],
		[contact, "Au contact : côtés inversés", 0.7, false, false, false, false],
		[contact, "Au contact : les deux en garde", 0.7, true, true, false, false],
		[contact, "Au contact : zones de touche", 0.7, true, false, true, false],
	]
	var index := 0
	for spec in specs:
		var c := await _setup(0, spec[3], spec[2])
		if spec[4]:
			c["me"].block = true
			c["them"].block = true
		if spec[5]:
			_show_zones(c["actor"])
			_show_zones(c["other"])
		if spec[6]:
			_force_black(c["actor"])
			_force_black(c["other"])
		await _steps(12)
		var img := _grab()
		_save_raw(img, "silhouette_duo_%02d" % index)
		index += 1
		var tile := _crop(img, c["m"].camera, _midpoint(c), Vector2i(1000, 640))
		(spec[0] as Array).append({"label": spec[1], "images": [tile]})
		await _teardown(c)
	# Noir pur réduit de moitié : lisibilité sur un petit écran.
	var c2 := await _setup(0, true, 2.0)
	_force_black(c2["actor"])
	_force_black(c2["other"])
	await _steps(12)
	var small := _crop(_grab(), c2["m"].camera, _midpoint(c2), Vector2i(1000, 640))
	small.resize(500, 320, Image.INTERPOLATE_LANCZOS)
	black.append({"label": "Noir pur, réduit de moitié (petit écran)", "images": [small]})
	await _teardown(c2)
	await _make_rows_planche("ensemble-2-les-deux.jpg", "Tandé et Mabé ensemble", "Distance 2 m, échelle 1:1 d'un écran 1080p. " + zones_legend, together)
	await _make_rows_planche("ensemble-3-noir-pur.jpg", "Noir pur, sans couleurs", "Reconnaissables à la forme seule ? Échelle 1:1, puis réduit de moitié.", black)
	await _make_rows_planche("ensemble-4-contact.jpg", "Au contact (0,7 m, distance minimale)", "Liserés et teintes distincts : qui est qui ? " + zones_legend, contact)

	# 5. Taille réelle sur téléphone : écran de jeu complet, interface comprise.
	var phone := [
		["telephone-1-debut.jpg", "Taille réelle sur téléphone : début du combat (3 m)", 3.0, false],
		["telephone-2-approche.jpg", "Taille réelle sur téléphone : approche (1,4 m)", 1.4, false],
		["telephone-3-contact.jpg", "Taille réelle sur téléphone : au contact, Mabé en garde", 0.7, true],
	]
	for spec in phone:
		var c := await _setup(0, true, spec[2])
		(c["m"].get_node("Interface") as CanvasLayer).visible = true
		c["them"].block = spec[3]
		await _steps(12)
		var img := _grab()
		_save_raw(img, String(spec[0]).get_basename())
		img.save_jpg(_out.path_join("planches").path_join(spec[0]), 0.9)
		_manifest["planches"].append({"file": spec[0], "title": spec[1] + " (ouvrir en plein écran, téléphone à l'horizontale)"})
		await _teardown(c)


## Planche générique : chaque rangée a un titre et une ou plusieurs images côte à côte,
## réduites seulement si elles dépassent la largeur disponible.
func _make_rows_planche(file: String, title: String, subtitle: String, rows: Array) -> void:
	var inner := PLANCHE_WIDTH - 2 * MARGIN
	var layout := []
	var height := HEADER_HEIGHT
	for row in rows:
		var images: Array = row["images"]
		var cell := (inner - (images.size() - 1) * MARGIN) / images.size()
		var sizes := []
		var row_height := 0
		for img: Image in images:
			var k := minf(1.0, float(cell) / img.get_width())
			var size := Vector2i(int(img.get_width() * k), int(img.get_height() * k))
			sizes.append(size)
			row_height = maxi(row_height, size.y)
		var captions: bool = row.has("captions")
		layout.append({"cell": cell, "sizes": sizes, "height": row_height, "captions": captions})
		height += ROW_LABEL_HEIGHT + row_height + (CAPTION_HEIGHT if captions else 0) + ROW_GAP
	height += MARGIN
	var vp := SubViewport.new()
	vp.size = Vector2i(PLANCHE_WIDTH, height)
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
	var sub := Label.new()
	sub.text = subtitle
	sub.position = Vector2(MARGIN, 116)
	sub.size = Vector2(inner, 50)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 21)
	sub.add_theme_color_override("font_color", Color(0.66, 0.64, 0.6))
	root.add_child(sub)
	var y := HEADER_HEIGHT
	for r in rows.size():
		var row: Dictionary = rows[r]
		var info: Dictionary = layout[r]
		_text(root, row["label"], Vector2(MARGIN, y + 10), 30, Color(1, 1, 1))
		var ty: int = y + ROW_LABEL_HEIGHT
		var images: Array = row["images"]
		for i in images.size():
			var size: Vector2i = info["sizes"][i]
			var cell: int = info["cell"]
			var x := MARGIN + i * (cell + MARGIN) + (cell - size.x) / 2
			_tile(root, images[i], Rect2(x, ty, size.x, size.y))
			if info["captions"]:
				_text(root, row["captions"][i], Vector2(x, ty + size.y + 6), 22, Color(0.75, 0.72, 0.68))
		y += ROW_LABEL_HEIGHT + int(info["height"]) + (CAPTION_HEIGHT if info["captions"] else 0) + ROW_GAP
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(_out.path_join("planches").path_join(file), 0.9)
	vp.queue_free()
	_manifest["planches"].append({"file": file, "title": title})


# --- Animations des silhouettes (étape 3) -------------------------------------------------

## Zone de frappe en rouge translucide ; sa visibilité suit l'activité réelle de la zone.
func _show_hitbox(fighter: Fighter) -> MeshInstance3D:
	var shape_node := fighter.hitbox.get_node("CollisionShape3D") as CollisionShape3D
	var box := BoxMesh.new()
	box.size = (shape_node.shape as BoxShape3D).size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = Color(1.0, 0.15, 0.1, 0.35)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	shape_node.add_child(mi)
	return mi


func _actor_tile(ctx: Dictionary, framing: String = "avant") -> Image:
	var img := _grab()
	var actor: Fighter = ctx["actor"]
	var dir: float = ctx["dir"]
	if framing == "ko":
		var tile := _crop(img, ctx["m"].camera, actor.global_position + Vector3(-dir * 0.95, 0.9, 0.0), Vector2i(720, 900))
		tile.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		return tile
	var shift := 0.2 if framing == "avant" else -0.1
	return _crop(img, ctx["m"].camera, actor.global_position + Vector3(dir * shift, 0.92, 0.0), TILE)


## Avance jusqu'à ce que le combattant soit dans l'état voulu, et capture aux images d'état demandées.
func _capture_state_frames(ctx: Dictionary, state: int, frames: Array, labels: Array, overlay: MeshInstance3D = null, framing: String = "avant") -> Array:
	var actor: Fighter = ctx["actor"]
	var images := []
	for i in 140:
		await _step()
		if overlay != null:
			overlay.visible = actor.hitbox.is_active()
		if actor.state == state and frames.has(actor.get("_state_frame")):
			images.append(_actor_tile(ctx, framing))
			if images.size() == frames.size():
				break
	if overlay != null:
		overlay.visible = false
	if images.size() != frames.size():
		_fail("%s : %d images capturées sur %d (%s)" % [ctx["who"], images.size(), frames.size(), labels])
	return images


func _capture_animations() -> void:
	for fighter_index in 2:
		var rows := []
		# Attente : respiration (cycle de 96 images).
		var c := await _setup(fighter_index, true, 2.4)
		_hide_visual(c["other"])
		var breath := []
		for k in 3:
			await _steps(4 if k == 0 else 24)
			breath.append(_actor_tile(c))
		rows.append({"label": "Attente en garde (respiration)", "images": breath, "captions": ["inspiration", "mi-souffle", "expiration"]})
		await _teardown(c)
		# Marche avant, marche arrière.
		for forward in [true, false]:
			c = await _setup(fighter_index, true, 4.0 if forward else 2.4)
			_hide_visual(c["other"])
			c["me"].move_axis = c["dir"] * (1.0 if forward else -1.0)
			await _steps(12)
			var walk := []
			for k in 3:
				await _steps(3)
				walk.append(_actor_tile(c))
			rows.append({"label": "Marche avant" if forward else "Marche arrière", "images": walk, "captions": ["pas 1", "pas 2", "pas 3"]})
			await _teardown(c)
		# Attaques : images de préparation, images actives (zone de frappe en rouge) et récupération.
		for heavy in [false, true]:
			c = await _setup(fighter_index, true, 2.4)
			_hide_visual(c["other"])
			var overlay := _show_hitbox(c["actor"])
			var attack: AttackData = c["actor"].heavy_attack if heavy else c["actor"].light_attack
			var s := attack.startup_frames
			var a := attack.active_frames
			var frames := [maxi(1, int(s * 0.4)), int(s * 0.8), s, s + 1, s + a, s + a + int(attack.recovery_frames * 0.5)]
			if heavy:
				c["me"].press_heavy()
			else:
				c["me"].press_light()
			var shots: Array = await _capture_state_frames(c, Fighter.State.ATTACK, frames, ["attaque"], overlay)
			if _failed:
				return
			var names := ["préparation", "préparation", "départ du coup", "actif (1re image)", "actif (dernière)", "récupération"]
			var captions := []
			for k in frames.size():
				captions.append("image %d : %s" % [frames[k], names[k]])
			var title := "Attaque lourde" if heavy else "Attaque légère"
			rows.append({"label": title + " (1/2)", "images": shots.slice(0, 3), "captions": captions.slice(0, 3)})
			rows.append({"label": title + " (2/2) - zone de frappe en rouge quand elle est active", "images": shots.slice(3, 6), "captions": captions.slice(3, 6)})
			await _teardown(c)
		# Coup reçu.
		c = await _setup(fighter_index, true, 0.9)
		c["them"].press_light()
		var hit: Array = await _capture_state_frames(c, Fighter.State.HITSTUN, [1, 5, 11], ["coup reçu"], null, "corps")
		if _failed:
			return
		rows.append({"label": "Coup reçu", "images": hit, "captions": ["image 1 : impact", "image 5 : recul", "image 11 : retour en garde"]})
		await _teardown(c)
		# Esquive.
		c = await _setup(fighter_index, true, 2.4)
		_hide_visual(c["other"])
		c["me"].press_dodge()
		var dodge: Array = await _capture_state_frames(c, Fighter.State.DODGE, [2, 7, 16], ["esquive"], null, "corps")
		if _failed:
			return
		rows.append({"label": "Esquive (invulnérable des images 2 à 14)", "images": dodge, "captions": ["image 2", "image 7", "image 16"]})
		await _teardown(c)
		# Poses tenues : garde, coup bloqué, K.O.
		var held := []
		c = await _setup(fighter_index, true, 2.4)
		_hide_visual(c["other"])
		c["me"].block = true
		await _steps(12)
		held.append(_actor_tile(c))
		await _teardown(c)
		c = await _setup(fighter_index, true, 0.9)
		c["me"].block = true
		await _steps(20)
		c["them"].press_light()
		var blocked: Array = await _capture_state_frames(c, Fighter.State.BLOCKSTUN, [3], ["coup bloqué"], null, "corps")
		if _failed:
			return
		held.append_array(blocked)
		await _teardown(c)
		c = await _setup(fighter_index, true, 0.9)
		c["actor"].health = 5.0
		c["them"].press_light()
		var ko: Array = await _capture_state_frames(c, Fighter.State.KO, [30], ["K.O."], null, "ko")
		if _failed:
			return
		held.append_array(ko)
		await _teardown(c)
		rows.append({"label": "Poses tenues", "images": held, "captions": ["garde (blocage)", "coup bloqué", "K.O."]})
		await _make_rows_planche("%s-animations.jpg" % FIGHTERS[fighter_index], "%s - animations" % FIGHTER_NAMES[fighter_index],
			"Images de combat réelles (60 par seconde). Vignettes à l'échelle 1:1 d'un écran 1080p réduites aux deux tiers.", rows)
	await _sequence_ai_fight()
	await _sequence_strikes_slow()


## Vrai combat : Tandé et Mabé pilotés chacun par l'IA du jeu (graines fixes : combat reproductible).
func _sequence_ai_fight() -> void:
	for folder in ["combat-ia", "combat-ia-video"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join("sequences").path_join(folder))
	var c := await _setup(0, true, 3.0)
	var ai_script: Script = load("res://scripts/ai/ai_controller.gd")
	for pair in [[c["actor"], 11], [c["other"], 20261119]]:
		var ai = ai_script.new()
		ai.rng_seed = pair[1]
		c["m"].add_child(ai)
		ai.reset()
		(pair[0] as Fighter).controller = ai
	var interface := c["m"].get_node("Interface") as CanvasLayer
	interface.visible = true
	(interface.get_node("TouchControls") as CanvasItem).visible = false
	var gif := 0
	var video := 0
	for t in 720:
		await _step()
		if t % 5 == 0:
			var small := _grab()
			small.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			small.save_png(_out.path_join("sequences/combat-ia").path_join("f_%04d.png" % gif))
			gif += 1
		if t % 2 == 0:
			var frame := _grab()
			frame.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			frame.save_png(_out.path_join("sequences/combat-ia-video").path_join("f_%04d.png" % video))
			video += 1
	await _teardown(c)
	_manifest["sequences"].append({"dir": "combat-ia", "fps": 12, "frames": gif,
		"title": "Vrai combat : Tandé contre Mabé, chacun piloté par l'IA du jeu (12 s, vitesse réelle)"})
	_manifest["sequences"].append({"dir": "combat-ia-video", "fps": 30, "frames": video, "format": "mp4",
		"title": "Le même combat en vidéo (30 images/s, plus fluide)"})


## Coups au ralenti (x3), zones de frappe en rouge pendant les images actives.
func _sequence_strikes_slow() -> void:
	var folder := "coups-ralenti"
	DirAccess.make_dir_recursive_absolute(_out.path_join("sequences").path_join(folder))
	var n := 0
	# [qui frappe (0 Tandé, 1 Mabé), lourd ?, l'autre garde ?]
	for spec in [[0, false, false], [1, true, true], [0, true, false], [1, false, false]]:
		var c := await _setup(spec[0], true, 0.9)
		var overlays := [_show_hitbox(c["actor"]), _show_hitbox(c["other"])]
		if spec[2]:
			c["them"].block = true
			await _steps(20)
		if spec[1]:
			c["me"].press_heavy()
		else:
			c["me"].press_light()
		for t in 52:
			await _step()
			(overlays[0] as MeshInstance3D).visible = (c["actor"] as Fighter).hitbox.is_active()
			(overlays[1] as MeshInstance3D).visible = (c["other"] as Fighter).hitbox.is_active()
			var tile := _crop(_grab(), c["m"].camera, _midpoint(c), Vector2i(900, 600))
			tile.resize(600, 400, Image.INTERPOLATE_LANCZOS)
			tile.save_png(_out.path_join("sequences").path_join(folder).path_join("f_%04d.png" % n))
			n += 1
		await _teardown(c)
	_manifest["sequences"].append({"dir": folder, "fps": 20, "frames": n,
		"title": "Coups au ralenti (x3) : légère de Tandé, lourde de Mabé bloquée, lourde de Tandé, légère de Mabé ; zone de frappe en rouge quand elle est active"})


# --- Jeu intégré V0.5.0 (mission 006) -----------------------------------------------------
# Tout est chargé par chemin : ce code ne doit pas empêcher le banc de tourner sur une version
# de référence qui n'a pas encore ces scènes.

func _drive_with_ai(m, ai_script: Script, seed_value: int) -> void:
	var ai = ai_script.new()
	ai.rng_seed = seed_value
	m.add_child(ai)
	ai.reset()
	m.fighter_a.controller = ai


func _save_screen(file: String, title: String) -> void:
	var img := _grab()
	img.save_jpg(_out.path_join("planches").path_join(file), 0.9)
	_manifest["planches"].append({"file": file, "title": title})


func _toggle_visual(game: Node) -> void:
	var toggle = game.match_scene.get_node("Interface/VisualToggle")
	toggle.button().pressed.emit()
	await _steps(4)


func _capture_integration() -> void:
	var settings: Script = load("res://scripts/visual/visual_settings.gd")
	var game_scene: PackedScene = load("res://scenes/main/game.tscn")
	var ai_script: Script = load("res://scripts/ai/ai_controller.gd")
	settings.clear()
	var game = game_scene.instantiate()
	add_child(game)
	await _steps(30)
	_save_screen("jeu-1-demarrage.jpg", "Le jeu au démarrage : pantins animés par défaut, bouton Visuel sous le chronomètre")
	# Pour les captures, Tandé est piloté par une IA de démonstration (en jeu, c'est vous).
	_drive_with_ai(game.match_scene, ai_script, 11)
	await _steps(240)
	_save_screen("jeu-2-combat-pantins.jpg", "Combat en cours avec les pantins animés")
	await _toggle_visual(game)
	_drive_with_ai(game.match_scene, ai_script, 11)
	await _steps(240)
	_save_screen("jeu-3-combat-capsules.jpg", "Après un toucher sur le bouton Visuel : combat neuf avec les capsules historiques")
	await _toggle_visual(game)
	_drive_with_ai(game.match_scene, ai_script, 11)
	game.match_scene.fighter_a.health = 8.0
	for i in 1500:
		await _step()
		if game.match_scene.match_over:
			break
	await _steps(45)
	_save_screen("jeu-4-resultat-pantins.jpg", "Fin de combat avec les pantins : K.O., écran du vainqueur et bouton Rejouer")
	game.queue_free()
	await _steps(2)
	# Séquence : 10 s de jeu intégré, bascule vers les capsules à mi-parcours.
	settings.clear()
	game = game_scene.instantiate()
	add_child(game)
	await _steps(10)
	_drive_with_ai(game.match_scene, ai_script, 11)
	for folder in ["jeu-integre", "jeu-integre-video"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join("sequences").path_join(folder))
	var gif := 0
	var video := 0
	for t in 600:
		if t == 300:
			await _toggle_visual(game)
			_drive_with_ai(game.match_scene, ai_script, 11)
		await _step()
		if t % 5 == 0:
			var small := _grab()
			small.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			small.save_png(_out.path_join("sequences/jeu-integre").path_join("f_%04d.png" % gif))
			gif += 1
		if t % 2 == 0:
			var frame := _grab()
			frame.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			frame.save_png(_out.path_join("sequences/jeu-integre-video").path_join("f_%04d.png" % video))
			video += 1
	game.queue_free()
	settings.clear()
	await _steps(2)
	_manifest["sequences"].append({"dir": "jeu-integre", "fps": 12, "frames": gif,
		"title": "Jeu intégré : 5 s avec les pantins, toucher sur le bouton Visuel, 5 s avec les capsules"})
	_manifest["sequences"].append({"dir": "jeu-integre-video", "fps": 30, "frames": video, "format": "mp4",
		"title": "La même séquence en vidéo (30 images/s)"})
