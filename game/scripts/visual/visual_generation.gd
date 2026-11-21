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
