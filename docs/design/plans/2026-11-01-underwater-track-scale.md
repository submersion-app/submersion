# Underwater Track Scale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A diver can resize a dead-reckoned underwater track against the map on the alignment page, by a drag handle or a stepper, saved with the track.

**Architecture:** `scaleFactor` joins `NavTrackCorrection`, and `NavTrackCorrector.apply` scales the active range about its first sample before the end-point stretch, so every reader of a corrected track follows without its own change. It persists as a defaulted column at schema v335. The handle's maths is a pure domain file, and its gesture lives in its own layer widget, so `nav_track_align_page.dart` only wires them in.

**Tech Stack:** Flutter, Drift, Riverpod, flutter_map 8.

**Spec:** `docs/design/specs/2026-11-01-underwater-track-scale-design.md`

## Global Constraints

- `scaleFactor` default 1.0. Range 25% to 400%, so factors 0.25 to 4.0. Stepper step 1%. One decimal, in the diver's locale. Handle result rounded to 0.1%.
- Depth and timestamp never change. Samples outside the active range are not scaled. At 1.0, `apply` is identical to today.
- Handle minimum: raw farthest distance from the first active sample of 10 m.
- Column: `nav_tracks.scale_factor`, `REAL NOT NULL DEFAULT 1`, schema 335. `minimumCompatibleSchemaVersion` does not change.
- Distance and speed readouts stay as recorded.
- User-visible strings go in all 11 ARB files. Inside underwater-only screens the word is plain "track"; Hungarian is "nyomvonal".
- ARB files are feature-grouped: insert next to `navTrack_align_rotationLabel` and `settings_conflict_field_headingOffsetDeg`, then run `flutter gen-l10n`.
- Paths via `p.join`. No em-dashes anywhere. No tool attribution in commits or the PR.
- Re-check the schema rung against main and open PRs immediately before pushing.

## Review Focus

- A rotated map while dragging the handle: the pointer must still track, because the maths reads ground positions through the camera. Pinned in Task 5.
- A recording with a pre-dive GPS fix: the pivot, the handle's sample and `P` all use the active start, not sample 0 or the origin. Pinned in Tasks 1 and 4.
- Dragging the handle through the start or past it: the scale clamps at 25% and never flips the track. Pinned in Task 4.
- A comma-decimal locale typing "112,5": reads as 112.5%, not rejected or read as 1125. Pinned in Task 3.
- An older peer editing the track's name while this device holds a scale: the scale survives, and a row new here reads 100%. Pinned in Task 2.

---

### Task 0: Before screenshots and marker checks

**Files:** none in the repo. Screenshots go in the session scratchpad.

- [ ] **Step 1: Launch the app from this worktree with the `run` skill and open a track with a set start point.**

Use a Suunto or Seacraft fixture from `test/fixtures/` through the import flow if the dev database has no track.

- [ ] **Step 2: Capture before shots, named `<nn>-<screen>-before[-phone].png`.**

The alignment page at desktop and phone widths, and the detail page at desktop width.

- [ ] **Step 3: Check the two suspected marker bugs and record the results.**

Rotate the map about 90 degrees, drag the start marker right, and note whether it follows the pointer. At north-up, drag it and note whether the map pans under it. The results decide Task 6.

### Task 1: The correction

**Files:**
- Modify: `lib/features/nav_track/domain/nav_track_corrector.dart`
- Test: `test/features/nav_track/domain/nav_track_corrector_test.dart`

**Interfaces:**
- Produces:
  - `NavTrackCorrection.scaleFactor` (double, default 1.0, in `copyWith`)
  - `NavTrackCorrection.minScaleFactor = 0.25`, `NavTrackCorrection.maxScaleFactor = 4.0`
  - `static bool NavTrackCorrector.endIsPinned(List<NavTrackPoint> points, NavTrackCorrection correction)`

- [ ] **Step 1: Write the failing tests, in a new `group('scaleFactor')`, using the file's `_p` helper.**

```dart
test('scales east and north about the first active sample', () {
  final points = [_p(), _p(timestamp: 1, north: 10), _p(timestamp: 2, north: 10, east: 20)];
  final out = NavTrackCorrector.apply(points, const NavTrackCorrection(scaleFactor: 2));
  expect(out[1].north, closeTo(20, 1e-9));
  expect(out[2].east, closeTo(40, 1e-9));
});
```

