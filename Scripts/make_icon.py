#!/usr/bin/env python3
"""Generate AppIcon.icns: tyf glyph in white on a liquid-glass gradient squircle."""
import subprocess, sys, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO = os.path.join(ROOT, "Resources", "logo-tyf.png")
OUT_ICNS = os.path.join(ROOT, "Resources", "AppIcon.icns")

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# Rounded-rect mask (macOS squircle approximation)
mask = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(mask)
margin = int(S * 0.08)
radius = int(S * 0.22)
d.rounded_rectangle([margin, margin, S - margin, S - margin], radius=radius, fill=255)

# Vertical gradient background (deep navy -> slate blue)
grad = Image.new("RGBA", (S, S))
top, bottom = (14, 22, 38, 255), (42, 62, 100, 255)
for y in range(S):
    t = y / S
    row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
    for _ in [0]:
        pass
    ImageDraw.Draw(grad).line([(0, y), (S, y)], fill=row)

# Teal/blue orbs for the liquid feel
orbs = Image.new("RGBA", (S, S), (0, 0, 0, 0))
od = ImageDraw.Draw(orbs)
od.ellipse([-200, -250, 550, 500], fill=(56, 214, 194, 110))
od.ellipse([500, 350, 1250, 1100], fill=(90, 133, 250, 110))
orbs = orbs.filter(ImageFilter.GaussianBlur(140))
grad = Image.alpha_composite(grad, orbs)

# Top specular sheen
sheen = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(sheen)
sd.ellipse([int(S*0.05), int(-S*0.35), int(S*0.95), int(S*0.42)], fill=(255, 255, 255, 46))
sheen = sheen.filter(ImageFilter.GaussianBlur(60))
grad = Image.alpha_composite(grad, sheen)

img.paste(grad, (0, 0), mask)

# White glyph from the tyf logo alpha channel
logo = Image.open(LOGO).convert("RGBA")
alpha = logo.split()[3]
glyph = Image.new("RGBA", logo.size, (255, 255, 255, 0))
glyph.putalpha(alpha)
white = Image.new("RGBA", logo.size, (245, 248, 252, 255))
glyph = Image.composite(white, Image.new("RGBA", logo.size, (0, 0, 0, 0)), alpha)
gs = int(S * 0.58)
glyph = glyph.resize((gs, gs), Image.LANCZOS)
img.paste(glyph, ((S - gs) // 2, (S - gs) // 2), glyph)

# Build .icns via iconutil
iconset = os.path.join(ROOT, "Resources", "AppIcon.iconset")
os.makedirs(iconset, exist_ok=True)
for size in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        px = size * scale
        name = f"icon_{size}x{size}" + ("@2x" if scale == 2 else "") + ".png"
        img.resize((px, px), Image.LANCZOS).save(os.path.join(iconset, name))
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", OUT_ICNS], check=True)
subprocess.run(["rm", "-rf", iconset])
print("OK:", OUT_ICNS)
