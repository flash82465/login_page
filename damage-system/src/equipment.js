// Pièces d'équipement (armes, boucliers, casques, armures, vêtements…) et leur état persistant.
// §36 paliers, §37 rupture déterministe, §41 cumul, §43 zones vulnérables, §48 non-réinitialisation.
import { IntegrityTier, LayerKind } from './constants.js';
import { getMaterial } from './materials.js';
import { vec } from './geometry.js';

/** §43 — zones par défaut, à surcharger par pièce. */
export const ZONE_PRESETS = Object.freeze({
  main: { resistance: 1, vulnerability: 1 },
  face: { resistance: 1.1, vulnerability: 0.9 },
  visor: { resistance: 0.7, vulnerability: 1.2 },
  plastron: { resistance: 1.1, vulnerability: 0.9 },
  shoulder: { resistance: 0.85, vulnerability: 1 },
  joint: { resistance: 0.45, vulnerability: 1.4 },
  attachment: { resistance: 0.3, vulnerability: 2.2, attachment: true, detachThreshold: 0.35 },
  // armes
  blade: { resistance: 1, vulnerability: 1 },
  edge: { resistance: 0.9, vulnerability: 1.3 },
  flat: { resistance: 0.8, vulnerability: 1.5 },
  guard: { resistance: 1.2, vulnerability: 0.8 },
  tang: { resistance: 0.5, vulnerability: 2, attachment: true, detachThreshold: 0.5 },
});

const CRACK_RADIUS = 0.08; // m — proximité pour considérer qu'on frappe « sur la fissure »

let pieceSeq = 0;

export class EquipmentPiece {
  /**
   * @param {object} def
   * @param {string} def.id
   * @param {string} def.name
   * @param {string} def.kind      LayerKind
   * @param {string} def.material  clé de MATERIALS
   * @param {string[]} [def.covers] zones corporelles couvertes
   * @param {object} [def.zones]   zones de la pièce { nom: {resistance, vulnerability, …} }
   * @param {object[]} [def.colliders] volumes { shape, center/radius | min/max, zone }
   * @param {number} [def.mass]    kg (armes)
   */
  constructor(def) {
    this.id = def.id ?? `piece_${++pieceSeq}`;
    this.name = def.name ?? this.id;
    this.kind = def.kind ?? LayerKind.ARMOR;
    this.material = def.material;
    getMaterial(this.material); // validation
    this.covers = def.covers ?? [];
    this.zones = {};
    const zoneDefs = def.zones ?? { main: ZONE_PRESETS.main };
    for (const [name, z] of Object.entries(zoneDefs)) this.zones[name] = { ...(ZONE_PRESETS[name] ?? ZONE_PRESETS.main), ...z };
    this.defaultZone = def.defaultZone ?? Object.keys(this.zones)[0];
    this.colliders = def.colliders ?? [];
    this.mass = def.mass ?? 1;
    this.heldBy = def.heldBy ?? null; // zone corporelle qui tient l'objet (bouclier, arme)
    this.sharpness = def.sharpness ?? (this.kind === LayerKind.WEAPON ? 1 : 0);

    // --- état persistant (§46) ---
    this.integrity = def.state?.integrity ?? 1;
    this.cracks = def.state?.cracks ?? [];      // { id, zone, position, severity, hits }
    this.deformation = def.state?.deformation ?? 0;
    this.tears = def.state?.tears ?? [];        // { zone, position, length }
    this.zoneDamage = def.state?.zoneDamage ?? {};
    this.hitCount = def.state?.hitCount ?? 0;
    this.detached = def.state?.detached ?? false;
    this.destroyed = def.state?.destroyed ?? false;
    this.stage = def.state?.stage ?? 'intact';  // intact → crack → deform → detach → shatter/break
    this.statuses = def.state?.statuses ?? [];  // ex. 'embrittled', 'burning', 'corroded'
    this.history = def.state?.history ?? [];
  }

  get materialDef() {
    const m = getMaterial(this.material);
    if (this.statuses.includes('embrittled')) return { ...m, brittleness: Math.min(1, m.brittleness + 0.35) };
    return m;
  }

  /** §36 */
  get tier() {
    if (this.destroyed || this.integrity <= 0) return IntegrityTier.DESTROYED;
    const t = this.materialDef.tierThresholds;
    if (this.integrity >= t.light) return IntegrityTier.INTACT;
    if (this.integrity >= t.heavy) return IntegrityTier.LIGHT;
    if (this.integrity >= t.critical) return IntegrityTier.HEAVY;
    return IntegrityTier.CRITICAL;
  }

  get efficiency() {
    if (this.detached) return 0;
    return this.materialDef.tierEfficiency[this.tier];
  }

  /** Une pièce détruite ou détachée est retirée de la collision et de la défense (§36 0 %). */
  get active() { return !this.destroyed && !this.detached; }

  /** Performance offensive d'une arme endommagée (force × tranchant). */
  get weaponPerformance() {
    if (!this.active) return 0;
    return Math.max(0.15, 0.4 + 0.6 * this.efficiency);
  }

