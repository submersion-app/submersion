# UDDF Test Data Generator Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve `scripts/generate_uddf_test_data.py` with 5-second sample intervals, realistic dive profiles (Perlin noise, micro-events, variable descent, workload-driven gas consumption), and PADI course generation with training dive linking.

**Architecture:** All changes are in a single Python script. New functions are added for Perlin noise, diver personality, micro-events, and course generation. The existing `generate_dive_profile()` function is refactored to use these new building blocks. The `generate_uddf()` function gains course output in the `<submersion>` extension section plus course-dive linking in dive elements.

**Tech Stack:** Python 3 stdlib only (`math`, `random`, `datetime`, `xml.etree.ElementTree`)

---

## File Structure

All changes are in a single file:

- **Modify:** `scripts/generate_uddf_test_data.py` -- the entire UDDF test data generator
- **Create:** `scripts/test_uddf_generator.py` -- unit tests for new functions

The script is ~2900 lines. New code adds approximately:
- ~60 lines for Perlin noise
- ~30 lines for diver personality
- ~80 lines for micro-events
- ~60 lines for descent improvements
- ~20 lines for temperature fix
- ~40 lines for gas consumption changes
- ~60 lines for course data + generation
- ~40 lines for UDDF course output

---

### Task 1: Sample Interval Default Change (10s to 5s)

**Files:**
- Modify: `scripts/generate_uddf_test_data.py:1545,2051,2871-2872`

- [ ] **Step 1: Change default in `generate_dive_profile()`**

In `scripts/generate_uddf_test_data.py`, line 1545, change:

```python
    sample_interval: int = 10,
```

to:

```python
    sample_interval: int = 5,
```

- [ ] **Step 2: Change default in `generate_uddf()`**

Line 2051, change:

```python
def generate_uddf(num_dives: int = 500, output_path: str = "test_data.uddf", sample_interval: int = 10, max_sites: int = None):
```

to:

```python
def generate_uddf(num_dives: int = 500, output_path: str = "test_data.uddf", sample_interval: int = 5, max_sites: int = None):
```

- [ ] **Step 3: Update help text and docstrings**

Line 2057, change:

```python
        sample_interval: Profile sample interval in seconds (10 for detailed, 30 for quick)
```

to:

```python
        sample_interval: Profile sample interval in seconds (5 for detailed, 30 for quick)
```

Line 2871-2872, change:

```python
        default=10,
        help="Profile sample interval in seconds (default: 10, use 30 for smaller files)"
```

to:

```python
        default=5,
        help="Profile sample interval in seconds (default: 5, use 30 for smaller files)"
```

- [ ] **Step 4: Verify script runs**

Run:
```bash
cd scripts && python generate_uddf_test_data.py --quick -o /tmp/test_quick.uddf
```

Expected: Script completes with no errors. Quick mode still uses 30s intervals (overrides default).

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_uddf_test_data.py
git commit -m "feat: change UDDF generator default sample interval from 10s to 5s"
```

---

### Task 2: Perlin Noise Implementation

**Files:**
- Modify: `scripts/generate_uddf_test_data.py` (add after `ease_in_out_cubic` function, around line 927)
- Create: `scripts/test_uddf_generator.py`

- [ ] **Step 1: Write tests for Perlin noise**

Create `scripts/test_uddf_generator.py`:

```python
#!/usr/bin/env python3
"""Tests for UDDF test data generator helper functions."""

import math
import sys
import os
import unittest

# Add scripts directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_uddf_test_data import PerlinNoise


class TestPerlinNoise(unittest.TestCase):
    """Test the 1D Perlin noise implementation."""

    def test_output_range(self):
        """Noise output should be in approximately [-1, 1] range."""
        noise = PerlinNoise(seed=42)
        values = [noise.noise(t * 0.1) for t in range(1000)]
        self.assertTrue(all(-1.5 <= v <= 1.5 for v in values),
                        f"Values out of range: min={min(values)}, max={max(values)}")

    def test_smoothness(self):
        """Adjacent samples should not have large jumps (smooth interpolation)."""
        noise = PerlinNoise(seed=42)
        step = 0.01
        for i in range(999):
            t1 = i * step
            t2 = (i + 1) * step
            diff = abs(noise.noise(t2) - noise.noise(t1))
            self.assertLess(diff, 0.2,
                            f"Jump too large at t={t1}: {diff}")

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
        differences = 0
        for t in [0.5, 1.5, 2.5, 3.5, 4.5]:
            if noise1.noise(t) != noise2.noise(t):
                differences += 1
        self.assertGreater(differences, 0)

    def test_non_periodic_over_dive_length(self):
        """Should not repeat within a typical dive duration (3600s at 0.02 frequency)."""
        noise = PerlinNoise(seed=42)
        # Sample at 0.02 frequency (typical use: time_seconds * 0.02)
        segment1 = [noise.noise(t * 0.02) for t in range(0, 300)]
        segment2 = [noise.noise(t * 0.02) for t in range(300, 600)]
        # Correlation between segments should be low
        self.assertNotEqual(segment1, segment2)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py -v 2>&1 | head -30
```

Expected: ImportError -- `PerlinNoise` does not exist yet.

- [ ] **Step 3: Implement PerlinNoise class**

In `scripts/generate_uddf_test_data.py`, add after the `ease_in_out_cubic` function (after line 926):

```python
class PerlinNoise:
    """Simple 1D gradient noise for organic, non-repeating variation.

    Uses a permutation table with gradient interpolation to produce
    smooth, continuous noise that doesn't repeat within typical dive durations.
    """

    def __init__(self, seed: int = 0, size: int = 256):
        rng = random.Random(seed)
        self._perm = list(range(size))
        rng.shuffle(self._perm)
        self._perm *= 2  # Double for wrapping
        self._gradients = [rng.uniform(-1, 1) for _ in range(size)]
        self._size = size

    def _fade(self, t: float) -> float:
        """Quintic smoothstep: 6t^5 - 15t^4 + 10t^3."""
        return t * t * t * (t * (t * 6 - 15) + 10)

    def noise(self, x: float) -> float:
        """Return noise value at position x, approximately in [-1, 1]."""
        xi = int(math.floor(x)) % self._size
        xf = x - math.floor(x)

        g0 = self._gradients[self._perm[xi]]
        g1 = self._gradients[self._perm[xi + 1]]

        d0 = g0 * xf
        d1 = g1 * (xf - 1)

        u = self._fade(xf)
        return d0 + u * (d1 - d0)
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestPerlinNoise -v
```

Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_uddf_test_data.py scripts/test_uddf_generator.py
git commit -m "feat: add Perlin noise implementation for organic depth variation"
```

---

### Task 3: Diver Personality and Breathing Oscillation

**Files:**
- Modify: `scripts/generate_uddf_test_data.py` (add after PerlinNoise class)
- Modify: `scripts/test_uddf_generator.py`

- [ ] **Step 1: Write tests**

Add to `scripts/test_uddf_generator.py`:

