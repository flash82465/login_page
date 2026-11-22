# OKÉLUN — revue visuelle de la mission 005

Images produites par le banc de capture (workflow « Revue visuelle (planches) ») : le vrai jeu, rendu image par image. Cette branche ne contient que ces images et leurs pages.

Étapes : [etape-1-capsule](etape-1-capsule/index.md) · [etape-2-silhouettes](etape-2-silhouettes/index.md) · [etape-3-animations](etape-3-animations/index.md) · [mission-006-integration](mission-006-integration/index.md) · [v06-etape-0-correctif-profondeur](v06-etape-0-correctif-profondeur/index.md) · [v06-etape-0-reference-v050](v06-etape-0-reference-v050/index.md)

## Étape 1 - génération visuelle capsule (v0.1 à v0.4.1)

- Code capturé : [`76b4cf6`](https://github.com/flash82465/login_page/commit/76b4cf6f12c976923e70e74ea9ae468483deeaa1) (branche `godot/android-first`)
- Rendu : Vulkan (llvmpipe (LLVM 20.1.2, 256 bits)), 1920 × 1080, 60 images/s fixes, interface masquée
- **Équivalence avec `version/v0.4.1` : ✅ identique au pixel près sur 207 images sur 207** (états et séquences)
- Exécution : [journal et artefact](https://github.com/flash82465/login_page/actions/runs/44815368428)

Touchez une image pour l'ouvrir en grand, puis zoomez.

### Tandé - attaques

![Tandé - attaques](etape-1-capsule/tande-1-attaques.jpg)

### Tandé - états et réactions

![Tandé - états et réactions](etape-1-capsule/tande-2-etats.jpg)

### Mabé - attaques

![Mabé - attaques](etape-1-capsule/mabe-1-attaques.jpg)

### Mabé - états et réactions

![Mabé - états et réactions](etape-1-capsule/mabe-2-etats.jpg)

### Séquences animées

**Échange Tandé contre Mabé, vitesse réelle : approche, coup, garde contre coup lourd, esquive, parade** (385 Ko)

![Échange Tandé contre Mabé, vitesse réelle : approche, coup, garde contre coup lourd, esquive, parade](etape-1-capsule/combat.gif)

**Attaque légère de Tandé qui touche Mabé, ralenti x4 (une image par frame de jeu)** (282 Ko)

![Attaque légère de Tandé qui touche Mabé, ralenti x4 (une image par frame de jeu)](etape-1-capsule/attaque-legere-ralenti.gif)


## Étape 2 - silhouettes de Tandé et Mabé (poses fixes)

- Code capturé : [`1d3f2b4`](https://github.com/flash82465/login_page/commit/1d3f2b445054b326fde3ba2f554077ddde9e70da) (branche `godot/android-first`)
- Rendu : Vulkan (llvmpipe (LLVM 20.1.2, 256 bits)), 1920 × 1080, 60 images/s fixes, interface masquée
- **Repli capsule : équivalence avec `version/v0.4.1` : ✅ identique au pixel près sur 207 images sur 207** (états et séquences)
- Exécution : [journal et artefact](https://github.com/flash82465/login_page/actions/runs/44867952840)

Touchez une image pour l'ouvrir en grand, puis zoomez.

### Tandé seul

![Tandé seul](etape-2-silhouettes/tande-1-seul.jpg)

### Mabé seul

![Mabé seul](etape-2-silhouettes/mabe-1-seul.jpg)

### Tandé et Mabé ensemble

![Tandé et Mabé ensemble](etape-2-silhouettes/ensemble-2-les-deux.jpg)

### Noir pur, sans couleurs

![Noir pur, sans couleurs](etape-2-silhouettes/ensemble-3-noir-pur.jpg)

### Au contact (0,7 m, distance minimale)

![Au contact (0,7 m, distance minimale)](etape-2-silhouettes/ensemble-4-contact.jpg)

### Taille réelle sur téléphone : début du combat (3 m) (ouvrir en plein écran, téléphone à l'horizontale)

![Taille réelle sur téléphone : début du combat (3 m) (ouvrir en plein écran, téléphone à l'horizontale)](etape-2-silhouettes/telephone-1-debut.jpg)

### Taille réelle sur téléphone : approche (1,4 m) (ouvrir en plein écran, téléphone à l'horizontale)

![Taille réelle sur téléphone : approche (1,4 m) (ouvrir en plein écran, téléphone à l'horizontale)](etape-2-silhouettes/telephone-2-approche.jpg)

### Taille réelle sur téléphone : au contact, Mabé en garde (ouvrir en plein écran, téléphone à l'horizontale)

![Taille réelle sur téléphone : au contact, Mabé en garde (ouvrir en plein écran, téléphone à l'horizontale)](etape-2-silhouettes/telephone-3-contact.jpg)


## Étape 3 - six animations des pantins Tandé et Mabé

- Code capturé : [`3eeb838`](https://github.com/flash82465/login_page/commit/3eeb838abeaa0a43651e4f00b61118bf44dd14b2) (branche `godot/android-first`)
- Rendu : Vulkan (llvmpipe (LLVM 20.1.2, 256 bits)), 1920 × 1080, 60 images/s fixes, interface masquée
- **Repli capsule : équivalence avec `version/v0.4.1` : ✅ identique au pixel près sur 207 images sur 207** (états et séquences)
- Exécution : [journal et artefact](https://github.com/flash82465/login_page/actions/runs/44872412154)

Touchez une image pour l'ouvrir en grand, puis zoomez.

### Tandé - animations

![Tandé - animations](etape-3-animations/tande-animations.jpg)

### Mabé - animations

![Mabé - animations](etape-3-animations/mabe-animations.jpg)

### Séquences animées

**Vrai combat : Tandé contre Mabé, chacun piloté par l'IA du jeu (12 s, vitesse réelle)** (2582 Ko)

![Vrai combat : Tandé contre Mabé, chacun piloté par l'IA du jeu (12 s, vitesse réelle)](etape-3-animations/combat-ia.gif)

**Le même combat en vidéo (30 images/s, plus fluide)** : [ouvrir la vidéo MP4](etape-3-animations/combat-ia-video.mp4) (271 Ko)

**Coups au ralenti (x3) : légère de Tandé, lourde de Mabé bloquée, lourde de Tandé, légère de Mabé ; zone de frappe en rouge quand elle est active** (3993 Ko)

![Coups au ralenti (x3) : légère de Tandé, lourde de Mabé bloquée, lourde de Tandé, légère de Mabé ; zone de frappe en rouge quand elle est active](etape-3-animations/coups-ralenti.gif)


## Mission 006 - jeu intégré V0.5.0 (pantins et capsules)

- Code capturé : [`84b3f6f`](https://github.com/flash82465/login_page/commit/84b3f6fc81f9064d93ab4870d09e61b3b0dad9bc) (branche `godot/android-first`)
- Rendu : Vulkan (llvmpipe (LLVM 20.1.2, 256 bits)), 1920 × 1080, 60 images/s fixes, interface masquée
- **Repli capsule : équivalence avec `version/v0.4.1` : ✅ identique au pixel près sur 207 images sur 207** (états et séquences)
- Exécution : [journal et artefact](https://github.com/flash82465/login_page/actions/runs/44873991875)

Touchez une image pour l'ouvrir en grand, puis zoomez.

### Le jeu au démarrage : pantins animés par défaut, bouton Visuel sous le chronomètre

![Le jeu au démarrage : pantins animés par défaut, bouton Visuel sous le chronomètre](mission-006-integration/jeu-1-demarrage.jpg)

### Combat en cours avec les pantins animés

![Combat en cours avec les pantins animés](mission-006-integration/jeu-2-combat-pantins.jpg)

### Après un toucher sur le bouton Visuel : combat neuf avec les capsules historiques

![Après un toucher sur le bouton Visuel : combat neuf avec les capsules historiques](mission-006-integration/jeu-3-combat-capsules.jpg)

### Fin de combat avec les pantins : K.O., écran du vainqueur et bouton Rejouer

![Fin de combat avec les pantins : K.O., écran du vainqueur et bouton Rejouer](mission-006-integration/jeu-4-resultat-pantins.jpg)

### Séquences animées

**Jeu intégré : 5 s avec les pantins, toucher sur le bouton Visuel, 5 s avec les capsules** (1249 Ko)

![Jeu intégré : 5 s avec les pantins, toucher sur le bouton Visuel, 5 s avec les capsules](mission-006-integration/jeu-integre.gif)

**La même séquence en vidéo (30 images/s)** : [ouvrir la vidéo MP4](mission-006-integration/jeu-integre-video.mp4) (203 Ko)


## V0.6-A étape 0 - correctif du bouton Profondeur (NON / OUI)

- Code capturé : [`9254b25`](https://github.com/flash82465/login_page/commit/9254b25187d6115ee57f96b7e86d7614cf468349) (branche `godot/android-first`)
- Rendu : Vulkan (llvmpipe (LLVM 20.1.2, 256 bits)), 1920 × 1080, 60 images/s fixes, interface masquée
- **Repli capsule : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 207 images sur 207**
- **Pantins animés : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 712 images sur 712**
- **Jeu complet, hors zone des boutons Visuel et Profondeur : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 420 images sur 420** (zone exclue : x 0.287-0.713, y 0.094-0.283 de l'image)
- Exécution : [journal et artefact](https://github.com/flash82465/login_page/actions/runs/45049105587)

Touchez une image pour l'ouvrir en grand, puis zoomez.

### Le jeu au démarrage : pantins animés par défaut, bouton Visuel sous le chronomètre

![Le jeu au démarrage : pantins animés par défaut, bouton Visuel sous le chronomètre](v06-etape-0-correctif-profondeur/jeu-1-demarrage.jpg)

### Combat en cours avec les pantins animés

![Combat en cours avec les pantins animés](v06-etape-0-correctif-profondeur/jeu-2-combat-pantins.jpg)

### Après un toucher sur le bouton Visuel : combat neuf avec les capsules historiques

![Après un toucher sur le bouton Visuel : combat neuf avec les capsules historiques](v06-etape-0-correctif-profondeur/jeu-3-combat-capsules.jpg)

### Fin de combat avec les pantins : K.O., écran du vainqueur et bouton Rejouer

![Fin de combat avec les pantins : K.O., écran du vainqueur et bouton Rejouer](v06-etape-0-correctif-profondeur/jeu-4-resultat-pantins.jpg)

### Bouton Profondeur sous le bouton Visuel : désactivé par défaut

![Bouton Profondeur sous le bouton Visuel : désactivé par défaut](v06-etape-0-correctif-profondeur/jeu-5-profondeur-desactivee.jpg)

### Après un toucher : option activée (enregistrée), combat neuf ; étape 0 : encore sans effet sur le combat

![Après un toucher : option activée (enregistrée), combat neuf ; étape 0 : encore sans effet sur le combat](v06-etape-0-correctif-profondeur/jeu-6-profondeur-activee.jpg)

### Séquences animées

**Jeu intégré : 5 s avec les pantins, toucher sur le bouton Visuel, 5 s avec les capsules** (1242 Ko)

![Jeu intégré : 5 s avec les pantins, toucher sur le bouton Visuel, 5 s avec les capsules](v06-etape-0-correctif-profondeur/jeu-integre.gif)

**La même séquence en vidéo (30 images/s)** : [ouvrir la vidéo MP4](v06-etape-0-correctif-profondeur/jeu-integre-video.mp4) (206 Ko)


## V0.6-A étape 0 - référence visuelle V0.5.0 (capsules, pantins, jeu complet)

- Code capturé : [`1fb22a2`](https://github.com/flash82465/login_page/commit/1fb22a2f820f09d9d0f38130a30d52f2437bdf65) (branche `godot/android-first`)
- Rendu : Vulkan (llvmpipe (LLVM 20.1.2, 256 bits)), 1920 × 1080, 60 images/s fixes, interface masquée
- **Repli capsule : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 207 images sur 207**
- **Pantins animés : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 712 images sur 712**
- **Jeu complet, hors zone des boutons Visuel et Profondeur : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 420 images sur 420** (zone exclue : x 0.287-0.713, y 0.094-0.283 de l'image)
- Exécution : [journal et artefact](https://github.com/flash82465/login_page/actions/runs/45039143410)

Touchez une image pour l'ouvrir en grand, puis zoomez.

### Le jeu au démarrage : pantins animés par défaut, bouton Visuel sous le chronomètre

![Le jeu au démarrage : pantins animés par défaut, bouton Visuel sous le chronomètre](v06-etape-0-reference-v050/jeu-1-demarrage.jpg)

### Combat en cours avec les pantins animés

![Combat en cours avec les pantins animés](v06-etape-0-reference-v050/jeu-2-combat-pantins.jpg)

### Après un toucher sur le bouton Visuel : combat neuf avec les capsules historiques

![Après un toucher sur le bouton Visuel : combat neuf avec les capsules historiques](v06-etape-0-reference-v050/jeu-3-combat-capsules.jpg)

### Fin de combat avec les pantins : K.O., écran du vainqueur et bouton Rejouer

![Fin de combat avec les pantins : K.O., écran du vainqueur et bouton Rejouer](v06-etape-0-reference-v050/jeu-4-resultat-pantins.jpg)

### Bouton Profondeur sous le bouton Visuel : désactivé par défaut

![Bouton Profondeur sous le bouton Visuel : désactivé par défaut](v06-etape-0-reference-v050/jeu-5-profondeur-desactivee.jpg)

### Après un toucher : option activée (enregistrée), combat neuf ; étape 0 : encore sans effet sur le combat

![Après un toucher : option activée (enregistrée), combat neuf ; étape 0 : encore sans effet sur le combat](v06-etape-0-reference-v050/jeu-6-profondeur-activee.jpg)

### Séquences animées

**Jeu intégré : 5 s avec les pantins, toucher sur le bouton Visuel, 5 s avec les capsules** (1246 Ko)

![Jeu intégré : 5 s avec les pantins, toucher sur le bouton Visuel, 5 s avec les capsules](v06-etape-0-reference-v050/jeu-integre.gif)

**La même séquence en vidéo (30 images/s)** : [ouvrir la vidéo MP4](v06-etape-0-reference-v050/jeu-integre-video.mp4) (209 Ko)

