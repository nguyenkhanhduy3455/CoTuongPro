import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

os.makedirs("Game/assets/sprites/pieces", exist_ok=True)

# Select best calligraphy font (Traditional Chinese Bold)
font_candidates = [
    ("/System/Library/Fonts/Supplemental/Songti.ttc", 2),
    ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
    ("/System/Library/Fonts/Hiragino Sans GB.ttc", 0)
]
font_path, font_index = font_candidates[0]
for fp, fidx in font_candidates:
    try:
        f = ImageFont.truetype(fp, 100, index=fidx)
        test_chars = ["帥", "仕", "相", "傌", "俥", "炮", "兵", "將", "士", "象", "馬", "車", "砲", "卒"]
        if all(f.getmask(c).size[1] > 0 for c in test_chars):
            font_path, font_index = fp, fidx
            break
    except Exception:
        continue

print("Using font:", font_path, "index:", font_index)

# ==========================================
# 1. GENERATE 14 3D PIECES (256x256 each)
# ==========================================
def render_3d_piece(symbol, is_red, out_path):
    canvas_sz = 512
    img = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    center = (canvas_sz // 2, canvas_sz // 2)
    radius = int(canvas_sz * 0.42)
    
    # 1. Soft Drop Shadow
    shadow = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.ellipse([center[0] - radius + 4, center[1] - radius + 18,
                    center[0] + radius + 4, center[1] + radius + 24], fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    
    # 2. 3D Wood Token Base
    token = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(token)
    
    # Red: Warm Sandalwood / Honey Amber Wood
    # Black: Dark Ebony / Teak Wood
    for r in range(radius, 0, -1):
        t = r / radius
        angle_bias = 0.35  # Light from top-left
        if is_red:
            # Outer bevel / wood grain
            if t > 0.90:
                base_r, base_g, base_b = int(180 + 30 * t), int(135 + 25 * t), int(70 + 20 * t)
            else:
                base_r, base_g, base_b = int(245 - 25 * (1-t)), int(218 - 30 * (1-t)), int(172 - 35 * (1-t))
        else:
            # Ebony / dark teak
            if t > 0.90:
                base_r, base_g, base_b = int(55 + 25 * t), int(45 + 20 * t), int(40 + 20 * t)
            else:
                base_r, base_g, base_b = int(72 - 20 * (1-t)), int(62 - 20 * (1-t)), int(58 - 20 * (1-t))
                
        t_draw.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=(base_r, base_g, base_b, 255))
    
    # Add subtle wood grain rings
    grain = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grain)
    for gr in range(int(radius * 0.25), int(radius * 0.85), 18):
        alpha = 25 if is_red else 35
        col = (139, 69, 19, alpha) if is_red else (25, 20, 18, alpha)
        g_draw.ellipse([center[0] - gr, center[1] - gr, center[0] + gr, center[1] + gr], outline=col, width=2)
    grain = grain.filter(ImageFilter.GaussianBlur(2))
    token.alpha_composite(grain)
    
    # Outer 3D Rim bevel (Specular light top-left, shadow bottom-right)
    rim = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    r_draw = ImageDraw.Draw(rim)
    rim_col_light = (255, 255, 255, 80) if is_red else (180, 180, 180, 60)
    rim_col_dark = (100, 50, 20, 90) if is_red else (0, 0, 0, 130)
    
    # Highlight arc
    r_draw.arc([center[0] - radius + 3, center[1] - radius + 3, center[0] + radius - 3, center[1] + radius - 3],
               start=190, end=350, fill=rim_col_light, width=6)
    # Shadow arc
    r_draw.arc([center[0] - radius + 3, center[1] - radius + 3, center[0] + radius - 3, center[1] + radius - 3],
               start=10, end=170, fill=rim_col_dark, width=6)
    token.alpha_composite(rim)
    
    # Inner Decorative Grooves & Rings
    groove = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    gr_draw = ImageDraw.Draw(groove)
    
    inner_r1 = radius - 16
    inner_r2 = radius - 26
    
    # Carved dark groove
    groove_col = (140, 80, 30, 180) if is_red else (20, 15, 15, 220)
    gr_draw.ellipse([center[0] - inner_r1, center[1] - inner_r1, center[0] + inner_r1, center[1] + inner_r1], outline=groove_col, width=4)
    
    # Colored accent ring
    ring_col = (200, 40, 35, 240) if is_red else (45, 95, 140, 240)
    gr_draw.ellipse([center[0] - inner_r2, center[1] - inner_r2, center[0] + inner_r2, center[1] + inner_r2], outline=ring_col, width=5)
    
    token.alpha_composite(groove)
    
    # 3. Engraved Calligraphy Symbol (3D Carved effect)
    text_layer = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(text_layer)
    
    font_size = int(radius * 1.15)
    font = ImageFont.truetype(font_path, font_size, index=font_index)
    
    bbox = t_draw.textbbox((0, 0), symbol, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = center[0] - tw / 2.0 - bbox[0]
    ty = center[1] - th / 2.0 - bbox[1]
    
    # Deep carved shadow (bottom-right)
    shadow_col = (70, 20, 10, 220) if is_red else (10, 10, 10, 255)
    t_draw.text((tx + 3, ty + 4), symbol, font=font, fill=shadow_col)
    
    # Inner carved highlight (top-left)
    hi_col = (255, 180, 160, 160) if is_red else (160, 190, 220, 140)
    t_draw.text((tx - 2, ty - 2), symbol, font=font, fill=hi_col)
    
    # Main Character Body (Crimson for Red, Deep Jade / Sapphire / White for Black)
    main_col = (195, 25, 20, 255) if is_red else (30, 130, 200, 255)
    t_draw.text((tx, ty), symbol, font=font, fill=main_col)
    
    # Subtle inner bevel glint on character
    glint_col = (255, 90, 80, 200) if is_red else (90, 180, 245, 200)
    t_draw.text((tx - 1, ty - 1), symbol, font=font, fill=glint_col)
    
    # Combine layers
    img.alpha_composite(shadow)
    img.alpha_composite(token)
    img.alpha_composite(text_layer)
    
    # Downsample with high-quality Lanczos filter to 256x256
    final_piece = img.resize((256, 256), Image.Resampling.LANCZOS)
    final_piece.save(out_path, "PNG")

# Generate all 14 piece sprites
pieces_def = [
    # Red pieces
    ("r_king", "帥", True),
    ("r_advisor", "仕", True),
    ("r_elephant", "相", True),
    ("r_horse", "傌", True),
    ("r_rook", "俥", True),
    ("r_cannon", "炮", True),
    ("r_pawn", "兵", True),
    # Black pieces
    ("b_king", "將", False),
    ("b_advisor", "士", False),
    ("b_elephant", "象", False),
    ("b_horse", "馬", False),
    ("b_rook", "車", False),
    ("b_cannon", "砲", False),
    ("b_pawn", "卒", False),
]

for name, sym, is_r in pieces_def:
    p_path = f"Game/assets/sprites/pieces/{name}.png"
    render_3d_piece(sym, is_r, p_path)
    print(f"Generated 3D piece: {name} ({sym}) -> {p_path}")

# ==========================================
# 2. GENERATE HIGH-RES 3D CHESSBOARD
# ==========================================
def render_chessboard(out_path):
    # Board dimensions (9 columns x 10 rows grid)
    # Target size: 1080 x 1215 (8:9 ratio grid + border margins)
    bw, bh = 1120, 1260
    board = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(board)
    
    # 1. Base Wood Planks with subtle vertical grain & warm rich mahogany / cedar tones
    for y in range(bh):
        t = y / bh
        # Subtle gradient from top to bottom
        base_r = int(215 + 15 * math.sin(t * math.pi) + 5 * math.sin(y * 0.05))
        base_g = int(168 + 12 * math.sin(t * math.pi) + 4 * math.sin(y * 0.05))
        base_b = int(112 + 10 * math.sin(t * math.pi) + 3 * math.sin(y * 0.05))
        draw.line([(0, y), (bw, y)], fill=(base_r, base_g, base_b, 255))
        
    # 2. Outer Ornate Golden & Rosewood Bevel Border
    margin = 55
    draw.rounded_rectangle([12, 12, bw - 12, bh - 12], radius=24, outline=(110, 60, 25, 255), width=8)
    draw.rounded_rectangle([20, 20, bw - 20, bh - 20], radius=18, outline=(184, 134, 11, 240), width=6)
    draw.rounded_rectangle([32, 32, bw - 32, bh - 32], radius=12, outline=(218, 165, 32, 180), width=3)
    
    # Corner golden bracket rivets
    def draw_corner_bracket(cx, cy, flip_x, flip_y):
        dx = 1 if not flip_x else -1
        dy = 1 if not flip_y else -1
        draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(218, 165, 32, 255))
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 225, 120, 255))
        draw.line([(cx, cy), (cx + dx * 28, cy)], fill=(184, 134, 11, 255), width=4)
        draw.line([(cx, cy), (cx, cy + dy * 28)], fill=(184, 134, 11, 255), width=4)
        
    draw_corner_bracket(40, 40, False, False)
    draw_corner_bracket(bw - 40, 40, True, False)
    draw_corner_bracket(40, bh - 40, False, True)
    draw_corner_bracket(bw - 40, bh - 40, True, True)
    
    # 3. Grid Coordinates & Lines
    grid_w = bw - margin * 2
    grid_h = bh - margin * 2
    cell_x = grid_w / 8.0
    cell_y = grid_h / 9.0
    
    line_col = (90, 45, 18, 230)
    line_hi = (255, 235, 190, 100)
    
    # Outer grid frame double line
    inner_box = [margin, margin, margin + grid_w, margin + grid_h]
    draw.rectangle(inner_box, outline=line_col, width=4)
    draw.rectangle([margin - 8, margin - 8, margin + grid_w + 8, margin + grid_h + 8], outline=line_col, width=2)
    
    def grid_to_px(gx, gy):
        return (margin + gx * cell_x, margin + gy * cell_y)
        
    # Horizontal lines (10 lines)
    for y in range(10):
        p1 = grid_to_px(0, y)
        p2 = grid_to_px(8, y)
        draw.line([(p1[0], p1[1] + 1), (p2[0], p2[1] + 1)], fill=line_hi, width=1)
        draw.line([p1, p2], fill=line_col, width=2)
        
    # Vertical lines (9 lines, broken across the river between y=4 and y=5)
    for x in range(9):
        if x == 0 or x == 8:
            # Outer continuous
            p1 = grid_to_px(x, 0)
            p2 = grid_to_px(x, 9)
            draw.line([(p1[0] + 1, p1[1]), (p2[0] + 1, p2[1])], fill=line_hi, width=1)
            draw.line([p1, p2], fill=line_col, width=2)
        else:
            # Top half
            p1 = grid_to_px(x, 0)
            p2 = grid_to_px(x, 4)
            draw.line([(p1[0] + 1, p1[1]), (p2[0] + 1, p2[1])], fill=line_hi, width=1)
            draw.line([p1, p2], fill=line_col, width=2)
            # Bottom half
            p3 = grid_to_px(x, 5)
            p4 = grid_to_px(x, 9)
            draw.line([(p3[0] + 1, p3[1]), (p4[0] + 1, p4[1])], fill=line_hi, width=1)
            draw.line([p3, p4], fill=line_col, width=2)
            
    # Diagonal palace lines
    # Top palace (x: 3..5, y: 0..2)
    draw.line([grid_to_px(3, 0), grid_to_px(5, 2)], fill=line_col, width=2)
    draw.line([grid_to_px(5, 0), grid_to_px(3, 2)], fill=line_col, width=2)
    # Bottom palace (x: 3..5, y: 7..9)
    draw.line([grid_to_px(3, 7), grid_to_px(5, 9)], fill=line_col, width=2)
    draw.line([grid_to_px(5, 7), grid_to_px(3, 9)], fill=line_col, width=2)
    
    # 4. River Calligraphy (楚河 漢界)
    river_y = margin + 4.5 * cell_y
    river_font = ImageFont.truetype(font_path, 42, index=font_index)
    
    # 楚 河 (left)
    chu_he = "楚  河"
    bbox1 = draw.textbbox((0, 0), chu_he, font=river_font)
    t1_w = bbox1[2] - bbox1[0]
    t1_h = bbox1[3] - bbox1[1]
    t1_x = margin + 1.8 * cell_x - t1_w / 2.0
    t1_y = river_y - t1_h / 2.0
    draw.text((t1_x + 1, t1_y + 1), chu_he, font=river_font, fill=(245, 220, 180, 150))
    draw.text((t1_x, t1_y), chu_he, font=river_font, fill=(110, 55, 22, 190))
    
    # 漢 界 (right)
    han_jie = "漢  界"
    bbox2 = draw.textbbox((0, 0), han_jie, font=river_font)
    t2_w = bbox2[2] - bbox2[0]
    t2_h = bbox2[3] - bbox2[1]
    t2_x = margin + 6.2 * cell_x - t2_w / 2.0
    t2_y = river_y - t2_h / 2.0
    draw.text((t2_x + 1, t2_y + 1), han_jie, font=river_font, fill=(245, 220, 180, 150))
    draw.text((t2_x, t2_y), han_jie, font=river_font, fill=(110, 55, 22, 190))
    
    # 5. Position Cross Marks (Cannon & Pawn points)
    def draw_star_cross(gx, gy):
        cx, cy = grid_to_px(gx, gy)
        d = 6
        l = 10
        cross_col = (100, 50, 20, 220)
        # 4 corners around intersection
        corners = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for sx, sy in corners:
            # Skip outer edges if touching borders
            if gx == 0 and sx == -1: continue
            if gx == 8 and sx == 1: continue
            px = cx + sx * d
            py = cy + sy * d
            draw.line([(px, py), (px + sx * l, py)], fill=cross_col, width=2)
            draw.line([(px, py), (px, py + sy * l)], fill=cross_col, width=2)
            
    # Cannons
    draw_star_cross(1, 2)
    draw_star_cross(7, 2)
    draw_star_cross(1, 7)
    draw_star_cross(7, 7)
    # Pawns
    for px in [0, 2, 4, 6, 8]:
        draw_star_cross(px, 3)
        draw_star_cross(px, 6)
        
    board.save(out_path, "PNG")
    print(f"Generated high-resolution chessboard: {out_path}")

render_chessboard("Game/assets/sprites/board_wood.png")
