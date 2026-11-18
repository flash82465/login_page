// §32–§47 — Damage Priority & Resolution System.
// Chaîne officielle : IMPACT → LOCALISATION → PROTECTION → MATERIAU → ABSORPTION → TRANSMISSION
//                     → DOMMAGE → BLESSURE → SAIGNEMENT → CONSEQUENCE → PERSISTANCE
import { AttackType, BodyZone, LayerKind, OPEN_WOUNDS, RESOLUTION_CHAIN, WoundType, layerRank } from './constants.js';
import { elementalModifiers } from './materials.js';
import { incidenceAngle, rayCollider, vec } from './geometry.js';
import { bodyZoneDef, classifyWound, limbModifiers } from './body.js';

export const DEFAULT_CONFIG = Object.freeze({
  healthScale: 0.3,              // énergie corporelle → points de vie
  maxHealthFractionPerHit: 0.45, // §45 équilibre compétitif : pas de one-shot sur un coup unique
  minLimbFunction: 0.35,         // §44 : jamais incapable d'agir
  maxBalanceLossPerHit: 0.8,
  attackerWeaponWear: 0.0006,    // usure de l'arme qui frappe une surface dure
  vfxBudget: { bloodParticles: 60, cosmeticEvents: 10 }, // §45 lisibilité
});

/** §34 — profils par type d'attaque. */
export const ATTACK_PROFILES = Object.freeze({
  [AttackType.SLASH]: { penetration: (m) => 1 - m.hardness * 1.1, transmission: 0.1, structural: 0.8, knockback: 0.2 },
  [AttackType.BLUNT]: { penetration: () => 0, transmission: 0.6, structural: 1.1, knockback: 1 },
  [AttackType.PIERCE]: { penetration: (m) => 1 - m.hardness * 0.6, transmission: 0.08, structural: 0.6, knockback: 0.15 },
  [AttackType.HEAVY]: { penetration: (m) => 0.3 * (1 - m.hardness * 0.5), transmission: 0.5, structural: 2, knockback: 1.3 },
  [AttackType.EXPLOSIVE]: { penetration: () => 0.25, transmission: 0.5, structural: 1.5, knockback: 1.6 },
  [AttackType.ELEMENTAL]: { penetration: () => 0.6, transmission: 0.3, structural: 1, knockback: 0.05 },
});

/** Facteur d'angle : un coup rasant transmet moins (et plus encore pour la perforation). */
export function angleFactor(attackType, angleDeg = 0) {
  const c = Math.cos((Math.min(89.9, Math.abs(angleDeg)) * Math.PI) / 180);
  switch (attackType) {
    case AttackType.SLASH: return 0.3 + 0.7 * c;
    case AttackType.PIERCE: return Math.max(0.1, c ** 1.5);
    case AttackType.BLUNT: return 0.5 + 0.5 * c;
    case AttackType.HEAVY: return 0.6 + 0.4 * c;
    default: return 1;
  }
}

const FLESH = Object.freeze({ hardness: 0 });
const HELD_RECOIL_SHARE = 0.4;

const EXPLOSION_EXPOSURE = Object.freeze({
  [BodyZone.HEAD]: 0.1, [BodyZone.TORSO]: 0.25, [BodyZone.ABDOMEN]: 0.15,
  [BodyZone.LEFT_ARM]: 0.075, [BodyZone.RIGHT_ARM]: 0.075,
  [BodyZone.LEFT_LEG]: 0.125, [BodyZone.RIGHT_LEG]: 0.125, [BodyZone.LEFT_HAND]: 0.0375, [BodyZone.RIGHT_HAND]: 0.0375,
});

const STRUCTURAL_SCALE = 0.25; // calibrage : énergie → fraction d'intégrité
const clamp01 = (x) => Math.max(0, Math.min(1, x));
const r3 = (x) => Math.round(x * 1000) / 1000;

