// §32 PRIORITÉ 3 — résistance des matériaux.
// Unités abstraites : l'énergie d'impact et la résistance partagent la même échelle.
import { AttackType, Element } from './constants.js';

/**
 * resistance   : énergie qu'une couche intacte peut arrêter en un impact.
 * hardness     : 0..1, capacité à dévier coupe/perforation.
 * toughness    : réserve structurelle (plus elle est haute, moins chaque coup entame l'intégrité).
 * brittleness  : 0..1, tendance à fissurer/éclater plutôt qu'à se déformer.
 * damping      : 0..1, fraction d'énergie contondante dissipée (rembourrage).
 * vulnerability: sensibilité structurelle selon le type d'attaque.
 * failureMode  : 'brittle' (fissure → éclat), 'ductile' (déformation → rupture), 'fabric' (déchirure).
 * tierThresholds / tierEfficiency : §36, variables selon le matériau.
 */
const DEFAULT_TIERS = { light: 0.875, heavy: 0.625, critical: 0.375 };
const DEFAULT_EFFICIENCY = { intact: 1, light_damage: 0.85, heavy_damage: 0.6, critical: 0.3, destroyed: 0 };

const base = (o) => ({
  tierThresholds: DEFAULT_TIERS,
  tierEfficiency: DEFAULT_EFFICIENCY,
  flammable: 0,
  conductive: 0,
  ...o,
  vulnerability: {
    [AttackType.SLASH]: 1, [AttackType.BLUNT]: 1, [AttackType.PIERCE]: 1,
    [AttackType.HEAVY]: 1, [AttackType.EXPLOSIVE]: 1, [AttackType.ELEMENTAL]: 1,
    ...(o.vulnerability ?? {}),
  },
});

export const MATERIALS = Object.freeze({
  cloth: base({
    resistance: 6, hardness: 0.02, toughness: 25, brittleness: 0, damping: 0.1,
    failureMode: 'fabric', flammable: 1,
    vulnerability: { slash: 1.8, pierce: 1.3, blunt: 0.3 },
  }),
  leather: base({
    resistance: 18, hardness: 0.15, toughness: 60, brittleness: 0.05, damping: 0.25,
    failureMode: 'fabric', flammable: 0.5,
    vulnerability: { slash: 1.3, pierce: 1.1, blunt: 0.5 },
  }),
  wood: base({
    resistance: 35, hardness: 0.3, toughness: 90, brittleness: 0.55, damping: 0.3,
    failureMode: 'brittle', flammable: 0.8,
    vulnerability: { slash: 1.1, heavy: 1.4, blunt: 1.1 },
  }),
  glass: base({
    resistance: 10, hardness: 0.6, toughness: 15, brittleness: 1, damping: 0.05,
    failureMode: 'brittle',
    tierEfficiency: { intact: 1, light_damage: 0.6, heavy_damage: 0.3, critical: 0.1, destroyed: 0 },
    vulnerability: { blunt: 2.2, heavy: 2.5, pierce: 1.5 },
  }),
  light_metal: base({
    resistance: 55, hardness: 0.65, toughness: 140, brittleness: 0.2, damping: 0.15,
    failureMode: 'ductile', conductive: 0.9,
    vulnerability: { slash: 0.6, pierce: 0.9, blunt: 1.1, heavy: 1.3 },
  }),
  heavy_metal: base({
    resistance: 90, hardness: 0.85, toughness: 260, brittleness: 0.3, damping: 0.2,
    failureMode: 'ductile', conductive: 1,
    vulnerability: { slash: 0.4, pierce: 0.7, blunt: 1, heavy: 1.2 },
  }),
  composite: base({
    resistance: 70, hardness: 0.55, toughness: 180, brittleness: 0.35, damping: 0.5,
    failureMode: 'brittle', conductive: 0.2,
    vulnerability: { slash: 0.7, pierce: 0.8, blunt: 0.8, heavy: 1.1 },
  }),
  stone: base({
    resistance: 80, hardness: 0.75, toughness: 120, brittleness: 0.85, damping: 0.35,
    failureMode: 'brittle',
    vulnerability: { slash: 0.3, pierce: 0.5, blunt: 1.4, heavy: 1.8 },
  }),
  supernatural: base({
    resistance: 120, hardness: 0.9, toughness: 400, brittleness: 0.1, damping: 0.6,
    failureMode: 'ductile',
    vulnerability: { elemental: 0.5 },
  }),
});

export function getMaterial(name) {
  const m = MATERIALS[name];
  if (!m) throw new Error(`Matériau inconnu : ${name}`);
  return m;
}

/**
 * §34 — attaque élémentaire : propriétés du matériau + conditions environnementales.
 * Retourne des multiplicateurs appliqués à la couche.
 */
export function elementalModifiers(material, element, environment = {}) {
  const out = { resistance: 1, structural: 1, passThrough: 0, effects: [] };
  if (!element) return out;
  const wet = environment.wet ? 1 : 0;
  const temp = environment.temperature ?? 15; // °C
  switch (element) {
    case Element.FIRE: {
      const envMul = (1 - 0.5 * wet) * (temp > 30 ? 1.2 : 1);
      out.structural = (1 + material.flammable * 1.5) * envMul;
      out.resistance = 1 - material.flammable * 0.5;
      out.passThrough = material.conductive * 0.4; // le métal transmet la chaleur
      if (material.flammable > 0.4 && !wet) out.effects.push('ignite');
      break;
    }
    case Element.COLD: {
      const envMul = temp < 0 ? 1.2 : 1;
      out.structural = 0.4 * envMul;
      if (material.failureMode !== 'fabric') out.effects.push('embrittle');
      break;
    }
    case Element.LIGHTNING: {
      const envMul = 1 + 0.5 * wet;
      out.resistance = 1 - material.conductive * 0.8;
      out.passThrough = Math.min(0.95, material.conductive * 0.7 * envMul);
      out.structural = 0.3;
      break;
    }
    case Element.ACID: {
      out.structural = material.failureMode === 'ductile' ? 1.8 : 1.2;
      out.effects.push('corrode');
      break;
    }
    default: break;
  }
  return out;
}
