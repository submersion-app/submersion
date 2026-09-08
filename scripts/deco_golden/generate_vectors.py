#!/usr/bin/env python3
"""Golden-vector generator for the Submersion deco engine.

Independent ZH-L16C + gradient-factor implementation. Semantics are pinned
to the contract in
docs/superpowers/plans/2026-07-05-dive-planner-phase1-engine.md (Task 9).
Regenerate with:

    python3 scripts/deco_golden/generate_vectors.py \
        > test/core/deco/golden/vectors.json
"""
import json
import math

# ZH-L16C tables: copied VERBATIM from
# lib/core/deco/constants/buhlmann_coefficients.dart
N2_HALF = [4.0, 8.0, 12.5, 18.5, 27.0, 38.3, 54.3, 77.0,
           109.0, 146.0, 187.0, 239.0, 305.0, 390.0, 498.0, 635.0]
HE_HALF = [1.51, 3.02, 4.72, 6.99, 10.21, 14.48, 20.53, 29.11,
           41.20, 55.19, 70.69, 90.34, 115.29, 147.42, 188.24, 240.03]
N2_A = [1.2599, 1.0000, 0.8618, 0.7562, 0.6200, 0.5043, 0.4410, 0.4000,
        0.3750, 0.3500, 0.3295, 0.3065, 0.2835, 0.2610, 0.2480, 0.2327]
N2_B = [0.5050, 0.6514, 0.7222, 0.7825, 0.8126, 0.8434, 0.8693, 0.8910,
        0.9092, 0.9222, 0.9319, 0.9403, 0.9477, 0.9544, 0.9602, 0.9653]
HE_A = [1.7424, 1.3830, 1.1919, 1.0458, 0.9220, 0.8205, 0.7305, 0.6502,
        0.5950, 0.5545, 0.5333, 0.5189, 0.5181, 0.5176, 0.5172, 0.5119]
HE_B = [0.4245, 0.5747, 0.6527, 0.7223, 0.7582, 0.7957, 0.8279, 0.8553,
        0.8757, 0.8903, 0.8997, 0.9073, 0.9122, 0.9171, 0.9217, 0.9267]

WV = 0.0627
AIR_N2 = 0.7902
G = 9.80665


class Env:
    def __init__(self, surface=1.0, density=1019.716213):
        self.surface = surface
        self.density = density

    @property
    def bar_per_m(self):
        return self.density * G / 100000.0

    def p_at(self, depth):
        return self.surface + depth * self.bar_per_m

    def depth_at(self, p):
        return (p - self.surface) / self.bar_per_m


class State:
    def __init__(self, env):
        self.env = env
        surf_n2 = (env.surface - WV) * AIR_N2
        self.n2 = [surf_n2] * 16
        self.he = [0.0] * 16
        self.anchor = 0.0  # deepest GF-low ceiling so far, meters

    def clone(self):
        s = State(self.env)
        s.n2, s.he, s.anchor = list(self.n2), list(self.he), self.anchor
        return s


def schreiner(p0, pi, minutes, half):
    k = math.log(2) / half
    return pi + (p0 - pi) * math.exp(-k * minutes)


def ceiling_pressure(state, i, gf):
    pn, ph = state.n2[i], state.he[i]
    total = pn + ph
    if total == 0:
        a, b = N2_A[i], N2_B[i]
    else:
        a = (pn * N2_A[i] + ph * HE_A[i]) / total
        b = (pn * N2_B[i] + ph * HE_B[i]) / total
    return (total - a * gf) / (gf / b + 1 - gf)


def ceiling_m(state, gf):
    """Max over compartments of the (>=0 clamped) ceiling in meters."""
    worst = 0.0
    for i in range(16):
        m = state.env.depth_at(ceiling_pressure(state, i, gf))
        if m < 0:
            m = 0.0
        worst = max(worst, m)
    return worst


