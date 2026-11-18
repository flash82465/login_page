// §38 — arme contre arme : arme A → point de contact → arme B, calculé séparément pour chaque arme.

const CLASH_SCALE = 0.15;
const r3 = (x) => Math.round(x * 1000) / 1000;

/**
 * @param {{weapon:import('./equipment.js').EquipmentPiece, speed:number, force?:number, zone?:string}} a
 * @param {{weapon:import('./equipment.js').EquipmentPiece, speed:number, force?:number, zone?:string}} b
 * @param {{angle?:number, point?:number[], id?:string, time?:number}} contact
 */
export function resolveWeaponClash(a, b, contact = {}) {
  const angle = contact.angle ?? 0;
  const angleF = 0.4 + 0.6 * Math.cos((Math.min(89.9, Math.abs(angle)) * Math.PI) / 180);
  const kinetic = (s) => 0.5 * s.weapon.mass * s.speed * s.speed + (s.force ?? 0);
  const kA = kinetic(a); const kB = kinetic(b);
  const total = (kA + kB) * angleF;

  const side = (self, other) => {
    const w = self.weapon; const o = other.weapon;
    const zone = self.zone ?? w.defaultZone;
    if (!w.active) return { weapon: w.id, skipped: 'already_broken', events: [] };
    const m = w.materialDef; const om = o.materialDef;
    const hardRatio = (om.hardness + 0.1) / (m.hardness + 0.1);
    const massShare = o.mass / (w.mass + o.mass);
    const weakness = w.localWeakness(zone, contact.point);
    const stateFactor = 1 + (1 - w.efficiency); // §32 P4 / §38 : une arme endommagée encaisse moins bien
    const stress = (total * hardRatio * massShare * 2 * CLASH_SCALE * w.zone(zone).vulnerability * weakness * stateFactor) / m.toughness;
    const integrityBefore = w.integrity;
    const res = w.applyStructuralDamage(stress, { zoneName: zone, position: contact.point, attackType: 'clash', impactId: contact.id, time: contact.time });
    if (zone === 'edge' || zone === 'blade') w.sharpness = Math.max(0, w.sharpness - stress * 0.5);
    return {
      weapon: w.id, zone, stress: r3(stress), weakness: r3(weakness),
      integrityBefore: r3(integrityBefore), integrityAfter: r3(w.integrity), tier: w.tier,
      broken: w.destroyed || w.detached, events: res.events,
    };
  };

  const ra = side(a, b);
  const rb = side(b, a);
  const pA = a.weapon.mass * a.speed; const pB = b.weapon.mass * b.speed;
  return {
    a: ra, b: rb,
    // le côté à plus faible quantité de mouvement est repoussé
    deflected: pA === pB ? 'both' : pA < pB ? 'a' : 'b',
    recoil: r3(Math.abs(pA - pB) / Math.max(1e-6, Math.min(a.weapon.mass, b.weapon.mass))),
    contactPoint: contact.point ? contact.point.map(r3) : null,
    sparks: Math.round(Math.min(40, total / 5 * Math.min(a.weapon.materialDef.hardness, b.weapon.materialDef.hardness))),
  };
}
