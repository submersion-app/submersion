#!/usr/bin/env python3
"""Compile the diver figure artwork into Dart.

Sources: tool/figure/manifest.json and one SVG per piece at tool/figure/<id>.svg,
drawn in the shared 200 by 400 figure space (y down).
Output:  lib/features/equipment/figure/artwork/figure_artwork.gen.dart

    python3 tool/build_figure_artwork.py            # write the Dart file
    python3 tool/build_figure_artwork.py --verify   # check the sources and that the Dart file is current

Accepted SVG subset: <path d>, <rect> (x y width height, optional rx ry),
<circle>, <ellipse>, nested in any <g>. A transform attribute anywhere, or a
gradient, filter, text, use, image, pattern, mask, clipPath or style element,
is rejected by name. Shapes map in document order to the manifest's roles.

Bounds are checked conservatively: for an arc both endpoints plus the arc's
radii around them count, so a rounded rectangle needs its rx of margin from
the figure edge. Use straight edges for shapes that touch the edge.
"""
import argparse
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tool" / "figure"
OUT = ROOT / "lib" / "features" / "equipment" / "figure" / "artwork" / "figure_artwork.gen.dart"
WIDTH, HEIGHT = 200.0, 400.0
ROLES = ["body", "bodyShade", "gearDark", "gearLight", "metal", "itemColor", "itemShade", "outline"]
VIEWS = ["front", "back"]
CONTAINERS = {"svg", "g", "title", "desc", "defs"}
REJECTED = {"linearGradient", "radialGradient", "filter", "text", "use", "image", "pattern", "mask", "clipPath", "style"}
TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
ARGS = {"M": 2, "L": 2, "T": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "A": 7, "Z": 0}


class FigureError(Exception):
    pass


def n(v):
    s = "{:.2f}".format(v).rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def local(tag):
    return tag.split("}")[-1]


def ellipse_path(cx, cy, rx, ry):
    return "M{} {}A{} {} 0 1 1 {} {}A{} {} 0 1 1 {} {}Z".format(
        n(cx - rx), n(cy), n(rx), n(ry), n(cx + rx), n(cy), n(rx), n(ry), n(cx - rx), n(cy)
    )


def rect_path(x, y, w, h, rx, ry):
    if rx <= 0 and ry <= 0:
        return "M{} {}H{}V{}H{}Z".format(n(x), n(y), n(x + w), n(y + h), n(x))
    rx = min(rx, w / 2)
    ry = min(ry, h / 2)
    return (
        "M{} {}H{}A{} {} 0 0 1 {} {}V{}A{} {} 0 0 1 {} {}H{}A{} {} 0 0 1 {} {}V{}A{} {} 0 0 1 {} {}Z".format(
            n(x + rx), n(y), n(x + w - rx), n(rx), n(ry), n(x + w), n(y + ry), n(y + h - ry),
            n(rx), n(ry), n(x + w - rx), n(y + h), n(x + rx), n(rx), n(ry), n(x), n(y + h - ry),
            n(y + ry), n(rx), n(ry), n(x + rx), n(y),
        )
    )


def attr(el, name, default=None):
    value = el.attrib.get(name, default)
    if value is None:
        raise FigureError("{} is missing {}".format(local(el.tag), name))
    return float(value)


def shapes_of(svg_file):
    """Every accepted shape in document order, as path data."""
    root = ET.parse(svg_file).getroot()
    shapes = []
    for el in root.iter():
        tag = local(el.tag)
        if tag in REJECTED:
            raise FigureError("{}: <{}> is not supported".format(svg_file.name, tag))
        if "transform" in el.attrib:
            raise FigureError("{}: transform attributes are not supported, draw in figure space".format(svg_file.name))
        if tag in CONTAINERS:
            if tag == "defs" and len(el):
                raise FigureError("{}: <defs> must be empty".format(svg_file.name))
            continue
        if tag == "path":
            shapes.append(el.attrib["d"].strip())
        elif tag == "rect":
            rx = float(el.attrib.get("rx", el.attrib.get("ry", 0)))
            ry = float(el.attrib.get("ry", el.attrib.get("rx", 0)))
            shapes.append(rect_path(attr(el, "x", 0), attr(el, "y", 0), attr(el, "width"), attr(el, "height"), rx, ry))
        elif tag == "circle":
            r = attr(el, "r")
            shapes.append(ellipse_path(attr(el, "cx", 0), attr(el, "cy", 0), r, r))
        elif tag == "ellipse":
            shapes.append(ellipse_path(attr(el, "cx", 0), attr(el, "cy", 0), attr(el, "rx"), attr(el, "ry")))
        else:
            raise FigureError("{}: <{}> is not supported".format(svg_file.name, tag))
    return shapes