def interp_gf(state, depth, gf_low, gf_high):
    if depth <= 0 or state.anchor <= 0:
        return gf_high
    if depth >= state.anchor:
        return gf_low
    return gf_high - (gf_high - gf_low) * (depth / state.anchor)


CEILING_SOLVE_ITERATIONS = 24
CEILING_SOLVE_TOL_M = 0.001


def gf_ceiling_m(state, gf_low, gf_high):
    """The operative ceiling: the depth tolerated under the GF that applies
    at that same depth, i.e. a fixed point of interp_gf. Mirrors Dart's
    BuhlmannAlgorithm.calculateCeiling. Depends only on tissue state and the
    anchor, never on where the diver currently is.
    """
    c = ceiling_m(state, gf_low)
    if c <= 0:
        return 0.0
    if state.anchor <= 0:
        return ceiling_m(state, gf_high)
    for _ in range(CEILING_SOLVE_ITERATIONS):
        nxt = ceiling_m(state, interp_gf(state, c, gf_low, gf_high))
        converged = abs(nxt - c) < CEILING_SOLVE_TOL_M
        c = nxt
        if converged:
            break
    return c


def load(state, depth, seconds, f_n2, f_he, gf_low, setpoint=None):
    amb = state.env.p_at(depth)
    p_alv = max(amb - WV, 0.0)
    if setpoint is None:
        i_n2, i_he = p_alv * f_n2, p_alv * f_he
    else:
        p_o2 = min(setpoint, p_alv)
        inert = max(p_alv - p_o2, 0.0)
        tot = f_n2 + f_he
        share = f_n2 / tot if tot > 0 else 0.0
        i_n2, i_he = inert * share, inert * (1 - share)
    minutes = seconds / 60.0
    for i in range(16):
        state.n2[i] = schreiner(state.n2[i], i_n2, minutes, N2_HALF[i])
        state.he[i] = schreiner(state.he[i], i_he, minutes, HE_HALF[i])
    state.anchor = max(state.anchor, ceiling_m(state, gf_low))


def gas_at(gases, depth):
    """Highest-O2 gas eligible at depth (depth <= mod + eps)."""
    best = None
    for g in gases:
        if depth <= g["mod_m"] + 1e-9:
            fo2 = 1.0 - g["f_n2"] - g["f_he"]
            if best is None or fo2 > (1.0 - best["f_n2"] - best["f_he"]):
                best = g
    if best is None:
        best = min(gases, key=lambda g: 1.0 - g["f_n2"] - g["f_he"])
    return best


def switch_depths(gases, deeper, shallower):
    out = []
    for g in gases:
        m = g["mod_m"]
        if shallower + 1e-9 < m < deeper - 1e-9:
            below, above = gas_at(gases, m + 1e-6), gas_at(gases, m - 1e-6)
            if below is not above:
                out.append(m)
    return sorted(out, reverse=True)


def ascend_load(state, frm, to, rate, gases, gf_low):
    """Tissue loading for an ascent leg, split at gas-switch depths.

    Mirrors BuhlmannAlgorithm._simulateAscent/_ascendLeg: each sub-leg is
    loaded at its average depth for round(delta/rate*60) seconds on the gas
    eligible at its deeper end. (TTS *time* is accounted separately,
    Dart-style, without switch splitting.)
    """
    if frm <= to:
        return
    seg_top = frm
    for sw in switch_depths(gases, frm, to):
        _leg_load(state, seg_top, sw, rate, gases, gf_low)
        seg_top = sw
    _leg_load(state, seg_top, to, rate, gases, gf_low)


def _leg_load(state, frm, to, rate, gases, gf_low):
    if frm <= to:
        return
    g = gas_at(gases, frm)
    secs = round((frm - to) / rate * 60)
    load(state, (frm + to) / 2.0, secs, g["f_n2"], g["f_he"], gf_low)


TRIAL_SLICE_SECONDS = 10


