import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// v261 dropped diver_settings.default_ceiling_source (#767). Peers below
/// 261 still publish `defaultCeilingSource` in their settings payloads, and
/// this build must apply those payloads with the key ignored, not rejected.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // A placeholder diver_id needn't reference a real diver: these rows only
    // exercise the settings serialization path.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// An exported settings row as an older peer would publish it: this
  /// build's wire format plus the retired key.
  Future<Map<String, dynamic>> legacyPayload(String id) async {
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
    return {...exported!, 'defaultCeilingSource': 0, 'defaultNdlSource': 0};
  }

  test('an exported settings row no longer carries the retired key', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds0',
            diverId: 'diver-0',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final exported = await serializer.fetchRecord('diverSettings', 'ds0');

    expect(exported, isNotNull);
    expect(exported!.containsKey('defaultCeilingSource'), isFalse);
  });

  test('a single legacy payload applies with the key ignored', () async {
    final payload = await legacyPayload('ds1');

    await serializer.upsertRecord('diverSettings', payload);

    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds1'))).getSingle();
    // The rest of the payload lands.
    expect(row.defaultNdlSource, 0);
  });

  test('a batch of legacy payloads applies with the key ignored', () async {
    final first = await legacyPayload('ds2');
    final second = await legacyPayload('ds3');

    await serializer.upsertRecords('diverSettings', [first, second]);

    final rows = await db.select(db.diverSettings).get();
    expect(rows.map((r) => r.id), containsAll(['ds2', 'ds3']));
    expect(rows.every((r) => r.defaultNdlSource == 0), isTrue);
  });
}
