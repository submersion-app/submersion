import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_history_providers.dart';

import '../../../../helpers/test_database.dart';

/// The History card refreshes when the item is put on or taken off a dive,
/// which writes only dive_equipment or dive_tanks (issue #2046).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'me', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at, '
      "diver_id) VALUES ('cyl', 'AL80', 'tank', 0, 0, 'me')",
    );
    for (final id in ['d1', 'd2']) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at) VALUES ('$id', 'me', 0, 0, 0)",
      );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<int> diveCount(ProviderContainer c) async {
    final entries = await c.read(equipmentHistoryProvider('cyl').future);
    return entries.whereType<EquipmentUsageRun>().fold<int>(
      0,
      (sum, r) => sum + r.diveCount,
    );
  }

  test('adding the item to a dive refreshes the history', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(equipmentHistoryProvider('cyl'), (_, _) {});
    addTearDown(sub.close);
    expect(await diveCount(container), 0);

    // customInsert with `updates` notifies table watchers, as every real
    // write does (a bare customStatement would not).
    await db.customInsert(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d1', 'cyl')",
      updates: {db.diveEquipment},
    );
    await db.customInsert(
      'INSERT INTO dive_tanks (id, dive_id, equipment_id) '
      "VALUES ('t2', 'd2', 'cyl')",
      updates: {db.diveTanks},
    );
    // Let the change ticks (debounced) fire and the provider rebuild.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(await diveCount(container), 2);
  });
}