def trial_clears(state, depth, nxt, rate, gases, gf_low, gf_high):
    """Mirror of _trialAscentClears: may the diver leave `depth` for `nxt`?

    Simulates the leg in slices of at most TRIAL_SLICE_SECONDS, each loaded
    at its mean depth on the gas eligible at its deeper end, and requires the
    ceiling to stay at or below the diver after every slice - the last of
    which lands exactly on `nxt`, so arrival is checked too. Works on a clone;
    `state` is untouched.
    """
    secs = round((depth - nxt) / rate * 60)
    if secs <= 0:
        return gf_ceiling_m(state, gf_low, gf_high) <= nxt
    trial = state.clone()
    span = depth - nxt
    elapsed = 0
    while elapsed < secs:
        dt = min(TRIAL_SLICE_SECONDS, secs - elapsed)
        start = depth - span * elapsed / secs
        end = nxt if elapsed + dt >= secs else depth - span * (elapsed + dt) / secs
        g = gas_at(gases, start)
        load(trial, (start + end) / 2.0, dt, g["f_n2"], g["f_he"], gf_low)
        elapsed += dt
        if gf_ceiling_m(trial, gf_low, gf_high) > end:
            return False
    return True


def next_level(depth, last_stop, incr):
    """Mirror of _nextLevel: next grid stop, the last stop when the grid
    would step past it, or 0 (surface) from the last stop itself."""
    if depth <= last_stop:
        return 0.0
    return max(depth - incr, last_stop)


def stop_time(state, depth, gases, gf_low, gf_high, last_stop, incr, rate):
    """Minutes-at-stop search, mirroring _calculateStopTime.

    Applies the found minutes to `state` (equivalent to Dart's restore +
    _loadStopMinutes single-call application: exponential loading composes).
    """
    nxt = next_level(depth, last_stop, incr)
    g = gas_at(gases, depth)
    t = 0
    while t < 120 * 60:
        # Tested on arrival, BEFORE the minute is loaded: may the diver leave
        # with the time spent so far? Testing after a trial minute and then
        # discarding it credited off-gassing the schedule never spends. The
        # test simulates the leg to the next level (Subsurface trial_ascent),
        # so the travel's own off-gassing counts toward clearing the stop.
        if trial_clears(state, depth, nxt, rate, gases, gf_low, gf_high):
            break
        load(state, depth, 60, g["f_n2"], g["f_he"], gf_low)
        t += 60
    return t


def schedule(state, depth, gases, gf_low, gf_high,
             last_stop=3.0, incr=3.0, rate=9.0):
    """Stops + TTS from `depth`, mirroring calculateDecoSchedule/Tts."""
    stops = []
    work = state.clone()
    ceil0 = gf_ceiling_m(work, gf_low, gf_high)
    if ceil0 <= 0:
        return stops, round(depth / rate * 60)
    # First stop: the grid level at or below the ceiling, never shallower
    # than the last stop (mirrors calculateDecoSchedule).
    stop = max(math.ceil(ceil0 / incr) * incr, last_stop)

    ascend_load(work, depth, stop, rate, gases, gf_low)
    while stop > 0:
        t = stop_time(work, stop, gases, gf_low, gf_high, last_stop, incr,
                      rate)
        if t > 0:
            stops.append({"depth_m": stop, "seconds": t})
        nxt = next_level(stop, last_stop, incr)
        if nxt > 0:
            ascend_load(work, stop, nxt, rate, gases, gf_low)
        stop = nxt

    # TTS, Dart calculateTts-style: stop seconds plus per-transition travel
    # legs rounded independently (NOT split at switch depths).
    tts = sum(s["seconds"] for s in stops)
    d = depth
    for s in stops:
        tts += round((d - s["depth_m"]) / rate * 60)
        d = s["depth_m"]
    if d > 0:
        tts += round(d / rate * 60)
    return stops, tts


