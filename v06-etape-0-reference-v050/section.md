## V0.6-A étape 0 - référence visuelle V0.5.0 (capsules, pantins, jeu complet)

- Code capturé : [`d1d8c0e`](https://github.com/flash82465/login_page/commit/d1d8c0e52c76be41220aa0b8f9f42397786a0597) (branche `godot/android-first`)
- Rendu : Vulkan (llvmpipe (LLVM 20.1.2, 256 bits)), 1920 × 1080, 60 images/s fixes, interface masquée
- **Repli capsule : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 207 images sur 207**
- **Pantins animés : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 712 images sur 712**
- **Jeu complet, hors zone du bouton Profondeur : équivalence avec `version/v0.5.0` : ✅ identique au pixel près sur 420 images sur 420** (zone exclue : x 0.296-0.704, y 0.182-0.271 de l'image)
- Exécution : [journal et artefact](https://github.com/flash82465/login_page/actions/runs/45037687056)

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

