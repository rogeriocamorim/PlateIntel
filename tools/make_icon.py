"""Draws Media/Icon.tga, the AddOns-list icon: a skull over a nameplate health bar that the DoTs (purple) fill.

Run from the repo root: python tools/make_icon.py   (needs Pillow). WoW reads uncompressed 32-bit TGA, 128x128 here.
"""
import os

from PIL import Image, ImageDraw

S, K = 128, 4  # final size, supersampling
W = S * K
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)


def r(v):
    return int(v * K)


# tile: dark rounded square with a purple rim
d.rounded_rectangle([r(2), r(2), r(125), r(125)], radius=r(20), fill=(24, 14, 36, 255), outline=(150, 80, 200, 255), width=r(4))

# skull: cranium, jaw, eyes, nose, teeth
bone = (236, 228, 208, 255)
shade = (24, 14, 36, 255)
d.ellipse([r(30), r(16), r(98), r(78)], fill=bone)
d.rounded_rectangle([r(44), r(60), r(84), r(88)], radius=r(8), fill=bone)
d.ellipse([r(40), r(40), r(58), r(62)], fill=shade)
d.ellipse([r(70), r(40), r(88), r(62)], fill=shade)
d.polygon([(r(64), r(60)), (r(58), r(72)), (r(70), r(72))], fill=shade)
for x in (51, 60, 69):
    d.rectangle([r(x), r(78), r(x + 1.6), r(88)], fill=shade)

# nameplate health bar: purple = damage the DoTs still deal, red = health left
bx0, bx1, by0, by1 = 14, 114, 98, 116
d.rounded_rectangle([r(bx0 - 2), r(by0 - 2), r(bx1 + 2), r(by1 + 2)], radius=r(6), fill=(0, 0, 0, 255))
d.rounded_rectangle([r(bx0), r(by0), r(bx1), r(by1)], radius=r(4), fill=(150, 30, 30, 255))
d.rounded_rectangle([r(bx0), r(by0), r(bx0 + 66), r(by1)], radius=r(4), fill=(170, 90, 235, 255))

os.makedirs("Media", exist_ok=True)
img.resize((S, S), Image.LANCZOS).save("Media/Icon.tga")
print("Media/Icon.tga written")
