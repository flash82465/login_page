# Compilation Android — procédure reproductible

L'APK de debug d'OKÉLUN est produit par **GitHub Actions** ; on peut donc tout piloter depuis un téléphone, sans installer d'outils.

## Règle absolue de gestion des versions

- On ne demande jamais de désinstaller une ancienne version pour installer une nouvelle.
- Chaque version distribuée pour test a **son propre identifiant Android** (`org.okelun.prototype.v0_4_1` pour 0.4.1), **un nom identifiable** sur le téléphone (« OKÉLUN V0.4.1 », « OKÉLUN V0.5 » pour 0.5.0), **la même signature stable** et **son propre APK conservé**.
- Les versions restent installables simultanément. Une version publiée n'est jamais écrasée, supprimée ni modifiée : toute correction devient une nouvelle version.
- Une migration technique se prépare sans toucher aux installations existantes.

La CI applique cette règle **avant chaque compilation**, puis contrôle l'APK produit. Si une condition manque, elle s'arrête sans produire d'APK :

| Contrôle | Avant la compilation | Sur l'APK produit |
| --- | --- | --- |
| Identifiant propre à la version | calculé depuis `version/name` ; jamais `org.okelun.prototype` (anciens APK déjà installés) | lu dans l'APK (`aapt2`) |
| Nom « OKÉLUN V0.X » | calculé depuis la version | lu dans l'APK |
| Signature stable | clé des secrets GitHub, empreinte comparée à celle inscrite dans la CI | certificat de l'APK comparé (`apksigner`) |
| Version non modifiée | une branche `version/vX.Y.Z` déjà publiée qui reçoit un commit fait échouer la compilation | — |
| Cohérence | la branche ou le tag correspond à la version du projet | numéro de version lu dans l'APK |

Les essais de développement (branches `godot/...`) portent un identifiant à part, `org.okelun.prototype.dev`, et le nom « OKÉLUN DEV ». Ils ne remplacent donc jamais une version. Seuls les APK de version sont distribués pour test.

## Mise en place unique (à faire une fois, depuis GitHub)

1. **Clé de signature stable** : dépôt → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Créer deux secrets avec les valeurs fournies hors du dépôt :
   - `OKELUN_KEYSTORE_PASSWORD`
   - `OKELUN_KEYSTORE_BASE64`

   Le dépôt est public : la clé ne doit jamais y être commitée. Seule son empreinte publique figure dans la CI (`OKELUN_CERT_SHA256`). Gardez une copie privée des deux valeurs.
2. **Archive permanente des APK** : dépôt → **Releases** → **Draft a new release** → **Choose a tag** : saisir `apk-archive` → **Create new tag** → titre « OKÉLUN — archive des APK » → **Publish release**. Chaque compilation de version y dépose ensuite son APK, sans limite de durée et sans jamais écraser un fichier existant. Ce nom de tag ne déclenche aucune compilation.

## Depuis un téléphone (procédure principale)

