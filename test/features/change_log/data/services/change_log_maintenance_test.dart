import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_preferences.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_maintenance.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  final repository = ChangeLogRepository();
  var now = DateTime(2026, 10, 30, 12);

  ChangeLogMaintenance maintenance() => ChangeLogMaintenance(
    preferences: ChangeLogPreferences(prefs),
    prefs: prefs,
    now: () => now,
  );

  /// Files one settled edit, ended [monthsAgo] before [now].
  Future<String> editAged(String notes, int monthsAgo) async {
    await db.customStatement(
      "UPDATE dives SET notes = '$notes' WHERE id = 'dive'",
    );
    await repository.settleAll();
    final ended = DateTime(
      now.year,
      now.month - monthsAgo,
      now.day,
    ).millisecondsSinceEpoch;
    final row = await db
        .customSelect(
          'SELECT id FROM change_log_operations '
          'ORDER BY last_event_id DESC LIMIT 1',
        )
        .getSingle();
    final id = row.read<String>('id');
    await db.customStatement(
      'UPDATE change_log_operations SET ended_at = ? WHERE id = ?',
      [ended, id],
    );
    return id;
  }

  Future<List<String>> operations() async => [
    for (final r
        in await db.customSelect('SELECT id FROM change_log_operations').get())
      r.read<String>('id'),
  ];

  Future<int> fieldCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM change_log_fields')
        .getSingle();
    return row.read<int>('c');
  }

  setUp(() async {
    now = DateTime(2026, 10, 30, 12);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDiver(db, 'other');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  test('twelve months is the default', () {
    expect(ChangeLogPreferences(prefs).retentionMonths, 12);
  });

  test('the retention choice is saved', () async {
    await ChangeLogPreferences(prefs).setRetentionMonths(3);

    expect(ChangeLogPreferences(prefs).retentionMonths, 3);
  });

  test('older operations go with their fields', () async {
    await editAged('Old', 13);
    final kept = await editAged('Recent', 11);

    final removed = await maintenance().prune();

    expect(removed, 1);
    expect(await operations(), [kept]);
    expect(await fieldCount(), 1);
    expect(await logEvents(db), hasLength(1));
  });

  test('a shorter retention prunes more', () async {
    await editAged('Old', 4);
    await ChangeLogPreferences(prefs).setRetentionMonths(3);

    expect(await maintenance().prune(), 1);
  });

  test('forever prunes nothing', () async {
    await editAged('Old', 60);
    await ChangeLogPreferences(prefs).setRetentionMonths(0);

    expect(await maintenance().prune(), 0);
    expect(await operations(), hasLength(1));
  });

  test('pruning works through batches', () async {
    await editAged('One', 20);
    await db.customStatement(
      "UPDATE dives SET notes = 'Spacer' WHERE id = 'dive'",
    );
    await editAged('Two', 20);
    await editAged('Three', 20);

    final removed = await maintenance().prune(batch: 1);

    expect(removed, 3);
  });

  test('pruneIfDue runs at most daily', () async {
    await maintenance().pruneIfDue();
    await editAged('Old', 13);

    expect(await maintenance().pruneIfDue(), 0);
    expect(await operations(), hasLength(1));

    now = now.add(const Duration(hours: 25));
    expect(await maintenance().pruneIfDue(), 1);
  });

  test('a clock moved back does not stop pruning', () async {
    await prefs.setInt(
      ChangeLogMaintenance.lastPrunedKey,
      now.add(const Duration(days: 400)).millisecondsSinceEpoch,
    );
    await editAged('Old', 13);

    expect(await maintenance().pruneIfDue(), 1);
  });

  test('pruning leaves unsettled events alone', () async {
    final old = await editAged('Old', 13);
    await db.customStatement(
      'UPDATE change_log_events SET settled = 0 WHERE operation_id = ?',
      [old],
    );

    expect(await maintenance().prune(), 0);
    expect(await logEvents(db), hasLength(1));
  });

  test('deleting a diver deletes their entries', () async {
    await insertDive(db, 'theirs', diverId: 'other', notes: 'Flat');
    await db.customStatement(
      "UPDATE dives SET notes = 'Mine' WHERE id = 'dive'",
    );
    await repository.settleAll();
    await db.customStatement(
      "UPDATE dives SET notes = 'Changed' WHERE id = 'theirs'",
    );

    // Nothing settled since that last edit: it must not outlive the diver
    // with no owner, where every profile would see it.
    await DiverRepository().deleteDiverWithReassignment('other');
    await repository.settleAll();

    final rows = await db.select(db.changeLogOperations).get();
    expect(rows.map((o) => o.diverId).toSet(), {'me'});
    expect(
      await logEvents(db),
      isNot(anyElement(containsPair('record_id', 'theirs'))),
    );
  });

  test('a failure clearing the log does not fail the delete', () async {
    await db.customStatement('DROP TABLE change_log_operations');

    await expectLater(
      DiverRepository().deleteDiverWithReassignment('other'),
      completes,
    );
  });
}
