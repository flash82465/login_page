# Compilation Android — procédure reproductible

L'APK de debug d'OKÉLUN est produit par **GitHub Actions** ; on peut donc tout piloter depuis un téléphone, sans installer d'outils.

## Depuis un téléphone (procédure principale)

1. Pousser un commit qui modifie `game/` (ou le workflow) sur une branche `godot/...`, `version/...` ou sur `main`, ou créer un tag `v...`. La compilation démarre seule. On peut aussi la lancer à la main : onglet **Actions** du dépôt GitHub → **Android build (Godot)** → **Run workflow**.
2. Attendre la fin de l'exécution, environ 5 à 10 minutes la première fois puis moins grâce au cache.
3. Ouvrir l'exécution → section **Artifacts** → télécharger l'artefact `okelun-...-debug`. C'est un fichier ZIP qui contient l'APK du même nom (voir le nommage ci-dessous).
4. Extraire l'APK et l'ouvrir sur le téléphone. Android demande d'autoriser l'installation d'applications de source inconnue pour l'application utilisée (navigateur ou gestionnaire de fichiers). **Si Android refuse l'installation par-dessus une version précédente, désinstaller d'abord l'ancienne** (voir « Limites actuelles »).

| Déclencheur | Nom de l'APK | Conservation |
| --- | --- | --- |
| Branche de travail (`godot/...`, `main`) | `okelun-v0.4.0-dev-<commit>-debug.apk` | 14 jours |
| Branche de version `version/v0.4.0` | `okelun-v0.4.0-debug.apk` | 90 jours |
| Tag `v0.4.0` | `okelun-v0.4.0-debug.apk`, aussi joint à la release GitHub | artefact 90 jours, release sans limite |

Le numéro vient de `version/name` dans `export_presets.cfg`. Pour un tag, la CI refuse de compiler si le tag ne correspond pas à ce numéro. Les journaux d'import, du test de fumée et de l'export sont publiés dans l'artefact `godot-logs-<commit>`, même en cas d'échec.

## Ce que fait la CI (`.github/workflows/android-build.yml`)

| Étape | Rôle | Échec si |
| --- | --- | --- |
| Java 17 | requis par les outils de signature Android | — |
| Godot 4.4.1 + modèles d'export | versions figées, mises en cache | téléchargement impossible |
| SDK Android + clé de debug | SDK préinstallé sur le runner ; clé générée à chaque exécution | SDK absent |
| Import du projet | construit le cache Godot | erreur de script ou de chargement |
| Test de fumée | lance la scène principale 120 frames en mode headless | « SMOKE TEST OK » absent |
| Tests de gameplay | 22 scénarios (tactile et multitouch, attaques, coups simultanés, garde, parade, esquive, K.O., double K.O., « Rejouer », IA et mesure d'équilibrage) | « TESTS OK » absent |
| Nommage | lit la version et choisit le nom de l'APK et la durée de conservation | tag différent de la version |
| Export | `--export-debug "Android"` → `build/okelun-<version>-debug.apk` | APK absent ou vide |
| Publication | artefact téléchargeable ; release GitHub (préversion) si tag `v...` | — |

## Versions et points de restauration

Aucune version n'est supprimée : chaque version validée garde une branche `version/vX.Y.Z` figée, qu'on ne modifie plus.

| Version | Contenu | Point de restauration | APK | Tag |
| --- | --- | --- | --- | --- |
| 0.3.0 | mission 003 : premier combat jouable | branche `version/v0.3.0` (commit `961e110`) | artefact `okelun-android-debug-961e110…` de la mission 003 (14 jours ; l'APK affiche le numéro interne 0.1.0) ; ensuite, **Run workflow** sur la branche `version/v0.3.0` le recompile | `v0.3.0` à créer depuis GitHub |
| 0.4.0 | mission 004 : stabilisation | branche `version/v0.4.0` | artefact `okelun-v0.4.0-debug` (90 jours) | `v0.4.0` à créer depuis GitHub |

**Revenir à une version** : réinstaller son APK (tableau ci-dessus, ou release du tag une fois créé), ou repartir de son code : `git checkout -b <nouvelle-branche> origin/version/v0.3.0`.

**Créer le tag d'une version validée** (depuis un téléphone) : page du dépôt → **Releases** → **Draft a new release** → **Choose a tag** : saisir `v0.4.0` → **Target** : branche `version/v0.4.0` → cocher **Set as a pre-release** → **Publish release**. Le tag déclenche la compilation, qui joint l'APK à cette release. Si la compilation ne démarre pas, la lancer à la main (**Actions** → **Android build (Godot)** → **Run workflow**, en choisissant le tag).

**Préparer une nouvelle version** : augmenter `version/name` et `version/code` dans `export_presets.cfg` et `config/version` dans `project.godot`, valider les tests en CI, puis pousser la branche `version/vX.Y.Z` et créer le tag `vX.Y.Z`.

## Sur un ordinateur (optionnel)

1. Installer Godot 4.4.1, les modèles d'export 4.4.1 (Éditeur → Gérer les modèles d'export), le JDK 17 et le SDK Android (via Android Studio ou les outils en ligne de commande).
2. Éditeur → Paramètres de l'éditeur → Export → Android : renseigner le chemin du SDK Android et du JDK.
3. Projet → Exporter → preset **Android** → Exporter le projet, ou en ligne de commande :
   `godot --headless --path game --export-debug "Android" build/okelun-v0.4.0-debug.apk`
4. Avec un téléphone en débogage USB : `adb install -r build/okelun-v0.4.0-debug.apk`.

## Limites actuelles

- **APK de debug uniquement** : il ne peut pas être publié sur un store.
- **Clé de debug différente à chaque compilation** : Android refuse alors d'installer un APK par-dessus un autre (« application non installée » ou conflit de paquet). Il faut désinstaller l'ancienne version avant d'installer la nouvelle ; le prototype n'enregistre encore aucune donnée, donc rien n'est perdu. Remède prévu : une clé de debug fixe conservée en secret GitHub (non commitée dans le dépôt).
- **Pour une version de release**, il faudra une clé de signature conservée en secret GitHub (`ANDROID_KEYSTORE_BASE64`, mot de passe, alias) et un second job `--export-release`. Ce n'est pas encore en place.
- **Architecture** : arm64-v8a uniquement ; les très vieux téléphones 32 bits ne sont pas couverts.
- **Vérification** : la compilation automatique ne prouve pas que le jeu fonctionne sur un téléphone. Ce n'est vérifié qu'après installation sur un appareil réel.
