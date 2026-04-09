#!/usr/bin/env python3
"""Generate Play Store feature graphic (1024x500)."""

from PIL import Image, ImageDraw, ImageFont
import os

# Colors from the app icon
BG_DARK = (30, 45, 80)       # dark navy (outer bg of icon)
BG_MID  = (42, 62, 110)      # mid navy
TEAL    = (134, 219, 201)    # sprite body color
ORANGE  = (220, 120, 40)     # play button color
WHITE   = (255, 255, 255)
LIGHT_BLUE = (160, 190, 240)

W, H = 1024, 500

img = Image.new("RGB", (W, H), BG_DARK)
draw = ImageDraw.Draw(img)

# Gradient-ish background: draw horizontal bands
for y in range(H):
    t = y / H
    r = int(BG_DARK[0] + (BG_MID[0] - BG_DARK[0]) * (1 - abs(t - 0.5) * 2))
    g = int(BG_DARK[1] + (BG_MID[1] - BG_DARK[1]) * (1 - abs(t - 0.5) * 2))
    b = int(BG_DARK[2] + (BG_MID[2] - BG_DARK[2]) * (1 - abs(t - 0.5) * 2))
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# ---- Pixel art decorative dots (scattered small squares) ----
import random
random.seed(42)
for _ in range(60):
    x = random.randint(0, W)
    y = random.randint(0, H)
    size = random.choice([2, 3, 4])
    alpha = random.randint(20, 80)
    color = random.choice([TEAL, LIGHT_BLUE, WHITE])
    c = tuple(int(c * alpha / 100) + int(BG_MID[i] * (100 - alpha) / 100) for i, c in enumerate(color))
    draw.rectangle([x, y, x+size, y+size], fill=c)

# ---- Place app icon on the left ----
icon_path = os.path.join(os.path.dirname(__file__), "icon-512.png")
icon = Image.open(icon_path).convert("RGBA")

# Resize icon to fit nicely
icon_size = 360
icon = icon.resize((icon_size, icon_size), Image.LANCZOS)

# Position: centered vertically, left side with padding
icon_x = 80
icon_y = (H - icon_size) // 2
img.paste(icon, (icon_x, icon_y), icon)

# ---- Text on the right ----
text_x = icon_x + icon_size + 60
text_area_w = W - text_x - 60

# Try to load a system font; fall back to default
def get_font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/SF Pro Display.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()

# App name "Shiru"
font_title = get_font(96, bold=True)
font_sub   = get_font(36)
font_tag   = get_font(28)

title = "Shiru"
tagline = "A DIY audio player for kids"
desc1 = "Parents build the library."
desc2 = "Kids tap cards to play."

# Draw title
title_y = 110
draw.text((text_x, title_y), title, font=font_title, fill=WHITE)

# Teal underline accent
try:
    bbox = draw.textbbox((text_x, title_y), title, font=font_title)
    title_w = bbox[2] - bbox[0]
    title_h = bbox[3] - bbox[1]
except Exception:
    title_w = 220
    title_h = 96

underline_y = title_y + title_h + 8
draw.rectangle([text_x, underline_y, text_x + title_w, underline_y + 5], fill=TEAL)

# Tagline
sub_y = underline_y + 28
draw.text((text_x, sub_y), tagline, font=font_sub, fill=LIGHT_BLUE)

# Description lines
desc_y = sub_y + 60
draw.text((text_x, desc_y), desc1, font=font_tag, fill=(200, 210, 230))
draw.text((text_x, desc_y + 42), desc2, font=font_tag, fill=(200, 210, 230))

# Small pixel squares as decoration next to text
for i, color in enumerate([TEAL, ORANGE, LIGHT_BLUE]):
    px = text_x + i * 22
    py = desc_y + 110
    draw.rectangle([px, py, px + 14, py + 14], fill=color)

# ---- Save ----
out_path = os.path.join(os.path.dirname(__file__), "feature-graphic-1024x500.png")
img.save(out_path, "PNG", optimize=True)
print(f"Saved: {out_path}")
print(f"Size: {os.path.getsize(out_path) // 1024} KB")
