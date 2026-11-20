# OKÉLUN — Prototype Godot 4 (Android first)

Socle du premier prototype jouable d'OKÉLUN (version **0.4.1** : jeu de la 0.4.0, installable à côté des versions précédentes), avec Godot 4.4.1 et Android comme cible prioritaire. Ce dossier ne remplace ni ne modifie le prototype logique des dégâts (`damage-system/`, PR #1) ni la documentation (`docs/`).

## Ouvrir et lancer

- **Godot 4.4.1** (éditeur standard, pas la version .NET) : ouvrir `game/project.godot`, puis F5.
- **Clavier (ordinateur)** : A/D ou flèches pour se déplacer, J attaque légère, K attaque lourde, L garde (maintenir), Espace esquive.
- **Écran tactile** : flèches à gauche ; à droite, bouclier (garde), petit rond (attaque légère), grand rond (attaque lourde), double flèche (esquive).
- **Tests de gameplay** : `godot --headless --path game --fixed-fps 60 res://tests/test_runner.tscn` (22 tests, code de sortie 0 si tout passe).
- **Test de fumée** : `godot --headless --path game -- --smoke-test`.
- **APK Android, versions et points de restauration** : voir [ANDROID_BUILD.md](ANDROID_BUILD.md).

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
4. Pendant les frames actives d'une attaque, sa `Hitbox` détecte les `Hurtbox` adverses (tête, torse, jambes), une seule fois par coup et par cible.
5. Le `MatchController` (traité après les deux combattants) met les touches de la frame en file, puis les résout ensemble par le `DamageService` : deux coups portés dans la même frame touchent tous les deux, quel que soit l'ordre des nœuds. Il vérifie ensuite les K.O. (deux K.O. simultanés = égalité), puis le chronomètre. Le `Hud` suit le signal `health_changed`.

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

## État réel (version 0.4.0, mission 004)

Trois niveaux distincts : **programmé** (le code existe), **testé automatiquement** (un test de `tests/test_runner.gd` le vérifie en CI, sans écran, avec des touchers simulés), **vérifié sur Android** (constaté par l'auteur sur un vrai téléphone).

L'auteur a constaté un premier combat fonctionnel sur téléphone avec l'APK de la mission 003, sans détailler chaque point. Ce code est conservé comme version 0.3.0 (l'APK affichait encore le numéro interne 0.1.0). « 0.3.0 (global) » veut donc dire que la fonction existait dans cet APK et que le combat a été jugé fonctionnel, pas que ce point précis a été contrôlé. Aucune fonction n'a encore été vérifiée sur téléphone avec les versions 0.4.0 et 0.4.1 ; leur jeu est identique.

| Fonctionnalité | Programmé | Testé automatiquement | Vérifié sur Android |
| --- | --- | --- | --- |
| Deux combattants, vie, chronomètre, boutons visibles | oui | oui (test de fumée) | **oui** (APK des missions 002 et 003) |
| Déplacement tactile maintenu, position conservée au relâchement | oui | oui (toucher simulé sur le vrai bouton) | 0.3.0 (global) |
| Glisser le doigt d'une flèche à l'autre sans le relever | oui | oui (nouveau test 0.4.0) | non |
| Multitouch : flèche maintenue + attaque, flèche + bouclier | oui | oui (nouveau test 0.4.0) | non |
| Déplacement libre, limites de l'arène, poussée de l'adversaire | oui | oui | 0.3.0 (global) |
| Caméra à zone morte, recentrée à chaque revanche | oui | oui | 0.3.0 (global) ; recentrage : non |
| Attaque légère et attaque lourde (poses provisoires) | oui | oui (dégâts 7,5 et 17,5, recul) | 0.3.0 (global) |
| Une attaque ne touche qu'une fois | oui | oui | 0.3.0 (global) |
| Coups simultanés : les deux combattants sont touchés | oui (0.4.0) | oui | non |
| Garde (bouclier maintenu) | oui | oui (20 % des dégâts) | 0.3.0 (global) |
| Parade : garde levée moins de 8 frames avant l'impact, au plus une fenêtre toutes les 30 frames | oui | oui (parade réussie ; marteler le bouclier = simple garde) | non (modifiée en 0.4.0) |
| Esquive (double flèche) | oui | oui (invulnérable, aucun dégât) | 0.3.0 (global) |
| Réaction au coup, recul, arrêt sur image, éclat rouge, effet d'impact | oui | oui | 0.3.0 (global) |
| K.O. et vainqueur (joueur ou IA) ; double K.O. = égalité | oui | oui | non (corrigé en 0.4.0) |
| « Rejouer » : n'importe quel doigt, revanches successives, aucune attaque fantôme | oui | oui | non (corrigé en 0.4.0) |
| Victoire au temps | oui | oui | 0.3.0 (global) |
| IA : approche, attaque, garde préventive, esquive, punition, gestion de la distance | oui | oui (jamais figée plus de 2 s ; mesure d'équilibrage) | non (modifiée en 0.4.0) |
| Dégâts | **provisoires** (`force × 0,25`) | oui | non |

### Équilibrage de l'IA mesuré en CI (3 graines aléatoires, 60 images/s)

| Joueur simulé | Résultat |
| --- | --- |
| Immobile, sans défense | K.O. en 15,8 à 19,7 s (avant la mission 004 : moins de 10 s) ; l'IA attaque 9 à 11 fois |
| Avance et martèle l'attaque légère, sans jamais se protéger | **gagne** en 8,9 à 11,0 s en gardant 62,5 à 92,5 PV ; l'IA n'attaque que 4 à 6 fois |

Ces joueurs simulés sont volontairement frustes : ils mesurent des bornes, pas le ressenti. Résultat : l'IA n'est plus expéditive contre un joueur passif, mais un simple martèlement de l'attaque légère la bat. C'est le principal défaut d'équilibrage restant ; le test vérifie seulement que les deux combattants se touchent. La difficulté face à un vrai joueur, qui se déplace, se protège et esquive, reste à juger sur téléphone. Les réglages sont les variables exportées de `scripts/ai/ai_controller.gd`.

## Reste à développer (dans l'ordre conseillé)

1. Vérifier sur téléphone l'APK 0.4.1 (« OKÉLUN V0.4.1 ») : K.O. et vainqueur, « Rejouer » (avec un 2e doigt posé, plusieurs revanches), multitouch, glissé entre les flèches, parade, difficulté de l'IA.
2. Équilibrage : l'IA perd contre un joueur qui martèle l'attaque légère (elle garde trop rarement et riposte trop peu). Piste : garde adaptative quand l'adversaire enchaîne les attaques, puis punition pendant sa récupération, réglée d'après le ressenti sur téléphone.
3. Signature de release (la clé stable des versions de test est en place depuis 0.4.1, voir [ANDROID_BUILD.md](ANDROID_BUILD.md)).
4. Animations : remplacer les poses provisoires par de vraies animations (squelette, transitions).
5. Portage GDScript du Damage Priority & Resolution System, en reprenant les 21 tests du prototype JavaScript, puis branchement dans `DamageService`.
6. Interface : Souffle, Kalé, statut ; indication visuelle de la parade réussie.
7. Mesures de performance sur 2 ou 3 téléphones de gammes différentes et budget par plateforme.