def run_case(name, env, gf, segments, sched_depth, gases,
             tissues=False, ceiling=False):
    st = State(env)
    for seg in segments:
        load(st, seg["avg_depth_m"], seg["seconds"], seg["f_n2"],
             seg["f_he"], gf[0] / 100.0, seg.get("setpoint"))
    expected = {}
    if sched_depth is not None:
        stops, tts = schedule(st, sched_depth, gases,
                              gf[0] / 100.0, gf[1] / 100.0)
        expected["stops"] = stops
        expected["tts_seconds"] = tts
    if tissues:
        expected["tissues_p_n2_bar"] = [round(x, 6) for x in st.n2]
        expected["tissues_p_he_bar"] = [round(x, 6) for x in st.he]
    if ceiling:
        expected["ceiling_m"] = round(
            gf_ceiling_m(st, gf[0] / 100.0, gf[1] / 100.0), 3)
    return {
        "name": name,
        "environment": {"surface_pressure_bar": env.surface,
                        "water_density_kg_m3": env.density},
        "gf": gf,
        "segments": segments,
        "schedule_from_depth_m": sched_depth,
        "gases": gases,
        "expected": expected,
    }


AIR = {"f_n2": 0.7902, "f_he": 0.0, "mod_m": 66.0}
EAN32 = {"f_n2": 0.68, "f_he": 0.0, "mod_m": 40.0}
EAN50 = {"f_n2": 0.50, "f_he": 0.0, "mod_m": 22.0}   # ppO2 1.6
O2 = {"f_n2": 0.0, "f_he": 0.0, "mod_m": 6.0}        # ppO2 1.6
TX1845 = {"f_n2": 0.37, "f_he": 0.45, "mod_m": 78.0}

STD = Env()
ISA_2000M = 1.01325 * (1 - 0.0000225577 * 2000.0) ** 5.25588

cases = [
    run_case("air-30m-25min-gf5080", STD, [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 1500,
               "f_n2": 0.7902, "f_he": 0.0}],
             30.0, [AIR], tissues=True),
    run_case("air-40m-20min-gf3070", STD, [30, 70],
             [{"avg_depth_m": 20.0, "seconds": 133,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 40.0, "seconds": 1200,
               "f_n2": 0.7902, "f_he": 0.0}],
             40.0, [AIR]),
    run_case("ean32-30m-40min-gf5080", STD, [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.68, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 2400,
               "f_n2": 0.68, "f_he": 0.0}],
             30.0, [EAN32]),
    run_case("tx1845-60m-25min-ean50-o2-gf5080", STD, [50, 80],
             [{"avg_depth_m": 30.0, "seconds": 200,
               "f_n2": 0.37, "f_he": 0.45},
              {"avg_depth_m": 60.0, "seconds": 1500,
               "f_n2": 0.37, "f_he": 0.45}],
             60.0, [TX1845, EAN50, O2]),
    run_case("air-30m-20min-altitude2000m", Env(surface=ISA_2000M), [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 1200,
               "f_n2": 0.7902, "f_he": 0.0}],
             30.0, [AIR]),
    run_case("air-30m-25min-freshwater", Env(density=1000.0), [50, 80],
             [{"avg_depth_m": 15.0, "seconds": 100,
               "f_n2": 0.7902, "f_he": 0.0},
              {"avg_depth_m": 30.0, "seconds": 1500,
               "f_n2": 0.7902, "f_he": 0.0}],
             30.0, [AIR]),
    run_case("ccr-sp13-dil1845-60m-25min-loading", STD, [50, 80],
             [{"avg_depth_m": 30.0, "seconds": 200, "f_n2": 0.37,
               "f_he": 0.45, "setpoint": 1.3},
              {"avg_depth_m": 60.0, "seconds": 1500, "f_n2": 0.37,
               "f_he": 0.45, "setpoint": 1.3}],
             None, [], tissues=True, ceiling=True),
]

print(json.dumps({"generator": "scripts/deco_golden/generate_vectors.py",
                  "semantics_version": 3, "cases": cases}, indent=2))
