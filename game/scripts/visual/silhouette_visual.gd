class_name SilhouetteVisual
extends FighterVisual
## Génération visuelle « silhouette » (mission 005, étape 2).
##
## Pantin vu de profil : 14 os effilés (rayon différent à chaque bout) qui se fondent en une
## silhouette continue, couleur de terre très sombre, liseré discret de contre-jour, pièces de
## costume décoratives et Marques des Pactes ocre. Les données viennent de SilhouetteProfiles.
## Étape 2 : deux poses fixes, « attente » et « garde » (pendant un blocage) ; les animations
## viendront à l'étape 3.
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

@export var character: StringName = &"tande"

var _profile: Dictionary = {}
var _rig: Node3D
var _bone_nodes := {}
var _info := {}
var _fk := {}
var _joints := {}
var _joint_layer := {}
var _ground: float = 0.0
var _pose: StringName = &""
var _materials: Array[ShaderMaterial] = []
var _flash_frames: int = 0
var _flash_color: Color = Color(1.0, 0.3, 0.25)
var _shown_flash: float = -1.0


func _ready() -> void:
	_build()
	_apply_pose(&"attente")


func update_visual(fighter: Fighter) -> void:
	if _profile.is_empty():
		return
	var wanted: StringName = &"garde" if fighter.is_blocking() else &"attente"
	if wanted != _pose:
		_apply_pose(wanted)
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

func current_pose() -> StringName:
	return _pose


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
	var reference: PackedVector2Array = _profile["poses"][&"attente"]
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
		_add_mesh(_bone_nodes[piece["bone"]], _prism(local, piece["thickness"]), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z)), _material(piece["color"], true))
	var mark_material := _material(_profile["mark"], false)
	for mark in _profile["marks"]:
		var a := _to_bone_local(mark["bone"], mark["a"])
		var b := _to_bone_local(mark["bone"], mark["b"])
		var r: Vector2 = radii[mark["bone"]]
		var t := Transform3D(Basis(Vector3.BACK, (b - a).angle() - PI / 2.0), Vector3(a.x, a.y, (r.x + r.y) * 0.5 + 0.006))
		_add_mesh(_bone_nodes[mark["bone"]], _tapered_capsule(MARK_RADIUS, MARK_RADIUS, a.distance_to(b)), t, mark_material)


func _apply_pose(pose_name: StringName) -> void:
	var points: PackedVector2Array = _profile["poses"][pose_name]
	for bone_def in BONES:
		var bone: StringName = bone_def[0]
		var info: Dictionary = _info[bone]
		var angle := (points[info["to"]] - points[info["from"]]).angle()
		var start: Vector2 = points[info["from"]]
		if bone_def[3] != &"":
			var parent: Dictionary = _fk[bone_def[3]]
			var parent_start: Vector2 = parent["start"]
			var anchor: Vector2 = info["anchor"]
			start = parent_start + anchor.rotated(float(parent["angle"]))
		var end := start + Vector2(float(info["length"]), 0.0).rotated(angle)
		_fk[bone] = {"start": start, "end": end, "angle": angle}
		_joints[bone_def[1]] = start
		_joints[bone_def[2]] = end
	_ground = -_lowest()
	for bone_def in BONES:
		var fk: Dictionary = _fk[bone_def[0]]
		var start: Vector2 = fk["start"]
		var node: Node3D = _bone_nodes[bone_def[0]]
		node.position = Vector3(start.x, start.y + _ground, LAYER_Z[bone_def[4]])
		node.rotation = Vector3(0.0, 0.0, float(fk["angle"]) - PI / 2.0)
	_pose = pose_name


## Point le plus bas des jambes et des pieds, avant la correction de hauteur.
func _lowest() -> float:
	var low := INF
	var radii: Dictionary = _profile["radii"]
	for bone in FEET:
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
