import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

const _noFilter = ChangeLogFilter();

Future<void> _editNotes(AppDatabase db, String id, String notes) =>
    db.customStatement("UPDATE dives SET notes = '$notes' WHERE id = '$id'");

Future<void> _insertSite(AppDatabase db, String id, String diverId) => db
    .into(db.diveSites)
    .insert(
      DiveSitesCompanion.insert(
        id: id,
        name: id,
        createdAt: 0,
        updatedAt: 0,
        diverId: Value(diverId),
      ),
    );

void main() {
  late AppDatabase db;
  late ChangeLogRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = ChangeLogRepository();
    await insertDiver(db, 'me');
    await insertDiver(db, 'them');
    await insertDive(db, 'mine', diverId: 'me', notes: 'Calm');
    await insertDive(db, 'theirs', diverId: 'them', notes: 'Flat');
    await repository.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    await clearLog(db);
  });
  tearDown(tearDownTestDatabase);

  Future<List<String?>> feedRoots(
    String diverId, {
    ChangeLogFilter filter = _noFilter,
  }) async {
    await repository.settleAll();
    final feed = await repository.getFeed(diverId: diverId, filter: filter);
    return feed.map((o) => o.rootId).toList();
  }

  // A pass ends once its time is spent, so a slow device commits often and
  // other queries get their turn; the loop must still reach the end rather
  // than stop at the first pass that settled less than a full batch (#4186).
  test('settles every event when each pass runs out of time', () async {
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'theirs', 'Two');
    await _editNotes(db, 'mine', 'Three');

    await repository.settleAll(budget: Duration.zero);

    final events = await logEvents(db);
    expect(events, hasLength(3));
    expect(events.every((e) => e['settled'] == 1), isTrue);
  });

  // Each pass announces its entries, the open feed rebuilds on that and
  // settles again in the rebuild: without joining, a backlog of many passes
  // started a settle loop per pass.
  test('a call while a settle runs joins it', () async {
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'theirs', 'Two');

    final first = repository.settleAll(budget: Duration.zero);
    final joined = ChangeLogRepository().settleAll(budget: Duration.zero);
    expect(identical(joined, first), isTrue);
    await first;

    final next = repository.settleAll();
    expect(identical(next, first), isFalse);
    await next;
    expect((await logEvents(db)).every((e) => e['settled'] == 1), isTrue);
  });

  test('feed shows only the active diver', () async {
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'theirs', 'Two');

    expect(await feedRoots('me'), ['mine']);
    expect(await feedRoots('them'), ['theirs']);
  });

  test(
    "a shared site's change shows for the diver it is shared with",
    () async {
      await _insertSite(db, 'site', 'them');
      await db.customStatement(
        'INSERT INTO site_shares (id, site_id, diver_id, created_at) '
        "VALUES ('s1', 'site', 'me', 0)",
      );

      expect(await feedRoots('me'), contains('site'));
    },
  );

  test('an unshared record stops showing', () async {
    await _insertSite(db, 'site', 'them');
    await db.customStatement(
      'INSERT INTO site_shares (id, site_id, diver_id, created_at) '
      "VALUES ('s1', 'site', 'me', 0)",
    );
    await repository.settleAll();

    await db.customStatement("DELETE FROM site_shares WHERE id = 's1'");

    expect(await feedRoots('me'), isNot(contains('site')));
  });

  test('a null owner shows for every diver', () async {
    await db.customStatement(
      'INSERT INTO settings (key, value, updated_at) '
      "VALUES ('share_new_records_by_default', 'true', 0)",
    );

    expect(await feedRoots('me'), ['share_new_records_by_default']);
    expect(await feedRoots('them'), ['share_new_records_by_default']);
  });

  test('a scope with no changes never shows', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () async {
        await repository.settleAll();
        expect(
          await repository.getFeed(diverId: 'me', filter: _noFilter),
          isEmpty,
        );
      },
    );
  });

  test('filter by record type', () async {
    await _editNotes(db, 'mine', 'One');
    await _insertSite(db, 'site', 'me');

    expect(
      await feedRoots(
        'me',
        filter: const ChangeLogFilter(rootTables: {'dive_sites'}),
      ),
      ['site'],
    );
  });

  test('filter by record type reaches a bulk operation', () async {
    await insertDive(db, 'second', diverId: 'me');
    await clearLog(db);
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () async {
        await _editNotes(db, 'mine', 'One');
        await _editNotes(db, 'second', 'Two');
      },
    );
    await repository.settleAll();

    final feed = await repository.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(rootTables: {'dives'}),
    );

    expect(feed.where((o) => o.isBulk), hasLength(1));
  });

  test('filter by source', () async {
    await _editNotes(db, 'mine', 'One');
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () => _editNotes(db, 'mine', 'Two'),
    );
    await repository.settleAll();

    final feed = await repository.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(sources: {ChangeLogSource.rule}),
    );

    expect(feed.single.source, ChangeLogSource.rule);
  });

  test('record filter returns one root', () async {
    await insertDive(db, 'second', diverId: 'me');
    await clearLog(db);
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'second', 'Two');

    expect(
      await feedRoots(
        'me',
        filter: const ChangeLogFilter(rootTable: 'dives', rootId: 'second'),
      ),
      ['second'],
    );
  });

  test(
    'record filter finds a bulk operation that touched the record',
    () async {
      await insertDive(db, 'second', diverId: 'me');
      await clearLog(db);
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.rule,
        body: () async {
          await _editNotes(db, 'mine', 'One');
          await _editNotes(db, 'second', 'Two');
        },
      );
      await repository.settleAll();

      final feed = await repository.getFeed(
        diverId: 'me',
        filter: const ChangeLogFilter(rootTable: 'dives', rootId: 'second'),
      );

      expect(feed, hasLength(1));
      expect(feed.single.isBulk, isTrue);
    },
  );

  test('paging returns no duplicates across equal timestamps', () async {
    for (var i = 0; i < 5; i++) {
      await ChangeLogScope.suppressed(
        db,
        label: 'Summary $i',
        source: ChangeLogSource.system,
        body: () async {},
      );
    }
    await db.customStatement(
      'UPDATE change_log_operations SET started_at = 5, ended_at = 5',
    );

    final seen = <String>[];
    ChangeLogPageCursor? after;
    while (true) {
      final page = await repository.getFeed(
        diverId: 'me',
        filter: _noFilter,
        after: after,
        limit: 2,
      );
      if (page.isEmpty) break;
      seen.addAll(page.map((o) => o.id));
      after = ChangeLogPageCursor.after(page.last);
    }

    expect(seen, hasLength(5));
    expect(seen.toSet(), hasLength(5));
  });

  test('a backwards clock keeps the newest change first', () async {
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'mine', 'Two');
    final events = await logEvents(db);
    await db.customStatement(
      'UPDATE change_log_events SET changed_at = 9000 WHERE id = ?',
      [events.first['id']],
    );
    await db.customStatement(
      'UPDATE change_log_events SET changed_at = 1000 WHERE id = ?',
      [events.last['id']],
    );
    await repository.settleAll();

    final feed = await repository.getFeed(diverId: 'me', filter: _noFilter);

    expect(feed.first.lastEventId, events.last['id']);
    expect(feed.first.endedAt.millisecondsSinceEpoch, 1000);
  });

  test('entry detail lists events with their fields', () async {
    await _editNotes(db, 'mine', 'One');
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).single;

    expect(await repository.getOperation(operation.id), operation);
    final events = await repository.getEvents(operation.id);
    expect(events.single.action, ChangeLogAction.update);
    expect(events.single.table, 'dives');
    final field = events.single.fields.single;
    expect(field.column, 'notes');
    expect(field.oldValue, 'Calm');
    expect(field.newValue, 'One');
  });

  group('a sitting that wrote only another record', () {
    setUp(() async {
      await db.customStatement(
        'INSERT INTO documents (id, diver_id, type, created_at, updated_at) '
        "VALUES ('doc', 'me', 'other', 0, 0)",
      );
      await repository.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
      await clearLog(db);
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.manual,
        label: RecordEditLabel.encode(
          table: 'dives',
          id: 'mine',
          cardIds: ['documents'],
        ),
        body: () => db.customStatement(
          "UPDATE documents SET dive_id = 'mine' WHERE id = 'doc'",
        ),
      );
    });

    test('the record filter finds it under the record it is pinned to, with '
        'no event of its own', () async {
      expect(
        await feedRoots(
          'me',
          filter: const ChangeLogFilter(rootTable: 'dives', rootId: 'mine'),
        ),
        ['mine'],
      );
    });

    test('the record filter still finds it under the document', () async {
      expect(
        await feedRoots(
          'me',
          filter: const ChangeLogFilter(rootTable: 'documents', rootId: 'doc'),
        ),
        ['mine'],
      );
    });

    // Its row is titled with the dive, so a field of the document there
    // would read as the dive's own.
    test('its feed row previews no field of the document', () async {
      await repository.settleAll();
      final operation = (await repository.getFeed(
        diverId: 'me',
        filter: _noFilter,
      )).single;

      expect(
        (await repository.getPreviewFields([operation]))[operation.id],
        isNull,
      );
    });
  });

  test('a sitting previews its own record\'s fields, not another\'s', () async {
    await _insertSite(db, 'reef', 'me');
    await repository.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    await clearLog(db);
    late String id;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      label: RecordEditLabel.encode(
        table: 'dives',
        id: 'mine',
        cardIds: ['altitude'],
      ),
      body: () async {
        id = ChangeLogScope.currentOperationId!;
        await db.customStatement(
          "UPDATE dives SET altitude = 512 WHERE id = 'mine'",
        );
        await db.customStatement(
          "UPDATE dive_sites SET altitude = 512 WHERE id = 'reef'",
        );
      },
    );
    await repository.settleAll();

    final preview = (await repository.getPreviewFields([
      (await repository.getOperation(id))!,
    ]))[id]!;
    expect(preview.fields.map((f) => (f.table, f.column)), [
      ('dives', 'altitude'),
    ]);
    expect(preview.total, 1);
  });

  group('machine rows an entry lists', () {
    setUp(() async {
      for (final tank in ['a', 'b']) {
        await db.customStatement(
          "INSERT INTO dive_tanks (id, dive_id) VALUES (?, 'mine')",
          [tank],
        );
      }
      await db.customStatement(
        'INSERT INTO tank_pressure_series (id, dive_id, tank_id, '
        'sample_count, start_timestamp, end_timestamp, codec_version, '
        'samples, created_at, updated_at) VALUES '
        "('series', 'mine', 'a', 2, 0, 60, 1, X'010203', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO dive_safety_findings (id, dive_id, rule_id, severity, '
        "engine_version, created_at) VALUES ('finding', 'mine', "
        "'fast_ascent', 'warning', 1, 0)",
      );
      await repository.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
      await clearLog(db);
    });

    Future<String> inScope(String label, Future<void> Function() body) async {
      late String id;
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.manual,
        label: label,
        body: () async {
          id = ChangeLogScope.currentOperationId!;
          await body();
        },
      );
      await repository.settleAll();
      return id;
    }

    final sitting = RecordEditLabel.encode(
      table: 'dives',
      id: 'mine',
      cardIds: ['safetyReview', 'tanks'],
    );

    test('an entry lists a dismissed finding with its dismissed_at', () async {
      final id = await inScope(
        sitting,
        () => db.customStatement(
          'UPDATE dive_safety_findings SET dismissed_at = 7000',
        ),
      );

      final event = (await repository.getEvents(id)).single;
      expect(event.table, 'dive_safety_findings');
      expect(event.fields.map((f) => (f.column, f.oldValue, f.newValue)), [
        ('dismissed_at', null, 7000),
      ]);
    });

    test('an entry lists moved readings with their tank_id only', () async {
      final id = await inScope(
        ChangeLogLabels.removeDuplicateCylinders,
        () => db.customStatement(
          "UPDATE tank_pressure_series SET tank_id = 'b', samples = X'09'",
        ),
      );

      final event = (await repository.getEvents(id)).single;
      expect(event.table, 'tank_pressure_series');
      expect(event.fields.map((f) => (f.column, f.oldValue, f.newValue)), [
        ('tank_id', 'a', 'b'),
      ]);
      expect(
        (await repository.getEvents(
          id,
          includeMachineRows: true,
        )).single.fields.map((f) => f.column),
        containsAll(['tank_id', 'samples']),
      );
    });

    test(
      'a series update that changed only its samples stays hidden',
      () async {
        final id = await inScope(
          ChangeLogLabels.removeSource,
          () => db.customStatement(
            "UPDATE tank_pressure_series SET samples = X'09'",
          ),
        );

        expect(await repository.getEvents(id), isEmpty);
        expect(await repository.countEvents(id), 0);
      },
    );

    test('countEvents counts what getEvents lists', () async {
      final id = await inScope(sitting, () async {
        await db.customStatement(
          'UPDATE dive_safety_findings SET dismissed_at = 7000',
        );
        await db.customStatement(
          "UPDATE tank_pressure_series SET samples = X'09'",
        );
      });

      expect(await repository.getEvents(id), hasLength(1));
      expect(await repository.countEvents(id), 1);
    });
  });

  test('entry detail hides machine rows by default', () async {
    await db.customStatement(
      'INSERT INTO tide_records (id, dive_id, height_meters, tide_state, '
      "created_at) VALUES ('tide', 'mine', 1.0, 'rising', 0)",
    );
    await clearLog(db);
    await db.customStatement("DELETE FROM dives WHERE id = 'mine'");
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).single;

    final shown = await repository.getEvents(operation.id);
    final all = await repository.getEvents(
      operation.id,
      includeMachineRows: true,
    );

    expect(shown.map((e) => e.table), isNot(contains('tide_records')));
    expect(all.map((e) => e.table), contains('tide_records'));
  });

  test('previews give the first fields and the total', () async {
    await db.customStatement(
      "UPDATE dives SET notes = 'One', max_depth = 30, avg_depth = 12 "
      "WHERE id = 'mine'",
    );
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).single;

    final previews = await repository.getPreviewFields([operation]);

    final preview = previews[operation.id]!;
    expect(preview.fields, hasLength(2));
    expect(preview.total, 3);
    expect(preview.fields.first.table, 'dives');
  });

  test('two saves to one field preview as one change', () async {
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'mine', 'Two');
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).single;

    final preview = (await repository.getPreviewFields([
      operation,
    ]))[operation.id]!;

    expect(preview.total, 1);
    expect(preview.fields.single.oldValue, 'Calm');
    expect(preview.fields.single.newValue, 'Two');
  });

  test('a field saved back to its start is no change', () async {
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'mine', 'Calm');
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).single;

    final preview = (await repository.getPreviewFields([
      operation,
    ]))[operation.id];

    expect(preview?.total ?? 0, 0);
  });

  test('a preview says a record went, even after an edit', () async {
    await _editNotes(db, 'mine', 'One');
    await db.customStatement("DELETE FROM dives WHERE id = 'mine'");
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).single;

    final preview = (await repository.getPreviewFields([
      operation,
    ]))[operation.id]!;

    expect(preview.rootAction, ChangeLogAction.delete);
  });

  test('a preview says a record was added, even with an edit', () async {
    await insertDive(db, 'fresh', diverId: 'me');
    await _editNotes(db, 'fresh', 'One');
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).single;

    final preview = (await repository.getPreviewFields([
      operation,
    ]))[operation.id]!;

    expect(preview.rootAction, ChangeLogAction.insert);
  });

  test('record counts count roots, not events', () async {
    await insertDive(db, 'second', diverId: 'me');
    await clearLog(db);
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () async {
        await _editNotes(db, 'mine', 'One');
        await _editNotes(db, 'mine', 'Two');
        await _editNotes(db, 'second', 'Three');
      },
    );
    await repository.settleAll();
    final operation = (await repository.getFeed(
      diverId: 'me',
      filter: _noFilter,
    )).firstWhere((o) => o.isBulk);

    expect(await repository.getRecordCounts([operation.id]), {operation.id: 2});
  });

  test('clear removes one diver\'s entries and their fields', () async {
    await _editNotes(db, 'mine', 'One');
    await _editNotes(db, 'theirs', 'Two');
    await repository.settleAll();

    expect(await repository.clearForDiver('me'), 1);

    expect(await feedRoots('me'), isEmpty);
    expect(await feedRoots('them'), ['theirs']);
    final remaining = await logEvents(db);
    expect(remaining.single['record_id'], 'theirs');
    final fields = await db
        .customSelect('SELECT COUNT(*) AS c FROM change_log_fields')
        .getSingle();
    expect(fields.read<int>('c'), 1);
  });

  test('filters with the same values are equal', () {
    expect(
      const ChangeLogFilter(rootTables: {'dives'}),
      const ChangeLogFilter(rootTables: {'dives'}),
    );
    expect(
      const ChangeLogFilter(rootTables: {'dives'}).hashCode,
      const ChangeLogFilter(rootTables: {'dives'}).hashCode,
    );
    expect(
      const ChangeLogFilter(rootTables: {'dives'}),
      isNot(const ChangeLogFilter()),
    );
  });
}