```python
from generate_uddf_test_data import DiverPersonality, breathing_oscillation


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
        early_skills = [DiverPersonality.generate(dive_number=i, total_dives=500).skill_level for i in range(1, 20)]
        late_skills = [DiverPersonality.generate(dive_number=i, total_dives=500).skill_level for i in range(480, 500)]
        self.assertGreater(sum(late_skills) / len(late_skills),
                           sum(early_skills) / len(early_skills))

    def test_descent_rate_varies_with_skill(self):
        """Experienced divers should have faster descent rates on average."""
        import random as rng
        rng.seed(42)
        novice = DiverPersonality(skill_level=0.2, activity_level=0.5)
        expert = DiverPersonality(skill_level=0.9, activity_level=0.5)
        # Novice range should center lower than expert range
        self.assertLess(novice.descent_rate_range[0], expert.descent_rate_range[0])


class TestBreathingOscillation(unittest.TestCase):
    """Test breathing oscillation function."""

    def test_amplitude_range(self):
        """Breathing oscillation should be within expected amplitude."""
        for skill in [0.2, 0.5, 0.9]:
            values = [breathing_oscillation(t, skill) for t in range(0, 600, 5)]
            max_amp = max(abs(v) for v in values)
            self.assertLess(max_amp, 0.5,
                            f"Breathing amplitude too large for skill {skill}: {max_amp}")

    def test_experienced_smaller_amplitude(self):
        """Higher skill level should produce smaller breathing oscillation."""
        novice_vals = [abs(breathing_oscillation(t, 0.2)) for t in range(0, 600, 5)]
        expert_vals = [abs(breathing_oscillation(t, 0.9)) for t in range(0, 600, 5)]
        self.assertGreater(max(novice_vals), max(expert_vals))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestDiverPersonality -v 2>&1 | head -20
```

Expected: ImportError -- `DiverPersonality` not found.

- [ ] **Step 3: Implement DiverPersonality and breathing_oscillation**

Add after the `PerlinNoise` class in `scripts/generate_uddf_test_data.py`:

```python
class DiverPersonality:
    """Per-dive randomized diver behavior parameters.

    Affects depth-holding stability, descent speed, SAC rate and consistency,
    and micro-event frequency. Skill trends upward over the diver's career.
    """

    def __init__(self, skill_level: float, activity_level: float):
        self.skill_level = max(0.0, min(1.0, skill_level))
        self.activity_level = max(0.0, min(1.0, activity_level))

    @staticmethod
    def generate(dive_number: int, total_dives: int) -> "DiverPersonality":
        """Generate personality with skill trending upward over career."""
        # Base skill from career progression (0.2 -> 0.9 over career)
        progress = dive_number / max(1, total_dives)
        base_skill = 0.2 + progress * 0.7
        # Add per-dive jitter (+/- 0.1)
        skill = base_skill + random.uniform(-0.1, 0.1)
        activity = random.uniform(0.2, 0.9)
        return DiverPersonality(skill_level=skill, activity_level=activity)

    @property
    def noise_amplitude(self) -> float:
        """Depth-holding noise amplitude in meters. Less skilled = more wobble."""
        return 0.4 + (1.0 - self.skill_level) * 1.2  # 0.4m (expert) to 1.6m (novice)

    @property
    def descent_rate_range(self) -> Tuple[float, float]:
        """Descent rate range in m/min. Novices descend slower."""
        min_rate = 6 + self.skill_level * 4    # 6-10 m/min
        max_rate = 10 + self.skill_level * 5   # 10-15 m/min
        return (min_rate, max_rate)

    @property
    def ascent_rate(self) -> float:
        """Ascent rate in m/min. Slightly variable, always safe."""
        return random.uniform(6, 9)

    @property
    def base_sac(self) -> float:
        """Base SAC rate in L/min. Experienced divers consume less air."""
        # 22 L/min (novice) down to 12 L/min (expert)
        return 22 - self.skill_level * 10 + random.uniform(-1.0, 1.0)

    @property
    def sac_consistency(self) -> float:
        """How consistent SAC is. 0.0 = very variable, 1.0 = rock steady."""
        return 0.3 + self.skill_level * 0.6  # 0.3 (novice) to 0.9 (expert)

    @property
    def eq_pause_count(self) -> int:
        """Number of equalization pauses during descent in first 10m."""
        max_pauses = max(0, int(3 - self.skill_level * 2.5))
        return random.randint(0, max(0, max_pauses))

    @property
    def micro_event_count(self) -> int:
        """Number of depth excursion events per depth level."""
        base = 2 + int(self.activity_level * 4)  # 2-6
        return random.randint(max(1, base - 1), base + 1)


def breathing_oscillation(time_seconds: float, skill_level: float,
                          breath_rate: float = None) -> float:
    """Simulate breathing-induced depth oscillation.

    Args:
        time_seconds: Current time in seconds.
        skill_level: 0.0 (novice) to 1.0 (expert).
        breath_rate: Breaths per minute. If None, randomized 12-18.

    Returns:
        Depth variation in meters from breathing (typically +/- 0.2 to 0.4m).
    """
    if breath_rate is None:
        # Seeded from skill so it's consistent within a dive but varies between dives
        breath_rate = 18 - skill_level * 6  # 18 (novice) to 12 (expert)
    amplitude = 0.4 - skill_level * 0.2  # 0.4m (novice) to 0.2m (expert)
    return amplitude * math.sin(2 * math.pi * (breath_rate / 60) * time_seconds)
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestDiverPersonality test_uddf_generator.py::TestBreathingOscillation -v
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_uddf_test_data.py scripts/test_uddf_generator.py
git commit -m "feat: add DiverPersonality and breathing oscillation for profile variety"
```

---

### Task 4: Micro-Events System

**Files:**
- Modify: `scripts/generate_uddf_test_data.py` (add after `breathing_oscillation`)
- Modify: `scripts/test_uddf_generator.py`

- [ ] **Step 1: Write tests**

Add to `scripts/test_uddf_generator.py`:

```python
from generate_uddf_test_data import generate_micro_events, apply_micro_event


class TestMicroEvents(unittest.TestCase):
    """Test micro-event generation and application."""

    def test_event_count_in_range(self):
        """Should generate reasonable number of events."""
        import random as rng
        rng.seed(42)
        events = generate_micro_events(
            level_start_time=60,
            level_duration=600,
            target_depth=20.0,
            activity_level=0.5,
            max_depth=25.0,
        )
        self.assertTrue(1 <= len(events) <= 8)

    def test_events_within_time_range(self):
        """All events should start within the level's time range."""
        import random as rng
        rng.seed(42)
        events = generate_micro_events(
            level_start_time=100,
            level_duration=500,
            target_depth=20.0,
            activity_level=0.8,
            max_depth=25.0,
        )
        for event in events:
            self.assertGreaterEqual(event["start_time"], 100)
            self.assertLessEqual(event["start_time"], 600)

    def test_event_depth_offset_reasonable(self):
        """Event depth offsets should not exceed specified bounds."""
        import random as rng
        rng.seed(42)
        for _ in range(50):
            events = generate_micro_events(
                level_start_time=0,
                level_duration=600,
                target_depth=20.0,
                activity_level=0.9,
                max_depth=25.0,
            )
            for event in events:
                self.assertLessEqual(abs(event["depth_offset"]), 5.0)

    def test_apply_returns_zero_outside_event(self):
        """apply_micro_event should return 0 when time is outside event window."""
        event = {
            "start_time": 100,
            "duration": 30,
            "depth_offset": -2.0,
            "event_type": "look_below",
        }
        self.assertAlmostEqual(apply_micro_event(event, 50), 0.0)
        self.assertAlmostEqual(apply_micro_event(event, 200), 0.0)

    def test_apply_returns_nonzero_during_event(self):
        """apply_micro_event should return a depth offset during the event."""
        event = {
            "start_time": 100,
            "duration": 30,
            "depth_offset": -2.0,
            "event_type": "look_below",
        }
        offset = apply_micro_event(event, 115)
        self.assertNotAlmostEqual(offset, 0.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestMicroEvents -v 2>&1 | head -20
```

Expected: ImportError.

- [ ] **Step 3: Implement micro-events**

Add after `breathing_oscillation` in `scripts/generate_uddf_test_data.py`:

