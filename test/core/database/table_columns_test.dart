import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/table_columns.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('CREATE TABLE scratch (id TEXT, extra TEXT)');
  });

  tearDown(() => db.close());

  test('tableColumnNames lists a table, and nothing for one absent', () async {
    expect(await tableColumnNames(db, 'scratch'), {'id', 'extra'});
    expect(await tableColumnNames(db, 'absent'), isEmpty);
  });

  test('dropColumnIfStillPresent drops the column', () async {
    await dropColumnIfStillPresent(db, 'scratch', 'extra');
    expect(await tableColumnNames(db, 'scratch'), {'id'});
  });

  test('dropColumnIfStillPresent accepts a column another connection '
      'already dropped', () async {
    // The UI and Workmanager isolates open the file at once and migrations
    // take no lock across them, so both can see the column and race to
    // drop it (PR #3812 review).
    await db.customStatement('ALTER TABLE scratch DROP COLUMN extra');
    await dropColumnIfStillPresent(db, 'scratch', 'extra');
    expect(await tableColumnNames(db, 'scratch'), {'id'});
  });

  test('addColumnIfStillMissing adds the column', () async {
    await addColumnIfStillMissing(db, 'scratch', 'more', 'INTEGER');
    expect(await tableColumnNames(db, 'scratch'), {'id', 'extra', 'more'});
  });

  test('addColumnIfStillMissing accepts a column another connection '
      'already added', () async {
    // The same race as the drop: both isolates read the column as missing
    // and race to add it.
    await addColumnIfStillMissing(db, 'scratch', 'extra', 'TEXT');
    expect(await tableColumnNames(db, 'scratch'), {'id', 'extra'});
  });

  test('addColumnIfStillMissing still reports any other failure', () async {
    await expectLater(
      addColumnIfStillMissing(db, 'absent', 'more', 'INTEGER'),
      throwsA(anything),
    );
  });

  test('dropColumnIfStillPresent reports a drop a view blocks, though '
      'SQLite words it as a missing column', () async {
    await db.customStatement(
      'CREATE VIEW scratch_view AS SELECT extra FROM scratch',
    );
    await expectLater(
      dropColumnIfStillPresent(db, 'scratch', 'extra'),
      throwsA(anything),
    );
    expect(await tableColumnNames(db, 'scratch'), {'id', 'extra'});
  });

  test('dropColumnIfStillPresent still reports any other failure', () async {
    await expectLater(
      dropColumnIfStillPresent(db, 'absent', 'extra'),
      throwsA(anything),
    );
  });
}
