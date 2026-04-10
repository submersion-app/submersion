#!/usr/bin/env python3
"""Tests for UDDF test data generator helper functions."""

import math
import sys
import os
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_uddf_test_data import (
    PerlinNoise,
    DiverPersonality,
    breathing_oscillation,
    generate_micro_events,
    apply_micro_event,
    calculate_temperature_at_depth,
    generate_dive_profile,
    THERMOCLINE_PROFILES,
    GAS_MIXES,
)


class TestPerlinNoise(unittest.TestCase):
    """Test the 1D Perlin noise implementation."""

    def test_output_range(self):
        """Noise output should be in approximately [-1, 1] range."""
        noise = PerlinNoise(seed=42)
        values = [noise.noise(t * 0.1) for t in range(1000)]
        self.assertTrue(
            all(-1.5 <= v <= 1.5 for v in values),
            f"Values out of range: min={min(values)}, max={max(values)}",
        )

    def test_smoothness(self):
        """Adjacent samples should not have large jumps."""
        noise = PerlinNoise(seed=42)
        step = 0.01
        for i in range(999):
            t1 = i * step
            t2 = (i + 1) * step
            diff = abs(noise.noise(t2) - noise.noise(t1))
            self.assertLess(diff, 0.2, f"Jump too large at t={t1}: {diff}")

    def test_deterministic(self):
        """Same seed and input should produce same output."""
        noise1 = PerlinNoise(seed=42)
        noise2 = PerlinNoise(seed=42)
        for t in [0.0, 1.5, 10.7, 100.3]:
            self.assertEqual(noise1.noise(t), noise2.noise(t))

    def test_different_seeds_differ(self):
        """Different seeds should produce different outputs."""
        noise1 = PerlinNoise(seed=42)
        noise2 = PerlinNoise(seed=99)
        differences = sum(
            1
            for t in [0.5, 1.5, 2.5, 3.5, 4.5]
            if noise1.noise(t) != noise2.noise(t)
        )
        self.assertGreater(differences, 0)

    def test_non_periodic_over_dive_length(self):
        """Should not repeat within a typical dive duration."""
        noise = PerlinNoise(seed=42)
        segment1 = [noise.noise(t * 0.02) for t in range(0, 300)]
        segment2 = [noise.noise(t * 0.02) for t in range(300, 600)]
        self.assertNotEqual(segment1, segment2)


class TestDiverPersonality(unittest.TestCase):
    """Test diver personality generation."""

    def test_fields_in_range(self):
        """All personality fields should be in [0, 1] range."""
        import random as rng

        rng.seed(42)
        for _ in range(100):
            p = DiverPersonality.generate(dive_number=50, total_dives=500)
            self.assertTrue(0 <= p.skill_level <= 1)
            self.assertTrue(0 <= p.activity_level <= 1)

    def test_skill_progression(self):
        """Later dives should tend toward higher skill."""
        import random as rng

        rng.seed(42)
        early = [DiverPersonality.generate(i, 500).skill_level for i in range(1, 20)]
        late = [DiverPersonality.generate(i, 500).skill_level for i in range(480, 500)]
        self.assertGreater(sum(late) / len(late), sum(early) / len(early))

    def test_descent_rate_varies_with_skill(self):
        """Experienced divers should have faster descent rates."""
        novice = DiverPersonality(skill_level=0.2, activity_level=0.5)
        expert = DiverPersonality(skill_level=0.9, activity_level=0.5)
        self.assertLess(novice.descent_rate_range[0], expert.descent_rate_range[0])


class TestBreathingOscillation(unittest.TestCase):
    """Test breathing oscillation function."""

    def test_amplitude_range(self):
        """Breathing oscillation should be within expected amplitude."""
        for skill in [0.2, 0.5, 0.9]:
            values = [breathing_oscillation(t, skill) for t in range(0, 600, 5)]
            max_amp = max(abs(v) for v in values)
            self.assertLess(
                max_amp, 0.5, f"Breathing amplitude too large for skill {skill}"
            )

    def test_experienced_smaller_amplitude(self):
        """Higher skill should produce smaller breathing oscillation."""
        novice = [abs(breathing_oscillation(t, 0.2)) for t in range(0, 600, 5)]
        expert = [abs(breathing_oscillation(t, 0.9)) for t in range(0, 600, 5)]
        self.assertGreater(max(novice), max(expert))