export class DamageResolver {
  constructor(config = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config, vfxBudget: { ...DEFAULT_CONFIG.vfxBudget, ...(config.vfxBudget ?? {}) } };
  }

  impactKey(impact) {
    return impact.attackId != null ? `${impact.attackId}:${impact.hitIndex ?? 0}` : impact.id;
  }

  // ------------------------------------------------------------------ §32 P1
  /**
   * Détermine ce qui a réellement été touché, de l'extérieur vers l'intérieur.
   * Trois sources possibles, par ordre de préférence :
   *  1. impact.hits      : liste fournie par le moteur physique
   *  2. origin+direction : lancer de rayon sur les volumes de l'équipement et du corps
   *  3. impact.bodyZone  : repli par zone (pièces couvrant la zone, ordre des couches)
   */
  localize(state, impact) {
    if (Array.isArray(impact.hits) && impact.hits.length) return this._localizeFromHits(state, impact);
    if (impact.origin && impact.direction) return this._localizeRay(state, impact);
    if (impact.bodyZone) return this._localizeZone(state, impact);
    throw new Error('Impact non localisable : fournir hits, origin+direction ou bodyZone.');
  }

  _localizeFromHits(state, impact) {
    const sorted = [...impact.hits].sort((a, b) => (a.distance ?? 0) - (b.distance ?? 0)
      || rankOfHit(state, a) - rankOfHit(state, b));
    const layers = []; let bodyZone = null; let bodyHit = null;
    for (const h of sorted) {
      if (h.bodyZone) { bodyZone = h.bodyZone; bodyHit = h; break; }
      const piece = state.getPiece(h.pieceId);
      if (!piece || !piece.active || layers.some((l) => l.piece === piece)) continue;
      layers.push({ piece, zone: h.zone ?? piece.defaultZone, point: h.point, angle: h.angle ?? (h.normal && impact.direction ? incidenceAngle(impact.direction, h.normal) : impact.angle ?? 0) });
    }
    this._addImplicitLayers(state, layers, bodyZone, impact, bodyHit?.point, bodyHit?.distance);
    return { method: 'engine_hits', layers, bodyZone, point: bodyHit?.point ?? layers[0]?.point, angle: layers[0]?.angle ?? impact.angle ?? 0 };
  }

  _localizeRay(state, impact) {
    const dir = vec.norm(impact.direction);
    const cands = [];
    for (const piece of state.activePieces()) {
      let best = null;
      for (const c of piece.colliders) {
        const h = rayCollider(impact.origin, dir, c);
        if (h && (!best || h.t < best.t)) best = { ...h, zone: c.zone ?? piece.defaultZone };
      }
      if (best) cands.push({ piece, rank: layerRank(piece.kind), ...best });
    }
    for (const c of state.bodyColliders) {
      const h = rayCollider(impact.origin, dir, c);
      if (h) cands.push({ bodyZone: c.bodyZone, rank: layerRank(LayerKind.BODY), ...h });
    }
    cands.sort((a, b) => (Math.round(a.t * 1e4) - Math.round(b.t * 1e4)) || a.rank - b.rank);
    const layers = []; let bodyZone = null; let bodyHit = null;
    for (const c of cands) {
      if (c.bodyZone) { bodyZone = c.bodyZone; bodyHit = c; break; }
      layers.push({ piece: c.piece, zone: c.zone, point: c.point, angle: incidenceAngle(dir, c.normal), distance: c.t });
    }
    this._addImplicitLayers(state, layers, bodyZone, impact, bodyHit?.point, bodyHit?.t);
    const angle = layers[0]?.angle ?? (bodyHit ? incidenceAngle(dir, bodyHit.normal) : 0);
    return { method: 'raycast', layers, bodyZone, point: bodyHit?.point ?? layers[0]?.point ?? null, angle };
  }

  _localizeZone(state, impact) {
    const layers = [];
    for (const piece of state.coveringPieces(impact.bodyZone)) {
      if (piece.kind === LayerKind.SHIELD && impact.blockedWith !== piece.id) continue;
      if (piece.kind === LayerKind.WEAPON && impact.parriedWith !== piece.id) continue;
      layers.push({ piece, zone: impact.pieceZones?.[piece.id] ?? piece.defaultZone, point: impact.point, angle: impact.angle ?? 0 });
    }
    // bouclier / arme interposés qui ne « couvrent » pas la zone
    for (const id of [impact.blockedWith, impact.parriedWith]) {
      const p = id && state.getPiece(id);
      if (p && p.active && !layers.some((l) => l.piece === p)) {
        layers.unshift({ piece: p, zone: impact.pieceZones?.[p.id] ?? p.defaultZone, point: impact.point, angle: impact.angle ?? 0 });
      }
    }
    layers.sort((a, b) => layerRank(a.piece.kind) - layerRank(b.piece.kind));
    return { method: 'zone', layers, bodyZone: impact.bodyZone, point: impact.point ?? null, angle: impact.angle ?? 0 };
  }

  /** Vêtements/pièces sans volume propre : ils épousent la zone corporelle touchée. */
  _addImplicitLayers(state, layers, bodyZone, impact, point, bodyDistance) {
    if (!bodyZone) return;
    for (const p of state.coveringPieces(bodyZone)) {
      if (p.colliders.length || layers.some((l) => l.piece === p)) continue;
      if (p.kind === LayerKind.SHIELD || p.kind === LayerKind.WEAPON) continue;
      layers.push({ piece: p, zone: impact.pieceZones?.[p.id] ?? p.defaultZone, point, angle: layers.at(-1)?.angle ?? impact.angle ?? 0, distance: bodyDistance ?? Infinity, implicit: true });
    }
    const d = (l) => l.distance ?? (bodyDistance ?? Infinity);
    layers.sort((a, b) => d(a) - d(b) || layerRank(a.piece.kind) - layerRank(b.piece.kind));
  }

  // ------------------------------------------------------------------ résolution
  /**
   * Résout un impact sur un combattant et met à jour son Damage State.
   * @param {import('./damageState.js').DamageState} state
   * @param {object} impact
   */
  resolveImpact(state, impact) {
    const cfg = this.config;
    const chain = [];
    const step = (name, data, skipped) => chain.push({ step: name, ...(skipped ? { skipped } : {}), data });
    const key = this.impactKey(impact);
    const attackType = impact.attackType ?? AttackType.BLUNT;
    const profile = ATTACK_PROFILES[attackType];
    if (!profile) throw new Error(`Type d'attaque inconnu : ${attackType}`);
    if (impact.time != null && impact.time > state.time) state.time = impact.time;

    // §42 — un même coup ne compte qu'une fois malgré des collisions successives
    if (state.processedImpacts.has(key)) {
      return { impactId: key, skipped: true, reason: 'duplicate_collision', chain: [] };
    }

    // ---- IMPACT
    const weaponPerf = impact.attackerWeapon ? impact.attackerWeapon.weaponPerformance : 1;
    const force = (impact.force ?? 0) * weaponPerf;
    step('IMPACT', { key, attackType, element: impact.element ?? null, rawForce: impact.force, weaponPerformance: r3(weaponPerf), force: r3(force) });

    // ---- LOCALISATION
    const loc = this.localize(state, impact);
    step('LOCALISATION', {
      method: loc.method, bodyZone: loc.bodyZone,
      surfaces: loc.layers.map((l) => ({ piece: l.piece.id, kind: l.piece.kind, zone: l.zone })),
    });
    if (!loc.bodyZone && loc.layers.length === 0) {
      for (const s of RESOLUTION_CHAIN.slice(2)) step(s, null, 'aucune surface touchée (esquive/manqué)');
      return { impactId: key, miss: true, chain };
    }
    state.processedImpacts.add(key);

    // ---- PROTECTION / MATERIAU / ABSORPTION / TRANSMISSION / DOMMAGE (équipement)
    const angleF = angleFactor(attackType, loc.angle);
    let main = force * angleF;   // canal « attaque » (coupe, perforation, choc principal)
    let blunt = 0;               // canal contondant transmis
    const env = impact.environment ?? {};
    const layerReports = [];
    const events = [];
    const holderRecoil = [];
    if (angleF < 0.45 && (attackType === AttackType.SLASH || attackType === AttackType.PIERCE)) {
      events.push({ type: 'glance', angle: r3(loc.angle) });
    }

    for (const layer of loc.layers) {
      const { piece, zone, point } = layer;
      if (!piece.active) continue; // détruite par un impact précédent de la même file
      const mat = piece.materialDef;
      const zoneDef = piece.zone(zone);
      const elem = elementalModifiers(mat, impact.element, env);
      const weakness = piece.localWeakness(zone, point);
      const eff = piece.efficiency;
      const resistance = mat.resistance * zoneDef.resistance * eff * elem.resistance / weakness;
      const tierBefore = piece.tier;

      const bypass = main * elem.passThrough;
      const contact = main - bypass;
      const absorbed = Math.min(contact, resistance);
      const overflow = contact - absorbed;
      const p = clamp01(profile.penetration(mat));
      let penOut = overflow * p + bypass;
      let bluntOut = blunt * (1 - mat.damping) + overflow * (1 - p) + absorbed * profile.transmission * (1 - mat.damping);

      const structural = (contact * profile.structural * (mat.vulnerability[attackType] ?? 1)
        + blunt * 0.3 * mat.vulnerability[AttackType.BLUNT]) * zoneDef.vulnerability * weakness * elem.structural * STRUCTURAL_SCALE / mat.toughness;
      const dmg = piece.applyStructuralDamage(structural, { zoneName: zone, position: point, attackType, impactId: key, time: state.time });
      events.push(...dmg.events);

      // §35 — couche détruite pendant l'impact : la suivante reçoit davantage
      if (dmg.brokeDuringImpact) {
        const extra = absorbed * dmg.overflow;
        penOut += extra * p;
        bluntOut += extra * (1 - p) * 0.8;
      }
      for (const e of elem.effects) {
        const status = { embrittle: 'embrittled', ignite: 'burning', corrode: 'corroded' }[e];
        piece.addStatus(status);
        events.push({ type: `status_${status}`, pieceId: piece.id });
      }

      // usure de l'arme attaquante (§38 : arme contre surface dure)
      if (impact.attackerWeapon && impact.attackerWeapon.active) {
        const w = impact.attackerWeapon;
        const wear = absorbed * cfg.attackerWeaponWear * (mat.hardness + 0.1) / (w.materialDef.hardness + 0.1);
        if (wear > 0) {
          const wr = w.applyStructuralDamage(wear, { zoneName: w.zones.edge ? 'edge' : w.defaultZone, attackType, impactId: key, time: state.time });
          if (attackType === AttackType.SLASH || attackType === AttackType.PIERCE) w.sharpness = Math.max(0, w.sharpness - wear);
          events.push(...wr.events.map((e) => ({ ...e, attacker: true })));
        }
      }

      // bouclier / arme tenus : le choc non pénétrant part dans le bras porteur
      if ((piece.kind === LayerKind.SHIELD || piece.kind === LayerKind.WEAPON) && piece.heldBy && !dmg.brokeDuringImpact) {
        // une parade tenue répartit le choc dans la posture : le bras n'en reçoit qu'une partie
        holderRecoil.push({ bodyZone: piece.heldBy, energy: bluntOut * HELD_RECOIL_SHARE });
        bluntOut = 0;
      }

      layerReports.push({
        piece: piece.id, name: piece.name, kind: piece.kind, zone, material: piece.material,
        incoming: r3(contact + bypass), bluntIncoming: r3(blunt), resistance: r3(resistance), weakness: r3(weakness),
        efficiency: r3(eff), absorbed: r3(absorbed), penetratingOut: r3(penOut), bluntOut: r3(bluntOut),
        structuralDamage: r3(structural), integrity: r3(piece.integrity), tierBefore, tierAfter: piece.tier,
        broke: dmg.brokeDuringImpact, detached: piece.detached,
      });
      main = penOut;
      blunt = bluntOut;
    }

    // Le canal principal atteint la chair : seule la part réellement coupante/perforante ouvre la peau,
    // le reste devient choc contondant (une masse ne « pénètre » pas un torse nu).
    if (loc.bodyZone) {
      const fleshPen = clamp01(profile.penetration(FLESH));
      blunt += main * (1 - fleshPen);
      main *= fleshPen;
    }
    step('PROTECTION', { interposed: layerReports.map((l) => `${l.name} (${l.kind}/${l.zone})`) },
      layerReports.length ? null : 'aucune protection active entre l’attaque et le corps');
    step('MATERIAU', layerReports.map((l) => ({ piece: l.piece, material: l.material, incoming: l.incoming, resistance: l.resistance, weakness: l.weakness, efficiency: l.efficiency })),
      layerReports.length ? null : 'aucun matériau interposé');
    step('ABSORPTION', layerReports.map((l) => ({ piece: l.piece, absorbed: l.absorbed })),
      layerReports.length ? null : 'aucun matériau interposé');
    step('TRANSMISSION', { penetrating: r3(main), blunt: r3(blunt), toHolders: holderRecoil.map((h) => ({ ...h, energy: r3(h.energy) })) });
    step('DOMMAGE', layerReports.map((l) => ({ piece: l.piece, structural: l.structuralDamage, integrity: l.integrity, tier: l.tierAfter, broke: l.broke })),
      layerReports.length ? null : 'aucun équipement touché');

    // ---- BLESSURE / SAIGNEMENT / CONSEQUENCE (corps)
    const body = { bodyZone: loc.bodyZone, wounds: [], healthDamage: 0, recoil: 0, balanceLoss: 0 };
    const bodyZones = [];
    if (loc.bodyZone) bodyZones.push({ bodyZone: loc.bodyZone, pen: main, blunt, primary: true });
    for (const h of holderRecoil) bodyZones.push({ bodyZone: h.bodyZone, pen: 0, blunt: h.energy, primary: false });

    const bleedReports = [];
    let totalHealth = 0; let recoil = 0; let balanceLoss = 0;
    for (const bz of bodyZones) {
      const zd = bodyZoneDef(bz.bodyZone);
      const point = bz.primary ? loc.point : null;
      if (bz.pen > 0.5) {
        const type = classifyWound(attackType, impact.element, bz.pen, 0, zd);
        const severity = clamp01(bz.pen / zd.toughness);
        if (severity > 0.01) {
          const { wound, aggravated } = state.registerWound({ bodyZone: bz.bodyZone, type, severity, position: point, impactId: key });
          body.wounds.push({ id: wound.id, zone: bz.bodyZone, type, severity: r3(severity), totalSeverity: r3(wound.severity), aggravated });
          if (wound.bleed) {
            const br = state.bleedRate(wound);
            bleedReports.push({ wound: wound.id, peakRate: r3(wound.bleed.peak), currentRate: r3(br.rate), phase: br.phase, aggravated });
          }
        }
      }
      const bluntSeverity = clamp01(bz.blunt / (zd.toughness * 2));
      if (bluntSeverity > 0.02) {
        const fracture = bz.blunt > zd.toughness * 1.2 && zd.limb !== 'torso';
        const type = fracture ? WoundType.FRACTURE : WoundType.CONTUSION;
        const { wound, aggravated } = state.registerWound({ bodyZone: bz.bodyZone, type, severity: bluntSeverity, position: point, impactId: key });
        state.addContusion(bz.bodyZone, bluntSeverity * 0.5, fracture);
        body.wounds.push({ id: wound.id, zone: bz.bodyZone, type, severity: r3(bluntSeverity), totalSeverity: r3(wound.severity), aggravated });
        if (zd.limb === 'torso' || zd.limb === 'head') state.internalDamage += bz.blunt * 0.1;
      }
      totalHealth += (bz.pen + 0.35 * bz.blunt) * zd.healthMult * cfg.healthScale;
      recoil += ((bz.blunt * profile.knockback + bz.pen * 0.1) / state.mass) * 4;
      balanceLoss += (bz.blunt / zd.balanceThreshold) * 0.5 * profile.knockback;
      state.pain = clamp01(state.pain + clamp01(bz.pen / zd.toughness) * 0.4 + bluntSeverity * 0.3);
      state.fatigue = clamp01(state.fatigue + bz.blunt * 0.0015 + bz.pen * 0.0005);
    }

    // §45 — équilibre compétitif : plafond par coup (le calcul physique brut reste tracé)
    const healthCap = cfg.maxHealthFractionPerHit * state.maxHealth;
    const appliedHealth = Math.min(totalHealth, healthCap);
    state.health = Math.max(0, state.health - appliedHealth);
    balanceLoss = Math.min(cfg.maxBalanceLossPerHit, balanceLoss);
    state.balance = Math.max(0, state.balance - balanceLoss);
    body.healthDamage = r3(appliedHealth);
    body.rawHealthDamage = r3(totalHealth);
    body.recoil = r3(recoil);
    body.balanceLoss = r3(balanceLoss);

    step('BLESSURE', body.wounds, body.wounds.length ? null : (loc.bodyZone ? 'énergie résiduelle insuffisante pour blesser' : 'impact entièrement arrêté par un objet tenu'));
    step('SAIGNEMENT', bleedReports, bleedReports.length ? null : 'aucune blessure ouverte');

    const modifiers = limbModifiers(state.limbs, cfg.minLimbFunction);
    const consequences = {
      recoil: body.recoil, balanceLoss: body.balanceLoss, staggered: state.balance < 0.4,
      pain: r3(state.pain), fatigue: r3(state.fatigue), internalDamage: r3(state.internalDamage), modifiers,
    };
    step('CONSEQUENCE', consequences);

    // ---- PERSISTANCE
    const persistent = [];
    for (const w of body.wounds) {
      const wound = state.wounds.find((x) => x.id === w.id);
      if (OPEN_WOUNDS.has(w.type)) {
        // §39 — volume de sang proportionnel à la gravité (carré) : pas d'effet disproportionné
        const surface = state.outermostSurface(w.zone);
        state.addTrace('blood', w.zone, w.severity * w.severity * 0.5, surface);
        persistent.push({ type: 'blood_trace', zone: w.zone, surface });
      }
      persistent.push({ type: 'wound', id: wound.id, zone: w.zone, woundType: w.type });
    }
    if (env.dusty && loc.bodyZone) { state.addTrace('dust', loc.bodyZone, 0.05); persistent.push({ type: 'dust', zone: loc.bodyZone }); }
    for (const e of events) {
      if (['crack', 'crack_aggravated', 'deform', 'tear', 'tear_widened', 'detach', 'shatter', 'break', 'shredded'].includes(e.type)) {
        persistent.push({ type: e.type, pieceId: e.pieceId });
      }
    }
    const record = {
      type: 'impact', key, time: state.time, attackType, bodyZone: loc.bodyZone,
      layers: layerReports.map((l) => ({ piece: l.piece, absorbed: l.absorbed, integrity: l.integrity, tier: l.tierAfter })),
      wounds: body.wounds.map((w) => w.id), healthDamage: body.healthDamage,
    };
    state.history.push(record);
    step('PERSISTANCE', persistent, persistent.length ? null : 'aucune conséquence visible durable');

    const presentation = this._presentation(events, body, bleedReports);

    return {
      impactId: key,
      chain,
      layers: layerReports,
      body,
      consequences,
      events: presentation.events,
      vfx: presentation.vfx,
      // §47 — les cinq questions
      answers: {
        whatWasHit: loc.layers.length ? `${loc.layers[0].piece.name} (${loc.layers[0].zone})` : loc.bodyZone,
        whatAbsorbed: layerReports.map((l) => ({ piece: l.name, absorbed: l.absorbed })),
        energyTransmitted: { penetrating: r3(main), blunt: r3(blunt) },
        physicalConsequence: { wounds: body.wounds, healthDamage: body.healthDamage, recoil: body.recoil, balanceLoss: body.balanceLoss },
        staysVisible: persistent,
      },
    };
  }

  /** §45 — lisibilité : les informations critiques ne sont jamais masquées par le spectacle. */
  _presentation(events, body, bleedReports) {
    const budget = this.config.vfxBudget;
    const critical = events.filter((e) => e.critical || ['detach', 'shatter', 'break', 'shredded', 'glance'].includes(e.type));
    const cosmetic = events.filter((e) => !critical.includes(e));
    const shownCosmetic = cosmetic.slice(0, budget.cosmeticEvents);
    const bloodSeverity = body.wounds.filter((w) => OPEN_WOUNDS.has(w.type)).reduce((s, w) => s + w.severity * w.severity, 0);
    return {
      events: [...critical, ...shownCosmetic],
      vfx: {
        bloodParticles: Math.min(budget.bloodParticles, Math.round(bloodSeverity * 120)),
        suppressedCosmeticEvents: cosmetic.length - shownCosmetic.length,
        cinematic: {
          // le spectaculaire est proposé, mais toujours subordonné à la lisibilité
          slowMotion: critical.some((e) => e.type === 'shatter' || e.type === 'break'),
          mustNotOcclude: ['health', 'stamina', 'guard', 'equipment_state'],
          bleedingIndicators: bleedReports.length,
        },
      },
    };
  }

  // ------------------------------------------------------------------ §34 explosif
  /**
   * @param {{id:string, center:number[], radius:number, energy:number, time?:number, element?:string, environment?:object}} explosion
   * @param {{state:import('./damageState.js').DamageState, position:number[]}[]} targets
   */
  resolveExplosion(explosion, targets) {
    const results = [];
    for (const { state, position } of targets) {
      const d = vec.dist(position, explosion.center);
      if (d > explosion.radius) continue;
      const falloff = (1 - d / explosion.radius) ** 2;
      const zones = [];
      for (const [zone, w] of Object.entries(EXPLOSION_EXPOSURE)) {
        const res = this.resolveImpact(state, {
          attackId: explosion.id, hitIndex: zone, time: explosion.time,
          attackType: explosion.element ? AttackType.ELEMENTAL : AttackType.EXPLOSIVE, element: explosion.element,
          force: explosion.energy * falloff * w, bodyZone: zone, angle: 0,
          environment: { ...(explosion.environment ?? {}), dusty: true },
        });
        zones.push(res);
      }
      const dir = vec.norm(vec.sub(position, explosion.center));
      const projection = vec.scale(dir, (explosion.energy * falloff) / state.mass * 0.5);
      state.balance = Math.max(0, state.balance - Math.min(1, falloff * 1.2));
      results.push({ combatantId: state.combatantId, distance: r3(d), falloff: r3(falloff), projection: projection.map(r3), zones });
    }
    return {
      explosionId: explosion.id,
      targets: results,
      environment: [
        { type: 'scorch', center: explosion.center, radius: explosion.radius * 0.4 },
        { type: 'debris', center: explosion.center, count: Math.round(explosion.energy / 20) },
        { type: 'dust_cloud', center: explosion.center, radius: explosion.radius },
      ],
    };
  }
}

function rankOfHit(state, h) {
  if (h.bodyZone) return layerRank(LayerKind.BODY);
  const p = state.getPiece(h.pieceId);
  return p ? layerRank(p.kind) : 99;
}
