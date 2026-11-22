#!/usr/bin/env python3
"""Revue visuelle OKÉLUN (mission 005).

Compare, pixel à pixel, les captures du code actuel à celles d'une version de référence,
fabrique les GIF des séquences et rédige la page de revue de l'étape, puis le README de la
branche de revue (qui ne contient que des images et ces pages).
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops


def parse_mask(text: str):
    """« x0,y0,x1,y1 » en fractions de l'image (0 à 1) : zone exclue de la comparaison."""
    if not text:
        return None
    values = [float(v) for v in text.split(",")]
    if len(values) != 4 or not (0 <= values[0] < values[2] <= 1 and 0 <= values[1] < values[3] <= 1):
        raise SystemExit(f"masque invalide : {text}")
    return tuple(values)


def blank(img: Image.Image, mask) -> Image.Image:
    if mask is None:
        return img
    w, h = img.size
    box = (int(mask[0] * w), int(mask[1] * h), int(round(mask[2] * w)), int(round(mask[3] * h)))
    img = img.copy()
    img.paste((0, 0, 0), box)
    return img


def compare(current: Path, reference: Path, mask=None) -> dict:
    """Compte, pour chaque image, les pixels dont au moins un canal diffère (hors masque éventuel)."""
    def pngs(root: Path) -> set:
        return {p.relative_to(root).as_posix() for p in root.rglob("*.png")
                if p.relative_to(root).parts[0] in ("raw", "sequences")}

    cur, ref = pngs(current), pngs(reference)
    rows = []
    for rel in sorted(cur):
        if rel not in ref:
            rows.append({"file": rel, "status": "absente de la référence"})
            continue
        a = blank(Image.open(current / rel).convert("RGB"), mask)
        b = blank(Image.open(reference / rel).convert("RGB"), mask)
        if a.size != b.size:
            rows.append({"file": rel, "status": f"taille {a.size} au lieu de {b.size}"})
            continue
        r, g, bl = ImageChops.difference(a, b).split()
        hist = ImageChops.lighter(ImageChops.lighter(r, g), bl).histogram()
        changed = sum(hist[1:])
        rows.append({"file": rel, "pixels": changed,
                     "max": max((i for i, c in enumerate(hist) if c), default=0)})
    missing = sorted(ref - cur)
    different = [r for r in rows if r.get("pixels", 1) != 0]
    return {"total": len(rows), "identical_count": len(rows) - len(different),
            "different": different, "missing": missing,
            "identical": not different and not missing and len(rows) > 0}


def make_gifs(current: Path, manifest: dict, dest: Path) -> list:
    gifs = []
    for seq in manifest["sequences"]:
        if seq.get("format") == "mp4":
            out = dest / f"{seq['dir']}.mp4"
            subprocess.run([
                "ffmpeg", "-loglevel", "error", "-y", "-framerate", str(seq["fps"]),
                "-i", str(current / "sequences" / seq["dir"] / "f_%04d.png"),
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "27", "-movflags", "+faststart", str(out)], check=True)
            gifs.append({"file": out.name, "title": seq["title"], "size": out.stat().st_size, "video": True})
            continue
        out = dest / f"{seq['dir']}.gif"
        subprocess.run([
            "ffmpeg", "-loglevel", "error", "-y", "-framerate", str(seq["fps"]),
            "-i", str(current / "sequences" / seq["dir"] / "f_%04d.png"),
            "-vf", "split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
            "-loop", "0", str(out)], check=True)
        gifs.append({"file": out.name, "title": seq["title"], "size": out.stat().st_size})
    return gifs


def comparison_lines(label: str, reference: str, result: dict, mask=None) -> list:
    zone = "" if mask is None else (f" (zone exclue : x {mask[0]:.3f}-{mask[2]:.3f}, "
                                    f"y {mask[1]:.3f}-{mask[3]:.3f} de l'image)")
    if result["identical"]:
        return [f"- **{label} `{reference}` : ✅ identique au pixel près sur "
                f"{result['total']} images sur {result['total']}**{zone}"]
    lines = [f"- **{label} `{reference}` : ❌ {len(result['different'])} image(s) différente(s), "
             f"{len(result['missing'])} manquante(s), sur {result['total']}**{zone}"]
    for r in result["different"][:12]:
        detail = r.get("status") or f"{r['pixels']} pixels, écart maximal {r['max']}/255"
        lines.append(f"  - `{r['file']}` : {detail}")
    return lines


