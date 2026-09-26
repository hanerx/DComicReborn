"""Generate platform icons from DComicMark. Requires Flutter and Pillow."""
import json
from pathlib import Path
import shutil
import subprocess

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def main():
    flutter = shutil.which("flutter")
    if flutter is None:
        raise SystemExit("Flutter must be on PATH")
    subprocess.run(
        [flutter, "test", "tool/render_brand_icons.dart"], cwd=ROOT, check=True
    )
    brand = ROOT / "assets/branding"
    with Image.open(brand / "logo.png") as rendered:
        # iOS requires opaque icons without an alpha channel.
        logo = rendered.convert("RGB")
    logo.save(brand / "logo.png")
    with Image.open(brand / "adaptive-foreground.png") as rendered:
        foreground = rendered.convert("RGBA")
    res = ROOT / "android/app/src/main/res"
    for density, legacy_size, adaptive_size in [
        ("mdpi", 48, 108),
        ("hdpi", 72, 162),
        ("xhdpi", 96, 216),
        ("xxhdpi", 144, 324),
        ("xxxhdpi", 192, 432),
    ]:
        directory = res / f"mipmap-{density}"
        logo.resize((legacy_size, legacy_size), Image.Resampling.LANCZOS).save(
            directory / "ic_launcher.png"
        )
        foreground.resize((adaptive_size, adaptive_size), Image.Resampling.LANCZOS).save(
            directory / "ic_launcher_foreground.png"
        )
    catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((catalog / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents["images"]:
        size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
        logo.resize((size, size), Image.Resampling.LANCZOS).save(catalog / entry["filename"])
    logo.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(size, size) for size in (16, 24, 32, 48, 64, 128, 256)],
    )
    print("Generated DComic logo, Android legacy/adaptive, iOS and Windows icons.")


if __name__ == "__main__":
    main()
