class_name Hitbox
extends Area3D
## Zone de frappe. Elle reste surveillée en permanence (coût négligeable pour 2 combattants)
## et n'est interrogée que pendant les frames actives d'une attaque : la détection ne dépend
## donc pas d'une activation différée de la physique.
## Un même coup ne touche une cible qu'une seule fois, même si plusieurs zones du corps
## sont touchées en même temps ou pendant plusieurs frames (docs, Damage System §10).

signal hit_detected(hurtbox: Hurtbox, attack: AttackData, attack_id: int)

var owner_fighter: Fighter
var _attack: AttackData
var _attack_id: int = 0
var _already_hit: Dictionary = {}

@onready var _shape: CollisionShape3D = $CollisionShape3D


func activate(attack: AttackData, attack_id: int) -> void:
	_attack = attack
	_attack_id = attack_id
	_already_hit.clear()


func deactivate() -> void:
	_attack = null


func is_active() -> bool:
	return _attack != null


func contact_point() -> Vector3:
	return _shape.global_position


## À appeler à chaque frame active : émet au plus une touche par cible pour ce coup.
func scan() -> void:
	if _attack == null:
		return
	var best: Dictionary = {}
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox.owner_fighter == null or hurtbox.owner_fighter == owner_fighter:
			continue
		var target := hurtbox.owner_fighter
		var target_id := target.get_instance_id()
		if _already_hit.has(target_id) or target.is_invulnerable():
			continue
		var current: Hurtbox = best.get(target_id)
		if current == null or _zone_rank(hurtbox.body_zone) < _zone_rank(current.body_zone):
			best[target_id] = hurtbox
	for target_id in best:
		_already_hit[target_id] = true
		hit_detected.emit(best[target_id], _attack, _attack_id)


func _zone_rank(zone: StringName) -> int:
	var order: Array
	match _attack.height:
		AttackData.Height.HIGH:
			order = [&"head", &"torso", &"legs"]
		AttackData.Height.LOW:
			order = [&"legs", &"torso", &"head"]
		_:
			order = [&"torso", &"head", &"legs"]
	var index := order.find(zone)
	return index if index >= 0 else order.size()
