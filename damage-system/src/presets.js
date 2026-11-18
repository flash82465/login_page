// Combattant d'exemple avec géométrie simplifiée (espace local, mètres ; +Z = avant du personnage).
import { BodyZone, LayerKind } from './constants.js';
import { DamageState } from './damageState.js';
import { EquipmentPiece } from './equipment.js';

export const KNIGHT_BODY_COLLIDERS = [
  { shape: 'sphere', center: [0, 1.65, 0], radius: 0.11, bodyZone: BodyZone.HEAD },
  { shape: 'box', min: [-0.06, 1.48, -0.06], max: [0.06, 1.54, 0.06], bodyZone: BodyZone.NECK },
  { shape: 'box', min: [-0.18, 1.15, -0.11], max: [0.18, 1.48, 0.11], bodyZone: BodyZone.TORSO },
  { shape: 'box', min: [-0.16, 0.92, -0.1], max: [0.16, 1.15, 0.1], bodyZone: BodyZone.ABDOMEN },
  { shape: 'sphere', center: [-0.24, 1.42, 0], radius: 0.07, bodyZone: BodyZone.LEFT_SHOULDER },
  { shape: 'sphere', center: [0.24, 1.42, 0], radius: 0.07, bodyZone: BodyZone.RIGHT_SHOULDER },
  { shape: 'box', min: [-0.3, 0.95, -0.05], max: [-0.2, 1.36, 0.05], bodyZone: BodyZone.LEFT_ARM },
  { shape: 'box', min: [0.2, 0.95, -0.05], max: [0.3, 1.36, 0.05], bodyZone: BodyZone.RIGHT_ARM },
  { shape: 'sphere', center: [-0.25, 0.88, 0], radius: 0.05, bodyZone: BodyZone.LEFT_HAND },
  { shape: 'sphere', center: [0.25, 0.88, 0], radius: 0.05, bodyZone: BodyZone.RIGHT_HAND },
  { shape: 'box', min: [-0.16, 0, -0.07], max: [-0.02, 0.92, 0.07], bodyZone: BodyZone.LEFT_LEG },
  { shape: 'box', min: [0.02, 0, -0.07], max: [0.16, 0.92, 0.07], bodyZone: BodyZone.RIGHT_LEG },
];

export function createKnight(combatantId = 'knight', { withShield = true } = {}) {
  const s = new DamageState({ combatantId, bodyColliders: KNIGHT_BODY_COLLIDERS });
  s.equip(new EquipmentPiece({
    id: `${combatantId}_helmet`, name: 'Casque', kind: LayerKind.HELMET, material: 'heavy_metal',
    covers: [BodyZone.HEAD],
    zones: { face: {}, visor: {}, joint: {}, attachment: {} },
    colliders: [
      { shape: 'box', min: [-0.04, 1.62, 0.1], max: [0.04, 1.68, 0.14], zone: 'visor' },
      { shape: 'sphere', center: [0, 1.66, 0], radius: 0.13, zone: 'face' },
      { shape: 'box', min: [-0.07, 1.5, 0.06], max: [0.07, 1.54, 0.12], zone: 'attachment' },
    ],
  }));
  s.equip(new EquipmentPiece({
    id: `${combatantId}_breastplate`, name: 'Plastron', kind: LayerKind.ARMOR, material: 'heavy_metal',
    covers: [BodyZone.TORSO, BodyZone.ABDOMEN],
    zones: { plastron: {}, joint: {}, attachment: {} },
    colliders: [
      { shape: 'box', min: [-0.2, 1.13, -0.13], max: [0.2, 1.5, 0.13], zone: 'plastron' },
      { shape: 'box', min: [-0.18, 0.92, -0.12], max: [0.18, 1.13, 0.12], zone: 'joint' },
      { shape: 'box', min: [0.18, 1.36, -0.03], max: [0.22, 1.46, 0.03], zone: 'attachment' },
    ],
  }));
  s.equip(new EquipmentPiece({
    id: `${combatantId}_pauldrons`, name: 'Épaulières', kind: LayerKind.ARMOR, material: 'light_metal',
    covers: [BodyZone.LEFT_SHOULDER, BodyZone.RIGHT_SHOULDER], zones: { shoulder: {}, attachment: {} },
    colliders: [
      { shape: 'sphere', center: [-0.24, 1.43, 0], radius: 0.09, zone: 'shoulder' },
      { shape: 'sphere', center: [0.24, 1.43, 0], radius: 0.09, zone: 'shoulder' },
    ],
  }));
  s.equip(new EquipmentPiece({
    id: `${combatantId}_bracers`, name: 'Brassards', kind: LayerKind.SECONDARY, material: 'leather',
    covers: [BodyZone.LEFT_ARM, BodyZone.RIGHT_ARM],
  }));
  s.equip(new EquipmentPiece({
    id: `${combatantId}_gambeson`, name: 'Gambison', kind: LayerKind.CLOTHING, material: 'cloth',
    covers: [BodyZone.TORSO, BodyZone.ABDOMEN, BodyZone.LEFT_ARM, BodyZone.RIGHT_ARM, BodyZone.LEFT_SHOULDER, BodyZone.RIGHT_SHOULDER],
  }));
  s.equip(new EquipmentPiece({
    id: `${combatantId}_trousers`, name: 'Chausses', kind: LayerKind.CLOTHING, material: 'cloth',
    covers: [BodyZone.LEFT_LEG, BodyZone.RIGHT_LEG],
  }));
  if (withShield) {
    s.equip(new EquipmentPiece({
      id: `${combatantId}_shield`, name: 'Bouclier', kind: LayerKind.SHIELD, material: 'wood', heldBy: BodyZone.LEFT_ARM,
      zones: { main: {}, attachment: { resistance: 0.4, vulnerability: 2, attachment: true, detachThreshold: 0.6 } },
      colliders: [{ shape: 'box', min: [-0.45, 0.9, 0.25], max: [-0.1, 1.45, 0.3], zone: 'main' }],
    }));
  }
  s.equip(createSword(`${combatantId}_sword`, { heldBy: BodyZone.RIGHT_HAND }));
  return s;
}

export function createSword(id = 'sword', overrides = {}) {
  return new EquipmentPiece({
    id, name: 'Épée', kind: LayerKind.WEAPON, material: 'light_metal', mass: 1.4,
    zones: { blade: {}, edge: {}, flat: {}, guard: {}, tang: {} }, defaultZone: 'blade',
    ...overrides,
  });
}

/** Rayon d'attaque frontal visant un point du corps (depuis 1 m devant). */
export function frontalStrike(target, { from = [0, 0, 1] } = {}) {
  const origin = [target[0] + from[0], target[1] + from[1], target[2] + from[2]];
  return { origin, direction: [target[0] - origin[0], target[1] - origin[1], target[2] - origin[2]] };
}