```python
# Micro-event types with behavior descriptors
MICRO_EVENT_TYPES = [
    {"type": "look_below", "direction": -1, "depth_range": (1, 3), "duration_range": (25, 50)},
    {"type": "check_above", "direction": 1, "depth_range": (1, 3), "duration_range": (20, 40)},
    {"type": "buoyancy_adj", "direction": 1, "depth_range": (0.3, 0.8), "duration_range": (10, 25)},
    {"type": "terrain_feature", "direction": -1, "depth_range": (2, 4), "duration_range": (60, 120)},
]


def generate_micro_events(
    level_start_time: float,
    level_duration: float,
    target_depth: float,
    activity_level: float,
    max_depth: float,
) -> List[Dict]:
    """Generate randomized depth excursion events for a depth level.

    Args:
        level_start_time: Seconds from dive start when this level begins.
        level_duration: Duration of this depth level in seconds.
        target_depth: Target depth of this level in meters.
        activity_level: 0.0-1.0, controls event frequency.
        max_depth: Maximum allowed depth for this dive.

    Returns:
        List of event dicts with start_time, duration, depth_offset, event_type.
    """
    num_events = max(1, int(2 + activity_level * 4 + random.uniform(-1, 1)))
    # Don't pack too many events into short levels
    num_events = min(num_events, max(1, int(level_duration / 60)))

    events = []
    # Spread events randomly across the level duration with some spacing
    available_slots = []
    slot_size = level_duration / max(1, num_events + 1)
    for i in range(num_events):
        slot_start = level_start_time + (i + 0.5) * slot_size
        jitter = random.uniform(-slot_size * 0.3, slot_size * 0.3)
        event_time = max(level_start_time, slot_start + jitter)
        available_slots.append(event_time)

    for event_time in available_slots:
        template = random.choice(MICRO_EVENT_TYPES)
        depth_mag = random.uniform(*template["depth_range"])
        duration = random.uniform(*template["duration_range"])

        # Determine direction: ensure we don't exceed max depth
        direction = template["direction"]
        depth_offset = direction * depth_mag

        # Clamp: don't descend beyond max_depth or ascend above 3m
        if target_depth + depth_offset > max_depth + 1:
            depth_offset = max_depth - target_depth
        if target_depth + depth_offset < 3:
            depth_offset = 3 - target_depth

        events.append({
            "start_time": event_time,
            "duration": duration,
            "depth_offset": depth_offset,
            "event_type": template["type"],
        })

    return events


def apply_micro_event(event: Dict, current_time: float) -> float:
    """Calculate depth offset from a micro-event at the given time.

    Uses a smooth bell curve (raised cosine) so the diver eases into
    and out of the excursion naturally.

    Args:
        event: Event dict from generate_micro_events.
        current_time: Current dive time in seconds.

    Returns:
        Depth offset in meters (negative = deeper, positive = shallower).
    """
    start = event["start_time"]
    end = start + event["duration"]

    if current_time < start or current_time > end:
        return 0.0

    # Raised cosine envelope: smooth bell curve
    progress = (current_time - start) / event["duration"]
    envelope = (1 - math.cos(2 * math.pi * progress)) / 2
    return event["depth_offset"] * envelope
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestMicroEvents -v
```

Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_uddf_test_data.py scripts/test_uddf_generator.py
git commit -m "feat: add micro-event system for purposeful depth excursions"
```

---

### Task 5: Temperature Fix

**Files:**
- Modify: `scripts/generate_uddf_test_data.py:247-283` (`calculate_temperature_at_depth` function)

- [ ] **Step 1: Write test**

Add to `scripts/test_uddf_generator.py`:

```python
from generate_uddf_test_data import calculate_temperature_at_depth, THERMOCLINE_PROFILES


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
        """Small depth changes should not cause large temperature swings."""
        profile = THERMOCLINE_PROFILES["tropical"]
        temp_offset = 0.0
        temps = []
        for d in [20.0, 20.5, 21.0, 20.5, 20.0, 20.3, 19.8]:
            temps.append(calculate_temperature_at_depth(d, profile, 28.0, temp_offset))
        max_swing = max(temps) - min(temps)
        # At 20m (below thermocline), 1m depth change should cause <0.3C change
        self.assertLess(max_swing, 0.5,
                        f"Temperature swings too much over 1m depth changes: {max_swing}")

    def test_thermocline_gradient(self):
        """Temperature should decrease with depth through thermocline."""
        profile = THERMOCLINE_PROFILES["tropical"]
        temp_surface = calculate_temperature_at_depth(5.0, profile, 28.0, 0.0)
        temp_deep = calculate_temperature_at_depth(35.0, profile, 28.0, 0.0)
        self.assertGreater(temp_surface, temp_deep)
```

- [ ] **Step 2: Run tests -- the oscillation test should fail with current code**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestTemperatureFix -v
```

Expected: `test_no_depth_correlated_oscillation` may fail (the sine noise causes > 0.5C swings) or pass depending on seed alignment. The test documents the correct behavior either way.

- [ ] **Step 3: Fix `calculate_temperature_at_depth`**

In `scripts/generate_uddf_test_data.py`, replace the `calculate_temperature_at_depth` function (lines 247-283) with:

```python
def calculate_temperature_at_depth(
    depth: float,
    profile: Dict,
    surface_temp: float,
    temp_offset: float = 0.0
) -> float:
    """
    Calculate water temperature at a given depth with thermocline modeling.

    Uses smooth S-curve transition through the thermocline zone.
    Temperature is purely depth-dependent (stratified) with only a small
    per-dive offset for day-to-day variation.

    Args:
        depth: Current depth in meters.
        profile: Thermocline profile dict.
        surface_temp: Surface water temperature in Celsius.
        temp_offset: Per-dive temperature offset in Celsius (+/- 0.2 typical).

    Returns:
        Temperature in Celsius at the given depth.
    """
    thermo_start = profile["thermocline_start"]
    thermo_thick = profile["thermocline_thickness"]
    temp_drop = profile["temp_drop"]
    deep_grad = profile["deep_gradient"]
    thermo_end = thermo_start + thermo_thick

    # Tiny random sensor noise (not depth-correlated)
    sensor_noise = random.uniform(-0.05, 0.05)

    if depth < thermo_start:
        # Surface layer - stable temperature
        return surface_temp + temp_offset + sensor_noise
    elif depth < thermo_end:
        # Thermocline transition - smooth S-curve
        progress = (depth - thermo_start) / thermo_thick
        t = progress * math.pi
        smooth = (1 - math.cos(t)) / 2  # 0 to 1 smoothly
        temp = surface_temp - (temp_drop * smooth)
        return temp + temp_offset + sensor_noise
    else:
        # Below thermocline - gradual cooling (or warming for cenotes)
        base_temp = surface_temp - temp_drop
        extra_depth = depth - thermo_end
        temp = base_temp - (extra_depth * deep_grad)
        return temp + temp_offset + sensor_noise
```

- [ ] **Step 4: Update callers to pass `temp_offset` instead of `variation_seed`**

In `generate_uddf()`, where `calculate_temperature_at_depth` is called for bottom temp reference (around line 2376-2378), change:

```python
        bottom_temp = calculate_temperature_at_depth(
            max_depth, thermocline_profile, surface_temp, random.uniform(0, 1000)
        )
```

to:

```python
        # Per-dive temperature offset for day-to-day variation
        temp_offset = random.uniform(-0.2, 0.2)
        bottom_temp = calculate_temperature_at_depth(
            max_depth, thermocline_profile, surface_temp, temp_offset
        )
```

In `generate_dive_profile()`, update the temperature calculation section (around lines 1846-1856). Change:

```python
        if thermocline_profile is not None:
            # Use realistic thermocline model
            current_temp = calculate_temperature_at_depth(
                current_depth, thermocline_profile, surface_temp, variation_seed
            )
        else:
            # Fallback to simple linear gradient
            temp_gradient = (surface_temp - bottom_temp) / max(max_depth, 1)
            current_temp = surface_temp - (temp_gradient * current_depth)
            current_temp += random.uniform(-0.2, 0.2)
```

