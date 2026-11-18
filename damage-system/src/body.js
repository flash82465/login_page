// §39 blessures, §44 membres, §33 transmission → conséquences physiques.
import { AttackType, BodyZone, Element, WoundType } from './constants.js';

/** Caractéristiques des zones corporelles. */
export const BODY_ZONES = Object.freeze({
  [BodyZone.HEAD]: { toughness: 45, bleedFactor: 1.3, healthMult: 1.6, limb: 'head', balanceThreshold: 35 },
  [BodyZone.NECK]: { toughness: 30, bleedFactor: 2, healthMult: 1.8, limb: 'head', balanceThreshold: 50 },
  [BodyZone.TORSO]: { toughness: 80, bleedFactor: 1, healthMult: 1.2, limb: 'torso', balanceThreshold: 70 },
  [BodyZone.ABDOMEN]: { toughness: 60, bleedFactor: 1.2, healthMult: 1.2, limb: 'torso', balanceThreshold: 70 },
  [BodyZone.LEFT_SHOULDER]: { toughness: 60, bleedFactor: 0.9, healthMult: 0.8, limb: 'arm', balanceThreshold: 80 },
  [BodyZone.RIGHT_SHOULDER]: { toughness: 60, bleedFactor: 0.9, healthMult: 0.8, limb: 'arm', balanceThreshold: 80 },
  [BodyZone.LEFT_ARM]: { toughness: 50, bleedFactor: 0.9, healthMult: 0.6, limb: 'arm', balanceThreshold: 90 },
  [BodyZone.RIGHT_ARM]: { toughness: 50, bleedFactor: 0.9, healthMult: 0.6, limb: 'arm', balanceThreshold: 90 },
  [BodyZone.LEFT_HAND]: { toughness: 30, bleedFactor: 0.7, healthMult: 0.4, limb: 'hand', balanceThreshold: 120 },
  [BodyZone.RIGHT_HAND]: { toughness: 30, bleedFactor: 0.7, healthMult: 0.4, limb: 'hand', balanceThreshold: 120 },
  [BodyZone.LEFT_LEG]: { toughness: 70, bleedFactor: 1.1, healthMult: 0.7, limb: 'leg', balanceThreshold: 40 },
  [BodyZone.RIGHT_LEG]: { toughness: 70, bleedFactor: 1.1, healthMult: 0.7, limb: 'leg', balanceThreshold: 40 },
});

export function bodyZoneDef(zone) {
  const z = BODY_ZONES[zone];
  if (!z) throw new Error(`Zone corporelle inconnue : ${zone}`);
  return z;
}

/** §34/§39 — type de blessure selon l'attaque et l'énergie. */
export function classifyWound(attackType, element, penEnergy, bluntEnergy, zoneDef) {
  if (attackType === AttackType.ELEMENTAL) {
    if (element === Element.FIRE) return WoundType.BURN;
    if (element === Element.COLD) return WoundType.FROSTBITE;
    if (element === Element.LIGHTNING) return WoundType.SHOCK;
    if (element === Element.ACID) return WoundType.BURN;
  }
  if (penEnergy > 0.5) {
    switch (attackType) {
      case AttackType.SLASH: return penEnergy > zoneDef.toughness * 0.6 ? WoundType.LACERATION : WoundType.CUT;
      case AttackType.PIERCE: return WoundType.PUNCTURE;
      case AttackType.HEAVY: return WoundType.CRUSH;
      case AttackType.EXPLOSIVE: return WoundType.BLAST;
      default: break;
    }
  }
  if (bluntEnergy > zoneDef.toughness * 1.2 && zoneDef.limb !== 'torso') return WoundType.FRACTURE;
  return WoundType.CONTUSION;
}

/** §44 — effets progressifs par type de membre ; plancher = jamais incapable d'agir. */
export function limbModifiers(limbs, minFunction) {
  const f = (zones) => {
    const vals = zones.map((z) => Math.max(minFunction, limbs[z]?.function ?? 1));
    return vals.reduce((a, b) => a + b, 0) / vals.length;
  };
  const arms = f([BodyZone.LEFT_ARM, BodyZone.RIGHT_ARM, BodyZone.LEFT_SHOULDER, BodyZone.RIGHT_SHOULDER]);
  const hands = f([BodyZone.LEFT_HAND, BodyZone.RIGHT_HAND]);
  const legs = f([BodyZone.LEFT_LEG, BodyZone.RIGHT_LEG]);
  const head = f([BodyZone.HEAD, BodyZone.NECK]);
  const torso = f([BodyZone.TORSO, BodyZone.ABDOMEN]);
  const animations = [];
  for (const [zone, l] of Object.entries(limbs)) {
    if (l.function < 0.6) animations.push(`${zone}_impaired`);
  }
  return {
    attackSpeed: 0.6 + 0.4 * arms,
    guardStability: 0.5 + 0.5 * arms,
    grip: 0.5 + 0.5 * hands,
    weaponHandling: 0.55 + 0.45 * Math.min(hands, arms),
    moveSpeed: 0.55 + 0.45 * legs,
    dodge: 0.5 + 0.5 * legs,
    staggerResistance: 0.6 + 0.4 * head,
    staminaRegen: 0.6 + 0.4 * torso,
    animations,
  };
}
