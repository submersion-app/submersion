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


# Drysuit layers. Both hang off the same wardrobe idea as the suits above but
# must never be mistaken for them at 20px, so each carries a shape the suits
# do not: the undersuit its quilting, the base layer its short body and
# straight sleeves.
add(
    "undersuit",
    "Undersuit",
    "The suit silhouette again, quilted: a drysuit undersuit is worn inside one.",
    g(
        WETSUIT_BODY,
        rrect(7.6, 5.8, 8.8, 1.2, 0.6, solid=False),  # quilting seam
        rrect(7.6, 8.6, 8.8, 1.2, 0.6, solid=False),
        rrect(7.6, 11.4, 8.8, 1.2, 0.6, solid=False),
    ),
)

add(
    "baselayer",
    "Base layer",
    "Long-sleeved thermal top: a garment, not a suit, so it stops at the hips.",
    poly(
        [
            (8.4, 4.2),                                # left shoulder
            (10.3, 4.2),
            (12.0, 6.3),                               # crew neck
            (13.7, 4.2),
            (15.6, 4.2),                               # right shoulder
            (21.2, 6.6),                               # right sleeve, top
            (21.2, 11.4),                              # right cuff
            (16.6, 9.8),                               # right armpit
            (16.6, 20.2),                              # right hem
            (7.4, 20.2),                               # left hem
            (7.4, 9.8),                                # left armpit
            (2.8, 11.4),                               # left cuff
            (2.8, 6.6),                                # left sleeve, top
        ]
    ),
)

# BCD rig parts (issue #1877). A band on its own is a ring, which the wing's
# donut already means, so the tank band is shown doing its job: clamped
# around a cylinder, with the cam buckle standing proud on the side. The
# cylinder is two separate pieces above and below the band rather than one
# body with the band cut out of it, so the gap never depends on a hole.
add(
    "tank_band",
    "Tank Band",
    "A cylinder with a band clamped around it and a cam buckle on the side.",
    g(
        "M6 8.2V5.6A4.4 3 0 0 1 14.8 5.6V8.2Z",       # cylinder shoulder
        rrect(9.2, 1.0, 2.4, 2.6, 0.6),               # valve
        rrect(6.0, 15.8, 8.8, 6.6, 1.4),              # cylinder below the band
        rrect(4.4, 9.2, 12.8, 5.6, 1.2),              # band
        rrect(15.6, 8.2, 5.2, 7.6, 1.4),              # cam buckle
        rrect(17.2, 10.0, 2.0, 4.0, 0.6, solid=False),  # buckle slot
    ),
)

# At 20px the two pockets are told apart by their details. The weight
# pocket's cues are its pull handle and the lead block inside it; the gear
# pocket's are its pointed flap and snap.
add(
    "weight_pocket",
    "Weight Pocket",
    "Pouch with a quick-release pull handle and a lead block inside.",
    g(
        rrect(9.0, 1.6, 6.0, 5.4, 2.4),               # pull handle
        rrect(4.2, 6.4, 15.6, 4.2, 1.4),              # flap
        rrect(5.0, 11.4, 14.0, 10.8, 2.4),            # pouch body
        rrect(10.6, 3.0, 2.8, 2.6, 1.2, solid=False),  # handle opening
        poly(
            [(9.8, 13.6), (14.2, 13.6), (15.6, 19.8), (8.4, 19.8)],
            solid=False,
        ),                                             # lead block
    ),
)

# A zip across a plain box, and mounting loops above it, both read as a
# calendar. The pointed flap is what says pocket; the pouch's top edge runs
# parallel to it so the gap between them survives at 20px.
add(
    "gear_pocket",
    "Gear Pocket",
    "Pouch under a pointed flap held down by a snap.",
    g(
        poly(
            [(4.0, 3.0), (20.0, 3.0), (20.0, 8.4), (12.0, 11.2), (4.0, 8.4)]
        ),                                             # flap
        poly(
            [(4.8, 9.6), (12.0, 12.2), (19.2, 9.6), (19.2, 17.0), (4.8, 17.0)]
        ),                                             # pouch, top edge
        rrect(4.8, 14.0, 14.4, 7.6, 2.4),             # pouch, rounded base
        circle(12.0, 7.6, 1.2, solid=False),          # snap
    ),
)

