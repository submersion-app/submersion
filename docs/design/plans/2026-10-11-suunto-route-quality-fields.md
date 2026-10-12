# Suunto Route Quality Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep a Suunto export's `DiveRouteQuality` and `QualityFeatures` as-is with the imported route (issue #3047).

**Architecture:** One nullable `nav_tracks.source_metadata` TEXT column (schema v282) holds a JSON object of source-specific fields under the export's own key names. `SuuntoDiveRouteParser` collects the two fields, `SuuntoRouteWriter` hands them to `NavTrackRepository.insertImportedRoute`, and a small codec turns the map into the column value and back. Sync needs no code: the column rides the existing Drift JSON, and both apply paths already keep a column an older peer omits.

**Tech Stack:** Flutter, Dart, Drift (SQLite), flutter_test.

**Spec:** `docs/design/specs/2026-10-11-suunto-route-quality-fields-design.md`

## Global Constraints

- No UI for the fields. The only new l10n string is the sync-conflict
  dialog's label for the new column (added after the final review: the
  conflict catalogue requires one for every synced column).
- Values are stored exactly as parsed: no rounding, no int/double coercion.
- Nothing about these fields may fail an import or a route read.
- No backfill of existing routes; Skip and Replace source behave as today.
- Schema goes 281 to 282; `minimumCompatibleSchemaVersion` stays 280.
- `nav_track_repository.dart` is over the 800-line limit: add only the parameter, the companion value and the mapping line there.
- No em dashes anywhere (code, comments, docs, commit messages). No mention of AI tools in commits.
- Paths in tests via `p.join` if any are built (none expected here).
- Codegen is needed after the table change. Run it through
  `<scratchpad>/codegen.sh` (it runs `dart run build_runner build --delete-conflicting-outputs`);
  a bare `build` word in a Bash command is refused in this environment.

## Review Focus

1. A non-finite number in either field (NaN or Infinity from a sample map not born of JSON): `jsonEncode` would throw, so the parser must drop that field and the route must still import. Pinned in Task 4.
2. The fields present but the route rejected (fewer than two points): nothing stored, no throw. Pinned in Task 4.
3. A peer on an older build sends the route without `sourceMetadata`: the local value must survive. Pinned in Task 6.
4. A stored value that is valid JSON but not an object (`[1,2]`, `"x"`, `3`): reads as null, the route still loads. Pinned in Task 2.
5. `QualityFeatures` mixes an integer (`16`) with floats: the integer must stay an `int`, not become `16.0`. Pinned in Task 4.

---

### Task 1: Schema v282, the `source_metadata` column

**Files:**
- Modify: `lib/core/database/tables/track_tables.dart` (NavTracks, before `points`)
- Modify: `lib/core/database/migrations/helpers/track_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (end of the ladder)
- Modify: `lib/core/database/database.dart:265` (`currentSchemaVersion`) and the `migrationVersions` list (ends at `281,`)
- Test: `test/core/database/migration_v282_nav_track_source_metadata_test.dart` (create)

**Interfaces:**
- Produces: `NavTrackRow.sourceMetadata` (`String?`), `NavTracksCompanion.sourceMetadata` (`Value<String?>`), JSON key `sourceMetadata` in `NavTrackRow.toJson`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v282: nav_tracks.source_metadata (issue #3047), a source's undocumented
/// fields kept as-is. Column only, no backfill: existing routes read null.
/// The sync floor does not move: an older peer omits the column, and both
/// apply paths keep a column a payload omits.
void main() {
  Future<Set<String>> columns(AppDatabase db) async {
    final rows = await db.customSelect("PRAGMA table_info('nav_tracks')").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// A file stranded at [userVersion] whose nav_tracks lacks the column and
  /// holds one route.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY, diver_id TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE nav_tracks (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT, start_time INTEGER)',
      );
      rawDb.execute("INSERT INTO nav_tracks (id) VALUES ('r1')");
    },
  );

  Future<String?> metadataOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect("SELECT source_metadata FROM nav_tracks WHERE id = '$id'")
        .getSingle();
    return row.read<String?>('source_metadata');
  }

  test('v282 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(282));
    expect(AppDatabase.migrationVersions, contains(282));
    expect(
      AppDatabase.migrationStepCount(281),
      AppDatabase.migrationStepCount(282) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(282));
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columns(db), contains('source_metadata'));
  });

  test('upgrading from v281 adds the column; existing routes read null',
      () async {
    final db = AppDatabase(strandedAt(281));
    addTearDown(db.close);
    expect(await columns(db), contains('source_metadata'));
    expect(await metadataOf(db, 'r1'), isNull);
  });

  test('a database already at v282 without the column regains it', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columns(db), contains('source_metadata'));
    expect(await metadataOf(db, 'r1'), isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v282_nav_track_source_metadata_test.dart`
