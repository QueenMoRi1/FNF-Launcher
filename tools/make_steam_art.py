#!/usr/bin/env python3
"""Builds Steam library artwork for the FNF Launcher shortcut.

Usage: make_steam_art.py <fnf_images_dir> <orange image> <out_dir> <appid>

<fnf_images_dir> is FunkinCrew's preload/images folder (menuBG*.png,
logoBumpin.*, gfDanceTitle.*, alphabet.*). Writes Steam's custom-art files:
  <appid>p.png       portrait capsule   600x900
  <appid>.png        wide capsule       920x430
  <appid>_hero.png   library hero       1920x620
  <appid>_logo.png   transparent logo   (drawn over the hero)
"""
import os
import re
import sys

from PIL import Image, ImageFilter, ImageOps


def sparrow_frame(images, name, prefix):
    """First frame of a Sparrow atlas animation, with its trim offsets restored."""
    sheet = Image.open(os.path.join(images, name + ".png")).convert("RGBA")
    xml = open(os.path.join(images, name + ".xml"), encoding="utf-8-sig").read()
    tag = re.search(r'<SubTexture name="%s0000"([^/]*)' % re.escape(prefix), xml).group(1)
    attr = {k: int(v) for k, v in re.findall(r'(\w+)="(-?\d+)"', tag)}
    frame = sheet.crop((attr["x"], attr["y"], attr["x"] + attr["width"], attr["y"] + attr["height"]))
    full = Image.new("RGBA", (attr.get("frameWidth", attr["width"]), attr.get("frameHeight", attr["height"])))
    full.paste(frame, (-attr.get("frameX", 0), -attr.get("frameY", 0)))
    return full


def alphabet(images, text, height):
    """Text in FNF's bold Alphabet font (letters and spaces only)."""
    sheet = Image.open(os.path.join(images, "alphabet.png")).convert("RGBA")
    xml = open(os.path.join(images, "alphabet.xml"), encoding="utf-8-sig").read()
    glyphs = {}
    for m in re.finditer(r'<SubTexture name="(.) bold0000" x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"', xml):
        c, x, y, w, h = m.group(1), *map(int, m.groups()[1:])
        glyphs[c] = sheet.crop((x, y, x + w, y + h))
    scale = height / 70.0
    parts = []
    for c in text.upper():
        if c in glyphs:
            g = glyphs[c]
            parts.append(g.resize((round(g.width * scale), round(g.height * scale)), Image.LANCZOS))
        else:
            parts.append(Image.new("RGBA", (round(36 * scale), 1)))
    gap = round(3 * scale)
    out = Image.new("RGBA", (sum(p.width for p in parts) + gap * len(parts), max(p.height for p in parts)))
    x = 0
    for p in parts:
        out.paste(p, (x, out.height - p.height), p)  # bottom-aligned, like in-game
        x += p.width + gap
    return out


def fit_height(img, height):
    return img.resize((round(img.width * height / img.height), height), Image.LANCZOS)


def fit_width(img, width):
    return img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)


def cover(img, size):
    return ImageOps.fit(img.convert("RGBA"), size, Image.LANCZOS)


def shadowed(canvas, img, pos, blur=10, offset=(8, 10), alpha=150):
    """Pastes img with a soft drop shadow."""
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.putalpha(img.getchannel("A").point(lambda a: a * alpha // 255))
    pad = blur * 3
    big = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2))
    big.paste(shadow, (pad, pad))
    big = big.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(big, (pos[0] - pad + offset[0], pos[1] - pad + offset[1]))
    canvas.alpha_composite(img, pos)


