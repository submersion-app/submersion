"""Build assets/fonts/submersion-equipment.ttf from tool/equipment_glyphs.py.

The dive-gear shapes in Submersion's equipment list -- wetsuit, drysuit, BCD,
rebreather, hood, gloves, bootie, reel, DPV, regulator -- exist in no icon
font, so they are drawn here and compiled into a small private font. Shipping
them as a font rather than as SVG or a painter keeps `equipmentTypeIcon`
returning `IconData`, so every call site keeps working and the glyphs inherit
IconTheme size, colour and directionality for free.

Run by hand whenever the glyph geometry changes, then commit the .ttf so no
contributor needs fonttools to build the app:

    pip install fonttools
    python3 tool/build_equipment_icon_font.py

Verify the result with --verify, which reads the glyphs back out of the font
it just wrote and reports their bounds.
"""

import argparse
import os
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.misc.transform import Transform
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.reverseContourPen import ReverseContourPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from equipment_glyphs import CODE_POINTS, GLYPHS  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "assets", "fonts", "submersion-equipment.ttf")

FAMILY = "Submersion Equipment"
VERSION = "1.000"
UPEM = 1000
GRID = 24
# Cubic-to-quadratic tolerance, in font units. This was half a grid unit, which
# is loose enough that the converted outline drifts away from the bounds
# measured on the source cubics: it left the gloves glyph a quarter of a unit
# off-centre after normalisation. One unit in 1000 keeps the approximation well
# inside rounding, and costs a handful of points in a 2.5 KB font.
MAX_ERR = 1.0

# Material's icon guidance keeps artwork inside a 20x20 live area on a 24x24
# grid, leaving a 2-unit margin so glyphs never touch the edge of their box.
# Every glyph is scaled to fill this in its larger dimension, which is what
# makes a set drawn by hand read as one set.
LIVE_AREA = 20.0

# Tolerances for --verify, in 24-grid units. Both are generous enough to absorb
# rounding into integer font units and the cubic-to-quadratic conversion, and
# tight enough to catch a glyph that was never normalised: the worst offender
# before normalisation existed sat 1.91 units high.
CENTRE_TOLERANCE = 0.10
SIZE_TOLERANCE = 0.10

# 2026-01-01T00:00:00Z expressed in the TrueType epoch, which starts at
# 1904-01-01 (Unix time plus 2082844800). Any fixed value works; what matters
# is that it never changes, so the build is reproducible.
FONT_EPOCH_STAMP = 1767225600 + 2082844800


def build_glyph(path_data):
    """Convert one 24-grid SVG path into a normalised TrueType glyph.

    Two transforms are applied, in this order.

    First, normalisation. Flutter's Icon widget centres the *em box*, never the
    ink, so a glyph drawn off to one side of the 24-grid renders off-centre in
    the app however the surrounding layout is written. Ten glyphs drawn
    independently had ten different centres and ranged from 16.4 to 22.0 units
    across, which read as icons that wander and jump size down a list. Each
    outline is therefore scaled to fill LIVE_AREA in its larger dimension and
    translated so its ink centre lands on the middle of the grid. Doing it here
    rather than by hand means the drawings in equipment_glyphs.py never have to
    care where they sit.

    Second, the move into font space. SVG is y-down and the font is y-up, so
    the transform flips Y and lands the icon box exactly on the em box: y=0
    maps to the ascender and y=24 to the baseline. Reversing the contours
    afterwards restores TrueType's convention of clockwise outer contours,
    which the Y flip would otherwise invert. Nonzero winding fills correctly
    either way, but matching the convention keeps font validators quiet.
    """
    outline = RecordingPen()
    parse_path(path_data, outline)

    bounds = BoundsPen(None)
    outline.replay(bounds)
    if bounds.bounds is None:
        raise ValueError("path produced no outline")
    x0, y0, x1, y1 = bounds.bounds
    scale = LIVE_AREA / max(x1 - x0, y1 - y0)

    normalise = (
        Transform()
        .translate(GRID / 2, GRID / 2)
        .scale(scale)
        .translate(-(x0 + x1) / 2, -(y0 + y1) / 2)
    )

    pen = TTGlyphPen(None)
    to_font_space = TransformPen(
        ReverseContourPen(Cu2QuPen(pen, MAX_ERR)),
        Transform(UPEM / GRID, 0, 0, -UPEM / GRID, 0, UPEM),
    )
    outline.replay(TransformPen(to_font_space, normalise))
    return pen.glyph()


def build():
    names = list(GLYPHS)
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder([".notdef"] + names)
    fb.setupCharacterMap({CODE_POINTS[name]: name for name in names})

    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    for name in names:
        glyphs[name] = build_glyph(GLYPHS[name]["d"])
    fb.setupGlyf(glyphs)

    # A full-em advance keeps every icon square, which is what Icon() assumes
    # when it sizes the glyph by font size.
    #
    # The left side bearing must equal the glyph's own xMin. Hardcoding it to 0
    # while the outlines start anywhere from 83 to 184 units in leaves the font
    # internally inconsistent, and consumers that honour the declared lsb shift
    # the outline by exactly (lsb - xMin) to reconcile the two. That displaced
    # every glyph left by up to 4.4 grid units while glyf's own bounds still
    # reported them perfectly centred, so the table said one thing and the
    # rendering did another.
    glyf = fb.font["glyf"]
    metrics = {}
    for name in glyphs:
        glyph = glyf[name]
        glyph.recalcBounds(glyf)
        metrics[name] = (UPEM, glyph.xMin if glyph.numberOfContours else 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=UPEM, descent=0)
    fb.setupNameTable(
        {
            "familyName": FAMILY,
            "styleName": "Regular",
            "uniqueFontIdentifier": f"{FAMILY} {VERSION}",
            "fullName": FAMILY,
            "psName": FAMILY.replace(" ", ""),
            "version": VERSION,
        }
    )
    fb.setupOS2(
        sTypoAscender=UPEM,
        sTypoDescender=0,
        sTypoLineGap=0,
        usWinAscent=UPEM,
        usWinDescent=0,
        achVendID="SUBM",
    )
    fb.setupPost(keepGlyphNames=False)

    # fontTools stamps head.created and head.modified with the current time, so
    # rebuilding unchanged geometry would still produce a byte-different file
    # and churn the committed binary. Pin both to a fixed date (seconds since
    # the 1904 font epoch) to keep the build reproducible: an unchanged rebuild
    # then leaves the .ttf untouched in git.
    head = fb.font["head"]
    head.created = head.modified = FONT_EPOCH_STAMP

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    fb.save(OUT)
    return names


def verify():
    """Read the glyphs back out of the font and report what actually landed.

    A code point that never made it into the cmap, or a path that collapsed to
    nothing, shows up here as a missing entry or an empty bounding box rather
    than as tofu on a device.
    """
    font = TTFont(OUT)
    cmap = font.getBestCmap()
    glyphset = font.getGlyphSet()
    problems = []

    for name in GLYPHS:
        cp = CODE_POINTS[name]
        # Glyph names are dropped from post to keep the font small, so the
        # reloaded font calls them uniXXXX. The cmap is what the app uses, so
        # that is what gets checked.
        mapped = cmap.get(cp)
        if mapped is None:
            problems.append(f"{name}: U+{cp:04X} is not in the cmap")
            continue
        rec = RecordingPen()
        glyphset[mapped].draw(rec)
        if not rec.value:
            problems.append(f"{name}: empty outline")
            continue

        # Measure the glyph as a consumer *draws* it, not only as glyf
        # tabulates it. These two disagree whenever hmtx lsb does not match
        # xMin, and that disagreement is invisible to a check that reads the
        # table alone: glyf reported dead-centre ink while every glyph drew up
        # to 4.4 grid units to the left.
        drawn = BoundsPen(None)
        rec.replay(drawn)
        advance, lsb = font["hmtx"][mapped]
        if lsb != font["glyf"][mapped].xMin:
            problems.append(
                f"{name}: hmtx lsb {lsb} does not match glyf xMin "
                f"{font['glyf'][mapped].xMin}; consumers that honour lsb will "
                f"shift the outline by {lsb - font['glyf'][mapped].xMin} units"
            )
        if advance != UPEM:
            problems.append(f"{name}: advance {advance} is not one em")
        # glyf's own bounds are the ink bounds. Measuring the drawn points
        # instead would flag off-curve control points, which legitimately sit
        # outside the shape they steer.
        glyph = font["glyf"][mapped]

        # Report in 24-grid units, which is what the drawings use, and measure
        # the ink centre against the middle of the box. Flutter centres the em
        # box rather than the ink, so this offset is exactly how far off-centre
        # the icon renders.
        k = GRID / UPEM
        dx0, dy0, dx1, dy1 = drawn.bounds
        cx = (dx0 + dx1) / 2 * k
        cy = (dy0 + dy1) / 2 * k
        dx, dy = cx - GRID / 2, cy - GRID / 2
        size = max(dx1 - dx0, dy1 - dy0) * k

        print(
            f"  {name:12s} U+{cp:04X}  "
            f"x {glyph.xMin:4d}..{glyph.xMax:4d}  y {glyph.yMin:4d}..{glyph.yMax:4d}  "
            f"size {size:5.2f}u  offset {dx:+5.2f},{dy:+5.2f}  "
            f"{glyph.numberOfContours} contours"
        )

        if glyph.xMin < 0 or glyph.xMax > UPEM or glyph.yMin < 0 or glyph.yMax > UPEM:
            problems.append(
                f"{name}: ink escapes the em box "
                f"(x {glyph.xMin}..{glyph.xMax}, y {glyph.yMin}..{glyph.yMax}); "
                f"it would be clipped on device"
            )
        if abs(dx) > CENTRE_TOLERANCE or abs(dy) > CENTRE_TOLERANCE:
            problems.append(
                f"{name}: ink is off-centre by {dx:+.2f},{dy:+.2f} grid units; "
                f"it would render off-centre in the app"
            )
        if abs(size - LIVE_AREA) > SIZE_TOLERANCE:
            problems.append(
                f"{name}: fills {size:.2f} units rather than {LIVE_AREA:.0f}; "
                f"it would look a different size from the rest of the set"
            )

    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--verify", action="store_true", help="read the font back and check it")
    args = ap.parse_args()

    names = build()
    size = os.path.getsize(OUT)
    print(f"wrote {OUT} ({size} bytes, {len(names)} glyphs)")

    if args.verify:
        print("verifying:")
        problems = verify()
        if problems:
            for p in problems:
                print(f"FAIL {p}", file=sys.stderr)
            return 1
        print("all glyphs present and inside the em box")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
