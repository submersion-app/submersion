import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A sitting is about the record it was opened on, however many other
/// records it wrote along the way (issue #4527): its History entry is titled
/// by that record and found in its History, and so is the entry that
/// reverts it.
void main() {
  late AppDatabase db;
  final repository = ChangeLogRepository();

  Future<String> inSitting(
    Future<void> Function() body, {
    String? label,
  }) async {
    late String operationId;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      label:
          label ??
          RecordEditLabel.encode(
            table: 'dives',
            id: 'dive',
            cardIds: ['documents', 'notes'],
          ),
      body: () async {
        operationId = ChangeLogScope.currentOperationId!;
        await body();
      },
    );
    return operationId;
  }

  Future<Map<String, Object?>> operation(String id) async =>
      (await db
              .customSelect(
                'SELECT * FROM change_log_operations WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .data;

  Future<List<String>> operationIds() async => [
    for (final row
        in await db
            .customSelect('SELECT id FROM change_log_operations ORDER BY id')
            .get())
      row.read<String>('id'),
  ];

  Future<void> editNotes() => db.customStatement(
    "UPDATE dives SET notes = 'Current' WHERE id = 'dive'",
  );

  Future<void> fileDocument() => db.customStatement(
    "UPDATE documents SET dive_id = 'dive' WHERE id = 'doc'",
  );

  Future<void> copyAltitude(String site) => db.customStatement(
    'UPDATE dive_sites SET altitude = 512 WHERE id = ?',
    [site],
  );

  void expectAboutTheDive(Map<String, Object?> row) {
    expect(row['root_table'], 'dives');
    expect(row['root_id'], 'dive');
    expect(row['root_label'], 'Reef');
    expect(row['root_ordinal'], 12);
    expect(row['diver_id'], 'me');
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDiver(db, 'them');
    for (final (id, owner) in [('site', 'me'), ('shared', 'them')]) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id == 'site' ? 'Reef' : 'Wall',
              createdAt: 0,
              updatedAt: 0,
              diverId: Value(owner),
            ),
          );
    }
    await db.customStatement(
      'INSERT INTO site_shares (id, site_id, diver_id, created_at) '
      "VALUES ('s1', 'shared', 'me', 0)",
    );
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db.customStatement(
      "UPDATE dives SET dive_number = 12, site_id = 'site' WHERE id = 'dive'",
    );
    await db.customStatement(
      'INSERT INTO documents (id, diver_id, type, created_at, updated_at) '
      "VALUES ('doc', 'me', 'other', 0, 0)",
    );
    await repository.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    await clearLog(db);
  });
  tearDown(tearDownTestDatabase);

  test(
    'a sitting that changes the dive and the site is about the dive',
    () async {
      final id = await inSitting(() async {
        await editNotes();
        await copyAltitude('site');
      });
      await repository.settleAll();

      expectAboutTheDive(await operation(id));
      final events = await logEvents(db);
      expect(
        {for (final e in events) e['root_table']},
        {'dives', 'dive_sites'},
      );
    },
  );

  test('a sitting that only files a document is about the dive', () async {
    final id = await inSitting(fileDocument);
    await repository.settleAll();

    expectAboutTheDive(await operation(id));
    expect((await logEvents(db)).single['root_table'], 'documents');
  });

  test('it stays about the dive across settle passes', () async {
    final id = await inSitting(() async {
      await fileDocument();
      await copyAltitude('site');
    });
    final settler = ChangeLogSettler(db);
    expect(await settler.settle(batch: 1), 1);
    expect(await settler.settle(batch: 1), 1);

    expectAboutTheDive(await operation(id));
  });

  test(
    'a sitting whose dive change cancelled out keeps the dive as root',
    () async {
      final id = await inSitting(() async {
        await db.customStatement(
          'INSERT INTO dive_custom_fields (id, dive_id, field_key, created_at) '
          "VALUES ('f', 'dive', 'k', 0)",
        );
        await db.customStatement(
          "DELETE FROM dive_custom_fields WHERE id = 'f'",
        );
        await fileDocument();
      });
      await repository.settleAll();

      expectAboutTheDive(await operation(id));
    },
  );

  test('a revert of a pinned sitting is about the same dive, and so is the '
      'revert of that revert', () async {
    final id = await inSitting(fileDocument);
    await repository.settleAll();
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});

    final revert = (await service.execute(
      await service.planOperation(id),
    )).operationId!;
    await repository.settleAll();
    expectAboutTheDive(await operation(revert));

    final redo = (await service.execute(
      await service.planOperation(revert),
    )).operationId!;
    await repository.settleAll();
    expectAboutTheDive(await operation(redo));
  });

  test('settling a revert writes nothing to the sitting it reverts', () async {
    final id = await inSitting(fileDocument);
    await repository.settleAll();
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    final revert = (await service.execute(
      await service.planOperation(id),
    )).operationId!;
    await db.customStatement('CREATE TEMP TABLE written (id TEXT)');
    await db.customStatement(
      'CREATE TEMP TRIGGER count_written AFTER UPDATE ON '
      'change_log_operations BEGIN INSERT INTO written VALUES (NEW.id); END',
    );

    await repository.settleAll();

    final written = await db.customSelect('SELECT id FROM written').get();
    final ids = written.map((row) => row.read<String>('id')).toSet();
    expect(ids, contains(revert));
    expect(ids, isNot(contains(id)));
  });

  // An agent labels its change set with free text, which may happen to read
  // like a sitting's label; only a diver's own sitting is pinned.
  test('an agent change set labelled like a sitting is not pinned', () async {
    late String id;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.agent,
      label: RecordEditLabel.encode(
        table: 'dives',
        id: 'dive',
        cardIds: ['notes'],
      ),
      body: () async {
        id = ChangeLogScope.currentOperationId!;
        await copyAltitude('site');
      },
    );
    await repository.settleAll();

    final row = await operation(id);
    expect(row['root_table'], 'dive_sites');
    expect(row['root_id'], 'site');
  });

  test('a sitting labelled the earlier way is filed as before', () async {
    final id = await inSitting(() async {
      await editNotes();
      await copyAltitude('site');
    }, label: 'record_edit:dives:notes');
    await repository.settleAll();

    expect((await operation(id))['root_id'], isNull);
  });

  // One entry about the dive, whoever owns the other records it wrote: the
  // site's owner sees the site's rows of it (ChangeLogRepository.getFeed).
  test("a sitting's write to another diver's shared site stays in its one "
      'entry', () async {
    final id = await inSitting(() async {
      await editNotes();
      await copyAltitude('shared');
    });
    await repository.settleAll();

    expectAboutTheDive(await operation(id));
    expect(await operationIds(), [id]);
    expect({for (final e in await logEvents(db)) e['operation_id']}, {id});
  });

  test("a sitting whose only write is to another diver's shared site is "
      'about the dive', () async {
    final id = await inSitting(() => copyAltitude('shared'));
    await repository.settleAll();

    expectAboutTheDive(await operation(id));
    expect(await operationIds(), [id]);
  });

  test("reverting the sitting puts another diver's shared site back, and "
      'the whole entry reads as reverted', () async {
    final id = await inSitting(() async {
      await editNotes();
      await copyAltitude('shared');
    });
    await repository.settleAll();
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});

    final revert = (await service.execute(
      await service.planOperation(id),
    )).operationId;
    await repository.settleAll();

    final site = await db
        .customSelect("SELECT altitude FROM dive_sites WHERE id = 'shared'")
        .getSingle();
    expect(site.data['altitude'], isNull);
    expect((await operation(id))['reverted_by_id'], revert);
  });

  test('an unscoped save is untouched', () async {
    await editNotes();
    await repository.settleAll();

    final row =
        (await db
                .customSelect('SELECT * FROM change_log_operations')
                .getSingle())
            .data;
    expect(row['label'], isNull);
    expect(row['root_id'], 'dive');
  });
}
