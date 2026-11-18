// §46 — Damage State persistant d'un combattant.
// §48 — règle de non-réinitialisation : seules des raisons explicites permettent de restaurer.
import { BodyZone, OPEN_WOUNDS, RestoreReason, layerRank } from './constants.js';
import { EquipmentPiece } from './equipment.js';
import { bleedProfile, bleedRateAt } from './bleeding.js';
import { bodyZoneDef } from './body.js';
import { vec } from './geometry.js';

const WOUND_MERGE_RADIUS = 0.1;
const BLOOD_TRACE_FLOOR = 0.25; // fraction d'une tache qui reste même sous la pluie

export class DamageState {
  constructor({ combatantId, maxHealth = 100, mass = 80, bloodVolume = 5000, bodyColliders = [] } = {}) {
    this.combatantId = combatantId ?? 'combatant';
    this.maxHealth = maxHealth;
    this.health = maxHealth;
    this.mass = mass;
    this.maxBloodVolume = bloodVolume;
    this.bloodVolume = bloodVolume;
    this.bodyColliders = bodyColliders; // { shape, …, bodyZone }
    this.pieces = new Map();
    this.wounds = [];
    this.limbs = {};
    for (const z of Object.values(BodyZone)) this.limbs[z] = { function: 1, contusion: 0, fracture: false };
    this.traces = { blood: {}, dust: {}, dirt: {} };
    this.fatigue = 0;       // 0..1
    this.pain = 0;          // 0..1
    this.internalDamage = 0; // abstrait (§33)
    this.balance = 1;       // 1 = stable
    this.time = 0;
    this.phase = 'match';
    this.history = [];
    this.processedImpacts = new Set();
    this.archivedPieces = [];
    this._seq = 0;
  }

  // ---------------- équipement ----------------
  equip(piece) {
    const p = piece instanceof EquipmentPiece ? piece : new EquipmentPiece(piece);
    this.pieces.set(p.id, p);
    return p;
  }

  getPiece(id) { return this.pieces.get(id); }

  activePieces() { return [...this.pieces.values()].filter((p) => p.active); }

  /** Pièces actives couvrant une zone, de l'extérieur vers l'intérieur. */
  coveringPieces(bodyZone) {
    return this.activePieces()
      .filter((p) => p.covers.includes(bodyZone))
      .sort((a, b) => layerRank(a.kind) - layerRank(b.kind));
  }

  outermostSurface(bodyZone) {
    const p = this.coveringPieces(bodyZone).find((x) => x.kind !== 'shield' && x.kind !== 'weapon');
    return p ? p.id : 'skin';
  }

  // ---------------- blessures (§39, §40, §44) ----------------
  registerWound({ bodyZone, type, severity, position, impactId }) {
    const zoneDef = bodyZoneDef(bodyZone);
    const isOpen = OPEN_WOUNDS.has(type);
    const existing = this.wounds.find((w) => w.bodyZone === bodyZone && w.type === type && !w.healed
      && (position && w.position ? vec.dist(position, w.position) <= WOUND_MERGE_RADIUS : true));

    if (existing) {
      // aggravation : la courbe de saignement repart avec un pic plus haut
      const currentRate = this.bleedRate(existing).rate;
      existing.severity = 1 - (1 - existing.severity) * (1 - severity);
      existing.hits += 1;
      existing.lastHitAt = this.time;
      existing.impacts.push(impactId);
      if (isOpen) {
        existing.bleed = bleedProfile(existing.severity, zoneDef.bleedFactor, type, currentRate);
        existing.bleedStart = this.time;
      }
      this._recomputeLimb(bodyZone);
      return { wound: existing, aggravated: true };
    }

    const wound = {
      id: `${this.combatantId}_w${++this._seq}`,
      bodyZone, type, severity, position,
      createdAt: this.time, lastHitAt: this.time, hits: 1, impacts: [impactId],
      open: isOpen, healed: false, treated: false,
      bleed: isOpen ? bleedProfile(severity, zoneDef.bleedFactor, type) : null,
      bleedStart: this.time,
      bloodLost: 0,
    };
    this.wounds.push(wound);
    this._recomputeLimb(bodyZone);
    return { wound, aggravated: false };
  }

  bleedRate(wound, movement = 0) {
    if (!wound.bleed || wound.treated) return { rate: 0, phase: wound.treated ? 'treated' : 'none' };
    return bleedRateAt(wound.bleed, this.time - wound.bleedStart, movement);
  }

  addContusion(bodyZone, amount, fracture = false) {
    const l = this.limbs[bodyZone];
    l.contusion = Math.min(1, l.contusion + amount);
    if (fracture) l.fracture = true;
    this._recomputeLimb(bodyZone);
  }

