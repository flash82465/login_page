import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DamageResolver, DamageState, EquipmentPiece, ImpactQueue, RESOLUTION_CHAIN, RestoreReason,
  createKnight, createSword, frontalStrike, resolveWeaponClash, bleedProfile, bleedRateAt, limbModifiers,
  AttackType, BodyZone, LayerKind, IntegrityTier, Element, WoundType,
} from '../src/index.js';

const resolver = new DamageResolver();
const CHEST = [0.05, 1.3, 0.11];
let n = 0;
const hit = (state, type, force, target = CHEST, extra = {}) =>
  resolver.resolveImpact(state, { attackId: `t${++n}`, attackType: type, force, ...frontalStrike(target), ...extra });

test('§47 — la chaîne officielle est complète et dans l’ordre', () => {
  const k = createKnight('k', { withShield: false });
  const r = hit(k, AttackType.BLUNT, 100);
  assert.deepEqual(r.chain.map((c) => c.step), [...RESOLUTION_CHAIN]);
  for (const c of r.chain) if (c.skipped) assert.ok(c.skipped.length > 0, `étape ${c.step} ignorée sans justification`);
  assert.ok(r.answers.whatWasHit && r.answers.whatAbsorbed && r.answers.energyTransmitted && r.answers.staysVisible);
});

test('§32 P1/P2 — géométrie : plastron puis gambison puis torse, de l’extérieur vers l’intérieur', () => {
  const k = createKnight('k', { withShield: false });
  const r = hit(k, AttackType.SLASH, 80);
  assert.deepEqual(r.layers.map((l) => l.kind), [LayerKind.ARMOR, LayerKind.CLOTHING]);
  assert.equal(r.body.bodyZone, BodyZone.TORSO);
  assert.equal(r.answers.whatWasHit, 'Plastron (plastron)');
});

test('§32 P2 — le plastron encaisse : le torse ne reçoit pas les mêmes dégâts', () => {
  const armored = createKnight('a', { withShield: false });
  const naked = new DamageState({ combatantId: 'n', bodyColliders: armored.bodyColliders });
  const ra = hit(armored, AttackType.SLASH, 100);
  const rn = hit(naked, AttackType.SLASH, 100);
  assert.ok(ra.body.rawHealthDamage < rn.body.rawHealthDamage / 3);
  assert.ok(rn.body.wounds.some((w) => w.type === WoundType.CUT || w.type === WoundType.LACERATION));
  assert.ok(!ra.body.wounds.some((w) => w.type === WoundType.CUT));
});

test('§32 P1 — le bouclier interposé est touché avant le corps, le choc part dans le bras porteur', () => {
  const k = createKnight('k');
  const r = hit(k, AttackType.BLUNT, 90, [-0.25, 1.2, 0.1]);
  assert.equal(r.layers[0].kind, LayerKind.SHIELD);
  assert.ok(r.body.wounds.length > 0);
  assert.ok(r.body.wounds.every((w) => w.zone === BodyZone.LEFT_ARM && w.type === WoundType.CONTUSION));
  assert.equal(r.answers.energyTransmitted.penetrating, 0);
});

test('§43 — zones vulnérables : la fixation du casque cède plus vite que la face', () => {
  const a = createKnight('a', { withShield: false });
  const b = createKnight('b', { withShield: false });
  const face = hit(a, AttackType.BLUNT, 90, [0, 1.75, 0.08]);
  const attach = hit(b, AttackType.BLUNT, 90, [0, 1.52, 0.1]);
  assert.equal(face.layers[0].zone, 'face');
  assert.equal(attach.layers[0].zone, 'attachment');
  assert.ok(attach.layers[0].structuralDamage > face.layers[0].structuralDamage * 2);
});