  zone(name) { return this.zones[name] ?? this.zones[this.defaultZone]; }

  /** §32 PRIORITÉ 4 — faiblesse locale due aux fissures et déformations existantes. */
  localWeakness(zoneName, position) {
    let w = 1;
    for (const c of this.cracks) {
      const near = position && c.position ? vec.dist(position, c.position) <= CRACK_RADIUS : c.zone === zoneName;
      if (near) w += c.severity;
    }
    w += this.deformation * 0.5;
    w += (this.zoneDamage[zoneName] ?? 0) * 0.5;
    return Math.min(w, 4);
  }

  /**
   * Applique des dégâts structurels (fraction d'intégrité). Jamais aléatoire (§37).
   * Retourne la liste d'événements visuels/gameplay générés.
   */
  applyStructuralDamage(amount, { zoneName, position, attackType, impactId, time }) {
    const events = [];
    if (!this.active || amount <= 0) return { events, brokeDuringImpact: false, overflow: 0 };
    const mat = this.materialDef;
    const zoneDef = this.zone(zoneName);
    const before = this.integrity;
    const tierBefore = this.tier;

    this.hitCount += 1;
    this.integrity = Math.max(0, before - amount);
    this.zoneDamage[zoneName] = (this.zoneDamage[zoneName] ?? 0) + amount;

    // Progression visuelle : fissure → déformation → détachement → bris.
    if (mat.failureMode === 'fabric') {
      const length = amount * 0.6;
      const existing = this.tears.find((t) => (position && t.position ? vec.dist(t.position, position) <= CRACK_RADIUS : t.zone === zoneName));
      if (existing) { existing.length += length; events.push(ev('tear_widened', this, { zone: zoneName, length: existing.length })); }
      else if (length > 0.02) { this.tears.push({ zone: zoneName, position, length }); events.push(ev('tear', this, { zone: zoneName, length })); }
    } else {
      const crackGrowth = amount * mat.brittleness * 2;
      if (crackGrowth > 0.02) {
        const existing = this.cracks.find((c) => (position && c.position ? vec.dist(c.position, position) <= CRACK_RADIUS : c.zone === zoneName));
        if (existing) {
          existing.severity = Math.min(1.5, existing.severity + crackGrowth);
          existing.hits += 1;
          events.push(ev('crack_aggravated', this, { zone: zoneName, severity: existing.severity }));
        } else {
          this.cracks.push({ id: `${this.id}_c${this.cracks.length + 1}`, zone: zoneName, position, severity: crackGrowth, hits: 1, impactId });
          events.push(ev('crack', this, { zone: zoneName, severity: crackGrowth }));
        }
        if (this.stage === 'intact') this.stage = 'crack';
      }
      const deform = amount * (1 - mat.brittleness) * 1.5;
      if (deform > 0.02) {
        this.deformation = Math.min(1, this.deformation + deform);
        events.push(ev('deform', this, { zone: zoneName, deformation: this.deformation }));
        if (this.stage === 'intact' || this.stage === 'crack') this.stage = 'deform';
      }
    }

    // §37 — détachement par la fixation.
    if (zoneDef.attachment && this.zoneDamage[zoneName] >= zoneDef.detachThreshold && this.integrity > 0) {
      this.detached = true;
      this.stage = 'detach';
      events.push(ev('detach', this, { zone: zoneName, critical: true }));
    }

    let brokeDuringImpact = false;
    let overflow = 0;
    if (this.integrity <= 0) {
      this.destroyed = true;
      brokeDuringImpact = true;
      overflow = before > 0 ? Math.max(0, 1 - before / amount) : 1;
      this.stage = mat.failureMode === 'brittle' ? 'shatter' : mat.failureMode === 'fabric' ? 'shredded' : 'break';
      events.push(ev(this.stage, this, { zone: zoneName, critical: true }));
    }

    const tierAfter = this.tier;
    if (tierAfter !== tierBefore) events.push(ev('tier_changed', this, { from: tierBefore, to: tierAfter, critical: true }));

    this.history.push({ impactId, time, attackType, zone: zoneName, amount, integrityBefore: before, integrityAfter: this.integrity, tier: tierAfter });
    return { events, brokeDuringImpact, overflow };
  }

  addStatus(status) { if (!this.statuses.includes(status)) this.statuses.push(status); }

  toJSON() {
    return {
      id: this.id, name: this.name, kind: this.kind, material: this.material, covers: this.covers,
      zones: this.zones, defaultZone: this.defaultZone, colliders: this.colliders, mass: this.mass, heldBy: this.heldBy, sharpness: this.sharpness,
      state: {
        integrity: this.integrity, cracks: this.cracks, deformation: this.deformation, tears: this.tears,
        zoneDamage: this.zoneDamage, hitCount: this.hitCount, detached: this.detached, destroyed: this.destroyed,
        stage: this.stage, statuses: this.statuses, history: this.history,
      },
    };
  }

  static fromJSON(json) { return new EquipmentPiece(structuredClone(json)); }
}

function ev(type, piece, data = {}) {
  return { type, pieceId: piece.id, pieceName: piece.name, kind: piece.kind, ...data };
}
