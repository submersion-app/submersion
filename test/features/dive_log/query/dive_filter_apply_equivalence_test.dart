import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

import '../../../helpers/test_database.dart';
import 'dive_query_fixture.dart';

/// Proves the lowering before apply() is deleted (Task 15): for every axis
/// the old in-memory result equals the compiled SQL result.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> viaSql(DiveFilterState f) async {
    final q = compileDiveFilter(f, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ?'
          '${q.isEmpty ? '' : ' AND ${q.where}'}',
          variables: [
            const Variable<String>('me'),
            ...q.params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<Set<String>> viaApply(DiveFilterState f) async {
    final all = await repo.getAllDives(diverId: 'me');
    return f.apply(all).map((d) => d.id).toSet();
  }

  final cases = <String, DiveFilterState>{
    'dates': DiveFilterState(
      startDate: DateTime(2025, 2, 1),
      endDate: DateTime(2025, 3, 14),
    ),
    'weekdays': const DiveFilterState(weekdays: [5, 6]),
    'site': const DiveFilterState(siteId: 's1'),
    'depth': const DiveFilterState(minDepth: 20, maxDepth: 30),
    'favorites': const DiveFilterState(favoritesOnly: true),
    'no buddy': const DiveFilterState(noBuddyOnly: true),
    'buddy name': const DiveFilterState(buddyNameFilter: 'an, bo'),
    'buddy name single': const DiveFilterState(buddyNameFilter: 'an'),
    'buddy id': const DiveFilterState(buddyId: 'b1'),
    'equipment': const DiveFilterState(equipmentIds: ['g_wet']),
    'ids': const DiveFilterState(diveIds: ['d1', 'd9']),
    'rating': const DiveFilterState(minRating: 1),
    'bottom time': const DiveFilterState(
      minBottomTimeMinutes: 10,
      maxBottomTimeMinutes: 50,
    ),
    'custom field': const DiveFilterState(customFieldKey: 'x'),
    'combined': DiveFilterState(
      startDate: DateTime(2025, 1, 1),
      noBuddyOnly: true,
      minDepth: 10,
    ),
  };

  for (final entry in cases.entries) {
    test('apply() and SQL agree: ${entry.key}', () async {
      expect(
        await viaSql(entry.value),
        equals(await viaApply(entry.value)),
        reason: entry.key,
      );
    });
  }

  test('the SQL-only axes match their old id-set methods', () async {
    expect(
      await viaSql(const DiveFilterState(decoOnly: true)),
      await repo.getDiveIdsWithDecoSignal(wantDeco: true, diverId: 'me'),
    );
    final cond = [EquipmentAttrCondition.suitThickness(min: 1)];
    expect(
      await viaSql(DiveFilterState(equipmentAttrConditions: cond)),
      await repo.getDiveIdsMatchingEquipmentAttrs(cond, diverId: 'me'),
    );
  });
}