test('§41/§32 P4 — cumul : fissure → aggravation → rupture → la couche suivante est visée', () => {
  const k = createKnight('k', { withShield: false });
  const plate = k.getPiece('k_breastplate');
  const seen = [];
  let afterBreak = null;
  for (let i = 0; i < 6; i++) {
    const r = hit(k, AttackType.HEAVY, 140);
    seen.push(...r.events.map((e) => e.type));
    if (plate.destroyed && afterBreak === null && !r.layers.some((l) => l.piece === plate.id)) afterBreak = r;
  }
  assert.ok(seen.includes('crack'));
  assert.ok(seen.includes('crack_aggravated'));
  assert.ok(seen.includes('break'));
  assert.ok(seen.indexOf('crack') < seen.indexOf('crack_aggravated'));
  assert.ok(seen.indexOf('crack_aggravated') < seen.indexOf('break'));
  assert.equal(plate.tier, IntegrityTier.DESTROYED);
  assert.ok(afterBreak, 'après rupture, l’attaque vise directement la couche suivante');
  assert.ok(plate.history.length >= 3, 'historique conservé');
});

test('§32 P4 — une pièce fissurée est plus vulnérable qu’une pièce neuve (déterministe)', () => {
  const a = createKnight('a', { withShield: false });
  const b = createKnight('b', { withShield: false });
  hit(a, AttackType.HEAVY, 140);
  const second = hit(a, AttackType.BLUNT, 80).layers[0];
  const fresh = hit(b, AttackType.BLUNT, 80).layers[0];
  assert.ok(second.weakness > fresh.weakness);
  assert.ok(second.structuralDamage > fresh.structuralDamage);
  // §37 : même entrée → même résultat
  const c = createKnight('c', { withShield: false });
  const d = createKnight('d', { withShield: false });
  assert.deepEqual(hit(c, AttackType.HEAVY, 120).layers, hit(d, AttackType.HEAVY, 120).layers.map((l) => ({ ...l, piece: l.piece.replace('d_', 'c_') })));
});

test('§33 — une armure efficace réduit mais transmet un choc contondant', () => {
  const k = createKnight('k', { withShield: false });
  const r = hit(k, AttackType.BLUNT, 120);
  assert.equal(r.answers.energyTransmitted.penetrating, 0);
  assert.ok(r.answers.energyTransmitted.blunt > 0);
  assert.ok(r.body.wounds.some((w) => w.type === WoundType.CONTUSION));
  assert.ok(r.body.recoil > 0 && r.body.balanceLoss > 0);
  assert.ok(r.consequences.pain > 0 && r.consequences.fatigue > 0);
});

test('§34 — tranchant coupe le tissu, pas le métal lourd ; lourd détruit l’équipement', () => {
  const mk = (material) => {
    const s = new DamageState({ combatantId: material });
    s.equip(new EquipmentPiece({ id: 'p', kind: LayerKind.ARMOR, material, covers: [BodyZone.TORSO] }));
    return s;
  };
  const z = { bodyZone: BodyZone.TORSO };
  const slashCloth = resolver.resolveImpact(mk('cloth'), { attackId: 'x', attackType: AttackType.SLASH, force: 60, ...z });
  const slashPlate = resolver.resolveImpact(mk('heavy_metal'), { attackId: 'x', attackType: AttackType.SLASH, force: 60, ...z });
  assert.ok(slashCloth.answers.energyTransmitted.penetrating > 30);
  assert.equal(slashPlate.answers.energyTransmitted.penetrating, 0);
  const heavy = resolver.resolveImpact(mk('heavy_metal'), { attackId: 'y', attackType: AttackType.HEAVY, force: 100, ...z });
  const slash = resolver.resolveImpact(mk('heavy_metal'), { attackId: 'y', attackType: AttackType.SLASH, force: 100, ...z });
  assert.ok(heavy.layers[0].structuralDamage > slash.layers[0].structuralDamage * 3);
});