def page(prefix: str, a: argparse.Namespace, manifest: dict, result, extras: list, gifs: list, heading: str) -> str:
    short = a.commit[:7]
    lines = [f"{heading} {a.title}", ""]
    lines.append(f"- Code capturé : [`{short}`]({a.repo_url}/commit/{a.commit}) "
                 f"(branche `{a.branch}`)")
    lines.append(f"- Rendu : {manifest['renderer']}, 1920 × 1080, 60 images/s fixes, interface masquée")
    if result is None:
        lines.append("- Comparaison pixel à pixel : aucune référence demandée")
    else:
        lines += comparison_lines(a.compare_label, a.reference, result)
    for extra in extras:
        lines += comparison_lines(extra["label"], a.reference, extra["result"], extra["mask"])
    lines.append(f"- Exécution : [journal et artefact]({a.run_url})")
    lines.append("")
    lines.append("Touchez une image pour l'ouvrir en grand, puis zoomez.")
    lines.append("")
    for p in manifest["planches"]:
        lines += [f"### {p['title']}", "", f"![{p['title']}]({prefix}{p['file']})", ""]
    if gifs:
        lines += ["### Séquences animées", ""]
        for g in gifs:
            if g.get("video"):
                lines += [f"**{g['title']}** : [ouvrir la vidéo MP4]({prefix}{g['file']}) ({g['size'] // 1024} Ko)", ""]
                continue
            lines += [f"**{g['title']}** ({g['size'] // 1024} Ko)", "", f"![{g['title']}]({prefix}{g['file']})", ""]
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--current", type=Path, required=True)
    ap.add_argument("--reference-dir", type=Path)
    ap.add_argument("--reference", default="aucune")
    ap.add_argument("--compare-dir", type=Path, help="captures comparées à la référence (par défaut : --current)")
    ap.add_argument("--compare-label", default="Équivalence avec")
    ap.add_argument("--extra", action="append", default=[],
                    help="comparaison supplémentaire « LIBELLÉ::CAPTURES::RÉFÉRENCE[::x0,y0,x1,y1] » (masque facultatif)")
    ap.add_argument("--review", type=Path, required=True)
    ap.add_argument("--step", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--commit", required=True)
    ap.add_argument("--branch", required=True)
    ap.add_argument("--repo-url", required=True)
    ap.add_argument("--run-url", required=True)
    ap.add_argument("--result", type=Path, required=True)
    a = ap.parse_args()

    manifest = json.loads((a.current / "manifest.json").read_text(encoding="utf-8"))
    result = compare(a.compare_dir or a.current, a.reference_dir) if a.reference_dir else None
    extras = []
    for spec in a.extra:
        parts = spec.split("::")
        if len(parts) not in (3, 4):
            raise SystemExit(f"--extra invalide : {spec}")
        mask = parse_mask(parts[3]) if len(parts) == 4 else None
        extras.append({"label": parts[0], "mask": mask,
                       "result": compare(Path(parts[1]), Path(parts[2]), mask)})

    dest = a.review / a.step
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    for p in manifest["planches"]:
        shutil.copy2(a.current / "planches" / p["file"], dest / p["file"])
    gifs = make_gifs(a.current, manifest, dest)
    (dest / "index.md").write_text(page("", a, manifest, result, extras, gifs, "#"), encoding="utf-8")
    (dest / "section.md").write_text(page(f"{a.step}/", a, manifest, result, extras, gifs, "##"), encoding="utf-8")

    steps = sorted(d for d in a.review.iterdir() if d.is_dir() and (d / "section.md").exists())
    readme = ["# OKÉLUN — revue visuelle de la mission 005", "",
              "Images produites par le banc de capture (workflow « Revue visuelle (planches) ») : "
              "le vrai jeu, rendu image par image. Cette branche ne contient que ces images et leurs pages.", "",
              "Étapes : " + " · ".join(f"[{d.name}]({d.name}/index.md)" for d in steps), ""]
    for d in steps:
        readme.append((d / "section.md").read_text(encoding="utf-8"))
    (a.review / "README.md").write_text("\n".join(readme), encoding="utf-8")

    all_identical = all(r["identical"] for r in [result] + [e["result"] for e in extras] if r is not None)
    a.result.write_text(json.dumps({"comparison": result, "extra_comparisons": extras, "all_identical": all_identical,
                                    "gifs": gifs}, indent=2, ensure_ascii=False), encoding="utf-8")
    if result is not None:
        print(f"COMPARAISON : {result['identical_count']}/{result['total']} images identiques, "
              f"{len(result['different'])} différentes, {len(result['missing'])} manquantes")
    for e in extras:
        r = e["result"]
        print(f"COMPARAISON {e['label']} : {r['identical_count']}/{r['total']} images identiques, "
              f"{len(r['different'])} différentes, {len(r['missing'])} manquantes")
    print("REVUE prête :", ", ".join(sorted(p.name for p in dest.iterdir())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