# Camera parts (issue #1997). Each is drawn doing its job, because the bare
# parts are generic shapes: a lens is a barrel with grip ribs and a flared
# front, a port is a dome on its collar, an arm shows the ball clamp that
# joins two segments, and a float is the same arm drawn fat. A hole only
# cancels one layer of winding, so every hole here sits on a single solid
# contour: the clamp and the float body are one-contour capsules rather than
# bar()'s quad-plus-circles, whose overlaps a hole cannot clear.
def capsule(p1, p2, w, steps=10):
    """A thick segment with round caps as one solid contour."""
    (x1, y1), (x2, y2) = p1, p2
    a = math.atan2(y2 - y1, x2 - x1)
    r = w / 2
    pts = []
    for cx, cy, start in ((x2, y2, a - math.pi / 2), (x1, y1, a + math.pi / 2)):
        for i in range(steps + 1):
            t = start + math.pi * i / steps
            pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    return poly(pts)


def slot(p1, p2, w):
    """A capless rectangular hole along p1-p2."""
    (x1, y1), (x2, y2) = p1, p2
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy) or 1e-6
    ox, oy = -dy / length * w / 2, dx / length * w / 2
    return poly(
        [(x1 + ox, y1 + oy), (x2 + ox, y2 + oy), (x2 - ox, y2 - oy), (x1 - ox, y1 - oy)],
        solid=False,
    )


add(
    "lens",
    "Lens",
    "A lens barrel seen side-on: mount, ribbed grip and a flared front.",
    g(
        rrect(2.0, 8.0, 3.6, 8.0, 0.6),               # mount
        rrect(5.0, 5.0, 10.6, 14.0, 1.2),             # barrel
        poly([(15.0, 5.0), (21.6, 2.4), (21.6, 21.6), (15.0, 19.0)]),  # front
        rrect(7.0, 7.0, 1.2, 10.0, 0.4, solid=False),  # grip rib
        rrect(9.7, 7.0, 1.2, 10.0, 0.4, solid=False),  # grip rib
        rrect(12.4, 7.0, 1.2, 10.0, 0.4, solid=False),  # grip rib
    ),
)

add(
    "port",
    "Port",
    "A dome port seen side-on: a half-dome on its mounting collar.",
    g(
        rrect(2.6, 4.0, 6.0, 16.0, 1.0),              # collar
        "M8 3A9 9 0 0 1 8 21Z",                       # dome
        rrect(4.6, 6.0, 1.2, 12.0, 0.4, solid=False),  # collar groove
        poly(
            [(11.4, 7.0), (13.4, 6.4), (15.4, 9.6), (14.0, 10.6)],
            solid=False,
        ),                                             # glint on the dome
    ),
)

add(
    "tray_handle",
    "Tray / Handle",
    "A camera tray with a handle rising at each end and a camera on it.",
    g(
        rrect(2.0, 16.4, 20.0, 3.6, 1.2),             # tray
        rrect(2.0, 3.0, 3.8, 17.0, 1.8),              # left handle
        rrect(18.2, 3.0, 3.8, 17.0, 1.8),             # right handle
        rrect(7.8, 8.4, 8.4, 6.6, 1.2),               # camera
        circle(12.0, 11.7, 1.8, solid=False),         # its lens
    ),
)

add(
    "arm_clamp",
    "Arm / Clamp",
    "Two arm segments with ball ends, joined by a ball clamp with its knob.",
    g(
        bar((4.6, 19.4), (10.0, 14.0), 2.4),          # lower segment
        circle(4.6, 19.4, 2.3),                       # ball end
        bar((14.0, 10.0), (19.4, 4.6), 2.4),          # upper segment
        circle(19.4, 4.6, 2.3),                       # ball end
        capsule((9.4, 14.6), (14.6, 9.4), 5.6),       # clamp
        bar((12.0, 12.0), (16.4, 16.4), 1.8),         # knob screw
        circle(17.4, 17.4, 2.2),                      # knob
    ),
)

add(
    "video_light",
    "Video Light",
    "A video light seen front-on: a square head round a wide LED, on a ball mount.",
    g(
        rrect(3.4, 1.6, 17.2, 15.2, 3.0),             # head
        circle(12.0, 9.2, 5.0, solid=False),          # bezel
        circle(12.0, 9.2, 3.0),                       # LED
        rrect(10.4, 16.0, 3.2, 3.4, 0.6),             # stem
        circle(12.0, 20.4, 2.4),                      # ball mount
    ),
)

