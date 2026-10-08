# Cumulative Tissue Loading and OTU Tracking

**Date:** 2026-03-01
**Status:** Approved

## Problem

Submersion calculates NDL, tissue loading, ceiling, and TTS for each dive independently, resetting all 16 Buhlmann compartments to surface-saturated state before analysis. This produces incorrect (optimistic) values for repetitive dives where residual nitrogen remains in tissues from previous dives.

CNS% is already cumulative via recursive lookback. Tissue loading and OTU are not.

## Decisions

- **Approach**: Recursive provider pattern (mirrors existing CNS lookback)
- **Tissue loading cutoff**: 48 hours (compartment 16 reaches ~99% equilibrium)
- **OTU model**: Daily running total (300 OTU/day limit) + 7-day rolling weekly total (850 OTU/week limit, REPEX)
- **Scope**: App-calculated values + fallback when dive computer data is absent
- **Sync provider**: `diveProfileAnalysisProvider` (synchronous) stays surface-saturated; only the async `profileAnalysisProvider` gets cumulative support

## Design

### 1. Cumulative Tissue Loading

#### Data Flow

```dart
profileAnalysisProvider(diveId)
  |
  +-- _computeResidualTissueState(ref, diveId)
  |     |
  |     +-- repository.getPreviousDive(diveId)
  |     +-- repository.getSurfaceInterval(diveId)
  |     +-- if interval >= 48h -> return null (surface-saturated)
  |     +-- if no previous dive -> return null
  |     +-- profileAnalysisProvider(previousDive.id)  [recursive]
  |     +-- extract final DecoStatus.compartments from previous analysis
  |     +-- apply Schreiner off-gassing for surface interval duration
  |     +-- return List<TissueCompartment>
  |
  +-- service.analyze(..., startCompartments: residualState)
```

#### Changes

**`ProfileAnalysisService.analyze()`**: Add optional `startCompartments` parameter. When provided, call `BuhlmannAlgorithm.setCompartments()` instead of `reset()`.

**`BuhlmannAlgorithm.processProfile()`**: Remove the internal `reset()` call. The caller (ProfileAnalysisService) controls initialization.

**`profile_analysis_provider.dart`**: Add `_computeResidualTissueState()` mirroring `_computeResidualCns()` with 48-hour cutoff. Returns `List<TissueCompartment>?` (null = surface-saturated).

### 2. Cumulative OTU Tracking

#### Data Flow

```text
profileAnalysisProvider(diveId)
  |
  +-- _computeResidualOtu(ref, diveId)
  |     |
  |     +-- repository.getDiveDateTime(diveId)
  |     +-- repository.getDivesOnSameDay(diveId)
  |     +-- sum OTU from all earlier dives that day
  |     +-- return cumulative daily OTU as startOtu
  |
  +-- service.analyze(..., startOtu: residualOtu)
```

OTU is non-recursive. Each dive's per-dive OTU is independent of previous OTU. We just query and sum.

#### Changes

**`O2Exposure`**: Add `otuStart` (double) and `otuDaily` (double) fields. Keep existing `otu` as this-dive-only value.

**`ProfileAnalysisService.analyze()`**: Add optional `startOtu` parameter. Calculate `otuDaily = startOtu + otu`.

**`DiveRepository`**: Add `getDivesOnSameDay(String diveId)` query helper (or reuse `getDivesInRange()` with midnight bounds).

**`profile_analysis_provider.dart`**: Add `_computeResidualOtu()`. Non-recursive, queries earlier same-day dives.

**Weekly OTU**: Separate provider querying dives from past 7 days and summing OTU. Used by the O2 toxicity card UI, not by per-dive analysis.

**`O2ToxicityCard` (UI)**: Display daily OTU total (% of 300 limit) and weekly OTU total (% of 850 limit) with warning colors at 80%+.

### 3. Edge Cases

**Out-of-order dives**: `getPreviousDive()` queries by `diveDateTime`, so chronological order is always correct regardless of insertion order.

**Deleted dives**: Recursive lookback skips them. The longer surface interval produces more off-gassing (conservative).

**Edited dives**: Riverpod dependency tracking invalidates downstream providers automatically.

**Cross-day boundary**: Tissue loading carries across days (within 48h). Daily OTU resets at midnight. Weekly OTU is a rolling 7-day window.

**Sync provider**: `diveProfileAnalysisProvider` stays surface-saturated (quick previews, dive list). Computer overlay values bypass app calculation.

### 4. Performance

Riverpod caches each `profileAnalysisProvider(diveId)` result. A 5-dive day with cold cache triggers 5 sequential analyses once, then all are cached. The 48-hour cutoff and chronological ordering guarantee recursion terminates.

### 5. Testing

**Unit tests**:

- `processProfile()` respects pre-loaded compartments
- Two consecutive dives with surface interval match manual Schreiner calculation
- 48-hour surface interval produces near-surface-saturated state
- `otuDaily` = `otuStart` + dive OTU
- Daily OTU resets across calendar day boundary

**Integration tests**:

- 3-dive day: verify NDL decreases with each successive dive
- Cross-day boundary: tissue carries across, daily OTU resets
- Verify daily and weekly OTU accumulation

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/deco/buhlmann_algorithm.dart` | Remove `reset()` from `processProfile()` |
| `lib/features/dive_log/data/services/profile_analysis_service.dart` | Add `startCompartments`, `startOtu` params |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Add `_computeResidualTissueState()`, `_computeResidualOtu()` |
| `lib/core/deco/entities/o2_exposure.dart` | Add `otuStart`, `otuDaily` fields |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Add `getDivesOnSameDay()` query |
| `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart` | Display daily/weekly OTU |
| `test/core/deco/buhlmann_algorithm_test.dart` | Cumulative tissue loading tests |
| `test/features/dive_log/data/services/profile_analysis_service_test.dart` | startCompartments/startOtu tests |
| `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` | Residual state provider tests |
