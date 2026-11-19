extends Node3D
## Repères visuels au sol et piliers de fond : sans eux, le sol uni ne permet pas de voir
## qu'un combattant s'est déplacé quand la caméra le suit (diagnostic mission 003).
## Deux MultiMesh seulement : 2 appels de dessin, quel que soit le nombre de repères.

@export var half_width: float = 8.0
@export var line_spacing: float = 1.0
@export var pillar_spacing: float = 4.0


func _ready() -> void:
	_add_lines()
	_add_pillars()


func _add_lines() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.01, 3.0)
	mesh.material = _material(Color(0.36, 0.25, 0.16))
	var count := int(half_width * 2.0 / line_spacing) + 1
	var multimesh := _multimesh(mesh, count)
	for i in count:
		var x := -half_width + i * line_spacing
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 0.006, 0.0)))
	_instance(multimesh)


func _add_pillars() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 3.0, 0.35)
	mesh.material = _material(Color(0.42, 0.3, 0.2))
	var count := int(half_width * 2.0 / pillar_spacing) + 1
	var multimesh := _multimesh(mesh, count)
	for i in count:
		var x := -half_width + i * pillar_spacing
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 1.5, -3.2)))
	_instance(multimesh)


func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _instance(multimesh: MultiMesh) -> void:
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	add_child(node)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
