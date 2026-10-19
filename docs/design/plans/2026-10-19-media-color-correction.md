# Display-only Media Color Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show underwater photos and videos with natural colour inside Submersion, automatically (depth-informed) or by hand, without ever writing to a media file or cached copy.

**Architecture:** Every correction reduces to one 4x5 colour matrix drawn with `ColorFiltered` at the existing render points (`MediaItemView` and the viewer's `VideoPlayer`). Per-item hand adjustments are a JSON column on the synced `media` row; the per-diver switch is a `diver_settings` column. Pixel statistics for the automatic fix are computed on device from a 64 px decode and cached in memory only. Video frames for per-moment correction come from a new `extractFrames` call in the existing `submersion_transcoder` plugin on all five platforms.

**Tech Stack:** Flutter, Riverpod 3, Drift, `package:image` 4.x, `submersion_transcoder` (AVFoundation, Media3/MediaMetadataRetriever, C++/WinRT, ffmpeg CLI), `video_player`, `photo_view`.

**Spec:** `docs/design/specs/2026-10-19-media-color-correction-design.md` (issue #3520; follow-up #3521).

## Global Constraints

- Nothing writes to a photo or video file, an OS thumbnail, an app thumbnail, a video poster, or a media store upload. The only new bytes are the `media.color_adjustment` value and the existing share temp file.
- Automatic correction is off by default for every diver; column default `false`, no backfill.
- Automatic correction considers only items with a `diveId`, never documents, site attachments without a dive, equipment paperwork or library-only items.
- Surface shot: enrichment `matchConfidence == MatchConfidence.estimated` (outside the recorded profile), or `!isWithinDiveWindow`, or `depthMeters < 1.0`.
- One schema rung, v292, adds both columns. `minimumCompatibleSchemaVersion` stays 280.
- UI English says "color" (app convention, e.g. "Metric Colors"). No emojis, no em dashes in any string.
- Every new ARB key is added to all 11 ARB files (`test/l10n/arb_parity_test.dart`), translated (not English copies), then `flutter gen-l10n`.
- Depth in labels goes through `UnitFormatter.formatDepth` with the active diver's units.
- New files stay under 400 lines where practical, 800 max (`database_table_libraries_test.dart` enforces 800 for tables/migrations).
- Before each commit: `dart format .`, `flutter analyze`, the task's tests, and `flutter test test/architecture/ test/shared/` when files were added under `lib/`.

## Review Focus

1. **Black water and night dives:** a photo that is nearly all black (or all clipped) yields no statistics; the automatic fix leaves it untouched and nothing throws. Test in Task 2.
2. **Already-balanced shots** (strobe-lit, red present) at depth: gains stay near 1, so the automatic fix barely changes them. Test in Task 2.
3. **Malformed or future `color_adjustment` JSON** (from a newer peer or a hand-edited row): parsed as "no adjustment" or with unknown keys ignored, never a crash in a grid. Test in Task 1.
4. **An older peer that lacks the column** syncs the row: the newer device's adjustment survives (existing overlay). Test in Task 4.
5. **Frame extraction unavailable** (Linux without ffmpeg, store-only video, failing codec): the video falls back to poster statistics plus depth, and playback is unaffected. Test in Task 10.

---

### Task 0: Before screenshots (no code changes yet)

**Files:**
- Create (throwaway, never committed): `test/zz_color_screenshots_test.dart` using `matchesGoldenFile` with `--update-goldens` and a real font loaded in `setUpAll`

- [ ] **Step 1: Render the current screens**: the photo viewer with its toolbar (phone 390x844 and desktop 1280x800), the Photos & Media page's Display card, and a dive media grid; light and dark.
- [ ] **Step 2: Copy the PNGs to the scratchpad** as `<nn>-<screen>-before[-dark][-phone].png`, then delete the throwaway test and its goldens (`git status` shows nothing).

---

### Task 1: Color matrix and adjustment value objects

**Files:**
- Create: `lib/features/media/domain/color/color_matrix.dart`
- Create: `lib/features/media/domain/color/color_adjustment.dart`
- Test: `test/features/media/domain/color/color_matrix_test.dart`
- Test: `test/features/media/domain/color/color_adjustment_test.dart`

**Interfaces:**
- Produces:
  - `class ColorMatrix` (immutable, `Equatable`): `const ColorMatrix(List<double> values)` (20 entries, Flutter `ColorFilter.matrix` layout: rows R,G,B,A; columns r,g,b,a,offset; offsets on the 0-255 scale). `static const identity`. `bool get isIdentity` (within 1e-6). `ColorMatrix then(ColorMatrix next)` (apply `this` first, then `next`). `static ColorMatrix lerp(ColorMatrix a, ColorMatrix b, double t)`. `static ColorMatrix gains(double r, double g, double b)`. `static ColorMatrix redFromGreen(double a)` (R' = R + a*G). `static ColorMatrix warmth(double w)`, `tint(double t)`, `brightness(double b)`, `contrast(double c)`, `saturation(double s)`. `(int, int, int) applyToPixel(int r, int g, int b)` clamped 0..255.
  - `class ColorAdjustment` (immutable, `Equatable`, `copyWith`): fields `bool? autoOverride` (null follows the diver setting), `double strength` (0..1, default 1.0), `double warmth`, `tint`, `brightness`, `contrast`, `saturation` (each -1..1, default 0), `WhitePoint? whitePoint`. `bool get isNeutral` (all defaults). `ColorAdjustment withSlidersFrom(ColorAdjustment source)` (copies autoOverride and the six sliders, keeps this whitePoint). `String toJsonString()`, `static ColorAdjustment? fromJsonString(String? raw)`.
  - `class WhitePoint` (`Equatable`): `final double r, g, b` (0..1, sampled from the uncorrected image).

- [ ] **Step 1: Write failing matrix tests**

```dart
test('identity leaves a pixel unchanged', () {
  expect(ColorMatrix.identity.applyToPixel(10, 120, 200), (10, 120, 200));
  expect(ColorMatrix.identity.isIdentity, isTrue);
});
test('then applies left first', () {
  final m = ColorMatrix.redFromGreen(0.5).then(ColorMatrix.gains(2, 1, 1));
  expect(m.applyToPixel(20, 100, 0), (140, 100, 0)); // (20 + 50) * 2
});
test('lerp at 0 and 1 returns the ends', () {
  final g = ColorMatrix.gains(2, 1, 0.5);
  expect(ColorMatrix.lerp(ColorMatrix.identity, g, 0), ColorMatrix.identity);
  expect(ColorMatrix.lerp(ColorMatrix.identity, g, 1), g);
});
test('warmth +1 raises red 25% and lowers blue 25%', () {
  expect(ColorMatrix.warmth(1).applyToPixel(100, 100, 100), (125, 100, 75));
});
test('tint +1 (magenta) lowers green 20%', () {
  expect(ColorMatrix.tint(1).applyToPixel(100, 100, 100), (100, 80, 100));
});
test('brightness +1 adds 64 to each channel', () {
  expect(ColorMatrix.brightness(1).applyToPixel(10, 10, 10), (74, 74, 74));
});
test('contrast +1 doubles distance from 128', () {
  expect(ColorMatrix.contrast(1).applyToPixel(160, 96, 128), (192, 64, 128));
});
test('saturation -1 gives Rec. 709 grey', () {
  final (r, g, b) = ColorMatrix.saturation(-1).applyToPixel(255, 0, 0);
  expect(r, g); expect(g, b); expect(r, 54); // 0.2126 * 255
});
test('results clamp to 0..255', () {
  expect(ColorMatrix.gains(4, 1, 1).applyToPixel(200, 0, 0).$1, 255);
});
```

- [ ] **Step 2: Write failing adjustment tests**

```dart
test('round-trips through JSON, omitting defaults', () {
  const a = ColorAdjustment(autoOverride: true, warmth: 0.3,
      whitePoint: WhitePoint(0.4, 0.6, 0.7));
  final s = a.toJsonString();
  expect(jsonDecode(s), {'v': 1, 'auto': true, 'warmth': 0.3, 'white': [0.4, 0.6, 0.7]});
  expect(ColorAdjustment.fromJsonString(s), a);
});
test('null, empty, malformed and non-object JSON give null', () {
  for (final raw in [null, '', '{', '[1]', '"x"']) {
    expect(ColorAdjustment.fromJsonString(raw), isNull);
  }
});
test('unknown keys and a newer version are tolerated', () {
  expect(ColorAdjustment.fromJsonString('{"v":9,"tint":0.2,"future":1}'),
      const ColorAdjustment(tint: 0.2));
});
test('out-of-range values clamp', () {
  expect(ColorAdjustment.fromJsonString('{"v":1,"warmth":5,"strength":-1}'),
      const ColorAdjustment(warmth: 1, strength: 0));
});
test('withSlidersFrom copies sliders and auto, keeps own white point', () {
  const target = ColorAdjustment(warmth: -0.5, whitePoint: WhitePoint(0.5, 0.5, 0.6));
  const source = ColorAdjustment(autoOverride: false, warmth: 0.4, contrast: 0.2,
      whitePoint: WhitePoint(0.1, 0.2, 0.3));
  expect(target.withSlidersFrom(source), const ColorAdjustment(
      autoOverride: false, warmth: 0.4, contrast: 0.2,
      whitePoint: WhitePoint(0.5, 0.5, 0.6)));
});
test('isNeutral only for all defaults', () {
  expect(const ColorAdjustment().isNeutral, isTrue);
  expect(const ColorAdjustment(autoOverride: false).isNeutral, isFalse);
});
```

- [ ] **Step 3: Run both test files, expect FAIL (types not defined)**

Run: `flutter test test/features/media/domain/color/`

- [ ] **Step 4: Implement both files**

Factor definitions (pinned): warmth `gains(1 + 0.25w, 1, 1 - 0.25w)`; tint `gains(1, 1 - 0.2t, 1)`; brightness offset `64 * b` on R,G,B; contrast `k = 1 + c`, `v' = k*v + 128*(1 - k)`; saturation `s' = 1 + s` with Rec. 709 luma weights (0.2126, 0.7152, 0.0722). JSON key names: `v`, `auto`, `strength`, `warmth`, `tint`, `brightness`, `contrast`, `saturation`, `white`.

- [ ] **Step 5: Run tests, expect PASS; commit**

```bash
git add lib/features/media/domain/color/ test/features/media/domain/color/
git commit -m "feat(media): color matrix and per-item color adjustment values"
```

---

### Task 2: Pixel statistics and the automatic correction

**Files:**
- Create: `lib/features/media/domain/color/channel_stats.dart`
- Create: `lib/features/media/domain/color/auto_correction.dart`
- Test: `test/features/media/domain/color/channel_stats_test.dart`
- Test: `test/features/media/domain/color/auto_correction_test.dart`

**Interfaces:**
- Consumes: `ColorMatrix` (Task 1).
- Produces:
  - `class ChannelStats` (`Equatable`): `meanR`, `meanG`, `meanB` (0..1). `static ChannelStats? fromRgba(Uint8List rgba, {int stride = 1})`. `bool get looksUnderwater`.
  - `class AutoCorrectionParams` (`Equatable`): `redFromGreen`, `gainR`, `gainG`, `gainB`. `static const none` (0, 1, 1, 1). `ColorMatrix toMatrix()` = `redFromGreen(a).then(gains(...))`. `static AutoCorrectionParams lerp(a, b, t)`. `AutoCorrectionParams boundedFor(double? depthMeters)` (re-applies the depth limits below, used per video moment).
  - `AutoCorrectionParams computeAutoCorrection(ChannelStats stats, {double? depthMeters})`.
  - `double depthFactor(double? depthMeters)`.

Pinned algorithm (values from the spec's limits, chosen here):
- `fromRgba`: skip pixels with luma < 0.04 or any channel > 0.98; return null if fewer than 5% of the pixels remain.
- `looksUnderwater`: `meanR < 0.6 * max(meanG, meanB) && max(meanG, meanB) > 0.15`.
- `depthFactor`: null gives 1.0; otherwise `(depth / 15).clamp(0.2, 1.0)`; below 1.0 m gives 0.
- `a = min(0.5 * f, 0.5 * max(0, (meanG - meanR) / meanG))`; `r1 = meanR + a * meanG`; `grey = (r1 + meanG + meanB) / 3`.
- Gains `grey / mean`, clamped: `gainR` to `[1, 1 + 1.5 f]`, `gainG` to `[0.8, 1.25]`, `gainB` to `[0.6, 1.1]`.
- Purple cap: `gainR * r1 <= 1.05 * gainG * meanG` and `gainB * meanB <= 1.05 * gainG * meanG` (reduce the offending gain).

- [ ] **Step 1: Write failing stats tests**

```dart
Uint8List solid(int r, int g, int b, {int n = 100}) =>
    Uint8List.fromList([for (var i = 0; i < n; i++) ...[r, g, b, 255]]);
test('means of a solid blue-green image', () {
  final s = ChannelStats.fromRgba(solid(26, 102, 153))!;
  expect(s.meanR, closeTo(0.102, 0.001));
  expect(s.looksUnderwater, isTrue);
});
test('all-black and all-clipped images give null', () {
  expect(ChannelStats.fromRgba(solid(2, 2, 2)), isNull);
  expect(ChannelStats.fromRgba(solid(255, 255, 255)), isNull);
});
test('a warm beach photo does not look underwater', () {
  expect(ChannelStats.fromRgba(solid(200, 170, 120))!.looksUnderwater, isFalse);
});
```

- [ ] **Step 2: Write failing auto-correction tests**

```dart
const deepBlue = ChannelStats(meanR: 0.08, meanG: 0.40, meanB: 0.55);
test('warms a deep blue shot and never goes purple', () {
  final p = computeAutoCorrection(deepBlue, depthMeters: 25);
  expect(p.redFromGreen, greaterThan(0));
  expect(p.gainR, greaterThan(1));
  final r = p.gainR * (deepBlue.meanR + p.redFromGreen * deepBlue.meanG);
  expect(r, lessThanOrEqualTo(1.05 * p.gainG * deepBlue.meanG + 1e-9));
  expect(p.gainB * deepBlue.meanB, lessThanOrEqualTo(1.05 * p.gainG * deepBlue.meanG + 1e-9));
});
test('a 5 m shot is corrected less than a 25 m shot', () {
  final shallow = computeAutoCorrection(deepBlue, depthMeters: 5);
  final deep = computeAutoCorrection(deepBlue, depthMeters: 25);
  expect(shallow.gainR, lessThan(deep.gainR));
  expect(shallow.redFromGreen, lessThan(deep.redFromGreen));
});
test('a balanced strobe-lit shot is left almost alone', () {
  final p = computeAutoCorrection(
      const ChannelStats(meanR: 0.45, meanG: 0.47, meanB: 0.50), depthMeters: 20);
  expect(p.gainR, closeTo(1, 0.1));
  expect(p.gainG, closeTo(1, 0.1));
  expect(p.gainB, closeTo(1, 0.1));
  expect(p.redFromGreen, lessThan(0.05));
});
test('shallower than 1 m is no correction', () {
  expect(computeAutoCorrection(deepBlue, depthMeters: 0.6), AutoCorrectionParams.none);
});
test('boundedFor re-clamps interpolated params to the moment depth', () {
  final deep = computeAutoCorrection(deepBlue, depthMeters: 25);
  expect(deep.boundedFor(3).gainR, lessThanOrEqualTo(1 + 1.5 * depthFactor(3)));
  expect(deep.boundedFor(0.5), AutoCorrectionParams.none);
});
```

- [ ] **Step 3: Run, expect FAIL; implement; run, expect PASS**

Run: `flutter test test/features/media/domain/color/`

- [ ] **Step 4: Commit**

```bash
git add lib/features/media/domain/color/ test/features/media/domain/color/
git commit -m "feat(media): depth-bounded automatic color correction"
```

---

### Task 3: Correction policy, composition and video track

**Files:**
- Create: `lib/features/media/domain/color/color_correction_policy.dart`
- Create: `lib/features/media/domain/color/video_color_track.dart`
- Test: `test/features/media/domain/color/color_correction_policy_test.dart`
- Test: `test/features/media/domain/color/video_color_track_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2; `MediaItem`, `MediaEnrichment`, `MatchConfidence` (`lib/features/media/domain/entities/media_item.dart`).
- Produces:
  - `bool isSurfaceShot(MediaEnrichment? e)`: true when `e != null` and (`e.matchConfidence == MatchConfidence.estimated` or `e.depthMeters != null && e.depthMeters! < 1.0`).
  - `bool autoEnabledFor(MediaItem item, {required bool diverAutoEnabled})`: `(item.colorAdjustment?.autoOverride ?? diverAutoEnabled) && item.diveId != null && !item.isDocument`.
  - `enum AutoNeed { none, stats }` and `AutoNeed autoNeedFor(MediaItem item, {required bool diverAutoEnabled})`: `none` when auto is off, the item has a white point, or (photo) `isSurfaceShot(item.enrichment)`; otherwise `stats`.
  - `ColorMatrix composeCorrection({required ColorAdjustment? adjustment, AutoCorrectionParams? auto})`: base = white-point gains if present, else `auto?.toMatrix()`, else identity; `lerp(identity, base, strength)`; then `warmth`, `tint`, `saturation`, `contrast`, `brightness` in that order.
  - `AutoCorrectionParams? autoParamsForPhoto(MediaItem item, ChannelStats? stats)`: null when `stats == null`; when `item.enrichment?.depthMeters == null`, requires `stats.looksUnderwater`; else `computeAutoCorrection(stats, depthMeters: depth)`.
  - `ColorMatrix whitePointGains(WhitePoint w)`: `avg / channel` per channel, each clamped to `[0.5, 3.0]`.
  - `class VideoColorTrack` (`Equatable`): `List<VideoColorKey> keys` sorted by `seconds`; `AutoCorrectionParams paramsAt(double seconds, {double? Function(double seconds)? depthAt})` (linear between neighbouring keys, held at the ends, then `boundedFor(depthAt?.call(seconds))` when `depthAt` is given); `AutoCorrectionParams get average`.
  - `class VideoColorKey` (`Equatable`): `double seconds`, `AutoCorrectionParams params`.
  - `List<double> frameSampleTimes(Duration duration, {int count = 7})`: `(i + 0.5) / count * duration` in seconds.

- [ ] **Step 1: Write failing policy tests** covering: surface by `estimated`; surface by 0.6 m; not surface at 18 m `interpolated`; auto off when `diveId == null` even with override true; override false beats diver true; override true beats diver false; `autoNeedFor` is `none` with a white point; `composeCorrection(adjustment: null, auto: null).isIdentity`; strength 0 with auto gives identity; white point replaces auto (compare against `whitePointGains` alone); sliders apply on top with no auto (warmth 1 equals `ColorMatrix.warmth(1)`); `autoParamsForPhoto` returns null for a non-underwater stat with no depth and non-null at 18 m.

- [ ] **Step 2: Write failing track tests** covering: `frameSampleTimes(Duration(seconds: 70))` equals `[5, 15, 25, 35, 45, 55, 65]`; `paramsAt` midway between two keys equals `AutoCorrectionParams.lerp(a, b, 0.5)`; before the first key and after the last key hold the end values; `depthAt` returning 0.5 gives `none`; `average` of two keys is their midpoint.

- [ ] **Step 3: Run, expect FAIL; implement; run, expect PASS**

Run: `flutter test test/features/media/domain/color/`

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(media): color correction policy and per-moment video track"
```

---

### Task 4: Schema v292, entity, settings field and sync guards

**Files:**
- Modify: `lib/core/database/tables/media_tables.dart` (add `TextColumn get colorAdjustment => text().nullable()();` after `displaySize`, inside the coverage block, with a `// v292` comment)
- Modify: `lib/core/database/tables/diver_tables.dart` (add `BoolColumn get autoColorCorrection => boolean().withDefault(const Constant(false))();` with a `// v292` comment)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 292`; append `// v292: media.color_adjustment, diver_settings.auto_color_correction (issue #3520).` then `292,`)
- Modify: `lib/core/database/migrations/helpers/media_migrations.dart` (`_assertMediaColorAdjustmentColumn()`, PRAGMA-guarded like `_assertMediaSiteAttachmentColumns`; call it from `_assertMediaRowColumns`)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (`_assertAutoColorCorrectionColumn()` via `_addColumnIfMissing('diver_settings', 'auto_color_correction', 'INTEGER NOT NULL DEFAULT 0 CHECK (auto_color_correction IN (0, 1))')`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung `if (from < 292) { await _assertMediaColorAdjustmentColumn(); await _assertAutoColorCorrectionColumn(); }` plus `reportProgress`)
- Modify: `lib/core/database/migrations/before_open.dart` (one line: `await _assertAutoColorCorrectionColumn();`; the media one rides `_assertMediaRowColumns`)
- Modify: `lib/features/media/domain/entities/media_item.dart` (`final ColorAdjustment? colorAdjustment;`, constructor, `copyWith` with `_undefined`, `props`)
- Modify: `lib/features/media/data/repositories/media_row_mapper.dart` (`colorAdjustment: ColorAdjustment.fromJsonString(row.colorAdjustment)`)
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`createMedia` and `updateMedia` companions write `Value(item.colorAdjustment?.toJsonString())`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings.autoColorCorrection` default false, `copyWith`, `SettingsNotifier.setAutoColorCorrection(bool value)`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (three spots: `createSettingsForDiver`, `_storedColumns`, `_mapRowToAppSettings`)
- Modify: the four explicit `SettingsNotifier` fakes: `test/helpers/mock_providers.dart`, `test/features/insights/presentation/pages/records_page_test.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/media_library_fields.dart` (`'colorAdjustment'`, `FieldKind.opaque`) and `.../diver_settings_fields.dart` (`'autoColorCorrection'`, `FieldKind.boolean`, alphabetical)
- Modify: all 11 `lib/l10n/arb/app_*.arb`: `settings_conflict_field_colorAdjustment` ("Color adjustment"), `settings_conflict_field_autoColorCorrection` ("Automatic color correction")
- Test: `test/core/database/migration_v292_color_correction_test.dart` (template: `migration_v266_media_site_attachment_test.dart` and `migration_v276_icd_warnings_test.dart`)
- Test: extend `test/features/settings/presentation/providers/settings_notifier_real_test.dart`
- Test: `test/features/media/data/media_color_adjustment_roundtrip_test.dart`

**Interfaces:**
- Produces: `MediaItem.colorAdjustment`, `AppSettings.autoColorCorrection`, `SettingsNotifier.setAutoColorCorrection(bool)`, Drift `MediaData.colorAdjustment` (`String?`), `DiverSetting.autoColorCorrection` (`bool`).

- [ ] **Step 1: Write the failing migration test**: `currentSchemaVersion >= 292`; `migrationVersions` contains 292; `migrationStepCount(291) == migrationStepCount(292) + 1`; `minimumCompatibleSchemaVersion == 280`; upgrading a raw v291 db adds `media.color_adjustment` (null on an existing row, row kept) and `diver_settings.auto_color_correction` (0 on an existing row); beforeOpen heals a db stamped 292 that lacks both columns.
- [ ] **Step 2: Write the failing round-trip test**: `createMedia` with `ColorAdjustment(warmth: 0.3)` then `getMediaById` returns it; `updateMedia` with `colorAdjustment: null` clears it; a row whose column holds `'{'` maps to `colorAdjustment == null`; serializing the row with the sync serializer and importing it through the overlay with the `colorAdjustment` key removed (older peer) keeps the local value (pattern: `test/core/services/sync/cross_version_roundtrip_test.dart`).
- [ ] **Step 3: Write the failing notifier test**: `setAutoColorCorrection(true)` persists and reloads as true; a fresh diver reads false.
- [ ] **Step 4: Run the three tests, expect FAIL**
- [ ] **Step 5: Implement the listed changes; `dart run build_runner build --delete-conflicting-outputs`; `flutter gen-l10n`**
- [ ] **Step 6: Run** `flutter test test/core/database test/core/services/sync test/features/settings test/features/media/data test/l10n`; expect PASS (includes `conflict_field_catalogue_coverage_test.dart`, `arb_parity_test.dart`, `database_table_libraries_test.dart`)
- [ ] **Step 7: Commit**: `feat(media): store per-item color adjustments and the diver's auto switch (v292)`

---

### Task 5: Color adjustment writer with bulk apply and undo

**Files:**
- Create: `lib/features/media/data/repositories/media_color_adjustment_repository.dart` (MediaRepository is past the size ceiling; follow `site_attachment_repository.dart`)
- Modify: `lib/features/media/presentation/providers/media_providers.dart` (`mediaColorAdjustmentRepositoryProvider`)
- Test: `test/features/media/data/repositories/media_color_adjustment_repository_test.dart`

**Interfaces:**
- Produces:
  - `Future<void> setColorAdjustment(String mediaId, ColorAdjustment? adjustment)`: neutral is stored as null; writes `updatedAt`, `markRecordPending(entityType: 'media', ...)`, `SyncEventBus.notifyLocalChange()`; throws `StateError` when no row matched.
  - `Future<Map<String, ColorAdjustment?>> applySlidersToDive({required String diveId, required String sourceMediaId, required ColorAdjustment source})`: in one transaction, every other non-document media row on the dive gets `(existing ?? const ColorAdjustment()).withSlidersFrom(source)`; returns each target's prior value keyed by id; marks each pending.
  - `Future<void> restoreColorAdjustments(Map<String, ColorAdjustment?> prior)`: writes each prior back (rows deleted since are skipped), marks pending.
  - `Future<int> countOtherMediaOnDive(String diveId, String excludeMediaId)` (for the confirmation).

- [ ] **Step 1: Write failing tests**: set then read; neutral stored as null column; unknown id throws `StateError`; apply copies sliders and auto to 3 siblings, keeps a sibling's own white point, skips documents and the source; returned prior holds the old values (including null); restore puts them back exactly; each write leaves a pending sync record (`SyncRepository` pending query, as in the site attachment tests); count excludes the source and documents.
- [ ] **Step 2: Run, expect FAIL; implement; run, expect PASS**
- [ ] **Step 3: Commit**: `feat(media): save color adjustments and apply them across a dive`

---

### Task 6: Analysis service and correction providers

**Files:**
- Create: `lib/features/media/data/services/color_analysis_service.dart`
- Create: `lib/features/media/presentation/providers/color_correction_providers.dart`
- Test: `test/features/media/data/services/color_analysis_service_test.dart`
- Test: `test/features/media/presentation/providers/color_correction_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 1-3, `settingsProvider`.
- Produces:
  - `class ColorAnalysisService`: `Future<ChannelStats?> statsFor(String key, ImageProvider source)`: decodes `ResizeImage(source, width: 64, policy: ResizeImagePolicy.fit)`, reads `toByteData(format: rawStraightRgba)`, returns `ChannelStats.fromRgba`; memoizes by key (LRU, 1000 entries, also memoizes null); coalesces concurrent requests for one key; at most 2 decodes at once; never throws (a failed decode is null). `ChannelStats? peek(String key)`.
  - `final colorAnalysisServiceProvider = Provider<ColorAnalysisService>` (keep alive).
  - `final diverAutoColorCorrectionProvider = Provider<bool>` (`settingsProvider.select((s) => s.autoColorCorrection)`).
  - `colorAdjustmentDraftNotifierProvider`: `NotifierProvider.family<ColorAdjustmentDraft, ColorAdjustment?, String>` (by media id) with `set(ColorAdjustment?)` and `clear()`. While non-null it wins over the stored value (live slider feedback).
  - `colorPeekOriginalNotifierProvider`: `NotifierProvider<ColorPeekOriginal, String?>` with `peek(String mediaId)` and `release()`; the peeked item draws uncorrected.
  - `ColorAdjustment? effectiveAdjustment(WidgetRef ref, MediaItem item)` helper: draft, else `item.colorAdjustment`.
  - `String colorStatsKey(MediaItem item)`: `'${item.id}|${item.updatedAt.millisecondsSinceEpoch}'`.

- [ ] **Step 1: Write failing service tests** with `MemoryImage` of a generated PNG (`img.encodePng` of a solid 8x8 blue image): stats returned; second call does not decode again (count decodes with a wrapping `ImageProvider` subclass); two concurrent calls share one decode; a provider that errors yields null and is memoized; a third concurrent key waits while two decodes are in flight (use completers).
- [ ] **Step 2: Write failing provider tests**: draft overrides stored; `clear` falls back to stored; peek sets and releases; `diverAutoColorCorrectionProvider` follows `settingsProvider` overrides.
- [ ] **Step 3: Run, expect FAIL; implement; run, expect PASS** (run with `tester.runAsync` where image decoding is involved)
- [ ] **Step 4: Commit**: `feat(media): on-device color analysis with a bounded in-memory cache`

---

### Task 7: Draw the correction everywhere through MediaItemView

**Files:**
- Create: `lib/features/media/presentation/widgets/color_corrected.dart`
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart` (wrap the memo `Image` (~L442), the `FileData` arm (~L473), the `NetworkData` arm (~L474) and the `BytesData` arm (~L487); placeholders, shimmer, error tiles and document pages stay unwrapped)
- Test: `test/features/media/presentation/widgets/color_corrected_test.dart`
- Test: extend `test/features/media/presentation/widgets/media_item_view_test.dart`

**Interfaces:**
- Consumes: Task 6 providers, Task 3 policy.
- Produces: `class ColorCorrected extends ConsumerStatefulWidget { const ColorCorrected({required MediaItem item, required ImageProvider analysisSource, required Widget child, VideoColorTrack? track}); }`. It builds `child` unchanged when the composed matrix is identity or the item is peeked; otherwise `ColorFiltered(colorFilter: ColorFilter.matrix(m.values), child: child)`. It requests stats only when `autoNeedFor` is `stats`, and uses `track.average` for videos when a track is available (Task 10 passes it).

- [ ] **Step 1: Write failing widget tests**: no adjustment and auto off renders no `ColorFiltered`; warmth 0.5 renders a `ColorFiltered` whose matrix equals `composeCorrection(adjustment: ColorAdjustment(warmth: 0.5))`; auto on for a dive photo at 18 m with a blue `analysisSource` renders a non-identity filter after stats resolve; a surface shot (`estimated`) with auto on renders none; an item without `diveId` with auto on renders none; peeking the item renders none; `MediaItemView` with `BytesData` and an adjustment wraps the `Image` in `ColorFiltered`, and its unavailable placeholder is never wrapped.
- [ ] **Step 2: Run, expect FAIL; implement; run, expect PASS**

Run: `flutter test test/features/media/presentation/widgets/`

- [ ] **Step 3: Commit**: `feat(media): draw color corrections on every media tile`

---

### Task 8: Settings switch in Photos & Media

**Files:**
- Modify: `lib/features/settings/presentation/pages/photos_media_hub_page.dart` (in the "Display" card, a `Column` with the existing provenance switch, a `Divider`, then a `SwitchListTile` with `secondary: Icon(Icons.palette_outlined)`, `value: ref.watch(settingsProvider.select((s) => s.autoColorCorrection))`, `onChanged: ref.read(settingsProvider.notifier).setAutoColorCorrection`)
- Modify: all 11 ARBs: `settings_media_autoColorCorrection` ("Automatic color correction"), `settings_media_autoColorCorrectionSubtitle` ("Warms up blue underwater photos and videos on screen, using the depth each was taken at. Your files are never changed.")
- Test: extend `test/features/settings/photos_media_hub_test.dart`

- [ ] **Step 1: Write the failing test**: the switch shows off by default; tapping it calls `setAutoColorCorrection(true)` (fake notifier with one override plus `noSuchMethod`, as in `icd_warnings_toggle_test.dart`).
- [ ] **Step 2: Run, expect FAIL; implement; `flutter gen-l10n`; run, expect PASS**
- [ ] **Step 3: Commit**: `feat(settings): automatic color correction switch in Photos & Media`

---

### Task 9: Native video frame extraction in submersion_transcoder

**Files:**
- Modify: `packages/submersion_transcoder/lib/src/transcode_engine.dart` (add `Future<List<Uint8List?>> extractFrames({required File source, required List<Duration> times, int maxDimension = 160})`, JPEG bytes per time, null for a time that failed)
- Modify: `packages/submersion_transcoder/lib/src/channel_transcode_engine.dart` (method `extractFrames`, args `{path, timesMs, maxDimension}`, returns `List<Object?>` of `Uint8List?`; `MissingPluginException`/`PlatformException` give all nulls)
- Modify: `packages/submersion_transcoder/lib/src/linux_ffmpeg_engine.dart` (one `ffmpeg -v error -ss <t> -i <src> -frames:v 1 -vf scale=<max>:<max>:force_original_aspect_ratio=decrease -f image2 -c:v mjpeg pipe:1` per time via `ProcessRunner`; missing ffmpeg gives all nulls)
- Modify: `packages/submersion_transcoder/darwin/Classes/SubmersionTranscoderPlugin.swift` (+ new `FrameExtractor.swift`: `AVAssetImageGenerator`, `appliesPreferredTrackTransform = true`, `maximumSize`, tolerances 0.5 s, on `DispatchQueue.global(qos: .userInitiated)`, JPEG via `NSBitmapImageRep`/`UIImage.jpegData` 0.8)
- Modify: `packages/submersion_transcoder/android/src/main/kotlin/app/submersion/transcoder/SubmersionTranscoderPlugin.kt` (+ `FrameExtractor.kt`: `MediaMetadataRetriever.getScaledFrameAtTime(us, OPTION_CLOSEST_SYNC, w, h)` on a background executor, `Bitmap.compress(JPEG, 80)`; accepts a file path or a `content://` URI)
- Modify: `packages/submersion_transcoder/windows/submersion_transcoder_plugin.cpp` (C++/WinRT `MediaClip::CreateFromFileAsync` + `MediaComposition::GetThumbnailAsync(TimeSpan, w, h, VideoFramePrecision::NearestFrame)`, read the stream to bytes; on the existing worker-thread pattern with an MTA apartment; result posted back like the progress path)
- Test: `packages/submersion_transcoder/test/channel_extract_frames_test.dart` (mock channel: args shape, results mapping, exception gives nulls)
- Test: `packages/submersion_transcoder/test/linux_ffmpeg_extract_frames_test.dart` (fake `ProcessRunner`: argv per time, non-zero exit gives null for that time, missing binary gives all nulls)
- Test: extend `integration_test/darwin_transcode_test.dart` (synthesized clip: 3 frames returned, each decodes, longest side <= 160)

**Interfaces:**
- Produces: `TranscodeEngine.extractFrames(...)` reachable through `createTranscodeEngine()` (`engine_factory.dart`).

- [ ] **Step 1: Write the two failing Dart tests; run** `cd packages/submersion_transcoder && flutter test`; expect FAIL
- [ ] **Step 2: Implement the Dart engines; run; expect PASS**
- [ ] **Step 3: Implement darwin, Android and Windows natives; extend the darwin integration test**
- [ ] **Step 4: Verify natives compile**: `flutter test integration_test/darwin_transcode_test.dart -d macos` (expect PASS, no skips); Android: a debug APK compile (`flutter build apk --debug`) succeeds; Windows and iOS are compiled by CI's build jobs.
- [ ] **Step 5: Commit**: `feat(media): extract video frames at chosen times on every platform`

---

### Task 10: Per-moment video correction in the viewer, averaged on tiles

**Files:**
- Create: `lib/features/media/presentation/providers/video_color_track_provider.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (`_VideoItemState` draw site ~L1281: wrap `VideoPlayer(controller)` in `_VideoColorFilter`, a `ValueListenableBuilder<VideoPlayerValue>` that composes the matrix for `value.position`)
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart` (for video items pass `track: ref.watch(videoColorTrackProvider(item)).value` to `ColorCorrected`)
- Test: `test/features/media/presentation/providers/video_color_track_provider_test.dart`
- Test: extend `test/features/media/presentation/pages/media_viewer_video_test.dart`

**Interfaces:**
- Consumes: Task 9 `extractFrames`, `resolvedFilePathProvider`, `diveProfileProvider(diveId)`, `MediaItem.enrichment.elapsedSeconds`, `MediaItem.durationSeconds`.
- Produces:
  - `videoColorTrackProvider`: `FutureProvider.family<VideoColorTrack?, MediaItem>` (keep alive per media id + `updatedAt`): null when auto is not needed; otherwise extracts 7 frames at `frameSampleTimes`, computes stats per frame (drop nulls), auto params per frame using the profile depth at `elapsedSeconds + t`; when no frame survives, one key at 0 from the poster stats (via `ColorAnalysisService.peek`/`statsFor`) with the start depth; at most one extraction at a time app-wide.
  - `double? Function(double seconds) videoDepthLookup(List<DiveProfilePoint> profile, int? startElapsedSeconds)`: linear interpolation in the profile; null outside the profile (treated as surface by `boundedFor`).
  - `transcodeEngineProvider` (`Provider<TranscodeEngine>`, `createTranscodeEngine()`), overridable in tests.

- [ ] **Step 1: Write failing provider tests** with a fake `TranscodeEngine`: 7 frames requested at the pinned times; a blue frame set at 20 m gives warming keys; all-null frames fall back to a single poster key; engine throwing falls back the same way (Review Focus 5); auto off gives null without calling the engine; the depth lookup interpolates and is null outside the profile.
- [ ] **Step 2: Write failing viewer test** (existing `_FakeVideoPlatform`): with a track whose first key is `none` and last key warms, the `ColorFiltered` matrix at position 0 is identity and at the end is non-identity; the player still initializes when the provider returns null.
- [ ] **Step 3: Run, expect FAIL; implement; run, expect PASS**
- [ ] **Step 4: Commit**: `feat(media): video color correction that follows the clip`

---

### Task 11: The Adjust color panel

**Files:**
- Create: `lib/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart`
- Create: `lib/features/media/presentation/widgets/color_adjust/color_adjust_sliders.dart`
- Create: `lib/features/media/presentation/widgets/color_adjust/apply_to_dive_action.dart`
- Create: `lib/features/media/presentation/widgets/color_adjust/color_correction_label.dart`
- Modify: all 11 ARBs (keys below)
- Test: `test/features/media/presentation/widgets/color_adjust/color_adjust_panel_test.dart`
- Test: `test/features/media/presentation/widgets/color_adjust/apply_to_dive_action_test.dart`
- Test: `test/features/media/presentation/widgets/color_adjust/color_correction_label_test.dart`

**Interfaces:**
- Consumes: Tasks 5 and 6.
- Produces:
  - `class ColorAdjustPanel extends ConsumerStatefulWidget { const ColorAdjustPanel({required MediaItem item, required VoidCallback onDone, required VoidCallback onPickWhite, bool pickWhiteAvailable = true, Axis layout = Axis.horizontal}); }` (`Axis.vertical` when docked right). Chips: Auto (`FilterChip`, toggles `autoOverride` against the diver default), Pick white, Original (press-and-hold peeks). Sliders: Strength (disabled when there is neither auto nor a white point), Warmth, Tint, and Brightness, Contrast, Saturation under a "More" `ExpansionTile` (expanded by default when docked). `onChanged` sets the draft; `onChangeEnd` saves via `setColorAdjustment` and clears the draft. Footer: Reset (saves null), Apply to this dive (only when `item.diveId != null`), Done.
  - `Future<void> runApplyToDive(BuildContext context, WidgetRef ref, MediaItem item, ColorAdjustment source)`: zero siblings shows nothing; otherwise a confirmation dialog with the count; on confirm `applySlidersToDive`, then a `SnackBar` (5 s, `showCloseIcon`) with an Undo action calling `restoreColorAdjustments` (pattern: `bulk_equipment_tag_sheet.dart`). The messenger and l10n are captured before awaiting.
  - `class ColorCorrectionLabel extends ConsumerWidget { const ColorCorrectionLabel({required MediaItem item}); }`: "Adjusted" when the effective adjustment is not neutral; "<depth> · auto" when auto applies and depth is known; "Auto" when auto applies without depth; nothing otherwise.
- ARB keys (English): `media_color_adjustAction` "Adjust color", `media_color_auto` "Auto", `media_color_pickWhite` "Pick white", `media_color_pickWhiteHint` "Tap something that should be white or gray", `media_color_original` "Original", `media_color_strength` "Strength", `media_color_warmth` "Warmth", `media_color_tint` "Tint", `media_color_more` "More", `media_color_brightness` "Brightness", `media_color_contrast` "Contrast", `media_color_saturation` "Saturation", `media_color_reset` "Reset", `media_color_done` "Done", `media_color_applyToDive` "Apply to this dive", `media_color_applyToDiveTitle` "Apply to this dive?", `media_color_applyToDiveBody` "{count, plural, =1{1 other photo or video will use these adjustments.} other{{count} other photos and videos will use these adjustments.}} Their own white points are kept.", `media_color_apply` "Apply", `media_color_appliedToDive` "{count, plural, =1{Updated 1 photo or video} other{Updated {count} photos and videos}}", `media_color_undo` "Undo", `media_color_undoFailed` "Couldn't undo the change", `media_color_saveFailed` "Couldn't save the color adjustment", `media_color_labelAutoDepth` "{depth} · auto", `media_color_labelAuto` "Auto", `media_color_labelAdjusted` "Adjusted".

- [ ] **Step 1: Write failing panel tests**: dragging Warmth sets the draft live and saves once on release; Strength is disabled with auto off and no white point; Auto chip on an item while the diver setting is off saves `autoOverride: true`; Reset saves null; Apply to this dive is hidden without `diveId`; holding Original peeks and releases; the More fold holds the three tone sliders.
- [ ] **Step 2: Write failing apply tests**: confirm dialog shows "3 other photos and videos"; cancel writes nothing; confirm applies and the snackbar Undo restores the prior map (fake repository).
- [ ] **Step 3: Write failing label tests**: metric "18 m · auto", imperial "59 ft · auto" (diver units), "Adjusted", "Auto", nothing.
- [ ] **Step 4: Run, expect FAIL; implement; `flutter gen-l10n`; run, expect PASS**
- [ ] **Step 5: Commit**: `feat(media): adjust color panel with apply to dive and undo`

---

### Task 12: Viewer integration (toolbar, layout, hold to compare, pick white)

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_viewer_toolbar.dart` (optional `onAdjustColor`; `MediaViewerAction(id: 'adjust_color', icon: Icons.palette_outlined, label: l10n.media_color_adjustAction, priority: 3)`; perdix and later priorities shift by one)
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (state `_colorPanelOpen`, `_pickingWhite`; when open, width `>= ResponsiveBreakpoints.desktop` gives `Row(Expanded(viewer), SizedBox(width: 320, child: panel))`, narrower gives `Column(Expanded(viewer), panel)`; the panel follows `_currentIndex`; long-press on the photo tap catcher and on the video item peeks; `ColorCorrectionLabel` bottom-left over the photo while the overlay shows)
- Create: `lib/features/media/presentation/helpers/white_point_sampler.dart`
- Modify: `lib/features/media/presentation/pages/site_media_viewer_page.dart` (an `IconButton` in `_TopOverlay` opening the same panel with the same layout rule; no pick white for videos there, since it has no player)
- Test: extend `test/features/media/presentation/widgets/media_viewer_toolbar_test.dart` (new action visible at desktop width, overflow order at 360 and 412)
- Test: `test/features/media/presentation/pages/media_viewer_color_panel_test.dart`
- Test: `test/features/media/presentation/helpers/white_point_sampler_test.dart`
- Test: extend `test/features/media/presentation/pages/site_media_viewer_page_test.dart`

**Interfaces:**
- Produces:
  - `WhitePoint? averageWhiteAround(ByteData rgba, int width, int height, Offset at, {int radius = 4})`: mean of the square, 0..1; null when out of bounds or the patch is nearly black (luma < 0.04).
  - Photo pick: with the item peeked for one frame, `RepaintBoundary` around the gallery, `toImage(pixelRatio: 1)`, sample at the tap, save `adjustment.copyWith(whitePoint: ...)`.
  - Video pick (paused only): `extractFrames(times: [position], maxDimension: 640)`, map the tap from the contain-fit `AspectRatio` box to frame pixels, sample, save.

- [ ] **Step 1: Write failing sampler tests**: a 10x10 patch average; out-of-bounds gives null; black patch gives null.
- [ ] **Step 2: Write failing viewer tests**: the action opens the panel under the photo at 400 px wide and docked right at 1200 px; swiping to the next item retargets the panel; holding the photo removes the `ColorFiltered`; the label shows for an adjusted photo; site viewer shows the action and opens the panel.
- [ ] **Step 3: Update toolbar expectations; run, expect FAIL; implement; run, expect PASS**

Run: `flutter test test/features/media/presentation/`

- [ ] **Step 4: Commit**: `feat(media): adjust color from the photo and site viewers`

---

### Task 13: Share photos with the correction applied

**Files:**
- Create: `lib/features/media/data/services/corrected_photo_encoder.dart`
- Modify: `lib/features/media/data/services/local_exif_loader.dart` (extract `img.ExifData? readExifFromBytes(Uint8List bytes, String mime)`; `readLocalExif` delegates to it)
- Create: `lib/features/media/presentation/helpers/share_color_matrix.dart`
- Modify: `lib/features/media/presentation/helpers/media_share_helper.dart` (before `writeShareTempFile`, photos with a non-identity matrix are re-encoded)
- Modify: `lib/features/media/presentation/pages/site_media_viewer_page.dart` (`_shareCurrentItem` uses the same step)
- Modify: `lib/features/media/data/services/media_share_temp_file.dart` (optional `filenameOverride`)
- Test: `test/features/media/data/services/corrected_photo_encoder_test.dart`
- Test: `test/features/media/presentation/helpers/share_color_matrix_test.dart`
- Test: extend the share helper test (or create `test/features/media/presentation/helpers/media_share_helper_test.dart`)

**Interfaces:**
- Produces:
  - `class CorrectedPhoto { final Uint8List bytes; final String filename; }`
  - `Future<CorrectedPhoto?> encodeCorrectedPhoto({required Uint8List bytes, required ColorMatrix matrix, required String filename, required String mime})`: decodes with `decodeWithFlutterCodec` (HEIC and EXIF orientation handled), applies the matrix per pixel in a `compute` isolate, encodes JPEG quality 92 with the original EXIF copied (orientation set to 1); the filename gets a `.jpg` extension; returns null on any failure (the caller then shares the original).
  - `Future<ColorMatrix> shareColorMatrixFor(WidgetRef ref, MediaItem item, Uint8List bytes)`: identity for videos and documents; otherwise `composeCorrection` with stats from `ColorAnalysisService.statsFor(colorStatsKey(item), MemoryImage(bytes))` when `autoNeedFor` is `stats`.

- [ ] **Step 1: Write failing encoder tests**: a JPEG with EXIF (`DateTimeOriginal`, GPS) and orientation 6, encoded with `ColorMatrix.warmth(1)`: output decodes, the red mean rose, `DateTimeOriginal` and GPS are kept, orientation is 1, the dimensions follow orientation; identity input is not used by callers (helper test); a corrupt input gives null.
- [ ] **Step 2: Write failing share tests**: a photo with warmth shares a `.jpg` temp file whose bytes differ from the original; a photo with no correction shares the original bytes untouched; a video with an adjustment shares the original file; an encoder failure falls back to the original.
- [ ] **Step 3: Run, expect FAIL; implement; run, expect PASS**
- [ ] **Step 4: Commit**: `feat(media): share photos with their color correction applied`

---

### Task 14: Screenshots, full verification, docs

**Files:**
- Create (throwaway, never committed): the Task 0 screenshot test, re-created
- Modify: `docs/design/specs/2026-10-19-media-color-correction-design.md` only if implementation settled a "Builder's call" worth recording

- [ ] **Step 1: Capture after images** of the Task 0 screens plus the open panel (phone and desktop, light and dark) and a grid with correction on. Save in the scratchpad as `<nn>-<screen>-after[-dark][-phone].png`; delete the throwaway test and goldens.
- [ ] **Step 2: Full checks**: `dart format .`; `flutter analyze` (no issues); `flutter test test/features/media test/features/settings test/core test/architecture test/shared test/l10n packages/submersion_transcoder` (all PASS).
- [ ] **Step 3: Commit any doc touch**: `docs(media): record color correction build decisions`
