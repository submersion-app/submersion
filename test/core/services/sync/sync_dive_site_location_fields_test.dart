import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// Sync serializes dive sites through Drift's generated `toJson`/`fromJson`
/// (see SyncDataSerializer._exportDiveSites and the diveSites import case), so
/// new columns are carried automatically. This guards that city, island, and
/// bodyOfWater survive a serialize -> deserialize cycle with no sync code.
void main() {
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    database = DatabaseService.instance.database;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('dive site city/island/bodyOfWater survive toJson/fromJson', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database
        .into(database.diveSites)
        .insert(
          db.DiveSitesCompanion.insert(
            id: 'sync-1',
            name: 'Sync Site',
            createdAt: now,
            updatedAt: now,
            city: const Value('Cebu City'),
            island: const Value('Malapascua'),
            bodyOfWater: const Value('Visayan Sea'),
          ),
        );
    final row = await (database.select(
      database.diveSites,
    )..where((t) => t.id.equals('sync-1'))).getSingle();

    final json = row.toJson();
    final restored = db.DiveSite.fromJson(json);

    expect(restored.city, 'Cebu City');
    expect(restored.island, 'Malapascua');
    expect(restored.bodyOfWater, 'Visayan Sea');
  });
}
