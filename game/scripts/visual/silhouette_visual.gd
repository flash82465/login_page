class_name SilhouetteVisual
extends FighterVisual
## Génération visuelle « silhouette » (mission 005, étape 2).
##
## Pantin vu de profil : 14 os effilés (rayon différent à chaque bout) qui se fondent en une
## silhouette continue, couleur de terre très sombre, liseré discret de contre-jour, pièces de
## costume décoratives et Marques des Pactes ocre. Les données viennent de SilhouetteProfiles.
## Étape 3 : animations pilotées par l'état du combattant et par les images de combat :
## attente (respiration), marche avant et arrière (pieds posés), attaques légère et lourde (calées
## sur préparation, images actives et récupération), coup reçu, esquive ; poses tenues pour la garde,
## le coup bloqué et le K.O. Les poses-clés viennent de SilhouetteProfiles ; entre deux poses, le
## pantin interpole les angles des os, puis place les jambes par cinématique inverse (pieds posés).
## Tout dépend uniquement des images de logique : même combat, même animation (déterminisme).
##
## Le visuel ne décide de rien : il lit l'état du combattant. Les zones de touche ne changent pas.
## Miroir 2D : quand le combattant se retourne, le pantin est en plus symétrisé en profondeur,
## si bien que le bras avant reste devant, comme l'image retournée d'un jeu de combat 2D.

const SHADER := preload("res://assets/visual/silhouette.gdshader")
const JOINTS: Array[StringName] = [
	&"hips", &"waist", &"chest", &"neck", &"head",
	&"shoulder_n", &"elbow_n", &"wrist_n", &"shoulder_f", &"elbow_f", &"wrist_f",
	&"hip_n", &"knee_n", &"ankle_n", &"toe_n", &"hip_f", &"knee_f", &"ankle_f", &"toe_f",
]
## Os : nom, articulation de départ, d'arrivée, os parent, couche (c = centre, n = près, f = loin).
## Les parents précèdent toujours leurs enfants.
const BONES := [
	[&"belly", &"hips", &"waist", &"", &"c"],
	[&"chest", &"waist", &"chest", &"belly", &"c"],
	[&"neck", &"chest", &"neck", &"chest", &"c"],
	[&"head", &"neck", &"head", &"neck", &"c"],
	[&"upper_arm_n", &"shoulder_n", &"elbow_n", &"chest", &"n"],
	[&"forearm_n", &"elbow_n", &"wrist_n", &"upper_arm_n", &"n"],
	[&"upper_arm_f", &"shoulder_f", &"elbow_f", &"chest", &"f"],
	[&"forearm_f", &"elbow_f", &"wrist_f", &"upper_arm_f", &"f"],
	[&"thigh_n", &"hip_n", &"knee_n", &"belly", &"n"],
	[&"shin_n", &"knee_n", &"ankle_n", &"thigh_n", &"n"],
	[&"foot_n", &"ankle_n", &"toe_n", &"shin_n", &"n"],
	[&"thigh_f", &"hip_f", &"knee_f", &"belly", &"f"],
	[&"shin_f", &"knee_f", &"ankle_f", &"thigh_f", &"f"],
	[&"foot_f", &"ankle_f", &"toe_f", &"shin_f", &"f"],
]
const LAYER_Z := {&"c": 0.0, &"n": 0.075, &"f": -0.075}
const FEET: Array[StringName] = [&"shin_n", &"foot_n", &"shin_f", &"foot_f"]
const RADIAL_SEGMENTS := 14
const CAP_RINGS := 4
const FLASH_AMOUNT := 0.55
const MARK_RADIUS := 0.0075
## Durée des fondus (images) en entrant dans chaque animation.
const BLEND_FRAMES := {&"locomotion": 5, &"garde": 4, &"coup_bloque": 3, &"legere": 3, &"lourde": 3, &"recul": 4, &"esquive": 3, &"ko": 26}
## Calage au sol : « sol » (pieds posés), « libre » (petit saut de l'esquive), « allonge » (corps au sol).
const GROUND_MODE := {&"esquive": &"libre", &"ko": &"allonge"}
const BREATH_PERIOD := 96
## Part du chemin vers le coup atteinte à la dernière image de préparation.
const STRIKE_LEAD := 0.8
const LEGS := {&"n": [8, 9, 10], &"f": [11, 12, 13]}

@export var character: StringName = &"tande"

