import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';

/// Sync serializes dive_profiles rows with Drift's generated `toJson()` and
/// restores them with `DiveProfile.fromJson`, so new columns ride along without
/// a serializer change. This pins that: if profile sync is ever switched to an
/// explicit column list, the O2 cell millivolts (issue #810) must be added to
/// it, and this test is what says so.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.utc(2026, 8, 15, 10).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-mv',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(() async => tearDownTestDatabase());

  Future<DiveProfile> insertProfileRow({
    required String id,
    int? mv1,
    int? mv2,
    int? mv3,
    double? sensor1,
  }) async {
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion.insert(
            id: id,
            diveId: 'dive-mv',
            timestamp: 60,
            depth: 20.0,
            o2Sensor1: Value(sensor1),
            o2SensorMv1: Value(mv1),
            o2SensorMv2: Value(mv2),
            o2SensorMv3: Value(mv3),
          ),
        );
    return (db.select(
      db.diveProfiles,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  test('millivolts survive the sync export/import round trip', () async {
    final row = await insertProfileRow(id: 'p1', mv1: 58, mv2: 61, mv3: 43);

    final json = row.toJson();
    expect(json['o2SensorMv1'], 58);
    expect(json['o2SensorMv2'], 61);
    expect(json['o2SensorMv3'], 43);

    final restored = DiveProfile.fromJson(json);
    expect(restored.o2SensorMv1, 58);
    expect(restored.o2SensorMv2, 61);
    expect(restored.o2SensorMv3, 43);
    expect(restored.o2SensorMv4, isNull);
  });

  test('a payload written before v151 restores with null millivolts', () async {
    // A peer still on the old schema sends a profile with no millivolt keys.
    // Restoring it must not throw -- the columns are nullable.
    final row = await insertProfileRow(id: 'p2', sensor1: 0.98);
    final legacy = Map<String, dynamic>.from(row.toJson())
      ..removeWhere((key, _) => key.startsWith('o2SensorMv'));

    final restored = DiveProfile.fromJson(legacy);
    expect(restored.o2Sensor1, 0.98);
    expect(restored.o2SensorMv1, isNull);
    expect(restored.o2SensorMv6, isNull);
  });
}
