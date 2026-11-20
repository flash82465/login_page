# OKÉLUN — consignes permanentes

## Règle absolue de gestion des versions

- Ne jamais demander à l'utilisateur de désinstaller une ancienne version pour installer une nouvelle.
- Chaque version distribuée pour test possède un applicationId Android distinct (`org.okelun.prototype.vX_Y_Z`), un nom identifiable (« OKÉLUN V0.X »), la signature stable (secrets `OKELUN_KEYSTORE_BASE64` / `OKELUN_KEYSTORE_PASSWORD`) et son propre APK conservé (release `apk-archive`).
- Les anciennes versions restent installables simultanément. Ne jamais écraser, supprimer ou modifier une ancienne version (branches `version/vX.Y.Z` figées) : une correction devient une nouvelle version.
- Avant toute nouvelle compilation, vérifier que ces conditions sont respectées (la CI le contrôle : `.github/workflows/android-build.yml`).
- Une migration technique se prépare sans supprimer les installations existantes.
- Ne jamais commiter de clé de signature : le dépôt est public.

Détails et procédures : `game/ANDROID_BUILD.md`.
