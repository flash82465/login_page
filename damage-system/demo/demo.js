// Démo : un chevalier encaisse une série de coups ; on affiche la chaîne de résolution
// et l'historique visible du combattant.  →  npm run demo
import {
  DamageResolver, DamageState, createKnight, createSword, frontalStrike, resolveWeaponClash,
  AttackType, RestoreReason,
} from '../src/index.js';

const resolver = new DamageResolver();
const knight = createKnight('chevalier', { withShield: false });
const attackerSword = createSword('epee_adverse');
const CHEST = [0.05, 1.3, 0.11];

console.log('=== Série de coups lourds sur le plastron (§41 cumul) ===');
for (let i = 1; i <= 5; i++) {
  const r = resolver.resolveImpact(knight, {
    attackId: `masse_${i}`, time: i * 1.5, attackType: AttackType.HEAVY, force: 115,
    attackerWeapon: attackerSword, ...frontalStrike(CHEST),
  });
  const plate = r.layers.find((l) => l.kind === 'armor');
  console.log(`Impact ${i} — touché : ${r.answers.whatWasHit}`);
  console.log(`   plastron : ${plate ? `${plate.tierBefore} → ${plate.tierAfter} (intégrité ${plate.integrity})` : 'absent (détruit)'}`);
  console.log(`   transmis : pénétrant ${r.answers.energyTransmitted.penetrating}, contondant ${r.answers.energyTransmitted.blunt}`);
  console.log(`   blessures : ${r.body.wounds.map((w) => `${w.type}@${w.zone} ${w.severity}${w.aggravated ? ' (aggravée)' : ''}`).join(', ') || 'aucune'}`);
  console.log(`   événements : ${r.events.map((e) => e.type).join(', ') || '—'}`);
  knight.update(1.5, { movement: 0.6 });
}

console.log('\n=== Chaîne officielle du dernier impact (§47) ===');
const last = resolver.resolveImpact(knight, { attackId: 'estoc', attackType: AttackType.PIERCE, force: 70, ...frontalStrike([-0.1, 1.05, 0.11]) });
for (const c of last.chain) console.log(` ${c.step.padEnd(13)} ${c.skipped ? `(ignorée : ${c.skipped})` : JSON.stringify(c.data).slice(0, 110)}`);

console.log('\n=== Arme contre arme (§38) ===');
const worn = createSword('epee_usee', { state: { integrity: 0.3, cracks: [{ id: 'c1', zone: 'blade', severity: 0.8, hits: 4 }] } });
const fresh = createSword('epee_neuve');
for (let i = 1; i <= 3 && !worn.destroyed; i++) {
  const c = resolveWeaponClash({ weapon: fresh, speed: 10, zone: 'blade' }, { weapon: worn, speed: 10, zone: 'blade' }, { id: `choc${i}` });
  console.log(` choc ${i} : neuve ${c.a.integrityAfter} (${c.a.tier}) | usée ${c.b.integrityAfter} (${c.b.tier})${c.b.broken ? ' → BRISÉE' : ''}`);
}

console.log('\n=== Tournoi : sauvegarde / chargement entre deux combats (§46) ===');
knight.update(30, { movement: 0.2, environment: { rain: 0.5 } });
const saved = JSON.stringify(knight.toJSON());
const nextRound = DamageState.fromJSON(JSON.parse(saved));
try { nextRound.restore('reset'); } catch (e) { console.log(' ' + e.message); }
nextRound.restore(RestoreReason.REST, { amount: 0.3 });
console.log(JSON.stringify(nextRound.summary(), null, 1).split('\n').slice(0, 60).join('\n'));
