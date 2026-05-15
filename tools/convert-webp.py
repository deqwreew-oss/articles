"""
Convert all .jpg/.jpeg/.png images in a folder to .webp.
Optionally downscale to MAX_DIM on the longest side.
Keeps originals in place; caller can delete them after verifying.

Usage:
    python tools/convert-webp.py <folder> [--max-dim 1600] [--quality 82]
"""

import argparse
import sys
from pathlib import Path
from PIL import Image

SUPPORTED = {".jpg", ".jpeg", ".png"}


def convert_one(src: Path, max_dim: int, quality: int) -> tuple[int, int]:
    with Image.open(src) as im:
        # Preserve transparency for PNG -> WebP
        if im.mode in ("P", "LA"):
            im = im.convert("RGBA")
        elif im.mode == "CMYK":
            im = im.convert("RGB")

        w, h = im.size
        longest = max(w, h)
        if longest > max_dim:
            ratio = max_dim / longest
            new_size = (round(w * ratio), round(h * ratio))
            im = im.resize(new_size, Image.LANCZOS)

        dst = src.with_suffix(".webp")
        # method=6 = slowest/best compression
        save_kwargs = {"quality": quality, "method": 6}
        if im.mode == "RGBA":
            save_kwargs["lossless"] = False
        im.save(dst, "WEBP", **save_kwargs)

    return src.stat().st_size, dst.stat().st_size


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--max-dim", type=int, default=1600)
    parser.add_argument("--quality", type=int, default=82)
    args = parser.parse_args()

    folder = Path(args.folder).resolve()
    if not folder.is_dir():
        print(f"Not a directory: {folder}", file=sys.stderr)
        return 1

    files = sorted(p for p in folder.iterdir() if p.suffix.lower() in SUPPORTED)
    if not files:
        print("No images found.")
        return 0

    total_before = 0
    total_after = 0
    for f in files:
        before, after = convert_one(f, args.max_dim, args.quality)
        total_before += before
        total_after += after
        pct = (1 - after / before) * 100 if before else 0
        print(f"  {f.name:20s} {before/1024:8.1f} KB -> {after/1024:7.1f} KB  ({pct:+.1f}%)")

    saved = total_before - total_after
    pct = (1 - total_after / total_before) * 100 if total_before else 0
    print()
    print(f"TOTAL: {total_before/1024/1024:.2f} MB -> {total_after/1024/1024:.2f} MB  (saved {saved/1024/1024:.2f} MB, -{pct:.1f}%)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
