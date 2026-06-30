import sys
import os
try:
    from PIL import Image, ImageOps
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image, ImageOps

input_image = "/Users/harish/Downloads/Buvvas_Logo (1).webp"
assets_dir = "/Users/harish/Downloads/KH80 DRIVERS 2/Buvvas-Driver-Package/installer/assets"
server_dir = "/Users/harish/Downloads/KH80 DRIVERS 2/Buvvas-Driver-Package/license-server"

os.makedirs(assets_dir, exist_ok=True)

try:
    img = Image.open(input_image).convert("RGBA")
    
    # Create white background image for BMPs
    def make_bmp(target_size, output_name):
        bg = Image.new("RGB", target_size, (255, 255, 255))
        img_ratio = img.width / img.height
        target_ratio = target_size[0] / target_size[1]
        
        if img_ratio > target_ratio:
            new_width = target_size[0]
            new_height = int(new_width / img_ratio)
        else:
            new_height = target_size[1]
            new_width = int(new_height * img_ratio)
            
        resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        offset = ((target_size[0] - new_width) // 2, (target_size[1] - new_height) // 2)
        
        if 'A' in resized.getbands():
            bg.paste(resized, offset, resized)
        else:
            bg.paste(resized, offset)
            
        bg.save(os.path.join(assets_dir, output_name))

    make_bmp((164, 314), "buvvas_sidebar.bmp")
    make_bmp((150, 57), "buvvas_header.bmp")
    
    icon_img = Image.new("RGBA", (256, 256), (255, 255, 255, 0))
    resized_for_icon = img.resize((256, int(256 * (img.height/img.width))), Image.Resampling.LANCZOS)
    offset_icon = (0, (256 - resized_for_icon.height) // 2)
    icon_img.paste(resized_for_icon, offset_icon, resized_for_icon)
    icon_img.save(os.path.join(assets_dir, "buvvas_icon.ico"), format="ICO", sizes=[(256, 256), (128, 128), (64, 64), (32, 32), (16, 16)])
    
    img.save(os.path.join(server_dir, "logo.png"))
    
    fav_img = icon_img.resize((32, 32), Image.Resampling.LANCZOS)
    fav_img.save(os.path.join(server_dir, "favicon.png"))
    
    print("Successfully processed all images using the new webp logo.")

except Exception as e:
    print(f"Error processing images: {e}")
