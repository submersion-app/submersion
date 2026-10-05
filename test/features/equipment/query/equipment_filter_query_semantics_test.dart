import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

/// What each equipment filter axis selects through the compiled query
/// (#2365), against rows: the status views (#636), category and curated
/// attributes (#1805), tags (#1942) and the owner scope (#2046) that
/// EquipmentFilterState.apply() once pinned in memory. The service-due
/// axis is pinned by equipment_service_status_cache_test.
void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    Future<void> item(
      String id,
      String type, {
      String? diver = 'me',
      String status = 'active',
      bool active = true,
    }) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
            diverId: Value(diver),
            status: Value(status),
            isActive: Value(active),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await item('bcd', 'bcd');
    await item('suit', 'wetsuit');
    // A legacy row: retired, with is_active never cleared.
    await item('old', 'regulator', status: 'retired');
    // A legacy row: only is_active cleared.
    await item('shelved', 'regulator', active: false);
    await item('gone', 'regulator', status: 'sold', active: false);
    await item('loan', 'computer', status: 'loaned');
    await item('lent', 'computer', diver: 'other');
    await item('mine0', 'fins', diver: null);
    // Wishlist gear (#2025), including a row whose is_active was left set.
    await item('wish', 'bcd', status: 'wanted', active: false);
    await item('wish2', 'fins', status: 'wanted');
    await db
        .into(db.equipmentShares)
        .insert(
          EquipmentSharesCompanion.insert(
            id: 'sh1',
            equipmentId: 'lent',
            diverId: 'me',
            createdAt: now,
          ),
        );
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion.insert(
            id: 'a1',
            equipmentId: 'suit',
            attrKey: 'thickness_mm',
            valueNum: const Value(7),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 't1',
            name: 'Travel',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.equipmentTags)
        .insert(
          EquipmentTagsCompanion.insert(
            id: 'et1',
            equipmentId: 'bcd',
            tagId: 't1',
            createdAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  /// The visible gear (the list's rows) the filter selects for 'me'.
  Future<Set<String>> selected(EquipmentFilterState f) async {
    final visible = {
      for (final e in await EquipmentRepository().getAllEquipment(
        diverId: 'me',
      ))
        e.id,
    };
    final ids = await QueryIdSetRunner(
      db,
    ).ids(compileEquipmentFilter(f), scope: f.ownerScope('me'));
    return ids.intersection(visible);
  }

  const defaultView = {'bcd', 'suit', 'loan', 'lent'};

  test('the default view hides retired, inactive and sold gear', () async {
    expect(await selected(const EquipmentFilterState()), defaultView);
  });

  test(
    'All Equipment selects every item, retired and sold too (#2590)',
    () async {
      final visible = {
        for (final e in await EquipmentRepository().getAllEquipment(
          diverId: 'me',
        ))
          e.id,
      };
      final all = await selected(const EquipmentFilterState(allStatuses: true));
      expect(all, visible);
      expect(all, containsAll(['old', 'shelved', 'gone']));
      expect(all, containsAll(defaultView));
    },
  );

  test('All Equipment still narrows by the other axes', () async {
    expect(
      await selected(
        const EquipmentFilterState(
          allStatuses: true,
          type: EquipmentType.regulator,
        ),
      ),
      {'old', 'shelved', 'gone'},
    );
  });

  test('each status view selects its gear', () async {
    expect(
      await selected(
        const EquipmentFilterState(status: EquipmentStatus.retired),
      ),
      {'old', 'shelved'},
    );
    expect(
      await selected(const EquipmentFilterState(status: EquipmentStatus.sold)),
      {'gone'},
    );
    expect(
      await selected(
        const EquipmentFilterState(status: EquipmentStatus.loaned),
      ),
      {'loan'},
    );
  });

  test('the Wanted view selects only wishlist gear (#2025)', () async {
    expect(
      await selected(
        const EquipmentFilterState(status: EquipmentStatus.wanted),
      ),
      {'wish', 'wish2'},
    );
  });

  test('the category narrows, and each condition narrows further', () async {
    expect(
      await selected(const EquipmentFilterState(type: EquipmentType.wetsuit)),
      {'suit'},
    );
    expect(
      await selected(
        EquipmentFilterState(
          type: EquipmentType.wetsuit,
          attrConditions: [EquipmentAttrCondition.suitThickness(min: 5)],
        ),
      ),
      {'suit'},
    );
    expect(
      await selected(
        EquipmentFilterState(
          type: EquipmentType.wetsuit,
          attrConditions: [EquipmentAttrCondition.suitThickness(min: 9)],
        ),
      ),
      isEmpty,
    );
  });

  test('tags match any of the selected, ANDed with the other axes', () async {
    expect(await selected(const EquipmentFilterState(tagIds: {'t1'})), {'bcd'});
    expect(
      await selected(
        const EquipmentFilterState(type: EquipmentType.bcd, tagIds: {'t1'}),
      ),
      {'bcd'},
    );
    expect(
      await selected(
        const EquipmentFilterState(type: EquipmentType.wetsuit, tagIds: {'t1'}),
      ),
      isEmpty,
    );
    expect(
      await selected(
        EquipmentFilterState(
          type: EquipmentType.wetsuit,
          attrConditions: [EquipmentAttrCondition.suitThickness(min: 5)],
          tagIds: const {'t1'},
        ),
      ),
      isEmpty,
    );
  });

  test('the owner scope compares each item with the active diver', () async {
    expect(
      await selected(
        const EquipmentFilterState(owner: EquipmentOwnerFilter.mine),
      ),
      {'bcd', 'suit', 'loan'},
    );
    expect(
      await selected(
        const EquipmentFilterState(owner: EquipmentOwnerFilter.sharedWithMe),
      ),
      {'lent'},
    );
  });

  test('with no active diver the owner axis narrows nothing', () {
    expect(
      const EquipmentFilterState(
        owner: EquipmentOwnerFilter.mine,
      ).ownerScope(null),
      isNull,
    );
  });
}
