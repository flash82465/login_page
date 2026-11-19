# OKÉLUN — Prototype Godot 4 (Android first)

Socle du premier prototype jouable d'OKÉLUN, avec Godot 4.4.1 et Android comme cible prioritaire. Ce dossier ne remplace ni ne modifie le prototype logique des dégâts (`damage-system/`, PR #1) ni la documentation (`docs/`).

## Ouvrir et lancer

- **Godot 4.4.1** (éditeur standard, pas la version .NET) : ouvrir `game/project.godot`, puis F5.
- **Clavier (ordinateur)** : A/D ou flèches pour se déplacer, J attaque légère, K attaque lourde, L garde (maintenir), Espace esquive.
- **Écran tactile** : flèches à gauche ; à droite, bouclier (garde), petit rond (attaque légère), grand rond (attaque lourde), double flèche (esquive).
- **Tests de gameplay** : `godot --headless --path game --fixed-fps 60 res://tests/test_runner.tscn` (14 tests, code de sortie 0 si tout passe).
- **Test de fumée** : `godot --headless --path game -- --smoke-test`.
- **APK Android** : voir [ANDROID_BUILD.md](ANDROID_BUILD.md).

## Organisation

```
game/
├── project.godot            configuration (rendu mobile, paysage, 60 Hz)
├── export_presets.cfg       preset d'export « Android » (arm64-v8a, APK de debug)
├── icon.svg
├── scenes/
│   ├── main/main.tscn       scène de combat : arène, 2 combattants, caméra, interface
│   ├── fighters/fighter.tscn combattant générique (corps, hurtbox, hitbox)
│   ├── arenas/arena_training.tscn  arène d'entraînement (sol, murs, lumière)
│   └── interface/           hud.tscn + hud.gd, touch_controls.tscn
├── scripts/
│   ├── combat/              Fighter, intentions, contrôleur joueur, hitbox, hurtbox, AttackData, match
│   ├── damage/              DamageService (autoload, provisoire)
│   ├── movement/            FighterMotor (inertie selon la masse)
│   ├── camera/              FightCamera (cadrage des deux combattants)
│   └── ai/                  AIController (IA basique)
└── assets/
    ├── ui/                  icônes des boutons tactiles
    └── data/attacks/        données des attaques légère et lourde
```

### Flux d'une frame

1. Chaque combattant demande une **intention** (`FighterIntent`) à son contrôleur : `PlayerInputController` (tactile ou clavier) ou `AIController`.
2. `Fighter` applique l'intention selon son **état** (`IDLE`, `WALK`, `ATTACK`, `BLOCK`, `DODGE`, `HITSTUN`, `KO`).
3. `FighterMotor` calcule la vitesse avec inertie ; le combattant reste sur le couloir de combat (Z = 0) et fait face à l'adversaire.
4. Quand une attaque sera active, sa `Hitbox` détectera les `Hurtbox` adverses (tête, torse, jambes), une seule fois par coup et par cible.
5. Le `MatchController` transmet chaque touche au `DamageService`, qui met à jour la vie ; le `Hud` suit le signal `health_changed`.

### Choix de configuration mobile

| Réglage | Valeur | Raison |
| --- | --- | --- |
| Rendu | `mobile` (Vulkan), repli automatique sur OpenGL ES 3 | Vulkan est absent ou instable sur une partie des appareils Android |
| Orientation | paysage avec capteur | jeu de combat latéral, deux mains sur l'écran |
| Résolution de base | 1280 × 720, étirement `canvas_items` / `expand` | lisible sur téléphone, s'adapte aux formats 18:9 à 21:9 |
| Échelle 3D | 0,85 (bilinéaire) | réduit le coût GPU, interface à pleine résolution |
| MSAA 3D | désactivé | trop coûteux sur mobile au stade prototype |
| Ombres | 2048 px, filtrage doux désactivé sur mobile | compromis qualité et performance |
| Images par seconde | 60 max, synchro verticale | combat à 60 Hz (docs : Système de combat §12) |
| Physique | 60 ticks/s, 4 sous-pas max | logique de combat à pas fixe |
| Compression de textures | ETC2/ASTC | obligatoire pour l'export Android |
| Architecture | arm64-v8a uniquement | couvre les téléphones actuels, APK plus léger |

Le rendu photoréaliste visé par la direction artistique n'est **pas** atteignable sur la plupart des téléphones Android. Ce socle vise d'abord un combat fluide et lisible ; la qualité visuelle sera montée par paliers mesurés sur de vrais appareils.

## État réel (mission 003)

Trois niveaux distincts : **programmé** (le code existe), **testé automatiquement** (un test de `tests/test_runner.gd` le vérifie en CI, sans écran, avec des touchers simulés), **vérifié sur Android** (constaté par l'auteur sur un vrai téléphone).

| Fonctionnalité | Programmé | Testé automatiquement | Vérifié sur Android |
| --- | --- | --- | --- |
| Deux combattants, vie, chronomètre, boutons visibles | oui | oui (test de fumée) | **oui** (APK de la mission 002) |
| Déplacement tactile maintenu, position conservée au relâchement | oui | oui (toucher simulé sur le vrai bouton) | non (correctif à vérifier) |
| Déplacement libre, limites de l'arène, poussée de l'adversaire | oui | oui | non |
| Caméra à zone morte, repères au sol | oui | oui (glissement à l'écran < 25 px) | non |
| Attaque légère et attaque lourde (poses provisoires) | oui | oui (dégâts 7,5 et 17,5, recul) | non |
| Une attaque ne touche qu'une fois | oui | oui (tête et torse touchés ensemble, 1 seul dégât) | non |
| Garde (bouclier maintenu) | oui | oui (20 % des dégâts) | non |
| Parade (garde levée moins de 8 frames avant l'impact) | oui | oui (0 dégât, attaquant déséquilibré) | non |
| Esquive (double flèche) | oui | oui (invulnérable, aucun dégât) | non |
| Réaction au coup, recul, arrêt sur image, éclat rouge, effet d'impact | oui | oui | non |
| K.O., écran du vainqueur, « Rejouer » | oui | oui | non |
| Victoire au temps | oui | oui | non |
| IA : approche, attaque, garde, esquive | oui | oui (10 attaques en 10 s, jamais figée) | non |
| Dégâts | **provisoires** (`force × 0,25`) | oui | non |

## Reste à développer (dans l'ordre conseillé)

1. Vérifier sur téléphone le nouvel APK : déplacement, attaques, garde, parade, esquive, victoire, revanche.
2. Équilibrage : l'IA met un joueur immobile K.O. en moins de 10 secondes ; durées, dégâts et agressivité à régler en main.
3. Animations : remplacer les poses provisoires par de vraies animations (squelette, transitions).
4. Portage GDScript du Damage Priority & Resolution System, en reprenant les 21 tests du prototype JavaScript, puis branchement dans `DamageService`.
5. Interface : Souffle, Kalé, statut ; indication visuelle de la parade réussie.
6. Mesures de performance sur 2 ou 3 téléphones de gammes différentes et budget par plateforme.
7. Signature de release (clé conservée en secret GitHub).