  _recomputeLimb(bodyZone, minFunction = 0) {
    const l = this.limbs[bodyZone];
    const woundImpairment = this.wounds
      .filter((w) => w.bodyZone === bodyZone)
      .reduce((s, w) => s + w.severity * (w.healed ? 0.15 : 0.6), 0);
    const impairment = woundImpairment + l.contusion * 0.25 + (l.fracture ? 0.3 : 0);
    l.function = Math.max(minFunction, 1 - impairment);
  }

  addTrace(kind, zone, amount, surface) {
    const bucket = this.traces[kind];
    const key = surface ? `${zone}@${surface}` : zone;
    const t = bucket[key] ?? { zone, surface: surface ?? null, intensity: 0, max: 0 };
    t.intensity = Math.min(1, t.intensity + amount);
    t.max = Math.max(t.max, t.intensity);
    bucket[key] = t;
  }

  // ---------------- temps (§40) ----------------
  /**
   * Avance la simulation persistante : saignement, traces, environnement.
   * @param {number} dt secondes
   * @param {{movement?:number, environment?:{rain?:number, dusty?:boolean, mud?:boolean}}} opts
   */
  update(dt, { movement = 0, environment = {} } = {}) {
    const events = [];
    // intégration simple par sous-pas pour suivre la courbe
    const steps = Math.max(1, Math.ceil(dt / 0.25));
    const h = dt / steps;
    for (let i = 0; i < steps; i++) {
      this.time += h;
      for (const w of this.wounds) {
        const { rate } = this.bleedRate(w, movement);
        if (rate <= 0) continue;
        const ml = rate * h;
        w.bloodLost += ml;
        this.bloodVolume = Math.max(0, this.bloodVolume - ml);
        this.addTrace('blood', w.bodyZone, ml / 400, this.outermostSurface(w.bodyZone));
      }
    }
    // perte de sang → fatigue (jauge séparée de la vie)
    const lossFrac = 1 - this.bloodVolume / this.maxBloodVolume;
    this.fatigue = Math.min(1, Math.max(this.fatigue, lossFrac * 1.5));
    // équilibre se rétablit
    this.balance = Math.min(1, this.balance + dt * 0.8);

    // conditions environnementales : la pluie lave partiellement, jamais complètement (§48)
    if (environment.rain) {
      for (const t of Object.values(this.traces.blood)) {
        const floor = t.max * BLOOD_TRACE_FLOOR;
        t.intensity = Math.max(floor, t.intensity - environment.rain * 0.01 * dt);
      }
      for (const [k, t] of Object.entries(this.traces.dust)) {
        if (t.intensity > 0.05) {
          this.addTrace('dirt', t.zone, t.intensity * 0.5);
          t.intensity *= 0.5;
        }
        this.traces.dust[k] = t;
      }
    }
    if (environment.dusty && movement > 0.3) {
      for (const z of [BodyZone.LEFT_LEG, BodyZone.RIGHT_LEG]) this.addTrace('dust', z, 0.002 * dt * movement);
    }
    if (environment.mud && movement > 0.3) {
      for (const z of [BodyZone.LEFT_LEG, BodyZone.RIGHT_LEG]) this.addTrace('dirt', z, 0.004 * dt * movement);
    }
    return events;
  }

  // ---------------- restauration encadrée (§48) ----------------
  restore(reason, payload = {}) {
    if (!Object.values(RestoreReason).includes(reason)) {
      throw new Error(`Restauration refusée : raison « ${reason} » non reconnue. Détruit = détruit.`);
    }
    const entry = { type: 'restore', reason, payload: summarizePayload(payload), time: this.time };
    switch (reason) {
      case RestoreReason.HEAL: {
        const targets = payload.woundId ? this.wounds.filter((w) => w.id === payload.woundId) : this.wounds;
        const amount = payload.amount ?? 0.3;
        for (const w of targets) {
          w.severity = Math.max(0, w.severity - amount);
          w.treated = true; // le saignement s'arrête, la blessure (cicatrice) reste enregistrée
          if (w.severity === 0) w.healed = true;
        }
        this.health = Math.min(this.maxHealth, this.health + (payload.health ?? 0));
        for (const z of new Set(targets.map((w) => w.bodyZone))) this._recomputeLimb(z);
        break;
      }
      case RestoreReason.REPAIR: {
        const p = this.pieces.get(payload.pieceId);
        if (!p) throw new Error(`Pièce inconnue : ${payload.pieceId}`);
        if (p.destroyed) throw new Error(`Réparation impossible : « ${p.name} » est détruite. Utiliser replace_equipment.`);
        p.integrity = Math.min(payload.maxIntegrity ?? 0.9, p.integrity + (payload.amount ?? 0.25));
        if (p.detached && payload.reattach) p.detached = false;
        for (const c of p.cracks) c.repaired = true; // la trace de réparation reste visible
        p.history.push({ type: 'repair', time: this.time, integrityAfter: p.integrity });
        break;
      }
      case RestoreReason.REST: {
        this.fatigue = Math.max(0, this.fatigue - (payload.amount ?? 0.5));
        this.pain = Math.max(0, this.pain - (payload.amount ?? 0.5) * 0.5);
        this.balance = 1;
        break;
      }
      case RestoreReason.REPLACE_EQUIPMENT: {
        const old = this.pieces.get(payload.pieceId);
        if (old) { this.archivedPieces.push(old.toJSON()); this.pieces.delete(old.id); }
        if (payload.newPiece) this.equip(payload.newPiece);
        break;
      }
      case RestoreReason.NEW_PHASE: {
        if (!payload.phase) throw new Error('new_phase exige un nom de phase explicite.');
        this.phase = payload.phase;
        if (payload.cleanTraces) this.traces = { blood: {}, dust: {}, dirt: {} };
        if (payload.restoreHealth) this.health = this.maxHealth;
        break;
      }
      default: break;
    }
    this.history.push(entry);
    return entry;
  }