Also:
- `depth and timestamp pass through`
- `1.0 is identical to a correction with no scale`, comparing every field
- `pivots on the first active sample when a pre-dive fix moves it off the origin`: build from the same pre-dive shape the file already tests for `activeRange`, assert `out[range.start]` equals the rotated raw sample and pre-range samples are unmoved
- `leaves the post-dive tail alone`: assert a sample after `range.end` equals its rotated raw value
- `sameAsStart still closes`, `point lands on the point`, and `gpsFix lands on the unscaled target`
- `samples before the trust mark are scaled`
- `trust fraction 1 returns the scaled list`
- `a loop changes size under sameAsStart`: a square loop whose end equals its start at scale 2 has `|out[mid]|` twice the raw value
- `endIsPinned`: true for `point` with anchor and end point and for `gpsFix` with a post-dive fix; false for `none`, `sameAsStart`, `point` missing either coordinate, `gpsFix` with no fix, and any mode at trust fraction 1

- [ ] **Step 2: Run them and confirm they fail.**

Run: `flutter test test/features/nav_track/domain/nav_track_corrector_test.dart`
Expected: FAIL with a compile error on `scaleFactor`.

- [ ] **Step 3: Implement.**

In `apply`, between `rotated` and `_resolveTarget`:

```dart
final scaled = correction.scaleFactor == 1
    ? rotated
    : _scale(rotated, activeRange(points), correction.scaleFactor);
```

Every later use of `rotated` in `apply` and the argument to `_resolveTarget` become `scaled`. That is safe for `gpsFix`, whose target comes from `points` rather than from the list. `_scale` is a private static that returns a new list, leaving samples outside the range as they are.

`endIsPinned` returns false when `endMode` is `none` or `sameAsStart` or `trustFraction >= 1`, and otherwise whether `_resolveTarget` over the rotated points returns non-null, so it shares the corrector's own rule.

- [ ] **Step 4: Run them and confirm they pass.**

Run: `flutter test test/features/nav_track/domain/`
Expected: PASS, including the path adapter's and the terrain check's existing tests.

- [ ] **Step 5: Commit.**

```bash
git add lib/features/nav_track/domain/nav_track_corrector.dart test/features/nav_track/domain/nav_track_corrector_test.dart
git commit -m "feat(nav-track): scale a track about the dive's start"
```

### Task 2: Storage and sync

**Files:**
- Modify: `lib/core/database/tables/track_tables.dart`
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` to 335, `migrationVersions`, comment)
- Modify: `lib/core/database/migrations/helpers/track_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart`
- Modify: `lib/features/nav_track/domain/entities/nav_track.dart`
- Modify: `lib/features/nav_track/data/repositories/nav_track_repository.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/site_trip_fields.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (`settings_conflict_field_scaleFactor`, English "Track scale factor")
- Create: `test/core/database/migration_v335_nav_track_scale_factor_test.dart`
- Test: `test/features/nav_track/data/repositories/nav_track_repository_test.dart`, `test/features/nav_track/domain/entities/nav_track_test.dart`, `test/core/services/sync/sync_nav_tracks_test.dart`

**Interfaces:**
- Consumes: `NavTrackCorrection.scaleFactor` from Task 1.
- Produces: `NavTrack.scaleFactor` (double, default 1.0); `route.correction` carries it; `updateCorrection` persists it.

- [ ] **Step 1: Write the failing tests.**

Migration test, modelled on `migration_v330_buddy_excluded_from_rankings_test.dart`:
- `v335 is in the migration ladder`
- `a fresh database has the column, NOT NULL with a default of 1`, asserting `notnull` is 1 and `dflt_value` is `'1'`
- `an existing track upgrades to 100%`, with a raw `nav_tracks` table at `user_version = 332`

Repository: `updateCorrection` round-trips 1.38; reset to `const NavTrackCorrection()` reads back 1.0.
Entity: `copyWith`, `props` and the `correction` getter carry it.
Sync, in `sync_nav_tracks_test.dart`:
- `an older peer's edit keeps the local scale`: a payload with `scaleFactor` removed and a new `name` keeps 1.38 locally
- `a row new here without the key reads 100%`
- `an undo of a first scale save writes 1.0`: save a scale, revert the change log entry, assert the column is 1.0

- [ ] **Step 2: Run them and confirm they fail.**

Run: `flutter test test/core/database/migration_v335_nav_track_scale_factor_test.dart`
Expected: FAIL, `scale_factor` not found.

- [ ] **Step 3: Add the column and the rung.**

Column beside `headingOffsetDeg`, with a doc comment:
`RealColumn get scaleFactor => real().withDefault(const Constant(1))();`

