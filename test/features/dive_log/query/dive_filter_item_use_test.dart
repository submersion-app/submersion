import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

/// The item page's dive links list what their counts read: the dives the item
/// was used on, so no plans (issue #4016). The diver's own equipment filter
/// still finds plans carrying the item.
void main() {
  const item = 'item';

  late AppDatabase db;

  Future<void> addDive(
    String id, {
    bool planned = false,
    bool excludedFromStats = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: 1,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(
            isPlanned: Value(planned),
            excludedFromStats: Value(excludedFromStats),
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(DiveEquipmentCompanion.insert(diveId: id, equipmentId: item));
  }

  Future<Set<String>> listed(DiveFilterState filter) =>
      QueryIdSetRunner(db).ids(compileDiveFilter(filter));

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: item,
            name: item,
            type: 'bcd',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test('the link lists what the Dives row counts', () async {
    await addDive('actual');
    await addDive('plan', planned: true);

    final ids = await listed(DiveFilterState.itemUse(item));

    expect(ids, {'actual'});
    expect(await EquipmentRepository().getDiveCountForEquipment(item), 1);
  });

  test(
    'a dive excluded from statistics stays, as the count keeps it',
    () async {
      await addDive('practice', excludedFromStats: true);

      expect(await listed(DiveFilterState.itemUse(item)), {'practice'});
      expect(await EquipmentRepository().getDiveCountForEquipment(item), 1);
    },
  );

  test('the equipment filter on its own still finds a plan', () async {
    await addDive('actual');
    await addDive('plan', planned: true);

    expect(await listed(const DiveFilterState(equipmentIds: [item])), {
      'actual',
      'plan',
    });
  });

  test('it goes with the items, so it filters nothing without them', () async {
    await addDive('plan', planned: true);

    expect(await listed(const DiveFilterState(equipmentUsedOnly: true)), {
      'plan',
    });
  });

  group('DiveFilterState', () {
    final link = DiveFilterState.itemUse(item);

    test('is no axis of its own', () {
      expect(link.activeAxisCount, 1);
      expect(
        const DiveFilterState(equipmentUsedOnly: true).hasActiveFilters,
        isFalse,
      );
    });

    test('counts in equality', () {
      const plain = DiveFilterState(equipmentIds: [item]);

      expect(link, isNot(plain));
      expect(link, DiveFilterState.itemUse(item));
      expect(link.hashCode, DiveFilterState.itemUse(item).hashCode);
    });

    test('survives an edit to another axis', () {
      expect(link.copyWith(favoritesOnly: true).equipmentUsedOnly, isTrue);
    });

    test('ends with the items it came with', () {
      expect(link.copyWith(clearEquipmentIds: true).equipmentUsedOnly, isFalse);
      expect(link.copyWith(equipmentIds: ['other']).equipmentUsedOnly, isFalse);
    });
  });
}
