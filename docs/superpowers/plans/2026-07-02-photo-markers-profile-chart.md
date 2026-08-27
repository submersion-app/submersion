# Photo Markers on Dive Profile Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render camera-icon markers on the dive detail profile chart at each photo's (time, depth), with tap-to-preview thumbnail cards, zoom-aware clustering, and an on-by-default legend toggle plus persisted settings default.

**Architecture:** Photo positions come from the existing `MediaEnrichment` records (`elapsedSeconds`, `depthMeters`) already computed at import time. Markers render as a widget overlay (`PhotoMarkerOverlay`) inside `DiveProfileChart`'s existing `Stack`, above the fl_chart `LineChart`, using the chart's viewport bounds and plot insets for a linear data-to-pixel mapping — the same pattern as the gas-strip cursor extensions. Visibility follows the #242 template: `ProfileLegendState.showPhotoMarkers` (live) seeded from `AppSettings.defaultShowPhotoMarkers` (persisted, DB column, schema v96).

**Tech Stack:** Flutter, fl_chart, Riverpod, Drift (schema v95 → v96), flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-07-02-photo-markers-profile-chart-design.md`

## Global Constraints

- Work in the worktree at `.claude/worktrees/issue-162-photo-markers` on branch `worktree-issue-162-photo-markers`. Never touch the main checkout.
- All commands run from the worktree root.
- `dart format .` must produce no changes before every commit (run it, then commit).
- No emojis anywhere in code, comments, or docs.
- Commit messages: conventional style (`feat(scope): ...`), no Co-Authored-By lines, no generated-with footers.
- Every user-visible string goes in `lib/l10n/arb/app_en.arb` AND all 10 locale files (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`), then `flutter gen-l10n`. Simple strings carry no `@` metadata block.
- Run specific test files (`flutter test test/path/file.dart`), never whole directories (they time out).
- All depths shown to the user go through `UnitFormatter` / `units.convertDepth` (respect diver unit settings). Internal storage stays metric.
- Drift codegen: after editing `lib/core/database/database.dart`, run `dart run build_runner build --delete-conflicting-outputs`. Never hand-edit `database.g.dart`.
- If a push is ever needed: `git push --no-verify` (the worktree pre-push hook runs against the main tree and reports false failures).

---

### Task 1: Persisted setting `defaultShowPhotoMarkers` (schema v96)

**Files:**
- Modify: `lib/core/database/database.dart` (column ~line 914, `currentSchemaVersion` line 1717, `migrationVersions` list ~line 1722, `onUpgrade` block after the `if (from < 95)` block ~line 4355)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field ~line 261, ctor ~line 370, copyWith ~lines 497/604, setter ~line 1146)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (insert ~line 137, update ~line 273, load ~line 447)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (backfill map ~line 3166)
- Modify: `test/helpers/mock_providers.dart` (~line 250)
- Create: `test/core/database/migration_v96_photo_markers_test.dart`
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart`, `test/core/services/sync/sync_diver_settings_fallback_test.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `AppSettings.defaultShowPhotoMarkers` (bool, default `true`), `SettingsNotifier.setDefaultShowPhotoMarkers(bool value)` (returns `Future<void>`). Tasks 2 and 6 depend on these exact names.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v96_photo_markers_test.dart` (template: `migration_v91_ascent_rate_line_test.dart`, adjusted for a default-TRUE column):

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v96 adds default_show_photo_markers to diver_settings, default 1',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 95');
          // Minimal pre-v96 diver_settings shape: just enough columns to
          // insert a row. The v96 migration adds default_show_photo_markers.
          rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute(
            "INSERT INTO diver_settings (id, diver_id, created_at, updated_at) "
            "VALUES ('s1', 'd1', 1, 1)",
          );
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('default_show_photo_markers'));

      // Existing rows read the new column as the SQL default (1 / true).
      final row = await db
          .customSelect(
            "SELECT default_show_photo_markers FROM diver_settings "
            "WHERE id = 's1'",
          )
          .getSingle();
      expect(row.data['default_show_photo_markers'], 1);
    },
  );

  test('v96 is the latest schema version and is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, 96);
    expect(AppDatabase.migrationVersions, contains(96));
  });

  test('v96 migration is idempotent when the column already exists', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 95');
        rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            default_show_photo_markers INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO diver_settings "
          "(id, diver_id, default_show_photo_markers, created_at, updated_at) "
          "VALUES ('s1', 'd1', 0, 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toList();

    // Column present exactly once (no duplicate ALTER).
    expect(names.where((n) => n == 'default_show_photo_markers').length, 1);

    // The pre-existing value is preserved, not reset to the new default.
    final row = await db
        .customSelect(
          "SELECT default_show_photo_markers FROM diver_settings "
          "WHERE id = 's1'",
        )
        .getSingle();
    expect(row.data['default_show_photo_markers'], 0);
  });
}
```

- [ ] **Step 2: Run the migration test to verify it fails**

Run: `flutter test test/core/database/migration_v96_photo_markers_test.dart`
Expected: FAIL (`currentSchemaVersion` is 95, column missing).

Note: if a pre-existing test asserts `currentSchemaVersion == 95` as a "latest version tripwire" (see the comment convention in the v91 test), find it with `grep -rn "currentSchemaVersion, 95" test/` and relax that file's assertion to `greaterThanOrEqualTo(95)` in Step 3 — that is the established convention when the ladder grows.

- [ ] **Step 3: Add the column, version bump, and migration**

In `lib/core/database/database.dart`:

(a) Column on the `DiverSettings` table, directly after the `defaultShowAscentRateLine` declaration (~line 914), inside its own coverage-ignore block matching the sibling's comment style:

```dart
  // coverage:ignore-start
  BoolColumn get defaultShowPhotoMarkers =>
      boolean().withDefault(const Constant(true))();
  // coverage:ignore-end
```

(b) Bump `static const int currentSchemaVersion = 95;` (line 1717) to `96`.

(c) Append `96,` to the end of the `static const List<int> migrationVersions = [...]` list (~line 1722, currently ends at `95`).

(d) In `onUpgrade`, after the `if (from < 95) await reportProgress();` line (~line 4355), add (template: the v91 block at lines 4276-4296, but `DEFAULT 1`):

```dart
        if (from < 96) {
          // Persisted default for the "Photo Markers" profile overlay
          // (issue #162). Guarded like v91: skip when diver_settings does
          // not exist (minimal-schema migration tests) or the column is
          // already present (interrupted upgrade).
          final cols = await customSelect(
            "PRAGMA table_info('diver_settings')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('default_show_photo_markers')) {
              await customStatement(
                'ALTER TABLE diver_settings '
                'ADD COLUMN default_show_photo_markers '
                'INTEGER NOT NULL DEFAULT 1',
              );
            }
          }
        }
        if (from < 96) await reportProgress();
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes without errors; `database.g.dart` gains the column.

- [ ] **Step 5: Run the migration test to verify it passes**

Run: `flutter test test/core/database/migration_v96_photo_markers_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Write the failing settings round-trip test**