Expected: FAIL (`migrationVersions` lacks 282; no `source_metadata` column).

- [ ] **Step 3: Add the column to the table**

In `track_tables.dart`, inside `NavTracks`, directly above the `/// Gzipped JSON array of` doc comment of `points`:

```dart
  /// Source-specific fields kept exactly as the export carried them, as a
  /// JSON object under the export's own names (v282, issue #3047): a
  /// Suunto route's `DiveRouteQuality` and `QualityFeatures`, whose meaning
  /// is undocumented. Null when the source carried none. Nothing reads it
  /// yet; the codec is nav_track_source_metadata_codec.dart.
  TextColumn get sourceMetadata => text().nullable()();

```

- [ ] **Step 4: Add the migration helper**

In `track_migrations.dart`, inside `_assertNavTracksSchema()`, after `await _assertNavTrackDiverIdColumn();` add:

```dart
    await _assertNavTrackSourceMetadataColumn();
```

and after the `_assertNavTrackDiverIdColumn` method add:

```dart
  /// v282: nav_tracks.source_metadata (issue #3047). Idempotent; called
  /// from the v282 onUpgrade step and from [_assertNavTracksSchema], which
  /// the beforeOpen backstop runs on every open.
  Future<void> _assertNavTrackSourceMetadataColumn() async {
    if (!await _tableExists('nav_tracks')) return;
    await _addColumnIfMissing('nav_tracks', 'source_metadata', 'TEXT');
  }
```

- [ ] **Step 5: Add the rung**

At the end of the ladder in `rungs_v231_onward.dart`, after the `if (from < 281) await reportProgress();` line:

```dart
    // v282: nav_tracks.source_metadata (issue #3047). Column only, no
    // backfill; re-asserted in beforeOpen through _assertNavTracksSchema.
    if (from < 282) {
      await _assertNavTrackSourceMetadataColumn();
    }
    if (from < 282) await reportProgress();
```

- [ ] **Step 6: Bump the version**

In `database.dart`: `static const int currentSchemaVersion = 282;`, and append to `migrationVersions` after `281,`:

```dart
    // v282: nav_tracks.source_metadata (issue #3047). Additive nullable
    // column, so the floor stays at 280.
    282,
```

- [ ] **Step 7: Regenerate code**

Run: `<scratchpad>/codegen.sh > <scratchpad>/codegen.log 2>&1; tail -3 <scratchpad>/codegen.log`
Expected: build_runner reports success; `NavTrackRow` gains `sourceMetadata`.

- [ ] **Step 8: Run the tests**

Run: `flutter test test/core/database/migration_v282_nav_track_source_metadata_test.dart test/core/database/migration_v281_trend_gap_collapse_test.dart test/core/database/migration_v252_nav_track_diver_test.dart test/core/database/migration_v230_nav_tracks_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/core/database/tables/track_tables.dart lib/core/database/migrations/helpers/track_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/database.dart test/core/database/migration_v282_nav_track_source_metadata_test.dart
git commit -m "feat(nav-track): add nav_tracks.source_metadata (schema v282)"
```

