# Compilation Android — procédure reproductible

L'APK de debug d'OKÉLUN est produit par **GitHub Actions** ; on peut donc tout piloter depuis un téléphone, sans installer d'outils.

## Depuis un téléphone (procédure principale)

1. Pousser un commit qui modifie `game/` sur une branche `godot/...` ou sur `main`. La compilation démarre seule. On peut aussi la lancer à la main : onglet **Actions** du dépôt GitHub → **Android build (Godot)** → **Run workflow**.
2. Attendre la fin de l'exécution, environ 5 à 10 minutes la première fois puis moins grâce au cache.
3. Ouvrir l'exécution → section **Artifacts** → télécharger `okelun-android-debug-<commit>`. C'est un fichier ZIP qui contient `okelun-debug.apk`.
4. Extraire l'APK et l'ouvrir sur le téléphone. Android demande d'autoriser l'installation d'applications de source inconnue pour l'application utilisée (navigateur ou gestionnaire de fichiers).

Les artefacts sont conservés 14 jours. Les journaux d'import, du test de fumée et de l'export sont publiés dans l'artefact `godot-logs-<commit>`, même en cas d'échec.

## Ce que fait la CI (`.github/workflows/android-build.yml`)

| Étape | Rôle | Échec si |
| --- | --- | --- |
| Java 17 | requis par les outils de signature Android | — |
| Godot 4.4.1 + modèles d'export | versions figées, mises en cache | téléchargement impossible |
| SDK Android + clé de debug | SDK préinstallé sur le runner ; clé générée à chaque exécution | SDK absent |
| Import du projet | construit le cache Godot | erreur de script ou de chargement |
| Test de fumée | lance la scène principale 120 frames en mode headless | « SMOKE TEST OK » absent |
| Tests de gameplay | 14 scénarios (déplacement tactile, attaques, garde, parade, esquive, victoire, IA) | « TESTS OK » absent |
| Export | `--export-debug "Android"` → `build/okelun-debug.apk` | APK absent ou vide |
| Publication | artefact téléchargeable | — |

## Sur un ordinateur (optionnel)

1. Installer Godot 4.4.1, les modèles d'export 4.4.1 (Éditeur → Gérer les modèles d'export), le JDK 17 et le SDK Android (via Android Studio ou les outils en ligne de commande).
2. Éditeur → Paramètres de l'éditeur → Export → Android : renseigner le chemin du SDK Android et du JDK.
3. Projet → Exporter → preset **Android** → Exporter le projet, ou en ligne de commande :
   `godot --headless --path game --export-debug "Android" build/okelun-debug.apk`
4. Avec un téléphone en débogage USB : `adb install -r build/okelun-debug.apk`.

## Limites actuelles

- **APK de debug uniquement** : il est signé avec une clé jetable, il ne peut pas être publié sur un store et chaque nouvelle version doit remplacer l'ancienne (désinstaller si Android refuse la mise à jour).
- **Pour une version de release**, il faudra une clé de signature conservée en secret GitHub (`ANDROID_KEYSTORE_BASE64`, mot de passe, alias) et un second job `--export-release`. Ce n'est pas encore en place.
- **Architecture** : arm64-v8a uniquement ; les très vieux téléphones 32 bits ne sont pas couverts.
- **Vérification** : la compilation automatique ne prouve pas que le jeu fonctionne sur un téléphone. Ce n'est vérifié qu'après installation sur un appareil réel.