In `test/features/settings/presentation/providers/settings_notifier_real_test.dart`, next to the `setDefaultShowAscentRateLine` test (~line 296):

```dart
    test('setDefaultShowPhotoMarkers persists the new default', () async {
      container.read(settingsProvider.notifier);
      await waitForInit();

      // Added as a persisted default in v96; photo markers start visible.
      expect(container.read(settingsProvider).defaultShowPhotoMarkers, isTrue);
      await container
          .read(settingsProvider.notifier)
          .setDefaultShowPhotoMarkers(false);
      expect(
        container.read(settingsProvider).defaultShowPhotoMarkers,
        isFalse,
      );
    });
```

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: FAIL to compile (`defaultShowPhotoMarkers` undefined).

- [ ] **Step 7: Add the AppSettings field, copyWith, setter, and persistence**

In `lib/features/settings/presentation/providers/settings_providers.dart`, mirroring `defaultShowGasSwitchMarkers` (the default-true sibling) at each site:

(a) Field, after `defaultShowGasSwitchMarkers` (~line 261):

```dart
  /// Default visibility for photo markers on dive profile
  final bool defaultShowPhotoMarkers;
```

(b) Constructor parameter (~line 370): `this.defaultShowPhotoMarkers = true,`

(c) copyWith parameter (~line 497): `bool? defaultShowPhotoMarkers,`

(d) copyWith assignment (~line 604):

```dart
      defaultShowPhotoMarkers:
          defaultShowPhotoMarkers ?? this.defaultShowPhotoMarkers,
```

(e) Setter on `SettingsNotifier`, after `setDefaultShowGasSwitchMarkers` (~line 1146):

```dart
  Future<void> setDefaultShowPhotoMarkers(bool value) async {
    state = state.copyWith(defaultShowPhotoMarkers: value);
    await _saveSettings();
  }
```

In `lib/features/settings/data/repositories/diver_settings_repository.dart`, one line at each of the three sites, next to the `defaultShowGasSwitchMarkers` line:

- `createSettingsForDiver` (~line 137): `defaultShowPhotoMarkers: Value(s.defaultShowPhotoMarkers),`
- `updateSettingsForDiver` (~line 273): `defaultShowPhotoMarkers: Value(settings.defaultShowPhotoMarkers),`
- `_mapRowToAppSettings` (~line 447): `defaultShowPhotoMarkers: row.defaultShowPhotoMarkers,`

In `test/helpers/mock_providers.dart`, after the `setDefaultShowAscentRateLine` override (~line 250):

```dart
  @override
  Future<void> setDefaultShowPhotoMarkers(bool value) async =>
      state = state.copyWith(defaultShowPhotoMarkers: value);
```

- [ ] **Step 8: Run the round-trip test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: PASS (all tests in file).

- [ ] **Step 9: Sync serializer backfill + failing sync fallback test**

In `test/core/services/sync/sync_diver_settings_fallback_test.dart`, extend the existing test: add `..remove('defaultShowPhotoMarkers')` to the `legacy` map construction (after `..remove('showAscentRateColors')`), and at the end of the test add:

```dart
      // v96 column hydrates to its default rather than throwing.
      expect(row.defaultShowPhotoMarkers, isTrue);
```

Run: `flutter test test/core/services/sync/sync_diver_settings_fallback_test.dart`
Expected: FAIL (missing non-nullable column throws, or expectation fails).

Then in `lib/core/services/sync/sync_data_serializer.dart`, in the backfill map next to `'defaultShowAscentRateLine': false,` (~line 3166):

```dart
      // Non-nullable bool added in v96; seed payloads predating the column.
      'defaultShowPhotoMarkers': true,
```

Run: `flutter test test/core/services/sync/sync_diver_settings_fallback_test.dart`
Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(settings): add persisted defaultShowPhotoMarkers setting (schema v96)"
```

---

### Task 2: Legend state `showPhotoMarkers`

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`
- Test: `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`

**Interfaces:**
- Consumes: `AppSettings.defaultShowPhotoMarkers` (Task 1).
- Produces: `ProfileLegendState.showPhotoMarkers` (bool), `ProfileLegend.togglePhotoMarkers()`. Task 5 depends on these exact names.

- [ ] **Step 1: Write the failing provider tests**

In `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`, next to the `showAscentRateLine seeds from ...` test (~line 317), using the same `_StubSettingsNotifier` already defined in that file:

```dart
    test('showPhotoMarkers seeds from defaultShowPhotoMarkers', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(
              const AppSettings(defaultShowPhotoMarkers: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLegendProvider).showPhotoMarkers, isFalse);
    });

    test('togglePhotoMarkers flips the state', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(const AppSettings()),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLegendProvider).showPhotoMarkers, isTrue);
      container.read(profileLegendProvider.notifier).togglePhotoMarkers();
      expect(container.read(profileLegendProvider).showPhotoMarkers, isFalse);
    });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: FAIL to compile (`showPhotoMarkers` undefined).

- [ ] **Step 3: Add the state field everywhere `showGasSwitchMarkers` appears**

In `lib/features/dive_log/presentation/providers/profile_legend_provider.dart`, run `grep -n "showGasSwitchMarkers" lib/features/dive_log/presentation/providers/profile_legend_provider.dart` and mirror every site with `showPhotoMarkers`. Concretely:

(a) Field, after `final bool showGasSwitchMarkers;` (~line 38):

```dart
  final bool showPhotoMarkers;
```

(b) Constructor default, after `this.showGasSwitchMarkers = true,` (~line 82):

```dart
    this.showPhotoMarkers = true,
```

(c) `activeSecondaryCount`, after `if (showGasSwitchMarkers) count++;` (~line 122):

```dart
    if (showPhotoMarkers) count++;
```

(d) copyWith parameter and assignment (mirror `showGasSwitchMarkers` at ~lines 153/189 region):

```dart
    bool? showPhotoMarkers,
...
      showPhotoMarkers: showPhotoMarkers ?? this.showPhotoMarkers,
```

(e) `operator ==` (~line 229 region): `showPhotoMarkers == other.showPhotoMarkers &&`

(f) `hashCode` list (~line 264 region): `showPhotoMarkers,`

(g) `build()` seed, after `showGasSwitchMarkers: settings.defaultShowGasSwitchMarkers,` (~line 316):

```dart
      showPhotoMarkers: settings.defaultShowPhotoMarkers,