Helper `_assertNavTrackScaleFactorColumn` in `track_migrations.dart`, in the shape of `_assertNavTrackSourceMetadataColumn`, passing `'REAL NOT NULL DEFAULT 1'`, called from `_assertNavTracksSchema`. Rung at the end of `rungs_v231_onward.dart`, with the `if (from < 335)` pair and a comment in the v330 style.

- [ ] **Step 4: Regenerate.**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0 and `grep -c scaleFactor lib/core/database/database.g.dart` is non-zero. Check the count, because codegen can die silently under load.

- [ ] **Step 5: Add the entity field, the repository write and mapper, the conflict field and the label.**

The conflict field is `FieldKind.number`, next to `headingOffsetDeg`. Run `flutter gen-l10n`.

- [ ] **Step 6: Run the affected tests.**

Run: `flutter test test/core/database/ test/features/nav_track/ test/core/services/sync/sync_nav_tracks_test.dart test/core/services/sync/cross_version_roundtrip_test.dart test/features/settings/presentation/conflicts/ test/features/change_log/`
Expected: PASS. Any test pinning the schema number moves with it.

- [ ] **Step 7: Commit, staging explicit paths.**

```bash
git commit -m "feat(nav-track): store a track's scale"
```

### Task 3: The stepper and the pinned hint

**Files:**
- Create: `lib/features/nav_track/presentation/widgets/nav_track_stepper_field.dart`
- Create: `lib/features/nav_track/presentation/widgets/nav_track_scale_control.dart`
- Modify: `lib/features/nav_track/presentation/widgets/nav_track_align_rotation_control.dart`
- Modify: `lib/features/nav_track/presentation/pages/nav_track_align_page.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (`navTrack_align_scaleLabel`, English "Scale:"; `navTrack_align_scalePinnedHint`, English "The end is pinned, so it sets the track's size. Scale only reshapes the path between.")
- Create: `test/features/nav_track/presentation/widgets/nav_track_scale_control_test.dart`
- Test: `test/features/nav_track/presentation/pages/nav_track_align_page_test.dart`

**Interfaces:**
- Consumes: `NavTrackCorrection.scaleFactor` and its limits, `NavTrackCorrector.endIsPinned`.
- Produces:
  - `NavTrackStepperField({required String label, required double value, required double min, required double max, required double step, required String suffix, required String keyPrefix, required ValueChanged<double> onChanged})`, keyed `<keyPrefix>-down`, `<keyPrefix>-field`, `<keyPrefix>-up`
  - `NavTrackScaleControl({required double scaleFactor, required ValueChanged<double> onChanged})`

- [ ] **Step 1: Write the failing tests.**

Control test:
- `shows 100.0 at the default`
- `plus and minus move 1%`: from 1.0, one tap on up reports 1.01
- `typed 103.5 reports 1.035`
- `clamps at 25% and 400%`
- `unreadable text restores the field`
- `reads 112,5 under a German locale`, with the locale set through the pump
- `a new value reseeds an unfocused field`

Page test:
- `a scale change moves the drawn track` and the terrain summary is scheduled
- `Save persists the scale, Cancel does not, Reset returns it to 100%`
- `the hint shows only while the end is pinned`, across `point` and `sameAsStart`

- [ ] **Step 2: Run them and confirm they fail.**

Run: `flutter test test/features/nav_track/presentation/widgets/nav_track_scale_control_test.dart`
Expected: FAIL, no such file to import.

- [ ] **Step 3: Extract `NavTrackStepperField` from `NavTrackRotationControl`.**

Everything but the label, range, step and suffix moves across unchanged, and the outer `Row` takes `mainAxisSize: MainAxisSize.min`. `NavTrackRotationControl` becomes a thin wrapper with `keyPrefix: 'nav-track-align-rotate'`, except that its field key stays `nav-track-align-rotation-field`, so give the field key its own optional parameter. Existing rotation tests must pass untouched.

- [ ] **Step 4: Implement `NavTrackScaleControl`.**

`keyPrefix: 'nav-track-align-scale'`, suffix `%`, range from the correction's limits times 100. Its `value` is `(scaleFactor * 1000).round() / 10`, so floating point noise never reaches the field or a step. It reports `percent / 100`.

- [ ] **Step 5: Wire the page.**

`_transientRoute` passes `scaleFactor`. In `_ControlsPanel`, wrap the rotation control and the scale control in `Wrap(spacing: 16, runSpacing: 4, ...)`, with the hint below it, keyed `nav-track-align-scale-pinned-hint`, in `bodySmall`, while `NavTrackCorrector.endIsPinned(route.points, correction)`.

- [ ] **Step 6: Generate strings and run the tests.**

Run: `flutter gen-l10n && flutter test test/features/nav_track/presentation/`
Expected: PASS.

- [ ] **Step 7: Commit, staging explicit paths.**

```bash
git commit -m "feat(nav-track): add a scale stepper to the alignment page"
```

### Task 4: Handle maths

**Files:**
- Create: `lib/features/nav_track/domain/nav_track_scale_handle.dart`
- Create: `test/features/nav_track/domain/nav_track_scale_handle_test.dart`

**Interfaces:**
- Produces:
  - `const double minScaleHandleDistanceMeters = 10`
  - `int? scaleHandleIndex(List<NavTrackPoint> points, {required int start, required int end})`
  - `double scaleFromDrag({required double pressScale, required double pressDistance, required double currentDistance})`

- [ ] **Step 1: Write the failing tests.**

`scaleHandleIndex`:
- `picks the farthest sample from the first active sample`
- `measures from start, not the origin or sample 0`
- `ignores samples outside the range`
- `is null below 10 m and non-null at exactly 10 m`
- `the first of equal samples wins`

`scaleFromDrag`:
- `(pressScale: 1, pressDistance: 100, currentDistance: 138)` is 1.38
- `(pressScale: 1.5, pressDistance: 200, currentDistance: 100)` is 0.75
- `rounds to 0.1%`: `(1, 3, 3.0101)` is 1.003
- `clamps at 4.0`
- `clamps at 0.25, including a currentDistance of 0`
- `a pressDistance of 0 returns pressScale`

- [ ] **Step 2: Run them and confirm they fail.**

Run: `flutter test test/features/nav_track/domain/nav_track_scale_handle_test.dart`
Expected: FAIL, no such file to import.

- [ ] **Step 3: Implement both as top-level functions.**

`scaleHandleIndex` reads raw north and east only. `scaleFromDrag` rounds with `(value * 1000).round() / 1000` after clamping to the correction's limits.

- [ ] **Step 4: Run them and confirm they pass.**

Run: `flutter test test/features/nav_track/domain/nav_track_scale_handle_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/features/nav_track/domain/nav_track_scale_handle.dart test/features/nav_track/domain/nav_track_scale_handle_test.dart
git commit -m "feat(nav-track): add the scale handle's maths"
```

### Task 5: The handle on the map

**Files:**
- Create: `lib/features/nav_track/presentation/widgets/nav_track_scale_handle_layer.dart`
- Modify: `lib/features/nav_track/presentation/pages/nav_track_align_page.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (`navTrack_align_scaleHandleLabel`, English "Drag to resize the track")
- Create: `test/features/nav_track/presentation/widgets/nav_track_scale_handle_layer_test.dart`
- Test: `test/features/nav_track/presentation/pages/nav_track_align_page_test.dart`

