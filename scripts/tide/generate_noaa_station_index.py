"""Generate the bundled NOAA harmonic station index asset.

Fetches the list of NOAA CO-OPS stations that publish harmonic
constituents (type=harcon; ~1,365 stations) and writes a compact JSON
array of [id, name, lat, lng] rows to assets/data/tide/noaa_stations.json.

Usage (from the repo root):
    python3 scripts/tide/generate_noaa_station_index.py
"""

import json
import urllib.request

URL = (
    "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/"
    "stations.json?type=harcon"
)
OUT = "assets/data/tide/noaa_stations.json"


def main() -> None:
    req = urllib.request.Request(URL, headers={"User-Agent": "submersion"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)

    rows = []
    for s in data["stations"]:
        if not s.get("id") or s.get("lat") is None or s.get("lng") is None:
            continue
        rows.append(
            [s["id"], s.get("name", s["id"]), round(s["lat"], 4), round(s["lng"], 4)]
        )
    rows.sort(key=lambda r: r[0])

    with open(OUT, "w") as f:
        json.dump(rows, f, separators=(",", ":"))
    print(f"Wrote {len(rows)} stations to {OUT}")


if __name__ == "__main__":
    main()