var _profile: Dictionary = {}
var _rig: Node3D
var _bone_nodes := {}
var _info := {}
var _fk := {}
var _joints := {}
var _joint_layer := {}
var _ground: float = 0.0
var _keys := {}
var _walk := {}
var _anim: StringName = &""
var _shown := {}
var _blend_from := {}
var _blend_total: int = 0
var _blend_left: int = 0
var _tick: int = 0
var _walk_distance: float = 0.0
var _walk_weight: float = 0.0
var _last_x: float = NAN
var _planted := {&"n": false, &"f": false}
var _materials: Array[ShaderMaterial] = []
var _flash_frames: int = 0
var _flash_color: Color = Color(1.0, 0.3, 0.25)
var _shown_flash: float = -1.0


func _ready() -> void:
	_build()
	if not _profile.is_empty():
		_display(_solved(_keys[&"attente"]), &"sol")


func update_visual(fighter: Fighter) -> void:
	if _profile.is_empty():
		return
	_tick += 1
	_track_walk(fighter)
	var anim := _animation_for(fighter)
	if anim != _anim:
		_blend_from = _shown.duplicate(true)
		_blend_total = BLEND_FRAMES.get(anim, 3)
		_blend_left = _blend_total if not _blend_from.is_empty() else 0
		_anim = anim
	var target := _sample(anim, fighter)
	if _blend_left > 0:
		_blend_left -= 1
		var w := 1.0 - float(_blend_left) / _blend_total
		w = w * w if anim == &"ko" else smoothstep(0.0, 1.0, w)
		target = _mix(_blend_from, target, w)
	_display(target, GROUND_MODE.get(anim, &"sol"))
	_rig.scale.z = 1.0 if fighter.facing >= 0.0 else -1.0
	var amount := 0.0
	if _flash_frames > 0:
		_flash_frames -= 1
		amount = FLASH_AMOUNT
	if amount != _shown_flash:
		_shown_flash = amount
		for m in _materials:
			m.set_shader_parameter(&"flash_amount", amount)
			m.set_shader_parameter(&"flash_color", _flash_color)


func flash(color: Color, frames: int) -> void:
	_flash_color = color
	_flash_frames = frames
	_shown_flash = -1.0


func reset_visual() -> void:
	_flash_frames = 0


# --- Mesures (tests et banc de capture) ---------------------------------------------------

## Pose affichée : « attente » (attente et marche), « garde », sinon le nom de l'animation.
func current_pose() -> StringName:
	return &"attente" if _anim == &"locomotion" or _anim == &"" else _anim


func current_animation() -> StringName:
	return _anim


## Articulation dans le repère du pantin (avant symétrie), hauteur au-dessus du sol.
func joint_local(joint: StringName) -> Vector2:
	var p: Vector2 = _joints[joint]
	return p + Vector2(0.0, _ground)


## Angles des 14 os affichés (radians), dans l'ordre de BONES.
func bone_angles() -> PackedFloat64Array:
	return _shown["angles"] if not _shown.is_empty() else PackedFloat64Array()


## Pendant la marche établie : vrai si le pied (&"n" avant, &"f" arrière) est en appui au sol.
func foot_planted(side: StringName) -> bool:
	return bool(_planted[side])


## Position globale d'une articulation, à la profondeur de sa couche.
func joint_global(joint: StringName) -> Vector3:
	var p: Vector2 = _joints[joint]
	return _rig.to_global(Vector3(p.x, p.y + _ground, float(_joint_layer[joint])))


## Hauteur globale du point le plus bas des pieds (sol de l'arène : 0).
func lowest_point_global() -> float:
	return _rig.to_global(Vector3(0.0, _lowest() + _ground, 0.0)).y


## Largeur divisée par la hauteur de la silhouette entière (costume compris), dans la pose courante.
func extent_ratio() -> float:
	var pts := _outline_points()
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	return (max_x - min_x) / (max_y - minf(0.0, min_y))


# --- Construction du pantin ----------------------------------------------------------------