to:

```python
        if thermocline_profile is not None:
            current_temp = calculate_temperature_at_depth(
                current_depth, thermocline_profile, surface_temp, temp_offset
            )
        else:
            temp_gradient = (surface_temp - bottom_temp) / max(max_depth, 1)
            current_temp = surface_temp - (temp_gradient * current_depth)
            current_temp += random.uniform(-0.05, 0.05)
```

Also add `temp_offset` as a parameter to `generate_dive_profile()` -- add it after `sample_interval`:

```python
    temp_offset: float = 0.0,
```

And update the call in `generate_uddf()` (around line 2425-2436) to pass it:

```python
        profile, gas_switches, final_tissue = generate_dive_profile(
            max_depth=max_depth,
            duration_minutes=duration,
            surface_temp=surface_temp,
            bottom_temp=bottom_temp,
            tank_configs=tank_config,
            is_tech=is_tech,
            site_type=site_type,
            thermocline_profile=thermocline_profile,
            tissue_state=dive_session.tissue if dive_session.dive_count_today > 0 else None,
            sample_interval=sample_interval,
            temp_offset=temp_offset,
        )
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestTemperatureFix -v
```

Expected: All 3 tests pass.

- [ ] **Step 6: Run quick generation to verify no breakage**

Run:
```bash
cd scripts && python generate_uddf_test_data.py --quick -o /tmp/test_temp_fix.uddf
```

Expected: Completes successfully.

- [ ] **Step 7: Commit**

```bash
git add scripts/generate_uddf_test_data.py scripts/test_uddf_generator.py
git commit -m "fix: make temperature depth-stratified instead of oscillating with depth"
```

---

### Task 6: Replace `depth_variation` and Refactor Profile Generation

This is the core change -- replacing the old sine-based depth model with Perlin noise, micro-events, breathing oscillation, variable descent, and improved bottom time. This modifies `generate_dive_profile()` substantially.

**Files:**
- Modify: `scripts/generate_uddf_test_data.py:929-949` (remove old `depth_variation`), `1533-1975` (refactor `generate_dive_profile`)
- Modify: `scripts/test_uddf_generator.py`

- [ ] **Step 1: Write integration test for profile realism**

Add to `scripts/test_uddf_generator.py`:

```python
from generate_uddf_test_data import generate_dive_profile, THERMOCLINE_PROFILES, GAS_MIXES


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
        # Find time to reach 90% of max depth
        target = 30 * 0.9
        for point in profile:
            if point["depth"] >= target:
                time_to_depth = point["divetime"]
                rate = (target / time_to_depth) * 60  # m/min
                self.assertLess(rate, 18,
                                f"Descent too steep: {rate:.1f} m/min")
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
        # Extract bottom phase points (after descent, before ascent)
        total = profile[-1]["divetime"]
        bottom_points = [p for p in profile
                         if total * 0.2 < p["divetime"] < total * 0.7]
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
        # Get pressure drops between consecutive points during bottom phase
        total = profile[-1]["divetime"]
        bottom_points = [p for p in profile
                         if total * 0.2 < p["divetime"] < total * 0.7]
        if len(bottom_points) > 20:
            drops = []
            for i in range(1, len(bottom_points)):
                p_prev = bottom_points[i-1]["tankpressures"][0]["pressure"]
                p_curr = bottom_points[i]["tankpressures"][0]["pressure"]
                drops.append(p_prev - p_curr)
            # Check variance of consumption rate
            if drops:
                avg_drop = sum(drops) / len(drops)
                variance = sum((d - avg_drop) ** 2 for d in drops) / len(drops)
                std_dev = variance ** 0.5
                # Coefficient of variation should be > 5% (not perfectly linear)
                if avg_drop > 0:
                    cv = std_dev / avg_drop
                    self.assertGreater(cv, 0.05,
                                       f"Gas consumption too linear: CV = {cv:.3f}")

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

        # Compare bottom phase depth patterns
        depths1 = [p["depth"] for p in profile1 if p["divetime"] > 120 and p["divetime"] < 1800]
        depths2 = [p["depth"] for p in profile2 if p["divetime"] > 120 and p["divetime"] < 1800]
        min_len = min(len(depths1), len(depths2))
        if min_len > 10:
            diffs = [abs(depths1[i] - depths2[i]) for i in range(min_len)]
            avg_diff = sum(diffs) / len(diffs)
            self.assertGreater(avg_diff, 0.5,
                               f"Dives too similar: avg depth diff = {avg_diff:.2f}m")
```

- [ ] **Step 2: Run tests (some will fail with current code)**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestProfileRealism -v
```

Expected: `test_bottom_not_flat` and `test_gas_consumption_not_linear` likely fail with current code.

- [ ] **Step 3: Remove old `depth_variation` function**

Delete the `depth_variation` function (lines 929-949 in the original file -- exact line numbers may have shifted after earlier tasks). This is the sine-wave stack that gets replaced by Perlin noise:

```python
# DELETE this entire function:
def depth_variation(time_seconds: float, amplitude: float = 2.0, seed: float = 0.0) -> float:
    ...
```

- [ ] **Step 4: Add `personality` and `temp_offset` parameters to `generate_dive_profile`**

Update the function signature. After the existing `sample_interval` parameter (and the `temp_offset` added in Task 5), add:

```python
    personality: DiverPersonality = None,
```

At the top of the function body, after `profile_points = []`, add:

```python
    # Create personality if not provided
    if personality is None:
        personality = DiverPersonality(skill_level=0.5, activity_level=0.5)

    # Create Perlin noise generator for this dive
    perlin = PerlinNoise(seed=random.randint(0, 100000))

    # Breathing parameters for this dive
    breath_rate = 18 - personality.skill_level * 6 + random.uniform(-1, 1)
```

- [ ] **Step 5: Refactor descent phase**

Replace the descent phase code (currently around the `if dive_phase == "descent":` block) with:

```python
        if dive_phase == "descent":
            target_depth_descent = level_depths[0] if level_depths else max_depth

            if current_time < descent_time_seconds:
                progress = current_time / descent_time_seconds

                # Check for equalization pauses in first 10m
                estimated_depth = target_depth_descent * progress
                in_eq_pause = False
                if estimated_depth < 10 and hasattr(personality, '_eq_pauses'):
                    for pause_depth, pause_start, pause_dur in personality._eq_pauses:
                        if pause_start <= current_time < pause_start + pause_dur:
                            current_depth = pause_depth
                            in_eq_pause = True
                            break

                if not in_eq_pause:
                    # Variable descent with segments between pauses
                    eased_progress = ease_in_out_cubic(progress)
                    current_depth = target_depth_descent * eased_progress
                    # Add slight wobble during descent (nervous beginner or current)
                    current_depth += perlin.noise(current_time * 0.05) * personality.noise_amplitude * 0.3
            else:
                dive_phase = "bottom"
                level_start_time = current_time
                current_depth = level_depths[0] if level_depths else max_depth
