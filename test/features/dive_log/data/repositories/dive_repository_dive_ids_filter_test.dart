import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3805: a chart row can hold most of a logbook, so the list and its
/// count must take a very long list of dive ids.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a row of 5,000 dive ids reaches the list and its count', () async {
    final ids = [for (var i = 0; i < 5000; i++) 'dive-$i'];
    await db.batch((batch) {
      batch.insertAll(db.dives, [
        for (final id in ids)
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    });
    final filter = DiveFilterState(diveIds: ids);

    expect(await repo.getDiveCount(filter: filter), 5000);
    expect(await repo.getDiveSummaries(filter: filter), hasLength(50));
  });
}
