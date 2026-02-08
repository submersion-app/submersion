#!/usr/bin/env python3
"""
Explore single-color (one-tone) variants:
all three parts (top wave, bottom wave, arrow) are the same color.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import os


def create_gradient(width, height, color_start, color_end):
    gradient = Image.new('RGBA', (width, height))
    for y in range(height):
        ratio = y / height
        r = int(color_start[0] + (color_end[0] - color_start[0]) * ratio)
        g = int(color_start[1] + (color_end[1] - color_start[1]) * ratio)
        b = int(color_start[2] + (color_end[2] - color_start[2]) * ratio)
        a = int(color_start[3] + (color_end[3] - color_start[3]) * ratio)
        for x in range(width):
            gradient.putpixel((x, y), (r, g, b, a))
    return gradient


def add_rounded_corners(img, radius):
    mask = Image.new('L', img.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255
    )
    result = Image.new('RGBA', img.size, (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def build_wave_arrow_mask(size):
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    cx = size // 2
    wave_width = size * 0.80
    thickness = size // 14
    wave_configs = [(size * 0.18, thickness), (size * 0.30, thickness)]
    lowest_wave_base_y = 0
    lowest_wave_thick = 0
    for base_y, thick in wave_configs:
        amplitude = size * 0.035
        num_waves = 2.5
        points_top = []
        points_bottom = []
        start_x = cx - wave_width / 2
        for i in range(int(wave_width) + 1):
            x = start_x + i
            progress = i / wave_width
            wave_y = amplitude * math.sin(progress * math.pi * 2 * num_waves)
            points_top.append((x, base_y + wave_y - thick / 2))
            points_bottom.append((x, base_y + wave_y + thick / 2))
        polygon_points = points_top + points_bottom[::-1]
        mask_draw.polygon(polygon_points, fill=255)
        if base_y > lowest_wave_base_y:
            lowest_wave_base_y = base_y
            lowest_wave_thick = thick
    amplitude = size * 0.035
    center_progress = 0.5
    center_wave_y = amplitude * math.sin(center_progress * math.pi * 2 * 2.5)
    arrow_top = lowest_wave_base_y + center_wave_y - lowest_wave_thick / 2
    arrow_bottom = size * 0.88
    arrow_width = size * 0.22
    shaft_width = size * 0.10
    head_height = size * 0.18
    mask_draw.rectangle(
        [cx - shaft_width / 2, arrow_top, cx + shaft_width / 2,
         arrow_bottom - head_height],
        fill=255,
    )
    head_top = arrow_bottom - head_height - shaft_width / 4
    mask_draw.polygon(
        [(cx, arrow_bottom), (cx - arrow_width, head_top),
         (cx + arrow_width, head_top)],
        fill=255,
    )
    return mask


def make_clip_mask(size):
    clip = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(clip)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], size // 8, fill=255)
    return clip


def make_background(size):
    color_top = (73, 232, 255, 255)
    color_bottom = (51, 191, 180, 255)
    img = create_gradient(size, size, color_top, color_bottom)
    return add_rounded_corners(img, size // 8)


def apply_depth_effects(img, mask, color, size, clip_mask):
    shadow_offset = int(size * 0.012)
    shadow_blur = int(size * 0.025)
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_color = Image.new('RGBA', (size, size), (0, 0, 0, 100))
    shadow_mask = Image.new('L', (size, size), 0)
    shadow_mask.paste(mask, (shadow_offset, shadow_offset))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(shadow_blur))
    shadow.paste(shadow_color, (0, 0), shadow_mask)
    shadow_clipped = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_clipped.paste(shadow, mask=clip_mask)
    img = Image.alpha_composite(img, shadow_clipped)

    color_layer = Image.new('RGBA', (size, size), color)
    img.paste(color_layer, (0, 0), mask)

    highlight_offset = int(size * 0.006)
    edge_blur = int(size * 0.012)
    mask_arr = mask.load()

    highlight = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hl_color = Image.new('RGBA', (size, size), (255, 255, 255, 80))
    hl_mask = Image.new('L', (size, size), 0)
    hl_mask.paste(mask, (0, -highlight_offset))
    hl_mask_arr = hl_mask.load()
    for y in range(size):
        for x in range(size):
            if mask_arr[x, y] > 0:
                hl_mask_arr[x, y] = 0
    hl_mask = hl_mask.filter(ImageFilter.GaussianBlur(edge_blur))
    highlight.paste(hl_color, (0, 0), hl_mask)

    edge_shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    sh_color = Image.new('RGBA', (size, size), (0, 0, 0, 60))
    sh_mask = Image.new('L', (size, size), 0)
    sh_mask.paste(mask, (0, highlight_offset))
    sh_mask_arr = sh_mask.load()
    for y in range(size):
        for x in range(size):
            if mask_arr[x, y] > 0:
                sh_mask_arr[x, y] = 0
    sh_mask = sh_mask.filter(ImageFilter.GaussianBlur(edge_blur))
    edge_shadow.paste(sh_color, (0, 0), sh_mask)

    hl_clipped = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hl_clipped.paste(highlight, mask=clip_mask)
    sh_clipped = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    sh_clipped.paste(edge_shadow, mask=clip_mask)
    img = Image.alpha_composite(img, hl_clipped)
    img = Image.alpha_composite(img, sh_clipped)
    return img


def make_one_tone_icon(size, color):
    img = make_background(size)
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, color, size, clip_mask)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    preview_dir = os.path.join(project_root, 'assets', 'icon', 'previews')
    os.makedirs(preview_dir, exist_ok=True)

    size = 512

    variants = [
        # Whites and near-whites
        ("White", (255, 255, 255, 255)),
        ("Ice Blue", (200, 230, 250, 255)),
        ("Mint", (180, 240, 220, 255)),
        ("Cream", (255, 245, 220, 255)),
        ("Pale Gold", (240, 210, 120, 255)),

        # Blues
        ("Navy", (15, 35, 75, 255)),
        ("Ocean Blue", (30, 90, 160, 255)),
        ("Royal Blue", (50, 70, 180, 255)),
        ("Soft Blue", (100, 160, 220, 255)),
        ("Cerulean", (0, 120, 180, 255)),

        # Teals and greens
        ("Dark Cyan", (10, 80, 90, 255)),
        ("Deep Teal", (20, 100, 105, 255)),
        ("Sea Green", (35, 130, 110, 255)),
        ("Emerald", (20, 140, 80, 255)),

        # Warm tones
        ("Gold", (218, 165, 32, 255)),
        ("Sunset Orange", (235, 140, 60, 255)),
        ("Coral", (230, 100, 80, 255)),
        ("Warm Red", (185, 35, 15, 255)),

        # Neutrals
        ("Slate", (60, 80, 100, 255)),
        ("Charcoal", (45, 50, 55, 255)),

        # Semi-transparent
        ("Frosted White", (255, 255, 255, 160)),
        ("Frosted Navy", (15, 35, 75, 140)),

        # Purples
        ("Deep Purple", (60, 30, 110, 255)),
        ("Lavender", (160, 140, 210, 255)),
    ]

    print("Generating one-tone variant previews...")
    images = []
    for idx, (label, color) in enumerate(variants):
        r, g, b, a = color
        alpha_str = f" a={a}" if a < 255 else ""
        print(f"  [{idx:02d}] {label} ({r},{g},{b}{alpha_str})")
        img = make_one_tone_icon(size, color)
        images.append((img, label, color))
        safe_name = label.lower().replace(' ', '_')
        path = os.path.join(preview_dir, f"onetone_{idx:02d}_{safe_name}.png")
        img.save(path, 'PNG')

    # Build tiled sheet - 6 columns x 4 rows
    padding = 24
    label_height = 40
    cols = 6
    rows = 4
    cell_w = size + padding
    cell_h = size + label_height + padding
    sheet_w = cols * cell_w + padding
    sheet_h = rows * cell_h + padding

    sheet = Image.new('RGBA', (sheet_w, sheet_h), (24, 24, 24, 255))
    draw = ImageDraw.Draw(sheet)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
    except (OSError, IOError):
        font = ImageFont.load_default()

    for idx, (img, label, color) in enumerate(images):
        row = idx // cols
        col = idx % cols
        x = padding + col * cell_w
        y = padding + row * cell_h
        sheet.paste(img, (x, y), img)
        text_x = x + size // 2
        text_y = y + size + 6
        draw.text(
            (text_x, text_y), label,
            fill=(200, 200, 200, 255), font=font, anchor="mt",
        )

    out_path = os.path.join(preview_dir, "one_tone_variants.png")
    sheet.save(out_path, 'PNG')
    print(f"\nSaved: {out_path}")


if __name__ == '__main__':
    main()