```

Before the main while loop, generate equalization pauses and store on personality:

```python
    # Pre-generate equalization pauses for descent
    eq_pauses = []
    num_eq_pauses = personality.eq_pause_count
    if num_eq_pauses > 0 and descent_time_seconds > 20:
        for i in range(num_eq_pauses):
            pause_depth = random.uniform(3, 9)
            pause_progress = pause_depth / (level_depths[0] if level_depths else max_depth)
            pause_start = pause_progress * descent_time_seconds
            pause_dur = random.uniform(3, 8)
            eq_pauses.append((pause_depth, pause_start, pause_dur))
    personality._eq_pauses = eq_pauses

    # Buddy check pause
    buddy_check_pause = None
    if random.random() < 0.3:
        buddy_check_pause = (random.uniform(3, 5), random.uniform(5, 10))  # (depth, duration)

    # Pre-generate micro-events for each depth level
    all_level_events = []
    level_start_est = descent_time_seconds
    for lvl_idx, lvl_depth in enumerate(level_depths):
        lvl_dur = time_per_level  # Will use weighted version below
        events = generate_micro_events(
            level_start_time=level_start_est,
            level_duration=lvl_dur,
            target_depth=lvl_depth,
            activity_level=personality.activity_level,
            max_depth=max_depth,
        )
        all_level_events.append(events)
        level_start_est += lvl_dur

    # Pre-generate exertion spikes for gas consumption
    num_spikes = random.randint(2, 4)
    exertion_spikes = []
    for _ in range(num_spikes):
        spike_start = random.uniform(descent_time_seconds, total_seconds * 0.8)
        spike_duration = random.uniform(30, 60)
        spike_magnitude = random.uniform(1.2, 1.4)
        exertion_spikes.append((spike_start, spike_duration, spike_magnitude))
```

- [ ] **Step 6: Refactor bottom phase**

Replace the bottom phase code with:

```python
        elif dive_phase == "bottom":
            target_depth = level_depths[level_index] if level_index < len(level_depths) else level_depths[-1]
            time_at_level = current_time - level_start_time

            # Dynamic level timing: deeper levels get more time
            # Weight: first level 50%, second 30%, rest 20%
            if len(level_depths) > 1:
                weights = []
                for li in range(len(level_depths)):
                    if li == 0:
                        weights.append(0.5)
                    elif li == 1:
                        weights.append(0.3)
                    else:
                        weights.append(0.2 / max(1, len(level_depths) - 2))
                total_weight = sum(weights)
                weights = [w / total_weight for w in weights]
                current_level_duration = available_bottom_time * weights[min(level_index, len(weights) - 1)]
                # Add jitter
                current_level_duration *= random.uniform(0.9, 1.1)
            else:
                current_level_duration = available_bottom_time

            if time_at_level >= current_level_duration:
                if level_index < len(level_depths) - 1:
                    level_index += 1
                    level_start_time = current_time
                    target_depth = level_depths[level_index]
                else:
                    dive_phase = "ascent"

            if dive_phase == "bottom":
                # Depth band: target +/- band_width (site-type dependent)
                band_width = 2.0  # default reef
                if site_type == "wall":
                    band_width = 1.0
                elif site_type == "manta":
                    band_width = 0.5
                elif site_type == "drift":
                    band_width = 3.0
                elif site_type == "wreck":
                    band_width = 1.5

                # Base depth from Perlin noise within band
                noise_val = perlin.noise(current_time * 0.015) * band_width
                current_depth = target_depth + noise_val

                # Add breathing oscillation
                current_depth += breathing_oscillation(current_time, personality.skill_level, breath_rate)

                # Apply micro-events
                if level_index < len(all_level_events):
                    for event in all_level_events[level_index]:
                        current_depth += apply_micro_event(event, current_time)

                # Smooth transition between levels
                if level_index > 0 and time_at_level < 90:
                    prev_depth = level_depths[level_index - 1]
                    transition_duration = random.uniform(30, 180) if not hasattr(personality, '_transition_dur') else personality._transition_dur
                    transition_progress = min(1.0, time_at_level / transition_duration)
                    eased = ease_in_out_cubic(transition_progress)
                    blend_depth = prev_depth + (target_depth - prev_depth) * eased
                    current_depth = blend_depth + noise_val * transition_progress

                # Clamp
                current_depth = max(3, min(max_depth + 2, current_depth))
```

- [ ] **Step 7: Refactor ascent phase**

Update the ascent phase to use Perlin noise for safety stop variation and add the post-safety-stop pause. Replace the safety stop holding depth line:

```python
                    current_depth = safety_stop_depth + random.uniform(-0.3, 0.3)
```

with:

```python
                    current_depth = safety_stop_depth + perlin.noise(current_time * 0.1) * 0.5
```

Replace the ascent rate calculation. Change:

```python
            max_ascent = (ascent_rate / 60) * sample_interval
```

to:

```python
            max_ascent = (personality.ascent_rate / 60) * sample_interval
```

After the safety stop completion block, add post-safety-stop pause logic. After the line `current_depth = max(0, current_depth - max_ascent)` in the final ascent section, add a check:

```python
                        # Post-safety-stop pause at 3m (~40% of dives)
                        if not hasattr(personality, '_post_stop_done'):
                            personality._post_stop_done = False
                            personality._do_post_stop = random.random() < 0.4
                            personality._post_stop_start = None

                        if personality._do_post_stop and not personality._post_stop_done:
                            if current_depth <= 3.5 and current_depth > 0.5:
                                if personality._post_stop_start is None:
                                    personality._post_stop_start = current_time
                                post_stop_elapsed = current_time - personality._post_stop_start
                                if post_stop_elapsed < random.uniform(10, 20):
                                    current_depth = 3.0 + perlin.noise(current_time * 0.1) * 0.3
                                else:
                                    personality._post_stop_done = True
```

- [ ] **Step 8: Refactor gas consumption**

Replace the SAC modifier section (around lines 1864-1871) with workload-driven SAC:

```python
        # Workload-driven SAC modifier
        if dive_phase == "descent":
            sac_modifier = 1.15 + (1.0 - personality.skill_level) * 0.1
        elif is_ascending:
            sac_modifier = 0.85 + random.uniform(-0.05, 0.05)
        else:
            # Base: steady hovering
            sac_modifier = 1.0

            # Depth change effort: more consumption when moving vertically
            if len(profile_points) >= 2:
                prev_depth = profile_points[-1]["depth"]
                depth_change_rate = abs(current_depth - prev_depth) / sample_interval * 60  # m/min
                sac_modifier += depth_change_rate * 0.03  # ~3% per m/min of vertical movement

            # Micro-event activity boost
            if level_index < len(all_level_events):
                for event in all_level_events[level_index]:
                    event_offset = apply_micro_event(event, current_time)
                    if abs(event_offset) > 0.1:
                        sac_modifier += 0.15  # 15% boost during active exploration
                        break

            # Exertion spikes
            for spike_start, spike_dur, spike_mag in exertion_spikes:
                if spike_start <= current_time < spike_start + spike_dur:
                    sac_modifier *= spike_mag
                    break

            # Skill-based random variation
            sac_jitter = random.uniform(-0.08, 0.08) * (1.0 - personality.sac_consistency)
            sac_modifier += sac_jitter
```

Also update base SAC initialization. Replace the existing base_sac line:

```python
    base_sac = random.uniform(13, 16) if is_tech else random.uniform(15, 19)
```

with:

```python
    base_sac = personality.base_sac if not is_tech else random.uniform(12, 15)
```

- [ ] **Step 9: Add dive variety features**

Near the top of `generate_dive_profile()`, after `total_seconds = duration_minutes * 60`, add:

```python
    # Depth target variety: +/- 5-10% jitter on actual max depth
    depth_jitter = random.uniform(-0.10, 0.05)
    max_depth = max_depth * (1.0 + depth_jitter)
    max_depth = max(5, max_depth)
```

Add anomaly generation before the main while loop:

```python
    # Occasional anomalies
    buoyancy_slip_time = None
    if random.random() < 0.05:  # 5% chance
        buoyancy_slip_time = random.uniform(descent_time_seconds + 60, total_seconds * 0.6)

    early_termination = False
    if random.random() < 0.03:  # 3% chance
        early_term_factor = random.uniform(0.7, 0.8)
        total_seconds = int(total_seconds * early_term_factor)

    extra_long_eq_pause = random.random() < 0.10  # 10% chance
    if extra_long_eq_pause and eq_pauses:
        # Make one equalization pause extra long
        idx = random.randint(0, len(eq_pauses) - 1)
        d, s, dur = eq_pauses[idx]
        eq_pauses[idx] = (d, s, dur + random.uniform(8, 15))
