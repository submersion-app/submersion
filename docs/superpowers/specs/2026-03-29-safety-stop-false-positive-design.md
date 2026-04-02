# Safety Stop False Positive Fix

**Date:** 2026-03-29
**Issue:** [#112](https://github.com/submersion-app/submersion/issues/112) - Shallow dives tagged with multiple false safety stops

## Problem

The safety stop detection algorithm in `ProfileAnalysisService._detectSafetyStops()` marks any period spent at 3-6m depth for 2+ minutes as a safety stop. It has no awareness of the overall dive profile, so shallow dives where the entire dive is at safety stop depths (3-6m) get tagged with multiple spurious Safety Stop Start/End markers whenever the depth briefly crosses the band boundaries.

## Solution

Three layered improvements to `_detectSafetyStops()` in `lib/features/dive_log/data/services/profile_analysis_service.dart`:

### Layer 1: Max Depth Gate

Early return if the dive's maximum depth is less than 10m. Safety stops are a decompression safety practice for dives deeper than 10m (per PADI/SSI training standards). A dive that never exceeds 10m has no need for safety stop detection.

**Constant:** `minDiveDepth = 10.0` (meters)

### Layer 2: Ascent-Phase Restriction

Only consider profile points that occur after the point of maximum depth (i.e., the ascent portion of the dive). Safety stops by definition occur during ascent, not during descent or bottom time.

Rather than importing the full `DivePhase` classifier from `GasAnalysisService`, the method uses a simpler approach: find the index of the maximum depth point, and skip any points at or before that index. This keeps safety stop detection self-contained within `ProfileAnalysisService`.

The method signature changes to accept a `maxDepthIndex` parameter:

```dart
void _detectSafetyStops(
  String diveId,
  List<double> depths,
  List<int> timestamps,
  int maxDepthIndex,        // NEW
  List<ProfileEvent> events,
  DateTime now,
)
```

The detection loop starts iteration from `maxDepthIndex + 1` instead of `0`.

### Layer 3: Consolidation

After collecting raw safety stop segments from the detection loop, merge consecutive stops separated by gaps of 30 seconds or less. This handles the case where a diver briefly oscillates outside the 3-6m band during what is effectively a single continuous safety stop.

**Implementation:**

1. The detection loop accumulates raw start/end timestamp pairs into a local list instead of directly creating `ProfileEvent` objects.
2. A post-processing pass iterates through the pairs chronologically. If the gap between one stop's end and the next stop's start is <= 30 seconds, the two are merged (keep the first start timestamp/depth, last end timestamp/depth).
3. `ProfileEvent` objects are created from the final merged list.

**Constant:** `maxConsolidationGap = 30` (seconds)

### Unchanged Constants

- `minStopDepth = 3.0` (meters)
- `maxStopDepth = 6.0` (meters)
- `minStopDuration = 120` (seconds / 2 minutes)

## Call Site Changes

In the `_detectEvents` method (~line 804), the call to `_detectSafetyStops` needs the max depth index. The method already computes `maxDepth` and has the `depths` array available. Finding the index is:

```dart
final maxDepthIndex = depths.indexOf(maxDepth);
```

This value is passed as the new parameter.

## Files Modified

| File | Change |
|------|--------|
| `lib/features/dive_log/data/services/profile_analysis_service.dart` | All three layers in `_detectSafetyStops()`, updated call site in `_detectEvents()` |
| `test/features/dive_log/data/services/profile_analysis_service_test.dart` | New and updated tests |

## Testing

### Max Depth Gate Tests
- Shallow dive (max 5m) in the 3-6m band for 3 minutes: no stops detected
- Dive at exactly 10m with 3-6m pause on ascent: stop detected
- Dive at 9.9m: no stops detected (boundary)

### Ascent-Phase Restriction Tests
- 20m dive with 2+ minutes at 4m during descent: no stop detected
- 20m dive with 2+ minutes at 4m during bottom phase: no stop detected
- 20m dive with 3-minute pause at 5m during ascent: stop detected

### Consolidation Tests
- Two stops separated by 10-second gap: merged into one
- Two stops separated by 31-second gap: remain as two separate stops
- Three consecutive stops with short gaps: all merge into one
- Single stop with no neighbors: unchanged

### Integration Test
- Simulate the shallow dive profile from issue #112 (Perdix AI dive at safety-stop depths): verify zero safety stop markers produced
