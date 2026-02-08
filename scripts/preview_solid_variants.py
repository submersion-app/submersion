#!/usr/bin/env python3
"""
Explore solid color combinations for the icon, with the option
of different colors for the top wave vs bottom wave + arrow.
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


def build_single_wave_mask(size, base_y, thickness):
    """Build a mask for a single wave line."""
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    cx = size // 2
    wave_width = size * 0.80
    amplitude = size * 0.035
    num_waves = 2.5
    points_top = []
    points_bottom = []
    start_x = cx - wave_width / 2
    for i in range(int(wave_width) + 1):
        x = start_x + i
        progress = i / wave_width
        wave_y = amplitude * math.sin(progress * math.pi * 2 * num_waves)
        points_top.append((x, base_y + wave_y - thickness / 2))
        points_bottom.append((x, base_y + wave_y + thickness / 2))
    polygon_points = points_top + points_bottom[::-1]
    mask_draw.polygon(polygon_points, fill=255)
    return mask


def build_arrow_mask(size):
    """Build a mask for just the arrow (shaft + head)."""
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    cx = size // 2
    thickness = size // 14

    # We need the lowest wave's position to connect the arrow
    lowest_base_y = size * 0.30
    amplitude = size * 0.035
    center_progress = 0.5
    center_wave_y = amplitude * math.sin(center_progress * math.pi * 2 * 2.5)

    arrow_top = lowest_base_y + center_wave_y - thickness / 2
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


def apply_shadow_for_mask(img, mask, size, clip_mask):
    """Apply drop shadow for a given mask layer."""
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
    return Image.alpha_composite(img, shadow_clipped)


def apply_edge_lighting(img, mask, size, clip_mask):
    """Apply edge highlight and shadow effects."""
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


def combine_masks(masks):
    """Combine multiple L-mode masks into one."""
    size = masks[0].size
    combined = Image.new('L', size, 0)
    combined_arr = combined.load()
    for m in masks:
        m_arr = m.load()
        for y in range(size[1]):
            for x in range(size[0]):
                val = combined_arr[x, y] + m_arr[x, y]
                combined_arr[x, y] = min(255, val)
    return combined


def make_solid_icon(size, wave1_color, wave2_color, arrow_color):
    """
    Build an icon with three independently colored parts:
    - wave1_color: top wave
    - wave2_color: bottom wave
    - arrow_color: shaft + arrowhead
    """
    thickness = size // 14
    wave1_mask = build_single_wave_mask(size, size * 0.18, thickness)
    wave2_mask = build_single_wave_mask(size, size * 0.30, thickness)
    arrow_mask = build_arrow_mask(size)

    full_mask = combine_masks([wave1_mask, wave2_mask, arrow_mask])
    clip_mask = make_clip_mask(size)
    img = make_background(size)

    # Shadow for the combined shape
    img = apply_shadow_for_mask(img, full_mask, size, clip_mask)

    # Paste each part with its own color
    for part_mask, color in [
        (wave1_mask, wave1_color),
        (wave2_mask, wave2_color),
        (arrow_mask, arrow_color),
    ]:
        color_layer = Image.new('RGBA', (size, size), color)
        img.paste(color_layer, (0, 0), part_mask)

    # Edge lighting on combined shape
    img = apply_edge_lighting(img, full_mask, size, clip_mask)

    return img


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    preview_dir = os.path.join(project_root, 'assets', 'icon', 'previews')
    os.makedirs(preview_dir, exist_ok=True)

    size = 512

    # Color palette
    white = (255, 255, 255, 255)
    navy = (15, 35, 75, 255)
    deep_teal = (20, 100, 105, 255)
    gold = (218, 165, 32, 255)
    coral = (230, 100, 80, 255)
    soft_blue = (100, 160, 220, 255)
    slate = (60, 80, 100, 255)
    cream = (255, 245, 220, 255)
    sunset_orange = (235, 140, 60, 255)
    mint = (180, 240, 220, 255)
    pale_gold = (240, 210, 120, 255)
    dark_cyan = (10, 80, 90, 255)

    variants = [
        # -- All one color --
        ("All White", white, white, white),
        ("All Navy", navy, navy, navy),

        # -- White waves, colored arrow --
        ("W/W/Navy", white, white, navy),
        ("W/W/Teal", white, white, deep_teal),
        ("W/W/Gold", white, white, gold),
        ("W/W/Slate", white, white, slate),

        # -- Colored waves, white arrow --
        ("Navy/Navy/W", navy, navy, white),
        ("Teal/Teal/W", deep_teal, deep_teal, white),

        # -- Gradient feel: lighter top, darker bottom --
        ("Mint/W/Navy", mint, white, navy),
        ("W/Cream/Gold", white, cream, gold),
        ("PaleGold/W/Navy", pale_gold, white, navy),
        ("SoftBlu/W/Navy", soft_blue, white, navy),

        # -- Bold contrast combos --
        ("Gold/W/Navy", gold, white, navy),
        ("W/Gold/Navy", white, gold, navy),
        ("Coral/W/W", coral, white, white),
        ("W/W/Coral", white, white, coral),

        # -- Monochrome tones --
        ("DkCyan/Teal/W", dark_cyan, deep_teal, white),
        ("Slate/W/Slate", slate, white, slate),
        ("Navy/W/Navy", navy, white, navy),
        ("W/Navy/W", white, navy, white),
    ]

    print("Generating solid color variant previews...")
    images = []
    for idx, (label, c1, c2, c3) in enumerate(variants):
        print(f"  [{idx:02d}] {label}")
        img = make_solid_icon(size, c1, c2, c3)
        images.append((img, label))
        individual_path = os.path.join(
            preview_dir, f"solid_{idx:02d}_{label.lower().replace('/', '_')}.png"
        )
        img.save(individual_path, 'PNG')

    # Build tiled sheet - 5 columns x 4 rows
    padding = 24
    label_height = 40
    cols = 5
    rows = 4
    cell_w = size + padding
    cell_h = size + label_height + padding
    sheet_w = cols * cell_w + padding
    sheet_h = rows * cell_h + padding

    sheet = Image.new('RGBA', (sheet_w, sheet_h), (24, 24, 24, 255))
    draw = ImageDraw.Draw(sheet)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
    except (OSError, IOError):
        font = ImageFont.load_default()

    for idx, (img, label) in enumerate(images):
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

    out_path = os.path.join(preview_dir, "solid_variants.png")
    sheet.save(out_path, 'PNG')
    print(f"\nSaved: {out_path}")


if __name__ == '__main__':
    main()