func _build() -> void:
	_profile = SilhouetteProfiles.get_profile(character)
	if _profile.is_empty():
		push_error("Silhouette inconnue : %s" % character)
		return
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var body := _material(_profile["body"], true)
	var far := _material(_profile["far"], true)
	var reference: PackedVector2Array = _profile["reference"]
	var radii: Dictionary = _profile["radii"]
	for bone_def in BONES:
		var bone: StringName = bone_def[0]
		var from := JOINTS.find(bone_def[1])
		var to := JOINTS.find(bone_def[2])
		var start: Vector2 = reference[from]
		var end: Vector2 = reference[to]
		var info := {
			"from": from, "to": to, "start": start, "angle": (end - start).angle(),
			"length": start.distance_to(end), "parent": bone_def[3], "layer": bone_def[4],
		}
		if bone_def[3] != &"":
			var parent: Dictionary = _info[bone_def[3]]
			var parent_start: Vector2 = parent["start"]
			info["anchor"] = (start - parent_start).rotated(-float(parent["angle"]))
		_info[bone] = info
		_joint_layer[bone_def[1]] = LAYER_Z[bone_def[4]]
		_joint_layer[bone_def[2]] = LAYER_Z[bone_def[4]]
		var node := Node3D.new()
		node.name = String(bone)
		_rig.add_child(node)
		_bone_nodes[bone] = node
		var material := far if bone_def[4] == &"f" else body
		var length: float = info["length"]
		if bone == &"head":
			_add_sphere(node, Vector3(0.0, length, 0.0), _profile["head_radius"], 1.1, material)
		else:
			var r: Vector2 = radii[bone]
			_add_mesh(node, _tapered_capsule(r.x, r.y, length), Transform3D.IDENTITY, material)
		if bone == &"forearm_n" or bone == &"forearm_f":
			_add_sphere(node, Vector3(0.0, length, 0.0), _profile["fist_radius"], 1.0, material)
	for extra in _profile["extra"]:
		var a := _to_bone_local(extra["bone"], extra["a"])
		var b := _to_bone_local(extra["bone"], extra["b"])
		var z := float(extra["z"]) - _bone_z(extra["bone"])
		var t := Transform3D(Basis(Vector3.BACK, (b - a).angle() - PI / 2.0), Vector3(a.x, a.y, z))
		_add_mesh(_bone_nodes[extra["bone"]], _tapered_capsule(extra["r0"], extra["r1"], a.distance_to(b)), t, body)
	for piece in _profile["costume"]:
		var local := PackedVector2Array()
		for p in piece["polygon"]:
			local.append(_to_bone_local(piece["bone"], p))
		var z := float(piece["z"]) - _bone_z(piece["bone"])
		# Pas de liseré sur les pièces plates : vues de profil, leur tranche donnerait un pointillé lumineux.
		_add_mesh(_bone_nodes[piece["bone"]], _prism(local, piece["thickness"]), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z)), _material(piece["color"], false))
	for volume in _profile["volumes"]:
		var owner_bone: StringName = volume["bone"]
		var z := float(volume["z"]) - _bone_z(owner_bone)
		var material := _material(volume["color"], false)
		if volume["kind"] == &"jupe":
			_add_mesh(_bone_nodes[owner_bone], _skirt(owner_bone, volume["rings"], z), Transform3D.IDENTITY, material)
		else:
			var center := _to_bone_local(owner_bone, volume["center"])
			var axes: Vector3 = volume["radii"]
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 16
			sphere.rings = 8
			# Demi-axes donnés dans la pose de référence : on annule la rotation du nœud de l'os.
			var turn := Basis(Vector3.BACK, -(float(_info[owner_bone]["angle"]) - PI / 2.0))
			_add_mesh(_bone_nodes[owner_bone], sphere, Transform3D(turn * Basis.from_scale(axes), Vector3(center.x, center.y, z)), material)
	for name in _profile["keys"]:
		var key: Dictionary = _profile["keys"][name]
		_keys[name] = _key_from_points(key["points"], key["ik"])
	_walk = _profile["walk"]
	var mark_material := _material(_profile["mark"], false)
	for mark in _profile["marks"]:
		var a := _to_bone_local(mark["bone"], mark["a"])
		var b := _to_bone_local(mark["bone"], mark["b"])
		var r: Vector2 = radii[mark["bone"]]
		# Profondeur : à la surface de l'os, ou imposée (Marque devant une autre pièce, comme la nuque de Mabé).
		var z := (r.x + r.y) * 0.5 + 0.006
		if mark.has("z"):
			z = float(mark["z"]) - _bone_z(mark["bone"])
		var t := Transform3D(Basis(Vector3.BACK, (b - a).angle() - PI / 2.0), Vector3(a.x, a.y, z))
		_add_mesh(_bone_nodes[mark["bone"]], _tapered_capsule(MARK_RADIUS, MARK_RADIUS, a.distance_to(b)), t, mark_material)