add(
    "float_arm",
    "Float Arm / Float",
    "A fat foam float with a ball at each end, banded across.",
    g(
        bar((3.6, 20.4), (6.8, 17.2), 2.0),           # lower stub
        circle(3.6, 20.4, 2.3),                       # ball end
        bar((17.2, 6.8), (20.4, 3.6), 2.0),           # upper stub
        circle(20.4, 3.6, 2.3),                       # ball end
        capsule((8.0, 16.0), (16.0, 8.0), 8.4),       # foam body
        slot((7.4, 11.4), (12.6, 16.6), 1.0),         # band
        slot((11.4, 7.4), (16.6, 12.6), 1.0),         # band
    ),
)

# The vest (#3108): the hooded ice vest worn over a wetsuit, or a core warmer
# under one. It joins the wardrobe family without reading as a suit or a top
# at 20px: no sleeves (the armholes cut in from the shoulders), a hood like
# the drysuit's with its face opening, and a front zip. The zip and the face
# opening each sit inside a single solid, so nonzero winding cuts them clean.
add(
    "vest",
    "Vest",
    "Sleeveless vest with an attached hood and a front zip.",
    g(
        circle(12.0, 5.6, 3.6),                        # attached hood
        poly(
            [
                (8.8, 8.2),                            # left neck
                (15.2, 8.2),                           # right neck
                (19.2, 9.8),                           # right shoulder
                (19.2, 10.8),
                (17.0, 14.6),                          # right armpit
                (17.0, 21.8),                          # right hem
                (7.0, 21.8),                           # left hem
                (7.0, 14.6),                           # left armpit
                (4.8, 10.8),
                (4.8, 9.8),                            # left shoulder
            ]
        ),
        circle(12.0, 5.6, 1.8, solid=False),           # face opening
        rrect(11.4, 10.2, 1.2, 10.4, 0.6, solid=False),  # front zip
    ),
)

add(
    "socks",
    "Socks",
    "A sock seen side-on: a ribbed cuff over the leg, turning into a rounded foot.",
    g(
        rrect(5.2, 2.0, 7.6, 3.0, 1.0),               # ribbed cuff
        rrect(5.2, 6.0, 7.6, 11.0, 1.0),              # leg
        capsule((9.0, 17.0), (18.6, 17.0), 7.6),      # foot, heel to toe
        slot((15.4, 13.6), (15.4, 20.4), 0.9),        # toe seam
    ),
)

# Tank roles (#2901). One glyph per way a cylinder is carried, so a diver can
# read a dive's configuration from the icons alone: back-mounted, sidemount
# left and right, slung (stage, deco, bailout), a pony beside the main tank,
# and a rebreather's onboard cylinder (diluent, O2 supply). A domed shoulder
# capped on top reads as a bottle, so the shoulders are flattened and the
# valve's handwheel stands edge-on to one side. The cylinders are built as
# point lists rather than from rrect() so the stage can be tilted as a whole.
def _arc_pts(cx, cy, rx, ry, a0, a1, steps):
    return [
        (cx + rx * math.cos(a0 + (a1 - a0) * i / steps),
         cy + ry * math.sin(a0 + (a1 - a0) * i / steps))
        for i in range(steps + 1)
    ]


def _cylinder_pts(x, y, w, h):
    """A cylinder whose shoulder top sits at y: flattened dome, rounded base."""
    dome = w * 0.3
    r = min(1.3, w * 0.18)
    return (
        _arc_pts(x + w / 2, y + dome, w / 2, dome, math.pi, 2 * math.pi, 10)
        + _arc_pts(x + w - r, y + h - r, r, r, 0, math.pi / 2, 4)
        + _arc_pts(x + r, y + h - r, r, r, math.pi / 2, math.pi, 4)
    )


