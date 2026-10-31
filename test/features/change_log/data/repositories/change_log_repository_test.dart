import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
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

    final previews = await repository.getPreviewFields([operation.id]);

    final preview = previews[operation.id]!;
    expect(preview.fields, hasLength(2));
    expect(preview.total, 3);
    expect(preview.fields.first.table, 'dives');
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