```

Inside the bottom phase, after clamping, add buoyancy slip handling:

```python
                # Buoyancy slip anomaly
                if buoyancy_slip_time is not None:
                    slip_window = 15  # seconds
                    if buoyancy_slip_time <= current_time < buoyancy_slip_time + slip_window:
                        slip_progress = (current_time - buoyancy_slip_time) / slip_window
                        if slip_progress < 0.3:
                            current_depth -= 2.5 * (slip_progress / 0.3)  # rapid rise
                        else:
                            current_depth -= 2.5 * (1.0 - (slip_progress - 0.3) / 0.7)  # recover
                        current_depth = max(3, current_depth)
```

- [ ] **Step 10: Update `generate_uddf()` to pass personality**

In the dive generation loop in `generate_uddf()`, before the call to `generate_dive_profile()`, add:

```python
        # Generate diver personality for this dive
        personality = DiverPersonality.generate(dive_number=dive_idx, total_dives=num_dives)
```

Update the `generate_dive_profile()` call to include the new parameter:

```python
        profile, gas_switches, final_tissue = generate_dive_profile(
            max_depth=max_depth,
            duration_minutes=duration,
            surface_temp=surface_temp,
            bottom_temp=bottom_temp,
            tank_configs=tank_config,
            is_tech=is_tech,
            site_type=site_type,
            thermocline_profile=thermocline_profile,
            tissue_state=dive_session.tissue if dive_session.dive_count_today > 0 else None,
            sample_interval=sample_interval,
            temp_offset=temp_offset,
            personality=personality,
        )
```

- [ ] **Step 11: Remove any remaining references to old `depth_variation` function**

Search for any remaining calls to `depth_variation` in the file and remove or replace them. There was one call in the original SAC modifier section:

```python
            sac_modifier = 1.0 + depth_variation(current_time, amplitude=0.1, seed=variation_seed + 500)
```

This should now be replaced by the workload-driven SAC code from Step 8. Also remove the `variation_seed` variable assignment if no longer used:

```python
    # Remove this line:
    variation_seed = random.uniform(0, 1000)
```

- [ ] **Step 12: Run all tests**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py -v
```

Expected: All tests pass.

- [ ] **Step 13: Run quick generation and verify output**

Run:
```bash
cd scripts && python generate_uddf_test_data.py --quick -o /tmp/test_profiles.uddf
```

Expected: Script completes successfully.

- [ ] **Step 14: Commit**

```bash
git add scripts/generate_uddf_test_data.py scripts/test_uddf_generator.py
git commit -m "feat: replace sine-wave depth model with Perlin noise, micro-events, and workload-driven gas

Addresses profile realism: organic depth variation, variable descent with
equalization pauses, depth bands with micro-events, breathing oscillation,
workload-driven gas consumption, and per-dive personality for variety."
```

---

### Task 7: Site-Type Depth Band Differentiation

**Files:**
- Modify: `scripts/generate_uddf_test_data.py` (the site-type profile section in `generate_dive_profile`)

- [ ] **Step 1: Update site-type level generation for distinct behaviors**

The existing site-type `level_depths` generation (around lines 1656-1713) already generates different depth levels. Update the micro-event generation to vary by site type. After the `all_level_events` generation loop, add site-type modifiers:

```python
    # Site-type specific micro-event adjustments
    if site_type == "wall":
        # Fewer events, diver hovers along wall
        for events in all_level_events:
            while len(events) > 2:
                events.pop()
    elif site_type == "manta":
        # Minimal events, diver stays still at cleaning station
        for events in all_level_events:
            while len(events) > 1:
                events.pop()
            for e in events:
                e["depth_offset"] *= 0.3  # Reduce magnitude
    elif site_type == "reef":
        # Most events -- already at max from activity_level
        pass
    elif site_type == "drift":
        # Replace some events with long gradual terrain-following
        for events in all_level_events:
            for e in events:
                e["duration"] = max(e["duration"], 60)  # At least 60s
                e["depth_offset"] *= 0.7  # Gentler changes
    elif site_type == "wreck":
        # Sharper transitions (entering/exiting compartments)
        for events in all_level_events:
            for e in events:
                e["duration"] = max(15, e["duration"] * 0.6)  # Quicker transitions
```

- [ ] **Step 2: Run tests and quick generation**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py -v && python generate_uddf_test_data.py --quick -o /tmp/test_sites.uddf
```

Expected: All tests pass and script completes.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_uddf_test_data.py
git commit -m "feat: differentiate dive profiles by site type (wall, reef, wreck, drift, manta)"
```

---

### Task 8: Course Data and Generation

**Files:**
- Modify: `scripts/generate_uddf_test_data.py` (add `PADI_COURSES` after `PADI_CERTIFICATIONS`, add course generation logic)
- Modify: `scripts/test_uddf_generator.py`

- [ ] **Step 1: Write tests for course data**

Add to `scripts/test_uddf_generator.py`:

```python
from generate_uddf_test_data import PADI_COURSES, PADI_CERTIFICATIONS, generate_training_dives


class TestCourseGeneration(unittest.TestCase):
    """Test PADI course data and training dive generation."""

    def test_every_cert_has_course(self):
        """Each certification should have a corresponding course."""
        cert_ids = {c["id"] for c in PADI_CERTIFICATIONS}
        course_cert_ids = {c["certification_id"] for c in PADI_COURSES}
        # Every cert referenced by a course should exist
        for cid in course_cert_ids:
            self.assertIn(cid, cert_ids, f"Course references missing cert: {cid}")

    def test_course_dates_before_cert(self):
        """Course start date should be before certification date."""
        cert_dates = {c["id"]: c["date"] for c in PADI_CERTIFICATIONS}
        for course in PADI_COURSES:
            cert_date = cert_dates.get(course["certification_id"])
            if cert_date:
                from datetime import datetime
                c_date = datetime.strptime(cert_date, "%Y-%m-%d")
                s_date = c_date - timedelta(days=course["course_duration_days"])
                self.assertLess(s_date, c_date)

    def test_training_dives_count(self):
        """generate_training_dives should return correct number of dives."""
        import random as rng
        rng.seed(42)
        course = PADI_COURSES[0]  # Open Water
        dives = generate_training_dives(course, dive_start_index=0)
        self.assertEqual(len(dives), course["num_training_dives"])

    def test_training_dives_in_date_range(self):
        """Training dives should fall within course date range."""
        import random as rng
        rng.seed(42)
        from datetime import datetime
        course = PADI_COURSES[0]
        cert = next(c for c in PADI_CERTIFICATIONS if c["id"] == course["certification_id"])
        completion = datetime.strptime(cert["date"], "%Y-%m-%d")
        start = completion - timedelta(days=course["course_duration_days"])

        dives = generate_training_dives(course, dive_start_index=0)
        for dive in dives:
            self.assertGreaterEqual(dive["datetime"], start)
            self.assertLessEqual(dive["datetime"], completion)

    def test_training_dive_depth_appropriate(self):
        """Training dives should not exceed course max depth."""
        import random as rng
        rng.seed(42)
        course = PADI_COURSES[0]  # OW, max 12m
        dives = generate_training_dives(course, dive_start_index=0)
        for dive in dives:
            self.assertLessEqual(dive["max_depth"], course["max_depth"] + 2)  # small tolerance
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestCourseGeneration -v 2>&1 | head -20
```

Expected: ImportError.

- [ ] **Step 3: Add `PADI_COURSES` data**

Add after `PADI_CERTIFICATIONS` in `scripts/generate_uddf_test_data.py`:

