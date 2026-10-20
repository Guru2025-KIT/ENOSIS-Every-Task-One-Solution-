from PIL import Image
import os

src_path = r"d:\DevSpace\ENOSIS\ENOSIS-Every-Task-One-Solution-\frontend\assets\branding\enosis_logo.png"
res_dir = r"d:\DevSpace\ENOSIS\ENOSIS-Every-Task-One-Solution-\frontend\android\app\src\main\res"

sizes = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

with Image.open(src_path) as img:
    # Ensure square RGBA
    img = img.convert("RGBA")
    w, h = img.size
    dim = max(w, h)
    square_img = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
    square_img.paste(img, ((dim - w) // 2, (dim - h) // 2))
    
    for folder, size in sizes.items():
        out_folder = os.path.join(res_dir, folder)
        os.makedirs(out_folder, exist_ok=True)
        resized = square_img.resize(size, Image.Resampling.LANCZOS)
        out_path = os.path.join(out_folder, "ic_launcher.png")
        resized.save(out_path, "PNG")
        print(f"Generated {out_path} ({size[0]}x{size[1]})")

print("All ENOSIS launcher icons generated successfully!")
