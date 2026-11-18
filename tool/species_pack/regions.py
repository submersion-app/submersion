#!/usr/bin/env python3
"""Where each candidate has been recorded, from GBIF's occurrence density
maps: two 512 px tiles cover the world at zoom 0 in EPSG:4326, so one
species is two requests. A coloured pixel is a recorded place; each one is
binned into the region grid. Needs Pillow."""

import io
import os
import time
import urllib.error
import urllib.request

from region_grid import cell_of

USER_AGENT = "species-pack-builder/0.1 (+https://github.com/submersion-app/submersion)"
TILE = "https://api.gbif.org/v2/map/occurrence/density/0/{x}/0@1x.png?srs=EPSG:4326&taxonKey={key}&style=classic.point"
TILE_SIZE = 512
DEGREES_PER_PIXEL = 180 / TILE_SIZE


def _tile(key, x, work):
    path = os.path.join(work, "tiles", f"{key}_{x}.png")
    if os.path.exists(path):
        with open(path, "rb") as fh:
            return fh.read()
    request = urllib.request.Request(TILE.format(x=x, key=key), headers={"User-Agent": USER_AGENT})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
            break
        except urllib.error.HTTPError as e:
            if e.code == 204:
                data = b""
                break
            if e.code not in (429, 500, 502, 503, 504) or attempt == 5:
                raise
            time.sleep(2 ** attempt)
        except (urllib.error.URLError, TimeoutError):
            if attempt == 5:
                raise
            time.sleep(2 ** attempt)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data)
    return data


def cells_for(key, cell_degrees, work):
    """The grid cells where species `key` has been recorded."""
    from PIL import Image

    cells = set()
    for x in (0, 1):
        data = _tile(key, x, work)
        if not data:
            continue
        image = Image.open(io.BytesIO(data)).convert("RGBA")
        alpha = image.getchannel("A")
        width, height = image.size
        pixels = alpha.load()
        for py in range(height):
            lat = 90 - (py + 0.5) * DEGREES_PER_PIXEL
            for px in range(width):
                if pixels[px, py]:
                    lon = -180 + x * 180 + (px + 0.5) * DEGREES_PER_PIXEL
                    cells.add(cell_of(lat, lon, cell_degrees))
    return cells
