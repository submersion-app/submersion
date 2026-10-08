# UDDF Test Data Generator Improvements

## Summary

Three improvements to `scripts/generate_uddf_test_data.py`:

1. **Sample interval**: Change default from 10s to 5s
2. **Dive profile realism**: Replace mechanical depth/temp/gas patterns with organic, varied profiles
3. **Course generation**: Generate PADI training courses linked to dives and certifications

## 1. Sample Interval Change

Change the default `sample_interval` parameter from `10` to `5` in both `generate_dive_profile()` (line 1545) and `generate_uddf()` (line 2051). Update help text and print output accordingly.

## 2. Dive Profile Realism

### 2.1 Depth Variation Model

**Problem:** The current `depth_variation()` function uses a fixed sum of sine waves, producing regular, repeating oscillations that look identical across dives.

**Solution:** Replace with Perlin noise + micro-events.

#### Perlin Noise

Implement a simple 1D gradient noise function inline in the script (no external dependencies -- just `math` and `random` from the stdlib). Uses a permutation table seeded uniquely per dive via `random.seed()`. Produces smooth, non-repeating organic variation in the +/-1m range. Replaces the `sin(t*0.05) + sin(t*0.023)...` stack entirely.

#### Breathing Oscillation

A subtle ~0.2-0.4m sinusoidal at 12-18 cycles/min (randomized per diver personality). Amplitude decreases with experience level. This is the one place a sine wave is appropriate -- breathing really is periodic.

#### Micro-Events During Bottom Time

Each depth level gets 2-6 randomized "exploration events" -- brief purposeful depth excursions:

- "Look at something below" -- descend 1-3m over 15-30s, hold 10-20s, return
- "Ascend to check reef top" -- rise 1-3m over 10-20s, hold briefly, return
- "Buoyancy adjustment" -- sudden 0.5m shift that slowly corrects
- "Swim over terrain feature" -- gradual 2-4m depth change over 60-120s

Events are spaced randomly (not evenly) throughout bottom time. Between events, the diver holds depth with just Perlin noise + breathing variation.

#### Diver Personality

Each dive gets randomized personality parameters:

- `skill_level`: 0.0-1.0 -- affects depth-holding stability (noise amplitude), descent pause frequency, and SAC consistency
- `activity_level`: 0.0-1.0 -- affects micro-event frequency and magnitude
- Both trend upward over the 5-year timeline as the diver gains experience (correlated with certification progression)

### 2.2 Descent Improvements

**Problem:** Fixed 15 m/min descent with a single smooth cubic ease -- too steep and mechanical.

**Solution:**

- **Variable descent rate:** 6-15 m/min base rate, randomized per dive. Slower for novice personality, faster for experienced. Rate varies during the descent: slower in first 5-10m, faster mid-range, slowing again near target depth.
- **Equalization pauses:** 1-3 brief pauses (3-8 seconds each) at randomized depths in the first 10m. Frequency and duration inversely correlate with `skill_level`.
- **Buddy check pause:** ~30% chance of a 5-10 second pause at 3-5m depth.
- **Easing:** Apply `ease_in_out_cubic` in segments between pauses rather than across the entire descent.

### 2.3 Ascent Improvements

The existing ascent logic is already fairly good (respects Buhlmann ceilings, safety stops, 9 m/min rate). Minor improvements:

- **Variable ascent rate:** 6-9 m/min randomized, with slight slowdowns near stop depths.
- **Safety stop variation:** Widen from 5m +/- 0.3m to 4.5-5.5m range with Perlin noise.
- **Post-safety-stop pause:** ~40% of dives get a brief "look around" at 3m for 10-20s before final surfacing.

### 2.4 Bottom Time Patterns

**Problem:** Each depth level gets exactly equal time, creating a flat staircase.

**Solution:**

- **Dynamic level timing:** Randomize time per level. Weight toward longer time at the deepest level. Example 3-level split: 50%/30%/20% with +/-10% random jitter.
- **Level transitions:** Variable speed (30s to 3 minutes) depending on depth difference. Add Perlin noise during transitions so they don't look like smooth ramps.
- **Exploration depth bands:** Each level gets a depth band (e.g., 22-26m) rather than a single target depth. The diver moves organically within the band.

#### Site-Type Differentiation

Expand per-site-type profiles for genuinely different-looking dives:

| Site Type | Behavior |
|-----------|----------|
| Wall | Tight depth band, fewer micro-events, hovering along the wall |
| Reef | Widest depth bands, most micro-events, exploring terrain |
| Wreck | Distinct "deck" and "interior" holds, sharper transitions |
| Drift | Gradual overall depth trend, less purposeful depth control |
| Manta | Very narrow band, long holds, minimal events |
| Cavern/cenote | Sharp layer boundaries, deliberate depth management |

### 2.5 Temperature Fix

**Problem:** `noise = math.sin(depth * 0.5 + variation_seed) * 0.3` makes temperature oscillate with every depth change. Water temperature is stratified, not noisy.

**Solution:** Remove the depth-based sine noise entirely. Temperature is determined purely by the thermocline model based on current depth. Add only:

- A small per-dive offset (+/- 0.2C) applied once at dive start (day-to-day variation)
- Optional sensor noise of +/- 0.05C (random, not depth-correlated)

### 2.6 Gas Consumption Realism