  // ---------------- lecture (§OBJECTIF) ----------------
  /** Résumé lisible : l'historique de combat visible sur le personnage. */
  summary() {
    return {
      combatantId: this.combatantId,
      health: round(this.health),
      bloodVolume: round(this.bloodVolume),
      fatigue: round(this.fatigue), pain: round(this.pain), internalDamage: round(this.internalDamage),
      equipment: [...this.pieces.values()].map((p) => ({
        id: p.id, name: p.name, kind: p.kind, integrity: round(p.integrity), tier: p.tier, stage: p.stage,
        cracks: p.cracks.length, deformation: round(p.deformation), tears: p.tears.length,
        detached: p.detached, destroyed: p.destroyed, hits: p.hitCount,
      })),
      wounds: this.wounds.map((w) => ({
        id: w.id, zone: w.bodyZone, type: w.type, severity: round(w.severity), hits: w.hits,
        bleeding: round(this.bleedRate(w).rate), phase: this.bleedRate(w).phase, bloodLost: round(w.bloodLost),
      })),
      limbs: Object.fromEntries(Object.entries(this.limbs).filter(([, l]) => l.function < 1 || l.contusion > 0)
        .map(([z, l]) => [z, { function: round(l.function), contusion: round(l.contusion), fracture: l.fracture }])),
      traces: this.traces,
    };
  }

  toJSON() {
    return {
      combatantId: this.combatantId, maxHealth: this.maxHealth, health: this.health, mass: this.mass,
      maxBloodVolume: this.maxBloodVolume, bloodVolume: this.bloodVolume, bodyColliders: this.bodyColliders,
      pieces: [...this.pieces.values()].map((p) => p.toJSON()),
      wounds: this.wounds, limbs: this.limbs, traces: this.traces,
      fatigue: this.fatigue, pain: this.pain, internalDamage: this.internalDamage, balance: this.balance,
      time: this.time, phase: this.phase, history: this.history,
      processedImpacts: [...this.processedImpacts], archivedPieces: this.archivedPieces, seq: this._seq,
    };
  }

  /** Mode tournoi : l'état est conservé entre les combats. */
  static fromJSON(json) {
    const j = structuredClone(json);
    const s = new DamageState({
      combatantId: j.combatantId, maxHealth: j.maxHealth, mass: j.mass, bloodVolume: j.maxBloodVolume, bodyColliders: j.bodyColliders,
    });
    Object.assign(s, {
      health: j.health, bloodVolume: j.bloodVolume, wounds: j.wounds, limbs: j.limbs, traces: j.traces,
      fatigue: j.fatigue, pain: j.pain, internalDamage: j.internalDamage, balance: j.balance,
      time: j.time, phase: j.phase, history: j.history, archivedPieces: j.archivedPieces, _seq: j.seq,
    });
    // Infinity n'est pas sérialisable en JSON : on le restaure
    for (const w of s.wounds) if (w.bleed && w.bleed.stopAfter == null) w.bleed.stopAfter = Infinity;
    s.processedImpacts = new Set(j.processedImpacts);
    for (const p of j.pieces) s.equip(EquipmentPiece.fromJSON(p));
    return s;
  }
}

const round = (x) => Math.round(x * 1000) / 1000;
function summarizePayload(p) {
  const { newPiece, ...rest } = p;
  return newPiece ? { ...rest, newPiece: newPiece.id ?? newPiece.name } : rest;
}
