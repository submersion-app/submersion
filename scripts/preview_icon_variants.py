#!/usr/bin/env python3
"""
Generate icon variant previews to compare approaches for reducing
red/blue clash while keeping the dive flag theme.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os


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


def build_flag(size, red_color=(204, 0, 0, 255)):
    """Build the dive flag pattern layer with configurable red."""
    flag = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    flag_draw = ImageDraw.Draw(flag)
    white = (255, 255, 255, 255)

    flag_draw.rectangle([0, 0, size, size], fill=red_color)

    stripe_width = size * 0.10
    flag_draw.polygon(
        [
            (0, 0),
            (stripe_width, 0),
            (size, size - stripe_width),
            (size, size),
            (size - stripe_width, size),
            (0, stripe_width),
        ],
        fill=white,
    )

    return flag


def build_flag_gradient(size):
    """Build dive flag with red gradient (brighter top, darker bottom)."""
    flag = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    flag_draw = ImageDraw.Draw(flag)

    red_top = (215, 30, 20)
    red_bottom = (140, 10, 25)
    for y in range(size):
        ratio = y / size
        r = int(red_top[0] + (red_bottom[0] - red_top[0]) * ratio)
        g = int(red_top[1] + (red_bottom[1] - red_top[1]) * ratio)
        b = int(red_top[2] + (red_bottom[2] - red_top[2]) * ratio)
        flag_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    white = (255, 255, 255, 255)
    stripe_width = size * 0.10
    flag_draw.polygon(
        [
            (0, 0),
            (stripe_width, 0),
            (size, size - stripe_width),
            (size, size),
            (size - stripe_width, size),
            (0, stripe_width),
        ],
        fill=white,
    )

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
        [
            cx - shaft_width / 2,
            arrow_top,
            cx + shaft_width / 2,
            arrow_bottom - head_height,
        ],
        fill=255,
    )

    head_top = arrow_bottom - head_height - shaft_width / 4
    mask_draw.polygon(
        [
            (cx, arrow_bottom),
            (cx - arrow_width, head_top),
            (cx + arrow_width, head_top),
        ],
        fill=255,
    )

    return mask


def build_expanded_mask(mask, expand_px):
    """Expand a mask outward by a given number of pixels (dilation)."""
    # Use MaxFilter for dilation effect
    expanded = mask.copy()
    iterations = max(1, expand_px // 2)
    for _ in range(iterations):
        expanded = expanded.filter(ImageFilter.MaxFilter(5))
    return expanded


def apply_depth_effects(img, mask, flag, size, clip_mask):
    """Apply drop shadow and edge lighting, then composite the flag."""
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

    img.paste(flag, (0, 0), mask)

    highlight_offset = int(size * 0.006)
    edge_blur = int(size * 0.012)

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


def apply_depth_effects_with_outline(
    img, mask, flag, size, clip_mask, outline_color, outline_width
):
    """Apply depth effects with an outline around the flag elements."""
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

    # Draw the outline by expanding the mask and filling with outline color
    expanded_mask = build_expanded_mask(mask, outline_width)
    outline_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    outline_fill = Image.new('RGBA', (size, size), outline_color)
    outline_layer.paste(outline_fill, (0, 0), expanded_mask)

    outline_clipped = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    outline_clipped.paste(outline_layer, mask=clip_mask)
    img = Image.alpha_composite(img, outline_clipped)

    # Now paste the flag on top
    img.paste(flag, (0, 0), mask)

    # Edge lighting
    highlight_offset = int(size * 0.006)
    edge_blur = int(size * 0.012)

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


def make_background(size):
    """Create the standard gradient background with rounded corners."""
    color_top = (73, 232, 255, 255)
    color_bottom = (51, 191, 180, 255)
    img = create_gradient(size, size, color_top, color_bottom)
    img = add_rounded_corners(img, size // 8)
    return img


def make_clip_mask(size):
    """Create standard clip mask with rounded corners."""
    clip_mask = Image.new('L', (size, size), 0)
    clip_draw = ImageDraw.Draw(clip_mask)
    clip_draw.rounded_rectangle([0, 0, size - 1, size - 1], size // 8, fill=255)
    return clip_mask


# -- Variant generators --


def variant_original(size):
    """Original icon (baseline for comparison)."""
    img = make_background(size)
    flag = build_flag(size)
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_white_outline(size):
    """Option 1: White outline around flag elements."""
    img = make_background(size)
    flag = build_flag(size)
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    outline_width = max(4, size // 80)
    return apply_depth_effects_with_outline(
        img, mask, flag, size, clip_mask,
        outline_color=(255, 255, 255, 255),
        outline_width=outline_width,
    )


def variant_warmer_red(size):
    """Option 2: Warmer, slightly deeper red."""
    img = make_background(size)
    flag = build_flag(size, red_color=(185, 35, 15, 255))
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_dark_outline(size):
    """Option 3: Dark navy/teal outline."""
    img = make_background(size)
    flag = build_flag(size)
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    outline_width = max(4, size // 80)
    return apply_depth_effects_with_outline(
        img, mask, flag, size, clip_mask,
        outline_color=(15, 50, 70, 255),
        outline_width=outline_width,
    )


def variant_gradient_red(size):
    """Option 4: Red gradient (bright top to deep bottom)."""
    img = make_background(size)
    flag = build_flag_gradient(size)
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_combined(size):
    """Option 5: White outline + warmer red."""
    img = make_background(size)
    flag = build_flag(size, red_color=(185, 35, 15, 255))
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    outline_width = max(4, size // 80)
    return apply_depth_effects_with_outline(
        img, mask, flag, size, clip_mask,
        outline_color=(255, 255, 255, 255),
        outline_width=outline_width,
    )


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    preview_dir = os.path.join(project_root, 'assets', 'icon', 'previews')
    os.makedirs(preview_dir, exist_ok=True)

    size = 512

    variants = [
        ("0_original", "Original (baseline)", variant_original),
        ("1_white_outline", "Option 1: White outline", variant_white_outline),
        ("2_warmer_red", "Option 2: Warmer/deeper red", variant_warmer_red),
        ("3_dark_outline", "Option 3: Dark navy outline", variant_dark_outline),
        ("4_gradient_red", "Option 4: Red gradient fill", variant_gradient_red),
        ("5_combined", "Option 5: White outline + warmer red", variant_combined),
    ]

    print("Generating icon variant previews...")
    images = []
    for filename, label, gen_fn in variants:
        print(f"  Generating: {label}")
        img = gen_fn(size)
        path = os.path.join(preview_dir, f"{filename}.png")
        img.save(path, 'PNG')
        images.append((img, label))
        print(f"    Saved: {path}")

    # Also create a side-by-side comparison sheet
    padding = 20
    label_height = 0  # We won't add text labels in the image itself
    cols = 3
    rows = 2
    sheet_w = cols * size + (cols + 1) * padding
    sheet_h = rows * size + (rows + 1) * padding
    sheet = Image.new('RGBA', (sheet_w, sheet_h), (30, 30, 30, 255))

    for idx, (img, label) in enumerate(images):
        row = idx // cols
        col = idx % cols
        x = padding + col * (size + padding)
        y = padding + row * (size + padding)
        sheet.paste(img, (x, y), img)

    sheet_path = os.path.join(preview_dir, "comparison_sheet.png")
    sheet.save(sheet_path, 'PNG')
    print(f"\n  Comparison sheet: {sheet_path}")
    print("\nDone! Check assets/icon/previews/ for all variants.")


if __name__ == '__main__':
    main()
