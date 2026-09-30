import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

size = 1024
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 1. Background: Dark lacquered mahogany with subtle radial gradient & rounded corners
center = (size // 2, size // 2)
bg_radius = size * 0.48

# Create background layer
bg = Image.new("RGBA", (size, size), (18, 20, 26, 255))
bg_draw = ImageDraw.Draw(bg)

# Rounded rectangle squircle mask for modern mobile app icon
corner_radius = 220
bg_mask = Image.new("L", (size, size), 0)
mask_draw = ImageDraw.Draw(bg_mask)
mask_draw.rounded_rectangle([20, 20, size - 20, size - 20], radius=corner_radius, fill=255)

# Radial gradient on background
for r in range(int(size * 0.75), 0, -8):
    factor = r / (size * 0.75)
    # Dark red/brown mahogany to dark slate
    cr = int(35 + (60 - 35) * (1 - factor))
    cg = int(22 + (28 - 22) * (1 - factor))
    cb = int(24 + (30 - 24) * (1 - factor))
    bg_draw.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=(cr, cg, cb, 255))

# Golden border around squircle
border_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
b_draw = ImageDraw.Draw(border_img)
b_draw.rounded_rectangle([24, 24, size - 24, size - 24], radius=corner_radius - 4, outline=(218, 165, 32, 220), width=12)
b_draw.rounded_rectangle([36, 36, size - 36, size - 36], radius=corner_radius - 16, outline=(255, 215, 0, 140), width=4)

# 2. Main 3D Xiangqi Piece (Quân Tướng / Soái)
piece_r = 320
piece_center = (size // 2, size // 2 + 10)

# Drop shadow for the piece
shadow_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
s_draw = ImageDraw.Draw(shadow_img)
s_draw.ellipse(
    [piece_center[0] - piece_r - 10, piece_center[1] - piece_r + 25,
     piece_center[0] + piece_r + 10, piece_center[1] + piece_r + 45],
    fill=(0, 0, 0, 180)
)
shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(28))

# Piece Base (Wood Token)
piece_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
p_draw = ImageDraw.Draw(piece_img)

# Radial gradient for 3D wood sphere/cylinder bevel
for r in range(piece_r, 0, -2):
    t = r / piece_r
    # Warm ivory / sandalwood gradient
    if t > 0.92:
        # Outer dark gold rim
        col = (int(160 + 60 * (1-t)*10), int(115 + 40 * (1-t)*10), int(45 + 20 * (1-t)*10), 255)
    else:
        # Sandalwood face
        col = (int(248 - 35 * (1-t)), int(224 - 40 * (1-t)), int(185 - 45 * (1-t)), 255)
    p_draw.ellipse([piece_center[0] - r, piece_center[1] - r, piece_center[0] + r, piece_center[1] + r], fill=col)

# Inner gold & red rings
p_draw.ellipse([piece_center[0] - piece_r + 18, piece_center[1] - piece_r + 18,
                piece_center[0] + piece_r - 18, piece_center[1] + piece_r - 18], outline=(184, 134, 11, 255), width=8)
p_draw.ellipse([piece_center[0] - piece_r + 32, piece_center[1] - piece_r + 32,
                piece_center[0] + piece_r - 32, piece_center[1] + piece_r - 32], outline=(192, 57, 43, 240), width=6)

# 3. Calligraphy Character '帥' (Soái / General)
font_candidates = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/Library/Fonts/Arial Unicode.ttf"
]
font_path = None
for fp in font_candidates:
    try:
        ImageFont.truetype(fp, 360)
        font_path = fp
        break
    except Exception:
        continue

if font_path:
    font = ImageFont.truetype(font_path, 340)
else:
    font = ImageFont.load_default()

symbol = "帥"

# Get text bounding box to center accurately
bbox = p_draw.textbbox((0, 0), symbol, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
tx = piece_center[0] - tw / 2.0 - bbox[0]
ty = piece_center[1] - th / 2.0 - bbox[1]

# Engraved shadow for the character
p_draw.text((tx + 4, ty + 6), symbol, font=font, fill=(80, 20, 15, 200))
# Inner embossed deep red core
p_draw.text((tx, ty), symbol, font=font, fill=(192, 41, 43, 255))
# Golden highlight on character
p_draw.text((tx - 2, ty - 2), symbol, font=font, fill=(235, 87, 87, 230))

# 4. Subtle Dragon / Star Accents
star_col = (255, 215, 0, 220)
# Corner stars / studs
def draw_star(draw_ctx, cx, cy, rad):
    draw_ctx.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=star_col)
    draw_ctx.ellipse([cx - rad*0.6, cy - rad*0.6, cx + rad*0.6, cy + rad*0.6], fill=(255, 255, 255, 240))

draw_star(b_draw, 90, 90, 10)
draw_star(b_draw, size - 90, 90, 10)
draw_star(b_draw, 90, size - 90, 10)
draw_star(b_draw, size - 90, size - 90, 10)

# Composite final image
final_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
final_img.paste(bg, (0, 0), bg_mask)
final_img.alpha_composite(shadow_img)
final_img.alpha_composite(piece_img)
final_img.alpha_composite(border_img)

# Save Master 1024x1024
final_img.save("Game/icon.png", "PNG")
final_img.save("Game/assets/sprites/app_icon.png", "PNG")

# Generate standard Android launcher sizes (192, 144, 96, 72, 48)
os.makedirs("Game/assets/icons", exist_ok=True)
for s in [512, 192, 144, 96, 72, 48]:
    resized = final_img.resize((s, s), Image.Resampling.LANCZOS)
    resized.save(f"Game/assets/icons/icon_{s}.png", "PNG")

# Also update project root icon
final_img.resize((128, 128), Image.Resampling.LANCZOS).save("Game/icon.svg.png", "PNG")

print("Created high-resolution App Icon assets successfully!")