# --- Animation ----------------------------------------------------------------------------

func _animation_for(fighter: Fighter) -> StringName:
	match fighter.state:
		Fighter.State.BLOCK:
			return &"garde"
		Fighter.State.BLOCKSTUN:
			return &"coup_bloque"
		Fighter.State.ATTACK:
			return &"lourde" if fighter.current_attack != null and fighter.current_attack == fighter.heavy_attack else &"legere"
		Fighter.State.HITSTUN:
			return &"recul"
		Fighter.State.DODGE:
			return &"esquive"
		Fighter.State.KO:
			return &"ko"
	return &"locomotion"


func _sample(anim: StringName, fighter: Fighter) -> Dictionary:
	var frame := fighter.get_state_frame()
	var rest: Dictionary = _keys[&"attente"]
	match anim:
		&"garde":
			return _solved(_keys[&"garde"])
		&"coup_bloque":
			if frame <= 3:
				return _solved(_mix(_keys[&"garde"], _keys[&"garde_recul"], _ease_out(frame / 3.0)))
			if frame <= 9:
				return _solved(_mix(_keys[&"garde_recul"], _keys[&"garde"], smoothstep(0.0, 1.0, (frame - 3) / 6.0)))
			return _solved(_keys[&"garde"])
		&"legere":
			return _attack(fighter, frame, &"legere_armee", &"legere_frappe")
		&"lourde":
			return _attack(fighter, frame, &"lourde_armee", &"lourde_frappe")
		&"recul":
			if frame <= 3:
				return _solved(_keys[&"recul"])
			if frame <= 12:
				return _solved(_mix(_keys[&"recul"], rest, smoothstep(0.0, 1.0, (frame - 3) / 9.0)))
			return _solved(rest)
		&"esquive":
			if frame <= 4:
				return _solved(_mix(rest, _keys[&"esquive"], _ease_out(frame / 4.0)))
			if frame <= 13:
				return _solved(_keys[&"esquive"])
			return _solved(_mix(_keys[&"esquive"], rest, smoothstep(0.0, 1.0, minf(1.0, (frame - 13) / 7.0))))
		&"ko":
			return _solved(_keys[&"ko"])
	return _locomotion()


## Attaque calée sur les images de combat : préparation (attente puis armé, puis départ du coup),
## coup pleinement porté pendant toutes les images actives, retour à l'attente pendant la récupération.
func _attack(fighter: Fighter, frame: int, armed_key: StringName, strike_key: StringName) -> Dictionary:
	var rest: Dictionary = _keys[&"attente"]
	var attack := fighter.current_attack
	if attack == null:
		return _solved(rest)
	var startup := attack.startup_frames
	var active := attack.active_frames
	var armed: Dictionary = _keys[armed_key]
	var strike: Dictionary = _keys[strike_key]
	if frame <= startup:
		var t := float(frame) / startup
		if t <= 0.5:
			return _solved(_mix(rest, armed, smoothstep(0.0, 1.0, t / 0.5)))
		var u := (t - 0.5) / 0.5
		return _solved(_mix(armed, strike, STRIKE_LEAD * u * u))
	if frame <= startup + active:
		return _solved(strike)
	return _solved(_mix(strike, rest, smoothstep(0.0, 1.0, float(frame - startup - active) / attack.recovery_frames)))


## Attente et marche : respiration, puis pas chassés pieds posés quand le combattant se déplace.
## La phase des pas suit la distance parcourue : un pied en appui reste exactement fixe au sol.
func _locomotion() -> Dictionary:
	var breath := 0.5 - 0.5 * cos(TAU * float(_tick % BREATH_PERIOD) / BREATH_PERIOD)
	var s := _mix(_keys[&"attente"], _keys[&"inspire"], breath)
	_planted[&"n"] = false
	_planted[&"f"] = false
	if _walk_weight > 0.0:
		var cycle: float = _walk["cycle"]
		var phase := _walk_distance / cycle
		for side: StringName in [&"n", &"f"]:
			var o := _foot_offset(phase + (0.0 if side == &"n" else 0.5))
			var ankle: Vector2 = s["ankle_" + side]
			s["ankle_" + side] = ankle + Vector2(o.x, o.y) * _walk_weight
			if o.z >= 0.0:
				s["foot_" + side] = float(s["foot_" + side]) - deg_to_rad(15.0) * sin(PI * o.z) * _walk_weight
			_planted[side] = o.z < 0.0 and _walk_weight >= 1.0
		var hips: Vector2 = s["hips"]
		s["hips"] = hips - Vector2(0.0, float(_walk["bob"]) * _walk_weight * (0.5 + 0.5 * cos(2.0 * TAU * phase)))
	return _solved(s)


