# Bottom Time: Multilevel-Correct Calculation

Date: 2026-08-09
Status: Approved

## Problem

`Dive.calculateBottomTimeFromProfile` defines "the bottom" as depth >= 85% of
max depth and reports bottom time as the span between the first and last
samples in that band. This embeds a square-profile assumption. On a multilevel
dive (e.g., 60 min total: 10 min at 95 ft, then a 40 min tail at 50 ft), the
50 ft tail sits below the ~81 ft threshold, so bottom time collapses to
roughly the 10 minutes spent near max depth.

The same 85% heuristic exists in three places:

1. `lib/features/dive_log/domain/entities/dive.dart` —
   `Dive.calculateBottomTimeFromProfile` (used by the UDDF entity importer,
   imported dive converter, dive merge builder, and the dive edit page's
   Calculate button).
2. `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
   — `_calculateBottomTimeFromPoints` (dive computer downloads).
3. `lib/core/database/database.dart` — `_bottomTimeSecondsFromProfileRows`
   (v132 migration backfill). Dives corrected by that backfill received
   multilevel-wrong values.

## Definition

Bottom time = time from **surface departure to the start of the final ascent**
(US Navy / dive-table convention; includes the descent). The final ascent
includes safety and deco stops, which are therefore excluded from bottom time.

## Algorithm

A pure function over timestamp-ordered `(timestamp, depth)` samples:

```
threshold   = min(max(6.0 m, 0.33 * maxDepth), 0.85 * maxDepth)
ascentStart = timestamp of the LAST sample with depth >= threshold
bottomTime  = ascentStart - firstSampleTimestamp
```

The outer `min` with `0.85 * maxDepth` caps the threshold on dives shallower
than ~7 m (where the 6 m floor would otherwise exceed max depth and no sample
could qualify); it guarantees the deepest sample always satisfies the
threshold, so shallow dives keep getting a result.

Null guards (matching the current method's contract):

- fewer than 3 samples
- max depth <= 0
- computed span <= 0

The absolute floor (6.0 m), fraction (0.33), and cap (0.85) are named
constants, overridable via optional parameters for tests.

Behavior:

- Reported case (95 ft max): threshold = max(6, 9.6 m) = 9.6 m; the 50 ft
  (15.2 m) tail stays above it, so bottom time is ~50 min, not ~10.
- A 5 m safety stop falls below the 6 m floor on any dive and is excluded.
- Known trade-off: on deco dives, a stop deeper than 1/3 of max depth (deep
  stops) counts as bottom time — a 1-3 minute overcount, accepted in exchange
  for fixing the multi-tens-of-minutes undercount on multilevel dives.

## Code structure

- New file `lib/features/dive_log/domain/services/bottom_time_calculator.dart`
  holding the pure function. No Drift or entity dependencies; operates on
  plain timestamp/depth pairs.
- `Dive.calculateBottomTimeFromProfile()` delegates to it. The
  `depthThresholdPercent` parameter is removed (no caller passes it). All
  existing call sites pick up the fix unchanged.
- `_calculateBottomTimeFromPoints` in `dive_computer_repository_impl.dart`
  delegates to the same function.
- The v132 helper `_bottomTimeSecondsFromProfileRows` in `database.dart`
  stays frozen as the old 85% heuristic. The new migration uses it as a
  fingerprint for machine-written values (below).

## Migration backfill

New schema version with an `onUpgrade`-only step, following the v132 pattern
(PRAGMA table_info guards, event-loop yield every 25 dives, `hlc` untouched —
the recompute is deterministic on every device, so LWW converges without sync
traffic):

For each dive with non-null `bottom_time` and a primary profile
(`is_primary = 1`, timestamp-ordered):

1. Compute `oldVal` with the frozen 85% heuristic.
2. If `stored == oldVal`, the value was auto-derived: compute `newVal` with
   the new algorithm and update when `newVal` is non-null and differs.
3. Otherwise the value was user-entered (or profile-independent): leave it
   untouched.

Never runs in `beforeOpen`. Values that only coincidentally match the old
heuristic are recomputed too; that is acceptable because the replacement is
still profile-consistent.

## Testing (TDD)

Unit tests for `bottom_time_calculator.dart`:

- Square profile: result equals the old value plus the descent duration
  (the new definition includes descent).
- Reported multilevel case (10 min @ 95 ft + 40 min @ 50 ft): ~50 min.
- Safety stop at 5 m excluded from bottom time.
- Shallow dive where the 6 m absolute floor governs the threshold.
- Deco dive with a deep stop beyond 1/3 max depth: documented overcount.
- Fewer than 3 samples, all-zero depths: null.
- Unsorted input handled (sorted internally).

Migration test following `migration_v132_bottom_time_backfill_test.dart`:

- Auto-derived value (matches old heuristic) is replaced with the new result.
- Hand-entered value (does not match) is untouched.
- Dive without a primary profile is untouched.
- `hlc` column unchanged by the backfill.

Existing tests asserting 85% behavior get updated expectations.

## Out of scope

- No UI changes: the edit page Calculate button and all displays flow through
  `Dive.calculateBottomTimeFromProfile`.
- No user-facing algorithm setting.
- No SAC changes (SAC uses runtime and average depth, not bottom time).
- No changes to the import trust rules from PR #675 (duration vs runtime
  seeding); only the profile-derived computation changes.
