#!/usr/bin/env python3
"""Generate ChatMate's original sticker packs and offline animated GIFs.

Everything here is authored from simple shapes and text, so the binary assets
are safe to ship and are not copied from WhatsApp, Giphy or any sticker pack.
Run from the repository root:

    python3 tools/generate_media_assets.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STICKER_DIR = ROOT / "assets" / "stickers"
GIF_DIR = ROOT / "assets" / "gifs"
STICKER_SIZE = 256


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
        else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def blob_points(cx: float, cy: float, radius: float, seed: int) -> list[tuple[float, float]]:
    rng = random.Random(seed)
    points = []
    for i in range(28):
        angle = (math.tau / 28) * i
        wobble = 1 + rng.uniform(-0.055, 0.055)
        points.append((cx + math.cos(angle) * radius * wobble,
                       cy + math.sin(angle) * radius * wobble))
    return points


def draw_blob(draw: ImageDraw.ImageDraw, color: str, seed: int, inset: int = 18) -> None:
    draw.polygon(blob_points(128, 126, 104, seed), fill=color)
    draw.ellipse((inset + 35, inset + 22, inset + 70, inset + 52), fill="#ffffff35")


def draw_face(draw: ImageDraw.ImageDraw, kind: str) -> None:
    ink = "#17231c"
    if kind == "happy":
        draw.ellipse((76, 96, 97, 120), fill=ink)
        draw.ellipse((159, 96, 180, 120), fill=ink)
        draw.arc((87, 105, 169, 178), 20, 160, fill=ink, width=9)
    elif kind == "laugh":
        draw.arc((72, 84, 112, 122), 190, 350, fill=ink, width=7)
        draw.arc((144, 84, 184, 122), 190, 350, fill=ink, width=7)
        draw.ellipse((91, 124, 165, 183), fill=ink)
        draw.ellipse((102, 145, 154, 173), fill="#e86f7a")
    elif kind == "sad":
        draw.arc((70, 92, 104, 126), 200, 340, fill=ink, width=7)
        draw.arc((152, 92, 186, 126), 200, 340, fill=ink, width=7)
        draw.arc((92, 153, 164, 189), 200, 340, fill=ink, width=8)
    elif kind == "angry":
        draw.line((70, 90, 108, 78), fill=ink, width=8)
        draw.line((148, 78, 186, 90), fill=ink, width=8)
        draw.ellipse((86, 103, 107, 123), fill=ink)
        draw.ellipse((149, 103, 170, 123), fill=ink)
        draw.arc((93, 154, 163, 184), 20, 160, fill=ink, width=8)
    elif kind == "love":
        for x, y, size in ((76, 85, 18), (145, 85, 18)):
            draw.ellipse((x, y, x + size, y + size), fill="#ff4f70")
            draw.ellipse((x + size, y, x + size * 2, y + size), fill="#ff4f70")
            draw.polygon([(x, y + size * .7), (x + size * 2, y + size * .7),
                          (x + size, y + size * 2.1)], fill="#ff4f70")
        draw.arc((92, 137, 164, 186), 20, 160, fill=ink, width=8)
    elif kind == "sleepy":
        draw.arc((72, 100, 108, 132), 190, 350, fill=ink, width=7)
        draw.arc((148, 100, 184, 132), 190, 350, fill=ink, width=7)
        draw.ellipse((105, 151, 151, 169), outline=ink, width=6)
        for x, y in ((39, 62), (194, 48), (205, 94)):
            draw.text((x, y), "z", font=font(22), fill=ink)
    elif kind == "wow":
        draw.ellipse((74, 88, 105, 126), fill=ink)
        draw.ellipse((151, 88, 182, 126), fill=ink)
        draw.ellipse((101, 139, 155, 193), fill=ink)
    elif kind == "cool":
        draw.rounded_rectangle((65, 96, 113, 126), radius=10, fill=ink)
        draw.rounded_rectangle((143, 96, 191, 126), radius=10, fill=ink)
        draw.line((113, 106, 143, 106), fill=ink, width=7)
        draw.arc((91, 143, 165, 178), 20, 160, fill=ink, width=8)
    elif kind == "nervous":
        draw.ellipse((78, 102, 96, 120), fill=ink)
        draw.ellipse((160, 102, 178, 120), fill=ink)
        draw.line((96, 162, 160, 162), fill=ink, width=7)
        for y in (72, 88, 104):
            draw.line((186, y, 204, y - 7), fill="#5d84ff", width=5)
    elif kind == "yes":
        draw.line((69, 135, 111, 171), fill=ink, width=15)
        draw.line((103, 174, 191, 84), fill=ink, width=15)
    elif kind == "no":
        draw.line((76, 80, 180, 174), fill=ink, width=16)
        draw.line((180, 80, 76, 174), fill=ink, width=16)


def sticker(name: str, color: str, face: str | None = None, caption: str | None = None,
            seed: int = 0) -> None:
    image = Image.new("RGBA", (STICKER_SIZE, STICKER_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon(blob_points(130, 132, 104, seed + 1), fill="#00000022")
    draw_blob(draw, color, seed)
    if face:
        draw_face(draw, face)
    if caption:
        label_font = font(35)
        box = draw.textbbox((0, 0), caption, font=label_font)
        width = box[2] - box[0]
        draw.rounded_rectangle((20, 185, 236, 243), radius=26, fill="#ffffffdd")
        draw.text((128 - width / 2, 197), caption, font=label_font, fill="#17231c")
    image.save(STICKER_DIR / f"{name}.png", optimize=True)


def make_gif(name: str, word: str, background: str, ink: str, accent: str, seed: int) -> None:
    width, height, frames = 300, 220, 14
    base = Image.new("RGB", (width, height), background)
    draw = ImageDraw.Draw(base)
    rng = random.Random(seed)
    dots = [(rng.randint(0, width), rng.randint(0, height), rng.randint(4, 15)) for _ in range(18)]
    for dot in dots:
        draw.ellipse((dot[0], dot[1], dot[0] + dot[2], dot[1] + dot[2]),
                     fill=accent + "55")
    image_frames = []
    for frame in range(frames):
        image = base.copy()
        draw = ImageDraw.Draw(image)
        label_font = font(68)
        box = draw.textbbox((0, 0), word, font=label_font)
        tw, th = box[2] - box[0], box[3] - box[1]
        offset = int(8 + 3 * math.sin((math.tau / frames) * frame))
        draw.rounded_rectangle(
            (24 + offset, 57 + offset, width - 24 + offset, height - 45 + offset),
            radius=28, fill=accent + "88")
        draw.text(((width - tw) / 2, (height - th) / 2 - 18), word,
                  font=label_font, fill=ink)
        for index, dot in enumerate(dots):
            phase = (frame / frames + index / len(dots)) % 1
            y = dot[1] - int(phase * 24)
            draw.ellipse((dot[0], y, dot[0] + dot[2], y + dot[2]), fill=accent + "aa")
        image_frames.append(image.convert("P", palette=Image.Palette.ADAPTIVE))
    image_frames[0].save(
        GIF_DIR / f"{name}.gif",
        save_all=True,
        append_images=image_frames[1:],
        duration=90,
        loop=0,
        optimize=False,
    )


def main() -> None:
    STICKER_DIR.mkdir(parents=True, exist_ok=True)
    GIF_DIR.mkdir(parents=True, exist_ok=True)

    packs = {
        "blobs": [
            ("happy", "#a8e6b8", "happy", None),
            ("laugh", "#ffd98e", "laugh", None),
            ("sad", "#a9c9ff", "sad", None),
            ("angry", "#ff9d9d", "angry", None),
            ("love", "#ffb7d5", "love", None),
            ("sleepy", "#c9b8ff", "sleepy", None),
            ("cool", "#9adfd4", "cool", None),
            ("nervous", "#d7e3a8", "nervous", None),
        ],
        "moods": [
            ("yes", "#b9edc5", "yes", "YES"),
            ("no", "#ffc2bd", "no", "NOPE"),
            ("wow", "#ffe49a", "wow", "WOW"),
            ("maybe", "#c7d8ff", None, "MAYBE"),
            ("brb", "#e2c8ff", None, "BRB"),
            ("oops", "#ffd0b8", None, "OOPS"),
            ("thanks", "#b8eadf", None, "THANKS"),
            ("same", "#d8e9a8", None, "SAME"),
        ],
        "latenight": [
            ("tired", "#a8bde6", "sleepy", "TIRED"),
            ("awake", "#ffe29a", "happy", "AWAKE"),
            ("overthinking", "#c3b1ff", "nervous", "THINKING"),
            ("coffee", "#c9a88a", None, "SEND COFFEE"),
            ("no_thoughts", "#b7c9d9", None, "NO THOUGHTS"),
            ("almost", "#f7c59f", None, "ALMOST"),
            ("help", "#ffb8b8", "nervous", "HELP"),
            ("goodnight", "#9da8dd", "sleepy", "GOODNIGHT"),
        ],
    }

    for pack_index, (pack, stickers) in enumerate(packs.items()):
        for index, (slug, color, face, caption) in enumerate(stickers):
            sticker(f"{pack}_{slug}", color, face, caption,
                    seed=pack_index * 50 + index * 7)

    gifs = [
        ("yes", "YES", "#0e3b24", "#d6ffe2", "#1db954", 1),
        ("nope", "NOPE", "#3a1114", "#ffe2e2", "#ff6b6b", 2),
        ("lol", "LOL", "#3b2b06", "#fff5c9", "#ffd93d", 3),
        ("wow", "WOW!", "#082f3a", "#d9fbff", "#42d6e8", 4),
        ("love", "LOVE", "#3b0a1f", "#ffe1ec", "#ff5d8f", 5),
        ("hey", "HEY", "#1c1542", "#e8e3ff", "#9b8cff", 6),
    ]
    for item in gifs:
        make_gif(*item)

    print(f"stickers: {len(list(STICKER_DIR.glob('*.png')))}")
    print(f"gifs: {len(list(GIF_DIR.glob('*.gif')))}")


if __name__ == "__main__":
    main()
