import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

# Let's inspect candidate frames and crop the General's face / action
# Candidates from videos:
# ma_an_chot_s2, ma_an_chot_s3
# xe_an_phao_s7, xe_an_phao_s8
# xe_an_ma_s7, xe_an_ma_s8
# phao_an_tot_s7, phao_an_tot_s8

def process_general_icon(src_frame_path, out_icon_path, title_badge=True):
    src_img = Image.open(src_frame_path).convert("RGBA")
    sw, sh = src_img.size
    
    # We want a 1:1 square cropped tightly on the General in the center
    # Most 16:9 action is centered horizontally
    sq_size = min(sw, sh)
    crop_x = (sw - sq_size) // 2
    crop_y = (sh - sq_size) // 2
    
    # Crop central 1:1 area
    cropped = src_img.crop((crop_x, crop_y, crop_x + sq_size, crop_y + sq_size))
    
    # Resize to 1024x1024 master
    master_sz = 1024
    base_art = cropped.resize((master_sz, master_sz), Image.Resampling.LANCZOS)
    
    # Boost contrast and vibrance for app icon clarity
    enhancer_con = ImageEnhance.Contrast(base_art)
    base_art = enhancer_con.enhance(1.22)
    enhancer_col = ImageEnhance.Color(base_art)
    base_art = enhancer_col.enhance(1.25)
    enhancer_sharp = ImageEnhance.Sharpness(base_art)
    base_art = enhancer_sharp.enhance(1.3)
    
    # 1. Rounded squircle mask for modern app icon
    corner_radius = 220
    mask = Image.new("L", (master_sz, master_sz), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle([16, 16, master_sz - 16, master_sz - 16], radius=corner_radius, fill=255)
    
    # 2. Vignette / Dark dramatic edge lighting
    vignette = Image.new("RGBA", (master_sz, master_sz), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vignette)
    for r in range(int(master_sz * 0.72), int(master_sz * 0.45), -6):
        factor = (r - master_sz * 0.45) / (master_sz * 0.27)
        alpha = int(140 * factor)
        v_draw.ellipse([master_sz // 2 - r, master_sz // 2 - r, master_sz // 2 + r, master_sz // 2 + r],
                       outline=(0, 0, 0, alpha), width=8)
    vignette = vignette.filter(ImageFilter.GaussianBlur(12))
    base_art.alpha_composite(vignette)
    
    # 3. Ornate Double Gold Border with Corner Rivets
    border = Image.new("RGBA", (master_sz, master_sz), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border)
    # Outer dark gold rim
    b_draw.rounded_rectangle([20, 20, master_sz - 20, master_sz - 20], radius=corner_radius - 4,
                             outline=(180, 130, 20, 240), width=12)
    # Inner shining gold line
    b_draw.rounded_rectangle([32, 32, master_sz - 32, master_sz - 32], radius=corner_radius - 16,
                             outline=(255, 215, 0, 210), width=5)
    # Highlight hairline
    b_draw.rounded_rectangle([42, 42, master_sz - 42, master_sz - 42], radius=corner_radius - 26,
                             outline=(255, 245, 180, 120), width=2)
    
    # Golden corner studs
    def draw_stud(cx, cy):
        b_draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(218, 165, 32, 255))
        b_draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 235, 140, 255))
        
    draw_stud(95, 95)
    draw_stud(master_sz - 95, 95)
    draw_stud(95, master_sz - 95)
    draw_stud(master_sz - 95, master_sz - 95)
    
    base_art.alpha_composite(border)
    
    # Final masked icon
    final_icon = Image.new("RGBA", (master_sz, master_sz), (0, 0, 0, 0))
    final_icon.paste(base_art, (0, 0), mask)
    final_icon.save(out_icon_path, "PNG")
    print(f"Generated General Avatar Icon: {out_icon_path}")

os.makedirs("Game/assets/avatar_candidates", exist_ok=True)
for f in ["xe_an_phao_s7.jpg", "xe_an_phao_s8.jpg", "xe_an_ma_s7.jpg", "xe_an_ma_s8.jpg", "phao_an_tot_s7.jpg", "ma_an_chot_s2.jpg", "ma_an_chot_s7.jpg"]:
    src = f"Game/assets/extracted_frames/all/{f}"
    if os.path.exists(src):
        dst = f"Game/assets/avatar_candidates/icon_{f[:-4]}.png"
        process_general_icon(src, dst)
