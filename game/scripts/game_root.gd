class_name GameRoot
extends Node
## Point d'entrée du jeu (mission 006). Crée la scène de combat avec le visuel choisi (pantins animés
## par défaut, ou capsules historiques), ajoute les boutons « Visuel » et « Profondeur » à son
## interface, et relance un combat neuf quand on change l'un des deux. La scène de combat
## (main.tscn) n'est pas modifiée : le visuel ne change que l'apparence, jamais le combat.
##
## Option « Profondeur » (V0.6, étape 0) : lue au démarrage (désactivée par défaut, jamais activée
## automatiquement) et transmise au combat. À l'étape 0, aucun code de combat ne la lit encore.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const TOGGLE_SCENE := preload("res://scenes/interface/visual_toggle.tscn")
const DEPTH_TOGGLE_SCENE := preload("res://scenes/interface/depth_toggle.tscn")

var match_scene: Node
var choice: StringName = &""
var depth_enabled: bool = false


func _ready() -> void:
	_start(VisualSettings.load_choice(), DepthSettings.load_enabled())


func _start(new_choice: StringName, new_depth: bool) -> void:
	choice = new_choice
	depth_enabled = new_depth
	if match_scene != null:
		remove_child(match_scene)
		match_scene.queue_free()
	var m := MAIN_SCENE.instantiate()
	VisualSettings.generation_for(choice).apply_to(m)
	m.depth_enabled = depth_enabled
	var toggle := TOGGLE_SCENE.instantiate() as VisualToggle
	toggle.choice = choice
	toggle.choice_requested.connect(_on_choice_requested)
	m.get_node("Interface").add_child(toggle)
	var depth_toggle := DEPTH_TOGGLE_SCENE.instantiate() as DepthToggle
	depth_toggle.enabled = depth_enabled
	depth_toggle.depth_requested.connect(_on_depth_requested)
	m.get_node("Interface").add_child(depth_toggle)
	add_child(m)
	match_scene = m


func _on_choice_requested(new_choice: StringName) -> void:
	VisualSettings.save_choice(new_choice)
	_start.call_deferred(new_choice, depth_enabled)


func _on_depth_requested(enabled: bool) -> void:
	DepthSettings.save_enabled(enabled)
	_start.call_deferred(choice, enabled)