class TestMicroEvents(unittest.TestCase):
    """Test micro-event generation and application."""

    def test_event_count_in_range(self):
        """Should generate reasonable number of events."""
        import random as rng

        rng.seed(42)
        events = generate_micro_events(60, 600, 20.0, 0.5, 25.0)
        self.assertTrue(1 <= len(events) <= 8)

    def test_events_within_time_range(self):
        """All events should start within the level's time range."""
        import random as rng

        rng.seed(42)
        events = generate_micro_events(100, 500, 20.0, 0.8, 25.0)
        for event in events:
            self.assertGreaterEqual(event["start_time"], 100)
            self.assertLessEqual(event["start_time"], 600)

    def test_event_depth_offset_reasonable(self):
        """Event depth offsets should not exceed bounds."""
        import random as rng

        rng.seed(42)
        for _ in range(50):
            events = generate_micro_events(0, 600, 20.0, 0.9, 25.0)
            for event in events:
                self.assertLessEqual(abs(event["depth_offset"]), 5.0)

    def test_apply_returns_zero_outside_event(self):
        """apply_micro_event should return 0 outside event window."""
        event = {
            "start_time": 100,
            "duration": 30,
            "depth_offset": -2.0,
            "event_type": "look_below",
        }
        self.assertAlmostEqual(apply_micro_event(event, 50), 0.0)
        self.assertAlmostEqual(apply_micro_event(event, 200), 0.0)

    def test_apply_returns_nonzero_during_event(self):
        """apply_micro_event should return depth offset during event."""
        event = {
            "start_time": 100,
            "duration": 30,
            "depth_offset": -2.0,
            "event_type": "look_below",
        }
        offset = apply_micro_event(event, 115)
        self.assertNotAlmostEqual(offset, 0.0)


class TestTemperatureFix(unittest.TestCase):
    """Test that temperature is depth-stratified, not noisy."""

    def test_same_depth_same_temp(self):
        """Same depth on same dive should return nearly identical temperature."""
        profile = THERMOCLINE_PROFILES["tropical"]
        temp_offset = 0.1
        t1 = calculate_temperature_at_depth(15.0, profile, 28.0, temp_offset)
        t2 = calculate_temperature_at_depth(15.0, profile, 28.0, temp_offset)
        self.assertAlmostEqual(t1, t2, places=1)

    def test_no_depth_correlated_oscillation(self):
        """Small depth changes in a uniform zone should not cause large temperature swings."""
        profile = THERMOCLINE_PROFILES["tropical"]
        temp_offset = 0.0
        # Use depths firmly in the surface layer (well above thermocline_start=18m)
        # so any swing is purely from sensor noise, not a real gradient
        temps = []
        for d in [8.0, 8.5, 9.0, 8.5, 8.0, 8.3, 7.8]:
            temps.append(calculate_temperature_at_depth(d, profile, 28.0, temp_offset))
        max_swing = max(temps) - min(temps)
        self.assertLess(max_swing, 0.5,
                        f"Temperature swings too much over 1m depth changes: {max_swing}")

    def test_thermocline_gradient(self):
        """Temperature should decrease with depth through thermocline."""
        profile = THERMOCLINE_PROFILES["tropical"]
        temp_surface = calculate_temperature_at_depth(5.0, profile, 28.0, 0.0)
        temp_deep = calculate_temperature_at_depth(35.0, profile, 28.0, 0.0)
        self.assertGreater(temp_surface, temp_deep)


