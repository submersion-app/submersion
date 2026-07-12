import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> insertDive(String id, int dateTimeMs, {int? number}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(dateTimeMs),
            diveNumber: Value(number),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  test(
    'returns ids in the same order as getDiveSummaries (date desc)',
    () async {
      await insertDive('a', 1000, number: 1);
      await insertDive('b', 3000, number: 3);
      await insertDive('c', 2000, number: 2);

      const sort = SortState(
        field: DiveSortField.date,
        direction: SortDirection.descending,
      );

      final ids = await repository.getOrderedDiveIds(sort: sort);
      final summaries = await repository.getDiveSummaries(
        sort: sort,
        limit: 1000,
      );

      expect(ids, summaries.map((s) => s.id).toList());
      expect(ids, ['b', 'c', 'a']); // newest first
    },
  );

  test('respects sort direction (date asc)', () async {
    await insertDive('a', 1000);
    await insertDive('b', 3000);
    await insertDive('c', 2000);

    final ids = await repository.getOrderedDiveIds(
      sort: const SortState(
        field: DiveSortField.date,
        direction: SortDirection.ascending,
      ),
    );
    expect(ids, ['a', 'c', 'b']);
  });
}
