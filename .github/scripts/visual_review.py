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


def compare(current: Path, reference: Path) -> dict:
    """Compte, pour chaque image, les pixels dont au moins un canal diffère."""
    def pngs(root: Path) -> set:
        return {p.relative_to(root).as_posix() for p in root.rglob("*.png")
                if p.relative_to(root).parts[0] in ("raw", "sequences")}

    cur, ref = pngs(current), pngs(reference)
    rows = []
    for rel in sorted(cur):
        if rel not in ref:
            rows.append({"file": rel, "status": "absente de la référence"})
            continue
        a = Image.open(current / rel).convert("RGB")
        b = Image.open(reference / rel).convert("RGB")
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


def page(prefix: str, a: argparse.Namespace, manifest: dict, result, gifs: list, heading: str) -> str:
    short = a.commit[:7]
    lines = [f"{heading} {a.title}", ""]
    lines.append(f"- Code capturé : [`{short}`]({a.repo_url}/commit/{a.commit}) "
                 f"(branche `{a.branch}`)")
    lines.append(f"- Rendu : {manifest['renderer']}, 1920 × 1080, 60 images/s fixes, interface masquée")
    if result is None:
        lines.append("- Comparaison pixel à pixel : aucune référence demandée")
    elif result["identical"]:
        lines.append(f"- **{a.compare_label} `{a.reference}` : ✅ identique au pixel près sur "
                     f"{result['total']} images sur {result['total']}** (états et séquences)")
    else:
        lines.append(f"- **{a.compare_label} `{a.reference}` : ❌ {len(result['different'])} image(s) différente(s), "
                     f"{len(result['missing'])} manquante(s), sur {result['total']}**")
        for r in result["different"][:12]:
            detail = r.get("status") or f"{r['pixels']} pixels, écart maximal {r['max']}/255"
            lines.append(f"  - `{r['file']}` : {detail}")
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

    dest = a.review / a.step
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    for p in manifest["planches"]:
        shutil.copy2(a.current / "planches" / p["file"], dest / p["file"])
    gifs = make_gifs(a.current, manifest, dest)
    (dest / "index.md").write_text(page("", a, manifest, result, gifs, "#"), encoding="utf-8")
    (dest / "section.md").write_text(page(f"{a.step}/", a, manifest, result, gifs, "##"), encoding="utf-8")

    steps = sorted(d for d in a.review.iterdir() if d.is_dir() and (d / "section.md").exists())
    readme = ["# OKÉLUN — revue visuelle de la mission 005", "",
              "Images produites par le banc de capture (workflow « Revue visuelle (planches) ») : "
              "le vrai jeu, rendu image par image. Cette branche ne contient que ces images et leurs pages.", "",
              "Étapes : " + " · ".join(f"[{d.name}]({d.name}/index.md)" for d in steps), ""]
    for d in steps:
        readme.append((d / "section.md").read_text(encoding="utf-8"))
    (a.review / "README.md").write_text("\n".join(readme), encoding="utf-8")

    a.result.write_text(json.dumps({"comparison": result, "gifs": gifs}, indent=2, ensure_ascii=False), encoding="utf-8")
    if result is not None:
        print(f"COMPARAISON : {result['identical_count']}/{result['total']} images identiques, "
              f"{len(result['different'])} différentes, {len(result['missing'])} manquantes")
    print("REVUE prête :", ", ".join(sorted(p.name for p in dest.iterdir())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