**Interfaces:**
- Consumes: `scaleHandleIndex`, `scaleFromDrag`, `offsetToGeoPoint`, `distanceMeters`.
- Produces: `NavTrackScaleHandleLayer({required GeoPoint point, required GeoPoint pivot, required double scaleFactor, required ValueChanged<double> onChanged})`, keyed `nav-track-align-scale-handle`.

- [ ] **Step 1: Write the failing tests.**

Layer test, pumping a real `FlutterMap` with a fixed camera:
- `dragging away from the pivot grows the scale`
- `dragging toward it shrinks the scale`
- `a sideways drag at constant distance leaves the scale alone`
- `does not pan the map`: `camera.center` is unchanged after a drag
- `tracks on a rotated map`: with `camera.rotation` at 90, a drag away from the pivot on screen still grows the scale, and the handle ends within a pixel of the pointer

Page test:
- `the handle shows once the track is on the map`
- `it is hidden with no anchor`, `on a track under 10 m`, `while placing a point` and `while the end is pinned`
- `a handle drag updates the scale field live`
- `the handle stays under the pointer with Same as start and trust set`

- [ ] **Step 2: Run them and confirm they fail.**

Run: `flutter test test/features/nav_track/presentation/widgets/nav_track_scale_handle_layer_test.dart`
Expected: FAIL, no such file to import.

- [ ] **Step 3: Implement the layer as a `StatefulWidget`.**

