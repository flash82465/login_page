class_name AttackData
extends Resource
## Données d'une attaque. Les frames sont comptées à 60 Hz (logique de jeu fixe).
## Les types reprennent ceux du Damage Priority & Resolution System (docs/technical/damage-system.md §7).

enum AttackType { SLASH, BLUNT, PIERCE, HEAVY, EXPLOSIVE, ELEMENTAL }
enum Height { HIGH, MID, LOW }

@export var id: StringName = &"attack"
@export var attack_type: AttackType = AttackType.BLUNT
@export var height: Height = Height.MID
@export_range(1, 60) var startup_frames: int = 6
@export_range(1, 30) var active_frames: int = 3
@export_range(1, 60) var recovery_frames: int = 12
## Force de l'impact, en unités d'impact (échelle du système de dégâts).
@export var force: float = 40.0
## Durée d'étourdissement infligée à la touche, et en garde.
@export_range(0, 60) var hitstun_frames: int = 14
@export_range(0, 60) var blockstun_frames: int = 8
## Arrêt sur image partagé par les deux combattants à l'impact (sensation de poids).
@export_range(0, 20) var hitstop_frames: int = 4
## Vitesse de recul infligée, en m/s pour un défenseur de 80 kg.
@export var knockback: float = 1.8
## Échelle de la pose provisoire du bras pendant l'attaque.
@export var arm_scale: float = 1.0


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames
