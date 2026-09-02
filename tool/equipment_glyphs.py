"""Source of truth for the custom Submersion equipment glyphs.

Each glyph is composed on a 24x24 grid. TrueType fills with the nonzero winding
rule, so solid contours are wound clockwise and holes counter-clockwise. That
way the same path data renders identically in an SVG preview and in the
generated font.

Polygon winding is normalised by signed area rather than trusted from the
point order: a thick segment's offset points flip direction with the segment's
own direction, so a hand-ordered quad unions for a hose running right but
subtracts for one running left.
"""

import json
import math
import sys


def n(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def circle(cx, cy, r, solid=True):
    s = 1 if solid else 0
    return (
        f"M{n(cx - r)} {n(cy)}"
        f"A{n(r)} {n(r)} 0 1 {s} {n(cx + r)} {n(cy)}"
        f"A{n(r)} {n(r)} 0 1 {s} {n(cx - r)} {n(cy)}Z"
    )


def ellipse(cx, cy, rx, ry, solid=True):
    s = 1 if solid else 0
    return (
        f"M{n(cx - rx)} {n(cy)}"
        f"A{n(rx)} {n(ry)} 0 1 {s} {n(cx + rx)} {n(cy)}"
        f"A{n(rx)} {n(ry)} 0 1 {s} {n(cx - rx)} {n(cy)}Z"
    )


def rrect(x, y, w, h, r, solid=True):
    r = min(r, w / 2, h / 2)
    if solid:
        return (
            f"M{n(x + r)} {n(y)}H{n(x + w - r)}A{n(r)} {n(r)} 0 0 1 {n(x + w)} {n(y + r)}"
            f"V{n(y + h - r)}A{n(r)} {n(r)} 0 0 1 {n(x + w - r)} {n(y + h)}"
            f"H{n(x + r)}A{n(r)} {n(r)} 0 0 1 {n(x)} {n(y + h - r)}"
            f"V{n(y + r)}A{n(r)} {n(r)} 0 0 1 {n(x + r)} {n(y)}Z"
        )
    return (
        f"M{n(x + r)} {n(y)}A{n(r)} {n(r)} 0 0 0 {n(x)} {n(y + r)}"
        f"V{n(y + h - r)}A{n(r)} {n(r)} 0 0 0 {n(x + r)} {n(y + h)}"
        f"H{n(x + w - r)}A{n(r)} {n(r)} 0 0 0 {n(x + w)} {n(y + h - r)}"
        f"V{n(y + r)}A{n(r)} {n(r)} 0 0 0 {n(x + w - r)} {n(y)}Z"
    )


def poly(points, solid=True):
    pts = list(points)
    # Screen coords are y-down, so a positive shoelace area means clockwise.
    area = sum(
        pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
        for i in range(len(pts))
    )
    clockwise = area > 0
    if clockwise != solid:
        pts.reverse()
    head = f"M{n(pts[0][0])} {n(pts[0][1])}"
    return head + "".join(f"L{n(px)} {n(py)}" for px, py in pts[1:]) + "Z"


def bar(p1, p2, w, solid=True):
    """Thick segment with round caps: a quad plus a circle at each end. Under
    nonzero these union into a capsule."""
    (x1, y1), (x2, y2) = p1, p2
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy) or 1e-6
    ox, oy = -dy / length * w / 2, dx / length * w / 2
    quad = poly(
        [(x1 + ox, y1 + oy), (x2 + ox, y2 + oy), (x2 - ox, y2 - oy), (x1 - ox, y1 - oy)],
        solid,
    )
    return quad + circle(x1, y1, w / 2, solid) + circle(x2, y2, w / 2, solid)


def g(*parts):
    return "".join(parts)


GLYPHS = {}


def add(key, label, note, d):
    GLYPHS[key] = {"label": label, "note": note, "d": d}


# --- Hand-drawn outlines that already survived the 20px test ----------------
# These three read correctly in the first pass, so they keep their original
# single-outline form rather than being rebuilt from primitives.

WETSUIT_BODY = (
    "M9.1 2.6c.6.9 1.6 1.4 2.9 1.4s2.3-.5 2.9-1.4c1.6.2 2.9.8 3.7 1.7l2.2 4.1"
    "c.35.65.1 1.45-.55 1.8l-1.4.75L17.3 8.1v4.4l.7 8.6a.9.9 0 0 1-.9.97h-2.5"
    "a.9.9 0 0 1-.9-.83L13 13.9h-2l-.7 7.34a.9.9 0 0 1-.9.83H6.9a.9.9 0 0 1-.9-.97"
    "l.7-8.6V8.1L5.15 11.05l-1.4-.75a1.35 1.35 0 0 1-.55-1.8l2.2-4.1"
    "c.8-.9 2.1-1.5 3.7-1.7Z"
)

add(
    "wetsuit",
    "Wetsuit",
    "One-piece suit, open neck, plain ankle cuffs.",
    WETSUIT_BODY,
)

add(
    "gloves",
    "Gloves",
    "Four fingers and a thumb above a sealed wrist cuff.",
    "M8.6 3.4a1.3 1.3 0 0 1 1.3 1.3v5.5h.8V3.1a1.3 1.3 0 0 1 2.6 0v7.1h.8V4.4"
    "a1.3 1.3 0 0 1 2.6 0v5.8h.8V7.6a1.25 1.25 0 0 1 2.5 0v6.9c0 1.6-.45 3-1.25 4.2"
    "H6.9c-.5-.6-.9-1.2-1.25-1.85L3.9 13.6a1.4 1.4 0 0 1 .55-1.9 1.5 1.5 0 0 1 1.95.5"
    "l.9 1.5V4.7a1.3 1.3 0 0 1 1.3-1.3ZM6.9 19.5h11.05c-.35.45-.75.85-1.2 1.2v1.1H8.1"
    "v-1.1c-.45-.35-.85-.75-1.2-1.2Z",
)

add(
    "boots",
    "Boots",
    "Dive bootie with an angled sole and a heel.",
    "M6 2.6h5.1a1.5 1.5 0 0 1 1.49 1.29l.86 6.1c.16 1.13.87 2.11 1.9 2.62l3.86 1.9"
    "A2.9 2.9 0 0 1 20.8 17.1v1.4a1.6 1.6 0 0 1-1.6 1.6H6a1.6 1.6 0 0 1-1.6-1.6V4.2"
    "A1.6 1.6 0 0 1 6 2.6Zm-1.6 15.1h16.4v.8a1.6 1.6 0 0 1-1.6 1.6H6a1.6 1.6 0 0 1-1.6-1.6Z",
)

# --- Rebuilt from primitives ------------------------------------------------

add(
    "drysuit",
    "Drysuit",
    "Same suit family as the wetsuit, told apart by its attached hood and boots.",
    g(
        circle(12.0, 3.0, 2.7),                        # attached hood
        WETSUIT_BODY,
        rrect(3.9, 19.3, 6.9, 3.0, 1.3),              # left attached boot
        rrect(13.2, 19.3, 6.9, 3.0, 1.3),             # right attached boot
        circle(12.0, 3.0, 1.35, solid=False),         # face opening
    ),
)

add(
    "regulator",
    "Regulator",
    "Second stage side-on: purge face, mouthpiece bit, exhaust cover, LP hose.",
    g(
        rrect(4.6, 6.8, 10.4, 9.0, 3.2),              # second stage body
        rrect(0.9, 9.9, 4.4, 3.0, 1.1),               # mouthpiece bit
        rrect(7.4, 15.2, 5.2, 3.6, 1.3),              # exhaust cover
        bar((14.6, 9.4), (19.5, 6.6), 2.4),           # hose run
        bar((19.5, 6.6), (19.5, 2.6), 2.4),           # hose riser
        circle(9.8, 11.3, 2.3, solid=False),          # purge cover
    ),
)

