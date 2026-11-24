"""Generates the addon's textures (needs numpy + Pillow)."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "DeathWish", "Media")
rng = np.random.default_rng(7)
W, H = 1024, 512
def noise(scale):
    s = rng.random((max(2, H // scale), max(2, W // scale))) * 255
    return np.asarray(Image.fromarray(s.astype("uint8")).resize((W, H), Image.BICUBIC)) / 255 - .5
img = Image.new("RGBA", (W, H))
sh = Image.new("RGBA", (W, H)); ImageDraw.Draw(sh).rounded_rectangle((14, 18, W-14, H-8), 18, fill=(0, 0, 0, 190))
img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
d = ImageDraw.Draw(img)
d.rounded_rectangle((14, 12, W-14, H-16), 16, fill=(48, 18, 12, 255))          # leather
d.rounded_rectangle((19, 17, W-19, H-21), 13, outline=(120, 84, 34, 255), width=2)
for x0, x1, y0, y1 in ((14, 60, 12, 58), (W-60, W-14, 12, 58), (14, 60, H-62, H-16), (W-60, W-14, H-62, H-16)):
    d.rounded_rectangle((x0, y0, x1, y1), 14, fill=(134, 96, 40, 255), outline=(70, 46, 16, 255), width=2)
for k in range(6):                                                             # page stack
    c = 150 + k * 12
    d.rectangle((32+k, 30+k//2, W-33-k, H-30-k), fill=(c, int(c*.86), int(c*.64), 255))
x, y = np.meshgrid(np.arange(W), np.arange(H))
base = np.array([226, 203, 158.])
n = noise(64)*26 + noise(16)*14 + noise(4)*8 + rng.normal(0, 2.5, (H, W))
px0, px1, py0, py1 = 40, W-41, 34, H-38
edge = np.minimum.reduce([x-px0, px1-x, y-py0, py1-y]).clip(0)
dark = 42*np.exp(-edge/22) + 95*np.exp(-np.abs(x-W/2)/20) + 22*np.exp(-np.abs(x-W/2)/75)
page = base + n[..., None]*np.array([1, 1, .9]) - dark[..., None]*np.array([.8, 1, 1.15])
mask = Image.new("L", (W, H)); ImageDraw.Draw(mask).rounded_rectangle((px0, py0, px1, py1), 5, fill=255)
img.paste(Image.fromarray(page.clip(0, 255).astype("uint8")).convert("RGBA"), (0, 0), mask)
img.save(os.path.join(out, "Book.tga"))
g = 64
yy, xx = np.mgrid[:g, :g]; r = np.hypot(xx-g/2+.5, yy-g/2+.5)/(g/2)
a = ((1-r).clip(0)**1.6*255).astype("uint8")
Image.fromarray(np.dstack([np.full((g, g, 3), 255, "uint8"), a])).save(os.path.join(out, "Glow.tga"))
