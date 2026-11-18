// Énumérations et constantes partagées du Damage Priority & Resolution System.

export const AttackType = Object.freeze({
  SLASH: 'slash',         // tranchante
  BLUNT: 'blunt',         // contondante
  PIERCE: 'pierce',       // perforante
  HEAVY: 'heavy',         // lourde
  EXPLOSIVE: 'explosive', // explosive
  ELEMENTAL: 'elemental', // élémentaire
});

export const Element = Object.freeze({
  FIRE: 'fire',
  COLD: 'cold',
  LIGHTNING: 'lightning',
  ACID: 'acid',
});

// §32 PRIORITÉ 1 — ordre de localisation (de l'extérieur vers l'intérieur).
export const LayerKind = Object.freeze({
  WEAPON: 'weapon',
  SHIELD: 'shield',
  HELMET: 'helmet',
  ARMOR: 'armor',
  SECONDARY: 'secondary',
  CLOTHING: 'clothing',
  SKIN: 'skin',
  BODY: 'body',
});

export const LAYER_PRIORITY = Object.freeze([
  LayerKind.WEAPON,
  LayerKind.SHIELD,
  LayerKind.HELMET,
  LayerKind.ARMOR,
  LayerKind.SECONDARY,
  LayerKind.CLOTHING,
  LayerKind.SKIN,
  LayerKind.BODY,
]);

export const layerRank = (kind) => {
  const i = LAYER_PRIORITY.indexOf(kind);
  return i < 0 ? LAYER_PRIORITY.length : i;
};

export const BodyZone = Object.freeze({
  HEAD: 'head',
  NECK: 'neck',
  TORSO: 'torso',
  ABDOMEN: 'abdomen',
  LEFT_SHOULDER: 'left_shoulder',
  RIGHT_SHOULDER: 'right_shoulder',
  LEFT_ARM: 'left_arm',
  RIGHT_ARM: 'right_arm',
  LEFT_HAND: 'left_hand',
  RIGHT_HAND: 'right_hand',
  LEFT_LEG: 'left_leg',
  RIGHT_LEG: 'right_leg',
});

// §36 — paliers d'intégrité.
export const IntegrityTier = Object.freeze({
  INTACT: 'intact',         // 100 %
  LIGHT: 'light_damage',    // 75 %
  HEAVY: 'heavy_damage',    // 50 %
  CRITICAL: 'critical',     // 25 %
  DESTROYED: 'destroyed',   // 0 %
});

export const WoundType = Object.freeze({
  CUT: 'cut',
  LACERATION: 'laceration',
  PUNCTURE: 'puncture',
  CONTUSION: 'contusion',
  FRACTURE: 'fracture',
  CRUSH: 'crush',
  BURN: 'burn',
  FROSTBITE: 'frostbite',
  SHOCK: 'shock',
  BLAST: 'blast',
});

export const OPEN_WOUNDS = Object.freeze(new Set([
  WoundType.CUT, WoundType.LACERATION, WoundType.PUNCTURE, WoundType.CRUSH, WoundType.BLAST,
]));

// §48 — seules ces raisons autorisent une restauration.
export const RestoreReason = Object.freeze({
  HEAL: 'heal',
  REPAIR: 'repair',
  REST: 'rest',
  REPLACE_EQUIPMENT: 'replace_equipment',
  NEW_PHASE: 'new_phase',
});

// §47 — chaîne officielle de résolution.
export const RESOLUTION_CHAIN = Object.freeze([
  'IMPACT', 'LOCALISATION', 'PROTECTION', 'MATERIAU', 'ABSORPTION', 'TRANSMISSION',
  'DOMMAGE', 'BLESSURE', 'SAIGNEMENT', 'CONSEQUENCE', 'PERSISTANCE',
]);