A `MarkerLayer` with one 36 by 36 `Marker`, the same size as `NavTrackDraggableMarker`. Its child is a `GestureDetector` with `onPanStart`, `onPanUpdate`, `onPanEnd` and `dragStartBehavior: DragStartBehavior.down`, not a `Listener`. A pan recognizer inside the map claims the gesture from the map's scale recognizer, because its slop is smaller, so the map does not pan. That is why this differs from `NavTrackDraggableMarker`.

Convert a pointer with `camera.screenOffsetToLatLng(box.globalToLocal(global))`, where `camera` is `MapCamera.of(context)` and `box` is the map's `RenderBox`, found through a `GlobalKey` the page passes in if the marker's own ancestor lookup does not reach it. On start, hold `scaleFactor` and the distance to `pivot`. On update, call `onChanged(scaleFromDrag(...))`.

The glyph is a white `Icons.open_in_full` on an amber circle with a white border, wrapped in `Semantics(label: ...)` and `Tooltip`. Add the import of `DragStartBehavior` from `gestures.dart`.

- [ ] **Step 4: Wire the page.**

In `_AlignPageBody.build`, compute `handleIndex = scaleHandleIndex(route.points, start: activeStart, end: activeEnd)`. Add the layer before the start marker when `anchor != null`, `handleIndex != null`, `state._placing == _Placing.none` and `!NavTrackCorrector.endIsPinned(route.points, correction)`. `point` is `offsetToGeoPoint(anchor, ...)` of `corrected[handleIndex]`, `pivot` the same of `corrected[activeStart]`, and `onChanged` goes through `_updateCorrection`.

- [ ] **Step 5: Generate strings and run the tests.**

Run: `flutter gen-l10n && flutter test test/features/nav_track/presentation/`
Expected: PASS.

- [ ] **Step 6: Commit, staging explicit paths.**

```bash
git commit -m "feat(nav-track): drag a handle to scale a track"
```

### Task 6: Detail page, and the marker fixes if Task 0 found them

**Files:**
- Modify: `lib/features/nav_track/presentation/pages/nav_track_detail_page.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (`navTrack_detail_scaleStatus`, English "Track scale: {percent}%", `percent` a String placeholder)
- Test: `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart`
- If needed: `lib/features/nav_track/presentation/widgets/nav_track_align_map_layers.dart`, `lib/features/nav_track/presentation/pages/nav_track_align_page.dart`

- [ ] **Step 1: Write the failing tests.**

- `the correction card shows the scale away from 100%`, reading "Track scale: 138%"
- `no scale line at 100%`
- `a scale change reframes the map`, modelled on the existing `_framingOf` test

If Task 0 confirmed a marker bug, add `a start marker drag tracks on a rotated map` and `a start marker drag does not pan the map`.

- [ ] **Step 2: Run them and confirm they fail.**

Run: `flutter test test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart`
Expected: FAIL on the new tests.

- [ ] **Step 3: Implement.**

Add `route.scaleFactor` to `_framingOf`. Show the line beside the correction status when `scaleFactor != 1`, formatting the percent with `NumberFormat('0.#', locale)` rather than the input helpers, which are not for display.

If the marker bugs are real, convert `NavTrackDraggableMarker` to the same `GestureDetector` pan and the same camera conversion as Task 5, with `_dragPoint` taking the pointer's ground position. Do not fix bugs Task 0 did not find.

- [ ] **Step 4: Run the tests.**

Run: `flutter gen-l10n && flutter test test/features/nav_track/`
Expected: PASS.

- [ ] **Step 5: Commit, staging explicit paths.**

```bash
git commit -m "feat(nav-track): show a track's scale on its detail page"
```

If marker fixes were made, commit them separately as `fix(nav-track): keep marker drags under the pointer` and note them for the PR's Follow-ups.

### Task 7: Final checks and after screenshots

**Files:** none new.

- [ ] **Step 1: Run the checks.**

Run: `dart format . && flutter analyze && flutter test test/architecture/ test/shared/ test/features/nav_track/ test/core/database/ test/core/services/sync/`
Expected: no format changes, no analyzer issues, all tests pass.

- [ ] **Step 2: Try it in the running app.**

Rebuild, open the same track, and confirm a handle drag fits the track, that it survives Save and reopening, and that the detail map and the 3D view follow. On a rotated map, confirm the handle stays under the pointer.

- [ ] **Step 3: Capture after shots of the same screens, plus the handle mid-drag and the pinned hint.**

Name them `<nn>-<screen>-after[-phone].png`.
