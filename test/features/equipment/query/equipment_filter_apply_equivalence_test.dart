import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

/// The compiled equipment query selects what the old pipeline did: the
/// provider chosen by the status axis, then EquipmentFilterState.apply
/// (#2365). Deleted with apply() once the list reads the query. The
/// service-due axis is pinned by equipment_service_status_cache_test.
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

  Future<Set<String>> oldPipeline(EquipmentFilterState f) async {
    final repo = EquipmentRepository();
    final base = f.status == null
        ? await repo.getActiveEquipment(diverId: 'me')
        : await repo.getEquipmentByStatus(f.status!, diverId: 'me');
    final tags = {
      for (final e
          in (await EquipmentTagRepository().getTagsByEquipment()).entries)
        e.key: [for (final t in e.value) t.id],
    };
    return {for (final e in f.apply(base, tags, activeDiverId: 'me')) e.id};
  }

  Future<Set<String>> newPipeline(EquipmentFilterState f) async {
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

  test('the default view hides retired and sold gear', () async {
    const f = EquipmentFilterState();
    expect(await newPipeline(f), await oldPipeline(f));
    expect(await newPipeline(f), isNot(contains('old')));
    expect(await newPipeline(f), isNot(contains('gone')));
  });

  test('every non-service axis selects what the old pipeline did', () async {
    for (final f in [
      const EquipmentFilterState(status: EquipmentStatus.retired),
      const EquipmentFilterState(status: EquipmentStatus.sold),
      const EquipmentFilterState(status: EquipmentStatus.loaned),
      const EquipmentFilterState(type: EquipmentType.wetsuit),
      EquipmentFilterState(
        type: EquipmentType.wetsuit,
        attrConditions: [EquipmentAttrCondition.suitThickness(min: 5)],
      ),
      EquipmentFilterState(
        type: EquipmentType.wetsuit,
        attrConditions: [EquipmentAttrCondition.suitThickness(min: 9)],
      ),
      const EquipmentFilterState(tagIds: {'t1'}),
      const EquipmentFilterState(owner: EquipmentOwnerFilter.mine),
      const EquipmentFilterState(owner: EquipmentOwnerFilter.sharedWithMe),
      const EquipmentFilterState(
        status: EquipmentStatus.retired,
        owner: EquipmentOwnerFilter.mine,
      ),
    ]) {
      expect(await newPipeline(f), await oldPipeline(f), reason: '$f');
    }
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