class TestProfileRealism(unittest.TestCase):
    """Integration tests for realistic dive profile generation."""

    def _make_single_tank(self):
        return [{"mix_id": "air", "volume": 0.0111, "role": "main",
                 "working_pressure": 200, "material": "aluminum"}]

    def test_descent_not_too_steep(self):
        """Descent rate should not exceed 18 m/min on average."""
        import random as rng
        rng.seed(42)
        profile, _, _ = generate_dive_profile(
            max_depth=30, duration_minutes=40, surface_temp=28, bottom_temp=24,
            tank_configs=self._make_single_tank(), site_type="reef",
            thermocline_profile=THERMOCLINE_PROFILES["tropical"],
        )
        target = 30 * 0.9
        for point in profile:
            if point["depth"] >= target:
                time_to_depth = point["divetime"]
                rate = (target / time_to_depth) * 60
                self.assertLess(rate, 18, f"Descent too steep: {rate:.1f} m/min")
                break

    def test_bottom_not_flat(self):
        """Bottom time should have meaningful depth variation."""
        import random as rng
        rng.seed(42)
        profile, _, _ = generate_dive_profile(
            max_depth=25, duration_minutes=45, surface_temp=28, bottom_temp=24,
            tank_configs=self._make_single_tank(), site_type="reef",
            thermocline_profile=THERMOCLINE_PROFILES["tropical"],
        )
        total = profile[-1]["divetime"]
        bottom_points = [p for p in profile if total * 0.2 < p["divetime"] < total * 0.7]
        if len(bottom_points) > 10:
            depths = [p["depth"] for p in bottom_points]
            depth_range = max(depths) - min(depths)
            self.assertGreater(depth_range, 1.0,
                               f"Bottom too flat: only {depth_range:.1f}m variation")

    def test_gas_consumption_not_linear(self):
        """Gas consumption rate should vary, not be perfectly linear."""
        import random as rng
        rng.seed(42)
        profile, _, _ = generate_dive_profile(
            max_depth=20, duration_minutes=40, surface_temp=28, bottom_temp=25,
            tank_configs=self._make_single_tank(), site_type="reef",
            thermocline_profile=THERMOCLINE_PROFILES["tropical"],
        )
        total = profile[-1]["divetime"]
        bottom_points = [p for p in profile if total * 0.2 < p["divetime"] < total * 0.7]
        if len(bottom_points) > 20:
            drops = []
            for i in range(1, len(bottom_points)):
                p_prev = bottom_points[i-1]["tankpressures"][0]["pressure"]
                p_curr = bottom_points[i]["tankpressures"][0]["pressure"]
                drops.append(p_prev - p_curr)
            if drops:
                avg_drop = sum(drops) / len(drops)
                variance = sum((d - avg_drop) ** 2 for d in drops) / len(drops)
                std_dev = variance ** 0.5
                if avg_drop > 0:
                    cv = std_dev / avg_drop
                    self.assertGreater(cv, 0.05, f"Gas consumption too linear: CV = {cv:.3f}")

    def test_dives_look_different(self):
        """Two dives at different seeds should have different profiles."""
        import random as rng
        tanks = self._make_single_tank()
        thermo = THERMOCLINE_PROFILES["tropical"]

        rng.seed(100)
        profile1, _, _ = generate_dive_profile(
            max_depth=25, duration_minutes=40, surface_temp=28, bottom_temp=24,
            tank_configs=tanks, site_type="reef", thermocline_profile=thermo,
        )

        rng.seed(200)
        profile2, _, _ = generate_dive_profile(
            max_depth=25, duration_minutes=40, surface_temp=28, bottom_temp=24,
            tank_configs=tanks, site_type="reef", thermocline_profile=thermo,
        )

        depths1 = [p["depth"] for p in profile1 if 120 < p["divetime"] < 1800]
        depths2 = [p["depth"] for p in profile2 if 120 < p["divetime"] < 1800]
        min_len = min(len(depths1), len(depths2))
        if min_len > 10:
            diffs = [abs(depths1[i] - depths2[i]) for i in range(min_len)]
            avg_diff = sum(diffs) / len(diffs)
            self.assertGreater(avg_diff, 0.5, f"Dives too similar: avg diff = {avg_diff:.2f}m")


if __name__ == "__main__":
    unittest.main()
