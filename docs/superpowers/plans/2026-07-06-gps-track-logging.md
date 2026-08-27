# GPS Track Logging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record a timestamped GPS track on the phone during a dive day and automatically stamp entry/exit positions onto imported dives by timestamp, feeding the existing site-matching flow.

**Architecture:** One synced Drift table (`gps_tracks`, blob-per-session) plus a local-only point buffer for crash safety. A `GpsTrackRecorder` wraps geolocator background streaming; a pure `GpsTrackMatcher` interpolates track position at dive start/end; a `GpsTrackMatchService` sweep stamps null GPS columns and is triggered at import time, on track arrival (stop or sync), and manually.

**Tech Stack:** Flutter, Drift ORM, Riverpod, geolocator ^14.0.2 (already a dependency), go_router.

**Spec:** `docs/superpowers/specs/2026-07-06-gps-track-logging-design.md` — read it before starting.

## Global Constraints

- Schema migration is version **101** (`currentSchemaVersion` is 100 on main). If another branch consumed 101 by execution time, use the next free version and keep the DDL idempotent (`CREATE TABLE IF NOT EXISTS`).
- Dive timestamps are **wall-clock-reinterpreted-as-UTC** epochs. Track points store wall-clock-as-UTC epoch **seconds**; track `startTime`/`endTime` store wall-clock-as-UTC epoch **milliseconds** (matching `dives.entryTime`).
- Matching **only fills null** `entryLatitude`/`entryLongitude`/`exitLatitude`/`exitLongitude` — never overwrites.
- No emojis in code, comments, or docs. `dart format .` (whole repo) must produce no changes before every commit.
- New user-facing strings go in `lib/l10n/arb/app_en.arb` AND all 10 other locales (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then regenerate with `flutter gen-l10n`.
- Anything displaying units respects the active diver's unit settings.
- Commit messages: plain, imperative, no Co-Authored-By lines.
- Run tests per-file (broad directories hit Bash timeouts).
- If executing in a fresh worktree: `git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs` first, or DB tests fail on missing `database.g.dart`.

## File Structure

```
lib/features/gps_log/
  domain/entities/gps_track.dart            # GpsTrack + GpsTrackPoint domain entities
  domain/track_point_codec.dart             # gzip JSON blob codec + wall-clock conversion
  domain/gps_track_matcher.dart             # pure position-at-time lookup
  data/repositories/gps_track_repository.dart  # CRUD, buffer, checkpoint/finalize, tombstones
  data/services/gps_track_match_service.dart   # sweep: stamp GPS-less dives from tracks
  data/services/gps_track_recorder.dart        # session lifecycle over geolocator stream
  presentation/providers/gps_log_providers.dart
  presentation/pages/gps_logger_page.dart

test/features/gps_log/
  track_point_codec_test.dart
  gps_track_matcher_test.dart
  gps_track_repository_test.dart
  gps_track_match_service_test.dart
  gps_track_recorder_test.dart
  gps_logger_page_test.dart
test/core/services/sync/sync_gps_tracks_test.dart
```

Modified: `database.dart` (tables + migration), `sync_data_serializer.dart` (7 touch points), `dive_repository_impl.dart` (2 methods), `reparse_service.dart` (GPS guard), `dive_import_service.dart` (import hook), `sync_providers.dart` (post-sync hook), `tools_page.dart` + `app_router.dart` (UI entry), `AndroidManifest.xml` + iOS `Info.plist` (permissions), arb files.

---

### Task 1: Schema — gps_tracks and gps_track_points_local tables

**Files:**
- Modify: `lib/core/database/database.dart` (table classes near `ChecklistTemplates` at :130; `@DriftDatabase` tables list at :1899; `currentSchemaVersion` :1982; `migrationVersions` :1987; `onUpgrade` migration tail after the `if (from < 100)` block)
- Test: `test/features/gps_log/gps_track_repository_test.dart` (schema smoke test only in this task)

**Interfaces:**
- Consumes: nothing new.
- Produces: Drift tables `GpsTracks` (data class `GpsTrackRow`, companion `GpsTracksCompanion`) and `GpsTrackPointsLocal` (data class `GpsTrackPointRow`). Columns as below. Later tasks use `_db.gpsTracks` / `_db.gpsTrackPointsLocal`.

- [ ] **Step 1: Add the two table classes** to `database.dart`, directly after the `TripChecklistItems` table class:

```dart
/// GPS surface tracks recorded by the phone during a dive day (spec
/// 2026-07-06-gps-track-logging). One row per recording session; points
/// live in a gzipped JSON blob because matching always reads whole tracks
/// and blob-per-session keeps sync to one HLC row per boat day.
@DataClassName('GpsTrackRow')
class GpsTracks extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();

  /// Wall-clock-as-UTC epoch milliseconds (same convention as dives.entryTime)
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer().nullable()();

  /// Device UTC offset at recording start, to reconstruct true UTC later
  IntColumn get tzOffsetMinutes => integer().withDefault(const Constant(0))();
  TextColumn get deviceName => text().nullable()();
  IntColumn get pointCount => integer().withDefault(const Constant(0))();

  /// Gzipped JSON array of [wallClockEpochSeconds, lat, lon, accuracyMeters]
  BlobColumn get points => blob().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// Local-only append buffer for the in-progress recording session. Never
/// synced (no hlc). Finalized into gps_tracks.points on stop or recovery.
@DataClassName('GpsTrackPointRow')
class GpsTrackPointsLocal extends Table {
  // coverage:ignore-start
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get trackId => text()();

  /// Wall-clock-as-UTC epoch seconds
  IntColumn get timestamp => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real().nullable()();
  // coverage:ignore-end
}
```

- [ ] **Step 2: Register the tables** in the `@DriftDatabase(tables: [...])` list, after `TripChecklistItems`:

```dart
    // GPS surface track logging (discussion #289)
    GpsTracks,
    GpsTrackPointsLocal,
```

- [ ] **Step 3: Bump schema version and add the migration.** Set `currentSchemaVersion = 101`, append `101` to `migrationVersions`, and add this block at the end of `onUpgrade` (after the `if (from < 100)` block, before the trailing `reportProgress` calls, matching the v98 checklist idiom):

```dart
        if (from < 101) {
          // GPS surface track logging (discussion #289). Idempotent DDL so
          // interrupted migrations and version-collision recovery are safe.
          await customStatement('''
            CREATE TABLE IF NOT EXISTS gps_tracks (
              id TEXT NOT NULL PRIMARY KEY,
              start_time INTEGER NOT NULL,
              end_time INTEGER,
              tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
              device_name TEXT,
              point_count INTEGER NOT NULL DEFAULT 0,
              points BLOB,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS gps_track_points_local (
              row_id INTEGER PRIMARY KEY AUTOINCREMENT,
              track_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy REAL
            )
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_gps_track_points_local_track_id
            ON gps_track_points_local(track_id)
          ''');
        }
        if (from < 101) await reportProgress();
```

- [ ] **Step 4: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes without errors; `database.g.dart` gains `GpsTrackRow`, `GpsTracksCompanion`, `GpsTrackPointRow`.

- [ ] **Step 5: Write a schema smoke test** at `test/features/gps_log/gps_track_repository_test.dart`. Look at an existing DB test (e.g. any test constructing the app database in-memory — `grep -rl "NativeDatabase.memory" test/ | head -3`) and copy its construction helper. Enable foreign keys in setup per project convention (`await db.customStatement('PRAGMA foreign_keys = ON')`).

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await db.close();
  });

  test('gps_tracks table accepts a row round-trip', () async {
    await db
        .into(db.gpsTracks)
        .insert(
          GpsTracksCompanion.insert(
            id: 'track-1',
            startTime: 1700000000000,
            createdAt: 1700000000000,
            updatedAt: 1700000000000,
          ),
        );
    final row = await (db.select(
      db.gpsTracks,
    )..where((t) => t.id.equals('track-1'))).getSingle();
    expect(row.endTime, isNull);
    expect(row.pointCount, 0);
  });

  test('gps_track_points_local accepts buffer rows', () async {
    await db
        .into(db.gpsTrackPointsLocal)
        .insert(
          GpsTrackPointsLocalCompanion.insert(
            trackId: 'track-1',
            timestamp: 1700000000,
            latitude: 20.5,
            longitude: -87.2,
          ),
        );
    final rows = await db.select(db.gpsTrackPointsLocal).get();
    expect(rows.single.latitude, 20.5);
  });
}
```

Note: if `AppDatabase.forTesting` does not exist, use whatever constructor the existing in-memory DB tests use — copy it exactly.

- [ ] **Step 6: Run the test**

Run: `flutter test test/features/gps_log/gps_track_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add gps_tracks and gps_track_points_local tables (schema v101)"
```

---

### Task 2: Domain entities, blob codec, wall-clock conversion (TDD)

**Files:**
- Create: `lib/features/gps_log/domain/entities/gps_track.dart`
- Create: `lib/features/gps_log/domain/track_point_codec.dart`
- Test: `test/features/gps_log/track_point_codec_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class GpsTrackPoint { final int timestamp; final double latitude; final double longitude; final double? accuracy; }` (timestamp = wall-clock-as-UTC epoch seconds)
  - `class GpsTrack { final String id; final int startTime; final int? endTime; final int tzOffsetMinutes; final String? deviceName; final int pointCount; final List<GpsTrackPoint> points; }` with `copyWith`
  - `Uint8List encodeTrackPoints(List<GpsTrackPoint> points)` / `List<GpsTrackPoint> decodeTrackPoints(Uint8List blob)`
  - `int toWallClockEpochSeconds(DateTime timestamp)` — converts a real-UTC `DateTime` to the app's wall-clock-as-UTC epoch seconds using the device's local timezone.

- [ ] **Step 1: Write the failing tests** at `test/features/gps_log/track_point_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

