#!/usr/bin/env python3
"""Generate the EuroMillions mod textures (item icons + workshop poster).

Project Zomboid item icons are small PNGs referenced from item scripts via
`Icon = EM_Foo`, which resolves to a texture file named `Item_EM_Foo.png`.
Icons render best at 32x32; we author at 64x64 for crispness.

The art is original and brand-evocative (EuroMillions' navy/gold star look)
rather than a copy of any official asset.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "mods", "EuroMillions", "media", "textures")
OUT = os.path.normpath(OUT)
POSTER = os.path.normpath(os.path.join(OUT, "..", "..", "poster.png"))

# Brand palette
NAVY = (20, 28, 80)
NAVY_DK = (12, 16, 52)
BLUE = (28, 60, 168)
GOLD = (255, 198, 41)
GOLD_DK = (214, 158, 18)
WHITE = (245, 247, 255)
RED = (206, 41, 56)
GREEN = (32, 156, 92)
PURPLE = (78, 36, 132)
SILVER = (190, 196, 214)


def _font(size, bold=True):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    for c in candidates:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


def star_points(cx, cy, outer, inner, rot=-math.pi / 2, n=5):
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = rot + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_star(d, cx, cy, outer, fill=GOLD, outline=GOLD_DK, inner_ratio=0.42, width=1):
    d.polygon(star_points(cx, cy, outer, outer * inner_ratio), fill=fill, outline=outline)


def rounded_card(size, top, bottom, radius=10):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # vertical gradient
    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        t = y / max(1, size - 1)
        col = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        gd.line([(0, y), (size, y)], fill=col)
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([2, 2, size - 3, size - 3], radius=radius, fill=255)
    img.paste(grad, (0, 0), mask)
    return img, ImageDraw.Draw(img)


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote", os.path.relpath(path))


def icon_blank_ticket():
    S = 64
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # paper play slip
    d.rounded_rectangle([10, 6, 54, 58], radius=4, fill=WHITE, outline=NAVY, width=2)
    # blue header band
    d.rectangle([12, 8, 52, 20], fill=NAVY)
    draw_star(d, 18, 14, 5)
    d.text((25, 9), "EM", font=_font(10), fill=GOLD)
    # number grid (the play area)
    for r in range(4):
        for c in range(5):
            x = 15 + c * 7
            y = 26 + r * 7
            d.rectangle([x, y, x + 4, y + 4], outline=BLUE, width=1)
    return img


def icon_filled_ticket():
    S = 64
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([10, 6, 54, 58], radius=4, fill=WHITE, outline=NAVY, width=2)
    d.rectangle([12, 8, 52, 20], fill=NAVY)
    draw_star(d, 18, 14, 5)
    d.text((25, 9), "EM", font=_font(10), fill=GOLD)
    marks = {(0, 1), (0, 3), (1, 0), (2, 2), (3, 4)}
    for r in range(4):
        for c in range(5):
            x = 15 + c * 7
            y = 26 + r * 7
            if (r, c) in marks:
                d.ellipse([x, y, x + 4, y + 4], fill=NAVY)
            else:
                d.rectangle([x, y, x + 4, y + 4], outline=BLUE, width=1)
    return img


def icon_scratch(name, label, accent, with_stars=False):
    img, d = rounded_card(64, accent, tuple(int(c * 0.6) for c in accent), radius=9)
    # foil panel
    d.rounded_rectangle([10, 24, 54, 50], radius=4, fill=SILVER, outline=(120, 126, 140), width=1)
    # diagonal foil sheen
    for i in range(-20, 64, 6):
        d.line([(i, 24), (i + 16, 50)], fill=(220, 224, 236), width=1)
    draw_star(d, 14, 13, 6)
    f = _font(8)
    d.text((23, 9), label, font=f, fill=GOLD)
    if with_stars:
        for sx in (20, 32, 44):
            draw_star(d, sx, 37, 4, fill=GOLD, outline=GOLD_DK)
    else:
        d.text((20, 31), "WIN", font=_font(11), fill=NAVY)
    return img


def icon_scratch_used():
    img, d = rounded_card(64, (120, 126, 140), (78, 82, 96), radius=9)
    d.rounded_rectangle([10, 24, 54, 50], radius=4, fill=(70, 72, 84))
    # scratched-off scribbles
    for i in range(-20, 64, 5):
        d.line([(i, 24), (i + 14, 50)], fill=(50, 52, 60), width=2)
    draw_star(d, 14, 13, 6, fill=(150, 150, 150), outline=(110, 110, 110))
    return img


def icon_voucher():
    img, d = rounded_card(64, GOLD, GOLD_DK, radius=9)
    d.rounded_rectangle([7, 16, 57, 48], radius=5, fill=NAVY, outline=GOLD, width=2)
    draw_star(d, 32, 30, 11)
    d.text((20, 50), "WINNER", font=_font(9), fill=NAVY)
    return img


def icon_flyer():
    S = 64
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([12, 5, 52, 59], radius=3, fill=WHITE, outline=NAVY, width=2)
    d.rectangle([12, 5, 52, 28], fill=NAVY)
    draw_star(d, 32, 16, 9)
    d.text((19, 30), "Could", font=_font(9), fill=NAVY)
    d.text((22, 40), "it be", font=_font(9), fill=NAVY)
    d.text((26, 50), "YOU?", font=_font(9), fill=RED)
    return img


def make_poster():
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # gradient bg
    for y in range(H):
        t = y / (H - 1)
        col = tuple(int(NAVY_DK[i] * (1 - t) + PURPLE[i] * t) for i in range(3)) + (255,)
        ImageDraw.Draw(img).line([(0, y), (W, y)], fill=col)
    d = ImageDraw.Draw(img)
    # scattered faint stars
    import random
    random.seed(7)
    for _ in range(40):
        x, y = random.randint(0, W), random.randint(0, H)
        draw_star(d, x, y, random.randint(2, 5), fill=(255, 210, 90, 60), outline=None)
    # big central star
    draw_star(d, 128, 104, 56, fill=GOLD, outline=GOLD_DK, width=3)
    draw_star(d, 128, 104, 30, fill=NAVY, outline=NAVY)
    d.text((112, 90), "EM", font=_font(34), fill=GOLD)
    # wordmark
    f = _font(30)
    txt = "EuroMillions"
    w = d.textlength(txt, font=f)
    d.text(((W - w) / 2, 168), txt, font=f, fill=WHITE)
    f2 = _font(15, bold=False)
    sub = "Could it be you?"
    w2 = d.textlength(sub, font=f2)
    d.text(((W - w2) / 2, 204), sub, font=f2, fill=GOLD)
    d.text((6, 232), "Project Zomboid Lottery Mod", font=_font(12, bold=False), fill=SILVER)
    img.save(POSTER)
    print("wrote", os.path.relpath(POSTER))


def main():
    os.makedirs(OUT, exist_ok=True)
    save(icon_blank_ticket(), "Item_EM_TicketBlank.png")
    save(icon_filled_ticket(), "Item_EM_TicketFilled.png")
    save(icon_scratch("m", "MILLIONAIRE", PURPLE), "Item_EM_ScratchMillionaire.png")
    save(icon_scratch("s", "LUCKY STARS", BLUE, with_stars=True), "Item_EM_ScratchLuckyStars.png")
    save(icon_scratch("g", "GOLD RUSH", GOLD_DK), "Item_EM_ScratchGoldRush.png")
    save(icon_scratch("7", "TRIPLE 7", RED), "Item_EM_Scratch777.png")
    save(icon_scratch_used(), "Item_EM_ScratchUsed.png")
    save(icon_voucher(), "Item_EM_Voucher.png")
    save(icon_flyer(), "Item_EM_Flyer.png")
    make_poster()


if __name__ == "__main__":
    main()
