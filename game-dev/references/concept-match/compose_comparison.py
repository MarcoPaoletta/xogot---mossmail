"""Compose a concept vs screenshot side by side for the concept match protocol.

Usage:
    python compose_comparison.py <concept.png> <screenshot.png> <out.png>

Concept on the left, screenshot on the right, both scaled to the same height,
a white gutter between them, and each file name burned in the corner.
Refuses to overwrite an existing output so the round history survives.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

GUTTER = 12
LABEL_PAD = 8


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__)
        return 2
    concept_path, shot_path, out_path = (Path(a) for a in argv[1:])
    if out_path.exists():
        print(f"refusing to overwrite {out_path}: pick the next number")
        return 1

    concept = Image.open(concept_path).convert("RGB")
    shot = Image.open(shot_path).convert("RGB")
    height = min(concept.height, shot.height)
    concept = concept.resize((round(concept.width * height / concept.height), height), Image.LANCZOS)
    shot = shot.resize((round(shot.width * height / shot.height), height), Image.LANCZOS)

    canvas = Image.new("RGB", (concept.width + GUTTER + shot.width, height), "white")
    canvas.paste(concept, (0, 0))
    canvas.paste(shot, (concept.width + GUTTER, 0))

    draw = ImageDraw.Draw(canvas)
    for label, x in ((concept_path.name, 0), (shot_path.name, concept.width + GUTTER)):
        box = draw.textbbox((0, 0), label)
        w, h = box[2] - box[0], box[3] - box[1]
        draw.rectangle((x + LABEL_PAD, height - h - 3 * LABEL_PAD, x + w + 3 * LABEL_PAD, height - LABEL_PAD), fill="black")
        draw.text((x + 2 * LABEL_PAD, height - h - 2 * LABEL_PAD), label, fill="white")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    print(f"wrote {out_path} ({canvas.width}x{canvas.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
