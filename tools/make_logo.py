"""Generates the CurseForge logo from the addon's own textures (needs Pillow)."""
import os
from PIL import Image, ImageDraw, ImageFilter
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
book = Image.open(os.path.join(root, "DeathWish", "Media", "Book.tga")).convert("RGBA")
S = 800
img = Image.new("RGBA", (S, S), (20, 10, 9, 255))
page = book.crop((512, 0, 1024, 512)).resize((S, S), Image.LANCZOS)
img.alpha_composite(page)
sk = Image.new("RGBA", (S, S))
d = ImageDraw.Draw(sk)
ink, gap = (120, 10, 8, 255), (0, 0, 0, 0)
d.ellipse((200, 150, 600, 520), fill=ink)
d.rounded_rectangle((290, 430, 510, 620), 40, fill=ink)
d.ellipse((260, 310, 375, 430), fill=gap)
d.ellipse((425, 310, 540, 430), fill=gap)
d.polygon(((400, 425), (365, 490), (435, 490)), fill=gap)
for x in (345, 400, 455):
    d.rectangle((x-6, 540, x+6, 620), fill=gap)
glow = sk.filter(ImageFilter.GaussianBlur(30))
img.alpha_composite(glow)
img.alpha_composite(sk)
img.convert("RGB").resize((400, 400), Image.LANCZOS).save(os.path.join(root, "logo.png"))
