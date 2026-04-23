"""Score a decoded profile against UDDF ground truth.

A decoded profile is a list[dict] with keys {time_s, depth_m, temperature_c?,
pressure_bar?, ppo2_bar?, ndl_s?}. The truth profile has the same shape.

Tolerances (from the spec):
    timestamp: exact match required (rounded to seconds)
    depth:     +/- 0.1 m
    temperature: +/- 0.5 C
"""
from __future__ import annotations

import math
from dataclasses import dataclass


DEPTH_TOLERANCE_M = 0.1
TEMP_TOLERANCE_C = 0.5


@dataclass
class Score:
    sample_count_match: float        # len(decoded) / len(truth), clamped [0, 1]
    timestamp_rmse: float            # seconds
    depth_rmse: float                # meters
    temperature_rmse: float          # celsius
    pct_samples_within_tolerance: float  # [0, 1]
    matched_samples: int
    truth_samples: int
    decoded_samples: int

    @property
    def overall(self) -> float:
        """Single scalar in [0, 1]; higher = better. Used for hypothesis ranking."""
        if self.truth_samples == 0:
            return 0.0
        return (
            0.5 * self.pct_samples_within_tolerance
            + 0.5 * min(1.0, self.sample_count_match)
        )


def score_decode(decoded: list[dict], truth: list[dict]) -> Score:
    truth_by_time = {s["time_s"]: s for s in truth}
    decoded_by_time = {s["time_s"]: s for s in decoded}

    matched_samples = 0
    depth_squared_err = 0.0
    temp_squared_err = 0.0
    temp_count = 0
    timestamps_matched = 0

    for t, truth_sample in truth_by_time.items():
        decoded_sample = decoded_by_time.get(t)
        if decoded_sample is None:
            continue
        timestamps_matched += 1

        depth_err = decoded_sample.get("depth_m", 0.0) - truth_sample.get("depth_m", 0.0)
        depth_squared_err += depth_err * depth_err

        if "temperature_c" in decoded_sample and "temperature_c" in truth_sample:
            temp_err = decoded_sample["temperature_c"] - truth_sample["temperature_c"]
            temp_squared_err += temp_err * temp_err
            temp_count += 1

        if abs(depth_err) <= DEPTH_TOLERANCE_M:
            temp_ok = (
                "temperature_c" not in truth_sample
                or "temperature_c" not in decoded_sample
                or abs(decoded_sample["temperature_c"] - truth_sample["temperature_c"]) <= TEMP_TOLERANCE_C
            )
            if temp_ok:
                matched_samples += 1

    truth_n = max(1, len(truth))
    return Score(
        sample_count_match=min(1.0, len(decoded) / truth_n) if truth_n else 0.0,
        timestamp_rmse=0.0,  # we match by exact time; non-matches excluded
        depth_rmse=math.sqrt(depth_squared_err / timestamps_matched) if timestamps_matched else float("nan"),
        temperature_rmse=math.sqrt(temp_squared_err / max(1, temp_count)) if temp_count else 0.0,
        pct_samples_within_tolerance=matched_samples / max(1, len(truth)),
        matched_samples=matched_samples,
        truth_samples=len(truth),
        decoded_samples=len(decoded),
    )
