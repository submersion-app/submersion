import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';

import '../../../helpers/test_database.dart';
import '../../database/change_log/change_log_support.dart';

Future<void> _edit(AppDatabase db, String notes) =>
    db.customStatement("UPDATE dives SET notes = '$notes' WHERE id = 'dive'");

Future<Map<String, Object?>> _context(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT * FROM change_log_context')
      .getSingle();
  return row.data;
}

Future<List<ChangeLogOperationRow>> _operations(AppDatabase db) =>
    db.select(db.changeLogOperations).get();

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await insertDiver(db, 'diver');
    await insertDive(db, 'dive', diverId: 'diver');
    await clearLog(db);
  });
  tearDown(() => db.close());

  test('events inside a scope carry its operation', () async {
    final result = await ChangeLogScope.run(
      db,
      source: ChangeLogSource.import,
      label: 'Shearwater Perdix',
      body: () async {
        await _edit(db, 'Imported');
        return 7;
      },
    );

    expect(result, 7);
    final operation = (await _operations(db)).single;
    expect(operation.source, 'import');
    expect(operation.label, 'Shearwater Perdix');
    expect(operation.closed, isTrue);
    expect((await logEvents(db)).single['operation_id'], operation.id);
    expect((await _context(db))['operation_id'], isNull);
  });

  test('a write after a scope has no operation', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () async {},
    );

    await _edit(db, 'After');

    expect((await logEvents(db)).single['operation_id'], isNull);
  });

  test('a scope records the peer device and what it reverts', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.sync,
      deviceId: 'peer',
      revertOfId: 'original',
      body: () async {},
    );

    final operation = (await _operations(db)).single;
    expect(operation.deviceId, 'peer');
    expect(operation.revertOfId, 'original');
  });

  test('a nested scope restores the outer one', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.import,
      body: () async {
        await ChangeLogScope.run(
          db,
          source: ChangeLogSource.rule,
          body: () => _edit(db, 'Inner'),
        );
        await _edit(db, 'Outer');
      },
    );

    final operations = await _operations(db);
    final byId = {for (final o in operations) o.id: o.source};
    final events = await logEvents(db);
    expect(byId[events.first['operation_id']], 'rule');
    expect(byId[events.last['operation_id']], 'import');
  });

  test('a bulk action outside a scope is its own manual operation', () async {
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.bulkEdit,
      body: () => _edit(db, 'Bulk'),
    );

    final operation = (await _operations(db)).single;
    expect(operation.source, 'manual');
    expect(operation.label, ChangeLogLabels.bulkEdit);
    expect((await logEvents(db)).single['operation_id'], operation.id);
  });

  test('a bulk action inside a scope joins it', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.revert,
      body: () => ChangeLogScope.bulk(
        db,
        label: ChangeLogLabels.bulkDelete,
        body: () => _edit(db, 'Joined'),
      ),
    );

    final operation = (await _operations(db)).single;
    expect(operation.source, 'revert');
    expect((await logEvents(db)).single['operation_id'], operation.id);
  });

  test('a null database runs the body with no log', () async {
    expect(
      await ChangeLogScope.run(
        null,
        source: ChangeLogSource.import,
        body: () async => 'ran',
      ),
      'ran',
    );
    expect(await _operations(db), isEmpty);
  });

  test('a summary alone records one entry', () async {
    await ChangeLogScope.summary(
      db,
      label: ChangeLogLabels.libraryRestored,
      source: ChangeLogSource.system,
    );

    final operation = (await _operations(db)).single;
    expect(operation.label, ChangeLogLabels.libraryRestored);
    expect(operation.summaryCount, 0);
  });

  test('an outer scope that already ended is not restored', () async {
    final outerDone = ChangeLogScope.run(
      db,
      source: ChangeLogSource.import,
      body: () async {},
    );
    late Future<void> inner;
    inner = ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () => outerDone,
    );
    await inner;

    expect((await _context(db))['operation_id'], isNull);
  });

  test('an expired scope stops labelling', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.import,
      body: () async {
        await db.customStatement(
          'UPDATE change_log_context SET scope_expires_at = 1',
        );
        await _edit(db, 'Late');
      },
    );

    expect((await logEvents(db)).single['operation_id'], isNull);
  });

  test('a suppressed body logs one summary and no rows', () async {
    final result = await ChangeLogScope.suppressed(
      db,
      label: 'Library adopted',
      source: ChangeLogSource.system,
      summaryCount: (_) => 412,
      body: () async {
        await _edit(db, 'Adopted');
        return 'done';
      },
    );

    expect(result, 'done');
    expect(await logEvents(db), isEmpty);
    final operation = (await _operations(db)).single;
    expect(operation.source, 'system');
    expect(operation.label, 'Library adopted');
    expect(operation.summaryCount, 412);
    expect(operation.closed, isTrue);
    expect((await _context(db))['suppressed_until'], isNull);
  });

  test('a summary takes the newest event id, so it sorts first', () async {
    await _edit(db, 'Before');
    final newest = (await logEvents(db)).last['id'];

    await ChangeLogScope.suppressed(
      db,
      label: 'Library restored',
      source: ChangeLogSource.system,
      body: () async {},
    );

    expect((await _operations(db)).single.lastEventId, newest);
  });

  test('an expired suppression lets recording resume', () async {
    await ChangeLogScope.suppressed(
      db,
      label: 'Library adopted',
      source: ChangeLogSource.system,
      body: () async {
        await db.customStatement(
          'UPDATE change_log_context SET suppressed_until = 1',
        );
        await _edit(db, 'Seen');
      },
    );

    expect(await logEvents(db), hasLength(1));
  });

  test('a failed suppressed body logs no summary and clears', () async {
    await expectLater(
      ChangeLogScope.suppressed(
        db,
        label: 'Library adopted',
        source: ChangeLogSource.system,
        body: () async => throw StateError('no'),
      ),
      throwsStateError,
    );

    expect(await _operations(db), isEmpty);
    expect((await _context(db))['suppressed_until'], isNull);
  });

  test('the body still runs when the context write fails', () async {
    await db.customStatement('DROP TABLE change_log_operations');
    await db.customStatement('DROP TABLE change_log_context');

    final result = await ChangeLogScope.run(
      db,
      source: ChangeLogSource.import,
      body: () async => 'ran',
    );
    final suppressed = await ChangeLogScope.suppressed(
      db,
      label: 'Library adopted',
      source: ChangeLogSource.system,
      body: () async => 'ran too',
    );

    expect(result, 'ran');
    expect(suppressed, 'ran too');
  });

  test('a throwing body closes the operation and rethrows', () async {
    await expectLater(
      ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () async => throw StateError('no'),
      ),
      throwsStateError,
    );

    expect((await _operations(db)).single.closed, isTrue);
    expect((await _context(db))['operation_id'], isNull);
  });

  test('an open during a scope leaves it alone', () async {
    final dir = Directory.systemTemp.createTempSync('change_log_scope');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'submersion.db'));
    final first = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    addTearDown(first.close);

    await ChangeLogScope.run(
      first,
      source: ChangeLogSource.import,
      body: () async {
        final held = await _context(first);
        final second = AppDatabase(
          NativeDatabase(file, setup: registerAppSqlFunctions),
        );
        await second.customSelect('SELECT 1').get();
        await second.close();
        expect(await _context(first), held);
        expect(held['operation_id'], isNotNull);
      },
    );
  });
}
