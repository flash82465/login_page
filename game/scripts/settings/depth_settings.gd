class_name DepthSettings
extends RefCounted
## Option « Profondeur » (V0.6, étape 0), conservée entre deux lancements dans le même fichier que
## le choix du visuel (user://okelun.cfg), dans sa propre section.
##
## Désactivée par défaut : sans fichier, sans valeur, ou avec une valeur qui n'est pas un booléen,
## l'option reste désactivée. Elle n'est jamais activée automatiquement : seul le bouton
## « Profondeur » l'enregistre. Désactivée, le jeu est strictement celui de V0.5.0.

const CONFIG_PATH := "user://okelun.cfg"
const SECTION := "combat"
const KEY := "profondeur"
const DEFAULT_ENABLED := false


static func load_enabled() -> bool:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return DEFAULT_ENABLED
	var value: Variant = config.get_value(SECTION, KEY, DEFAULT_ENABLED)
	if typeof(value) != TYPE_BOOL:
		return DEFAULT_ENABLED
	return value


## Enregistre le choix sans toucher aux autres réglages du fichier (choix du visuel).
static func save_enabled(enabled: bool) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(SECTION, KEY, enabled)
	config.save(CONFIG_PATH)


## Retire seulement ce réglage (retour au défaut, désactivé) ; les autres sont conservés.
static func clear() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	if config.has_section_key(SECTION, KEY):
		config.erase_section_key(SECTION, KEY)
		config.save(CONFIG_PATH)
