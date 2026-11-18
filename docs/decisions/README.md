| Traçabilité | |
| --- | --- |
| Document | OKÉLUN — Registre des décisions |
| Version | 0.1.0 |
| Date | 2026-11-18 (création et dernière révision connues) |
| Statut | Ouvert — aucune décision enregistrée à ce jour |
| Source | Créé lors de la centralisation documentaire |
| Documents associés | [Index documentaire](../README.md), [Cahier des charges](../vision/cahier-des-charges.md) |

<!-- FIN EN-TÊTE DE TRAÇABILITÉ -->

# Registre des décisions

Ce dossier contient une note par décision de conception ou d’architecture. Une décision n’existe que si elle est écrite ici et approuvée par l’auteur du projet. **Aucune décision n’a encore été prise.**

## Format d’une décision

Fichier `NNNN-titre-court.md` (ex. `0001-chaine-de-resolution.md`) :

```markdown
# NNNN — Titre

- Statut : proposée | approuvée | remplacée par NNNN
- Date :
- Décideur :
- Exigences concernées : A§n, B§n
- Documents impactés :

## Contexte
## Options étudiées
## Décision
## Conséquences
```

## Questions en attente de décision

Ces points ont été relevés par les audits du 2026-11-18. Ils sont listés, **pas tranchés**.

| # | Question | Sources en conflit |
| --- | --- | --- |
| Q1 | Numérotation : la partie B (§32–48) remplace-t-elle ou prolonge-t-elle les §32–35 de la partie A ? | Cahier des charges A et B |
| Q2 | Chaîne de résolution canonique : 11 étapes (B§47, Damage System), 11 étapes de A§9, ou 12 étapes avec FATIGUE (A§32, Système de combat §1) ? | A§9, A§32, B§47 |
| Q3 | Réseau : serveur autoritaire sans rollback ou netcode à rollback ? | Damage System §20, Système de combat §12 |
| Q4 | Persistance des dégâts en Ranked : par set ou par manche ? | Modes de jeu, Système de combat §13 |
| Q5 | Casse des armes : « probabilité » ou déterminisme strict ? | A§13, B§37 |
| Q6 | Exception d’Ekissa (annule ses propres dégâts) face à la non-réinitialisation | Bible §8, A§31, B§48 |
| Q7 | Défaite par hémorragie, effets de la douleur et du dommage interne | Damage System §12–13, Système de combat §13 |
| Q8 | Mode « classique » sans persistance pour l’e-sport | Système de combat §13 |
