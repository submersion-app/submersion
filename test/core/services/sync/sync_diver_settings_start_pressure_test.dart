import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// v275 retyped diver_settings.default_start_pressure from INTEGER to REAL
/// (issue #3091) and raised the floor to 275, which stops older readers
/// applying our decimals. The floor cannot stop the other direction: a peer
/// below 275 still publishes the whole-bar int, and this build must apply it.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Map<String, dynamic>> exportRow(double startPressure) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-sp',
            diverId: 'diver-sp',
            createdAt: now,
            updatedAt: now,
            defaultStartPressure: Value(startPressure),
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', 'ds-sp');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-sp'))).go();
    return exported!;
  }

  Future<double> storedStartPressure() async {
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-sp'))).getSingle();
    return row.defaultStartPressure;
  }

  test('a decimal start pressure round-trips exactly', () async {
    final exported = await exportRow(206.8428);
    expect(exported['defaultStartPressure'], 206.8428);

    await serializer.upsertRecord('diverSettings', exported);

    expect(await storedStartPressure(), 206.8428);
  });

  test("applies a pre-v275 peer's whole-bar int", () async {
    final legacy = {...await exportRow(200), 'defaultStartPressure': 232};

    await serializer.upsertRecord('diverSettings', legacy);

    expect(await storedStartPressure(), 232.0);
  });

  test('a payload missing the key falls back to 200 bar', () async {
    final legacy = Map<String, dynamic>.from(await exportRow(232))
      ..remove('defaultStartPressure');

    await serializer.upsertRecord('diverSettings', legacy);

    expect(await storedStartPressure(), 200.0);
  });
}
