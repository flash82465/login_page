class_name FighterVisual
extends Node3D
## Contrat commun des générations visuelles d'un combattant (mission 005).
##
## Le visuel ne décide de rien : le combattant lui transmet son état après chaque frame de
## logique, et il l'affiche. Les états, les zones de touche et les dégâts restent dans Fighter.
## Chaque génération visuelle (capsule, silhouette, puis 2.5D...) est une scène séparée dont la
## racine hérite de cette classe ; on choisit la génération par Fighter.visual_scene.


## Appelé une fois, quand le combattant est prêt.
func bind(_fighter: Fighter) -> void:
	pass


## Appelé après chaque frame de logique du combattant (jamais pendant un arrêt sur image),
## à sa création et au début de chaque manche.
func update_visual(_fighter: Fighter) -> void:
	pass


## Éclair de couleur bref : coup reçu, déséquilibre après une parade.
func flash(_color: Color, _frames: int) -> void:
	pass


## Remise à zéro au début d'une manche.
func reset_visual() -> void:
	pass
