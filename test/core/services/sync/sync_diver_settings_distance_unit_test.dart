import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Issue #2030. A diver_settings row from a peer older than v262 carries no
/// distanceUnit. For a row new to this device the column default would make
/// a feet diver's distances kilometres; the unit is derived from the
/// payload's own depth unit instead.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A wire payload for settings row [id] as a pre-v262 peer sends it.
  Future<Map<String, dynamic>> legacyPayload(
    String id, {
    required String depthUnit,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-$id',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', id);
    await (db.delete(db.diverSettings)..where((t) => t.id.equals(id))).go();
    return Map<String, dynamic>.from(exported!)
      ..remove('distanceUnit')
      ..['depthUnit'] = depthUnit;
  }

  Future<String> storedDistanceUnit(String id) async {
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.distanceUnit;
  }

  test('a new feet row from an older peer hydrates to miles', () async {
    await serializer.upsertRecord(
      'diverSettings',
      await legacyPayload('ds1', depthUnit: 'feet'),
    );
    expect(await storedDistanceUnit('ds1'), 'miles');
  });

  test('a new metres row from an older peer hydrates to kilometers', () async {
    await serializer.upsertRecord(
      'diverSettings',
      await legacyPayload('ds1', depthUnit: 'meters'),
    );
    expect(await storedDistanceUnit('ds1'), 'kilometers');
  });

  test('the batch path derives it too', () async {
    await serializer.upsertRecords('diverSettings', [
      await legacyPayload('ds1', depthUnit: 'feet'),
      await legacyPayload('ds2', depthUnit: 'meters'),
    ]);
    expect(await storedDistanceUnit('ds1'), 'miles');
    expect(await storedDistanceUnit('ds2'), 'kilometers');
  });

  test('a payload that carries the unit keeps it', () async {
    final payload = await legacyPayload('ds1', depthUnit: 'feet');
    payload['distanceUnit'] = 'kilometers';
    await serializer.upsertRecord('diverSettings', payload);
    expect(await storedDistanceUnit('ds1'), 'kilometers');
  });

  test('a row this device holds keeps its own unit', () async {
    final payload = await legacyPayload('ds1', depthUnit: 'meters');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds1',
            diverId: 'diver-ds1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.customStatement(
      "UPDATE diver_settings SET distance_unit = 'miles' WHERE id = 'ds1'",
    );
    await serializer.upsertRecord('diverSettings', payload);
    expect(await storedDistanceUnit('ds1'), 'miles');
  });

  test('the batch path keeps the unit of a row this device holds', () async {
    final payload = await legacyPayload('ds1', depthUnit: 'meters');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds1',
            diverId: 'diver-ds1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.customStatement(
      "UPDATE diver_settings SET distance_unit = 'miles' WHERE id = 'ds1'",
    );
    await serializer.upsertRecords('diverSettings', [payload]);
    expect(await storedDistanceUnit('ds1'), 'miles');
  });
}
