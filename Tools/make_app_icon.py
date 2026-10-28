#!/usr/bin/env python3
"""Builds the App Store icon from the supplied artwork.

The source artwork is an icon mockup: a green rounded frame with white corners
outside it. iOS applies its own corner mask, so a square, full-bleed, opaque
image is required. The artwork's frame radius (~23%) closely matches the iOS
mask (~22.4%), so this script keeps the frame and only repaints the white
corners with the frame's own green (normalised convolution of nearby frame
pixels). The system mask then rounds the icon exactly as designed, and the
logotype stays safely inside the frame.

Output: opaque 1024×1024 sRGB PNG (App Store Connect rejects alpha).

Options:
  --preview PATH      also write a preview with an iOS-style corner mask
  --brand-mark DIR    also write BrandMark.png / @2x / @3x: the icon with rounded,
                      transparent corners, used on the launch screen and splash

Usage: make_app_icon.py <source-image> <output-png> [--preview PATH] [--brand-mark DIR]
"""

import argparse
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ICON_SIZE = 1024
# Rounded shape of the artwork's own frame, as fractions of the source size.
# Slightly tighter than the measured frame so anti-aliased white edges are replaced too.
FRAME_INSET = 5 / 1600
FRAME_RADIUS = 410 / 1600
# Blur used to extend frame colours into the corners.
FILL_BLUR = 28
# iOS icon corner radius as a fraction of icon size.
IOS_MASK_RADIUS = 0.2237
# Brand mark size in points on the launch screen and splash.
BRAND_MARK_POINTS = 160


def rounded_mask(size: int, inset: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((inset, inset, size - 1 - inset, size - 1 - inset), radius=radius, fill=255)
    return mask


def fill_outside(image: Image.Image, mask: Image.Image, blur: int) -> Image.Image:
    """Replaces pixels outside `mask` with a smooth extension of nearby pixels inside it."""
    filled = image
    known = mask
    # Repeated normalised convolution grows the frame colours outward until the
    # corners are covered.
    for _ in range(12):
        weight = known.filter(ImageFilter.GaussianBlur(blur))
        premultiplied = ImageChops.multiply(filled, Image.merge("RGB", (known,) * 3))
        spread = premultiplied.filter(ImageFilter.GaussianBlur(blur))
        # colour = blur(colour × mask) / blur(mask), computed per channel.
        channels = []
        weight_data = weight.load()
        for channel in spread.split():
            data = channel.load()
            out = Image.new("L", channel.size)
            out_data = out.load()
            for y in range(channel.size[1]):
                for x in range(channel.size[0]):
                    w = weight_data[x, y]
                    out_data[x, y] = min(255, round(data[x, y] * 255 / w)) if w else 0
            channels.append(out)
        extension = Image.merge("RGB", channels)
        filled = Image.composite(filled, extension, known)
        known = weight.point(lambda v: 255 if v > 0 else 0)
        if known.getextrema()[0] == 255:
            break
    return Image.composite(image, filled, mask)


def build_icon(source_path: str) -> Image.Image:
    source = Image.open(source_path).convert("RGB")
    side = min(source.size)
    source = source.crop((0, 0, side, side))
    # Work at icon size: faster, and the fill is smooth anyway.
    artwork = source.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
    inset = round(ICON_SIZE * FRAME_INSET)
    radius = round(ICON_SIZE * FRAME_RADIUS)
    mask = rounded_mask(ICON_SIZE, inset, radius)
    return fill_outside(artwork, mask, FILL_BLUR).convert("RGB")


def smooth_rounded_mask(size: int) -> Image.Image:
    """Anti-aliased iOS-style rounded mask (drawn at 4× and downsampled)."""
    big = size * 4
    return rounded_mask(big, 0, round(big * IOS_MASK_RADIUS)).resize((size, size), Image.LANCZOS)


def write_brand_mark(icon: Image.Image, directory: str) -> None:
    os.makedirs(directory, exist_ok=True)
    for scale in (1, 2, 3):
        size = BRAND_MARK_POINTS * scale
        mark = icon.resize((size, size), Image.LANCZOS).convert("RGBA")
        mark.putalpha(smooth_rounded_mask(size))
        name = "BrandMark.png" if scale == 1 else f"BrandMark@{scale}x.png"
        path = os.path.join(directory, name)
        mark.save(path, format="PNG", optimize=True)
        print(f"wrote {path} ({size}x{size}, RGBA)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the App Store icon from supplied artwork.")
    parser.add_argument("source")
    parser.add_argument("output")
    parser.add_argument("--preview")
    parser.add_argument("--brand-mark", dest="brand_mark")
    args = parser.parse_args()

    icon = build_icon(args.source)
    icon.save(args.output, format="PNG", optimize=True)
    print(f"wrote {args.output} ({icon.size[0]}x{icon.size[1]}, {icon.mode})")

    if args.preview:
        preview = Image.new("RGB", (ICON_SIZE, ICON_SIZE), (240, 240, 240))
        preview.paste(icon, (0, 0), smooth_rounded_mask(ICON_SIZE))
        preview.save(args.preview)
        print(f"wrote {args.preview} (masked preview)")
    if args.brand_mark:
        write_brand_mark(icon, args.brand_mark)


if __name__ == "__main__":
    main()
