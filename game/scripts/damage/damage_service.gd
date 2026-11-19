extends Node
## Point d'entrée unique des dégâts côté jeu (chargé en autoload sous le nom DamageService).
##
## PROVISOIRE : ce service applique une perte de vie simple, proportionnelle à la force.
## Il sera remplacé par le portage GDScript du Damage Priority & Resolution System
## (prototype de référence : damage-system/ sur la branche de la PR #1 ;
## spécification : docs/technical/damage-system.md). Rien ici ne remplace ce système.

signal impact_resolved(result: Dictionary)

const PLACEHOLDER_HEALTH_PER_FORCE := 0.25


func resolve_hit(attacker: Fighter, defender: Fighter, hurtbox: Hurtbox, attack: AttackData, attack_id: int) -> Dictionary:
	var damage := attack.force * PLACEHOLDER_HEALTH_PER_FORCE
	defender.receive_damage(damage)
	var result := {
		"attacker": attacker.display_name,
		"defender": defender.display_name,
		"body_zone": hurtbox.body_zone,
		"attack": attack.id,
		"attack_id": attack_id,
		"health_damage": damage,
		"placeholder": true,
	}
	impact_resolved.emit(result)
	return result