```

(h) Toggle method, after `toggleGasSwitchMarkers()` (~line 403):

```dart
  void togglePhotoMarkers() {
    state = state.copyWith(showPhotoMarkers: !state.showPhotoMarkers);
  }
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/providers/profile_legend_provider_test.dart`
Expected: PASS (all tests in file).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dive_log): add showPhotoMarkers legend state seeded from settings"
```

---

### Task 3: `PhotoChartMarker` model + pure layout/clustering functions

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/photo_marker_layout.dart`
- Create: `test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart`

**Interfaces:**
- Consumes: `MediaItem`, `MediaEnrichment`, `MediaType`, `MatchConfidence` from `package:submersion/features/media/domain/entities/media_item.dart`.
- Produces (Tasks 4, 5, 7 depend on these exact signatures):
  - `class PhotoChartMarker { final MediaItem item; final int elapsedSeconds; final double depthMeters; }`
  - `List<PhotoChartMarker> photoMarkersFromMedia(List<MediaItem> media, {required int maxProfileSeconds})`
  - `class PhotoMarkerCluster { final List<int> memberIndexes; final double x; final double y; }` (x/y are plot-relative pixels)
  - `List<PhotoMarkerCluster> clusterPhotoMarkers({required List<({double seconds, double depthDisplay})> points, required double visibleMinSeconds, required double visibleMaxSeconds, required double visibleMinDepth, required double visibleMaxDepth, required double plotWidth, required double plotHeight, double mergeRadiusPx})`

- [ ] **Step 1: Write the failing unit tests**

Create `test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