test('§34 — élémentaire : la foudre traverse le métal, surtout sous la pluie ; le feu enflamme le tissu', () => {
  const mk = (material) => {
    const s = new DamageState({ combatantId: material });
    s.equip(new EquipmentPiece({ id: 'p', kind: LayerKind.ARMOR, material, covers: [BodyZone.TORSO] }));
    return s;
  };
  const base = { attackType: AttackType.ELEMENTAL, element: Element.LIGHTNING, force: 80, bodyZone: BodyZone.TORSO };
  const dry = resolver.resolveImpact(mk('heavy_metal'), { attackId: 'l1', ...base });
  const wet = resolver.resolveImpact(mk('heavy_metal'), { attackId: 'l2', ...base, environment: { wet: true } });
  const leather = resolver.resolveImpact(mk('leather'), { attackId: 'l3', ...base });
  assert.ok(wet.answers.energyTransmitted.penetrating > dry.answers.energyTransmitted.penetrating);
  assert.ok(dry.answers.energyTransmitted.penetrating > leather.answers.energyTransmitted.penetrating);
  const fire = resolver.resolveImpact(mk('cloth'), { attackId: 'f', attackType: AttackType.ELEMENTAL, element: Element.FIRE, force: 30, bodyZone: BodyZone.TORSO });
  assert.ok(fire.events.some((e) => e.type === 'status_burning'));
  assert.ok(fire.body.wounds.some((w) => w.type === WoundType.BURN));
});

test('§35 — une couche détruite pendant l’impact laisse passer plus d’énergie', () => {
  const mk = (integrity) => {
    const s = new DamageState({ combatantId: 's' });
    s.equip(new EquipmentPiece({ id: 'g', kind: LayerKind.ARMOR, material: 'glass', covers: [BodyZone.TORSO], state: { integrity } }));
    return s;
  };
  const intact = resolver.resolveImpact(mk(1), { attackId: 'a', attackType: AttackType.PIERCE, force: 25, bodyZone: BodyZone.TORSO });
  const fragile = resolver.resolveImpact(mk(0.05), { attackId: 'a', attackType: AttackType.PIERCE, force: 25, bodyZone: BodyZone.TORSO });
  assert.equal(fragile.layers[0].broke, true);
  assert.ok(fragile.answers.energyTransmitted.penetrating > intact.answers.energyTransmitted.penetrating);
});

test('§36 — paliers d’intégrité et perte progressive d’efficacité ; 0 % = retiré de la collision', () => {
  const p = new EquipmentPiece({ id: 'p', kind: LayerKind.ARMOR, material: 'heavy_metal', covers: [BodyZone.TORSO] });
  const tiers = [];
  for (const i of [1, 0.75, 0.5, 0.25]) { p.integrity = i; tiers.push([p.tier, p.efficiency]); }
  assert.deepEqual(tiers.map((t) => t[0]), [IntegrityTier.INTACT, IntegrityTier.LIGHT, IntegrityTier.HEAVY, IntegrityTier.CRITICAL]);
  for (let i = 1; i < tiers.length; i++) assert.ok(tiers[i][1] < tiers[i - 1][1]);
  const s = new DamageState({ combatantId: 's' });
  s.equip(new EquipmentPiece({ id: 'gone', kind: LayerKind.ARMOR, material: 'cloth', covers: [BodyZone.TORSO], state: { integrity: 0, destroyed: true } }));
  const r = resolver.resolveImpact(s, { attackId: 'z', attackType: AttackType.SLASH, force: 20, bodyZone: BodyZone.TORSO });
  assert.equal(r.layers.length, 0);
});

test('§38 — épée intacte contre épée endommagée : la plus faible se brise', () => {
  const intact = createSword('a');
  const damaged = createSword('b', { state: { integrity: 0.3, cracks: [{ id: 'c', zone: 'blade', severity: 0.8, hits: 3 }] } });
  let res;
  for (let i = 0; i < 3 && !damaged.destroyed; i++) {
    res = resolveWeaponClash({ weapon: intact, speed: 10, zone: 'blade' }, { weapon: damaged, speed: 10, zone: 'blade' }, { id: `clash${i}` });
  }
  assert.equal(damaged.destroyed, true);
  assert.equal(intact.destroyed, false);
  assert.ok(intact.integrity > 0.5);
  assert.ok(res.b.events.some((e) => e.type === 'break'));
});

