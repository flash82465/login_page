class_name SilhouetteProfiles
extends RefCounted
## Proportions, couleurs, poses et costumes des silhouettes (mission 005, étape 2).
##
## Coordonnées en mètres, vue de profil : combattant tourné vers +X, pieds au sol (Y = 0).
## Une pose donne la position des 19 articulations (ordre : SilhouetteVisual.JOINTS) ; le pantin
## en déduit l'angle de chaque os et garde des os de longueur fixe (celle de la pose d'attente).
## Les pièces de costume et les Marques sont décrites dans la pose d'attente et suivent leur os.
## Costume purement décoratif : il ne change aucune zone de touche.


static func get_profile(id: StringName) -> Dictionary:
	match id:
		&"tande":
			return _tande()
		&"mabe":
			return _mabe()
	return {}


static func _tande() -> Dictionary:
	return {
		"name": "Tandé",
		"body": Color(0.1, 0.066, 0.046),
		"far": Color(0.17, 0.115, 0.082),
		"rim": Color(0.86, 0.46, 0.18),
		"rim_strength": 0.5,
		"mark": Color(1.0, 0.7, 0.28),
		"head_radius": 0.115,
		"fist_radius": 0.07,
		"radii": {
			&"belly": Vector2(0.155, 0.135),
			&"chest": Vector2(0.15, 0.18),
			&"neck": Vector2(0.082, 0.076),
			&"head": Vector2(0.0, 0.0),
			&"upper_arm_n": Vector2(0.082, 0.064),
			&"forearm_n": Vector2(0.062, 0.073),
			&"upper_arm_f": Vector2(0.082, 0.064),
			&"forearm_f": Vector2(0.062, 0.073),
			&"thigh_n": Vector2(0.105, 0.078),
			&"shin_n": Vector2(0.076, 0.056),
			&"foot_n": Vector2(0.05, 0.04),
			&"thigh_f": Vector2(0.105, 0.078),
			&"shin_f": Vector2(0.076, 0.056),
			&"foot_f": Vector2(0.05, 0.04),
		},
		"poses": {
			&"attente": PackedVector2Array([
				Vector2(0.0, 0.93), Vector2(0.02, 1.12), Vector2(0.05, 1.36), Vector2(0.06, 1.52),
				Vector2(0.05, 1.64), Vector2(0.07, 1.42), Vector2(0.22, 1.21), Vector2(0.34, 1.42),
				Vector2(0.02, 1.43), Vector2(0.1, 1.19), Vector2(0.17, 1.51), Vector2(0.02, 0.92),
				Vector2(0.13, 0.5), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.02, 0.93),
				Vector2(-0.1, 0.5), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
			]),
			&"garde": PackedVector2Array([
				Vector2(0.0, 0.88), Vector2(0.02, 1.07), Vector2(0.03, 1.31), Vector2(0.04, 1.47),
				Vector2(0.03, 1.59), Vector2(0.05, 1.37), Vector2(0.16, 1.22), Vector2(0.19, 1.62),
				Vector2(0.01, 1.38), Vector2(0.11, 1.2), Vector2(0.14, 1.59), Vector2(0.02, 0.87),
				Vector2(0.16, 0.47), Vector2(0.18, 0.09), Vector2(0.31, 0.04), Vector2(-0.02, 0.88),
				Vector2(-0.12, 0.47), Vector2(-0.21, 0.09), Vector2(-0.09, 0.04),
			]),
		},
		"costume": [
			{"bone": &"belly", "z": 0.21, "thickness": 0.025, "color": Color(0.14, 0.09, 0.058),
				"polygon": PackedVector2Array([
					Vector2(0.155, 1.05), Vector2(0.235, 0.72), Vector2(0.09, 0.685), Vector2(-0.05, 0.7),
					Vector2(-0.19, 0.745), Vector2(-0.145, 1.05),
				])},
			{"bone": &"upper_arm_n", "z": 0.2, "thickness": 0.03, "color": Color(0.2, 0.175, 0.155),
				"polygon": PackedVector2Array([
					Vector2(-0.03, 1.46), Vector2(0.01, 1.545), Vector2(0.11, 1.555), Vector2(0.175, 1.47),
					Vector2(0.15, 1.38), Vector2(0.04, 1.37),
				])},
		],
		"extra": [
		],
		"marks": [
			{"bone": &"forearm_n", "a": Vector2(0.226, 1.27), "b": Vector2(0.262, 1.42)},
			{"bone": &"forearm_n", "a": Vector2(0.243, 1.25), "b": Vector2(0.279, 1.4)},
		],
	}


