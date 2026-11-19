# OKÉLUN — Prototype Godot 4 (Android first)

Socle du premier prototype jouable d'OKÉLUN, avec Godot 4.4.1 et Android comme cible prioritaire. Ce dossier ne remplace ni ne modifie le prototype logique des dégâts (`damage-system/`, PR #1) ni la documentation (`docs/`).

## Ouvrir et lancer

- **Godot 4.4.1** (éditeur standard, pas la version .NET) : ouvrir `game/project.godot`, puis F5.
- **Clavier (ordinateur)** : A/D ou flèches pour se déplacer ; J, K, L et Espace sont réservés aux attaques légère et lourde, à la parade et à l'esquive (pas encore actives).
- **Écran tactile** : les boutons à l'écran déclenchent les mêmes actions.
- **Test de fumée** : `godot --headless --path game -- --smoke-test` charge la scène principale, la simule 120 frames, vérifie le socle et quitte avec le code 0 (succès) ou 1 (échec).
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

## État réel

Échelle : *Conçu* (dans les documents) → *Implémenté* (code présent) → *Testé* (vérifié automatiquement) → *Validé* (essayé et approuvé sur appareil).

| Élément | Statut | Détail |
| --- | --- | --- |
| Projet Godot, configuration mobile | Implémenté | `project.godot`, `export_presets.cfg` |
| Scène de combat, arène, caméra | Implémenté | caméra qui suit et recule selon l'écart |
| Deux combattants | Implémenté | capsules provisoires, masses 92 et 110 kg |
| Déplacements | Implémenté | inertie selon la masse, orientation, couloir Z = 0 |
| Attaques | Conçu | données prêtes (`AttackData`), `Fighter.request_attack` vide |
| Parade | Conçu | action et bouton prêts, `Fighter.request_block` vide |
| Esquive | Conçu | action et bouton prêts, `Fighter.request_dodge` vide |
| Détection des impacts | Implémenté, non déclenché | hitbox, hurtbox et déduplication ; aucune attaque ne l'active encore |
| Barre de vie et timer | Implémenté | reliés aux signaux du combattant |
| Interface tactile | Implémenté | 6 boutons multitouch reliés aux actions |
| IA basique | Partiel | s'approche à distance de garde, n'attaque pas |
| Dégâts | Provisoire | `DamageService` applique `force × 0,25` ; portage du vrai système à faire |
| Compilation Android | Préparé | workflow GitHub Actions ; voir ANDROID_BUILD.md |
| Exécution sur un appareil Android | **Non testé** | aucun APK n'a encore été lancé sur un téléphone |

## Reste à développer (dans l'ordre conseillé)

1. Valider la chaîne de compilation : premier APK produit par la CI, installé et lancé sur un téléphone.
2. Attaques légère et lourde : machine à états démarrage, frames actives, récupération ; activation de la hitbox.
3. Réaction aux coups : étourdissement, recul physique, K.O. et fin de manche.
4. Parade (avec usure) et esquive (avec fenêtre d'invulnérabilité).
5. IA : choix d'attaque, de parade et d'esquive selon la distance et l'état adverse.
6. Portage GDScript du Damage Priority & Resolution System, en reprenant les 21 tests du prototype JavaScript, puis branchement dans `DamageService`.
7. Interface : Souffle, Kalé, statut ; écran de fin de manche.
8. Mesures de performance sur 2 ou 3 téléphones de gammes différentes et budget par plateforme.
9. Signature de release et publication (keystore en secret GitHub).
