// §40 — saignement, indépendant de la barre de vie.
// Courbe : début → augmentation → maximum → diminution progressive → écoulement résiduel (→ arrêt).
import { WoundType } from './constants.js';

const TYPE_FACTOR = {
  [WoundType.CUT]: 1,
  [WoundType.LACERATION]: 1.2,
  [WoundType.PUNCTURE]: 0.8,
  [WoundType.CRUSH]: 0.6,
  [WoundType.BLAST]: 0.7,
};

const BASE_RATE = 12; // ml/s pour une blessure de gravité 1, zone facteur 1

/**
 * Profil de saignement. La gravité est élevée au carré : une petite coupure
 * saigne beaucoup moins qu'une blessure majeure (§39 — pas d'effet disproportionné).
 */
export function bleedProfile(severity, zoneFactor, woundType, onsetLevel = 0) {
  const peak = severity * severity * zoneFactor * (TYPE_FACTOR[woundType] ?? 0) * BASE_RATE;
  return {
    peak,
    onset: Math.max(onsetLevel, peak * 0.35),
    rise: 1 + severity * 3,
    hold: 1 + severity * 6,
    tau: 4 + severity * 25,
    residual: peak * 0.04 * severity,
    // les blessures légères finissent par s'arrêter, les graves gardent un écoulement résiduel
    stopAfter: severity < 0.35 ? 1 + severity * 3 + 1 + severity * 6 + (4 + severity * 25) * 4 : Infinity,
  };
}

/**
 * @param {object} p   profil (bleedProfile)
 * @param {number} t   secondes depuis le début (ou la réouverture) de la blessure
 * @param {number} movement 0..1, intensité de l'effort
 */
export function bleedRateAt(p, t, movement = 0) {
  if (!p || p.peak <= 0) return { rate: 0, phase: 'none' };
  const move = 1 + 0.5 * Math.max(0, Math.min(1, movement));
  if (t >= p.stopAfter) return { rate: 0, phase: 'stopped' };
  if (t < p.rise) {
    const r = p.onset + (p.peak - p.onset) * (t / p.rise);
    return { rate: r * move, phase: t < p.rise * 0.25 ? 'onset' : 'rising' };
  }
  if (t < p.rise + p.hold) return { rate: p.peak * move, phase: 'peak' };
  const td = t - p.rise - p.hold;
  const r = p.residual + (p.peak - p.residual) * Math.exp(-td / p.tau);
  const phase = r <= p.residual * 1.5 + 1e-9 ? 'residual' : 'decaying';
  return { rate: r * move, phase };
}
