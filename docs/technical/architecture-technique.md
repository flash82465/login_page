| Traçabilité | |
| --- | --- |
| Document | OKÉLUN — Architecture technique |
| Version | 0.1.0 |
| Date | 2026-11-18 (création et dernière révision connues) |
| Statut | Ébauche — document nouveau : état constaté et renvois ; ne contient aucune décision de conception |
| Source | Créé lors de la centralisation documentaire ; constats issus de l’audit du projet du 2026-11-18 |
| Documents associés | [Damage System](damage-system.md), [Système de combat](../gameplay/systeme-combat.md) (§12), [Direction artistique](../art-audio/direction-artistique.md) (§7), [Décisions](../decisions/README.md) |

<!-- FIN EN-TÊTE DE TRAÇABILITÉ -->

# OKÉLUN — Architecture technique

Aucun document de conception existant n’est consacré à l’architecture technique globale. Ce fichier ne fait que **constater l’état actuel** et **renvoyer** vers les sections existantes qui traitent d’architecture. Il ne contient aucune décision nouvelle.

## État constaté du dépôt (2026-11-18)

| Élément | Constat |
| --- | --- |
| Moteur de jeu | aucun |
| Code du jeu | aucun, hors prototype logique des dégâts |
| Prototype des dégâts | `damage-system/` : JavaScript (modules ES), Node 22, aucune dépendance, 12 modules source, 21 tests (21 réussis) |
| Autre contenu du dépôt | page de connexion statique sans rapport (`index.html`, `index2.html`, `index.css`, `index2.css`, `img/`) |
| Branche du prototype | `claude/damage-priority-system-axfx15`, pull request #1 ouverte vers `main` |

## Où se trouve l’architecture déjà documentée

| Sujet | Document et section |
| --- | --- |
| Architecture du système de dégâts (modules, chaîne, pipeline) | [Damage System](damage-system.md), §1 |
| Persistance, journal, rendu dérivé de l’état | [Damage System](damage-system.md), §16 à §18 |
| Adaptation à Unreal Engine 5 (C++, Blueprints, GAS, réseau autoritaire) | [Damage System](damage-system.md), §20 |
| Risques techniques | [Damage System](damage-system.md), §21 |
| Frames, netcode à rollback, déterminisme, Training | [Système de combat](../gameplay/systeme-combat.md), §12 |
| Qualité graphique et objectifs de performance | [Direction artistique](../art-audio/direction-artistique.md), §7 |

## Contradiction connue (non résolue)

Le [Damage System](damage-system.md) §20 prévoit un serveur autoritaire sans rollback ; le [Système de combat](../gameplay/systeme-combat.md) §12 exige un netcode à rollback. Voir `docs/decisions/README.md`.
