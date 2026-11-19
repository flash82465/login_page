extends Node
## Point d'entrée unique des dégâts côté jeu (chargé en autoload sous le nom DamageService).
##
## PROVISOIRE : ce service applique une perte de vie simple, proportionnelle à la force,
## ainsi que les règles de garde, de parade, d'étourdissement, de recul et d'arrêt sur image.
## Il sera remplacé par le portage GDScript du Damage Priority & Resolution System
## (prototype de référence : damage-system/ sur la branche de la PR #1 ;
## spécification : docs/technical/damage-system.md). Rien ici ne remplace ce système.

signal impact_resolved(result: Dictionary)

const PLACEHOLDER_HEALTH_PER_FORCE := 0.25
const BLOCK_DAMAGE_FACTOR := 0.2
const BLOCK_KNOCKBACK_FACTOR := 0.5
const PARRY_STAGGER_FRAMES := 24
const PARRY_FREEZE_FRAMES := 6
const REFERENCE_MASS_KG := 80.0


func resolve_hit(attacker: Fighter, defender: Fighter, hurtbox: Hurtbox, attack: AttackData, attack_id: int) -> Dictionary:
	var result := {
		"attacker": attacker.display_name,
		"defender": defender.display_name,
		"body_zone": hurtbox.body_zone,
		"attack": attack.id,
		"attack_id": attack_id,
		"outcome": &"ignored",
		"health_damage": 0.0,
		"placeholder": true,
	}
	if defender.state == Fighter.State.KO:
		return result
	var contact := attacker.hitbox.contact_point()
	var direction := signf(defender.global_position.x - attacker.global_position.x)
	if direction == 0.0:
		direction = attacker.facing

	if defender.is_parrying():
		attacker.apply_parry_stagger(PARRY_STAGGER_FRAMES)
		attacker.apply_freeze(PARRY_FREEZE_FRAMES)
		defender.apply_freeze(PARRY_FREEZE_FRAMES)
		ImpactFx.spawn(defender.get_parent(), contact, ImpactFx.Kind.PARRY, 1.2)
		result["outcome"] = &"parried"
	else:
		var blocked := defender.is_blocking()
		var damage := attack.force * PLACEHOLDER_HEALTH_PER_FORCE * (BLOCK_DAMAGE_FACTOR if blocked else 1.0)
		var mass_factor := REFERENCE_MASS_KG / maxf(defender.mass_kg, 1.0)
		var knockback := direction * attack.knockback * mass_factor * (BLOCK_KNOCKBACK_FACTOR if blocked else 1.0)
		var stun := attack.blockstun_frames if blocked else attack.hitstun_frames
		defender.apply_hit(damage, stun, knockback, blocked)
		attacker.apply_freeze(attack.hitstop_frames)
		defender.apply_freeze(attack.hitstop_frames)
		var kind := ImpactFx.Kind.BLOCK if blocked else ImpactFx.Kind.HIT
		ImpactFx.spawn(defender.get_parent(), contact, kind, 0.6 * attack.arm_scale)
		result["outcome"] = &"blocked" if blocked else &"hit"
		result["health_damage"] = damage
	impact_resolved.emit(result)
	return result