test('§39/§40 — saignement proportionnel, courbe complète, indépendant de la vie', () => {
  const small = bleedProfile(0.1, 1, WoundType.CUT);
  const major = bleedProfile(0.8, 1, WoundType.CUT);
  assert.ok(major.peak > small.peak * 30);
  const phases = new Set();
  for (let t = 0; t < 200; t += 0.25) phases.add(bleedRateAt(major, t).phase);
  for (const ph of ['onset', 'rising', 'peak', 'decaying', 'residual']) assert.ok(phases.has(ph), ph);
  assert.equal(bleedRateAt(small, 500).phase, 'stopped');
  assert.ok(bleedRateAt(major, 3, 1).rate > bleedRateAt(major, 3, 0).rate, 'le mouvement augmente le débit');

  const s = new DamageState({ combatantId: 's' });
  resolver.resolveImpact(s, { attackId: 'c', attackType: AttackType.SLASH, force: 50, bodyZone: BodyZone.LEFT_ARM });
  const hp = s.health;
  s.update(20, { movement: 0.5 });
  assert.equal(s.health, hp, 'le saignement ne touche pas la barre de vie');
  assert.ok(s.bloodVolume < s.maxBloodVolume);
});

test('§40 — même zone : aggravation de la blessure ; autre zone : nouvelle blessure', () => {
  const s = new DamageState({ combatantId: 's' });
  const z = (attackId, bodyZone) => resolver.resolveImpact(s, { attackId, attackType: AttackType.SLASH, force: 30, bodyZone });
  z('1', BodyZone.LEFT_ARM);
  s.update(15);
  const before = s.bleedRate(s.wounds[0]).rate;
  const r2 = z('2', BodyZone.LEFT_ARM);
  assert.equal(s.wounds.filter((w) => w.type === WoundType.CUT).length, 1);
  assert.ok(r2.body.wounds[0].aggravated);
  assert.ok(s.wounds[0].bleed.peak > bleedProfile(r2.body.wounds[0].severity, 0.9, WoundType.CUT).peak);
  assert.ok(s.bleedRate(s.wounds[0]).rate >= before);
  z('3', BodyZone.RIGHT_LEG);
  assert.equal(s.wounds.filter((w) => w.type === WoundType.CUT).length, 2);
});

test('§42 — impacts multiples : ordre temporel, puis extérieur d’abord ; un coup compté une seule fois', () => {
  const k = createKnight('k', { withShield: false });
  const q = new ImpactQueue();
  const base = { attackType: AttackType.BLUNT, force: 60 };
  q.push(k, { ...base, attackId: 'late', time: 0.2, bodyZone: BodyZone.LEFT_LEG });
  q.push(k, { ...base, attackId: 'swing', time: 0.1, ...frontalStrike(CHEST) });
  q.push(k, { ...base, attackId: 'swing', time: 0.1004, ...frontalStrike(CHEST) }); // collision successive du même coup
  q.push(k, { ...base, attackId: 'early', time: 0.05, bodyZone: BodyZone.RIGHT_LEG });
  const res = q.flush(resolver);
  assert.deepEqual(res.map((r) => r.impactId), ['early:0', 'swing:0', 'swing:0', 'late:0']);
  assert.equal(res[2].skipped, true);
  assert.equal(k.getPiece('k_breastplate').hitCount, 1);
  // le résolveur rejette aussi un doublon hors file
  assert.equal(resolver.resolveImpact(k, { ...base, attackId: 'swing', ...frontalStrike(CHEST) }).skipped, true);
});

