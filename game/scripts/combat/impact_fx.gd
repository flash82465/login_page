class_name ImpactFx
extends MeshInstance3D
## Effet d'impact provisoire : une sphère lumineuse qui grossit puis disparaît (12 frames).
## Coût minimal sur mobile : maillage et matériaux partagés, pas de transparence, pas d'ombre.

enum Kind { HIT, BLOCK, PARRY }

const LIFETIME_FRAMES := 12

static var _mesh: SphereMesh
static var _materials: Dictionary = {}

var _frame: int = 0
var _max_scale: float = 1.0


static func spawn(parent: Node, at: Vector3, kind: Kind, strength: float) -> ImpactFx:
	var fx := ImpactFx.new()
	fx.mesh = _shared_mesh()
	fx.material_override = _shared_material(kind)
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx._max_scale = 1.0 + strength
	fx.add_to_group(&"impact_fx")
	parent.add_child(fx)
	fx.global_position = at
	fx.scale = Vector3.ONE * 0.3
	return fx


func _physics_process(_delta: float) -> void:
	_frame += 1
	var t := float(_frame) / LIFETIME_FRAMES
	scale = Vector3.ONE * maxf(0.05, _max_scale * sin(PI * t))
	if _frame >= LIFETIME_FRAMES:
		queue_free()


static func _shared_mesh() -> SphereMesh:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.12
		_mesh.height = 0.24
		_mesh.radial_segments = 12
		_mesh.rings = 6
	return _mesh


static func _shared_material(kind: Kind) -> StandardMaterial3D:
	if not _materials.has(kind):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		match kind:
			Kind.BLOCK:
				material.albedo_color = Color(0.45, 0.75, 1.0)
			Kind.PARRY:
				material.albedo_color = Color(1.0, 1.0, 0.85)
			_:
				material.albedo_color = Color(1.0, 0.55, 0.15)
		_materials[kind] = material
	return _materials[kind]