(Generated `*.g.dart` files are gitignored; check `git status` and stage any tracked generated file that changed.)

---

### Task 2: Source metadata codec and the entity field

**Files:**
- Create: `lib/features/nav_track/domain/nav_track_source_metadata_codec.dart`
- Modify: `lib/features/nav_track/domain/entities/nav_track.dart` (field, constructor, `copyWith`, `props`)
- Test: `test/features/nav_track/domain/nav_track_source_metadata_codec_test.dart` (create)
- Test: `test/features/nav_track/domain/entities/nav_track_test.dart`

**Interfaces:**
- Produces: `String? encodeNavTrackSourceMetadata(Map<String, Object?>? metadata)`, `Map<String, Object?>? decodeNavTrackSourceMetadata(String? json)`, `NavTrack.sourceMetadata` (`Map<String, Object?>?`), `NavTrack.copyWith({Map<String, Object?>? sourceMetadata})`.

- [ ] **Step 1: Write the failing codec test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/domain/nav_track_source_metadata_codec.dart';

void main() {
  const metadata = {
    'DiveRouteQuality': 0,
    'QualityFeatures': [16, 0.10000000149011612, 3505.73388671875],
  };

  test('round-trips a map exactly', () {
    final decoded = decodeNavTrackSourceMetadata(
      encodeNavTrackSourceMetadata(metadata),
    );
    expect(decoded, metadata);
    expect((decoded!['QualityFeatures']! as List).first, isA<int>());
  });

  test('null and an empty map encode to null', () {
    expect(encodeNavTrackSourceMetadata(null), isNull);
    expect(encodeNavTrackSourceMetadata(const {}), isNull);
  });

  test('null decodes to null', () {
    expect(decodeNavTrackSourceMetadata(null), isNull);
  });

  test('a stored value that is not a JSON object decodes to null', () {
    for (final stored in ['not json', '[1,2]', '"x"', '3', 'null', '']) {
      expect(decodeNavTrackSourceMetadata(stored), isNull, reason: stored);
    }
  });

  test('the decoded map and its lists are unmodifiable', () {
    final decoded = decodeNavTrackSourceMetadata(
      encodeNavTrackSourceMetadata(metadata),
    )!;
    expect(() => decoded['x'] = 1, throwsUnsupportedError);
    expect(
      () => (decoded['QualityFeatures']! as List).add(1),
      throwsUnsupportedError,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/nav_track/domain/nav_track_source_metadata_codec_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Write the codec**

```dart
import 'dart:convert';

// `nav_tracks.source_metadata` (issue #3047): a JSON object of fields a
// route's source exported about the recording, kept exactly as the export
// carried them under its own key names. Nothing interprets them yet.

/// The column value for [metadata]: null when there is nothing to keep.
String? encodeNavTrackSourceMetadata(Map<String, Object?>? metadata) {
  if (metadata == null || metadata.isEmpty) return null;
  return jsonEncode(metadata);
}

/// The stored [json] as an unmodifiable map, or null when the column is
/// empty or holds anything but a JSON object. Never throws: a value this
/// cannot read must not stop the route from loading.
Map<String, Object?>? decodeNavTrackSourceMetadata(String? json) {
  if (json == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  return _freeze(decoded) as Map<String, Object?>;
}

Object? _freeze(Object? value) => switch (value) {
  Map<String, dynamic>() => Map<String, Object?>.unmodifiable({
    for (final entry in value.entries) entry.key: _freeze(entry.value),
  }),
  List<dynamic>() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};
```

- [ ] **Step 4: Run the codec test**

Run: `flutter test test/features/nav_track/domain/nav_track_source_metadata_codec_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing entity test**

Append inside `main()` of `nav_track_test.dart`:

```dart
  group('sourceMetadata (#3047)', () {
    const metadata = {'DiveRouteQuality': 1};

    test('copyWith keeps it unless replaced', () {
      final track = _track().copyWith(sourceMetadata: metadata);
      expect(track.copyWith(name: 'x').sourceMetadata, metadata);
      expect(
        track.copyWith(sourceMetadata: const {'DiveRouteQuality': 0})
            .sourceMetadata,
        {'DiveRouteQuality': 0},
      );
    });

    test('takes part in equality', () {
      expect(
        _track().copyWith(sourceMetadata: metadata),
        isNot(_track()),
      );
      expect(
        _track().copyWith(sourceMetadata: metadata),
        _track().copyWith(sourceMetadata: const {'DiveRouteQuality': 1}),
      );
    });
  });
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/nav_track/domain/entities/nav_track_test.dart`
Expected: FAIL (no `sourceMetadata` parameter).

- [ ] **Step 7: Add the field**

In `nav_track.dart`, after the `headingOffsetDeg` field:

```dart
  /// Fields the source exported about the recording that nothing reads
  /// yet, kept as-is under the export's own names (`nav_tracks.
  /// source_metadata`, issue #3047): a Suunto route's `DiveRouteQuality`
  /// and `QualityFeatures`. Null when the source carried none.
  final Map<String, Object?>? sourceMetadata;
```

Constructor, after `this.headingOffsetDeg = 0,`: `this.sourceMetadata,`
`copyWith` parameter after `double? headingOffsetDeg,`: `Map<String, Object?>? sourceMetadata,`
`copyWith` body after the `headingOffsetDeg:` line: `sourceMetadata: sourceMetadata ?? this.sourceMetadata,`
`props` after `headingOffsetDeg,`: `sourceMetadata,`

- [ ] **Step 8: Run both tests**

Run: `flutter test test/features/nav_track/domain/entities/nav_track_test.dart test/features/nav_track/domain/nav_track_source_metadata_codec_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/nav_track/domain/nav_track_source_metadata_codec.dart lib/features/nav_track/domain/entities/nav_track.dart test/features/nav_track/domain/nav_track_source_metadata_codec_test.dart test/features/nav_track/domain/entities/nav_track_test.dart
git commit -m "feat(nav-track): add the route source metadata codec and entity field"
```

---

### Task 3: Repository stores and reads the metadata

**Files:**
- Modify: `lib/features/nav_track/data/repositories/nav_track_repository.dart` (`insertImportedRoute` parameters and companion, `_toDomain`, imports)
- Test: `test/features/nav_track/data/repositories/nav_track_repository_test.dart` (group `insertImportedRoute`)

**Interfaces:**
- Consumes: `encodeNavTrackSourceMetadata`, `decodeNavTrackSourceMetadata`, `NavTrack.sourceMetadata` (Task 2); `NavTracksCompanion.sourceMetadata` (Task 1).
- Produces: `insertImportedRoute({..., Map<String, Object?>? sourceMetadata})`.

- [ ] **Step 1: Write the failing tests**

Inside `group('insertImportedRoute', () {`:

```dart
    test('keeps the source metadata as-is (#3047)', () async {
      const metadata = {
        'DiveRouteQuality': 0,
        'QualityFeatures': [16, 0.10000000149011612],
      };
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.suuntoRoute,
        sourceRef: 'suunto:NS-1:2026-10-09T10:00:00.000Z',
        sourceMetadata: metadata,
      );

      expect((await repo.getById(id))!.sourceMetadata, metadata);
    });

    test('stores no source metadata when the source carried none', () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
      );

      final row = await db
          .customSelect(
            "SELECT source_metadata FROM nav_tracks WHERE id = '$id'",
          )
          .getSingle();
      expect(row.read<String?>('source_metadata'), isNull);
      expect((await repo.getById(id))!.sourceMetadata, isNull);
    });

    test('reads unreadable stored metadata as none and still loads the route',
        () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.suuntoRoute,
        sourceRef: 'suunto:NS-1:x',
      );
      await db.customStatement(
        "UPDATE nav_tracks SET source_metadata = '[1,2]' WHERE id = '$id'",
      );

      final route = await repo.getById(id);
      expect(route, isNotNull);
      expect(route!.sourceMetadata, isNull);
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/nav_track/data/repositories/nav_track_repository_test.dart --plain-name 'insertImportedRoute'`
Expected: FAIL (no `sourceMetadata` parameter).

- [ ] **Step 3: Implement**

Import, with the other `nav_track/domain` imports:

```dart
import 'package:submersion/features/nav_track/domain/nav_track_source_metadata_codec.dart';
```

In `insertImportedRoute`'s parameter list, after `double? anchorLongitude,`:

```dart
    Map<String, Object?>? sourceMetadata,
```

Add one sentence to its doc comment, after the anchor paragraph:

```dart
  /// [sourceMetadata] is stored as-is (issue #3047).
```

In the `NavTracksCompanion.insert(` call, after `anchorLongitude: Value(anchor?.longitude),`:

```dart
              sourceMetadata: Value(
                encodeNavTrackSourceMetadata(sourceMetadata),
              ),
```

In `_toDomain`, after `headingOffsetDeg: row.headingOffsetDeg,`:

```dart
      sourceMetadata: decodeNavTrackSourceMetadata(row.sourceMetadata),
```

- [ ] **Step 4: Run the whole repository test**

Run: `flutter test test/features/nav_track/data/repositories/nav_track_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/nav_track/data/repositories/nav_track_repository.dart test/features/nav_track/data/repositories/nav_track_repository_test.dart
git commit -m "feat(nav-track): store an imported route's source metadata"
```

---

### Task 4: Parse the Suunto route quality fields

**Files:**
- Modify: `lib/core/services/suunto_cloud/suunto_dive_route.dart` (`SuuntoDiveRoute`, `SuuntoDiveRouteParser.parse`)
- Test: `test/core/services/suunto_cloud/suunto_dive_route_test.dart`
- Test: `test/core/services/suunto_cloud/suunto_sml_normalizer_test.dart` (cloud shape)

**Interfaces:**
- Produces: `SuuntoDiveRoute.sourceMetadata` (`Map<String, Object?>?`, unmodifiable), constructor parameter `sourceMetadata`.

- [ ] **Step 1: Write the failing parser tests**

Append inside `main()` of `suunto_dive_route_test.dart`:

```dart
  // #3047: an export with a route also carries DiveRouteQuality and a
  // QualityFeatures array, meaning undocumented, on its first sample beside
  // DiveRouteOrigin. Kept as-is for later analysis.
  group('route quality fields', () {
    // From a real Nautic S export (Dahab, 2026-10-09).
    const features = [
      16,
      0.10000000149011612,
      0.6539999842643738,
      3.99759840965271,
      1.1491650342941284,
      21.36615562438965,
      10.3184175491333,
      3505.73388671875,
      20.444210052490234,
      0.7803016304969788,
      30.586137771606445,
      0.18129804730415344,
    ];

    List<Map<String, dynamic>> withRoute(Map<String, dynamic> fields) => [
      {
        'TimeISO8601': '2026-04-19T10:00:00.000Z',
        'DiveRouteOrigin': {'Latitude': 28.43, 'Longitude': 34.45},
        ...fields,
      },
      _routeSample(1, 0, 0, -2),
      _routeSample(2, 1, 1, -3),
    ];

    test('keeps both fields verbatim', () {
      final route = _parse(
        withRoute({'DiveRouteQuality': 0, 'QualityFeatures': features}),
      )!;

      expect(route.sourceMetadata, {
        'DiveRouteQuality': 0,
        'QualityFeatures': features,
      });
      // Not coerced: the integer count stays an int.
      final kept = route.sourceMetadata!['QualityFeatures']! as List;
      expect(kept.first, isA<int>());
    });

    test('is null when the export carries neither field', () {
      expect(_parse(withRoute({}))!.sourceMetadata, isNull);
    });

    test('keeps a field that arrives alone', () {
      expect(_parse(withRoute({'DiveRouteQuality': 1}))!.sourceMetadata, {
        'DiveRouteQuality': 1,
      });
    });

    test('drops a malformed field and keeps the other', () {
      final cases = <Map<String, dynamic>, Map<String, Object?>>{
        {'DiveRouteQuality': '1', 'QualityFeatures': features}: {
          'QualityFeatures': features,
        },
        {'DiveRouteQuality': double.nan, 'QualityFeatures': features}: {
          'QualityFeatures': features,
        },
        {'DiveRouteQuality': 1, 'QualityFeatures': 'x'}: {
          'DiveRouteQuality': 1,
        },
        {'DiveRouteQuality': 1, 'QualityFeatures': [1, 'a']}: {
          'DiveRouteQuality': 1,
        },
        {'DiveRouteQuality': 1, 'QualityFeatures': [1, double.infinity]}: {
          'DiveRouteQuality': 1,
        },
      };
      cases.forEach((fields, expected) {
        expect(
          _parse(withRoute(fields))!.sourceMetadata,
          expected,
          reason: '$fields',
        );
      });
    });

    test('the first well-formed value of each field wins', () {
      final samples = withRoute({'DiveRouteQuality': 'bad'})
        ..add({
          'TimeISO8601': '2026-04-19T10:00:03.000Z',
          'DiveRouteQuality': 1,
        })
        ..add({
          'TimeISO8601': '2026-04-19T10:00:04.000Z',
          'DiveRouteQuality': 0,
        });
      expect(_parse(samples)!.sourceMetadata, {'DiveRouteQuality': 1});
    });

    test('is unmodifiable', () {
      final route = _parse(
        withRoute({'DiveRouteQuality': 0, 'QualityFeatures': features}),
      )!;
      expect(
        () => route.sourceMetadata!['x'] = 1,
        throwsUnsupportedError,
      );
      expect(
        () => (route.sourceMetadata!['QualityFeatures']! as List).add(1),
        throwsUnsupportedError,
      );
    });

    test('no route, nothing kept, nothing thrown', () {
      final samples = withRoute({
        'DiveRouteQuality': 1,
        'QualityFeatures': features,
      })..removeLast();
      expect(_parse(samples), isNull);
    });
  });
```

- [ ] **Step 2: Write the failing cloud-shape test**

Append inside `main()` of `suunto_sml_normalizer_test.dart`, after the `DiveRoute` pass-through test:

```dart
  // #3047: the route quality fields ride in the same cloud Sample.
  test('passes the route quality fields through from the cloud Sample', () {
    final export = SuuntoSmlNormalizer.parse({
      'Summary': {
        'Samples': [
          {
            'Attributes': {
              'suunto/sml': {
                'Header': {'ActivityType': 51},
              },
            },
          },
        ],
      },
      'Data': {
        'Samples': [
          {
            'TimeISO8601': '2026-04-19T10:00:00.000Z',
            'Attributes': {
              'suunto/sml': {
                'Sample': {
                  'DiveRouteQuality': 1,
                  'QualityFeatures': [16, 0.1],
                },
              },
            },
          },
        ],
      },
    });
    expect(export.samples.single['DiveRouteQuality'], 1);
    expect(export.samples.single['QualityFeatures'], [16, 0.1]);
  });
```

- [ ] **Step 3: Run them to verify the parser tests fail**

Run: `flutter test test/core/services/suunto_cloud/suunto_dive_route_test.dart test/core/services/suunto_cloud/suunto_sml_normalizer_test.dart`
Expected: the route tests FAIL to compile (`sourceMetadata` undefined). The normalizer test passes once the file compiles: it pins existing behaviour the feature relies on.

- [ ] **Step 4: Implement**

In `SuuntoDiveRoute`, add the constructor parameter `this.sourceMetadata,` after `this.originLongitude,`, and the field after `originLongitude`:

```dart
  /// The export's route quality fields under their own names (issue
  /// #3047): `DiveRouteQuality` and `QualityFeatures`. Their meaning is
  /// undocumented, so they are kept as-is for later analysis. Null when the
  /// export carried neither.
  final Map<String, Object?>? sourceMetadata;
```

In `SuuntoDiveRouteParser`, add above `parse`:

```dart
  static const _qualityKey = 'DiveRouteQuality';
  static const _featuresKey = 'QualityFeatures';
```

In `parse`'s returned `SuuntoDiveRoute(`, after `originLongitude: originLongitude,`:

```dart
      sourceMetadata: _sourceMetadata(samples),
```

And add the helper after `parse`:

```dart
  /// `DiveRouteQuality` (one number) and `QualityFeatures` (a list of
  /// numbers, 12 so far), which sit on the first sample beside
  /// `DiveRouteOrigin` (issue #3047). The first well-formed value of each
  /// wins and a malformed one is left out; a non-finite number counts as
  /// malformed, since JSON has no form to store it in.
  static Map<String, Object?>? _sourceMetadata(
    List<Map<String, dynamic>> samples,
  ) {
    num? quality;
    List<num>? features;
    for (final sample in samples) {
      if (quality == null) {
        final value = sample[_qualityKey];
        if (value is num && value.isFinite) quality = value;
      }
      if (features == null) {
        final value = sample[_featuresKey];
        if (value is List && value.every((v) => v is num && v.isFinite)) {
          features = List<num>.unmodifiable(value.cast<num>());
        }
      }
      if (quality != null && features != null) break;
    }
    if (quality == null && features == null) return null;
    return Map<String, Object?>.unmodifiable({
      if (quality != null) _qualityKey: quality,
      if (features != null) _featuresKey: features,
    });
  }
```

- [ ] **Step 5: Run the Suunto tests**

Run: `flutter test test/core/services/suunto_cloud/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/suunto_cloud/suunto_dive_route.dart test/core/services/suunto_cloud/suunto_dive_route_test.dart test/core/services/suunto_cloud/suunto_sml_normalizer_test.dart
git commit -m "feat(nav-track): read the Suunto route quality fields"
```

---

### Task 5: The route writer keeps them

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/suunto_route_writer.dart` (`attach`)
- Test: `test/features/import_wizard/data/adapters/suunto_route_writer_test.dart`

**Interfaces:**
- Consumes: `SuuntoDiveRoute.sourceMetadata` (Task 4), `insertImportedRoute(sourceMetadata:)` (Task 3).

- [ ] **Step 1: Write the failing tests**

Change the `_route` helper to accept metadata:

```dart
SuuntoDiveRoute _route({
  double? lat = 47.3,
  double? lon = -2.9,
  Map<String, Object?>? metadata,
}) => SuuntoDiveRoute(
  points: const [
    NavTrackPoint(timestamp: 1776606280, north: 0, east: 0, depth: 1),
    NavTrackPoint(timestamp: 1776606281, north: 1, east: 1, depth: 2),
  ],
  originLatitude: lat,
  originLongitude: lon,
  sourceMetadata: metadata,
);
```

Add after the re-import test:

```dart
  test('keeps the route quality fields on the stored route (#3047)', () async {
    await _insertDive(db, 'd1');
    const metadata = {
      'DiveRouteQuality': 1,
      'QualityFeatures': [16, 0.1],
    };
    await writer.attach('d1', _parsed(route: _route(metadata: metadata)));

    expect((await repo.getForDive('d1')).single.sourceMetadata, metadata);
  });

  test('a re-import carries the new export\'s quality fields', () async {
    await _insertDive(db, 'd1');
    await writer.attach(
      'd1',
      _parsed(route: _route(metadata: const {'DiveRouteQuality': 1})),
    );
    await writer.attach(
      'd1',
      _parsed(route: _route(metadata: const {'DiveRouteQuality': 0})),
    );

    expect((await repo.getForDive('d1')).single.sourceMetadata, {
      'DiveRouteQuality': 0,
    });
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/suunto_route_writer_test.dart`
Expected: the two new tests FAIL (`sourceMetadata` is null).

- [ ] **Step 3: Implement**

In `attach`, in the `insertImportedRoute(` call, after `anchorLongitude: route.originLongitude,`:

```dart
        sourceMetadata: route.sourceMetadata,
```

- [ ] **Step 4: Run the writer and import core tests**

Run: `flutter test test/features/import_wizard/data/adapters/suunto_route_writer_test.dart test/features/import_wizard/data/adapters/suunto_dive_import_core_route_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_wizard/data/adapters/suunto_route_writer.dart test/features/import_wizard/data/adapters/suunto_route_writer_test.dart
git commit -m "feat(import-wizard): keep the Suunto route quality fields on import"
```

---

### Task 6: Sync carries the column and keeps it from older peers

No production code is expected: these tests pin the behaviour the spec relies on. If one fails, stop and report it; it means the spec's sync section is wrong.

**Files:**
- Test: `test/core/services/sync/sync_nav_tracks_test.dart`

**Interfaces:**
- Consumes: `insertImportedRoute(sourceMetadata:)` (Task 3).

- [ ] **Step 1: Write the tests**

Add inside `main()`, after the `diverId` round-trip test:

```dart
  test('a route\'s source metadata (v282) travels with it', () async {
    const metadata = {
      'DiveRouteQuality': 0,
      'QualityFeatures': [16, 0.1],
    };
    final id = await repo.insertImportedRoute(
      points: samplePoints(),
      source: NavTrackSource.suuntoRoute,
      sourceRef: 'suunto:NS-1:x',
      sourceMetadata: metadata,
    );

    final fetched = (await serializer.fetchRecord('navTracks', id))!;
    expect(fetched['sourceMetadata'], isA<String>());

    await serializer.deleteRecord('navTracks', id);
    await serializer.upsertRecord('navTracks', fetched);

    expect((await repo.getById(id))!.sourceMetadata, metadata);
  });

  test('a row from a peer that predates source metadata keeps the local '
      'value', () async {
    const metadata = {'DiveRouteQuality': 0};
    final id = await repo.insertImportedRoute(
      points: samplePoints(),
      source: NavTrackSource.suuntoRoute,
      sourceRef: 'suunto:NS-1:x',
      sourceMetadata: metadata,
    );
    final fetched = (await serializer.fetchRecord('navTracks', id))!;
    // A v280-v281 peer omits the column it does not have.
    final fromOlderPeer = {...fetched, 'name': 'Renamed'}
      ..remove('sourceMetadata');

    await serializer.upsertRecord('navTracks', fromOlderPeer);

    final route = (await repo.getById(id))!;
    expect(route.name, 'Renamed');
    expect(route.sourceMetadata, metadata);
  });
```

- [ ] **Step 2: Run them**

Run: `flutter test test/core/services/sync/sync_nav_tracks_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/core/services/sync/sync_nav_tracks_test.dart
git commit -m "test(nav-track): pin source metadata through sync"
```

---

### Task 7: Final checks

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes left unformatted; "No issues found!"

- [ ] **Step 2: Architecture and adoption guards (a new file under lib/)**

Run: `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 3: Affected suites**

Run: `flutter test test/core/database/ test/core/services/suunto_cloud/ test/core/services/sync/ test/features/nav_track/ test/features/import_wizard/`
Expected: PASS.

- [ ] **Step 4: Commit any formatting change**

```bash
git status --porcelain
```

If `dart format` changed files, stage those exact paths and commit `style: format`.