void main() {
  group('encode/decode round-trip', () {
    test('preserves points exactly', () {
      final points = [
        const GpsTrackPoint(
          timestamp: 1700000000,
          latitude: 20.123456,
          longitude: -87.654321,
          accuracy: 8.5,
        ),
        const GpsTrackPoint(
          timestamp: 1700000060,
          latitude: 20.123999,
          longitude: -87.654001,
          accuracy: null,
        ),
      ];
      final decoded = decodeTrackPoints(encodeTrackPoints(points));
      expect(decoded.length, 2);
      expect(decoded[0].timestamp, 1700000000);
      expect(decoded[0].latitude, closeTo(20.123456, 1e-9));
      expect(decoded[0].longitude, closeTo(-87.654321, 1e-9));
      expect(decoded[0].accuracy, closeTo(8.5, 1e-9));
      expect(decoded[1].accuracy, isNull);
    });

    test('empty list round-trips', () {
      expect(decodeTrackPoints(encodeTrackPoints(const [])), isEmpty);
    });

    test('compresses a large track well below raw JSON size', () {
      final points = List.generate(
        3600,
        (i) => GpsTrackPoint(
          timestamp: 1700000000 + i * 10,
          latitude: 20.0 + i * 0.00001,
          longitude: -87.0 - i * 0.00001,
          accuracy: 10,
        ),
      );
      final blob = encodeTrackPoints(points);
      // 3600 points raw JSON is ~200 KB; gzip should be far smaller.
      expect(blob.length, lessThan(100 * 1024));
      expect(decodeTrackPoints(blob).length, 3600);
    });
  });

  group('toWallClockEpochSeconds', () {
    test('reinterprets local wall clock as UTC', () {
      // A real-UTC instant. Its local wall-clock components, read in the
      // test runner's timezone, reinterpreted as UTC, must equal the result.
      final utc = DateTime.utc(2026, 7, 6, 15, 30, 45);
      final local = utc.toLocal();
      final expected =
          DateTime.utc(
            local.year,
            local.month,
            local.day,
            local.hour,
            local.minute,
            local.second,
          ).millisecondsSinceEpoch ~/
          1000;
      expect(toWallClockEpochSeconds(utc), expected);
    });

    test('differs from real UTC by the local offset', () {
      final utc = DateTime.utc(2026, 7, 6, 15, 30, 45);
      final offsetSeconds = utc.toLocal().timeZoneOffset.inSeconds;
      expect(
        toWallClockEpochSeconds(utc) - utc.millisecondsSinceEpoch ~/ 1000,
        offsetSeconds,
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/gps_log/track_point_codec_test.dart`
Expected: FAIL — files do not exist / symbols undefined.

- [ ] **Step 3: Implement the entities** at `lib/features/gps_log/domain/entities/gps_track.dart`:

```dart
/// A single recorded GPS fix.
///
/// [timestamp] is a wall-clock-as-UTC epoch in SECONDS: the recording
/// device's local wall-clock components reinterpreted as UTC, matching the
/// convention used by dives.entryTime so points compare directly against
/// dive timestamps on any device.
class GpsTrackPoint {
  final int timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;

  const GpsTrackPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
}

/// A recorded GPS surface track (one recording session).
///
/// [startTime] and [endTime] are wall-clock-as-UTC epoch MILLISECONDS,
/// matching dives.entryTime. [endTime] is null while recording.
class GpsTrack {
  final String id;
  final int startTime;
  final int? endTime;
  final int tzOffsetMinutes;
  final String? deviceName;
  final int pointCount;
  final List<GpsTrackPoint> points;

  const GpsTrack({
    required this.id,
    required this.startTime,
    this.endTime,
    this.tzOffsetMinutes = 0,
    this.deviceName,
    this.pointCount = 0,
    this.points = const [],
  });

  GpsTrack copyWith({
    String? id,
    int? startTime,
    int? endTime,
    int? tzOffsetMinutes,
    String? deviceName,
    int? pointCount,
    List<GpsTrackPoint>? points,
  }) {
    return GpsTrack(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      deviceName: deviceName ?? this.deviceName,
      pointCount: pointCount ?? this.pointCount,
      points: points ?? this.points,
    );
  }
}
```

- [ ] **Step 4: Implement the codec** at `lib/features/gps_log/domain/track_point_codec.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'entities/gps_track.dart';

/// Encodes points as a gzipped JSON array of
/// [wallClockEpochSeconds, lat, lon, accuracyMeters] tuples.
Uint8List encodeTrackPoints(List<GpsTrackPoint> points) {
  final json = jsonEncode([
    for (final p in points) [p.timestamp, p.latitude, p.longitude, p.accuracy],
  ]);
  return Uint8List.fromList(gzip.encode(utf8.encode(json)));
}

List<GpsTrackPoint> decodeTrackPoints(Uint8List blob) {
  final json = utf8.decode(gzip.decode(blob));
  final list = jsonDecode(json) as List<dynamic>;
  return [
    for (final raw in list)
      GpsTrackPoint(
        timestamp: (raw[0] as num).toInt(),
        latitude: (raw[1] as num).toDouble(),
        longitude: (raw[2] as num).toDouble(),
        accuracy: raw[3] == null ? null : (raw[3] as num).toDouble(),
      ),
  ];
}

/// Converts a real-UTC instant to the app's wall-clock-as-UTC epoch seconds:
/// the device's local wall-clock components reinterpreted as UTC. This is
/// the same convention dive computers' clocks follow, so track points line
/// up with dives.entryTime with no conversion at match time.
int toWallClockEpochSeconds(DateTime timestamp) {
  final local = timestamp.toLocal();
  return DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      ).millisecondsSinceEpoch ~/
      1000;
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/gps_log/track_point_codec_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add GPS track domain entities, blob codec, wall-clock conversion"
```

---

### Task 3: GpsTrackRepository (TDD)

**Files:**
- Create: `lib/features/gps_log/data/repositories/gps_track_repository.dart`
- Test: `test/features/gps_log/gps_track_repository_test.dart` (extend Task 1's file)

**Interfaces:**
- Consumes: Task 1 tables, Task 2 entities/codec. `SyncRepository.logDeletion({required String entityType, required String recordId})` and `markRecordPending({required String entityType, required String recordId, required int localUpdatedAt})` from `lib/core/data/repositories/sync_repository.dart`. `SyncEventBus.notifyLocalChange()` from `lib/core/services/sync/sync_event_bus.dart`.
- Produces (used by recorder, match service, providers):

```dart
class GpsTrackRepository {
  GpsTrackRepository({AppDatabase? db, SyncRepository? syncRepository});
  Future<String> startTrack({required int startTimeMs, required int tzOffsetMinutes, String? deviceName});
  Future<void> appendBufferPoint(String trackId, GpsTrackPoint point);
  Future<List<GpsTrackPoint>> getBufferPoints(String trackId);
  Future<void> checkpoint(String trackId);            // buffer -> blob, keeps endTime null
  Future<void> finalizeTrack(String trackId, {int? endTimeMs}); // checkpoint + endTime + clear buffer
  Future<List<String>> recoverOrphanedTracks();       // finalize any endTime-null tracks
  Future<List<GpsTrack>> getCompletedTracks({bool includePoints = false});
  Future<GpsTrack?> getTrack(String id, {bool includePoints = true});
  Future<void> deleteTrack(String id);                // row delete + tombstone
  Stream<void> watchTracksChanges();
}
```

**Pattern notes for the implementer:** copy internals style from `lib/features/checklists/data/repositories/checklist_template_repository.dart` (constructor/singleton access, logging, hlc stamping) and `lib/features/dive_log/data/repositories/dive_repository_impl.dart:300-320` (`setSite` — partial update + `markRecordPending` + `SyncEventBus.notifyLocalChange()`). Entity type key for sync is `'gpsTracks'`.

- [ ] **Step 1: Write failing tests** (append to the Task 1 test file). Construct the repository with the in-memory db and a real `SyncRepository` if its constructor allows injection of the db; if `SyncRepository` cannot be constructed in tests, check how checklist repository tests handle it (`grep -rl "ChecklistTemplateRepository" test/`) and copy that arrangement.

```dart
  group('GpsTrackRepository', () {
    late GpsTrackRepository repo;

    // setUp: construct repo against the in-memory db, mirroring how
    // checklist repository tests construct theirs.

    test('startTrack inserts an active row', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: -300,
      );
      final track = await repo.getTrack(id);
      expect(track, isNotNull);
      expect(track!.endTime, isNull);
      expect(track.tzOffsetMinutes, -300);
    });

    test('checkpoint encodes buffer into blob without ending track', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
      );
      await repo.checkpoint(id);
      final track = await repo.getTrack(id);
      expect(track!.endTime, isNull);
      expect(track.pointCount, 1);
      expect(track.points.single.latitude, 1);
      // Buffer survives a checkpoint (only finalize clears it).
      expect(await repo.getBufferPoints(id), hasLength(1));
    });

    test('finalizeTrack sets endTime, encodes points, clears buffer', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000100, latitude: 1, longitude: 2),
      );
      await repo.finalizeTrack(id, endTimeMs: 1700000200000);
      final track = await repo.getTrack(id);
      expect(track!.endTime, 1700000200000);
      expect(track.pointCount, 1);
      expect(await repo.getBufferPoints(id), isEmpty);
      expect(await repo.getCompletedTracks(), hasLength(1));
    });

    test('finalizeTrack without endTimeMs uses last buffer point time', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000500, latitude: 1, longitude: 2),
      );
      await repo.finalizeTrack(id);
      final track = await repo.getTrack(id);
      expect(track!.endTime, 1700000500000);
    });

    test('recoverOrphanedTracks finalizes stale active tracks', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000300, latitude: 1, longitude: 2),
      );
      final recovered = await repo.recoverOrphanedTracks();
      expect(recovered, [id]);
      final track = await repo.getTrack(id);
      expect(track!.endTime, isNotNull);
    });

    test('recoverOrphanedTracks deletes empty orphans', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.recoverOrphanedTracks();
      expect(await repo.getTrack(id), isNull);
    });

    test('deleteTrack removes row and writes a tombstone', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.finalizeTrack(id, endTimeMs: 1700000100000);
      await repo.deleteTrack(id);
      expect(await repo.getTrack(id), isNull);
      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.recordId.equals(id))).get();
      expect(tombstones, hasLength(1));
      expect(tombstones.single.entityType, 'gpsTracks');
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/gps_log/gps_track_repository_test.dart`
Expected: FAIL — `GpsTrackRepository` undefined.

- [ ] **Step 3: Implement the repository.** Core logic (adapt constructor/logging to the checklist repository's exact style; stamp `hlc` on every insert/update the same way that repository does — via `ensureSyncClockConfigured()` + `SyncClock.instance.issue()` if that is its pattern):

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/data/repositories/sync_repository.dart';
import '../../../../core/services/sync/sync_event_bus.dart';
import '../../domain/entities/gps_track.dart';
import '../../domain/track_point_codec.dart';

class GpsTrackRepository {
  static const _entityType = 'gpsTracks';
  final AppDatabase _db;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  // Constructor: mirror ChecklistTemplateRepository (optional injection,
  // singleton fallback).

  Future<String> startTrack({
    required int startTimeMs,
    required int tzOffsetMinutes,
    String? deviceName,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.gpsTracks)
        .insert(
          GpsTracksCompanion.insert(
            id: id,
            startTime: startTimeMs,
            tzOffsetMinutes: Value(tzOffsetMinutes),
            deviceName: Value(deviceName),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> appendBufferPoint(String trackId, GpsTrackPoint point) async {
    await _db
        .into(_db.gpsTrackPointsLocal)
        .insert(
          GpsTrackPointsLocalCompanion.insert(
            trackId: trackId,
            timestamp: point.timestamp,
            latitude: point.latitude,
            longitude: point.longitude,
            accuracy: Value(point.accuracy),
          ),
        );
  }

  Future<List<GpsTrackPoint>> getBufferPoints(String trackId) async {
    final rows =
        await (_db.select(_db.gpsTrackPointsLocal)
              ..where((t) => t.trackId.equals(trackId))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    return [
      for (final r in rows)
        GpsTrackPoint(
          timestamp: r.timestamp,
          latitude: r.latitude,
          longitude: r.longitude,
          accuracy: r.accuracy,
        ),
    ];
  }

  Future<void> checkpoint(String trackId) async {
    final points = await getBufferPoints(trackId);
    if (points.isEmpty) return;
    await _writeBlob(trackId, points, endTimeMs: null);
  }

  Future<void> finalizeTrack(String trackId, {int? endTimeMs}) async {
    final points = await getBufferPoints(trackId);
    if (points.isEmpty) {
      // Nothing recorded: an empty track is useless, remove it silently.
      await (_db.delete(
        _db.gpsTracks,
      )..where((t) => t.id.equals(trackId))).go();
      return;
    }
    final end = endTimeMs ?? points.last.timestamp * 1000;
    await _writeBlob(trackId, points, endTimeMs: end);
    await (_db.delete(
      _db.gpsTrackPointsLocal,
    )..where((t) => t.trackId.equals(trackId))).go();
  }

  Future<void> _writeBlob(
    String trackId,
    List<GpsTrackPoint> points, {
    required int? endTimeMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.gpsTracks)..where((t) => t.id.equals(trackId)))
        .write(
          GpsTracksCompanion(
            points: Value(encodeTrackPoints(points)),
            pointCount: Value(points.length),
            endTime: endTimeMs != null
                ? Value(endTimeMs)
                : const Value.absent(),
            updatedAt: Value(now),
            // hlc: stamp per checklist repository pattern
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: _entityType,
      recordId: trackId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Finalizes tracks left active by a crash or force-kill. Returns the ids
  /// of tracks that were recovered with points; empty orphans are deleted.
  Future<List<String>> recoverOrphanedTracks() async {
    final orphans = await (_db.select(
      _db.gpsTracks,
    )..where((t) => t.endTime.isNull())).get();
    final recovered = <String>[];
    for (final row in orphans) {
      final hadPoints = (await getBufferPoints(row.id)).isNotEmpty ||
          (row.points != null && row.pointCount > 0);
      if (hadPoints && (await getBufferPoints(row.id)).isEmpty) {
        // Blob exists from a checkpoint but buffer is gone: close at the
        // last blob point.
        final points = decodeTrackPoints(Uint8List.fromList(row.points!));
        await _writeBlob(row.id, points, endTimeMs: points.last.timestamp * 1000);
        recovered.add(row.id);
      } else if (hadPoints) {
        await finalizeTrack(row.id);
        recovered.add(row.id);
      } else {
        await (_db.delete(
          _db.gpsTracks,
        )..where((t) => t.id.equals(row.id))).go();
      }
    }
    return recovered;
  }

  Future<List<GpsTrack>> getCompletedTracks({bool includePoints = false}) async {
    final rows =
        await (_db.select(_db.gpsTracks)
              ..where((t) => t.endTime.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
            .get();
    return [for (final r in rows) _toDomain(r, includePoints: includePoints)];
  }

  Future<GpsTrack?> getTrack(String id, {bool includePoints = true}) async {
    final row = await (_db.select(
      _db.gpsTracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row, includePoints: includePoints);
  }

  Future<void> deleteTrack(String id) async {
    await (_db.delete(_db.gpsTracks)..where((t) => t.id.equals(id))).go();
    await (_db.delete(
      _db.gpsTrackPointsLocal,
    )..where((t) => t.trackId.equals(id))).go();
    await _syncRepository.logDeletion(entityType: _entityType, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  Stream<void> watchTracksChanges() =>
      _db.select(_db.gpsTracks).watch().map((_) => null);

  GpsTrack _toDomain(GpsTrackRow row, {required bool includePoints}) {
    return GpsTrack(
      id: row.id,
      startTime: row.startTime,
      endTime: row.endTime,
      tzOffsetMinutes: row.tzOffsetMinutes,
      deviceName: row.deviceName,
      pointCount: row.pointCount,
      points: includePoints && row.points != null
          ? decodeTrackPoints(Uint8List.fromList(row.points!))
          : const [],
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/gps_log/gps_track_repository_test.dart`
Expected: PASS (all tests including Task 1's).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add GpsTrackRepository with buffer, checkpoint, recovery, tombstones"
```

---

### Task 4: Sync serializer wiring

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (7 touch points, all modeled on the `checklistTemplates` cases)
- Test: `test/core/services/sync/sync_gps_tracks_test.dart`

**Interfaces:**
- Consumes: `GpsTrackRow` (Drift data class), Task 1 table.
- Produces: `gpsTracks` key flowing through export/import/merge; other devices receive tracks.

**Note:** `gps_track_points_local` is NOT wired into sync — it stays device-local by design. Do NOT add `gps_tracks` to `_hlcTables` in `database.dart` (that list is only for the legacy HLC-backfill migrations; the checklist tables are not in it either).

- [ ] **Step 1: Write the failing round-trip test** at `test/core/services/sync/sync_gps_tracks_test.dart`. Find an existing serializer test to copy setup from: `ls test/core/services/sync/`. Model on whichever test exercises export + import of a table (e.g. a checklists or dives serializer test). The test must:

```dart
// Pseudocode structure — copy the concrete setUp from an existing
// serializer test in test/core/services/sync/.
test('gps_tracks row round-trips through export and import', () async {
  // 1. Insert a gps_tracks row with a real encoded blob:
  final blob = encodeTrackPoints(
    [const GpsTrackPoint(timestamp: 1700000000, latitude: 20.1, longitude: -87.2, accuracy: 5)],
  );
  //    ... GpsTracksCompanion.insert(id: 'track-rt', startTime: ..., points: Value(blob), hlc: Value('...')) ...
  // 2. Export via the serializer (same call the existing test uses).
  // 3. Wipe the table (delete all rows).
  // 4. Import the exported payload via the serializer.
  // 5. Assert the row is back and decodeTrackPoints(row.points) returns the
  //    original point (blob survived JSON serialization byte-for-byte).
});

test('deleted gps_tracks row stays deleted after merge (tombstone)', () async {
  // Insert, export, delete via repository (writes tombstone), then merge the
  // stale export back in with the merge entry point the existing tombstone
  // test uses; assert row does not resurrect.
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/sync_gps_tracks_test.dart`
Expected: FAIL — serializer has no `gpsTracks` handling (export returns nothing / import throws unknown entity).

- [ ] **Step 3: Wire the serializer.** Seven touch points in `sync_data_serializer.dart`, each copying the adjacent `checklistTemplates` code shape exactly:

1. **SyncData field** (near :235): `final List<Map<String, dynamic>> gpsTracks;`
2. **Constructor default** (near :284): `this.gpsTracks = const [],`
3. **toJson** (near :334): `'gpsTracks': gpsTracks,` and **fromJson** (near :385): `gpsTracks: _parseList(json['gpsTracks']),`
4. **Descriptor entry** in `_baseTables` (after the checklist entries, near :595). Check first how existing `blob: true` entries handle binary columns (`grep -n "blob: true" lib/core/services/sync/sync_data_serializer.dart`) and match their choice:

```dart
    (key: 'gpsTracks', table: _db.gpsTracks, blob: true, full: null),
```

If no `blob: true` precedent exists, use `blob: false` — Drift's `toJson`/`fromJson` serialize `Uint8List` symmetrically, and the Step 1 round-trip test proves it either way.

5. **Export** (near :961) + helper (near :3243):

```dart
      gpsTracks: await _safeExport('gpsTracks', () => _exportGpsTracks(hlcSince)),
```

```dart
  Future<List<Map<String, dynamic>>> _exportGpsTracks(String? hlcSince) async {
    final query = _db.select(_db.gpsTracks);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

6. **Case branches** — add a `case 'gpsTracks':` to each of the four switch sites, copying the `checklistTemplates` branch with `GpsTrackRow.fromJson`:
   - single-row fetch (near :1289)
   - batch fetch-by-ids (near :1504)
   - single-record import `insertOnConflictUpdate` (near :1761): `GpsTrackRow.fromJson(data).toCompanion(false)` — `.toCompanion(false)` is required so cleared nullable fields propagate (project convention for HLC entities)
   - batch merge `insertAllOnConflictUpdate` (near :2158)
7. **Table/pk resolver** (near :2484): `case 'gpsTracks': return plain(_db.gpsTracks, _db.gpsTracks.id);`

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/sync/sync_gps_tracks_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the existing serializer test file** (regression):

Run: `flutter test test/core/services/sync/` — if this times out, run each file individually.
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Sync gps_tracks table through changeset serializer"
```

---

### Task 5: GpsTrackMatcher — pure position lookup (TDD)

**Files:**
- Create: `lib/features/gps_log/domain/gps_track_matcher.dart`
- Test: `test/features/gps_log/gps_track_matcher_test.dart`

**Interfaces:**
- Consumes: `GpsTrack`, `GpsTrackPoint` (Task 2).
- Produces:

```dart
typedef TrackPosition = ({double latitude, double longitude});
class GpsTrackMatcher {
  static const int toleranceSeconds = 1800; // 30 min, from spec
  static GpsTrack? trackCovering(List<GpsTrack> tracks, int wallClockMs);
  static TrackPosition? positionAt(List<GpsTrackPoint> points, int wallClockSeconds);
}
```

- [ ] **Step 1: Write failing tests** at `test/features/gps_log/gps_track_matcher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';

GpsTrackPoint p(int t, double lat, double lon) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: lon);

void main() {
  group('positionAt', () {
    test('interpolates linearly between bracketing points', () {
      final points = [p(1000, 10.0, 20.0), p(2000, 11.0, 21.0)];
      final pos = GpsTrackMatcher.positionAt(points, 1500);
      expect(pos, isNotNull);
      expect(pos!.latitude, closeTo(10.5, 1e-9));
      expect(pos.longitude, closeTo(20.5, 1e-9));
    });

    test('returns exact point on exact timestamp', () {
      final points = [p(1000, 10.0, 20.0), p(2000, 11.0, 21.0)];
      final pos = GpsTrackMatcher.positionAt(points, 2000);
      expect(pos!.latitude, 11.0);
    });

    test('clamps to first point within tolerance before track start', () {
      final points = [p(10000, 10.0, 20.0)];
      // 29 minutes before the first point: within 30-min tolerance.
      final pos = GpsTrackMatcher.positionAt(points, 10000 - 29 * 60);
      expect(pos!.latitude, 10.0);
    });

    test('returns null beyond tolerance before track start', () {
      final points = [p(10000, 10.0, 20.0)];
      final pos = GpsTrackMatcher.positionAt(points, 10000 - 31 * 60);
      expect(pos, isNull);
    });

    test('clamps to last point within tolerance after track end', () {
      final points = [p(10000, 10.0, 20.0)];
      expect(
        GpsTrackMatcher.positionAt(points, 10000 + 29 * 60)!.latitude,
        10.0,
      );
      expect(GpsTrackMatcher.positionAt(points, 10000 + 31 * 60), isNull);
    });

    test('does not interpolate across an interior gap wider than 2x tolerance', () {
      // A 4-hour hole (recording interruption): interpolating across it
      // would place the boat mid-transit. Nearest edge within tolerance wins.
      final points = [p(10000, 10.0, 20.0), p(10000 + 4 * 3600, 12.0, 22.0)];
      final nearStart = GpsTrackMatcher.positionAt(points, 10000 + 600);
      expect(nearStart!.latitude, 10.0); // clamped to nearest edge
      final midGap = GpsTrackMatcher.positionAt(points, 10000 + 2 * 3600);
      expect(midGap, isNull); // both edges beyond tolerance
    });

    test('empty points returns null', () {
      expect(GpsTrackMatcher.positionAt(const [], 1000), isNull);
    });
  });

  group('trackCovering', () {
    GpsTrack track(String id, int startMs, int endMs) => GpsTrack(
      id: id,
      startTime: startMs,
      endTime: endMs,
      pointCount: 1,
    );

    test('finds the track whose window contains the time', () {
      final tracks = [
        track('a', 1000000, 2000000),
        track('b', 5000000, 6000000),
      ];
      expect(GpsTrackMatcher.trackCovering(tracks, 5500000)!.id, 'b');
    });

    test('window extends by tolerance on both sides', () {
      final tracks = [track('a', 1000000, 2000000)];
      // 29 min after end (in ms).
      expect(
        GpsTrackMatcher.trackCovering(tracks, 2000000 + 29 * 60 * 1000),
        isNotNull,
      );
      expect(
        GpsTrackMatcher.trackCovering(tracks, 2000000 + 31 * 60 * 1000),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/gps_log/gps_track_matcher_test.dart`
Expected: FAIL — `GpsTrackMatcher` undefined.

- [ ] **Step 3: Implement** at `lib/features/gps_log/domain/gps_track_matcher.dart`:

```dart
import 'entities/gps_track.dart';

typedef TrackPosition = ({double latitude, double longitude});

/// Pure timestamp-to-position lookup within recorded GPS tracks.
/// All timestamps are wall-clock-as-UTC (points: seconds; tracks: ms).
class GpsTrackMatcher {
  /// Maximum distance in time between a dive timestamp and the nearest
  /// usable track point (spec: 30 minutes).
  static const int toleranceSeconds = 1800;

  static GpsTrack? trackCovering(List<GpsTrack> tracks, int wallClockMs) {
    const tolMs = toleranceSeconds * 1000;
    for (final track in tracks) {
      final end = track.endTime;
      if (end == null) continue;
      if (wallClockMs >= track.startTime - tolMs &&
          wallClockMs <= end + tolMs) {
        return track;
      }
    }
    return null;
  }

  static TrackPosition? positionAt(
    List<GpsTrackPoint> points,
    int wallClockSeconds,
  ) {
    if (points.isEmpty) return null;
    final t = wallClockSeconds;
    final first = points.first;
    final last = points.last;

    if (t <= first.timestamp) {
      return (first.timestamp - t) <= toleranceSeconds
          ? (latitude: first.latitude, longitude: first.longitude)
          : null;
    }
    if (t >= last.timestamp) {
      return (t - last.timestamp) <= toleranceSeconds
          ? (latitude: last.latitude, longitude: last.longitude)
          : null;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (t < a.timestamp || t > b.timestamp) continue;
      final gap = b.timestamp - a.timestamp;
      if (gap > 2 * toleranceSeconds) {
        // Interior hole (interrupted recording): interpolating across it
        // would invent a mid-transit position. Clamp to the nearest edge if
        // within tolerance, else no match.
        if (t - a.timestamp <= toleranceSeconds) {
          return (latitude: a.latitude, longitude: a.longitude);
        }
        if (b.timestamp - t <= toleranceSeconds) {
          return (latitude: b.latitude, longitude: b.longitude);
        }
        return null;
      }
      if (gap == 0) return (latitude: a.latitude, longitude: a.longitude);
      final f = (t - a.timestamp) / gap;
      return (
        latitude: a.latitude + (b.latitude - a.latitude) * f,
        longitude: a.longitude + (b.longitude - a.longitude) * f,
      );
    }
    return null;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/gps_log/gps_track_matcher_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add pure GPS track position matcher with interpolation and tolerance"
```

---

### Task 6: Dive repo GPS methods, GpsTrackMatchService, reparse guard (TDD)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add 2 methods next to `setSite` at :300)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart:385-389` (GPS write guard)
- Create: `lib/features/gps_log/data/services/gps_track_match_service.dart`
- Test: `test/features/gps_log/gps_track_match_service_test.dart`

**Interfaces:**
- Consumes: `GpsTrackRepository.getCompletedTracks(includePoints: true)` (Task 3), `GpsTrackMatcher` (Task 5), `setSite` pattern at `dive_repository_impl.dart:300-320`, `getDivesNeedingSiteMatch` query idiom at :322-346.
- Produces:

```dart
// On DiveRepository (impl + interface if one exists):
typedef GpsMatchCandidate = ({String id, int startMs, int? endMs});
Future<List<GpsMatchCandidate>> getDivesMissingEntryGps({List<String>? limitToIds});
Future<void> setDiveGps(String diveId, {double? entryLatitude, double? entryLongitude, double? exitLatitude, double? exitLongitude});

// New service:
class GpsTrackMatchService {
  GpsTrackMatchService({required GpsTrackRepository trackRepository, required DiveRepositoryImpl diveRepository});
  Future<List<String>> sweep({List<String>? limitToIds}); // returns stamped dive ids
}
```

- [ ] **Step 1: Add the dive repository methods** (next to `setSite`; copy its error-handling shape). `runtime` is in seconds; `entryTime`/`exitTime`/`diveDateTime` in ms:

```dart
  /// Dives lacking an entry GPS position, as (id, start, end) timestamps for
  /// GPS-track matching. Times are wall-clock-as-UTC epoch milliseconds.
  Future<List<({String id, int startMs, int? endMs})>>
  getDivesMissingEntryGps({List<String>? limitToIds}) async {
    if (limitToIds != null && limitToIds.isEmpty) return [];
    final query = _db.select(_db.dives)
      ..where((t) {
        var cond = t.entryLatitude.isNull() & t.entryLongitude.isNull();
        if (limitToIds != null) cond = cond & t.id.isIn(limitToIds);
        return cond;
      });
    final rows = await query.get();
    return [
      for (final r in rows)
        (
          id: r.id,
          startMs: r.entryTime ?? r.diveDateTime,
          endMs:
              r.exitTime ??
              (r.runtime != null
                  ? (r.entryTime ?? r.diveDateTime) + r.runtime! * 1000
                  : null),
        ),
    ];
  }

  /// Stamps GPS coordinates onto a dive. Callers must only target dives
  /// missing GPS: this never runs through the null-check itself so the
  /// matching sweep can batch-verify candidates once.
  Future<void> setDiveGps(
    String diveId, {
    double? entryLatitude,
    double? entryLongitude,
    double? exitLatitude,
    double? exitLongitude,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(
          entryLatitude: entryLatitude != null
              ? Value(entryLatitude)
              : const Value.absent(),
          entryLongitude: entryLongitude != null
              ? Value(entryLongitude)
              : const Value.absent(),
          exitLatitude: exitLatitude != null
              ? Value(exitLatitude)
              : const Value.absent(),
          exitLongitude: exitLongitude != null
              ? Value(exitLongitude)
              : const Value.absent(),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set GPS on dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Adjust nullability to the actual generated types (`r.runtime` may be non-nullable; check `database.g.dart` and drop the `!` if so).

- [ ] **Step 2: Apply the reparse guard.** In `reparse_service.dart` `_updateDiveRow` (:366-391), change the four GPS lines so a parse without GPS cannot clobber log-stamped positions:

```dart
        entryLatitude: parsed.entryLatitude != null
            ? Value(parsed.entryLatitude)
            : const Value.absent(),
        entryLongitude: parsed.entryLongitude != null
            ? Value(parsed.entryLongitude)
            : const Value.absent(),
        exitLatitude: parsed.exitLatitude != null
            ? Value(parsed.exitLatitude)
            : const Value.absent(),
        exitLongitude: parsed.exitLongitude != null
            ? Value(parsed.exitLongitude)
            : const Value.absent(),
```

Check for a second GPS write site around :329-344 (DiveDataSources companion) — that one records what the computer parsed and should stay as-is.

- [ ] **Step 3: Write failing service tests** at `test/features/gps_log/gps_track_match_service_test.dart` (in-memory DB, same setup as Task 3's test; insert dives directly via `db.into(db.dives).insert(...)` — copy required column values from an existing dive-inserting test, `grep -rl "DivesCompanion.insert" test/ | head -3`):

```dart
// Test scenarios (write with real inserts, following existing dive test fixtures):

test('sweep stamps entry and exit GPS on a dive inside a track', () async {
  // Track: two points at wall-clock seconds 1000 and 2000 (lat 10->11).
  // Dive: entryTime 1500000 ms, exitTime 1800000 ms, no GPS.
  // After sweep: entryLatitude closeTo(10.5), exitLatitude closeTo(10.8).
  // sweep() returns [diveId].
});

test('sweep skips dives that already have GPS', () async {
  // Dive with entryLatitude set: sweep returns [] and coordinates unchanged.
});

test('sweep skips dives outside all track windows', () async {
  // Dive dated hours away from the only track: sweep returns [], GPS null.
});

test('sweep respects limitToIds', () async {
  // Two GPS-less dives inside the track; limitToIds: [diveA] stamps only A.
});
```

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/features/gps_log/gps_track_match_service_test.dart`
Expected: FAIL — `GpsTrackMatchService` undefined.

- [ ] **Step 5: Implement the service** at `lib/features/gps_log/data/services/gps_track_match_service.dart`:

```dart
import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../domain/gps_track_matcher.dart';
import '../repositories/gps_track_repository.dart';

/// Sweeps GPS-less dives against recorded tracks and stamps entry/exit
/// positions. Single choke point for all three triggers (import-time,
/// track-arrival, manual) so matching behavior cannot diverge.
class GpsTrackMatchService {
  final GpsTrackRepository _trackRepository;
  final DiveRepositoryImpl _diveRepository;

  GpsTrackMatchService({
    required GpsTrackRepository trackRepository,
    required DiveRepositoryImpl diveRepository,
  }) : _trackRepository = trackRepository,
       _diveRepository = diveRepository;

  /// Returns ids of dives that received a GPS position.
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    // Close out any track a crash left open before matching against it.
    await _trackRepository.recoverOrphanedTracks();

    final candidates = await _diveRepository.getDivesMissingEntryGps(
      limitToIds: limitToIds,
    );
    if (candidates.isEmpty) return [];

    final tracks = await _trackRepository.getCompletedTracks(
      includePoints: true,
    );
    if (tracks.isEmpty) return [];

    final stamped = <String>[];
    for (final dive in candidates) {
      final track = GpsTrackMatcher.trackCovering(tracks, dive.startMs);
      if (track == null) continue;
      final entry = GpsTrackMatcher.positionAt(
        track.points,
        dive.startMs ~/ 1000,
      );
      if (entry == null) continue;
      final exit = dive.endMs != null
          ? GpsTrackMatcher.positionAt(track.points, dive.endMs! ~/ 1000)
          : null;
      await _diveRepository.setDiveGps(
        dive.id,
        entryLatitude: entry.latitude,
        entryLongitude: entry.longitude,
        exitLatitude: exit?.latitude,
        exitLongitude: exit?.longitude,
      );
      stamped.add(dive.id);
    }
    return stamped;
  }
}
```

Match the `DiveRepositoryImpl` type reference to how other services reference the dive repository (interface vs impl) — use whatever `SiteMatchingService` uses.

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/gps_log/gps_track_match_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Run reparse regression tests**

Run: `flutter test test/features/dive_computer/` — if timeouts, run the reparse test file(s) individually (`ls test/features/dive_computer/ | grep reparse`).
Expected: PASS. If a reparse test asserted GPS gets nulled by a GPS-less reparse, update that expectation — the guard is the new intended behavior.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add GPS track match sweep, dive GPS stamping, reparse GPS guard"
```

---

### Task 7: Trigger wiring — import-time and post-sync hooks

**Files:**
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart` (constructor + end of `importDives` at :401)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (success branch at :790-818)
- Create: `lib/features/gps_log/presentation/providers/gps_log_providers.dart` (service providers only in this task)
- Test: extend `test/features/gps_log/gps_track_match_service_test.dart` if feasible; otherwise verified via analyze + existing import tests.

**Interfaces:**
- Consumes: `GpsTrackMatchService.sweep` (Task 6), `ImportResult.importedDiveIds` (existing).
- Produces: `gpsTrackRepositoryProvider`, `gpsTrackMatchServiceProvider` (Riverpod `Provider`s); `DiveImportService` gains optional `GpsTrackMatchService? gpsTrackMatchService` constructor parameter.

- [ ] **Step 1: Create the service providers** at `lib/features/gps_log/presentation/providers/gps_log_providers.dart` (mirror `checklist_providers.dart` style; the dive repository provider name is discoverable via `grep -n "diveRepositoryProvider" lib/features/dive_log/presentation/providers/*.dart`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/gps_track_repository.dart';
import '../../data/services/gps_track_match_service.dart';
// import the dive repository provider from its actual location

final gpsTrackRepositoryProvider = Provider<GpsTrackRepository>(
  (ref) => GpsTrackRepository(),
);

final gpsTrackMatchServiceProvider = Provider<GpsTrackMatchService>(
  (ref) => GpsTrackMatchService(
    trackRepository: ref.watch(gpsTrackRepositoryProvider),
    diveRepository: ref.watch(diveRepositoryProvider),
  ),
);
```

Adjust the dive repository access to match how `SiteMatchingService`'s provider obtains it.

- [ ] **Step 2: Import-time hook.** Find the `DiveImportService` constructor and its construction sites: `grep -rn "DiveImportService(" lib/`. Add an optional dependency and invoke it just before the final `return ImportResult.success(...)` at `dive_import_service.dart:401`:

```dart
  // Constructor: add
  final GpsTrackMatchService? _gpsTrackMatchService;
  // named param: GpsTrackMatchService? gpsTrackMatchService,
  // initializer: _gpsTrackMatchService = gpsTrackMatchService,
```

```dart
    // Stamp GPS from recorded surface tracks before the summary step, so the
    // existing "Match sites" button sees these dives as site-matchable.
    if (_gpsTrackMatchService != null && importedDiveIds.isNotEmpty) {
      try {
        await _gpsTrackMatchService.sweep(limitToIds: importedDiveIds);
      } catch (e) {
        _log.warning('GPS track sweep after import failed: $e');
      }
    }

    return ImportResult.success(
```

(Use the service's actual logger field name.) Update the provider(s) constructing `DiveImportService` to pass `gpsTrackMatchService: ref.read(gpsTrackMatchServiceProvider)`. Leave non-provider construction sites (tests) unchanged — the parameter is optional.

- [ ] **Step 3: Post-sync hook.** In `sync_providers.dart`, in the `if (result.isSuccess)` branch (:790-818) alongside `_surfaceOldBackendCleanupOffer()` / `checkLibraryMoved()`, add a sweep. Inspect how that notifier accesses other services (constructor deps vs `ref`): if it holds a `Ref`, use `_ref.read(gpsTrackMatchServiceProvider)`; if it takes constructor deps, add `GpsTrackMatchService` the same way its existing deps are added — and update the notifier's test mocks (project history: new notifier deps break several mocks; `flutter analyze` finds them all):

```dart
          // A track that just synced in may cover dives imported earlier on
          // this device (phone-records/desktop-imports race): sweep GPS-less
          // dives against the freshly merged tracks.
          try {
            await _gpsTrackMatchService.sweep();
          } catch (e) {
            _log.warning('Post-sync GPS track sweep failed: $e');
          }
```

- [ ] **Step 4: Analyze the whole project**

Run: `flutter analyze`
Expected: No issues. Fix any test mocks flagged for the changed constructors.

- [ ] **Step 5: Run affected test files**

Run: `flutter test test/features/dive_computer/` (or individual import-service test files if timeouts) and the sync notifier's test file (find via `grep -rl "SyncNotifier\|sync_providers" test/ | head -5`).
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "Trigger GPS track matching after dive import and after sync merge"
```

---

### Task 8: GpsTrackRecorder (TDD with fake position stream)

**Files:**
- Create: `lib/features/gps_log/data/services/gps_track_recorder.dart`
- Test: `test/features/gps_log/gps_track_recorder_test.dart`

**Interfaces:**
- Consumes: `GpsTrackRepository` (Task 3), `toWallClockEpochSeconds` (Task 2), geolocator `Position`/`LocationSettings`.
- Produces:

```dart
enum GpsRecorderStatus { idle, recording }
class GpsRecorderState {
  final GpsRecorderStatus status;
  final String? trackId;
  final int pointCount;
  final DateTime? startedAt;      // real UTC, for elapsed display
  final DateTime? lastFixAt;      // real UTC
  final double? lastFixAccuracy;  // meters
}
class GpsTrackRecorder {
  GpsTrackRecorder({
    required GpsTrackRepository repository,
    Stream<Position> Function(LocationSettings)? positionStreamFactory, // test seam
    Duration keepaliveInterval = const Duration(minutes: 5),
    Duration checkpointInterval = const Duration(minutes: 10),
    Future<void> Function(String trackId)? onTrackFinalized, // wired to sweep by provider
  });
  GpsRecorderState get state;
  Stream<GpsRecorderState> get states;
  bool get isRecording;
  Future<void> start({required String notificationTitle, required String notificationText});
  Future<void> stop();
}
```

- [ ] **Step 1: Write failing tests** at `test/features/gps_log/gps_track_recorder_test.dart`. Position construction helper (geolocator 14 requires all fields):

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:drift/native.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';

Position fix({
  required double lat,
  required double lon,
  double accuracy = 5,
  DateTime? time,
}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: time ?? DateTime.now().toUtc(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  // setUp: in-memory db + repo as in gps_track_repository_test.dart,
  // plus: controller = StreamController<Position>();
  // recorder = GpsTrackRecorder(
  //   repository: repo,
  //   positionStreamFactory: (_) => controller.stream,
  // );

  test('start creates an active track and buffers incoming fixes', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    expect(recorder.isRecording, isTrue);
    controller.add(fix(lat: 10, lon: 20));
    controller.add(fix(lat: 10.001, lon: 20.001));
    await pumpEventQueue();
    expect(recorder.state.pointCount, 2);
    final buffered = await repo.getBufferPoints(recorder.state.trackId!);
    expect(buffered, hasLength(2));
  });

  test('drops fixes with accuracy worse than 100 m', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20, accuracy: 250));
    await pumpEventQueue();
    expect(recorder.state.pointCount, 0);
  });

  test('stop finalizes the track and resets to idle', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    final trackId = recorder.state.trackId!;
    await recorder.stop();
    expect(recorder.isRecording, isFalse);
    final track = await repo.getTrack(trackId);
    expect(track!.endTime, isNotNull);
    expect(track.pointCount, 1);
    expect(await repo.getBufferPoints(trackId), isEmpty);
  });

  test('stop invokes onTrackFinalized with the track id', () async {
    String? finalized;
    final r = GpsTrackRecorder(
      repository: repo,
      positionStreamFactory: (_) => controller.stream,
      onTrackFinalized: (id) async => finalized = id,
    );
    await r.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    await r.stop();
    expect(finalized, isNotNull);
  });

  test('start while recording is a no-op', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    final id = recorder.state.trackId;
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    expect(recorder.state.trackId, id);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/gps_log/gps_track_recorder_test.dart`
Expected: FAIL — `GpsTrackRecorder` undefined.

- [ ] **Step 3: Implement** at `lib/features/gps_log/data/services/gps_track_recorder.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../../domain/entities/gps_track.dart';
import '../../domain/track_point_codec.dart';
import '../repositories/gps_track_repository.dart';

enum GpsRecorderStatus { idle, recording }

class GpsRecorderState {
  final GpsRecorderStatus status;
  final String? trackId;
  final int pointCount;
  final DateTime? startedAt;
  final DateTime? lastFixAt;
  final double? lastFixAccuracy;

  const GpsRecorderState({
    this.status = GpsRecorderStatus.idle,
    this.trackId,
    this.pointCount = 0,
    this.startedAt,
    this.lastFixAt,
    this.lastFixAccuracy,
  });
}

/// Records a GPS surface track via a continuous geolocator stream.
/// Foreground-started; both platforms keep the stream alive in the
/// background under While-In-Use permission (iOS blue indicator, Android
/// foreground-service notification supplied by geolocator settings).
class GpsTrackRecorder {
  static const double maxAccuracyMeters = 100;
  static const int distanceFilterMeters = 20;

  final GpsTrackRepository _repository;
  final Stream<Position> Function(LocationSettings) _positionStreamFactory;
  final Duration _keepaliveInterval;
  final Duration _checkpointInterval;
  final Future<void> Function(String trackId)? _onTrackFinalized;

  final _stateController = StreamController<GpsRecorderState>.broadcast();
  GpsRecorderState _state = const GpsRecorderState();
  StreamSubscription<Position>? _subscription;
  Timer? _keepaliveTimer;
  Timer? _checkpointTimer;
  Position? _lastPosition;

  GpsTrackRecorder({
    required GpsTrackRepository repository,
    Stream<Position> Function(LocationSettings)? positionStreamFactory,
    Duration keepaliveInterval = const Duration(minutes: 5),
    Duration checkpointInterval = const Duration(minutes: 10),
    Future<void> Function(String trackId)? onTrackFinalized,
  }) : _repository = repository,
       _positionStreamFactory =
           positionStreamFactory ?? Geolocator.getPositionStream,
       _keepaliveInterval = keepaliveInterval,
       _checkpointInterval = checkpointInterval,
       _onTrackFinalized = onTrackFinalized;

  GpsRecorderState get state => _state;
  Stream<GpsRecorderState> get states => _stateController.stream;
  bool get isRecording => _state.status == GpsRecorderStatus.recording;

  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (isRecording) return;
    final now = DateTime.now();
    final trackId = await _repository.startTrack(
      startTimeMs: toWallClockEpochSeconds(now.toUtc()) * 1000,
      tzOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    _setState(
      GpsRecorderState(
        status: GpsRecorderStatus.recording,
        trackId: trackId,
        startedAt: now.toUtc(),
      ),
    );
    _subscription = _positionStreamFactory(
      _buildSettings(notificationTitle, notificationText),
    ).listen(_onPosition, onError: (Object _) {});
    _keepaliveTimer = Timer.periodic(_keepaliveInterval, (_) {
      final last = _lastPosition;
      final lastAt = _state.lastFixAt;
      if (last == null || lastAt == null) return;
      // Provider loss guard: if no real fix has arrived in two keepalive
      // intervals, stop fabricating coverage from the stale position. The
      // UI surfaces the growing fix age; matching treats the hole via the
      // interior-gap rule in GpsTrackMatcher.
      if (DateTime.now().toUtc().difference(lastAt) > _keepaliveInterval * 2) {
        return;
      }
      // Re-record the last known position with a fresh timestamp so a
      // moored boat still produces continuous track coverage.
      _record(last, timestampOverride: DateTime.now().toUtc());
    });
    _checkpointTimer = Timer.periodic(_checkpointInterval, (_) {
      final id = _state.trackId;
      if (id != null) _repository.checkpoint(id);
    });
  }

  Future<void> stop() async {
    final trackId = _state.trackId;
    await _subscription?.cancel();
    _keepaliveTimer?.cancel();
    _checkpointTimer?.cancel();
    _subscription = null;
    _keepaliveTimer = null;
    _checkpointTimer = null;
    _lastPosition = null;
    if (trackId != null) {
      await _repository.finalizeTrack(trackId);
      await _onTrackFinalized?.call(trackId);
    }
    _setState(const GpsRecorderState());
  }

  void _onPosition(Position position) {
    if (position.accuracy > maxAccuracyMeters) return;
    _lastPosition = position;
    _record(position);
  }

  void _record(Position position, {DateTime? timestampOverride}) {
    final trackId = _state.trackId;
    if (trackId == null) return;
    final timestamp = timestampOverride ?? position.timestamp;
    _repository.appendBufferPoint(
      trackId,
      GpsTrackPoint(
        timestamp: toWallClockEpochSeconds(timestamp),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      ),
    );
    _setState(
      GpsRecorderState(
        status: GpsRecorderStatus.recording,
        trackId: trackId,
        pointCount: _state.pointCount + 1,
        startedAt: _state.startedAt,
        lastFixAt: timestamp,
        lastFixAccuracy: position.accuracy,
      ),
    );
  }

  LocationSettings _buildSettings(String title, String text) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: title,
          notificationText: text,
          enableWakeLock: true,
        ),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
  }

  void _setState(GpsRecorderState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }
}
```

Verify the geolocator 14 API names compile (`ForegroundNotificationConfig` field names, `AppleSettings` params) — check `~/.pub-cache` sources or the package docs if analyze complains, and adjust.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/gps_log/gps_track_recorder_test.dart`
Expected: PASS (5 tests). Note: `appendBufferPoint` is fire-and-forget inside `_record`; if the pointCount assertions flake, await a `pumpEventQueue()` (already in tests) — if still flaky, make `_record` async-await the append.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add GpsTrackRecorder with accuracy gate, keepalive, checkpointing"
```

---

### Task 9: Platform permission configuration

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: nothing from code tasks.
- Produces: OS-level capability for Task 8's stream to run in background.

- [ ] **Step 1: Android manifest.** The existing `ACCESS_FINE_LOCATION` is capped (`android:maxSdkVersion="30"`, declared for BLE scanning). Add uncapped location + foreground-service permissions alongside the existing `uses-permission` block (keep the old BLE-scoped entry — remove only the exact duplicate if the uncapped line makes it redundant; `ACCESS_COARSE_LOCATION` is required by fine on modern SDKs):

```xml
    <!-- GPS track logging (surface tracks for dive position matching) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] **Step 2: iOS Info.plist.** Add `location` to the existing `UIBackgroundModes` array (near :149), and update the two location usage strings (:118-121) to also cover track recording, e.g.:

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Submersion uses your location to set dive site coordinates and to record a GPS surface track during dive days so imported dives can be matched to positions.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>Submersion uses your location to set dive site coordinates and to record a GPS surface track during dive days so imported dives can be matched to positions.</string>
```

```xml
	<key>UIBackgroundModes</key>
	<array>
		<!-- keep existing entries -->
		<string>location</string>
	</array>
```

- [ ] **Step 3: Verify nothing broke**

Run: `flutter analyze`
Expected: No issues (manifest/plist changes are not analyzed, this is a sanity gate).

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "Add background location permissions for GPS track logging"
```

---

### Task 10: UI — l10n, providers, GPS Logger page, Tools card, route

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` + all 10 other locale arbs (`ar, de, es, fr, he, hu, it, nl, pt, zh`)
- Modify: `lib/features/gps_log/presentation/providers/gps_log_providers.dart` (extend Task 7 file)
- Create: `lib/features/gps_log/presentation/pages/gps_logger_page.dart`
- Modify: `lib/features/tools/presentation/pages/tools_page.dart` (add card)
- Modify: `lib/core/router/app_router.dart` (add `/tools/gps-logger` route near :241)
- Test: `test/features/gps_log/gps_logger_page_test.dart`

**Interfaces:**
- Consumes: `GpsTrackRecorder` (Task 8), `GpsTrackRepository`/`GpsTrackMatchService` providers (Task 7), `LocationService.instance` (`checkPermission`, `requestPermission`, `isSupported`), existing `/dives/match-sites` route.
- Produces: user-facing GPS Logger feature.

- [ ] **Step 1: Add l10n strings** to `app_en.arb` (translate the same keys into all 10 other locale files — project rule; then regenerate):

```json
  "tools_gpsLogger_title": "GPS Logger",
  "tools_gpsLogger_subtitle": "Record a surface track",
  "tools_gpsLogger_description": "Record your position during a dive day and match imported dives to GPS locations automatically.",
  "gpsLogger_startButton": "Start logging",
  "gpsLogger_stopButton": "Stop logging",
  "gpsLogger_recordingStatus": "Recording - {count} points",
  "@gpsLogger_recordingStatus": {
    "placeholders": { "count": { "type": "int" } }
  },
  "gpsLogger_lastFix": "Last fix {age} ago ({accuracy})",
  "@gpsLogger_lastFix": {
    "placeholders": { "age": { "type": "String" }, "accuracy": { "type": "String" } }
  },
  "gpsLogger_noFixYet": "Waiting for GPS fix",
  "gpsLogger_tracksHeader": "Recorded tracks",
  "gpsLogger_noTracks": "No GPS tracks recorded yet",
  "gpsLogger_trackSubtitle": "{count} points, {duration}",
  "@gpsLogger_trackSubtitle": {
    "placeholders": { "count": { "type": "int" }, "duration": { "type": "String" } }
  },
  "gpsLogger_matchButton": "Match dives to GPS logs",
  "gpsLogger_matchResult": "{count} dives positioned",
  "@gpsLogger_matchResult": {
    "placeholders": { "count": { "type": "int" } }
  },
  "gpsLogger_matchResultNone": "No dives matched a recorded track",
  "gpsLogger_reviewSites": "Review site matches",
  "gpsLogger_deleteTrackTitle": "Delete track?",
  "gpsLogger_deleteTrackMessage": "This removes the recorded GPS track. Positions already stamped on dives are kept.",
  "gpsLogger_permissionDenied": "Location permission is required to record a GPS track. Enable it in system settings.",
  "gpsLogger_locationOff": "Location services are turned off.",
  "gpsLogger_interruptedNotice": "A previous recording was interrupted. The track was saved.",
  "gpsLogger_androidNotificationTitle": "Submersion GPS Logger",
  "gpsLogger_androidNotificationText": "Recording your surface track"
```

Run: `flutter gen-l10n` (or the project's l10n generation step if different — check how existing strings regenerate).
Expected: `lib/l10n/app_localizations_en.dart` gains the getters.

- [ ] **Step 2: Extend providers** in `gps_log_providers.dart`:

```dart
final gpsTrackRecorderProvider = Provider<GpsTrackRecorder>((ref) {
  final recorder = GpsTrackRecorder(
    repository: ref.watch(gpsTrackRepositoryProvider),
    onTrackFinalized: (_) async {
      await ref.read(gpsTrackMatchServiceProvider).sweep();
    },
  );
  ref.onDispose(recorder.stop);
  return recorder;
});

final gpsRecorderStateProvider = StreamProvider<GpsRecorderState>(
  (ref) => ref.watch(gpsTrackRecorderProvider).states,
);

/// Completed tracks for the logger page list.
final gpsTracksProvider = FutureProvider<List<GpsTrack>>((ref) async {
  final repository = ref.watch(gpsTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTracksChanges());
  return repository.getCompletedTracks();
});
```

(`invalidateSelfWhen` is the project's extension — see `checklist_providers.dart`. Render lists from `AsyncValue.value` to avoid reload flicker, per project convention.)

- [ ] **Step 3: Build the page** at `lib/features/gps_log/presentation/pages/gps_logger_page.dart`. Structure (follow an existing simple tools/settings page for Scaffold/AppBar idioms, e.g. `weight_calculator_page.dart`):

- `ConsumerStatefulWidget` watching `gpsRecorderStateProvider` and `gpsTracksProvider`.
- **Interrupted-recording recovery**: in `initState` (via `Future.microtask` — Riverpod 3 forbids provider mutation during lifecycle callbacks), if the recorder is not recording, call `repository.recoverOrphanedTracks()`; when it returns a non-empty list, show a SnackBar with `context.l10n.gpsLogger_interruptedNotice` (the track list refreshes itself via `watchTracksChanges`).
- **Record section** (hidden when `!LocationService.instance.isSupported || !(Platform.isAndroid || Platform.isIOS)`): when idle, a `FilledButton.icon` with `context.l10n.gpsLogger_startButton`; when recording, elapsed time, `gpsLogger_recordingStatus(state.pointCount)`, last-fix line (`gpsLogger_lastFix(ageString, accuracyString)` or `gpsLogger_noFixYet`), and a stop button. Format the accuracy distance with the app's unit-formatting helper so it respects the diver's depth/distance unit setting (`grep -rn "formatDistance\|UnitFormatter" lib/core/ | head` to find it).
- Start button handler: check `LocationService.instance.checkPermission()`; if denied request; if `deniedForever` show a dialog with `gpsLogger_permissionDenied`; if `Geolocator.isLocationServiceEnabled()` is false show `gpsLogger_locationOff`; else `recorder.start(notificationTitle: context.l10n.gpsLogger_androidNotificationTitle, notificationText: context.l10n.gpsLogger_androidNotificationText)`.
- **Tracks section**: header `gpsLogger_tracksHeader`; `gpsLogger_noTracks` empty state; per track a `ListTile` with the formatted start date (existing date-format helpers) and `gpsLogger_trackSubtitle(pointCount, durationString)`, plus a delete `IconButton` guarded by an `AlertDialog` (`gpsLogger_deleteTrackTitle` / `gpsLogger_deleteTrackMessage`). Use `persist: false` + `showCloseIcon` if any SnackBar has an action (project convention).
- **Match action**: `OutlinedButton` `gpsLogger_matchButton` calling `ref.read(gpsTrackMatchServiceProvider).sweep()`; on result show a SnackBar with `gpsLogger_matchResult(n)` (or `gpsLogger_matchResultNone`) and, when n > 0, an action `gpsLogger_reviewSites` doing `context.push('/dives/match-sites', extra: stampedIds)`.

- [ ] **Step 4: Register route and card.** In `app_router.dart` next to the weight-calculator route (:241):

```dart
                  GoRoute(
                    path: 'gps-logger',
                    name: 'gpsLogger',
                    builder: (context, state) => const GpsLoggerPage(),
                  ),
```

In `tools_page.dart` after the weight calculator card:

```dart
          _ToolCard(
            icon: Icons.gps_fixed,
            iconColor: colorScheme.tertiary,
            title: context.l10n.tools_gpsLogger_title,
            subtitle: context.l10n.tools_gpsLogger_subtitle,
            description: context.l10n.tools_gpsLogger_description,
            onTap: () => context.go('/tools/gps-logger'),
          ),
```

- [ ] **Step 5: Write widget tests** at `test/features/gps_log/gps_logger_page_test.dart` (copy `ProviderScope` override setup from an existing page test, e.g. one under `test/features/tools/` or `test/features/checklists/`):

```dart
// Scenarios:
// 1. Idle state shows the start button and empty-tracks message
//    (override gpsRecorderStateProvider with idle state, gpsTracksProvider
//    with []).
// 2. Recording state shows point count and stop button (override state with
//    status: recording, pointCount: 42; expect text containing '42').
// 3. Track list renders a tile per completed track with delete icon.
// Overrides: gpsTrackRecorderProvider with a recorder built on a
// StreamController<Position> factory and in-memory repo, or override the
// state/tracks providers directly with fixed values (simpler; do that).
```

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/features/gps_log/gps_logger_page_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "Add GPS Logger page, tools card, route, and localized strings"
```

---

### Task 11: Full verification pass

**Files:** none new.

- [ ] **Step 1: Whole-project format check**

Run: `dart format .`
Expected: "0 changed" (if files changed, commit the formatting).

- [ ] **Step 2: Whole-project analyze** (never pipe through tail/head — read full output)

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run every test file this feature added or touched, individually:**

```bash
flutter test test/features/gps_log/track_point_codec_test.dart
flutter test test/features/gps_log/gps_track_matcher_test.dart
flutter test test/features/gps_log/gps_track_repository_test.dart
flutter test test/features/gps_log/gps_track_match_service_test.dart
flutter test test/features/gps_log/gps_track_recorder_test.dart
flutter test test/features/gps_log/gps_logger_page_test.dart
flutter test test/core/services/sync/sync_gps_tracks_test.dart
```

Expected: all PASS.

- [ ] **Step 4: Run neighboring regression suites** (import, reparse, site matching, sync notifier — individual files if directories time out):

```bash
flutter test test/features/dive_computer/
flutter test test/features/dive_sites/
```

Expected: PASS.

- [ ] **Step 5: Build smoke test on macOS**

Run: `flutter build macos --debug`
Expected: builds. (Recording is hidden on macOS; this verifies the page, providers, and geolocator settings compile for desktop.)

- [ ] **Step 6: Commit any stragglers**

```bash
git status
# commit only if steps 1-5 produced changes
```

**Manual verification (post-merge, real hardware — cannot be automated):** start a recording on a phone, lock the screen 20+ minutes, walk around, stop; import a dive whose wall-clock time falls inside the track; confirm entry GPS is stamped and the Match Sites flow proposes the right site. Verify Android persistent notification and iOS blue indicator appear.
