class_name Hurtbox
extends Area3D
## Zone du corps qui peut être touchée. Le nom de zone suit le modèle du système de dégâts
## (docs/technical/damage-system.md §2) ; le prototype n'utilise que head, torso et legs.

@export var body_zone: StringName = &"torso"

var owner_fighter: Fighter
