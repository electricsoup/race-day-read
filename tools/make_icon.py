"""Draws the app icon: a race bib with a check mark, on the Wine & Dine burgundy."""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
S = 1024
out = sys.argv[1]
img = Image.new("RGB", (S, S), (74, 22, 38))
d = ImageDraw.Draw(img)
# soft vertical glow
for y in range(S):
    t = y / S
    r = int(74 + (40 - 74) * t); g = int(22 + (14 - 22) * t); b = int(38 + (52 - 38) * t)
    d.line([(0, y), (S, y)], fill=(r, g, b))
# bib on its own layer so it can rotate
bib = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(bib)
x0, y0, x1, y1 = 182, 262, 842, 762
bd.rounded_rectangle([x0, y0, x1, y1], radius=46, fill=(255, 253, 248, 255))
bd.rectangle([x0 + 70, y0 + 92, x1 - 70, y0 + 108], fill=(217, 174, 85, 255))
for cx, cy in [(x0 + 52, y0 + 52), (x1 - 52, y0 + 52), (x0 + 52, y1 - 52), (x1 - 52, y1 - 52)]:
    bd.ellipse([cx - 19, cy - 19, cx + 19, cy + 19], fill=(74, 22, 38, 255))
# check mark
pts = [(x0 + 190, y0 + 300), (x0 + 290, y0 + 395), (x1 - 170, y0 + 175)]
bd.line(pts, fill=(140, 42, 60, 255), width=74, joint="curve")
for p in [pts[0], pts[2]]:
    bd.ellipse([p[0] - 37, p[1] - 37, p[0] + 37, p[1] + 37], fill=(140, 42, 60, 255))
bib = bib.rotate(6, resample=Image.BICUBIC, center=(S / 2, S / 2))
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
shadow.paste((0, 0, 0, 120), mask=bib.split()[3])
shadow = shadow.filter(ImageFilter.GaussianBlur(24))
img.paste(shadow, (0, 22), shadow)
img.paste(bib, (0, 0), bib)
img.save(out)
print("saved", out)
