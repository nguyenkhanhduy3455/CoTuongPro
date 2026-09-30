import os
import math
from PIL import Image, ImageDraw

out_dir = r"D:\Github\CoTuongPro\Game\assets\sprites"
os.makedirs(out_dir, exist_ok=True)

def draw_gear(draw, cx, cy, r_outer, r_inner, r_hole, teeth_count=8, color=(255, 220, 120)):
    # Draw gear teeth and body
    points = []
    for i in range(teeth_count * 2):
        angle = i * (math.pi / teeth_count)
        is_tooth = (i % 2 == 0)
        r = r_outer if is_tooth else r_inner
        # Add slight tooth shape
        a1 = angle - 0.15
        a2 = angle + 0.15
        if is_tooth:
            points.append((cx + (r_outer) * math.cos(a1), cy + (r_outer) * math.sin(a1)))
            points.append((cx + (r_outer) * math.cos(a2), cy + (r_outer) * math.sin(a2)))
        else:
            points.append((cx + (r_inner) * math.cos(a1), cy + (r_inner) * math.sin(a1)))
            points.append((cx + (r_inner) * math.cos(a2), cy + (r_inner) * math.sin(a2)))
    
    draw.polygon(points, fill=color)
    # Center hole
    draw.ellipse([cx - r_hole, cy - r_hole, cx + r_hole, cy + r_hole], fill=(0, 0, 0, 0))

def draw_power_exit(draw, cx, cy, r_outer, r_inner, stroke_w, color=(255, 220, 120)):
    # Draw open arc (270 degrees) and vertical bar
    # Arc from 45 deg to 315 deg (or top open from -60 to -120 deg)
    # In PIL arc start and end are in degrees clockwise from 3 o'clock
    # Top is 270 deg. Open at top: arc from 300 to 240 (cross 0) -> from -60 to 240
    # Let's draw thick arc by drawing multiple arcs or filled polygon
    for w in range(-stroke_w//2, stroke_w//2 + 1):
        r = r_outer + w
        draw.arc([cx - r, cy - r, cx + r, cy + r], start=125, end=415, fill=color, width=stroke_w)
    
    # Vertical line at top
    line_top = cy - r_outer - 4
    line_bot = cy - 2
    draw.line([(cx, line_top), (cx, line_bot)], fill=color, width=stroke_w)

def create_icon_button(name, icon_type, is_pressed=False):
    size = (128, 128)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = 64, 64
    if is_pressed:
        cy += 2
    radius = 56
    
    # Outer drop shadow
    if not is_pressed:
        shadow_box = [cx - radius, cy - radius + 5, cx + radius, cy + radius + 5]
        draw.ellipse(shadow_box, fill=(0, 0, 0, 100))
    
    # Base background (Mahogany / Ebony lacquer)
    if icon_type == "exit":
        base_color = (65, 18, 20) if not is_pressed else (45, 12, 14)
        border_gold = (235, 130, 110) if not is_pressed else (180, 80, 70)
        inner_gold = (255, 200, 180) if not is_pressed else (200, 140, 120)
    else:
        base_color = (38, 24, 18) if not is_pressed else (26, 16, 12)
        border_gold = (212, 168, 76) if not is_pressed else (160, 125, 55)
        inner_gold = (255, 230, 140) if not is_pressed else (200, 180, 100)
        
    main_box = [cx - radius, cy - radius, cx + radius, cy + radius]
    draw.ellipse(main_box, fill=base_color)
    
    # Triple golden ring border
    draw.ellipse(main_box, outline=border_gold, width=4)
    inner_box1 = [cx - radius + 6, cy - radius + 6, cx + radius - 6, cy + radius - 6]
    draw.ellipse(inner_box1, outline=inner_gold, width=2)
    inner_box2 = [cx - radius + 10, cy - radius + 10, cx + radius - 10, cy + radius - 10]
    draw.ellipse(inner_box2, outline=(border_gold[0]//2, border_gold[1]//2, border_gold[2]//2), width=1)
    
    # Icon layer
    icon_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    icon_draw = ImageDraw.Draw(icon_layer)
    
    if icon_type == "settings":
        # Golden gear
        draw_gear(icon_draw, cx, cy, r_outer=32, r_inner=22, r_hole=10, teeth_count=8, color=inner_gold)
    elif icon_type == "exit":
        # Power / Exit symbol
        draw_power_exit(icon_draw, cx, cy, r_outer=24, r_inner=18, stroke_w=7, color=inner_gold)
        
    # Composite
    img = Image.alpha_composite(img, icon_layer)
    
    path = os.path.join(out_dir, f"{name}.png")
    img.save(path, "PNG")
    print(f"Generated {path}")

create_icon_button("btn_icon_settings", "settings", False)
create_icon_button("btn_icon_settings_pressed", "settings", True)
create_icon_button("btn_icon_exit", "exit", False)
create_icon_button("btn_icon_exit_pressed", "exit", True)
