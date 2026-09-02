import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  Future<void> insert(
    String id, {
    bool excluded = false,
    bool planned = false,
    String? diverId,
  }) async {
    final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at),
            excludedFromStats: Value(excluded),
            isPlanned: Value(planned),
            diverId: Value(diverId),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('counts zero when nothing is excluded', () async {
    await insert('a');
    expect(await repo.countExcludedDives(), 0);
  });

  test('counts only dives the diver excluded', () async {
    await insert('a');
    await insert('b', excluded: true);
    await insert('c', excluded: true);
    expect(await repo.countExcludedDives(), 2);
  });

  test('does not count planned dives', () async {
    await insert('a');
    await insert('planned', planned: true);
    expect(
      await repo.countExcludedDives(),
      0,
      reason:
          'the footnote explains the diver\'s own choice back to them; a '
          'planned dive is not something they chose to exclude, so counting '
          'it here would confuse rather than clarify',
    );
  });
}
