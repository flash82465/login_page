# OKÉLUN — consignes permanentes

## Dépôt, branches et rôles

- **Dépôt GitHub** : `flash82465/login_page`
- **Branche de développement active** : `godot/android-first`
- **Référence stable (figée)** : `version/v0.5.0`
- **Attention** : la branche par défaut `main` contient uniquement une ancienne page HTML/CSS (`login page`) ; le jeu OKÉLUN se trouve sur `godot/android-first`.
- **Rôles** :
  - **Créateur** : directeur créatif et décideur du projet.
  - **Agent** : exécutant technique.

## Méthode de développement

`État de référence → Mission précise → Modification minimale → Tests → Vérification → Validation par le créateur.`

## Règles permanentes de travail

1. Ne jamais reconstruire le jeu à partir d'une description.
2. Ne jamais remplacer, supprimer ou réécrire les systèmes existants sans demande explicite.
3. Préserver les personnages Tandé et Mabé, leurs silhouettes, leurs animations, leurs proportions, l'arène, la caméra, les contrôles, les systèmes de combat et l'architecture.
4. Toute modification doit être ciblée et minimale.
5. Ne pas modifier plusieurs systèmes simultanément pour une seule mission.
6. Avant toute modification, identifier précisément les fichiers concernés et expliquer brièvement pourquoi.
7. Ne jamais considérer une idée personnelle comme une demande du créateur.
8. Ne jamais déclarer un test réussi s'il n'a pas réellement été exécuté.
9. Distinguer clairement dans chaque compte rendu : **analyse**, **modification effectuée**, **tests réellement exécutés** et **éléments non vérifiés**.
10. Ne jamais fusionner directement une modification importante dans la version stable.
11. Préserver l'historique Git et créer des commits clairs pour chaque mission validée.
12. En cas de doute sur le comportement attendu, arrêter et demander une clarification plutôt que deviner.

## Règle absolue de gestion des versions

- Ne jamais demander à l'utilisateur de désinstaller une ancienne version pour installer une nouvelle.
- Chaque version distribuée pour test possède un applicationId Android distinct (`org.okelun.prototype.vX_Y_Z`), un nom identifiable (« OKÉLUN V0.X »), la signature stable (secrets `OKELUN_KEYSTORE_BASE64` / `OKELUN_KEYSTORE_PASSWORD`) et son propre APK conservé (release `apk-archive`).
- Les anciennes versions restent installables simultanément. Ne jamais écraser, supprimer ou modifier une ancienne version (branches `version/vX.Y.Z` figées) : une correction devient une nouvelle version.
- Avant toute nouvelle compilation, vérifier que ces conditions sont respectées (la CI le contrôle : `.github/workflows/android-build.yml`).
- Une migration technique se prépare sans supprimer les installations existantes.
- Ne jamais commiter de clé de signature : le dépôt est public.

Détails et procédures : `game/ANDROID_BUILD.md`.