MediaItem _media({
  String id = 'm1',
  MediaType type = MediaType.photo,
  MediaEnrichment? enrichment,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return MediaItem(
    id: id,
    diveId: 'dive-1',
    mediaType: type,
    takenAt: now,
    createdAt: now,
    updatedAt: now,
    enrichment: enrichment,
  );
}

MediaEnrichment _enrichment({
  int? elapsedSeconds = 600,
  double? depthMeters = 18.0,
  MatchConfidence confidence = MatchConfidence.exact,
}) {
  return MediaEnrichment(
    id: 'e1',
    mediaId: 'm1',
    diveId: 'dive-1',
    elapsedSeconds: elapsedSeconds,
    depthMeters: depthMeters,
    matchConfidence: confidence,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('photoMarkersFromMedia', () {
    test('maps an enriched photo to a marker', () {
      final markers = photoMarkersFromMedia(
        [_media(enrichment: _enrichment())],
        maxProfileSeconds: 3600,
      );
      expect(markers, hasLength(1));
      expect(markers.single.elapsedSeconds, 600);
      expect(markers.single.depthMeters, 18.0);
    });

    test('excludes videos, missing enrichment, noProfile, and null fields',
        () {
      final markers = photoMarkersFromMedia(
        [
          _media(id: 'v1', type: MediaType.video, enrichment: _enrichment()),
          _media(id: 'm2'),
          _media(
            id: 'm3',
            enrichment:
                _enrichment(confidence: MatchConfidence.noProfile),
          ),
          _media(id: 'm4', enrichment: _enrichment(elapsedSeconds: null)),
          _media(id: 'm5', enrichment: _enrichment(depthMeters: null)),
        ],
        maxProfileSeconds: 3600,
      );
      expect(markers, isEmpty);
    });

    test('clamps elapsed seconds into the profile range and sorts by time',
        () {
      final markers = photoMarkersFromMedia(
        [
          _media(id: 'late', enrichment: _enrichment(elapsedSeconds: 4000)),
          _media(id: 'early', enrichment: _enrichment(elapsedSeconds: -30)),
        ],
        maxProfileSeconds: 3600,
      );
      expect(markers, hasLength(2));
      expect(markers[0].elapsedSeconds, 0);
      expect(markers[1].elapsedSeconds, 3600);
    });
  });

  group('clusterPhotoMarkers', () {
    // A 100x100 plot over 0..1000s and 0..50 depth keeps the math legible:
    // 1 px per 10 s horizontally, 1 px per 0.5 depth units vertically.
    List<PhotoMarkerCluster> cluster(
      List<({double seconds, double depthDisplay})> points, {
      double mergeRadiusPx = 24,
    }) {
      return clusterPhotoMarkers(
        points: points,
        visibleMinSeconds: 0,
        visibleMaxSeconds: 1000,
        visibleMinDepth: 0,
        visibleMaxDepth: 50,
        plotWidth: 100,
        plotHeight: 100,
        mergeRadiusPx: mergeRadiusPx,
      );
    }

    test('maps a single marker linearly into plot pixels', () {
      final clusters = cluster([(seconds: 500.0, depthDisplay: 25.0)]);
      expect(clusters, hasLength(1));
      expect(clusters.single.memberIndexes, [0]);
      expect(clusters.single.x, closeTo(50, 0.001));
      expect(clusters.single.y, closeTo(50, 0.001));
    });

    test('merges markers within the radius at the mean position', () {
      final clusters = cluster([
        (seconds: 500.0, depthDisplay: 20.0),
        (seconds: 600.0, depthDisplay: 30.0), // 10 px right of the first
      ]);
      expect(clusters, hasLength(1));
      expect(clusters.single.memberIndexes, [0, 1]);
      expect(clusters.single.x, closeTo(55, 0.001));
      expect(clusters.single.y, closeTo(50, 0.001));
    });

    test('keeps markers beyond the radius separate', () {
      final clusters = cluster([
        (seconds: 100.0, depthDisplay: 10.0),
        (seconds: 600.0, depthDisplay: 30.0), // 50 px apart
      ]);
      expect(clusters, hasLength(2));
      expect(clusters[0].memberIndexes, [0]);
      expect(clusters[1].memberIndexes, [1]);
    });

    test('omits markers outside the visible time or depth window', () {
      final clusters = clusterPhotoMarkers(
        points: [
          (seconds: 100.0, depthDisplay: 25.0), // left of window
          (seconds: 500.0, depthDisplay: 45.0), // below window
          (seconds: 600.0, depthDisplay: 25.0), // visible
        ],
        visibleMinSeconds: 400,
        visibleMaxSeconds: 800,
        visibleMinDepth: 10,
        visibleMaxDepth: 40,
        plotWidth: 100,
        plotHeight: 100,
      );
      expect(clusters, hasLength(1));
      expect(clusters.single.memberIndexes, [2]);
    });

    test('returns empty for degenerate geometry', () {
      expect(
        clusterPhotoMarkers(
          points: [(seconds: 500.0, depthDisplay: 25.0)],
          visibleMinSeconds: 0,
          visibleMaxSeconds: 0,
          visibleMinDepth: 0,
          visibleMaxDepth: 50,
          plotWidth: 100,
          plotHeight: 100,
        ),
        isEmpty,
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart`
Expected: FAIL to compile (file does not exist).

- [ ] **Step 3: Implement the layout file**

Create `lib/features/dive_log/presentation/widgets/photo_marker_layout.dart`:

```dart
import 'dart:math' as math;

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// A photo positioned on the dive profile chart, derived from the photo's
/// persisted [MediaEnrichment] (computed once at import time).
class PhotoChartMarker {
  /// Source media item; used by the preview card and tap-through navigation.
  final MediaItem item;

  /// Seconds from dive start, clamped to the profile range.
  final int elapsedSeconds;

  /// Depth in meters at capture time.
  final double depthMeters;

  const PhotoChartMarker({
    required this.item,
    required this.elapsedSeconds,
    required this.depthMeters,
  });
}

/// Builds chart markers from a dive's media list, time-sorted. Only photos
/// with a usable profile position are included; elapsed time is clamped to
/// the profile range to absorb entry/exit clock skew.
List<PhotoChartMarker> photoMarkersFromMedia(
  List<MediaItem> media, {
  required int maxProfileSeconds,
}) {
  final markers = <PhotoChartMarker>[];
  for (final item in media) {
    if (item.mediaType != MediaType.photo) continue;
    final enrichment = item.enrichment;
    if (enrichment == null) continue;
    if (enrichment.matchConfidence == MatchConfidence.noProfile) continue;
    final seconds = enrichment.elapsedSeconds;
    final depth = enrichment.depthMeters;
    if (seconds == null || depth == null) continue;
    markers.add(
      PhotoChartMarker(
        item: item,
        elapsedSeconds: math.min(math.max(seconds, 0), maxProfileSeconds),
        depthMeters: depth,
      ),
    );
  }
  markers.sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
  return markers;
}

/// Markers that would overlap at the current zoom, rendered as one chip
/// (with a count badge when there is more than one member).
class PhotoMarkerCluster {
  /// Indexes into the marker list handed to [clusterPhotoMarkers].
  final List<int> memberIndexes;

  /// Chip center in plot-relative pixels (0,0 = top-left of the plot rect).
  final double x;
  final double y;

  const PhotoMarkerCluster({
    required this.memberIndexes,
    required this.x,
    required this.y,
  });
}

/// Maps time-sorted marker [points] into plot pixels for the visible window
/// and greedily merges neighbors whose x positions fall within
/// [mergeRadiusPx] of the open cluster's running center. Zooming in grows
/// pixels-per-second, so clusters split apart with no extra state. Markers
/// outside the visible time or depth window are omitted.
List<PhotoMarkerCluster> clusterPhotoMarkers({
  required List<({double seconds, double depthDisplay})> points,
  required double visibleMinSeconds,
  required double visibleMaxSeconds,
  required double visibleMinDepth,
  required double visibleMaxDepth,
  required double plotWidth,
  required double plotHeight,
  double mergeRadiusPx = 24,
}) {
  final rangeX = visibleMaxSeconds - visibleMinSeconds;
  final rangeY = visibleMaxDepth - visibleMinDepth;
  if (rangeX <= 0 || rangeY <= 0 || plotWidth <= 0 || plotHeight <= 0) {
    return const [];
  }

  final positioned = <({int index, double x, double y})>[];
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    if (p.seconds < visibleMinSeconds || p.seconds > visibleMaxSeconds) {
      continue;
    }
    if (p.depthDisplay < visibleMinDepth || p.depthDisplay > visibleMaxDepth) {
      continue;
    }
    positioned.add((
      index: i,
      x: (p.seconds - visibleMinSeconds) / rangeX * plotWidth,
      y: (p.depthDisplay - visibleMinDepth) / rangeY * plotHeight,
    ));
  }
  if (positioned.isEmpty) return const [];

  final clusters = <PhotoMarkerCluster>[];
  var members = <({int index, double x, double y})>[positioned.first];

  double centerX() =>
      members.map((m) => m.x).reduce((a, b) => a + b) / members.length;

  void close() {
    final cy =
        members.map((m) => m.y).reduce((a, b) => a + b) / members.length;
    clusters.add(
      PhotoMarkerCluster(
        memberIndexes: [for (final m in members) m.index],
        x: centerX(),
        y: cy,
      ),
    );
  }

  for (final p in positioned.skip(1)) {
    if ((p.x - centerX()).abs() <= mergeRadiusPx) {
      members.add(p);
    } else {
      close();
      members = [p];
    }
  }
  close();
  return clusters;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dive_log): add photo marker model and clustering layout"
```

---

### Task 4: `PhotoMarkerOverlay` widget + l10n semantics label

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/photo_marker_overlay.dart`
- Modify: `lib/l10n/arb/app_en.arb` + the 10 locale ARBs
- Create: `test/features/dive_log/presentation/widgets/photo_marker_overlay_test.dart`

**Interfaces:**
- Consumes: `PhotoChartMarker`, `clusterPhotoMarkers`, `PhotoMarkerCluster` (Task 3); `MediaItemView` (`lib/features/media/presentation/widgets/media_item_view.dart`); `PhotoViewerPage(diveId:, initialMediaId:)` (`lib/features/media/presentation/pages/photo_viewer_page.dart`); `UnitFormatter` (`lib/core/utils/unit_formatter.dart`).
- Produces (Task 5 depends on this exact constructor):

```dart
PhotoMarkerOverlay({
  required List<PhotoChartMarker> markers, // time-sorted
  required double visibleMinSeconds,
  required double visibleMaxSeconds,
  required double visibleMinDepth,  // display units (chart Y)
  required double visibleMaxDepth,  // display units (chart Y)
  required ({double left, double top, double right, double bottom}) insets,
  required UnitFormatter units,
  void Function(MediaItem item)? onOpenPhoto, // null = push PhotoViewerPage
})
```

- [ ] **Step 1: Add the l10n key**

In `lib/l10n/arb/app_en.arb`, alphabetically within the `diveLog_profile_semantics_*` group:

```json
  "diveLog_profile_semantics_photoMarker": "Photo marker",
```

And in each locale file (same position, no `@` metadata):

| File | Value |
| --- | --- |
| `app_ar.arb` | `"علامة صورة"` |
| `app_de.arb` | `"Fotomarkierung"` |
| `app_es.arb` | `"Marcador de foto"` |
| `app_fr.arb` | `"Marqueur de photo"` |
| `app_he.arb` | `"סמן תמונה"` |
| `app_hu.arb` | `"Fotójelölő"` |
| `app_it.arb` | `"Indicatore foto"` |
| `app_nl.arb` | `"Fotomarkering"` |
| `app_pt.arb` | `"Marcador de foto"` |
| `app_zh.arb` | `"照片标记"` |

Run: `flutter gen-l10n`
Expected: regenerates without errors.

- [ ] **Step 2: Write the failing widget tests**

Create `test/features/dive_log/presentation/widgets/photo_marker_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

PhotoChartMarker _marker({
  String id = 'm1',
  int seconds = 500,
  double depth = 25.0,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return PhotoChartMarker(
    item: MediaItem(
      id: id,
      diveId: 'dive-1',
      mediaType: MediaType.photo,
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    elapsedSeconds: seconds,
    depthMeters: depth,
  );
}

Widget _overlay({
  required List<PhotoChartMarker> markers,
  double visibleMinSeconds = 0,
  double visibleMaxSeconds = 1000,
  void Function(MediaItem item)? onOpenPhoto,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: PhotoMarkerOverlay(
            markers: markers,
            visibleMinSeconds: visibleMinSeconds,
            visibleMaxSeconds: visibleMaxSeconds,
            visibleMinDepth: 0,
            visibleMaxDepth: 50,
            insets: (left: 30, top: 0, right: 30, bottom: 36),
            units: UnitFormatter(const AppSettings()),
            onOpenPhoto: onOpenPhoto,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders one chip per well-separated marker', (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'a', seconds: 100),
          _marker(id: 'b', seconds: 800),
        ],
      ),
    );
    expect(find.byIcon(Icons.camera_alt), findsNWidgets(2));
  });

  testWidgets('shows a count badge for clustered markers', (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'a', seconds: 500),
          _marker(id: 'b', seconds: 510),
          _marker(id: 'c', seconds: 520),
        ],
      ),
    );
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping a chip opens the preview card; tapping away closes it',
      (tester) async {
    await tester.pumpWidget(_overlay(markers: [_marker()]));
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsNothing);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsOneWidget);
    // Caption shows depth in the diver's units and runtime as m:ss.
    expect(find.textContaining('8:20'), findsOneWidget);

    await tester.tapAt(const Offset(390, 10));
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsNothing);
  });

  testWidgets('tapping the card thumbnail reports the photo', (tester) async {
    MediaItem? opened;
    await tester.pumpWidget(
      _overlay(markers: [_marker()], onOpenPhoto: (item) => opened = item),
    );
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('photoMarkerCardThumb-m1')));
    await tester.pump();
    expect(opened?.id, 'm1');
  });

  testWidgets('cluster card shows one thumbnail per member', (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'a', seconds: 500),
          _marker(id: 'b', seconds: 510),
        ],
      ),
    );
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCardThumb-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('photoMarkerCardThumb-b')), findsOneWidget);
  });

  testWidgets('viewport change dismisses the preview card', (tester) async {
    await tester.pumpWidget(_overlay(markers: [_marker()]));
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsOneWidget);

    // Simulate a zoom: the visible window changes.
    await tester.pumpWidget(
      _overlay(markers: [_marker()], visibleMinSeconds: 200,
          visibleMaxSeconds: 900),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsNothing);
  });

  testWidgets('markers outside the visible window render nothing',
      (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [_marker(seconds: 100)],
        visibleMinSeconds: 400,
        visibleMaxSeconds: 900,
      ),
    );
    expect(find.byIcon(Icons.camera_alt), findsNothing);
  });
}
```

Note: use `tester.pump()` (never `pumpAndSettle`) — `MediaItemView` resolves thumbnails asynchronously and may never settle in tests; missing files fall back to its placeholder, which is fine.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/photo_marker_overlay_test.dart`
Expected: FAIL to compile (overlay file does not exist).

- [ ] **Step 4: Implement the overlay**

Create `lib/features/dive_log/presentation/widgets/photo_marker_overlay.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Camera-icon markers over the dive profile chart at each photo's
/// (time, depth), with a tap-to-preview thumbnail card.
///
/// Rendered as a widget layer above the LineChart (a later Stack child) so
/// its tap targets win hit-testing over the chart's pan/scrub/tooltip
/// gestures without entering fl_chart's touch arena.
class PhotoMarkerOverlay extends StatefulWidget {
  /// Time-sorted markers (see [photoMarkersFromMedia]).
  final List<PhotoChartMarker> markers;

  /// Visible time window in seconds (the chart's zoomed/panned X range).
  final double visibleMinSeconds;
  final double visibleMaxSeconds;

  /// Visible depth window in display units (the chart's Y range, positive).
  final double visibleMinDepth;
  final double visibleMaxDepth;

  /// Reserved axis gutters around the plot rect (the chart's _plotInsets).
  final ({double left, double top, double right, double bottom}) insets;

  final UnitFormatter units;

  /// Invoked when a preview-card thumbnail is tapped. When null, pushes
  /// [PhotoViewerPage] for the photo.
  final void Function(MediaItem item)? onOpenPhoto;

  const PhotoMarkerOverlay({
    super.key,
    required this.markers,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
    required this.visibleMinDepth,
    required this.visibleMaxDepth,
    required this.insets,
    required this.units,
    this.onOpenPhoto,
  });

  @override
  State<PhotoMarkerOverlay> createState() => _PhotoMarkerOverlayState();
}

class _PhotoMarkerOverlayState extends State<PhotoMarkerOverlay> {
  /// First member index of the previewed cluster, or null when closed.
  /// Tracking a member (not the cluster) keeps the selection stable while
  /// clusters re-form during rebuilds.
  int? _selectedIndex;

  static const double _chipSize = 22.0;
  static const double _tapTarget = 32.0;
  static const double _thumbSize = 72.0;
  static const double _cardHeight = 112.0;

  @override
  void didUpdateWidget(PhotoMarkerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A pan/zoom (or data change) invalidates the card's anchor; dismiss.
    if (oldWidget.visibleMinSeconds != widget.visibleMinSeconds ||
        oldWidget.visibleMaxSeconds != widget.visibleMaxSeconds ||
        oldWidget.visibleMinDepth != widget.visibleMinDepth ||
        oldWidget.visibleMaxDepth != widget.visibleMaxDepth ||
        oldWidget.markers.length != widget.markers.length) {
      _selectedIndex = null;
    }
  }

  void _openPhoto(MediaItem item) {
    if (widget.onOpenPhoto != null) {
      widget.onOpenPhoto!(item);
      return;
    }
    final diveId = item.diveId;
    if (diveId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            PhotoViewerPage(diveId: diveId, initialMediaId: item.id),
      ),
    );
  }

  String _formatRuntime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth =
            constraints.maxWidth - widget.insets.left - widget.insets.right;
        final plotHeight =
            constraints.maxHeight - widget.insets.top - widget.insets.bottom;
        if (plotWidth <= 0 || plotHeight <= 0) {
          return const SizedBox.shrink();
        }

        final clusters = clusterPhotoMarkers(
          points: [
            for (final m in widget.markers)
              (
                seconds: m.elapsedSeconds.toDouble(),
                depthDisplay: widget.units.convertDepth(m.depthMeters),
              ),
          ],
          visibleMinSeconds: widget.visibleMinSeconds,
          visibleMaxSeconds: widget.visibleMaxSeconds,
          visibleMinDepth: widget.visibleMinDepth,
          visibleMaxDepth: widget.visibleMaxDepth,
          plotWidth: plotWidth,
          plotHeight: plotHeight,
        );
        if (clusters.isEmpty) return const SizedBox.shrink();

        PhotoMarkerCluster? selected;
        if (_selectedIndex != null) {
          for (final c in clusters) {
            if (c.memberIndexes.contains(_selectedIndex)) {
              selected = c;
              break;
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Tap-away dismisses the preview card.
            if (selected != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _selectedIndex = null),
                ),
              ),
            for (final cluster in clusters)
              Positioned(
                left: widget.insets.left + cluster.x - _tapTarget / 2,
                top: widget.insets.top + cluster.y - _tapTarget / 2,
                width: _tapTarget,
                height: _tapTarget,
                child: _buildChip(context, cluster),
              ),
            if (selected != null)
              _buildPreviewCard(context, selected, plotWidth, plotHeight),
          ],
        );
      },
    );
  }

  Widget _buildChip(BuildContext context, PhotoMarkerCluster cluster) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = cluster.memberIndexes.length;

    return Semantics(
      button: true,
      label: context.l10n.diveLog_profile_semantics_photoMarker,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            setState(() => _selectedIndex = cluster.memberIndexes.first),
        child: Center(
          child: Container(
            width: _chipSize,
            height: _chipSize,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 12,
                  color: colorScheme.onPrimaryContainer,
                ),
                if (count > 1)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    PhotoMarkerCluster cluster,
    double plotWidth,
    double plotHeight,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final members = [
      for (final i in cluster.memberIndexes) widget.markers[i],
    ];
    final cardWidth = members.length == 1
        ? _thumbSize + 16
        : (members.length * (_thumbSize + 4) + 12)
              .clamp(0.0, plotWidth)
              .toDouble();

    final chipX = widget.insets.left + cluster.x;
    final chipY = widget.insets.top + cluster.y;
    final minLeft = widget.insets.left;
    // num.clamp returns num; Positioned wants double.
    final maxLeft = (widget.insets.left + plotWidth - cardWidth)
        .clamp(minLeft, double.infinity)
        .toDouble();
    final left = (chipX - cardWidth / 2).clamp(minLeft, maxLeft).toDouble();
    final fitsAbove = chipY - _cardHeight - 8 >= widget.insets.top;
    final top = fitsAbove
        ? chipY - _cardHeight - 8
        : chipY + _tapTarget / 2 + 4;

    return Positioned(
      key: const ValueKey('photoMarkerCard'),
      left: left,
      top: top,
      width: cardWidth,
      height: _cardHeight,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: members.length == 1
              ? _buildThumb(context, members.single)
              : ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final m in members)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: _thumbSize,
                          child: _buildThumb(context, m),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildThumb(BuildContext context, PhotoChartMarker marker) {
    final caption =
        '${widget.units.formatDepth(marker.depthMeters, decimals: 0)}'
        ' · ${_formatRuntime(marker.elapsedSeconds)}';
    return GestureDetector(
      key: ValueKey('photoMarkerCardThumb-${marker.item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPhoto(marker.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: MediaItemView(
                item: marker.item,
                thumbnail: true,
                targetSize: const Size(200, 200),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

Notes for the implementer:
- If `UnitFormatter.formatDepth` has no `decimals` parameter in this codebase version, check its signature in `lib/core/utils/unit_formatter.dart` — `mini_dive_profile_overlay.dart:105` calls `formatter.formatDepth(photoDepthMeters, decimals: 0)`, so it exists.
- If `MediaItemView`'s constructor differs (check `lib/features/media/presentation/widgets/media_item_view.dart`), match the call in `dive_media_section.dart:515-520`.
- If `colorScheme.surfaceContainerHigh` is unavailable on the project's Flutter version, use `colorScheme.surfaceContainerHighest`.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/photo_marker_overlay_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dive_log): add PhotoMarkerOverlay with clustering and preview card"
```

---

### Task 5: Chart and legend integration

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (params ~line 205, legend sync ~line 1160, legendConfig ~line 1216, Stack children ~line 2629)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` (config field ~line 23/52, `hasSecondaryToggles` ~line 82, badge count ~line 294, markers popover section ~line 518)
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale ARBs (legend label)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`, `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`

**Interfaces:**
- Consumes: `PhotoChartMarker` (Task 3), `PhotoMarkerOverlay` (Task 4), `ProfileLegendState.showPhotoMarkers` / `togglePhotoMarkers()` (Task 2).
- Produces: `DiveProfileChart.photoMarkers` (`List<PhotoChartMarker>?`, optional, default null) and `ProfileLegendConfig.hasPhotoMarkers` (bool, default false). Task 7 depends on `photoMarkers`.

- [ ] **Step 1: Write the failing chart test**

In `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`:

(a) Add imports:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
```

(b) Add a `List<PhotoChartMarker>? photoMarkers` parameter to the `_buildChart` helper (~line 83) and pass it through to the `DiveProfileChart` constructor inside (~line 134): `photoMarkers: photoMarkers,`

(c) Add a marker factory and tests at the end of `main()`:

```dart
PhotoChartMarker _photoMarker({String id = 'p1', int seconds = 120}) {
  final now = DateTime.utc(2026, 1, 1);
  return PhotoChartMarker(
    item: MediaItem(
      id: id,
      diveId: 'dive-1',
      mediaType: MediaType.photo,
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    elapsedSeconds: seconds,
    depthMeters: 10.0,
  );
}
```

```dart
  group('photo markers', () {
    testWidgets('renders the overlay when photo markers are provided',
        (tester) async {
      await tester.pumpWidget(
        _buildChart(photoMarkers: [_photoMarker()]),
      );
      await tester.pump();
      expect(find.byType(PhotoMarkerOverlay), findsOneWidget);
    });

    testWidgets('renders no overlay without photo markers', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pump();
      expect(find.byType(PhotoMarkerOverlay), findsNothing);
    });

    testWidgets('hides the overlay when the legend toggle is off',
        (tester) async {
      await tester.pumpWidget(
        _buildChart(photoMarkers: [_photoMarker()]),
      );
      await tester.pump();
      final element = tester.element(find.byType(DiveProfileChart));
      final container = ProviderScope.containerOf(element);
      container.read(profileLegendProvider.notifier).togglePhotoMarkers();
      await tester.pump();
      expect(find.byType(PhotoMarkerOverlay), findsNothing);
    });
  });
```

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`
Expected: FAIL to compile (`photoMarkers` is not a `DiveProfileChart` parameter).

- [ ] **Step 2: Add the chart parameter, legend sync, config flag, and overlay**

In `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`:

(a) Imports:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
```

(b) Widget field, near the `markers` field (~line 89), plus the matching `this.photoMarkers,` entry in the constructor (~line 321):

```dart
  /// Photos positioned on the profile via their import-time enrichment.
  /// Rendered as a tappable overlay when the legend toggle is on.
  final List<PhotoChartMarker>? photoMarkers;
```

(c) State field near the other `_show*` fields and sync line in the legend-sync block (after `_showGasSwitchMarkers = legendState.showGasSwitchMarkers;`, ~line 1160):

```dart
  bool _showPhotoMarkers = true;
...
    _showPhotoMarkers = legendState.showPhotoMarkers;
```

(d) `legendConfig` entry (~line 1216, after `hasGasSwitches:`):

```dart
      hasPhotoMarkers:
          widget.photoMarkers != null && widget.photoMarkers!.isNotEmpty,
```

(e) In `_buildChart`, add the overlay as the LAST Stack child (after the `if (_hasGasStrip) ..._buildGasStripCursorExtensions(...)` entry, ~line 2629), so the preview card draws above the gas strip:

```dart
        // Photo markers: tappable camera chips at each photo's (time, depth).
        // A widget layer (not an fl_chart element) so its taps never enter
        // the chart's gesture arena; insets mirror the plot-rect math used
        // by the gas strip above.
        if (_showPhotoMarkers &&
            widget.photoMarkers != null &&
            widget.photoMarkers!.isNotEmpty)
          Positioned.fill(
            child: PhotoMarkerOverlay(
              markers: widget.photoMarkers!,
              visibleMinSeconds: visibleMinX,
              visibleMaxSeconds: visibleMaxX,
              visibleMinDepth: visibleMinDepth,
              visibleMaxDepth: visibleMaxDepth,
              insets: _plotInsets(availableWidth, units),
              units: units,
            ),
          ),
```

- [ ] **Step 3: Run the chart tests to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`
Expected: PASS (all tests, including the 3 new ones).

- [ ] **Step 4: Add the legend l10n label**

In `lib/l10n/arb/app_en.arb`, alphabetically within the `diveLog_legend_label_*` group (~line 2117):

```json
  "diveLog_legend_label_photoMarkers": "Photos",
```

Locale values (same position in each file):

| File | Value |
| --- | --- |
| `app_ar.arb` | `"الصور"` |
| `app_de.arb` | `"Fotos"` |
| `app_es.arb` | `"Fotos"` |
| `app_fr.arb` | `"Photos"` |
| `app_he.arb` | `"תמונות"` |
| `app_hu.arb` | `"Fotók"` |
| `app_it.arb` | `"Foto"` |
| `app_nl.arb` | `"Foto's"` |
| `app_pt.arb` | `"Fotos"` |
| `app_zh.arb` | `"照片"` |

Run: `flutter gen-l10n`

- [ ] **Step 5: Write the failing legend test**

In `test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`, mirror how the existing gas-switch popover test works (open the file, find the test that sets `hasGasSwitches: true` and opens the "More" popover; copy its structure). Add:

```dart
    testWidgets('shows the Photos toggle in the More popover when available',
        (tester) async {
      await tester.pumpWidget(
        _buildLegend(config: const ProfileLegendConfig(hasPhotoMarkers: true)),
      );
      await _openMorePopover(tester);
      expect(find.text('Photos'), findsOneWidget);
    });

    testWidgets('hides the Photos toggle when the dive has no photos',
        (tester) async {
      await tester.pumpWidget(
        _buildLegend(config: const ProfileLegendConfig()),
      );
      expect(find.text('Photos'), findsNothing);
    });
```

Use the file's existing helper names for `_buildLegend`/popover-opening; if the file's helpers are named differently, adapt these two tests to the file's existing conventions (the assertions stay the same).

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: FAIL to compile (`hasPhotoMarkers` undefined).

- [ ] **Step 6: Add the legend config flag and popover row**

In `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`:

(a) Config field after `hasGasSwitches` (~line 23) and constructor default (~line 52):

```dart
  final bool hasPhotoMarkers;
...
    this.hasPhotoMarkers = false,
```

(b) `hasSecondaryToggles` getter (~line 82): add `hasPhotoMarkers ||` after `hasGasSwitches ||`.

(c) Popover badge count (~line 294), after the gas-switches line:

```dart
    if (config.hasPhotoMarkers && legendState.showPhotoMarkers) count++;
```

(d) Markers section of the popover, after the `config.hasGasSwitches` block (~line 518-526):

```dart
      if (config.hasPhotoMarkers)
        _buildToggleItem(
          context,
          label: context.l10n.diveLog_legend_label_photoMarkers,
          color: Colors.cyan,
          isEnabled: legendState.showPhotoMarkers,
          onTap: legendNotifier.togglePhotoMarkers,
        ),
```

- [ ] **Step 7: Run the legend tests to verify pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dive_log): render photo markers on the dive profile chart with legend toggle"
```

---

### Task 6: Settings page toggle

**Files:**
- Modify: `lib/features/settings/presentation/pages/default_visible_metrics_page.dart` (~line 55)
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart` (`_countEnabledMetrics`, ~line 607)
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale ARBs
- Test: `test/features/settings/presentation/pages/default_visible_metrics_page_test.dart`

**Interfaces:**
- Consumes: `AppSettings.defaultShowPhotoMarkers`, `SettingsNotifier.setDefaultShowPhotoMarkers` (Task 1).
- Produces: user-facing Settings row; nothing downstream.

- [ ] **Step 1: Add the settings l10n label**

In `lib/l10n/arb/app_en.arb`, alphabetically within the `settings_appearance_metric_*` group (~line 5677):

```json
  "settings_appearance_metric_photoMarkers": "Photo Markers",
```

Locale values:

| File | Value |
| --- | --- |
| `app_ar.arb` | `"علامات الصور"` |
| `app_de.arb` | `"Fotomarkierungen"` |
| `app_es.arb` | `"Marcadores de fotos"` |
| `app_fr.arb` | `"Marqueurs de photos"` |
| `app_he.arb` | `"סמני תמונות"` |
| `app_hu.arb` | `"Fotójelölők"` |
| `app_it.arb` | `"Indicatori foto"` |
| `app_nl.arb` | `"Fotomarkeringen"` |
| `app_pt.arb` | `"Marcadores de fotos"` |
| `app_zh.arb` | `"照片标记"` |

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing page test**

In `test/features/settings/presentation/pages/default_visible_metrics_page_test.dart`: first add the setter override to the file's local mock notifier (lines 12-26), matching its existing style:

```dart
  @override
  Future<void> setDefaultShowPhotoMarkers(bool value) async =>
      state = state.copyWith(defaultShowPhotoMarkers: value);
```

Then add a test mirroring the file's existing toggle tests (copy the structure of its `defaultShowEvents` test):

```dart
    testWidgets('toggles Photo Markers default', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(SwitchListTile, 'Photo Markers');
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    });
```

(Adapt the pump helper name to the file's existing convention; assertions stay the same.)

Run: `flutter test test/features/settings/presentation/pages/default_visible_metrics_page_test.dart`
Expected: FAIL (no such SwitchListTile).

- [ ] **Step 3: Add the settings row and counter entry**

In `lib/features/settings/presentation/pages/default_visible_metrics_page.dart`, after the events row (~line 55):

```dart
          SwitchListTile(
            title: Text(context.l10n.settings_appearance_metric_photoMarkers),
            value: settings.defaultShowPhotoMarkers,
            onChanged: notifier.setDefaultShowPhotoMarkers,
          ),
```

In `lib/features/settings/presentation/pages/section_appearance_page.dart`, add to the `values` list in `_countEnabledMetrics` (~line 611, after `settings.defaultShowEvents,`):

```dart
      settings.defaultShowPhotoMarkers,
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/settings/presentation/pages/default_visible_metrics_page_test.dart`
Expected: PASS.

Also run (the counter change touches this page): `flutter test test/features/settings/presentation/pages/settings_page_test.dart`
Expected: PASS. If a metric-count assertion fails (e.g. an expected "N of M enabled" string), update the expected count to include the new default-true metric.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(settings): add Photo Markers to default visible metrics"
```

---

### Task 7: Wire photo markers into the dive detail page (main + fullscreen charts)

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (main chart ~line 1290, fullscreen chart ~line 4960)

**Interfaces:**
- Consumes: `mediaForDiveProvider` (`lib/features/media/presentation/providers/media_providers.dart`), `photoMarkersFromMedia` (Task 3), `DiveProfileChart.photoMarkers` (Task 5).
- Produces: end-user feature complete on the dive detail page.

Scope note: the dive-list side panel (`dive_profile_panel.dart`) intentionally does NOT get markers — the spec limits this feature to the dive detail profile chart and its fullscreen variant.

- [ ] **Step 1: Add the import**

In `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (check which are already imported first — `mediaForDiveProvider` is already referenced at ~line 4274, so its import exists):

```dart
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
```

- [ ] **Step 2: Build the marker list at the main chart site**

In the build scope containing the `DiveProfileChart(` construction at ~line 1290 (the same scope that computes `markers` and watches `showMaxDepthMarkerProvider` — grep for `final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);` nearest above line 1290), add:

```dart
    final photoMedia =
        ref.watch(mediaForDiveProvider(dive.id)).valueOrNull ?? const [];
    final photoMarkers = dive.profile.isEmpty
        ? const <PhotoChartMarker>[]
        : photoMarkersFromMedia(
            photoMedia,
            maxProfileSeconds: dive.profile.last.timestamp,
          );
```

Then in the `DiveProfileChart(` constructor call at ~line 1290, after `markers: markers,`:

```dart
                        photoMarkers: photoMarkers.isEmpty ? null : photoMarkers,
```

- [ ] **Step 3: Same for the fullscreen chart**

In the fullscreen profile widget's `build` (the scope at ~line 4900 that watches `showMaxDepthMarkerProvider`), add the same two-statement block (this widget also has `dive` in scope via `widget.dive`; use the local `final dive = widget.dive;` already present at ~line 4901), and pass `photoMarkers: photoMarkers.isEmpty ? null : photoMarkers,` to the `DiveProfileChart(` at ~line 4960.

- [ ] **Step 4: Analyze and spot-check**

Run: `flutter analyze`
Expected: No issues found (whole project — never pipe through tail/head).

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dive_log): wire photo markers into dive detail profile charts (#162)"
```

---

### Task 8: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Formatting and static analysis**

```bash
dart format .
git status --short   # must be clean except intended files
flutter analyze
```

Expected: format changes nothing, analyze reports no issues. If analyze flags a `SettingsNotifier` mock missing the new setter in any test file not touched yet (see `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`, `test/features/statistics/presentation/pages/records_page_test.dart`), add the same two-line override used in Task 1 Step 7 there.

- [ ] **Step 2: Run the full affected test set (specific files, not directories)**

```bash
flutter test \
  test/core/database/migration_v96_photo_markers_test.dart \
  test/core/services/sync/sync_diver_settings_fallback_test.dart \
  test/features/settings/presentation/providers/settings_notifier_real_test.dart \
  test/features/settings/presentation/pages/default_visible_metrics_page_test.dart \
  test/features/settings/presentation/pages/settings_page_test.dart \
  test/features/dive_log/presentation/providers/profile_legend_provider_test.dart \
  test/features/dive_log/presentation/widgets/photo_marker_layout_test.dart \
  test/features/dive_log/presentation/widgets/photo_marker_overlay_test.dart \
  test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart \
  test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart \
  test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart
```

Expected: all PASS.

- [ ] **Step 3: Live verification on macOS**

Run the app (`flutter run -d macos`) and verify by hand (or via the `verify` skill):
1. Open a dive that has photos with enrichment — camera chips appear on the profile at plausible times/depths.
2. Tap a chip — preview card with thumbnail + depth/runtime caption; tap the thumbnail — full photo viewer opens.
3. Pinch/scroll zoom in — clustered chips split; the open card dismisses on zoom.
4. Legend "More" popover — "Photos" toggle present only on dives with positioned photos; toggling hides/shows chips.
5. Settings > Appearance > default visible metrics — "Photo Markers" row present; turning it off makes new chart views start with markers hidden.
6. A dive with no photos — no chips, no "Photos" legend entry, chart identical to before.

- [ ] **Step 4: Final commit (if any stragglers) and status update**

```bash
git add -A
git commit -m "test: photo markers verification fixes"  # only if changes exist
git log --oneline main..HEAD
```

Expected: one commit per task, worktree clean.
