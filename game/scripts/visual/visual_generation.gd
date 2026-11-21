class_name VisualGeneration
extends Resource
## Génération visuelle complète d'un combat (mission 005) : visuel de chaque combattant et
## ambiance de l'arène (fond, lumière ambiante, sol). Seul l'aspect change : ni la scène de
## l'arène, ni ses collisions, ni la logique des combattants ne sont modifiées.

@export var label: String = ""
@export var fighter_a_visual: PackedScene
@export var fighter_b_visual: PackedScene
## Vide : ambiance d'origine de l'arène.
@export var environment: Environment
## Vide : sol d'origine.
@export var floor_material: Material
## Couleur des piliers du décor ; transparente : couleur d'origine.
@export var pillar_color: Color = Color(0, 0, 0, 0)


## À appeler sur la scène de combat avant son entrée dans l'arbre.
func apply_to(main: Node) -> void:
	var a := main.get_node_or_null("Fighters/FighterA") as Fighter
	var b := main.get_node_or_null("Fighters/FighterB") as Fighter
	if a != null and fighter_a_visual != null:
		a.visual_scene = fighter_a_visual
	if b != null and fighter_b_visual != null:
		b.visual_scene = fighter_b_visual
	if environment != null:
		var world := main.get_node_or_null("Arena/WorldEnvironment") as WorldEnvironment
		if world != null:
			world.environment = environment
	if floor_material != null:
		var ground := main.get_node_or_null("Arena/Floor/Mesh") as MeshInstance3D
		if ground != null:
			ground.material_override = floor_material
	var arena := main.get_node_or_null("Arena")
	if arena != null and pillar_color.a > 0.0:
		# Les piliers sont créés par l'arène à son démarrage : on les recolore juste après.
		arena.ready.connect(_recolor_pillars.bind(arena), CONNECT_ONE_SHOT)


func _recolor_pillars(arena: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = pillar_color
	material.roughness = 0.9
	for child in arena.get_children():
		var instance := child as MultiMeshInstance3D
		if instance == null or instance.multimesh == null:
			continue
		var box := instance.multimesh.mesh as BoxMesh
		if box != null and box.size.y > 1.0:
			instance.material_override = material