def _rrect_pts(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return (
        _arc_pts(x + w - r, y + r, r, r, -math.pi / 2, 0, 3)
        + _arc_pts(x + w - r, y + h - r, r, r, 0, math.pi / 2, 3)
        + _arc_pts(x + r, y + h - r, r, r, math.pi / 2, math.pi, 3)
        + _arc_pts(x + r, y + r, r, r, math.pi, 1.5 * math.pi, 3)
    )


def _valve_pts(cx, y, s, knob):
    """Neck, valve body, stem and edge-on handwheel on a cylinder whose
    shoulder top is y. knob is -1 for a handwheel on the left, +1 right."""
    stem_x = cx + knob * 1.6 * s
    wheel_x = cx + knob * 3.2 * s
    return [
        _rrect_pts(cx - 1.0 * s, y - 1.6 * s, 2.0 * s, 2.0 * s, 0.3 * s),
        _rrect_pts(cx - 1.7 * s, y - 3.6 * s, 3.4 * s, 2.3 * s, 0.6 * s),
        _rrect_pts(min(stem_x, stem_x + knob * 1.6 * s), y - 3.4 * s,
                   1.6 * s, 1.9 * s, 0.4 * s),
        _rrect_pts(wheel_x - 0.7 * s, y - 4.6 * s, 1.4 * s, 4.3 * s, 0.6 * s),
    ]


def _tank_pts(x, y, w, h, s=1.0, knob=-1):
    return [_cylinder_pts(x, y, w, h)] + _valve_pts(x + w / 2, y, s, knob)


def _rotated(pts, degrees, cx, cy):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return [
        (cx + (px - cx) * c - (py - cy) * s, cy + (px - cx) * s + (py - cy) * c)
        for px, py in pts
    ]


def _polys(point_lists):
    return "".join(poly(pts) for pts in point_lists)


add(
    "tank_back_gas",
    "Back Gas",
    "An upright cylinder with its valve and handwheel.",
    _polys(_tank_pts(6.6, 6.4, 10.8, 16.2)),
)

# Sidemount is an equal pair; the side the cylinder is on is drawn solid and
# the other hollow. The hollow sits inside a single solid contour so nonzero
# winding cuts it clean.
SIDEMOUNT_W, SIDEMOUNT_H, SIDEMOUNT_Y = 7.8, 14.4, 8.0


def _sidemount(solid_left):
    left_x, right_x = 2.4, 13.8
    hollow_x = right_x if solid_left else left_x
    st = 1.5
    return g(
        _polys(_tank_pts(left_x, SIDEMOUNT_Y, SIDEMOUNT_W, SIDEMOUNT_H, 0.8, -1)),
        _polys(_tank_pts(right_x, SIDEMOUNT_Y, SIDEMOUNT_W, SIDEMOUNT_H, 0.8, 1)),
        poly(
            _cylinder_pts(hollow_x + st, SIDEMOUNT_Y + st,
                          SIDEMOUNT_W - 2 * st, SIDEMOUNT_H - 2 * st),
            solid=False,
        ),
    )


add(
    "tank_sidemount_left",
    "Sidemount Left",
    "A pair of cylinders, the left one solid.",
    _sidemount(solid_left=True),
)

add(
    "tank_sidemount_right",
    "Sidemount Right",
    "A pair of cylinders, the right one solid.",
    _sidemount(solid_left=False),
)

# A leash standing off from the cylinder reads as a tank beside a wrench, so
# it runs close along the side with a clamp at the neck and at the base, and
# the whole rig is tilted the way a slung cylinder hangs.
def _slung():
    tilt, cx, cy = 26, 12.4, 12.6
    leash_x = 6.6
    turn = lambda pt: _rotated([pt], tilt, cx, cy)[0]
    parts = _tank_pts(8.6, 6.4, 8.4, 14.6, 0.9, 1)
    parts += [
        _rrect_pts(leash_x, 8.6, 2.6, 1.3, 0.3),      # neck clamp
        _rrect_pts(leash_x, 17.6, 2.6, 1.3, 0.3),     # base clamp
    ]
    out = _polys(_rotated(p, tilt, cx, cy) for p in parts)
    out += bar(turn((leash_x, 5.4)), turn((leash_x, 20.2)), 1.2)  # leash
    for end in (turn((leash_x, 3.6)), turn((leash_x, 21.8))):
        out += circle(end[0], end[1], 1.8)            # bolt snap
        out += circle(end[0], end[1], 0.8, solid=False)
    return out


add(
    "tank_slung",
    "Stage / Deco / Bailout",
    "A tilted cylinder on a leash clamped at neck and base, a bolt snap at each end.",
    _slung(),
)

add(
    "tank_pony",
    "Pony Bottle",
    "A short bottle strapped beside a full-size cylinder.",
    g(
        _polys(_tank_pts(2.4, 6.4, 10.2, 16.2, 1.0, -1)),
        _polys(_tank_pts(14.8, 13.0, 6.8, 9.6, 0.7, 1)),
        rrect(11.8, 15.0, 3.8, 1.5, 0.4),             # strap
        rrect(11.8, 19.0, 3.8, 1.5, 0.4),             # strap
    ),
)

# A cylinder on its own carries no hint of a loop, and one hung valve-down
# under a lid read as a bin. Beside the scrubber canister (rounded like the
# rebreather glyph's pods) it reads as the unit's own small cylinder.
add(
    "tank_rebreather",
    "Diluent / O2 Supply",
    "A stubby cylinder beside a rebreather's scrubber canister and head.",
    g(
        _polys(_tank_pts(2.6, 9.4, 9.4, 13.2, 0.9, -1)),
        rrect(14.2, 6.4, 6.8, 16.2, 3.0),             # scrubber canister
        rrect(13.0, 3.0, 9.2, 2.8, 1.0),              # head unit
    ),
)

# --- Regulator stages -------------------------------------------------------


def din_thread(x0, x1, cy, root, crest, teeth):
    """Male DIN thread in profile, top and bottom edges cut into teeth."""
    pitch = (x1 - x0) / teeth
    top, bottom = [], []
    for i in range(teeth):
        a = x0 + i * pitch
        top += [(a, cy - root), (a + pitch * 0.5, cy - crest)]
        bottom += [(a, cy + root), (a + pitch * 0.5, cy + crest)]
    top.append((x1, cy - root))
    bottom.append((x1, cy + root))
    return poly(top + bottom[::-1])


def knurled_wheel(x, y, w, h, grooves):
    """Handwheel edge-on, its knurl drawn as grooves across the rim."""
    parts = [rrect(x, y, w, h, 0.9)]
    for i in range(1, grooves + 1):
        gy = y + h * i / (grooves + 1)
        parts.append(slot((x + 0.6, gy), (x + w - 0.6, gy), 0.75))
    return g(*parts)


# Holes cut one winding layer, so each rib and ring sits on a single contour.
add(
    "first_stage",
    "First Stage",
    "DIN first stage side-on: thread, knurled wheel, a body with a ribbed "
    "collar under its cap, a big and a small port, a side boss and a turret.",
    g(
        rrect(0.4, 10.6, 1.4, 2.8, 0.5),                     # O-ring nose
        din_thread(1.4, 4.6, 12.0, 2.0, 2.9, 3),             # DIN thread
        knurled_wheel(4.4, 4.69, 3.4, 14.62, 3),             # handwheel
        rrect(7.6, 9.6, 1.4, 5.6, 0.2),                      # neck under the wheel
        rrect(9.1, 3.4, 9.8, 3.0, 1.2),                      # environmental cap
        rrect(10.1, 6.2, 7.8, 2.7, 0.3),                     # collar
        slot((11.66, 6.7), (11.66, 8.4), 0.8),               # collar ribs
        slot((14.0, 6.7), (14.0, 8.4), 0.8),
        slot((16.34, 6.7), (16.34, 8.4), 0.8),
        rrect(8.8, 8.7, 10.4, 10.3, 1.6),                    # body
        circle(14.4, 13.6, 2.0, solid=False),                # big port
        circle(17.4, 17.0, 0.8, solid=False),                # small port
        rrect(18.8, 12.0, 1.3, 3.4, 0.5),                    # side port boss
        rrect(10.5, 18.8, 7.0, 3.6, 1.6),                    # turret
        slot((11.0, 20.6), (17.0, 20.6), 0.75),              # turret ring
    ),
)


def dashed_ring(cx, cy, r, count, length, w):
    """Straight dashes cut round a circle, each a chord of the given length."""
    half = length / 2 / r
    dashes = []
    for i in range(count):
        a = 2 * math.pi * i / count
        p1 = (cx + r * math.cos(a - half), cy + r * math.sin(a - half))
        p2 = (cx + r * math.cos(a + half), cy + r * math.sin(a + half))
        dashes.append(slot(p1, p2, w))
    return g(*dashes)


# Parts attached to the body overlap only its outer band, so the gap inside
# it cuts cleanly.
add(
    "second_stage",
    "Second Stage",
    "Second stage face-on: the body and its purge cover with six dashes and a "
    "centre button, the mouthpiece on top, the hose fitting and the knob.",
    g(
        rrect(7.2, 1.8, 9.6, 3.0, 1.3),                      # mouthpiece bite block
        poly([(8.2, 4.0), (15.8, 4.0), (14.6, 6.2), (9.4, 6.2)]),  # flare to the body
        rrect(0.6, 11.6, 2.8, 3.2, 0.5),                     # hose end
        rrect(2.8, 10.4, 2.3, 5.6, 0.5),                     # hose fitting collar
        rrect(19.0, 9.4, 2.6, 6.4, 1.0),                     # adjustment knob
        circle(12.0, 13.2, 8.0),                             # body
        circle(12.0, 13.2, 6.6, solid=False),                # gap round the cover
        circle(12.0, 13.2, 5.5),                             # purge cover
        dashed_ring(12.0, 13.2, 3.9, 6, 1.8, 0.85),          # cover ribs
        circle(12.0, 13.2, 2.2, solid=False),                # button surround
        circle(12.0, 13.2, 1.3),                             # purge button
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
