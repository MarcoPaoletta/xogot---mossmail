"""Measure where passengers stand on each island's dock (feedback round 3).

The forest island's spot was approved by eye. Every island painting has the
same dock drawn at a slightly different place, so this finds the forest dock
(lantern post and deck around the approved feet) inside each island's art by
template matching and prints the matching feet point, in art pixels from the
art's centre, for IslandData.stand_point. It also prints Lilyport's
stand_offset for the LilyportDock node. Check the result with the red-cross
sheet it writes to tmp/dock_anchors.png before applying it.

    python tools/measure_dock_anchors.py
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets" / "images"
# Approved forest feet: dock_offset (415, 80) plus stand offset (-145, -12)
# at visual scale 0.85, in art pixels from the centre.
FOREST_FEET = np.array([415.0, 80.0]) + np.array([-145.0, -12.0]) / 0.85
LILYPORT_BASE = (np.array([620.0, 2060.0]), 0.85)
LILYPORT_DOCK = np.array([1090.0, 2060.0])


def gray(name: str) -> tuple[np.ndarray, np.ndarray]:
    rgba = np.array(Image.open(IMAGES / f"{name}.png").convert("RGBA")).astype(np.float32)
    rgb = (rgba[..., :3] * rgba[..., 3:4] / 255.0).astype(np.uint8)
    return cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY), np.array([rgba.shape[1], rgba.shape[0]]) / 2.0


def main() -> None:
    forest, centre = gray("island_forest")
    feet = centre + FOREST_FEET
    x0, y0 = int(feet[0] - 90), int(feet[1] - 150)
    template = forest[y0:int(feet[1] + 60), x0:min(forest.shape[1], int(feet[0] + 80))]
    crops = []
    for name in ["island_forest", "island_cherry", "island_pine", "island_autumn", "island_sand", "island_meadow", "lilyport_island_base"]:
        image, middle = gray(name)
        scores = cv2.matchTemplate(image, template, cv2.TM_CCOEFF_NORMED)
        _, best, _, location = cv2.minMaxLoc(scores)
        point = np.array(location) + feet - np.array([x0, y0])
        relative = point - middle
        if name.startswith("lilyport"):
            world = LILYPORT_BASE[0] + relative * LILYPORT_BASE[1]
            print(f"{name}: match {best:.2f}  LilyportDock.stand_offset = {np.round(world - LILYPORT_DOCK, 1)}")
        else:
            print(f"{name}: match {best:.2f}  stand_point = {np.round(relative, 1)}")
        art = Image.open(IMAGES / f"{name}.png").convert("RGBA")
        backdrop = Image.new("RGBA", art.size, (30, 110, 200, 255))
        backdrop.alpha_composite(art)
        crop = backdrop.crop((int(point[0] - 110), int(point[1] - 170), int(point[0] + 110), int(point[1] + 70)))
        draw = ImageDraw.Draw(crop)
        draw.line((96, 170, 124, 170), fill=(255, 0, 0), width=3)
        draw.line((110, 156, 110, 184), fill=(255, 0, 0), width=3)
        crops.append(crop)
    sheet = Image.new("RGBA", (220 * len(crops), 240))
    for index, crop in enumerate(crops):
        sheet.paste(crop, (index * 220, 0))
    (ROOT / "tmp").mkdir(exist_ok=True)
    sheet.save(ROOT / "tmp" / "dock_anchors.png")


if __name__ == "__main__":
    main()