```python
# PADI Courses linked to certifications
# Each course generates training dives and links to a certification
PADI_COURSES = [
    {
        "id": "course_ow",
        "name": "Open Water Diver",
        "agency": "padi",
        "certification_id": "cert_ow",
        "instructor": "John Smith",
        "instructor_number": "S-12345",
        "location": "Blue Water Divers",
        "num_training_dives": 4,
        "course_duration_days": 4,
        "max_depth": 12,
        "min_depth": 6,
        "dive_duration_range": (30, 45),
        "site_type": "shallow",
        "skill_level_range": (0.15, 0.35),
    },
    {
        "id": "course_aow",
        "name": "Advanced Open Water Diver",
        "agency": "padi",
        "certification_id": "cert_aow",
        "instructor": "Maria Garcia",
        "instructor_number": "S-12345",
        "location": "Blue Water Divers",
        "num_training_dives": 5,
        "course_duration_days": 3,
        "max_depth": 30,
        "min_depth": 10,
        "dive_duration_range": (35, 50),
        "site_type": "reef",
        "skill_level_range": (0.3, 0.5),
        "adventure_dives": [
            {"name": "Deep", "max_depth": 30, "min_depth": 25, "site_type": "reef", "duration_range": (30, 40)},
            {"name": "Navigation", "max_depth": 15, "min_depth": 12, "site_type": "shallow", "duration_range": (30, 40)},
            {"name": "Night", "max_depth": 15, "min_depth": 12, "site_type": "reef", "duration_range": (35, 45)},
            {"name": "PPB", "max_depth": 15, "min_depth": 12, "site_type": "shallow", "duration_range": (35, 45)},
            {"name": "Naturalist", "max_depth": 18, "min_depth": 10, "site_type": "reef", "duration_range": (40, 50)},
        ],
    },
    {
        "id": "course_rescue",
        "name": "Rescue Diver",
        "agency": "padi",
        "certification_id": "cert_rescue",
        "instructor": "David Chen",
        "instructor_number": "S-23456",
        "location": "Aqua Adventures",
        "num_training_dives": 2,
        "course_duration_days": 3,
        "max_depth": 15,
        "min_depth": 8,
        "dive_duration_range": (20, 35),
        "site_type": "shallow",
        "skill_level_range": (0.4, 0.55),
    },
    {
        "id": "course_ean",
        "name": "Enriched Air Diver",
        "agency": "padi",
        "certification_id": "cert_ean",
        "instructor": "Maria Garcia",
        "instructor_number": "S-12345",
        "location": "Blue Water Divers",
        "num_training_dives": 2,
        "course_duration_days": 1,
        "max_depth": 25,
        "min_depth": 15,
        "dive_duration_range": (40, 55),
        "site_type": "reef",
        "skill_level_range": (0.45, 0.55),
    },
    {
        "id": "course_deep",
        "name": "Deep Diver",
        "agency": "padi",
        "certification_id": "cert_deep",
        "instructor": "James Wilson",
        "instructor_number": "S-34567",
        "location": "Deep Blue Diving",
        "num_training_dives": 4,
        "course_duration_days": 2,
        "max_depth": 35,
        "min_depth": 25,
        "dive_duration_range": (25, 40),
        "site_type": "wall",
        "skill_level_range": (0.45, 0.6),
    },
    {
        "id": "course_wreck",
        "name": "Wreck Diver",
        "agency": "padi",
        "certification_id": "cert_wreck",
        "instructor": "Robert Taylor",
        "instructor_number": "S-45678",
        "location": "Wreck Diving Specialists",
        "num_training_dives": 4,
        "course_duration_days": 2,
        "max_depth": 25,
        "min_depth": 15,
        "dive_duration_range": (30, 45),
        "site_type": "wreck",
        "skill_level_range": (0.45, 0.6),
    },
    {
        "id": "course_msd",
        "name": "Master Scuba Diver",
        "agency": "padi",
        "certification_id": "cert_msd",
        "instructor": "David Chen",
        "instructor_number": "S-23456",
        "location": "Aqua Adventures",
        "num_training_dives": 0,  # MSD is a rating, not a course with dives
        "course_duration_days": 1,
        "max_depth": 30,
        "min_depth": 15,
        "dive_duration_range": (40, 55),
        "site_type": "reef",
        "skill_level_range": (0.6, 0.75),
    },
    {
        "id": "course_tec40",
        "name": "Tec 40",
        "agency": "padi",
        "certification_id": "cert_tec40",
        "instructor": "Michael Brown",
        "instructor_number": "S-56789",
        "location": "Technical Diving Center",
        "num_training_dives": 4,
        "course_duration_days": 5,
        "max_depth": 40,
        "min_depth": 30,
        "dive_duration_range": (35, 55),
        "site_type": "wall",
        "skill_level_range": (0.75, 0.9),
    },
    {
        "id": "course_tec45",
        "name": "Tec 45",
        "agency": "padi",
        "certification_id": "cert_tec45",
        "instructor": "Michael Brown",
        "instructor_number": "S-56789",
        "location": "Technical Diving Center",
        "num_training_dives": 4,
        "course_duration_days": 5,
        "max_depth": 45,
        "min_depth": 35,
        "dive_duration_range": (35, 55),
        "site_type": "wall",
        "skill_level_range": (0.8, 0.95),
    },
    {
        "id": "course_drysuit",
        "name": "Dry Suit Diver",
        "agency": "padi",
        "certification_id": "cert_drysuit",
        "instructor": "Sarah Johnson",
        "instructor_number": "S-67890",
        "location": "Cold Water Diving",
        "num_training_dives": 2,
        "course_duration_days": 1,
        "max_depth": 18,
        "min_depth": 10,
        "dive_duration_range": (30, 45),
        "site_type": "reef",
        "skill_level_range": (0.5, 0.6),
    },
    {
        "id": "course_sidemount",
        "name": "Sidemount Diver",
        "agency": "padi",
        "certification_id": "cert_sidemount",
        "instructor": "Michael Brown",
        "instructor_number": "S-56789",
        "location": "Technical Diving Center",
        "num_training_dives": 3,
        "course_duration_days": 3,
        "max_depth": 25,
        "min_depth": 12,
        "dive_duration_range": (35, 50),
        "site_type": "reef",
        "skill_level_range": (0.55, 0.7),
    },
]
```

- [ ] **Step 4: Implement `generate_training_dives` function**

Add after `PADI_COURSES`:

```python
def generate_training_dives(course: Dict, dive_start_index: int) -> List[Dict]:
    """Generate training dive metadata for a course.

    Args:
        course: Course dict from PADI_COURSES.
        dive_start_index: Starting index for dive numbering.

    Returns:
        List of training dive dicts with datetime, max_depth, duration,
        site_type, skill_level, course_id.
    """
    cert = next(c for c in PADI_CERTIFICATIONS if c["id"] == course["certification_id"])
    completion_date = datetime.strptime(cert["date"], "%Y-%m-%d")
    start_date = completion_date - timedelta(days=course["course_duration_days"])

    num_dives = course["num_training_dives"]
    if num_dives == 0:
        return []

    dives = []
    adventure_dives = course.get("adventure_dives")

    for i in range(num_dives):
        # Spread dives across course duration
        day_offset = int(i * course["course_duration_days"] / max(1, num_dives))
        dive_date = start_date + timedelta(days=day_offset)
        # Morning/afternoon dive times
        hour = 8 + (i % 3) * 3  # 8am, 11am, 2pm rotation
        dive_datetime = dive_date.replace(hour=hour, minute=0, second=0)

        # Use adventure dive specs if available (AOW course)
        if adventure_dives and i < len(adventure_dives):
            adv = adventure_dives[i]
            max_depth = random.uniform(adv["min_depth"], adv["max_depth"])
            duration = random.randint(*adv["duration_range"])
            site_type = adv["site_type"]
        else:
            max_depth = random.uniform(course["min_depth"], course["max_depth"])
            duration = random.randint(*course["dive_duration_range"])
            site_type = course["site_type"]

        skill = random.uniform(*course["skill_level_range"])

        dives.append({
            "datetime": dive_datetime,
            "max_depth": max_depth,
            "duration": duration,
            "site_type": site_type,
            "skill_level": skill,
            "course_id": course["id"],
            "course_name": course["name"],
            "instructor": course["instructor"],
        })

    return dives
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py::TestCourseGeneration -v
```

