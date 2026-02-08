#!/usr/bin/env python3
"""
Explore creative alternatives to the red dive flag that still
clearly read as a 'dive' application icon.
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


def build_wave_arrow_outline_mask(size, outline_width):
    """Build just the outline (border) of the wave+arrow shapes."""
    inner = build_wave_arrow_mask(size)
    # Expand the mask outward
    outer = inner.copy()
    iterations = max(1, outline_width // 2)
    for _ in range(iterations):
        outer = outer.filter(ImageFilter.MaxFilter(5))
    # Subtract inner from outer to get outline only
    inner_arr = inner.load()
    outer_arr = outer.load()
    result = Image.new('L', (size, size), 0)
    result_arr = result.load()
    for y in range(size):
        for x in range(size):
            if outer_arr[x, y] > 0 and inner_arr[x, y] == 0:
                result_arr[x, y] = outer_arr[x, y]
    return result


def build_flag_solid(size, color):
    """Build flag fill with a single solid color + white stripe."""
    flag = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(flag)
    draw.rectangle([0, 0, size, size], fill=color)
    stripe_width = size * 0.10
    draw.polygon(
        [(0, 0), (stripe_width, 0), (size, size - stripe_width),
         (size, size), (size - stripe_width, size), (0, stripe_width)],
        fill=(255, 255, 255, 255),
    )
    return flag


def build_flag_no_stripe(size, color):
    """Build flag fill with a single solid color, NO stripe."""
    flag = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(flag)
    draw.rectangle([0, 0, size, size], fill=color)
    return flag


def build_flag_stripe_only(size, main_color, stripe_color):
    """Build flag with main color + custom stripe color."""
    flag = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(flag)
    draw.rectangle([0, 0, size, size], fill=main_color)
    stripe_width = size * 0.10
    draw.polygon(
        [(0, 0), (stripe_width, 0), (size, size - stripe_width),
         (size, size), (size - stripe_width, size), (0, stripe_width)],
        fill=stripe_color,
    )
    return flag


def build_flag_gradient_vert(size, top_color, bottom_color):
    """Build flag with a vertical gradient + white stripe."""
    flag = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(flag)
    for y in range(size):
        ratio = y / size
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ratio)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ratio)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ratio)
        a = int(top_color[3] + (bottom_color[3] - top_color[3]) * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b, a))
    stripe_width = size * 0.10
    draw.polygon(
        [(0, 0), (stripe_width, 0), (size, size - stripe_width),
         (size, size), (size - stripe_width, size), (0, stripe_width)],
        fill=(255, 255, 255, 255),
    )
    return flag


def make_clip_mask(size):
    clip = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(clip)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], size // 8, fill=255)
    return clip


def apply_depth_effects(img, mask, flag, size, clip_mask):
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


def make_background(size):
    color_top = (73, 232, 255, 255)
    color_bottom = (51, 191, 180, 255)
    img = create_gradient(size, size, color_top, color_bottom)
    return add_rounded_corners(img, size // 8)


# ---- Variant generators ----


def variant_white_monochrome(size):
    """Pure white shapes on cyan - clean, modern, minimal."""
    img = make_background(size)
    flag = build_flag_no_stripe(size, (255, 255, 255, 255))
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_dark_teal_tone(size):
    """Darker shade of the background - tone-on-tone elegance."""
    img = make_background(size)
    flag = build_flag_solid(size, (20, 100, 105, 255))
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_alpha_flag(size):
    """International dive Alpha flag colors - blue and white.
    The Alpha flag (blue+white, swallowtail) is the international
    signal for 'diver below'."""
    img = make_background(size)
    flag = build_flag_stripe_only(
        size,
        main_color=(25, 60, 140, 255),
        stripe_color=(255, 255, 255, 255),
    )
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_white_red_accent(size):
    """White shapes with just a thin red diagonal stripe - minimal red."""
    img = make_background(size)
    flag = build_flag_stripe_only(
        size,
        main_color=(255, 255, 255, 255),
        stripe_color=(195, 25, 18, 255),
    )
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_frosted_glass(size):
    """Semi-transparent white - frosted underwater glass effect."""
    img = make_background(size)
    flag = build_flag_no_stripe(size, (255, 255, 255, 160))
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_navy_deep(size):
    """Deep ocean navy with white stripe - nautical feel."""
    img = make_background(size)
    flag = build_flag_solid(size, (15, 35, 75, 255))
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def variant_outline_only(size):
    """White outline/wireframe of the shapes - no fill."""
    img = make_background(size)
    outline_width = max(4, size // 60)
    outline_mask = build_wave_arrow_outline_mask(size, outline_width)
    white_fill = Image.new('RGBA', (size, size), (255, 255, 255, 240))
    clip_mask = make_clip_mask(size)

    # Shadow
    shadow_offset = int(size * 0.012)
    shadow_blur = int(size * 0.025)
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_color = Image.new('RGBA', (size, size), (0, 0, 0, 80))
    shadow_mask = Image.new('L', (size, size), 0)
    shadow_mask.paste(outline_mask, (shadow_offset, shadow_offset))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(shadow_blur))
    shadow.paste(shadow_color, (0, 0), shadow_mask)
    shadow_clipped = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_clipped.paste(shadow, mask=clip_mask)
    img = Image.alpha_composite(img, shadow_clipped)

    img.paste(white_fill, (0, 0), outline_mask)
    return img


def variant_gold_accent(size):
    """Warm gold/amber shapes - complementary to teal, premium feel."""
    img = make_background(size)
    flag = build_flag_solid(size, (218, 165, 32, 255))
    mask = build_wave_arrow_mask(size)
    clip_mask = make_clip_mask(size)
    return apply_depth_effects(img, mask, flag, size, clip_mask)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    preview_dir = os.path.join(project_root, 'assets', 'icon', 'previews')
    os.makedirs(preview_dir, exist_ok=True)

    size = 512

    variants = [
        ("White Mono", variant_white_monochrome,
         "Pure white, no stripe"),
        ("Dark Teal", variant_dark_teal_tone,
         "Tone-on-tone, subtle"),
        ("Alpha Flag", variant_alpha_flag,
         "Intl dive flag (blue+white)"),
        ("Red Accent", variant_white_red_accent,
         "White w/ red stripe only"),
        ("Frosted", variant_frosted_glass,
         "Semi-transparent white"),
        ("Deep Navy", variant_navy_deep,
         "Nautical navy + white"),
        ("Outline", variant_outline_only,
         "White wireframe, no fill"),
        ("Gold", variant_gold_accent,
         "Gold/amber, teal complement"),
    ]

    print("Generating creative variant previews...")
    images = []
    for idx, (label, gen_fn, desc) in enumerate(variants):
        print(f"  {label}: {desc}")
        img = gen_fn(size)
        images.append((img, label, desc))
        individual_path = os.path.join(
            preview_dir, f"creative_{idx}_{label.lower().replace(' ', '_')}.png"
        )
        img.save(individual_path, 'PNG')

    # Build tiled sheet
    padding = 30
    label_height = 70
    cols = 4
    rows = 2
    cell_w = size + padding
    cell_h = size + label_height + padding
    sheet_w = cols * cell_w + padding
    sheet_h = rows * cell_h + padding

    sheet = Image.new('RGBA', (sheet_w, sheet_h), (24, 24, 24, 255))
    draw = ImageDraw.Draw(sheet)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 26)
        font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 17)
    except (OSError, IOError):
        font = ImageFont.load_default()
        font_small = font

    for idx, (img, label, desc) in enumerate(images):
        row = idx // cols
        col = idx % cols
        x = padding + col * cell_w
        y = padding + row * cell_h

        sheet.paste(img, (x, y), img)

        text_x = x + size // 2
        text_y = y + size + 8
        draw.text(
            (text_x, text_y), label,
            fill=(220, 220, 220, 255), font=font, anchor="mt",
        )
        draw.text(
            (text_x, text_y + 30), desc,
            fill=(150, 150, 150, 255), font=font_small, anchor="mt",
        )

    out_path = os.path.join(preview_dir, "creative_variants.png")
    sheet.save(out_path, 'PNG')
    print(f"\nSaved: {out_path}")


if __name__ == '__main__':
    main()
