# Damage Priority & Resolution System

Module JavaScript (ES modules, aucune dépendance, Node ≥ 18) qui détermine **ce qui se produit réellement lors de chaque impact**, de l'extérieur vers l'intérieur, puis du dommage immédiat vers ses conséquences persistantes.

Il est indépendant du moteur : le moteur fournit soit sa propre liste de surfaces touchées, soit un rayon d'attaque (origine + direction) résolu sur des volumes de collision, soit une simple zone corporelle.

```bash
npm test       # 21 tests, un par règle du cahier des charges
npm run demo   # série de coups, chaîne de résolution, arme contre arme, sauvegarde tournoi
```

## Chaîne officielle (§47)

Chaque appel à `resolver.resolveImpact(state, impact)` produit une trace `chain` contenant **toutes** les étapes, dans l'ordre :

`IMPACT → LOCALISATION → PROTECTION → MATERIAU → ABSORPTION → TRANSMISSION → DOMMAGE → BLESSURE → SAIGNEMENT → CONSEQUENCE → PERSISTANCE`

Une étape sans objet n'est jamais omise : elle est marquée `skipped` avec sa justification (ex. « aucune blessure ouverte »). Le résultat répond aussi explicitement aux cinq questions (`answers`) : ce qui a été touché, ce qui a absorbé, l'énergie transmise, la conséquence physique, ce qui reste visible.

## Utilisation

```js
import { DamageResolver, createKnight, frontalStrike, AttackType } from './src/index.js';

const resolver = new DamageResolver();
const defender = createKnight('chevalier');           // DamageState + équipement + géométrie

const result = resolver.resolveImpact(defender, {
  attackId: 'swing_42',          // identifiant du coup (dédoublonnage §42)
  time: 12.31,
  attackType: AttackType.SLASH,  // slash | blunt | pierce | heavy | explosive | elemental
  element: undefined,            // fire | cold | lightning | acid (attaque élémentaire)
  force: 90,
  attackerWeapon: swordPiece,    // optionnel : l'état de l'arme module la force et s'use
  environment: { wet: false, temperature: 15, dusty: true },
  ...frontalStrike([0.05, 1.3, 0.11]),   // origin + direction
  // ou : hits: [{ pieceId, zone, point, normal, distance }, { bodyZone, point, distance }]
  // ou : bodyZone: 'torso', blockedWith: 'shield_id', pieceZones: { breastplate: 'joint' }
});

defender.update(dt, { movement: 0.7, environment: { rain: 0.3 } }); // saignement, traces
```

## Correspondance avec le cahier des charges

| § | Règle | Implémentation |
|---|---|---|
| 32 P1 | Localisation (arme → bouclier → casque → armure → secondaire → vêtements → peau → corps) | `resolver.localize` : lancer de rayon sur les volumes (`geometry.js`), tri par distance puis `LAYER_PRIORITY` ; les vêtements sans volume épousent la zone touchée |
| 32 P2 | Objet interposé avant le corps | boucle de couches dans `resolveImpact` ; le torse ne reçoit que le résiduel |
| 32 P3 | Résistance du matériau : *force × type × angle* vs *résistance + état* | `materials.js` (tissu, cuir, bois, verre, métal léger/lourd, composite, pierre, surnaturel), `angleFactor`, `ATTACK_PROFILES` |
| 32 P4 | État préexistant | `EquipmentPiece.localWeakness` : fissures proches, déformation, dégâts cumulés de la zone |
| 33 | Transmission | deux canaux : pénétrant et contondant ; l'armure amortit (`damping`) mais transmet → contusion, recul, perte d'équilibre, douleur, fatigue, dommage interne abstrait |
| 34 | Priorité selon le type d'attaque | `ATTACK_PROFILES` (pénétration selon la dureté, transmission, dégâts structurels, recul), `resolveExplosion`, `elementalModifiers` (inflammabilité, conductivité, pluie, température) |
| 35 | Protections successives | ordre physique ; une couche détruite pendant l'impact laisse passer l'énergie qu'elle n'a pas pu absorber |
| 36 | Armures endommagées 100/75/50/25/0 % | `IntegrityTier`, seuils et efficacité par matériau ; détruite/détachée = retirée de la collision et de la défense |
| 37 | Rupture non aléatoire | aucun tirage aléatoire ; progression fissure → déformation → détachement (zones `attachment`) → bris / rupture / lambeaux |
| 38 | Arme contre arme | `resolveWeaponClash` : chaque arme calculée séparément (matériau, masse, dureté, état, vitesse, angle, force) |
| 39 | Blessures | localisation → gravité → type → saignement → conséquences ; volume de sang ∝ gravité² |
| 40 | Saignement indépendant de la vie | `bleeding.js` : début → augmentation → maximum → diminution → résiduel (→ arrêt pour les plaies légères) ; mouvement ; même zone = aggravation et nouvelle courbe, autre zone = nouvelle blessure |
| 41 | Cumul | historique par pièce (`piece.history`) et par combattant (`state.history`) |
| 42 | Impacts multiples | `ImpactQueue` : temps réel → localisation → puissance → surface de contact → priorité de collision ; un même coup n'est compté qu'une fois |
| 43 | Zones vulnérables | `ZONE_PRESETS` : face, visière, plastron, épaule, articulation, fixation… |
| 44 | Membres individuels | `limbModifiers` : bras → vitesse d'attaque/garde, main → prise, jambe → mobilité ; plancher `minLimbFunction` |
| 45 | Gameplay vs réalisme | 1) physique calculée d'abord, 2) lisibilité (budget VFX, événements critiques jamais masqués), 3) plafond de dégâts par coup, 4) suggestions cinématiques subordonnées |
| 46 | Mémoire des dégâts | `DamageState` : pièces, fissures, déformations, déchirures, armes, blessures, sang, poussière, salissures, fatigue, membres ; `toJSON` / `fromJSON` pour le tournoi |
| 47 | Cohérence | trace `chain` + `answers` |
| 48 | Non-réinitialisation | `state.restore(reason)` n'accepte que `heal`, `repair`, `rest`, `replace_equipment`, `new_phase` ; une pièce détruite ne se répare pas (remplacement seulement) ; une blessure soignée reste enregistrée ; la pluie atténue le sang sans l'effacer |

## Structure

```
src/
  constants.js     énumérations (types d'attaque, couches, zones, paliers, chaîne)
  materials.js     matériaux + modificateurs élémentaires/environnementaux
  geometry.js      rayon / sphère / boîte, angle d'incidence
  equipment.js     EquipmentPiece : zones, intégrité, fissures, déformation, déchirures, historique
  body.js          zones corporelles, classification des blessures, effets des membres
  bleeding.js      courbe de saignement
  damageState.js   Damage State persistant, temps, traces, restauration encadrée, sérialisation
  resolver.js      DamageResolver : chaîne complète, explosion, politique de présentation
  weaponClash.js   arme contre arme
  impactQueue.js   impacts multiples
  presets.js       chevalier d'exemple avec géométrie simplifiée
```

## Calibrage

Toutes les valeurs (résistances, ténacités, seuils, plafonds) sont des points de départ réglables : `MATERIALS`, `ZONE_PRESETS`, `BODY_ZONES`, `ATTACK_PROFILES` et la configuration passée à `new DamageResolver({ maxHealthFractionPerHit, minLimbFunction, vfxBudget, … })`. Les unités sont abstraites : l'énergie d'impact et la résistance des matériaux partagent la même échelle.
