import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/dive_deco_status_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['a', 'b', 'c']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: const Value(now),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test(
    'replaceAll writes the map exactly and leaves unchanged rows alone',
    () async {
      final repo = DiveDecoStatusRepository();
      await repo.replaceAll({'a': true, 'b': false}, computedAt: 10);
      expect(await repo.verdicts(), {'a': true, 'b': false});

      var ticks = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.diveDecoStatus))
          .listen((_) => ticks++);
      addTearDown(sub.cancel);
      // Same verdicts, later clock: no write, so no filtered list re-query.
      await repo.replaceAll({'a': true, 'b': false}, computedAt: 20);
      await pumpEventQueue();
      expect(ticks, 0);

      // 'b' goes, 'c' arrives, 'a' changes.
      await repo.replaceAll({'a': false, 'c': true}, computedAt: 30);
      expect(await repo.verdicts(), {'a': false, 'c': true});
    },
  );

  test('a verdict for a dive deleted mid-analysis is skipped', () async {
    // The analysis judged 'ghost', then it was deleted before the write:
    // the cache keeps the live dives instead of failing the whole write on
    // the dives foreign key.
    final repo = DiveDecoStatusRepository();
    await repo.replaceAll({'a': true, 'ghost': false}, computedAt: 10);
    expect(await repo.verdicts(), {'a': true});
  });
}
