# Imported Profile Multi-Gas Decompression Analysis

**Date:** 2026-03-31

## Problem

Imported dives can already persist multiple tanks and gas-switch records, but the historical profile-analysis path still treats the whole dive as if the diver breathed a single gas from `dive.tanks.first`.

That means calculated decompression for imported dives:

- NDL
- ceiling
- TTS
- deco status / stops
- end-of-dive tissue state carried into repetitive dives

is wrong whenever the dive switched to another gas during the profile.

## Goals

- Make imported historical-dive decompression analysis honor gas switches.
- Preserve existing single-gas behavior when a dive has no gas-switch records.
- Keep the Bühlmann math shared and reusable rather than forking imported-dive-specific logic.
- Add tests proving that a richer switched gas reduces decompression burden versus calculating the same profile entirely on air.

## Non-Goals

- No invalid-gas-switch warning UX in this pass.
- No calculated-deco validity framework in this pass.
- No dive-detail warning icon work in this pass.
- No SSRF/UDDF importer redesign in this pass.
- No planner UX changes.
- No change to computer-data overlay precedence beyond what already exists.

## Current Architecture

Today:

1. `profileAnalysisProvider` loads the dive and profile.
2. It derives one `o2Fraction` / `heFraction` pair from the first tank.
3. It runs `ProfileAnalysisService.analyze(...)`.
4. `ProfileAnalysisService` calls `BuhlmannAlgorithm.processProfile(...)` with one gas for the whole dive.

The missing link is converting persisted gas switches into a time-ordered gas schedule for the existing decompression engine.

## Solution

### High-Level Approach

Add an explicit gas-schedule model for profile analysis and run the existing Bühlmann engine with the active gas for each profile interval.

Instead of:

- one profile
- one gas

the analysis becomes:

- one profile
- one ordered gas schedule
- one continuous tissue-state simulation using the current gas for each interval

### New Analysis Model

Use a lightweight core entity:

```dart
class ProfileGasSegment {
  final int startTimestamp;
  final double fN2;
  final double fHe;
}
```

This model is analysis-only. It does not need planner concepts like depth ownership, reserves, or warnings. Its job is just:

> what inert-gas fractions are active from this timestamp onward?

### Gas Schedule Construction

Build gas segments in `profileAnalysisProvider`.

Rules:

1. Start with the primary tank gas at timestamp `0`.
2. Load gas switches in timestamp order.
3. Each switch replaces the active gas from its timestamp onward.
4. If multiple switches share the same timestamp, the later sorted segment wins.
5. If there are no switches, preserve the current one-gas path.

For this scoped implementation, gas switches are assumed to resolve normally through the existing repository/entity path.

### Core API

Add a new gas-aware entry point to `BuhlmannAlgorithm`:

```dart
List<DecoStatus> processProfileWithGasSegments({
  required List<double> depths,
  required List<int> timestamps,
  required List<ProfileGasSegment> gasSegments,
})
```

Behavior:

- reject empty `gasSegments`
- reject unsorted `gasSegments`
- resolve the active gas for each profile interval
- call `calculateSegment(...)` with that interval’s gas
- return the same `DecoStatus` series shape as the existing single-gas path

Keep `processProfile(...)` as a convenience wrapper that delegates to the gas-aware path with one segment.

### Service Integration

Extend `ProfileAnalysisService.analyze(...)` with optional `gasSegments`.

When `gasSegments` is absent:

- keep the current single-gas behavior exactly

When `gasSegments` is present:

- run the new gas-aware Bühlmann profile processing path

This keeps the service API backward-compatible while enabling imported multi-gas dives.

### Provider Integration

`profileAnalysisProvider` should:

1. load persisted gas switches for the dive
2. convert the primary tank plus switches into `ProfileGasSegment`s
3. pass those segments through `_ProfileAnalysisInput`
4. forward them into `ProfileAnalysisService.analyze(...)`

This keeps repository access in the provider layer and leaves `ProfileAnalysisService` pure.

## Edge Cases

### No Tanks

Fallback to air, matching current behavior.

### No Gas Switches

Single-gas behavior remains unchanged.

### Gas Switch at Timestamp 0

It overrides the default starting gas immediately.

### Multiple Switches at the Same Timestamp

The last sorted switch at that timestamp wins.

### Switch Beyond Profile End

It has no effect on the processed intervals.

## Files Expected To Change

| File | Change |
|------|--------|
| `lib/core/deco/buhlmann_algorithm.dart` | Add gas-aware profile-processing entry point and keep single-gas wrapper |
| `lib/core/deco/entities/profile_gas_segment.dart` | Add lightweight gas-schedule entity |
| `lib/features/dive_log/data/services/profile_analysis_service.dart` | Accept optional gas schedule and use gas-aware processing |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Load gas switches, build gas segments, pass them into analysis |
| `test/core/deco/buhlmann_algorithm_test.dart` | Add gas-segment validation and gas-aware profile-processing tests |
| `test/features/dive_log/data/services/profile_analysis_service_test.dart` | Add multi-gas service tests |
| `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` | Add gas-segment construction/provider coverage |

## Testing

### Core Algorithm Tests

- `processProfileWithGasSegments(...)` with one segment matches `processProfile(...)`
- empty `gasSegments` throws
- unsorted `gasSegments` throws
- switching from air to a richer gas reduces decompression burden versus all-air for the same profile

### Service Tests

- single-segment gas schedule matches legacy single-gas analysis
- switching to EAN32 during ascent produces lower tissue loading / lower-or-equal ceiling / lower-or-equal TTS / greater-or-equal NDL versus all-air

### Provider Tests

- builds the expected gas schedule from primary tank plus sorted switches
- treats default-air tanks correctly
- handles duplicate-timestamp switch replacement correctly

## Acceptance Criteria

- Imported historical dives with gas switches no longer calculate decompression on one fixed gas.
- Single-gas dives continue to behave as before.
- The end-of-dive tissue state used for repetitive dives reflects the actual switched gases.
- Focused unit tests cover the new gas-schedule path in the core algorithm, service, and provider.