## Décalage d'un pied pour une phase de marche : x (avant), y (levée), z (progression du vol, -1 en appui).
func _foot_offset(phase: float) -> Vector3:
	var cycle: float = _walk["cycle"]
	var q := fposmod(phase, 1.0)
	if q < 0.5:
		return Vector3(cycle * 0.25 - q * cycle, 0.0, -1.0)
	var s := (q - 0.5) * 2.0
	var e := s * s * (3.0 - 2.0 * s)
	return Vector3(-cycle * 0.25 + e * cycle * 0.5, float(_walk["lift"]) * sin(PI * s), s)


func _track_walk(fighter: Fighter) -> void:
	var x := fighter.global_position.x
	if not is_nan(_last_x):
		_walk_distance += (x - _last_x) * fighter.facing
	_last_x = x
	var moving := fighter.state == Fighter.State.IDLE or fighter.state == Fighter.State.WALK
	var target := clampf(absf(fighter.velocity.x) / 1.2, 0.0, 1.0) if moving else 0.0
	_walk_weight = move_toward(_walk_weight, target, 0.2)


func _key_from_points(points: PackedVector2Array, ik: bool) -> Dictionary:
	var angles := PackedFloat64Array()
	for bone_def in BONES:
		var info: Dictionary = _info[bone_def[0]]
		angles.append((points[info["to"]] - points[info["from"]]).angle())
	return {
		"hips": points[0], "angles": angles, "ik": ik,
		"ankle_n": points[13], "ankle_f": points[17],
		"foot_n": (points[14] - points[13]).angle(), "foot_f": (points[18] - points[17]).angle(),
	}


func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var angles := PackedFloat64Array()
	var aa: PackedFloat64Array = a["angles"]
	var ba: PackedFloat64Array = b["angles"]
	for i in aa.size():
		angles.append(lerp_angle(aa[i], ba[i], t))
	var hips_a: Vector2 = a["hips"]
	var hips_b: Vector2 = b["hips"]
	var out := {"hips": hips_a.lerp(hips_b, t), "angles": angles, "ik": bool(a.get("ik", false)) and bool(b.get("ik", false))}
	if a.has("ankle_n") and b.has("ankle_n"):
		for side in ["n", "f"]:
			var ankle_a: Vector2 = a["ankle_" + side]
			var ankle_b: Vector2 = b["ankle_" + side]
			out["ankle_" + side] = ankle_a.lerp(ankle_b, t)
			out["foot_" + side] = lerp_angle(float(a["foot_" + side]), float(b["foot_" + side]), t)
	return out


## Pose finale : jambes placées par cinématique inverse vers les chevilles visées (genou vers l'avant).
func _solved(sample: Dictionary) -> Dictionary:
	var s := sample.duplicate(true)
	if not bool(s.get("ik", false)):
		return s
	var angles: PackedFloat64Array = s["angles"]
	var hips: Vector2 = s["hips"]
	for side: StringName in LEGS:
		var ids: Array = LEGS[side]
		var thigh: Dictionary = _info[BONES[ids[0]][0]]
		var shin: Dictionary = _info[BONES[ids[1]][0]]
		var thigh_anchor: Vector2 = thigh["anchor"]
		var hip := hips + thigh_anchor.rotated(angles[0])
		var target: Vector2 = s["ankle_" + side]
		var l1: float = thigh["length"]
		var l2: float = shin["length"]
		var d := clampf(hip.distance_to(target), absf(l1 - l2) + 0.0001, l1 + l2 - 0.0001)
		var bend := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
		var thigh_angle := (target - hip).angle() + bend
		var knee := hip + Vector2(l1, 0.0).rotated(thigh_angle)
		angles[ids[0]] = thigh_angle
		angles[ids[1]] = (target - knee).angle()
		angles[ids[2]] = float(s["foot_" + side])
	s["angles"] = angles
	s["ik"] = false
	return s


