"""Generates the addon's textures (needs numpy + Pillow)."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "DeathNotebook", "Media")
rng = np.random.default_rng(7)
BONE = (205, 200, 188, 255)


def noise(w, h, scale):
    s = rng.random((max(2, h // scale), max(2, w // scale))) * 255
    return np.asarray(Image.fromarray(s.astype("uint8")).resize((w, h), Image.BICUBIC)) / 255 - .5


def textured(w, h, base, amount):
    """Grainy dark surface, used for leather and paper."""
    n = noise(w, h, 64) * amount + noise(w, h, 14) * amount * .6 + noise(w, h, 4) * amount * .5
    n += rng.normal(0, amount * .12, (h, w))
    return np.array(base, float) + n[..., None]


def to_image(a):
    return Image.fromarray(a.clip(0, 255).astype("uint8")).convert("RGBA")


def emblem(size, color):
    """Our own mark: a narrow skull whose jaw runs out into a pen nib."""
    k = 4
    s = size * k
    m = Image.new("L", (s, s))
    d = ImageDraw.Draw(m)
    p = lambda *pts: [(x * s, y * s) for x, y in pts]
    d.ellipse((.22 * s, .04 * s, .78 * s, .56 * s), fill=255)
    d.polygon(p((.30, .46), (.70, .46), (.64, .68), (.50, .98), (.36, .68)), fill=255)
    d.polygon(p((.29, .30), (.46, .36), (.43, .46), (.32, .44)), fill=0)
    d.polygon(p((.71, .30), (.54, .36), (.57, .46), (.68, .44)), fill=0)
    d.polygon(p((.50, .45), (.465, .54), (.535, .54)), fill=0)
    d.ellipse((.465 * s, .63 * s, .535 * s, .70 * s), fill=0)
    d.rectangle((.492 * s, .68 * s, .508 * s, .94 * s), fill=0)
    m = m.resize((size, size), Image.LANCZOS)
    e = Image.new("RGBA", (size, size), color)
    e.putalpha(m)
    return e


def cover(w, h):
    """Closed black book, front view."""
    img = Image.new("RGBA", (w, h))
    leather = textured(w, h, (25, 24, 27), 14)
    x = np.arange(w)
    leather += (14 * np.exp(-np.abs(x - w * .11) / (w * .012)))[None, :, None]   # hinge
    leather -= (16 * np.exp(-np.abs(x - w * .135) / (w * .012)))[None, :, None]
    mask = Image.new("L", (w, h))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), w // 22, fill=255)
    img.paste(to_image(leather), (0, 0), mask)
    ImageDraw.Draw(img).rounded_rectangle((1, 1, w - 2, h - 2), w // 22, outline=(74, 72, 76, 255), width=max(1, w // 130))
    return img


def make_book():
    W, H = 1024, 512
    img = Image.new("RGBA", (W, H))
    sh = Image.new("RGBA", (W, H))
    ImageDraw.Draw(sh).rounded_rectangle((14, 18, W - 14, H - 8), 18, fill=(0, 0, 0, 210))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    mask = Image.new("L", (W, H))
    ImageDraw.Draw(mask).rounded_rectangle((14, 12, W - 14, H - 16), 16, fill=255)
    img.paste(to_image(textured(W, H, (19, 18, 21), 12)), (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((14, 12, W - 14, H - 16), 16, outline=(66, 64, 68, 255), width=2)
    d.rounded_rectangle((20, 18, W - 20, H - 22), 12, outline=(44, 42, 46, 255), width=1)
    for k in range(6):                                          # page stack
        c = 88 + k * 9
        d.rectangle((32 + k, 30 + k // 2, W - 33 - k, H - 30 - k), fill=(c, c - 2, c - 6, 255))
    x, y = np.meshgrid(np.arange(W), np.arange(H))
    px0, px1, py0, py1 = 40, W - 41, 34, H - 38
    edge = np.minimum.reduce([x - px0, px1 - x, y - py0, py1 - y]).clip(0)
    dark = 14 * np.exp(-edge / 26) + 30 * np.exp(-np.abs(x - W / 2) / 18) + 10 * np.exp(-np.abs(x - W / 2) / 75)
    page = textured(W, H, (42, 41, 42), 11) - dark[..., None]
    mask = Image.new("L", (W, H))
    ImageDraw.Draw(mask).rounded_rectangle((px0, py0, px1, py1), 5, fill=255)
    img.paste(to_image(page), (0, 0), mask)
    img.save(os.path.join(out, "Book.tga"))


def make_icon():
    img = Image.new("RGBA", (256, 256))
    img.alpha_composite(cover(184, 232), (36, 12))
    ImageDraw.Draw(img).rectangle((214, 24, 219, 232), fill=(150, 146, 138, 255))
    img.alpha_composite(emblem(132, BONE), (72, 62))
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(out, "Icon.tga"))


def make_glow():
    g = 64
    yy, xx = np.mgrid[:g, :g]
    r = np.hypot(xx - g / 2 + .5, yy - g / 2 + .5) / (g / 2)
    a = ((1 - r).clip(0) ** 1.6 * 255).astype("uint8")
    Image.fromarray(np.dstack([np.full((g, g, 3), 255, "uint8"), a])).save(os.path.join(out, "Glow.tga"))


if __name__ == "__main__":
    make_book()
    make_icon()
    make_glow()
