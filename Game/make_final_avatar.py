import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

def create_master_general_icon(src_frame_path, out_icon_path):
    src_img = Image.open(src_frame_path).convert("RGBA")
    sw, sh = src_img.size
    
    # 1:1 center crop focusing slightly on upper body / head of the General
    sq_size = min(sw, sh)
    crop_x = (sw - sq_size) // 2
    crop_y = max(0, (sh - sq_size) // 2 - 20)
    
    cropped = src_img.crop((crop_x, crop_y, crop_x + sq_size, crop_y + sq_size))
    master_sz = 1024
    base_art = cropped.resize((master_sz, master_sz), Image.Resampling.LANCZOS)
    
    # Visual enhancements for crisp icon presentation
    base_art = ImageEnhance.Contrast(base_art).enhance(1.25)
    base_art = ImageEnhance.Color(base_art).enhance(1.30)
    base_art = ImageEnhance.Sharpness(base_art).enhance(1.35)
    
    # Squircle mask (standard modern mobile icon curvature)
    corner_radius = 220
    mask = Image.new("L", (master_sz, master_sz), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle([16, 16, master_sz - 16, master_sz - 16], radius=corner_radius, fill=255)
    
    # Vignette
    vignette = Image.new("RGBA", (master_sz, master_sz), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vignette)
    for r in range(int(master_sz * 0.72), int(master_sz * 0.44), -8):
        factor = (r - master_sz * 0.44) / (master_sz * 0.28)
        alpha = int(150 * factor)
        v_draw.ellipse([master_sz // 2 - r, master_sz // 2 - r, master_sz // 2 + r, master_sz // 2 + r],
                       outline=(0, 0, 0, alpha), width=10)
    vignette = vignette.filter(ImageFilter.GaussianBlur(14))
    base_art.alpha_composite(vignette)
    
    # Ornate Gold Border
    border = Image.new("RGBA", (master_sz, master_sz), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border)
    b_draw.rounded_rectangle([20, 20, master_sz - 20, master_sz - 20], radius=corner_radius - 4,
                             outline=(180, 130, 20, 240), width=12)
    b_draw.rounded_rectangle([32, 32, master_sz - 32, master_sz - 32], radius=corner_radius - 16,
                             outline=(255, 215, 0, 220), width=5)
    b_draw.rounded_rectangle([42, 42, master_sz - 42, master_sz - 42], radius=corner_radius - 26,
                             outline=(255, 245, 180, 130), width=2)
    
    # Corner studs
    def draw_stud(cx, cy):
        b_draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(218, 165, 32, 255))
        b_draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 235, 140, 255))
        
    draw_stud(95, 95)
    draw_stud(master_sz - 95, 95)
    draw_stud(95, master_sz - 95)
    draw_stud(master_sz - 95, master_sz - 95)
    
    base_art.alpha_composite(border)
    
    # Final composite
    final_icon = Image.new("RGBA", (master_sz, master_sz), (0, 0, 0, 0))
    final_icon.paste(base_art, (0, 0), mask)
    
    final_icon.save(out_icon_path, "PNG")
    
    # Update project icon paths
    final_icon.save("Game/icon.png", "PNG")
    final_icon.save("Game/assets/sprites/app_icon.png", "PNG")
    
    # Export standard launcher sizes
    for s in [512, 192, 144, 96, 72, 48]:
        resized = final_icon.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(f"Game/assets/icons/icon_{s}.png", "PNG")
        
    print("Master General App Icon successfully updated!")

# Use best cinematic frame with the General
src = "Game/assets/extracted_frames/all/xe_an_phao_s7.jpg"
create_master_general_icon(src, "Game/assets/sprites/general_avatar.png")
