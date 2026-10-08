#!/usr/bin/env python3
"""Fetch NOAA local-time tide fixtures for the site-time golden test.

For each station: harmonic constituents (GMT phases), the MSL minus MLLW
datum offset, the station coordinates, and NOAA's own high/low predictions
in the station's local standard or daylight time (time_zone=lst_ldt). NOAA
performs the local-time conversion, independently of Submersion's code.

Usage (from the repo root):
    python3.14 scripts/tide/fetch_noaa_local_time_fixtures.py
"""

import json
import urllib.request
from pathlib import Path

MDAPI = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations"
DATAGETTER = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
OUT_DIR = Path("test/core/tide/fixtures")

# Same spelling map as NoaaStationService._nameMap.
NAME_MAP = {
    "NU2": "Nu2",
    "MU2": "Mu2",
    "LAM2": "La2",
    "RHO": "Rho1",
    "MM": "Mm",
    "SSA": "Ssa",
    "SA": "Sa",
    "MF": "Mf",
}

STATIONS = [
    # San Francisco (Pacific time): windows straddle both 2026 DST changes.
    ("9414290", [("20260307", "20260309"), ("20261031", "20261102")]),
    # San Juan, Puerto Rico (Atlantic time, no DST).
    ("9755371", [("20260714", "20260716")]),
]


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "submersion"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def main() -> None:
    for station, windows in STATIONS:
        meta = get_json(f"{MDAPI}/{station}.json")["stations"][0]
        harcon = get_json(f"{MDAPI}/{station}/harcon.json?units=metric")
        datums = get_json(f"{MDAPI}/{station}/datums.json?units=metric")["datums"]
        datum = {d["name"]: d["value"] for d in datums}

        constituents = {}
        for c in harcon["HarmonicConstituents"]:
            if c["amplitude"] <= 0:
                continue
            name = NAME_MAP.get(c["name"], c["name"])
            constituents[name] = {"amplitude": c["amplitude"], "phase": c["phase_GMT"]}

        extremes = []
        for begin, end in windows:
            url = (
                f"{DATAGETTER}?product=predictions&application=submersion"
                f"&begin_date={begin}&end_date={end}&datum=MLLW&station={station}"
                "&time_zone=lst_ldt&units=metric&interval=hilo&format=json"
            )
            for p in get_json(url)["predictions"]:
                extremes.append(
                    {"localTime": p["t"], "type": p["type"], "height": float(p["v"])}
                )

        fixture = {
            "station": station,
            "name": meta["name"],
            "latitude": meta["lat"],
            "longitude": meta["lng"],
            "source": "NOAA CO-OPS harcon, datums and hilo predictions, time_zone=lst_ldt",
            "z0MetersAboveMllw": round(datum["MSL"] - datum["MLLW"], 4),
            "constituents": constituents,
            "expectedLocalExtremes": extremes,
        }
        out = OUT_DIR / f"noaa_local_{station}.json"
        out.write_text(json.dumps(fixture, indent=1) + "\n", encoding="utf-8")
        print(f"Wrote {len(extremes)} extremes for {station} to {out}")


if __name__ == "__main__":
    main()
