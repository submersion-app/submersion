#!/usr/bin/env python3
"""Regenerate VPM-B golden vectors for the Dart VpmB deco model.

The vectors in test/core/deco/golden/vpmb_golden.json are the acceptance
reference for lib/core/deco/vpm_b.dart. NEVER hand-edit the JSON - regenerate
it with this script so the Dart implementation is always checked against an
independent engine.

Reference engine: bwaite/vpmb (https://github.com/bwaite/vpmb), a BSD-2
licensed Python port of Erik C. Baker's canonical FORTRAN VPMDECO. Fetch it:

    curl -sL -o vpmb.py \\
      https://raw.githubusercontent.com/bwaite/vpmb/master/vpmb.py

then run this script from the same directory:

    python3 vpmb_generate.py > ../../test/core/deco/golden/vpmb_golden.json

Conservatism +0..+4 maps to the critical nucleus radius via Subsurface's
multiplier array {1.0, 1.05, 1.12, 1.22, 1.35} on the 0.55/0.45 micron base
(see lib/core/deco/vpm_b.dart). Units: msw (the app's internal metric).

Validation tripwire: air 50 m / 25 min at +3 must give first stop 27 m.
"""
import json
import sys

try:
    from vpmb import DiveState
except ImportError:
    sys.stderr.write(
        "Fetch bwaite/vpmb first (see this file's docstring).\n"
    )
    raise

CONS = {
    0: (0.550, 0.450),
    1: (0.578, 0.473),
    2: (0.616, 0.504),
    3: (0.671, 0.549),
    4: (0.743, 0.608),
}

SEA_LEVEL = {
    "Altitude_of_Dive": 0,
    "Diver_Acclimatized_at_Altitude": "no",
    "Starting_Acclimatized_Altitude": 0,
    "Ascent_to_Altitude_Hours": 1,
    "Hours_at_Altitude_Before_Dive": 2,
}


def settings(level):
    rn2, rhe = CONS[level]
    return {
        "Units": "msw",
        "Surface_Tension_Gamma": 0.0179,
        "Skin_Compression_GammaC": 0.257,
        "Crit_Volume_Parameter_Lambda": 7500.0,
        "Regeneration_Time_Constant": 20160.0,
        "Gradient_Onset_of_Imperm_Atm": 8.2,
        "Minimum_Deco_Stop_Time": 1.0,
        "Critical_Radius_N2_Microns": rn2,
        "Critical_Radius_He_Microns": rhe,
        "Critical_Volume_Algorithm": "on",
        "Pressure_Other_Gases_mmHg": 102.0,
        "SetPoint_Is_Bar": True,
        "Altitude_Dive_Algorithm": "OFF",
    }


def dive(desc, depth_m, bottom_min, o2=0.21, he=0.0,
         descent_rate=18.0, ascent_rate=10.0):
    n2 = round(1.0 - o2 - he, 6)
    return {
        "desc": desc,
        "num_gas_mixes": 1,
        "gasmix_summary": [
            {"fraction_O2": o2, "fraction_He": he, "fraction_N2": n2}
        ],
        "profile_codes": [
            {"profile_code": 1, "starting_depth": 0, "ending_depth": depth_m,
             "rate": descent_rate, "gasmix": 1, "setpoint": 0.0},
            {"profile_code": 2, "depth": depth_m,
             "run_time_at_end_of_segment": bottom_min, "gasmix": 1,
             "setpoint": 0.0},
            {"profile_code": 99, "number_of_ascent_parameter_changes": 1,
             "ascent_summary": [
                 {"starting_depth": depth_m, "gasmix": 1,
                  "rate": -ascent_rate, "step_size": 3, "setpoint": 0.0}]},
        ],
        "repetitive_code": 0,
    }


def schedule(level, d):
    state = DiveState(
        json_input={"settings": settings(level), "input": [d],
                    "altitude": SEA_LEVEL}
    )
    state.main()
    out = state.output_object.get_json()[0]
    stops = []
    for row in out["decompression_profile"]:
        depth, stop_time = row[6].strip(), row[7].strip()
        if depth and stop_time:
            stops.append([int(depth), int(stop_time)])
    return stops


SCENARIOS = [
    ("air_50m_25min", dict(desc="air 50m 25min", depth_m=50, bottom_min=25)),
    ("air_40m_30min", dict(desc="air 40m 30min", depth_m=40, bottom_min=30)),
    ("air_30m_40min", dict(desc="air 30m 40min", depth_m=30, bottom_min=40)),
    ("tx1845_60m_25min",
     dict(desc="18/45 60m 25min", depth_m=60, bottom_min=25, o2=0.18, he=0.45)),
]


def main():
    golden = {}
    for name, kwargs in SCENARIOS:
        golden[name] = {
            "dive": kwargs,
            "schedules": {str(lvl): schedule(lvl, dive(**kwargs))
                          for lvl in range(5)},
        }
    assert golden["air_50m_25min"]["schedules"]["3"][0][0] == 27, \
        "config mismatch: air 50m/25min +3 first stop must be 27 m"
    json.dump(golden, sys.stdout, indent=1)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