def path_points(d):
    """Points that bound the path: every endpoint and control point, and for
    arcs the radii around both ends."""
    tokens = TOKEN.findall(d)
    points = []
    cx = cy = sx = sy = 0.0
    i = 0
    command = None
    while i < len(tokens):
        if tokens[i].isalpha():
            command = tokens[i]
            i += 1
            if command in "Zz":
                cx, cy = sx, sy
                continue
        if command is None:
            raise FigureError("path data must start with a command: {}".format(d[:40]))
        upper = command.upper()
        count = ARGS[upper]
        args = [float(t) for t in tokens[i:i + count]]
        if len(args) != count:
            raise FigureError("{} needs {} numbers: {}".format(command, count, d[:60]))
        i += count
        relative = command.islower()
        ox, oy = (cx, cy) if relative else (0.0, 0.0)
        if upper == "H":
            cx = ox + args[0]
        elif upper == "V":
            cy = oy + args[0]
        elif upper == "A":
            rx, ry = abs(args[0]), abs(args[1])
            ex, ey = ox + args[5], oy + args[6]
            for x, y in ((cx, cy), (ex, ey)):
                points.extend([(x - rx, y - ry), (x + rx, y + ry)])
            cx, cy = ex, ey
        else:
            for k in range(0, count, 2):
                points.append((ox + args[k], oy + args[k + 1]))
            cx, cy = ox + args[count - 2], oy + args[count - 1]
        if upper == "M":
            sx, sy = cx, cy
            command = "l" if relative else "L"
        points.append((cx, cy))
    return points


def load_manifest():
    data = json.loads((SRC / "manifest.json").read_text(encoding="utf-8"))
    pieces = data.get("pieces")
    if not isinstance(pieces, list) or not pieces:
        raise FigureError("manifest.json needs a non-empty pieces list")
    seen = set()
    for piece in pieces:
        pid = piece.get("id")
        if not isinstance(pid, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", pid):
            raise FigureError("bad piece id: {!r}".format(pid))
        if pid in seen:
            raise FigureError("duplicate piece id: {}".format(pid))
        seen.add(pid)
        if piece.get("view") not in VIEWS:
            raise FigureError("{}: view must be one of {}".format(pid, VIEWS))
        if not isinstance(piece.get("layer"), int) or piece["layer"] < 0:
            raise FigureError("{}: layer must be a non-negative integer".format(pid))
        roles = piece.get("roles")
        if not isinstance(roles, list) or not roles or any(r not in ROLES for r in roles):
            raise FigureError("{}: roles must be a non-empty list drawn from {}".format(pid, ROLES))
    orphans = [s for s in sorted(f.stem for f in SRC.glob("*.svg")) if s not in seen]
    if orphans:
        raise FigureError("SVG files without a manifest entry: {}".format(", ".join(orphans)))
    return pieces


def compile_pieces(pieces):
    compiled = []
    for piece in pieces:
        svg_file = SRC / "{}.svg".format(piece["id"])
        if not svg_file.exists():
            raise FigureError("{}: {} is missing".format(piece["id"], svg_file.name))
        shapes = shapes_of(svg_file)
        if len(shapes) != len(piece["roles"]):
            raise FigureError("{}: {} shapes but {} roles".format(piece["id"], len(shapes), len(piece["roles"])))
        for d in shapes:
            for x, y in path_points(d):
                if not (0 <= x <= WIDTH and 0 <= y <= HEIGHT):
                    raise FigureError("{}: a shape leaves the figure box at ({}, {})".format(piece["id"], n(x), n(y)))
        compiled.append({"id": piece["id"], "view": piece["view"], "layer": piece["layer"],
                         "paths": list(zip(piece["roles"], shapes))})
    return compiled


def digest():
    h = hashlib.sha256()
    files = sorted(list(SRC.glob("*.svg")) + [SRC / "manifest.json"], key=lambda f: f.name)
    for f in files:
        h.update("{}\n".format(f.name).encode("utf-8"))
        h.update(f.read_bytes())
    return h.hexdigest()


def emit_dart(compiled, sources_digest):
    lines = [
        "// GENERATED by tool/build_figure_artwork.py from tool/figure/. Do not edit.",
        "// sources-digest: {}".format(sources_digest),
        "// dart format off",
        "",
        "import 'package:submersion/features/equipment/figure/domain/figure_piece_data.dart';",
        "import 'package:submersion/features/equipment/figure/domain/figure_role.dart';",
        "import 'package:submersion/features/equipment/figure/domain/figure_view.dart';",
        "",
        "/// SHA-256 over the manifest and every SVG, so a test can tell when this",
        "/// file is stale against its sources.",
        "const String figureArtworkDigest = '{}';".format(sources_digest),
        "",
        "/// Every piece of artwork by id.",
        "const Map<String, FigurePieceData> figureArtwork = {",
    ]
    for piece in compiled:
        lines.append("  '{}': FigurePieceData(".format(piece["id"]))
        lines.append("    id: '{}',".format(piece["id"]))
        lines.append("    view: FigureView.{},".format(piece["view"]))
        lines.append("    layer: {},".format(piece["layer"]))
        lines.append("    paths: [")
        for role, d in piece["paths"]:
            lines.append("      FigurePathData(role: FigureRole.{}, d: '{}'),".format(role, d))
        lines.append("    ],")
        lines.append("  ),")
    lines.append("};")
    lines.append("")
    return "\n".join(lines)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verify", action="store_true", help="check sources and that the Dart file is current")
    args = parser.parse_args(argv)
    try:
        compiled = compile_pieces(load_manifest())
        text = emit_dart(compiled, digest())
    except (FigureError, ET.ParseError, KeyError, ValueError) as error:
        print("FAIL {}".format(error))
        return 1
    if args.verify:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("FAIL {} is stale; run python3 tool/build_figure_artwork.py".format(OUT.relative_to(ROOT)))
            return 1
        print("OK {} pieces current".format(len(compiled)))
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print("wrote {} ({} pieces)".format(OUT.relative_to(ROOT), len(compiled)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