## Applique une pose finale : chaîne des os, calage au sol, transformations des nœuds.
func _display(sample: Dictionary, ground: StringName) -> void:
	var angles: PackedFloat64Array = sample["angles"]
	for i in BONES.size():
		var bone_def: Array = BONES[i]
		var bone: StringName = bone_def[0]
		var info: Dictionary = _info[bone]
		var angle := angles[i]
		var start: Vector2 = sample["hips"]
		if bone_def[3] != &"":
			var parent: Dictionary = _fk[bone_def[3]]
			var parent_start: Vector2 = parent["start"]
			var anchor: Vector2 = info["anchor"]
			start = parent_start + anchor.rotated(float(parent["angle"]))
		var end := start + Vector2(float(info["length"]), 0.0).rotated(angle)
		_fk[bone] = {"start": start, "end": end, "angle": angle}
		_joints[bone_def[1]] = start
		_joints[bone_def[2]] = end
	match ground:
		&"libre":
			_ground = 0.0
		&"allonge":
			_ground = maxf(0.0, -_lowest(true))
		_:
			_ground = -_lowest(false)
	for bone_def in BONES:
		var fk: Dictionary = _fk[bone_def[0]]
		var start: Vector2 = fk["start"]
		var node: Node3D = _bone_nodes[bone_def[0]]
		node.position = Vector3(start.x, start.y + _ground, LAYER_Z[bone_def[4]])
		node.rotation = Vector3(0.0, 0.0, float(fk["angle"]) - PI / 2.0)
	_shown = sample


func _ease_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## Point le plus bas des jambes et des pieds (ou du corps entier), avant la correction de hauteur.
func _lowest(whole_body: bool = false) -> float:
	var low := INF
	var radii: Dictionary = _profile["radii"]
	var bones: Array = FEET
	if whole_body:
		bones = []
		for bone_def in BONES:
			bones.append(bone_def[0])
	for bone in bones:
		var fk: Dictionary = _fk[bone]
		var r: Vector2 = radii[bone]
		var start: Vector2 = fk["start"]
		var end: Vector2 = fk["end"]
		low = minf(low, minf(start.y - r.x, end.y - r.y))
	return low


func _outline_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var lift := Vector2(0.0, _ground)
	var radii: Dictionary = _profile["radii"]
	for bone_def in BONES:
		var fk: Dictionary = _fk[bone_def[0]]
		var r: Vector2 = radii[bone_def[0]]
		pts.append_array(_disc(fk["start"] + lift, r.x))
		pts.append_array(_disc(fk["end"] + lift, r.y))
	pts.append_array(_disc(_fk[&"head"]["end"] + lift, _profile["head_radius"]))
	pts.append_array(_disc(_fk[&"forearm_n"]["end"] + lift, _profile["fist_radius"]))
	pts.append_array(_disc(_fk[&"forearm_f"]["end"] + lift, _profile["fist_radius"]))
	for piece in _profile["costume"]:
		for p in piece["polygon"]:
			pts.append(_follow_bone(piece["bone"], p) + lift)
	for extra in _profile["extra"]:
		pts.append_array(_disc(_follow_bone(extra["bone"], extra["a"]) + lift, extra["r0"]))
		pts.append_array(_disc(_follow_bone(extra["bone"], extra["b"]) + lift, extra["r1"]))
	for volume in _profile["volumes"]:
		if volume["kind"] == &"jupe":
			for ring: Vector4 in volume["rings"]:
				pts.append(_follow_bone(volume["bone"], Vector2(ring.y, ring.x)) + lift)
				pts.append(_follow_bone(volume["bone"], Vector2(ring.z, ring.x)) + lift)
		else:
			var axes: Vector3 = volume["radii"]
			var c := _follow_bone(volume["bone"], volume["center"]) + lift
			pts.append_array(PackedVector2Array([c + Vector2(-axes.x, 0.0), c + Vector2(axes.x, 0.0), c + Vector2(0.0, axes.y)]))
	return pts


## Points extrêmes (gauche, droite, haut) d'un disque.
func _disc(p: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(-r, 0.0), p + Vector2(r, 0.0), p + Vector2(0.0, r)])


## Point décrit dans la pose de référence, déplacé avec son os dans la pose courante.
func _follow_bone(bone: StringName, p: Vector2) -> Vector2:
	var info: Dictionary = _info[bone]
	var fk: Dictionary = _fk[bone]
	var ref_start: Vector2 = info["start"]
	var start: Vector2 = fk["start"]
	return start + (p - ref_start).rotated(float(fk["angle"]) - float(info["angle"]))