def vignette(size, strength=170):
    """Dark edges, transparent middle."""
    w, h = size
    mask = Image.new("L", (w, h), 0)
    inner = Image.new("L", (int(w * 0.75), int(h * 0.75)), 255)
    mask.paste(inner, ((w - inner.width) // 2, (h - inner.height) // 2))
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) // 5))
    layer = Image.new("RGBA", size, (0, 0, 0, strength))
    layer.putalpha(ImageOps.invert(mask).point(lambda a: a * strength // 255))
    return layer


def tinted(img, color):
    gray = ImageOps.grayscale(img.convert("RGB"))
    return ImageOps.colorize(gray, black=(0, 0, 0), white=color).convert("RGBA")


def main():
    images, orange_path, out, appid = sys.argv[1:5]
    os.makedirs(out, exist_ok=True)
    logo = sparrow_frame(images, "logoBumpin", "logo bumpin").crop((0, 0, 939, 703))
    logo = logo.crop(logo.getbbox())
    gf = sparrow_frame(images, "gfDanceTitle", "gfDance")
    gf = gf.crop(gf.getbbox())
    word = alphabet(images, "LAUNCHER", 70)
    orange = Image.open(orange_path).convert("RGBA")
    magenta = Image.open(os.path.join(images, "menuBGMagenta.png"))
    yellow = Image.open(os.path.join(images, "menuBG.png"))
    desat = Image.open(os.path.join(images, "menuDesat.png"))

    # Logo lockup: FNF logo with LAUNCHER under it (also Steam's transparent logo).
    lock_logo = fit_width(logo, 900)
    lock_word = fit_width(word, 620)
    lockup = Image.new("RGBA", (lock_logo.width, lock_logo.height + lock_word.height - 40))
    lockup.alpha_composite(lock_logo, (0, 0))
    shadowed(lockup, lock_word, ((lockup.width - lock_word.width) // 2, lock_logo.height - 60), blur=6, offset=(5, 6))
    lockup = lockup.crop(lockup.getbbox())
    lockup.save(os.path.join(out, f"{appid}_logo.png"))

    # Portrait capsule 600x900: magenta menu art, GF dancing, logo on top.
    p = cover(magenta, (600, 900))
    g = fit_height(gf, 640)
    shadowed(p, g, ((600 - g.width) // 2 + 30, 900 - g.height + 40), blur=14)
    p.alpha_composite(vignette(p.size, 150))
    l = fit_width(lockup, 560)
    shadowed(p, l, ((600 - l.width) // 2, 24), blur=10)
    o = fit_width(orange, 170).rotate(-12, resample=Image.BICUBIC, expand=True)
    shadowed(p, o, (16, 900 - o.height - 16), blur=8)
    p.convert("RGB").save(os.path.join(out, f"{appid}p.png"))

    # Wide capsule 920x430: classic yellow menu, logo left, GF right.
    w = cover(yellow, (920, 430))
    g = fit_height(gf, 470)
    shadowed(w, g, (920 - g.width + 40, 430 - g.height + 60), blur=12)
    w.alpha_composite(vignette(w.size, 120))
    l = fit_height(lockup, 360)
    shadowed(w, l, (28, (430 - l.height) // 2), blur=10)
    w.convert("RGB").save(os.path.join(out, f"{appid}.png"))

    # Hero 1920x620: purple-tinted menu art, GF on the right; Steam draws the logo.
    h = cover(tinted(desat, (146, 113, 253)), (1920, 620))
    shade = Image.new("RGBA", (1920, 620))
    for x in range(1920):  # darken the left side where Steam puts the logo
        a = int(150 * max(0.0, 1.0 - x / 1100))
        shade.paste((0, 0, 0, a), (x, 0, x + 1, 620))
    h.alpha_composite(shade)
    g = fit_height(gf, 640)
    shadowed(h, g, (1920 - g.width - 120, 620 - g.height + 60), blur=16)
    o = fit_width(orange, 210).rotate(10, resample=Image.BICUBIC, expand=True)
    shadowed(h, o, (1920 - g.width - 300, 60), blur=10)
    h.alpha_composite(vignette(h.size, 110))
    h.convert("RGB").save(os.path.join(out, f"{appid}_hero.png"))
    print("wrote", ", ".join(f for f in os.listdir(out) if f.startswith(appid)))


if __name__ == "__main__":
    main()