# A circle sitting on top of a box reads as a head, which turned the first
# attempts at these two into little robots. Both now keep their mass low and
# wide and carry their meaning in cut-outs rather than in a crowning shape.
# The sloped shoulders are cut into the outline itself rather than subtracted
# afterwards: a hole that runs outside the shape it cuts lands on winding -1,
# which nonzero fills instead of clearing.
add(
    "bcd",
    "BCD",
    "Buoyancy vest: sloped shoulders, front opening, waist belt, inflator hose.",
    g(
        poly(
            [
                (8.6, 3.8),
                (15.4, 3.8),
                (19.8, 7.8),
                (19.8, 18.8),
                (4.2, 18.8),
                (4.2, 7.8),
            ]
        ),                                             # vest outline
        bar((6.4, 6.0), (3.0, 2.6), 1.9),             # inflator hose
        rrect(3.4, 13.2, 17.2, 2.9, 1.0),             # waist belt
        poly([(10.1, 3.8), (13.9, 3.8), (12.0, 8.2)], solid=False),  # neck V
        rrect(11.4, 7.8, 1.2, 10.6, 0.4, solid=False),  # front opening
    ),
)

# Hoses drawn out to the sides read as arms, so the loop is implied by the
# pod layout instead: three vertical masses under one lid.
add(
    "rebreather",
    "Rebreather (CCR)",
    "Scrubber canister flanked by two counterlungs beneath the head unit.",
    g(
        rrect(9.6, 6.4, 4.8, 13.8, 2.2),              # scrubber canister
        rrect(3.9, 8.8, 4.6, 9.2, 2.2),               # left counterlung
        rrect(15.5, 8.8, 4.6, 9.2, 2.2),              # right counterlung
        rrect(7.8, 3.8, 8.4, 3.0, 1.2),               # head unit
    ),
)

# The face opening has to run clean off the bottom edge or the leftover white
# stays enclosed and the whole thing reads as a padlock. Square the lower
# corners and overshoot the viewbox.
add(
    "hood",
    "Hood",
    "Hood seen front-on, its face opening running out through the neck.",
    g(
        circle(12.0, 10.0, 7.2),                       # crown
        rrect(4.8, 10.0, 14.4, 11.8, 2.4),            # neck and shoulders
        rrect(8.6, 5.8, 6.8, 8.0, 3.4, solid=False),   # rounded top of opening
        poly(
            [(8.6, 9.4), (15.4, 9.4), (15.4, 21.8), (8.6, 21.8)],
            solid=False,
        ),                                             # opening runs out to the hem
    ),
)

add(
    "reel",
    "Reel",
    "Finger spool: hub, line slot, and line paying out.",
    g(
        circle(10.8, 10.8, 7.2),                       # side plate
        bar((10.8, 17.4), (10.8, 21.6), 1.4),         # line paying out
        bar((10.8, 21.6), (15.6, 21.6), 1.4),
        circle(10.8, 10.8, 2.7, solid=False),         # hub
        poly(
            [(10.15, 3.6), (11.45, 3.6), (11.45, 8.6), (10.15, 8.6)],
            solid=False,
        ),                                             # line slot
    ),
)

add(
    "dpv",
    "DPV / Scooter",
    "Torpedo hull with a shrouded prop and a top handle.",
    g(
        bar((7.2, 13.4), (13.4, 13.4), 8.4),          # hull
        rrect(15.0, 8.8, 2.2, 9.2, 0.8),              # shroud
        poly([(17.2, 9.8), (21.6, 13.4), (17.2, 17.0)]),  # prop cone
        rrect(7.0, 4.0, 6.6, 2.4, 1.0),               # handle bar
        bar((8.8, 5.8), (8.8, 9.2), 1.8),             # left stem
        bar((11.8, 5.8), (11.8, 9.2), 1.8),           # right stem
    ),
)


# Private Use Area code points, assigned in declaration order and never
# renumbered: they are baked into the committed font and into
# lib/core/icons/submersion_icons.dart.
FIRST_CODE_POINT = 0xE900

CODE_POINTS = {
    name: FIRST_CODE_POINT + i for i, name in enumerate(GLYPHS)
}


if __name__ == "__main__":
    payload = {
        name: {**spec, "codePoint": CODE_POINTS[name]}
        for name, spec in GLYPHS.items()
    }
    json.dump(payload, sys.stdout, indent=2)
