// §32 PRIORITÉ 1 — géométrie réelle : intersection rayon / volumes de collision.
// L'espace est local au personnage. Un moteur peut aussi fournir directement sa liste de hits.

export const vec = {
  add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]],
  sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
  scale: (a, s) => [a[0] * s, a[1] * s, a[2] * s],
  dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
  len: (a) => Math.hypot(a[0], a[1], a[2]),
  norm: (a) => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; },
  dist: (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]),
};

export function raySphere(origin, dir, center, radius) {
  const oc = vec.sub(origin, center);
  const b = vec.dot(oc, dir);
  const c = vec.dot(oc, oc) - radius * radius;
  const disc = b * b - c;
  if (disc < 0) return null;
  const s = Math.sqrt(disc);
  let t = -b - s;
  if (t < 0) t = -b + s;
  if (t < 0) return null;
  const point = vec.add(origin, vec.scale(dir, t));
  return { t, point, normal: vec.norm(vec.sub(point, center)) };
}

export function rayBox(origin, dir, min, max) {
  let tmin = -Infinity; let tmax = Infinity; let axis = -1; let sign = 0;
  for (let i = 0; i < 3; i++) {
    if (Math.abs(dir[i]) < 1e-12) {
      if (origin[i] < min[i] || origin[i] > max[i]) return null;
      continue;
    }
    let t1 = (min[i] - origin[i]) / dir[i];
    let t2 = (max[i] - origin[i]) / dir[i];
    if (t1 > t2) [t1, t2] = [t2, t1];
    if (t1 > tmin) { tmin = t1; axis = i; sign = -Math.sign(dir[i]); }
    if (t2 < tmax) tmax = t2;
    if (tmin > tmax) return null;
  }
  if (tmax < 0) return null;
  const t = Math.max(tmin, 0);
  const normal = [0, 0, 0];
  if (axis >= 0) normal[axis] = sign;
  return { t, point: vec.add(origin, vec.scale(dir, t)), normal };
}

export function rayCollider(origin, dir, collider) {
  if (collider.shape === 'sphere') return raySphere(origin, dir, collider.center, collider.radius);
  if (collider.shape === 'box') return rayBox(origin, dir, collider.min, collider.max);
  throw new Error(`Forme de collision inconnue : ${collider.shape}`);
}

/** Angle d'incidence en degrés (0 = frappe perpendiculaire à la surface). */
export function incidenceAngle(dir, normal) {
  const c = Math.min(1, Math.abs(vec.dot(vec.norm(dir), normal)));
  return (Math.acos(c) * 180) / Math.PI;
}
