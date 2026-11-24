"""Generates the CurseForge logo: the closed black book (needs numpy + Pillow)."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from make_art import BONE, cover, emblem
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FONT = "/usr/share/fonts/liberation/LiberationSerif-Bold.ttf"
S = 800
img = Image.new("RGBA", (S, S), (58, 10, 12, 255))
light = Image.new("RGBA", (S, S))
ImageDraw.Draw(light).ellipse((120, 80, 680, 720), fill=(150, 24, 22, 150))
img.alpha_composite(light.filter(ImageFilter.GaussianBlur(90)))
sh = Image.new("RGBA", (S, S))
ImageDraw.Draw(sh).rounded_rectangle((150, 70, 690, 770), 24, fill=(0, 0, 0, 230))
img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)))
d = ImageDraw.Draw(img)
for k in range(8):                                              # page edges
    c = 120 + (k % 2) * 40
    d.rectangle((160, 66, 672 - k * 2, 752 - k * 2), fill=(c, c - 4, c - 12, 255))
img.alpha_composite(cover(520, 690), (140, 50))
img.alpha_composite(emblem(300, BONE), (275, 300))
font = ImageFont.truetype(FONT, 62)
for text, y in (("DEATH", 130), ("NOTEBOOK", 205)):
    d.text((425, y), text, font=font, fill=BONE, anchor="ma")
d.line((290, 640, 560, 640), fill=(170, 26, 24, 255), width=5)
img.convert("RGB").resize((400, 400), Image.LANCZOS).save(os.path.join(root, "logo.png"))
