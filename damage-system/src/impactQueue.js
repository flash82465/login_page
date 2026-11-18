// §42 — impacts multiples quasi simultanés.
import { layerRank } from './constants.js';

/**
 * Ordre de résolution :
 *  1. ordre temporel réel (regroupé par fenêtre de simultanéité)
 *  2. localisation (couche la plus extérieure d'abord)
 *  3. puissance (décroissante)
 *  4. surface de contact (la plus concentrée d'abord)
 *  5. priorité de collision (décroissante)
 *  6. l'état des protections est celui du moment exact : résolution séquentielle.
 * Un même coup (attackId + hitIndex) sur une même cible n'est compté qu'une fois.
 */
export class ImpactQueue {
  constructor({ simultaneityWindow = 0.001 } = {}) {
    this.window = simultaneityWindow;
    this.pending = [];
    this._order = 0;
  }

  push(state, impact) {
    this.pending.push({ state, impact, order: this._order++ });
    return this;
  }

  get size() { return this.pending.length; }

  /** @param {import('./resolver.js').DamageResolver} resolver */
  flush(resolver) {
    const items = this.pending.map((it) => {
      let rank = 99;
      try {
        const loc = resolver.localize(it.state, it.impact);
        rank = loc.layers.length ? layerRank(loc.layers[0].piece.kind) : layerRank('body');
      } catch { /* non localisable : résolu en dernier dans son groupe */ }
      return { ...it, rank };
    });
    this.pending = [];
    items.sort((x, y) => {
      const a = x.impact; const b = y.impact;
      return Math.floor((a.time ?? 0) / this.window) - Math.floor((b.time ?? 0) / this.window)
        || x.rank - y.rank
        || (b.force ?? 0) - (a.force ?? 0)
        || (a.contactArea ?? 1) - (b.contactArea ?? 1)
        || (b.collisionPriority ?? 0) - (a.collisionPriority ?? 0)
        || x.order - y.order;
    });
    const seen = new Set();
    const results = [];
    for (const it of items) {
      const k = `${it.state.combatantId}|${resolver.impactKey(it.impact)}`;
      if (seen.has(k)) { results.push({ impactId: resolver.impactKey(it.impact), skipped: true, reason: 'duplicate_collision', combatantId: it.state.combatantId }); continue; }
      seen.add(k);
      results.push({ ...resolver.resolveImpact(it.state, it.impact), combatantId: it.state.combatantId });
    }
    return results;
  }
}