## Coordonnées d'un point de la pose de référence dans le repère du nœud de son os (+Y le long de l'os).
func _to_bone_local(bone: StringName, p: Vector2) -> Vector2:
	var info: Dictionary = _info[bone]
	return Transform2D(float(info["angle"]) - PI / 2.0, info["start"]).affine_inverse() * p


func _bone_z(bone: StringName) -> float:
	return LAYER_Z[_info[bone]["layer"]]


func _material(color: Color, rim: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"body_color", color)
	m.set_shader_parameter(&"rim_color", _profile["rim"])
	m.set_shader_parameter(&"rim_strength", float(_profile["rim_strength"]) if rim else 0.0)
	_materials.append(m)
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, t: Transform3D, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = t
	mi.material_override = material
	parent.add_child(mi)


func _add_sphere(parent: Node3D, at: Vector3, radius: float, stretch: float, material: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0 * stretch
	sphere.radial_segments = 16
	sphere.rings = 8
	_add_mesh(parent, sphere, Transform3D(Basis.IDENTITY, at), material)


## Capsule effilée le long de +Y, de y = 0 (rayon r0) à y = length (rayon r1).
static func _tapered_capsule(r0: float, r1: float, length: float) -> ArrayMesh:
	var profile: Array[Vector4] = []
	for i in CAP_RINGS + 1:
		var a := -PI / 2.0 + PI / 2.0 * float(i) / CAP_RINGS
		profile.append(Vector4(r0 * cos(a), r0 * sin(a), cos(a), sin(a)))
	for i in CAP_RINGS + 1:
		var a := PI / 2.0 * float(i) / CAP_RINGS
		profile.append(Vector4(r1 * cos(a), length + r1 * sin(a), cos(a), sin(a)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in profile.size() - 1:
		for j in RADIAL_SEGMENTS:
			var t0 := TAU * float(j) / RADIAL_SEGMENTS
			var t1 := TAU * float(j + 1) / RADIAL_SEGMENTS
			_ring_vertex(st, profile[k], t0)
			_ring_vertex(st, profile[k], t1)
			_ring_vertex(st, profile[k + 1], t1)
			_ring_vertex(st, profile[k], t0)
			_ring_vertex(st, profile[k + 1], t1)
			_ring_vertex(st, profile[k + 1], t0)
	return st.commit()


static func _ring_vertex(st: SurfaceTool, p: Vector4, t: float) -> void:
	st.set_normal(Vector3(p.z * cos(t), p.w, p.z * sin(t)).normalized())
	st.add_vertex(Vector3(p.x * cos(t), p.y, p.x * sin(t)))


## Jupe : anneaux elliptiques (hauteur, bord arrière, bord avant, demi-profondeur) décrits dans la
## pose de référence, reliés en un volume centré sur le corps.
func _skirt(bone: StringName, rings: Array, z: float) -> ArrayMesh:
	var loops: Array[PackedVector3Array] = []
	for ring: Vector4 in rings:
		var loop := PackedVector3Array()
		var cx := (ring.y + ring.z) * 0.5
		var hx := (ring.z - ring.y) * 0.5
		for j in RADIAL_SEGMENTS + 1:
			var t := TAU * float(j) / RADIAL_SEGMENTS
			var p := _to_bone_local(bone, Vector2(cx + hx * cos(t), ring.x))
			loop.append(Vector3(p.x, p.y, z + ring.w * sin(t)))
		loops.append(loop)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in loops.size() - 1:
		var a := loops[k]
		var b := loops[k + 1]
		for j in RADIAL_SEGMENTS:
			for v in [a[j], a[j + 1], b[j + 1], a[j], b[j + 1], b[j]]:
				st.set_normal(Vector3.BACK)
				st.add_vertex(v)
	return st.commit()


## Pièce plate (costume) : contour extrudé sur l'épaisseur donnée, centré en z = 0.
static func _prism(polygon: PackedVector2Array, thickness: float) -> ArrayMesh:
	var indices := Geometry2D.triangulate_polygon(polygon)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thickness * 0.5
	for side: float in [1.0, -1.0]:
		for i in indices:
			st.set_normal(Vector3(0.0, 0.0, side))
			st.add_vertex(Vector3(polygon[i].x, polygon[i].y, h * side))
	var count := polygon.size()
	for i in count:
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		var n := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		for v in [Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h)]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()
