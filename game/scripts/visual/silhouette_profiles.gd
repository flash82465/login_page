class_name SilhouetteProfiles
extends RefCounted
## Proportions, couleurs, poses et costumes des silhouettes (mission 005, étape 2).
##
## Coordonnées en mètres, vue de profil : combattant tourné vers +X, pieds au sol (Y = 0).
## « reference » : pose de construction (longueurs des os, points d'attache, costume). « keys » :
## poses-clés des animations (étape 3), positions des 19 articulations (ordre : SilhouetteVisual.JOINTS) ;
## le pantin en déduit l'angle de chaque os, garde des os de longueur fixe et, si « ik », place les
## jambes par cinématique inverse vers les chevilles de la pose (pieds posés). « walk » : marche.
## Les pièces de costume, les volumes et les Marques sont décrits dans la pose d'attente et suivent
## leur os. Volumes : « jupe » (anneaux : hauteur, arrière, avant, demi-profondeur) et « dome » (ellipsoïde).
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
		"reference": PackedVector2Array([
			Vector2(0.0, 0.93), Vector2(0.02, 1.12), Vector2(0.05, 1.36), Vector2(0.06, 1.52),
			Vector2(0.05, 1.64), Vector2(0.07, 1.42), Vector2(0.2363, 1.1824), Vector2(0.3725, 1.4385),
			Vector2(0.02, 1.43), Vector2(0.1192, 1.1575), Vector2(0.1795, 1.4412), Vector2(0.02, 0.92),
			Vector2(0.13, 0.5), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.02, 0.93),
			Vector2(-0.1, 0.5), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
		]),
		"keys": {
			&"attente": {"ik": true, "points": PackedVector2Array([
					Vector2(0.0, 0.88), Vector2(0.02, 1.07), Vector2(0.05, 1.31), Vector2(0.06, 1.47),
					Vector2(0.05, 1.59), Vector2(0.07, 1.37), Vector2(0.2363, 1.1324), Vector2(0.3725, 1.3885),
					Vector2(0.02, 1.38), Vector2(0.1192, 1.1075), Vector2(0.1795, 1.3912), Vector2(0.02, 0.87),
					Vector2(0.2403, 0.4959), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.02, 0.88),
					Vector2(0.0327, 0.4458), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"inspire": {"ik": true, "points": PackedVector2Array([
					Vector2(0.0, 0.884), Vector2(0.022, 1.0738), Vector2(0.0553, 1.3133), Vector2(0.0639, 1.4734),
					Vector2(0.0539, 1.5934), Vector2(0.0762, 1.3731), Vector2(0.2507, 1.1414), Vector2(0.3778, 1.4021),
					Vector2(0.0263, 1.3837), Vector2(0.135, 1.1149), Vector2(0.1853, 1.4005), Vector2(0.0199, 0.8738),
					Vector2(0.2352, 0.4968), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.02, 0.8842),
					Vector2(0.0269, 0.4494), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"garde": {"ik": true, "points": PackedVector2Array([
					Vector2(0.0, 0.88), Vector2(0.0266, 1.0692), Vector2(0.0691, 1.3073), Vector2(0.0735, 1.4675),
					Vector2(0.0677, 1.5878), Vector2(0.0923, 1.3662), Vector2(0.3483, 1.23), Vector2(0.293, 1.5147),
					Vector2(0.0428, 1.3788), Vector2(0.2584, 1.1847), Vector2(0.223, 1.4726), Vector2(0.0196, 0.8693),
					Vector2(0.241, 0.4958), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.02, 0.8807),
					Vector2(0.0318, 0.4464), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"garde_recul": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.045, 0.87), Vector2(-0.035, 1.0608), Vector2(-0.0218, 1.3023), Vector2(-0.0202, 1.4626),
					Vector2(-0.0302, 1.5826), Vector2(-0.006, 1.3635), Vector2(0.2568, 1.241), Vector2(0.1867, 1.5224),
					Vector2(-0.0566, 1.37), Vector2(0.1656, 1.1836), Vector2(0.1152, 1.4692), Vector2(-0.0245, 0.8611),
					Vector2(0.2157, 0.4994), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.065, 0.869),
					Vector2(0.0364, 0.4435), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"legere_armee": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.015, 0.87), Vector2(0.0017, 1.0603), Vector2(0.0233, 1.3012), Vector2(0.0333, 1.4612),
					Vector2(0.0233, 1.5812), Vector2(0.0412, 1.3619), Vector2(0.1308, 1.0861), Vector2(0.3093, 1.3146),
					Vector2(-0.0091, 1.3701), Vector2(0.09, 1.0976), Vector2(0.1404, 1.3832), Vector2(0.0052, 0.8604),
					Vector2(0.241, 0.4958), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.035, 0.8697),
					Vector2(0.0429, 0.4393), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"legere_frappe": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.033, 0.86), Vector2(0.0068, 1.0469), Vector2(0.0739, 1.2792), Vector2(0.0923, 1.4385),
					Vector2(0.0865, 1.5588), Vector2(0.1031, 1.3354), Vector2(0.3902, 1.295), Vector2(0.6801, 1.3051),
					Vector2(0.0552, 1.3531), Vector2(0.1449, 1.0772), Vector2(0.1852, 1.3644), Vector2(-0.0142, 0.848),
					Vector2(0.24, 0.496), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.0529, 0.8621),
					Vector2(0.0472, 0.4363), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"lourde_armee": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.06, 0.855), Vector2(-0.0666, 1.0459), Vector2(-0.0872, 1.2869), Vector2(-0.0884, 1.4472),
					Vector2(-0.0984, 1.5672), Vector2(-0.0801, 1.3498), Vector2(0.142, 1.1634), Vector2(0.2317, 1.4392),
					Vector2(-0.1311, 1.3492), Vector2(-0.2672, 1.0931), Vector2(-0.1311, 1.3492), Vector2(-0.0388, 0.8479),
					Vector2(0.2196, 0.499), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.0798, 0.8522),
					Vector2(0.0498, 0.4345), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"lourde_frappe": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.034, 0.84), Vector2(0.0187, 1.0236), Vector2(0.1137, 1.2461), Vector2(0.1376, 1.4046),
					Vector2(0.1339, 1.525), Vector2(0.1494, 1.2982), Vector2(0.1596, 1.0084), Vector2(0.2297, 1.2898),
					Vector2(0.1041, 1.3216), Vector2(0.3913, 1.2813), Vector2(0.6797, 1.3116), Vector2(-0.016, 0.8267),
					Vector2(0.2604, 0.4919), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.0537, 0.8435),
					Vector2(0.1128, 0.439), Vector2(-0.16, 0.12), Vector2(-0.0613, 0.0354),
				])},
			&"recul": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.07, 0.86), Vector2(-0.0833, 1.0506), Vector2(-0.1206, 1.2896), Vector2(-0.1385, 1.4489),
					Vector2(-0.1733, 1.5642), Vector2(-0.1179, 1.3527), Vector2(-0.0776, 1.0656), Vector2(0.1629, 1.2277),
					Vector2(-0.1687, 1.3486), Vector2(-0.2191, 1.063), Vector2(-0.0406, 1.2915), Vector2(-0.0486, 0.8536),
					Vector2(0.2041, 0.5005), Vector2(0.17, 0.09), Vector2(0.3, 0.04), Vector2(-0.0897, 0.8565),
					Vector2(0.0424, 0.4396), Vector2(-0.19, 0.09), Vector2(-0.07, 0.04),
				])},
			&"esquive": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.1, 0.75), Vector2(-0.1, 0.941), Vector2(-0.1121, 1.1826), Vector2(-0.0854, 1.3407),
					Vector2(-0.0744, 1.4606), Vector2(-0.1028, 1.2452), Vector2(0.0333, 0.9891), Vector2(0.003, 1.2775),
					Vector2(-0.1538, 1.2463), Vector2(-0.0836, 0.965), Vector2(-0.134, 1.2505), Vector2(-0.0791, 0.7421),
					Vector2(0.2834, 0.5032), Vector2(0.12, 0.125), Vector2(0.25, 0.075), Vector2(-0.1199, 0.7479),
					Vector2(0.1032, 0.3717), Vector2(-0.24, 0.13), Vector2(-0.12, 0.08),
				])},
			&"ko": {"ik": false, "points": PackedVector2Array([
					Vector2(-0.55, 0.14), Vector2(-0.7392, 0.1666), Vector2(-0.9807, 0.1798), Vector2(-1.1409, 0.173),
					Vector2(-1.2604, 0.1588), Vector2(-1.0419, 0.1956), Vector2(-1.2931, 0.3406), Vector2(-1.582, 0.3153),
					Vector2(-1.0484, 0.145), Vector2(-1.2348, 0.3671), Vector2(-1.5074, 0.4663), Vector2(-0.5393, 0.1596),
					Vector2(-0.1146, 0.2499), Vector2(0.2851, 0.1502), Vector2(0.365, 0.2643), Vector2(-0.5507, 0.12),
					Vector2(-0.1645, 0.3253), Vector2(0.1915, 0.1029), Vector2(0.2525, 0.2177),
				])},
		},
		"walk": {"cycle": 0.72, "lift": 0.07, "bob": 0.015},
		"costume": [
		],
		"volumes": [
			{"bone": &"belly", "kind": &"jupe", "z": 0.0, "color": Color(0.11, 0.07, 0.047),
				"rings": [Vector4(1.05, -0.15, 0.13, 0.165), Vector4(0.9, -0.185, 0.19, 0.19), Vector4(0.72, -0.225, 0.255, 0.215)]},
			{"bone": &"upper_arm_n", "kind": &"dome", "z": 0.095, "color": Color(0.13, 0.115, 0.1), "center": Vector2(0.07, 1.465), "radii": Vector3(0.105, 0.075, 0.1)},
		],
		"extra": [
		],
		"marks": [
			{"bone": &"forearm_n", "a": Vector2(0.2878, 1.2536), "b": Vector2(0.345, 1.3612)},
			{"bone": &"forearm_n", "a": Vector2(0.2666, 1.2649), "b": Vector2(0.3238, 1.3724)},
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
		"reference": PackedVector2Array([
			Vector2(0.0, 0.95), Vector2(0.04, 1.13), Vector2(0.11, 1.34), Vector2(0.08, 1.52),
			Vector2(0.05, 1.66), Vector2(0.14, 1.42), Vector2(0.2426, 1.1381), Vector2(0.4898, 1.2695),
			Vector2(0.08, 1.44), Vector2(0.1218, 1.1429), Vector2(0.3592, 1.2913), Vector2(0.02, 0.94),
			Vector2(0.16, 0.52), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.03, 0.95),
			Vector2(-0.1135, 0.4988), Vector2(-0.2, 0.1001), Vector2(-0.07, 0.0401),
		]),
		"keys": {
			&"attente": {"ik": true, "points": PackedVector2Array([
					Vector2(0.0, 0.9), Vector2(0.04, 1.08), Vector2(0.11, 1.29), Vector2(0.08, 1.47),
					Vector2(0.05, 1.61), Vector2(0.14, 1.37), Vector2(0.2426, 1.0881), Vector2(0.4898, 1.2195),
					Vector2(0.08, 1.39), Vector2(0.1218, 1.0929), Vector2(0.3592, 1.2413), Vector2(0.02, 0.89),
					Vector2(0.2566, 0.5158), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.03, 0.9),
					Vector2(0.0196, 0.4438), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"inspire": {"ik": true, "points": PackedVector2Array([
					Vector2(0.0, 0.904), Vector2(0.0419, 1.0836), Vector2(0.1148, 1.2926), Vector2(0.0832, 1.4723),
					Vector2(0.0532, 1.6123), Vector2(0.1459, 1.3721), Vector2(0.2583, 1.094), Vector2(0.5008, 1.234),
					Vector2(0.0862, 1.393), Vector2(0.1383, 1.0975), Vector2(0.3704, 1.2541), Vector2(0.0199, 0.8938),
					Vector2(0.2516, 0.5165), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.03, 0.9043),
					Vector2(0.0137, 0.4475), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"garde": {"ik": true, "points": PackedVector2Array([
					Vector2(0.0, 0.9), Vector2(0.0463, 1.0785), Vector2(0.1272, 1.2845), Vector2(0.0909, 1.4634),
					Vector2(0.0658, 1.6043), Vector2(0.1613, 1.3629), Vector2(0.4157, 1.2039), Vector2(0.3767, 1.4812),
					Vector2(0.1024, 1.386), Vector2(0.3146, 1.1738), Vector2(0.2853, 1.4523), Vector2(0.0196, 0.8893),
					Vector2(0.2571, 0.5157), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.03, 0.901),
					Vector2(0.0182, 0.4447), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"garde_recul": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.04, 0.89), Vector2(-0.0095, 1.0718), Vector2(0.0457, 1.2862), Vector2(0.0063, 1.4644),
					Vector2(-0.0237, 1.6044), Vector2(0.0701, 1.3681), Vector2(0.3324, 1.2227), Vector2(0.279, 1.4975),
					Vector2(0.0088, 1.3839), Vector2(0.2282, 1.1793), Vector2(0.1844, 1.4558), Vector2(-0.0195, 0.8811),
					Vector2(0.2348, 0.5187), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.07, 0.8884),
					Vector2(0.0259, 0.4396), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"legere_armee": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.02, 0.89), Vector2(0.0169, 1.0707), Vector2(0.0795, 1.283), Vector2(0.0495, 1.463),
					Vector2(0.0195, 1.603), Vector2(0.1067, 1.364), Vector2(0.1171, 1.0642), Vector2(0.3834, 1.1507),
					Vector2(0.046, 1.3819), Vector2(0.0878, 1.0848), Vector2(0.3252, 1.2332), Vector2(0.0002, 0.8804),
					Vector2(0.2523, 0.5164), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.05, 0.8895),
					Vector2(0.0292, 0.4374), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"legere_frappe": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.078, 0.88), Vector2(-0.0225, 1.0558), Vector2(0.0726, 1.2557), Vector2(0.0521, 1.4371),
					Vector2(0.027, 1.578), Vector2(0.1121, 1.3315), Vector2(0.4005, 1.2488), Vector2(0.6803, 1.239),
					Vector2(0.055, 1.3586), Vector2(0.0864, 1.0603), Vector2(0.3289, 1.2003), Vector2(-0.0589, 0.8683),
					Vector2(0.2148, 0.5203), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.1079, 0.8826),
					Vector2(0.0217, 0.4424), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"lourde_armee": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.07, 0.88), Vector2(-0.0522, 1.0635), Vector2(-0.0198, 1.2825), Vector2(-0.0622, 1.46),
					Vector2(-0.0922, 1.6), Vector2(-0.0041, 1.3665), Vector2(0.1459, 1.1067), Vector2(0.3884, 1.2467),
					Vector2(-0.0667, 1.3758), Vector2(-0.0405, 1.6746), Vector2(-0.0649, 1.9536), Vector2(-0.0489, 0.8725),
					Vector2(0.219, 0.5201), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.0998, 0.8763),
					Vector2(0.0307, 0.4364), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"lourde_frappe": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.061, 0.86), Vector2(0.0067, 1.0315), Vector2(0.1254, 1.2184), Vector2(0.1144, 1.4005),
					Vector2(0.0942, 1.5423), Vector2(0.1739, 1.2887), Vector2(0.1634, 0.9889), Vector2(0.3779, 1.1689),
					Vector2(0.1205, 1.3226), Vector2(0.4203, 1.3122), Vector2(0.6799, 1.2073), Vector2(-0.0428, 0.847),
					Vector2(0.2518, 0.5165), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.0906, 0.8647),
					Vector2(0.0872, 0.4416), Vector2(-0.17, 0.125), Vector2(-0.0616, 0.0315),
				])},
			&"recul": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.07, 0.88), Vector2(-0.0587, 1.064), Vector2(-0.0415, 1.2847), Vector2(-0.1023, 1.4568),
					Vector2(-0.1608, 1.5875), Vector2(-0.0318, 1.3696), Vector2(-0.0422, 1.0698), Vector2(0.2335, 1.1184),
					Vector2(-0.0948, 1.3745), Vector2(-0.1725, 1.0847), Vector2(0.07, 1.2247), Vector2(-0.0487, 0.8733),
					Vector2(0.2183, 0.5201), Vector2(0.19, 0.1), Vector2(0.33, 0.04), Vector2(-0.0996, 0.8753),
					Vector2(0.0318, 0.4356), Vector2(-0.2, 0.1), Vector2(-0.07, 0.04),
				])},
			&"esquive": {"ik": true, "points": PackedVector2Array([
					Vector2(-0.1, 0.78), Vector2(-0.079, 0.9632), Vector2(-0.0427, 1.1816), Vector2(-0.0538, 1.3637),
					Vector2(-0.059, 1.5068), Vector2(-0.0256, 1.2653), Vector2(0.0964, 0.9912), Vector2(0.0866, 1.271),
					Vector2(-0.088, 1.2756), Vector2(-0.0256, 0.9822), Vector2(-0.0549, 1.2607), Vector2(-0.0791, 0.7721),
					Vector2(0.2904, 0.5283), Vector2(0.14, 0.135), Vector2(0.28, 0.075), Vector2(-0.1298, 0.7769),
					Vector2(0.0857, 0.3717), Vector2(-0.25, 0.14), Vector2(-0.12, 0.08),
				])},
			&"ko": {"ik": false, "points": PackedVector2Array([
					Vector2(-0.55, 0.14), Vector2(-0.7324, 0.1673), Vector2(-0.9513, 0.1998), Vector2(-1.1338, 0.2015),
					Vector2(-1.277, 0.2013), Vector2(-1.0353, 0.2155), Vector2(-1.2951, 0.3655), Vector2(-1.5741, 0.3411),
					Vector2(-1.0446, 0.1529), Vector2(-1.2374, 0.3827), Vector2(-1.5005, 0.4785), Vector2(-0.5414, 0.1606),
					Vector2(-0.1084, 0.2527), Vector2(0.3002, 0.1508), Vector2(0.3876, 0.2756), Vector2(-0.5479, 0.1101),
					Vector2(-0.1427, 0.3255), Vector2(0.2032, 0.1094), Vector2(0.2704, 0.2358),
				])},
		},
		"walk": {"cycle": 0.66, "lift": 0.065, "bob": 0.018},
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
		"volumes": [
		],
		"extra": [
			{"bone": &"chest", "z": 0.0, "a": Vector2(-0.04, 1.2), "b": Vector2(0.03, 1.44), "r0": 0.17, "r1": 0.17},
		],
		"marks": [
			{"bone": &"neck", "a": Vector2(-0.05, 1.455), "b": Vector2(-0.015, 1.535), "z": 0.26},
		],
	}
