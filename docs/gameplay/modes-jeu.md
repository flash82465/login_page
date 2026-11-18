| Traçabilité | |
| --- | --- |
| Document | OKÉLUN — Modes de jeu et persistance (Système de combat, §11) |
| Version | 0.1.0 (source : Système de combat, révision 14) |
| Date | 2026-11-18 (création et dernière révision connues) |
| Statut | Brouillon — conçu et documenté ; non implémenté, non validé |
| Source | Claude Docs « OKÉLUN — Système de combat et modes de jeu », révision 14 ([lien](https://claude.ai/artifact/FFJPMkUML2duUcTwtDrW2R)), export Markdown du 2026-11-18 |
| Documents associés | [Système de combat](systeme-combat.md), [Damage System](../technical/damage-system.md) (§17 tournoi) |

<!-- FIN EN-TÊTE DE TRAÇABILITÉ -->

> Extrait de « Système de combat et modes de jeu » (§11), déplacé sans modification lors de la centralisation documentaire. Le reste du document est dans le fichier d’origine.

<!-- DÉBUT CONTENU DÉPLACÉ -->
## 11. Modes de jeu et persistance

Tous les modes appliquent la non-réinitialisation ; ce qui change d'un mode à l'autre, c'est **l'unité de persistance** et les restaurations prévues entre deux combats.

| Mode | Description | Unité de persistance | Restaurations entre combats |
| --- | --- | --- | --- |
| Histoire | campagne en sept actes (document 1) | toute la campagne | phases narratives : atelier, soins, repos, remplacement |
| Exploration | régions ouvertes, sanctuaires, événements | partagée avec l'Histoire | forges, guérisseurs, consommables trouvés |
| Arcade | 8 combats et un boss, avec scènes de rivalité | toute la série | un repos court entre chaque combat |
| Tournoi | bracket de 8 ou 16 avec phases de préparation | tout le tournoi | budget limité à répartir : atelier, soins, repos, consommable |
| Versus local | match libre | le set (manches et matchs d'un même affrontement) | aucune pendant le set |
| En ligne (non classé) | comme Versus | le set | aucune pendant le set |
| Ranked | compétitif classé, set au meilleur des 3 | le set | aucune pendant le set ; état neuf au set suivant (nouvelle phase explicite) |
| Survie | combats enchaînés jusqu'à la défaite | toute la série | un consommable tous les 5 combats |
| Boss Rush | les sept boss à la suite | toute la série | aucune |
| Training | entraînement et analyse | au choix : persistance ou remise à neuf | remise à neuf explicite par le menu (nouvelle phase) |

### Exemple de tournoi

1. **Combat 1** : l'armure de Tandé sort légèrement endommagée.
2. **Combat 2** : elle reste endommagée ; il choisit de soigner son bras plutôt que de réparer.
3. **Combat 3** : une pièce déjà fissurée se brise.
4. **Combat 4** : il arrive sans cette pièce, faute de budget pour la remplacer.

### Mécaniques de réparation et de soin

| Mécanique | Où | Effet | Limite |
| --- | --- | --- | --- |
| Atelier | forges (Histoire, Exploration), phase de préparation (Tournoi) | répare une pièce non détruite ; les marques de réparation restent visibles | temps et ressources |
| Soins | guérisseurs, phase de préparation | arrête un saignement, réduit une blessure ; la cicatrice reste | une séance par phase |
| Repos | entre deux combats | réduit fatigue et douleur | ne soigne pas les blessures |
| Remplacement | inventaire, marchés | équipe une nouvelle pièce ; l'ancienne est archivée | coût |
| Consommable | objets trouvés ou achetés | effet précis et limité (bandage, pommade, rivets) | quantité |
| Phase narrative | Histoire | restauration prévue par le scénario | écrite, jamais automatique |

**Point à valider** : faire persister les dégâts à l'échelle du set en Ranked impose un netcode capable de sauvegarder et restaurer l'état complet à chaque frame (section 12).

