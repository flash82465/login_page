class_name Hitbox
extends Area3D
## Zone de frappe d'une attaque. Elle n'est active que pendant les frames actives.
## Un même coup ne touche une cible qu'une seule fois (docs, Damage System §10).

signal hit_detected(hurtbox: Hurtbox, attack: AttackData, attack_id: int)

var owner_fighter: Fighter
var _attack: AttackData
var _attack_id: int = 0
var _already_hit: Dictionary = {}


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func activate(attack: AttackData, attack_id: int) -> void:
	_attack = attack
	_attack_id = attack_id
	_already_hit.clear()
	set_deferred(&"monitoring", true)


func deactivate() -> void:
	_attack = null
	set_deferred(&"monitoring", false)


func is_active() -> bool:
	return _attack != null


func _on_area_entered(area: Area3D) -> void:
	if _attack == null:
		return
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox.owner_fighter == null or hurtbox.owner_fighter == owner_fighter:
		return
	var target_id := hurtbox.owner_fighter.get_instance_id()
	if _already_hit.has(target_id):
		return
	_already_hit[target_id] = true
	hit_detected.emit(hurtbox, _attack, _attack_id)
