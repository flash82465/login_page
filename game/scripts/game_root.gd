class_name GameRoot
extends Node
## Point d'entrée du jeu (mission 006). Crée la scène de combat avec le visuel choisi (pantins animés
## par défaut, ou capsules historiques), ajoute le bouton « Visuel » à son interface, et relance un
## combat neuf quand on change de visuel. La scène de combat (main.tscn) n'est pas modifiée : le
## visuel ne change que l'apparence, jamais le combat.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const TOGGLE_SCENE := preload("res://scenes/interface/visual_toggle.tscn")

var match_scene: Node
var choice: StringName = &""


func _ready() -> void:
	_start(VisualSettings.load_choice())


func _start(new_choice: StringName) -> void:
	choice = new_choice
	if match_scene != null:
		remove_child(match_scene)
		match_scene.queue_free()
	var m := MAIN_SCENE.instantiate()
	VisualSettings.generation_for(choice).apply_to(m)
	var toggle := TOGGLE_SCENE.instantiate() as VisualToggle
	toggle.choice = choice
	toggle.choice_requested.connect(_on_choice_requested)
	m.get_node("Interface").add_child(toggle)
	add_child(m)
	match_scene = m


func _on_choice_requested(new_choice: StringName) -> void:
	VisualSettings.save_choice(new_choice)
	_start.call_deferred(new_choice)