static func _mabe() -> Dictionary:
	return {
		"name": "Mabé",
		"body": Color(0.058, 0.072, 0.098),
		"far": Color(0.11, 0.13, 0.165),
		"rim": Color(0.55, 0.67, 0.76),
		"rim_strength": 0.5,
		"mark": Color(1.0, 0.7, 0.28),
		"head_radius": 0.12,
		"fist_radius": 0.08,
		"radii": {
			&"belly": Vector2(0.19, 0.205),
			&"chest": Vector2(0.21, 0.19),
			&"neck": Vector2(0.1, 0.092),
			&"head": Vector2(0.0, 0.0),
			&"upper_arm_n": Vector2(0.088, 0.077),
			&"forearm_n": Vector2(0.075, 0.071),
			&"upper_arm_f": Vector2(0.088, 0.077),
			&"forearm_f": Vector2(0.075, 0.071),
			&"thigh_n": Vector2(0.128, 0.097),
			&"shin_n": Vector2(0.097, 0.07),
			&"foot_n": Vector2(0.058, 0.046),
			&"thigh_f": Vector2(0.128, 0.097),
			&"shin_f": Vector2(0.097, 0.07),
			&"foot_f": Vector2(0.058, 0.046),
		},
		"poses": {
			&"attente": PackedVector2Array([
				Vector2(0.0, 0.95), Vector2(0.04, 1.13), Vector2(0.11, 1.34), Vector2(0.08, 1.52),
				Vector2(0.05, 1.66), Vector2(0.14, 1.42), Vector2(0.25, 1.15), Vector2(0.37, 1.29),
				Vector2(0.08, 1.44), Vector2(0.16, 1.12), Vector2(0.3, 1.25), Vector2(0.02, 0.94),
				Vector2(0.16, 0.52), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.03, 0.95),
				Vector2(-0.12, 0.5), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
			]),
			&"garde": PackedVector2Array([
				Vector2(0.0, 0.92), Vector2(0.04, 1.1), Vector2(0.1, 1.31), Vector2(0.08, 1.49),
				Vector2(0.04, 1.63), Vector2(0.13, 1.39), Vector2(0.24, 1.17), Vector2(0.27, 1.55),
				Vector2(0.07, 1.41), Vector2(0.19, 1.14), Vector2(0.22, 1.5), Vector2(0.02, 0.91),
				Vector2(0.17, 0.5), Vector2(0.2, 0.1), Vector2(0.34, 0.04), Vector2(-0.03, 0.92),
				Vector2(-0.13, 0.49), Vector2(-0.21, 0.1), Vector2(-0.08, 0.04),
			]),
		},
		"costume": [
			{"bone": &"chest", "z": -0.24, "thickness": 0.03, "color": Color(0.1, 0.08, 0.07),
				"polygon": PackedVector2Array([
					Vector2(0.02, 1.49), Vector2(-0.08, 1.3), Vector2(-0.16, 1.0), Vector2(-0.23, 0.72),
					Vector2(-0.27, 0.53), Vector2(-0.31, 0.47), Vector2(-0.345, 0.53), Vector2(-0.39, 0.46),
					Vector2(-0.45, 0.5), Vector2(-0.38, 0.66), Vector2(-0.3, 0.88), Vector2(-0.23, 1.12),
					Vector2(-0.16, 1.37), Vector2(-0.08, 1.54),
				])},
			{"bone": &"chest", "z": -0.02, "thickness": 0.04, "color": Color(0.2, 0.19, 0.17),
				"polygon": PackedVector2Array([
					Vector2(-0.1, 1.47), Vector2(-0.17, 1.585), Vector2(-0.17, 1.43),
				])},
			{"bone": &"chest", "z": -0.02, "thickness": 0.04, "color": Color(0.2, 0.19, 0.17),
				"polygon": PackedVector2Array([
					Vector2(-0.17, 1.36), Vector2(-0.26, 1.45), Vector2(-0.23, 1.3),
				])},
			{"bone": &"chest", "z": -0.02, "thickness": 0.04, "color": Color(0.2, 0.19, 0.17),
				"polygon": PackedVector2Array([
					Vector2(-0.22, 1.22), Vector2(-0.31, 1.27), Vector2(-0.26, 1.15),
				])},
		],
		"extra": [
			{"bone": &"chest", "z": 0.0, "a": Vector2(-0.04, 1.2), "b": Vector2(0.03, 1.44), "r0": 0.17, "r1": 0.17},
		],
		"marks": [
			{"bone": &"neck", "a": Vector2(0.035, 1.46), "b": Vector2(0.07, 1.555)},
		],
	}
