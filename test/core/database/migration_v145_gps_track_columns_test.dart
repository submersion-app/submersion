import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test('gps_tracks carries the v145 columns', () async {
    final columns = await db
        .customSelect("PRAGMA table_info('gps_tracks')")
        .get();
    final names = columns.map((r) => r.read<String>('name')).toSet();

    expect(names, contains('source'));
    expect(names, contains('source_ref'));
    expect(names, contains('name'));
    expect(names, contains('trim_start_time'));
    expect(names, contains('trim_end_time'));
  });

  test('source defaults to phone for a row inserted without it', () async {
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
    expect(row.source, 'phone');
    expect(row.sourceRef, isNull);
    expect(row.name, isNull);
    expect(row.trimStartTime, isNull);
    expect(row.trimEndTime, isNull);
  });

  test('schema version is at least 145', () {
    // greaterThanOrEqualTo, matching migration_v142_trip_return_flight_test:
    // parallel branches bump this ladder, and an exact assertion would fail
    // on merge for no real reason. This step was itself renumbered from v144
    // when main took that rung for the visibility scale work.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(145));
  });
}
