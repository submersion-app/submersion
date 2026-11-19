import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_shares_sharing_adapter.dart';

import '../../../../helpers/test_database.dart';

/// A gear item's sharing held in its sitting writes through this adapter
/// (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late EquipmentSharesSharingAdapter adapter;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['me', 'sam']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'BCD',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('me'),
          ),
        );
    adapter = EquipmentSharesSharingAdapter(EquipmentShareRepository());
  });

  tearDown(tearDownTestDatabase);

  Future<int> shareRows() async =>
      (await db.select(db.equipmentShares).get()).length;

  test('the owner shares, and the sharing reads back', () async {
    final done = await adapter.write('bcd', {'sam'}, actingDiverId: 'me');

    expect(done, isTrue);
    expect(await adapter.read('bcd'), {'sam'});
  });

  // A profile deleted on another device while the sitting was open is not
  // the diver's to fix: the rest of the sharing is written.
  test('a profile that no longer exists is left out, not refused', () async {
    final done = await adapter.write('bcd', {
      'sam',
      'ghost',
    }, actingDiverId: 'me');

    expect(done, isTrue);
    expect(await adapter.read('bcd'), {'sam'});
  });

  test('another profile is refused and changes nothing', () async {
    final done = await adapter.write('bcd', {'sam'}, actingDiverId: 'sam');

    expect(done, isFalse);
    expect(await shareRows(), 0);
  });

  test('no acting profile is refused and writes nothing', () async {
    final done = await adapter.write('bcd', {'sam'}, actingDiverId: null);

    expect(done, isFalse);
    expect(await shareRows(), 0);
  });
}