**Problem:** SAC modifier is a fixed phase multiplier with the same sine pattern as depth. Consumption looks perfectly linear.

**Solution:** Workload-driven SAC:

- **Depth changes:** Consumption increases proportional to rate of depth change (effort of descending/ascending)
- **Micro-events:** Active exploration bumps SAC by 10-30% during the event
- **Steady hovering:** Lowest SAC rate
- **Exertion spikes:** Brief 20-40% SAC increases lasting 30-60s, 2-4 per dive (fighting current, adjusting gear)
- **Skill-based SAC:** `skill_level` affects base SAC (12-14 L/min experienced, 16-22 L/min novice) and SAC consistency
- **Per-dive variability:** Each dive gets a slightly different base SAC within the diver's range

### 2.7 Dive Variety

Additional levers to ensure dives don't look similar:

- **Per-dive randomization:** Each dive rolls its own personality, event count, descent pattern, SAC personality, and Perlin seed
- **Duration variety:** +/- 15% random jitter on target duration. Some dives end early (cold, low air, buddy signals)
- **Depth target variety:** +/- 5-10% on achieved max depth. Sometimes the diver goes 1-2m deeper than planned, sometimes doesn't quite reach it
- **Occasional anomalies (low frequency):**
  - ~5% of dives: brief rapid ascent of 2-3m followed by re-descent (buoyancy slip)
  - ~10% of dives: extra-long pause during descent (equalization trouble)
  - ~3% of dives: early termination (20-30% off planned bottom time)

## 3. Course Generation

### 3.1 Course Data Structure

Add a `PADI_COURSES` list parallel to the existing `PADI_CERTIFICATIONS`. Each entry:

```python
{
    "id": "course_ow",
    "name": "Open Water Diver",
    "agency": "padi",
    "certification_id": "cert_ow",
    "instructor_buddy_index": 0,
    "center_index": 0,
    "num_training_dives": 4,
    "course_duration_days": 4,
    "max_depth": 12,
    "min_depth": 6,
    "dive_duration_range": (30, 45),
    "site_type": "shallow",
    "skill_level_range": (0.2, 0.4),
}
```

### 3.2 Course Definitions

| Course | Training Dives | Duration | Max Depth | Skill Level |
|--------|---------------|----------|-----------|-------------|
| Open Water | 4 | 3-5 days | 12m | 0.2-0.4 (novice) |
| Advanced OW | 5 adventure dives | 2-3 days | 30m | 0.35-0.5 |
| Rescue | 2 scenario dives | 2-3 days | 15m | 0.4-0.55 |
| EANx | 2 dives | 1 day | 25m | 0.45-0.55 |
| Deep Diver | 4 dives | 2 days | 35m | 0.45-0.6 |
| Wreck Diver | 4 dives | 2 days | 25m | 0.45-0.6 |
| Divemaster | ~20 dives | 2-4 weeks | 30m | 0.7-0.85 |
| Tec 40 | 4 dives | 3-5 days | 40m | 0.75-0.9 |
| Tec 45 | 4 dives | 3-5 days | 45m | 0.8-0.95 |
| Dry Suit | 2 dives | 1 day | 18m | 0.5-0.6 |

### 3.3 AOW Adventure Dive Specialization

The 5 AOW adventure dives should each have distinct characteristics:

1. Deep dive -- 25-30m, single level
2. Navigation dive -- 15m, very steady depth (compass work)
3. Night dive -- 12-15m, slow pace, high activity (using lights)
4. Peak performance buoyancy -- 15m, minimal depth variation (stable hovering)
5. Naturalist -- 10-18m, many micro-events (inspecting marine life)

### 3.4 Timeline Integration

For each course:

1. `completion_date` = the corresponding certification's issue date from `PADI_CERTIFICATIONS`
2. `start_date` = `completion_date - course_duration_days`
3. Generate `num_training_dives` spread across the course date range
4. Training dives get `courseRef` pointing to the course ID
5. Course gets `certificationRef` pointing to the certification ID
6. Instructor comes from the buddies list (reuse same instructor as certification where names match, or assign from buddies)
7. Location comes from `DIVE_CENTERS` (reuse facility from certification data where possible)

### 3.5 UDDF Output Format

Courses are written into the `<submersion>` extension section, matching the format the importer already parses:

```xml
<courses>
  <course id="course_ow">
    <name>Open Water Diver</name>
    <agency>padi</agency>
    <startdate>2018-03-12</startdate>
    <completiondate>2018-03-15</completiondate>
    <instructorname>John Smith</instructorname>
    <instructornumber>S-12345</instructornumber>
    <location>Blue Water Divers</location>
    <link ref="cert_ow" role="certification"/>
  </course>
</courses>
```

Each training dive includes a course link in `<informationbeforedive>`:

```xml
<link ref="course_ow"/>
```

Training dives are also included in the main dive count and follow chronological ordering with all other dives.

## Scope

All changes are confined to `scripts/generate_uddf_test_data.py`. No Dart code changes are required -- the UDDF importer already supports all the data structures being generated (courses, course-dive links, course-certification links).

## File Size Impact

Changing from 10s to 5s sample interval doubles the number of waypoints per dive. For 500 dives, the output file will be roughly 2x larger. The `--quick` mode (30s intervals) remains available for fast testing.
