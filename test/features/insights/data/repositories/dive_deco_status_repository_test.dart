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

  /// Every dive the fixture holds, plus one deleted before the write.
  const all = {'a', 'b', 'c', 'ghost'};

  test(
    'replaceFor writes the map exactly and leaves unchanged rows alone',
    () async {
      final repo = DiveDecoStatusRepository();
      await repo.replaceFor(
        {'a': true, 'b': false},
        diveIds: all,
        computedAt: 10,
      );
      expect(await repo.verdicts(), {'a': true, 'b': false});

      var ticks = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.diveDecoStatus))
          .listen((_) => ticks++);
      addTearDown(sub.cancel);
      // Same verdicts, later clock: no write, so no filtered list re-query.
      await repo.replaceFor(
        {'a': true, 'b': false},
        diveIds: all,
        computedAt: 20,
      );
      await pumpEventQueue();
      expect(ticks, 0);

      // 'b' goes, 'c' arrives, 'a' changes.
      await repo.replaceFor(
        {'a': false, 'c': true},
        diveIds: all,
        computedAt: 30,
      );
      expect(await repo.verdicts(), {'a': false, 'c': true});
    },
  );

  test('replaceFor rewrites only the dives it names', () async {
    // A rule run on two imported dives refreshes those two and leaves the
    // rest of the logbook's verdicts as the last full pass wrote them.
    final repo = DiveDecoStatusRepository();
    await repo.replaceFor(
      {'a': true, 'b': true, 'c': false},
      diveIds: all,
      computedAt: 10,
    );

    // 'a' changes, 'b' has no verdict now (its computer's data arrived),
    // 'c' is not named and stays.
    await repo.replaceFor({'a': false}, diveIds: {'a', 'b'}, computedAt: 20);
    expect(await repo.verdicts(), {'a': false, 'c': false});
  });

  test('a whole pass leaves alone rows written after it began', () async {
    // A targeted refresh (an import's rules) wrote 'b' while a pass that
    // scanned before the import was still analyzing: that pass knows
    // nothing of 'b' and must not delete or overwrite it.
    final repo = DiveDecoStatusRepository();
    await repo.replaceFor({'a': true}, diveIds: all, computedAt: 10);
    await repo.replaceFor({'b': true}, diveIds: {'b'}, computedAt: 30);

    await repo.replaceFor(
      {'a': false},
      diveIds: all,
      computedAt: 40,
      keepWrittenAfter: 20,
    );
    expect(await repo.verdicts(), {'a': false, 'b': true});
  });

  test('write stamps never tie, however fast they are taken', () {
    // A pass that begins and a targeted refresh that writes in the same
    // instant must still be ordered, or the pass would treat the newer row
    // as one it may replace.
    final stamps = [for (var i = 0; i < 1000; i++) nextDecoWriteStamp()];
    for (var i = 1; i < stamps.length; i++) {
      expect(stamps[i], greaterThan(stamps[i - 1]));
    }
  });

  test('a verdict for a dive deleted mid-analysis is skipped', () async {
    // The analysis judged 'ghost', then it was deleted before the write:
    // the cache keeps the live dives instead of failing the whole write on
    // the dives foreign key.
    final repo = DiveDecoStatusRepository();
    await repo.replaceFor(
      {'a': true, 'ghost': false},
      diveIds: all,
      computedAt: 10,
    );
    expect(await repo.verdicts(), {'a': true});
  });
}
