#!/usr/bin/env python3
"""Generate a single tiled comparison image of all icon variants."""

from PIL import Image, ImageDraw, ImageFont
import os


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    preview_dir = os.path.join(project_root, 'assets', 'icon', 'previews')

    variants = [
        ("0_original.png", "Original"),
        ("1_white_outline.png", "1: White Outline"),
        ("2_warmer_red.png", "2: Warmer Red"),
        ("3_dark_outline.png", "3: Dark Outline"),
        ("4_gradient_red.png", "4: Gradient Red"),
        ("5_combined.png", "5: Outline + Warm Red"),
    ]

    icon_size = 512
    padding = 30
    label_height = 50
    cols = 3
    rows = 2

    cell_w = icon_size + padding
    cell_h = icon_size + label_height + padding

    sheet_w = cols * cell_w + padding
    sheet_h = rows * cell_h + padding

    sheet = Image.new('RGBA', (sheet_w, sheet_h), (24, 24, 24, 255))
    draw = ImageDraw.Draw(sheet)

    # Try to get a reasonable font
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    except (OSError, IOError):
        font = ImageFont.load_default()

    for idx, (filename, label) in enumerate(variants):
        row = idx // cols
        col = idx % cols

        x = padding + col * cell_w
        y = padding + row * cell_h

        img_path = os.path.join(preview_dir, filename)
        img = Image.open(img_path).convert('RGBA')

        sheet.paste(img, (x, y), img)

        text_x = x + icon_size // 2
        text_y = y + icon_size + 10
        draw.text(
            (text_x, text_y),
            label,
            fill=(220, 220, 220, 255),
            font=font,
            anchor="mt",
        )

    out_path = os.path.join(preview_dir, "tiled_comparison.png")
    sheet.save(out_path, 'PNG')
    print(f"Saved: {out_path}")


if __name__ == '__main__':
    main()
