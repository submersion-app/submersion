import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';

import '../../../helpers/test_database.dart';

/// Every record's editing sitting is written in one change log operation
/// labelled with the record and its cards, and in one transaction, so a
/// failure leaves nothing half saved (issue #4527).
void main() {
  late AppDatabase db;
  final changeLog = ChangeLogRepository();

  Future<String?> name() async =>
      (await db
              .customSelect(
                'SELECT name FROM dive_sites WHERE id = ?',
                variables: const [Variable<String>('s1')],
              )
              .getSingleOrNull())
          ?.read<String>('name');

  Future<String?> city() async =>
      (await db
              .customSelect(
                'SELECT city FROM dive_sites WHERE id = ?',
                variables: const [Variable<String>('s1')],
              )
              .getSingle())
          .read<String?>('city');

  Future<void> writeName(String value) => db.customUpdate(
    'UPDATE dive_sites SET name = ? WHERE id = ?',
    variables: [Variable<String>(value), const Variable<String>('s1')],
  );

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({String before, String after})?> save({
    String Function(String stored)? apply,
    Future<String?> Function()? read,
    Iterable<String> cards = const ['notes'],
    Future<void> Function(String stored, String merged)? write,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) => writeRecordSitting<String>(
    table: 'dive_sites',
    recordId: 's1',
    changedCardIds: cards,
    read: read ?? name,
    apply: apply ?? (stored) => stored,
    write: write ?? (_, merged) => writeName(merged),
    writeFirst: writeFirst,
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWriteIsAChange,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Lake',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    // The row above is setup, not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('one operation labelled with the record and its cards', () async {
    final result = await save(
      apply: (_) => 'Pond',
      cards: const ['notes', 'description'],
    );

    expect(await name(), 'Pond');
    expect(result, (before: 'Lake', after: 'Pond'));
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:dive_sites:s1:description,notes');
  });

  test('nothing changed writes nothing', () async {
    final result = await save();

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a held change alone is written', () async {
    final result = await save(
      alsoWriteIsAChange: true,
      alsoWrite: () =>
          db.customUpdate("UPDATE dive_sites SET city = 'X' WHERE id = 's1'"),
    );

    expect(await city(), 'X');
    expect(result, (before: 'Lake', after: 'Lake'));
  });

  test('writeFirst runs before the record and alsoWrite after', () async {
    final order = <String>[];
    await save(
      apply: (_) => 'Pond',
      writeFirst: () async => order.add('first'),
      write: (_, merged) async {
        order.add('write');
        await writeName(merged);
      },
      alsoWrite: () async => order.add('also'),
    );

    expect(order, ['first', 'write', 'also']);
  });

  test('a failing held write rolls everything back', () async {
    await expectLater(
      save(
        apply: (_) => 'Pond',
        alsoWrite: () async => throw StateError('refused'),
      ),
      throwsStateError,
    );

    expect(await name(), 'Lake');
  });

  // A write inside the sitting tells sync of its change; the sitting tells
  // it once it has committed, and not at all when it rolls back, so nothing
  // reacts to rows that were never saved.
  group('sync is told', () {
    late int told;
    setUp(() {
      told = 0;
      final listening = SyncEventBus.changes.listen((_) => told++);
      addTearDown(listening.cancel);
    });

    Future<void> delivered() => Future<void>.delayed(Duration.zero);

    test('once, after the commit', () async {
      var toldInside = -1;
      await save(
        apply: (_) => 'Pond',
        write: (_, merged) async {
          await writeName(merged);
          SyncEventBus.notifyLocalChange();
          SyncEventBus.notifyLocalChange();
        },
        alsoWrite: () async {
          await delivered();
          toldInside = told;
        },
      );
      await delivered();

      expect(toldInside, 0);
      expect(told, 1);
    });

    test('not at all when the sitting rolls back', () async {
      await expectLater(
        save(
          apply: (_) => 'Pond',
          write: (_, merged) async {
            await writeName(merged);
            SyncEventBus.notifyLocalChange();
          },
          alsoWrite: () async => throw StateError('refused'),
        ),
        throwsStateError,
      );
      await delivered();

      expect(told, 0);
    });

    test('by work the sitting started, once it has ended', () async {
      final later = Completer<void>();
      await save(
        apply: (_) => 'Pond',
        write: (_, merged) async {
          await writeName(merged);
          // A timer started during the sitting outlives it.
          Timer(const Duration(milliseconds: 1), () {
            SyncEventBus.notifyLocalChange();
            later.complete();
          });
        },
      );
      await later.future;
      await delivered();

      // One for the committed save, one from the timer it outlived.
      expect(told, 2);
    });

    // A repository write told to stay quiet inside a sitting sends no
    // notice of its own; the sitting still tells sync it saved.
    test(
      'once after the commit, by a save whose writes told it nothing',
      () async {
        await save(apply: (_) => 'Pond');
        await delivered();

        expect(told, 1);
      },
    );

    test('not by a save that changed nothing', () async {
      await save();
      await delivered();

      expect(told, 0);
    });

    test('outside a sitting, at once', () async {
      SyncEventBus.notifyLocalChange();
      await delivered();

      expect(told, 1);
    });
  });

  test('a record that has gone throws', () async {
    await expectLater(
      save(read: () async => null),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('dive_sites s1 no longer exists'),
        ),
      ),
    );
  });

  /// A new record's sitting (issue #4527, phase 3, plan 11): the row, then
  /// the sitting's held writes, in one operation, or nothing at all.
  group('createRecordSitting', () {
    Future<String?> nameOf(String id) async =>
        (await db
                .customSelect(
                  'SELECT name FROM dive_sites WHERE id = ?',
                  variables: [Variable<String>(id)],
                )
                .getSingleOrNull())
            ?.read<String>('name');

    Future<void> insertSite(String id, String name) => db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: name,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    Future<String> create({
      String id = 'n1',
      Future<void> Function()? alsoWrite,
      Future<String?> Function()? readBack,
    }) => createRecordSitting<String>(
      table: 'dive_sites',
      recordId: id,
      changedCardIds: const ['header', 'notes'],
      isStored: () async => await nameOf(id) != null,
      insert: () => insertSite(id, 'Blue Hole'),
      alsoWrite: alsoWrite,
      readBack: readBack ?? () => nameOf(id),
      created: 'as created',
    );

    test('sync is told once after the commit, though its writes told it '
        'nothing, and not when it rolls back', () async {
      var told = 0;
      final listening = SyncEventBus.changes.listen((_) => told++);
      addTearDown(listening.cancel);

      await create();
      await Future<void>.delayed(Duration.zero);
      expect(told, 1);

      await expectLater(
        create(id: 'n2', alsoWrite: () async => throw StateError('refused')),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(told, 1);
    });

    test('creates the record with its id, as one History entry', () async {
      expect(await create(), 'Blue Hole');
      expect(await nameOf('n1'), 'Blue Hole');
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['source'], 'manual');
      expect(ops.single['label'], 'record_edit:dive_sites:n1:header,notes');
    });

    test('held writes run after the row, in the same entry', () async {
      String? seen;
      await create(
        alsoWrite: () async {
          seen = await nameOf('n1');
          await db.customUpdate(
            "UPDATE dive_sites SET city = 'Dahab' WHERE id = 'n1'",
          );
        },
      );
      expect(seen, 'Blue Hole');
      final row = await db
          .customSelect("SELECT city FROM dive_sites WHERE id = 'n1'")
          .getSingle();
      expect(row.read<String?>('city'), 'Dahab');
      expect(await operations(), hasLength(1));
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        create(alsoWrite: () async => throw StateError('refused')),
        throwsStateError,
      );
      expect(await nameOf('n1'), isNull);
      expect(await operations(), isEmpty);
    });

    test('an empty id or one already stored is refused', () async {
      await expectLater(create(id: ''), throwsStateError);
      await expectLater(create(id: 's1'), throwsStateError);
      expect(await nameOf('s1'), 'Lake');
      expect(await operations(), isEmpty);
    });

    test('the read-back copy is returned, else the created one', () async {
      expect(await create(readBack: () async => null), 'as created');
    });
  });

  group('relabelRecordSitting', () {
    test(
      'a sitting relabelled in its body is labelled with the new id',
      () async {
        await runRecordSitting<void>(
          table: 'dive_sites',
          recordId: 'a',
          changedCardIds: const [],
          body: () async {
            await writeName('Pond');
            await relabelRecordSitting(table: 'dive_sites', recordId: 's1');
          },
        );

        final ops = await operations();
        expect(ops, hasLength(1));
        expect(ops.single['label'], 'record_edit:dive_sites:s1:');
        expect(await name(), 'Pond');
      },
    );

    test('a relabelled sitting that throws leaves no operation', () async {
      await expectLater(
        runRecordSitting<void>(
          table: 'dive_sites',
          recordId: 'a',
          changedCardIds: const [],
          body: () async {
            await writeName('Pond');
            await relabelRecordSitting(table: 'dive_sites', recordId: 's1');
            throw StateError('refused');
          },
        ),
        throwsStateError,
      );

      expect(await operations(), isEmpty);
      expect(await name(), 'Lake');
    });

    test('relabelling outside a sitting does nothing', () async {
      await relabelRecordSitting(table: 'dive_sites', recordId: 's1');

      expect(await operations(), isEmpty);
    });
  });
}