Expected: All 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/generate_uddf_test_data.py scripts/test_uddf_generator.py
git commit -m "feat: add PADI course definitions and training dive generation"
```

---

### Task 9: Integrate Courses into UDDF Output

**Files:**
- Modify: `scripts/generate_uddf_test_data.py` (the `generate_uddf()` function)

- [ ] **Step 1: Generate training dives and merge into dive list**

In `generate_uddf()`, before the main dive generation loop (before `for dive_idx in range(num_dives):`), add:

```python
    # Generate training dives from courses
    training_dives = []
    for course in PADI_COURSES:
        course_dives = generate_training_dives(course, dive_start_index=len(training_dives))
        training_dives.extend(course_dives)

    # Sort training dives by date for chronological insertion
    training_dives.sort(key=lambda d: d["datetime"])

    # Track which dives are training dives (by their index in the final output)
    training_dive_indices = {}  # dive_idx -> training_dive_dict
```

- [ ] **Step 2: Insert training dives chronologically into the dive loop**

Inside the main dive loop, after determining `dive_datetime`, check if a training dive should be inserted. Add before the `generate_dive_profile` call:

```python
        # Check if there's a training dive that should be inserted at this point
        course_ref = None
        is_training_dive = False
        while training_dives and training_dives[0]["datetime"] <= dive_datetime:
            td = training_dives.pop(0)
            training_dive_indices[dive_idx] = td
            is_training_dive = True
            course_ref = td["course_id"]
            # Override dive parameters for training dive
            max_depth = td["max_depth"]
            duration = td["duration"]
            site_type = td["site_type"]
            personality = DiverPersonality(
                skill_level=td["skill_level"],
                activity_level=random.uniform(0.3, 0.5),  # Training dives: moderate activity
            )
            dive_datetime = td["datetime"]
            break
```

- [ ] **Step 3: Add course link to dive's `informationbeforedive`**

After the existing trip link code in the `informationbeforedive` section, add:

```python
        # Link to training course if this is a course dive
        if course_ref:
            course_link = ET.SubElement(before, "link")
            course_link.set("ref", course_ref)
```

- [ ] **Step 4: Write courses to the `<submersion>` extension section**

In the `<submersion>` extension section output (after the certifications block, around line 2782), add:

```python
    # Courses in Submersion's expected format
    courses_elem = ET.SubElement(submersion, "courses")
    for course in PADI_COURSES:
        cert = next((c for c in PADI_CERTIFICATIONS if c["id"] == course["certification_id"]), None)
        if cert is None:
            continue

        course_elem = ET.SubElement(courses_elem, "course")
        course_elem.set("id", course["id"])
        ET.SubElement(course_elem, "name").text = course["name"]
        ET.SubElement(course_elem, "agency").text = course["agency"]

        completion_date = datetime.strptime(cert["date"], "%Y-%m-%d")
        start_date = completion_date - timedelta(days=course["course_duration_days"])
        ET.SubElement(course_elem, "startdate").text = start_date.strftime("%Y-%m-%d")
        ET.SubElement(course_elem, "completiondate").text = cert["date"]

        ET.SubElement(course_elem, "instructorname").text = course["instructor"]
        if course.get("instructor_number"):
            ET.SubElement(course_elem, "instructornumber").text = course["instructor_number"]
        ET.SubElement(course_elem, "location").text = course["location"]

        # Link to certification
        cert_link = ET.SubElement(course_elem, "link")
        cert_link.set("ref", course["certification_id"])
        cert_link.set("role", "certification")
```

- [ ] **Step 5: Update summary print output**

After the existing `print(f"- {len(PADI_CERTIFICATIONS)} certifications (PADI)")` line, add:

```python
    print(f"- {len(PADI_COURSES)} courses (PADI) with {sum(c['num_training_dives'] for c in PADI_COURSES)} training dives")
```

- [ ] **Step 6: Run full generation and verify**

Run:
```bash
cd scripts && python generate_uddf_test_data.py --quick -o /tmp/test_courses.uddf
```

Expected: Script completes. Output includes course and training dive counts.

- [ ] **Step 7: Verify UDDF contains course data**

Run:
```bash
grep -c "<course " /tmp/test_courses.uddf
```

Expected: Should show the number of courses (11, one per cert including sidemount).

Run:
```bash
grep -c "ref=\"course_" /tmp/test_courses.uddf
```

Expected: Should show training dive links (number of training dives that fit in the quick 10-dive window).

- [ ] **Step 8: Run all tests**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py -v
```

Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add scripts/generate_uddf_test_data.py scripts/test_uddf_generator.py
git commit -m "feat: generate PADI courses with training dives in UDDF output

Courses are written to the <submersion> extension section with links
to certifications. Training dives are inserted chronologically with
courseRef links. Includes specialized AOW adventure dive profiles."
```

---

### Task 10: Final Verification

**Files:**
- No changes -- verification only

- [ ] **Step 1: Run all tests**

Run:
```bash
cd scripts && python -m pytest test_uddf_generator.py -v
```

Expected: All tests pass.

- [ ] **Step 2: Run full 500-dive generation**

Run:
```bash
cd scripts && python generate_uddf_test_data.py -n 50 -o /tmp/test_full_50.uddf
```

Expected: Script completes with summary showing dives, courses, training dives, certifications.

- [ ] **Step 3: Verify UDDF structure**

Run:
```bash
python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/tmp/test_full_50.uddf')
root = tree.getroot()
ns = {'u': 'http://www.streit.cc/uddf/3.2'}

# Count dives
dives = root.findall('.//u:dive', ns)
print(f'Total dives: {len(dives)}')

# Count waypoints in first dive
first_dive = dives[0] if dives else None
if first_dive:
    waypoints = first_dive.findall('.//u:waypoint', ns)
    print(f'Waypoints in first dive: {len(waypoints)}')
    # Check interval
    if len(waypoints) >= 2:
        t1 = int(waypoints[0].find('u:divetime', ns).text)
        t2 = int(waypoints[1].find('u:divetime', ns).text)
        print(f'Sample interval: {t2-t1}s')

# Count course links
course_links = [e for e in root.iter() if e.get('ref', '').startswith('course_')]
print(f'Course links in dives: {len(course_links)}')

# Check submersion extension
sub = root.find('.//{http://submersion.app/uddf/extensions}submersion') or root.find('.//submersion')
if sub is None:
    # Try without namespace
    for elem in root.iter():
        if 'submersion' in elem.tag.lower() and elem.tag != root.tag:
            sub = elem
            break
if sub is not None:
    courses = sub.findall('.//course') or sub.findall('./courses/course')
    print(f'Courses in submersion section: {len(courses)}')
else:
    print('Submersion extension section not found (check namespace)')
"
```

Expected:
- Sample interval: 5s
- Course links present in dives
- Courses present in submersion section

- [ ] **Step 4: Mark complete**

All three improvements implemented:
1. Sample interval changed from 10s to 5s
2. Dive profiles use Perlin noise, micro-events, variable descent, workload-driven gas, diver personality
3. PADI courses generated with training dives linked to dives and certifications
