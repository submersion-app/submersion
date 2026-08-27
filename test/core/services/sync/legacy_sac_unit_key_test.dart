// A peer or backup written before v170 keys the consumption preference as
// 'sacUnit' with a unit spelling. Raising minimumCompatibleSchemaVersion
// stops OLD readers applying OUR payloads, but the gate is one-directional,
// so their payloads still arrive here and must land on the lane they meant.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // FK enforcement off so a placeholder diver_id needn't reference a real
    // diver; this only exercises the settings serialization path.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A wire-format settings row as this build exports it, minus the new key.
  Future<Map<String, dynamic>> legacyRecord(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-$id',
            createdAt: now,
            updatedAt: now,
            gasConsumptionDisplay: const Value('both'),
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', id);
    expect(exported, isNotNull);
    await (db.delete(db.diverSettings)..where((t) => t.id.equals(id))).go();
    return Map<String, dynamic>.from(exported!)
      ..remove('gasConsumptionDisplay');
  }

  Future<String> displayOf(String id) async {
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.gasConsumptionDisplay;
  }

  test('an old peer on L/min lands on the RMV lane', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-vol'),
      'sacUnit': 'litersPerMin',
    });
    expect(await displayOf('ds-vol'), 'rmv');
  });

  test('an old peer on pressure/min lands on the SAC lane', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-prs'),
      'sacUnit': 'pressurePerMin',
    });
    expect(await displayOf('ds-prs'), 'sac');
  });

  test('the batched path maps the value too', () async {
    await serializer.upsertRecords('diverSettings', [
      {...await legacyRecord('ds-batch'), 'sacUnit': 'litersPerMin'},
    ]);
    expect(await displayOf('ds-batch'), 'rmv');
  });

  test('a current payload keyed gasConsumptionDisplay applies as is', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-new'),
      'gasConsumptionDisplay': 'sac',
    });
    expect(await displayOf('ds-new'), 'sac');
  });

  test('a payload with neither key hydrates to both', () async {
    await serializer.upsertRecord(
      'diverSettings',
      await legacyRecord('ds-none'),
    );
    expect(await displayOf('ds-none'), 'both');
  });

  test('a payload carrying both keys prefers the current spelling', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-both'),
      'sacUnit': 'litersPerMin',
      'gasConsumptionDisplay': 'sac',
    });
    expect(await displayOf('ds-both'), 'sac');
  });
}