1. Une version se compile depuis sa branche `version/vX.Y.Z`. Si la création de la branche ne lance pas la compilation (c'est le cas quand le commit existe déjà sur une autre branche), la lancer à la main : onglet **Actions** → **Android build (Godot)** → **Run workflow**, en choisissant la branche.
2. Attendre la fin de l'exécution (5 à 10 minutes).
3. Télécharger l'APK : release **apk-archive** (fichier `okelun-vX.Y.Z-debug.apk`), ou section **Artifacts** de l'exécution (fichier ZIP).
4. Ouvrir l'APK sur le téléphone. Il s'installe **à côté** des versions déjà présentes, sous le nom « OKÉLUN V… ». Android peut demander d'autoriser l'installation d'applications de source inconnue pour le navigateur ou le gestionnaire de fichiers.

| Déclencheur | Application installée | Nom de l'APK | Conservation |
| --- | --- | --- | --- |
| Branche de version `version/v0.4.1` | OKÉLUN V0.4.1 (`org.okelun.prototype.v0_4_1`) | `okelun-v0.4.1-debug.apk` | release `apk-archive` sans limite ; artefact 90 jours |
| Tag `v0.4.1` (facultatif) | identique à la branche de version | identique | idem (l'exemplaire déjà archivé n'est pas remplacé) |
| Branche de travail (`godot/...`, `main`) | OKÉLUN DEV (`org.okelun.prototype.dev`) | `okelun-v0.4.1-dev-<commit>-debug.apk` | artefact 14 jours |

Les journaux (import, test de fumée, tests, export, contrôle de l'APK) sont publiés dans l'artefact `godot-logs-<commit>`, même en cas d'échec.

## Ce que fait la CI (`.github/workflows/android-build.yml`)

| Étape | Rôle | Échec si |
| --- | --- | --- |
| Java 17 | requis par les outils de signature Android | — |
| Godot 4.4.1 + modèles d'export | versions figées, mises en cache | téléchargement impossible |
| SDK Android | SDK préinstallé sur le runner | SDK absent |
| Import du projet | construit le cache Godot | erreur de script ou de chargement |
| Test de fumée | lance la scène principale 120 frames en mode headless | « SMOKE TEST OK » absent |
| Tests de gameplay | 22 scénarios (tactile et multitouch, attaques, coups simultanés, garde, parade, esquive, K.O., double K.O., « Rejouer », IA et mesure d'équilibrage) | « TESTS OK » absent |
| Règle des versions | identifiant, nom, clé stable, version non modifiée (voir plus haut) | une condition manque |
| Export | `--export-debug "Android"` → `build/okelun-<version>-debug.apk` | APK absent ou vide |
| Contrôle de l'APK | identifiant, nom, version et signature lus dans l'APK | APK non conforme |
| Publication | artefact ; pour une version, dépôt dans la release `apk-archive` | — |

**Conserver d'anciens APK sans les recompiler** : **Run workflow** avec le champ `archive_runs`, par exemple `[{"run": "44470978370", "label": "v0.3.0"}]`. L'APK d'origine est copié octet pour octet (empreinte SHA-256 affichée) dans un artefact de 90 jours et, si elle existe, dans la release `apk-archive`.

## Versions et points de restauration

Aucune version n'est supprimée. Chaque version garde une branche `version/vX.Y.Z` figée.

| Version | Contenu | Code | Application sur le téléphone | APK conservé |
| --- | --- | --- | --- | --- |
| mission 002 | socle, déplacement | commit `b296050` | « OKÉLUN » (`org.okelun.prototype`) | `okelun-mission002-b296050-debug.apk` |
| 0.3.0 | mission 003 : premier combat jouable | branche `version/v0.3.0` (`961e110`) | « OKÉLUN » (`org.okelun.prototype`) | `okelun-v0.3.0-debug.apk` (et la compilation antérieure `okelun-mission003-6984db6-debug.apk`, même jeu) |
| 0.4.0 | mission 004 : stabilisation | branche `version/v0.4.0` (`c5ae145`) | « OKÉLUN » (`org.okelun.prototype`) | `okelun-v0.4.0-debug.apk` |
| 0.4.1 | 0.4.0 + règle des versions (identifiant, nom, signature stable) ; jeu identique à 0.4.0 | branche `version/v0.4.1` | **« OKÉLUN V0.4.1 »** (`org.okelun.prototype.v0_4_1`) | `okelun-v0.4.1-debug.apk` |

**Limite héritée, non corrigée pour ne pas modifier d'anciennes versions** : les APK antérieurs à 0.4.1 partagent l'identifiant `org.okelun.prototype` et ont chacun une clé de debug différente. Un seul d'entre eux peut être présent sur un téléphone. Celui qui est installé y reste ; ne pas installer l'APK 0.4.0 par-dessus (Android le refuserait). À partir de 0.4.1, toutes les versions s'installent côte à côte.

**Revenir à une version** : installer son APK conservé (tableau ci-dessus). Ne jamais recompiler une version antérieure à 0.4.1 : son workflow utilisait une clé jetable. Pour reprendre son code : `git checkout -b <nouvelle-branche> origin/version/v0.3.0`.

**Préparer une nouvelle version** :
1. Augmenter `version/name` et `version/code` dans `export_presets.cfg`, et `config/version` dans `project.godot`.
2. Valider les tests en CI sur la branche de travail.
3. Créer la branche `version/vX.Y.Z` sur le commit validé.

Les tags `vX.Y.Z` sont facultatifs : ils servent de repères et recompilent la même version à l'identique.

## Sur un ordinateur (optionnel)

1. Installer Godot 4.4.1, les modèles d'export 4.4.1 (Éditeur → Gérer les modèles d'export), le JDK 17 et le SDK Android (via Android Studio ou les outils en ligne de commande).
2. Éditeur → Paramètres de l'éditeur → Export → Android : renseigner le chemin du SDK Android et du JDK. La clé stable n'est pas nécessaire pour un essai local. Un export local porte l'identifiant `org.okelun.prototype.dev`, donc il ne touche jamais une version installée.
3. Projet → Exporter → preset **Android** → Exporter le projet, ou en ligne de commande :
   `godot --headless --path game --export-debug "Android" build/okelun-dev-debug.apk`

## Limites actuelles

- **APK de debug uniquement** : il ne peut pas être publié sur un store. Une version de release demandera un second job `--export-release` ; elle pourra réutiliser la clé stable.
- **Architecture** : arm64-v8a uniquement ; les très vieux téléphones 32 bits ne sont pas couverts.
- **Vérification** : la compilation automatique ne prouve pas que le jeu fonctionne sur un téléphone. Ce n'est vérifié qu'après installation sur un appareil réel.
