#!/usr/bin/env python3
"""
Generate the final Submersion app icon.

Renders at 4x resolution and downscales with LANCZOS for anti-aliased edges.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

SUPERSAMPLE = 4


def create_gradient(width, height, color_start, color_end):
    """Create a vertical gradient."""
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
    """Add rounded corners to an image."""
    mask = Image.new('L', img.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255
    )
    result = Image.new('RGBA', img.size, (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def build_flag(size):
    """Build the dive flag pattern layer."""
    flag = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    flag_draw = ImageDraw.Draw(flag)

    dive_red = (204, 0, 0, 255)
    white = (255, 255, 255, 255)

    flag_draw.rectangle([0, 0, size, size], fill=dive_red)

    upper_half = size * 0.075
    lower_half = size * 0.125
    flag_draw.polygon([
        (0, 0),
        (upper_half, 0),
        (size, size - upper_half),
        (size, size),
        (size - lower_half, size),
        (0, lower_half),
    ], fill=white)

    return flag


def build_wave_arrow_mask(size):
    """Build the wave + arrow mask."""
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)

    cx = size // 2
    wave_width = size * 0.80
    thickness = size // 14

    wave_configs = [
        (size * 0.18, thickness),
        (size * 0.30, thickness),
    ]

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

    # Arrow
    amplitude = size * 0.035
    center_progress = 0.5
    center_wave_y = amplitude * math.sin(center_progress * math.pi * 2 * 2.5)

    arrow_top = lowest_wave_base_y + center_wave_y - lowest_wave_thick / 2
    arrow_bottom = size * 0.88
    arrow_width = size * 0.22
    shaft_width = size * 0.10
    head_height = size * 0.18

    mask_draw.rectangle(
        [cx - shaft_width / 2, arrow_top,
         cx + shaft_width / 2, arrow_bottom - head_height],
        fill=255
    )

    head_top = arrow_bottom - head_height - shaft_width / 4
    mask_draw.polygon([
        (cx, arrow_bottom),
        (cx - arrow_width, head_top),
        (cx + arrow_width, head_top),
    ], fill=255)

    return mask


def apply_depth_effects(img, mask, flag, size, clip_mask):
    """Apply drop shadow, white outline, flag composite, and edge lighting."""
    # Drop shadow
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

    # White outline via mask dilation
    expanded = mask.copy()
    for _ in range(4):
        expanded = expanded.filter(ImageFilter.MaxFilter(5))
    outline_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    outline_fill = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    outline_layer.paste(outline_fill, (0, 0), expanded)
    outline_clipped = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    outline_clipped.paste(outline_layer, mask=clip_mask)
    img = Image.alpha_composite(img, outline_clipped)

    # Composite dive flag pattern using waves/arrow as mask
    img.paste(flag, (0, 0), mask)

    # Edge lighting: highlight on top edges, shadow on bottom edges
    highlight_offset = int(size * 0.006)
    edge_blur = int(size * 0.012)

    # Top-edge highlight
    highlight = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hl_color = Image.new('RGBA', (size, size), (255, 255, 255, 80))
    hl_mask = Image.new('L', (size, size), 0)
    hl_mask.paste(mask, (0, -highlight_offset))
    hl_mask_arr = hl_mask.load()
    mask_arr = mask.load()
    for y in range(size):
        for x in range(size):
            if mask_arr[x, y] > 0:
                hl_mask_arr[x, y] = 0
    hl_mask = hl_mask.filter(ImageFilter.GaussianBlur(edge_blur))
    highlight.paste(hl_color, (0, 0), hl_mask)

    # Bottom-edge shadow
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


def create_icon(size):
    """Create the final Submersion app icon with anti-aliasing."""
    hi = size * SUPERSAMPLE
    color_top = (73, 232, 255, 255)    # Tropical cyan
    color_bottom = (51, 191, 180, 255) # Tropical teal
    img = create_gradient(hi, hi, color_top, color_bottom)
    img = add_rounded_corners(img, hi // 8)

    flag = build_flag(hi)
    mask = build_wave_arrow_mask(hi)

    clip_mask = Image.new('L', (hi, hi), 0)
    clip_draw = ImageDraw.Draw(clip_mask)
    clip_draw.rounded_rectangle([0, 0, hi - 1, hi - 1], hi // 8, fill=255)

    img = apply_depth_effects(img, mask, flag, hi, clip_mask)
    return img.resize((size, size), Image.LANCZOS)


def create_icon_no_rounded_corners(size):
    """Create icon without rounded corners (for macOS which applies its own mask)."""
    hi = size * SUPERSAMPLE
    color_top = (73, 232, 255, 255)    # Tropical cyan
    color_bottom = (51, 191, 180, 255) # Tropical teal
    img = create_gradient(hi, hi, color_top, color_bottom)

    flag = build_flag(hi)
    mask = build_wave_arrow_mask(hi)

    clip_mask = Image.new('L', (hi, hi), 255)

    img = apply_depth_effects(img, mask, flag, hi, clip_mask)
    return img.resize((size, size), Image.LANCZOS)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    assets_dir = os.path.join(project_root, 'assets', 'icon')
    os.makedirs(assets_dir, exist_ok=True)

    print("Generating Submersion app icon (4x supersample for anti-aliasing)...")

    # Main icon at 1024x1024 (with rounded corners for iOS, Android, etc.)
    icon_1024 = create_icon(1024)
    icon_path = os.path.join(assets_dir, 'icon.png')
    icon_1024.save(icon_path, 'PNG')
    print(f"  Created: {icon_path}")

    # macOS icon without rounded corners (macOS applies its own mask)
    macos_icon = create_icon_no_rounded_corners(1024)
    macos_path = os.path.join(assets_dir, 'icon_macos.png')
    macos_icon.save(macos_path, 'PNG')
    print(f"  Created: {macos_path}")

    # Adaptive icon foreground for Android
    adaptive_size = 1024
    adaptive_fg = Image.new('RGBA', (adaptive_size, adaptive_size), (0, 0, 0, 0))
    inner_size = int(adaptive_size * 0.65)
    inner_icon = create_icon(inner_size)
    paste_x = (adaptive_size - inner_size) // 2
    paste_y = (adaptive_size - inner_size) // 2
    adaptive_fg.paste(inner_icon, (paste_x, paste_y))

    adaptive_fg_path = os.path.join(assets_dir, 'icon_adaptive_foreground.png')
    adaptive_fg.save(adaptive_fg_path, 'PNG')
    print(f"  Created: {adaptive_fg_path}")

    # Adaptive icon background
    adaptive_bg = create_gradient(
        1024, 1024, (73, 232, 255, 255), (51, 191, 180, 255)
    )
    adaptive_bg_path = os.path.join(assets_dir, 'icon_adaptive_background.png')
    adaptive_bg.save(adaptive_bg_path, 'PNG')
    print(f"  Created: {adaptive_bg_path}")

    print("\nIcon generation complete!")


if __name__ == '__main__':
    main()