test('§44 — membres : effets progressifs, jamais incapable d’agir', () => {
  const s = new DamageState({ combatantId: 's' });
  for (let i = 0; i < 6; i++) resolver.resolveImpact(s, { attackId: `l${i}`, attackType: AttackType.SLASH, force: 60, bodyZone: BodyZone.RIGHT_LEG });
  resolver.resolveImpact(s, { attackId: 'h', attackType: AttackType.BLUNT, force: 50, bodyZone: BodyZone.RIGHT_HAND });
  const m = limbModifiers(s.limbs, resolver.config.minLimbFunction);
  assert.ok(m.moveSpeed < 1 && m.moveSpeed >= 0.55 + 0.45 * 0.5 * (1 + 0.35) - 1e-9);
  assert.ok(m.grip < 1 && m.grip > 0.5);
  assert.equal(m.attackSpeed, 1, 'les bras intacts ne sont pas affectés');
  assert.ok(m.animations.includes('right_leg_impaired'));
});

test('§45 — un coup unique ne retire jamais plus que le plafond compétitif', () => {
  const s = new DamageState({ combatantId: 's' });
  const r = resolver.resolveImpact(s, { attackId: 'x', attackType: AttackType.HEAVY, force: 2000, bodyZone: BodyZone.HEAD });
  assert.ok(r.body.rawHealthDamage > r.body.healthDamage);
  assert.equal(r.body.healthDamage, 45);
  assert.ok(r.vfx.bloodParticles <= resolver.config.vfxBudget.bloodParticles);
  assert.ok(r.vfx.cinematic.mustNotOcclude.includes('health'));
});

test('§46/§48 — persistance tournoi et non-réinitialisation', () => {
  const k = createKnight('k', { withShield: false });
  for (let i = 0; i < 4; i++) hit(k, AttackType.HEAVY, 140);
  k.update(10, { environment: { rain: 1 } });
  const saved = JSON.parse(JSON.stringify(k.toJSON()));
  const restored = DamageState.fromJSON(saved);
  assert.deepEqual(restored.summary(), k.summary());
  assert.equal(restored.getPiece('k_breastplate').destroyed, true);
  assert.equal(restored.processedImpacts.size, k.processedImpacts.size);

  assert.throws(() => restored.restore('because'), /refusée/);
  assert.throws(() => restored.restore(RestoreReason.REPAIR, { pieceId: 'k_breastplate' }), /détruite/);
  const before = restored.wounds.length;
  restored.restore(RestoreReason.HEAL, { amount: 1 });
  assert.equal(restored.wounds.length, before, 'les blessures soignées restent dans l’historique');
  assert.ok(restored.wounds.every((w) => restored.bleedRate(w).rate === 0));
  restored.restore(RestoreReason.REPLACE_EQUIPMENT, {
    pieceId: 'k_breastplate',
    newPiece: new EquipmentPiece({ id: 'k_breastplate2', name: 'Plastron neuf', kind: LayerKind.ARMOR, material: 'heavy_metal', covers: [BodyZone.TORSO] }),
  });
  assert.equal(restored.archivedPieces.length, 1);
  assert.ok(restored.history.filter((h) => h.type === 'restore').length === 2);
});

test('§48 — la pluie atténue le sang sans jamais l’effacer', () => {
  const s = new DamageState({ combatantId: 's' });
  resolver.resolveImpact(s, { attackId: 'c', attackType: AttackType.SLASH, force: 60, bodyZone: BodyZone.TORSO });
  s.update(5);
  const t = Object.values(s.traces.blood)[0];
  const max = t.max;
  s.update(3600, { environment: { rain: 1 } });
  assert.ok(t.intensity >= max * 0.25 - 1e-9);
  assert.ok(t.intensity > 0);
});

test('§34 — explosion : dégâts de zone, projection, environnement', () => {
  const a = createKnight('a', { withShield: false });
  const b = createKnight('b', { withShield: false });
  const r = resolver.resolveExplosion({ id: 'boom', center: [0, 0, 0], radius: 6, energy: 400 },
    [{ state: a, position: [1, 0, 0] }, { state: b, position: [4, 0, 0] }]);
  assert.equal(r.targets.length, 2);
  assert.ok(r.targets[0].projection[0] > r.targets[1].projection[0]);
  assert.ok(r.targets[0].zones.length > 5);
  assert.ok(r.environment.some((e) => e.type === 'debris'));
  assert.ok(Object.keys(a.traces.dust).length > 0);
});
