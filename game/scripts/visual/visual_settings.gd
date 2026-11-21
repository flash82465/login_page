class_name VisualSettings
extends RefCounted
## Choix du visuel des combattants (mission 006), conservé entre deux lancements :
## « pantins » (pantins animés, par défaut) ou « capsules » (visuel historique des versions 0.1 à 0.4.1).

const CONFIG_PATH := "user://okelun.cfg"
const SECTION := "affichage"
const KEY := "visuel"
const PANTINS := &"pantins"
const CAPSULES := &"capsules"
const GENERATIONS := {
	&"pantins": "res://assets/visual/generation_silhouette_v05.tres",
	&"capsules": "res://assets/visual/generation_capsule_v04.tres",
}


static func load_choice() -> StringName:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		var value := StringName(str(config.get_value(SECTION, KEY, PANTINS)))
		if GENERATIONS.has(value):
			return value
	return PANTINS


static func save_choice(choice: StringName) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(SECTION, KEY, String(choice))
	config.save(CONFIG_PATH)


static func clear() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG_PATH))


static func generation_for(choice: StringName) -> VisualGeneration:
	return load(GENERATIONS.get(choice, GENERATIONS[PANTINS])) as VisualGeneration


static func other(choice: StringName) -> StringName:
	return CAPSULES if choice == PANTINS else PANTINS
