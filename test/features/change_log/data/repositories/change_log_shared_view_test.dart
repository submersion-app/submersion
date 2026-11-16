import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

const _noFilter = ChangeLogFilter();

/// A sitting is one entry about the dive it was opened on (issue #4527). A
/// diver who does not own the dive, but owns or shares a record the sitting
/// changed, sees the entry too: titled with that record, listing only its
/// rows, so the dive's name and fields stay hidden.
void main() {
  late AppDatabase db;
  final repository = ChangeLogRepository();

  Future<void> insertSite(String id, String owner) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: id,
          createdAt: 0,
          updatedAt: 0,
          diverId: Value(owner),
        ),
      );

  Future<void> share(String site, String diver) => db.customStatement(
    'INSERT INTO site_shares (id, site_id, diver_id, created_at) '
    "VALUES ('$site-$diver', '$site', '$diver', 0)",
  );

  /// A sitting on the dive 'mine' that sets its altitude and [site]'s.
  Future<String> copyAltitude(String? site) async {
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
        if (site != null) {
          await db.customStatement(
            'UPDATE dive_sites SET altitude = 512 WHERE id = ?',
            [site],
          );
        }
      },
    );
    await repository.settleAll();
    return id;
  }

  Future<ChangeLogOperation?> seenBy(String diverId, String id) async {
    final feed = await repository.getFeed(diverId: diverId, filter: _noFilter);
    return feed.where((operation) => operation.id == id).firstOrNull;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDiver(db, 'them');
    await insertDiver(db, 'other');
    await insertDive(db, 'mine', diverId: 'me', notes: 'Calm');
    await insertSite('reef', 'me');
    await insertSite('wall', 'them');
    await share('reef', 'them');
    await share('wall', 'me');
    await repository.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    await clearLog(db);
  });
  tearDown(tearDownTestDatabase);

  test('the dive owner sees the whole entry', () async {
    final id = await copyAltitude('reef');

    final mine = (await seenBy('me', id))!;
    expect(mine.rootTable, 'dives');
    expect(mine.rootId, 'mine');
    expect(mine.shownRoots, isNull);
    expect(await repository.getEvents(id), hasLength(2));
  });

  group('a diver a changed site is shared with', () {
    test('sees the entry titled with the site', () async {
      final id = await copyAltitude('reef');

      final theirs = (await seenBy('them', id))!;
      expect(theirs.rootTable, 'dive_sites');
      expect(theirs.rootId, 'reef');
      expect(theirs.rootLabel, 'reef');
      expect(theirs.rootOrdinal, isNull);
      expect(theirs.shownRoots, {(table: 'dive_sites', id: 'reef')});
    });

    test("finds it in the site's History", () async {
      final id = await copyAltitude('reef');

      final feed = await repository.getFeed(
        diverId: 'them',
        filter: const ChangeLogFilter(rootTable: 'dive_sites', rootId: 'reef'),
      );
      expect(feed.map((operation) => operation.id), [id]);
    });

    test("lists and previews only the site's rows", () async {
      final id = await copyAltitude('reef');
      final theirs = (await repository.getVisibleOperation(id, 'them'))!;

      final events = await repository.getEvents(
        id,
        onlyRoots: theirs.shownRoots,
      );
      expect(events.map((event) => event.table), ['dive_sites']);
      expect(await repository.countEvents(id, onlyRoots: theirs.shownRoots), 1);
      final preview = (await repository.getPreviewFields([theirs]))[id]!;
      expect(preview.fields.map((field) => (field.table, field.column)), [
        ('dive_sites', 'altitude'),
      ]);
    });

    test(
      'reverts only the site, and the entry does not read as reverted',
      () async {
        final id = await copyAltitude('reef');
        final theirs = (await repository.getVisibleOperation(id, 'them'))!;
        final service = ChangeLogRevertService(afterDiveWrites: (_) {});

        final plan = await service.planOperation(
          id,
          onlyRoots: theirs.shownRoots,
        );
        expect(plan.wholeOperation, isFalse);
        await service.execute(plan);
        await repository.settleAll();

        final dive = await db
            .customSelect("SELECT altitude FROM dives WHERE id = 'mine'")
            .getSingle();
        final site = await db
            .customSelect("SELECT altitude FROM dive_sites WHERE id = 'reef'")
            .getSingle();
        expect(dive.data['altitude'], 512);
        expect(site.data['altitude'], isNull);
        expect((await repository.getOperation(id))!.isReverted, isFalse);
      },
    );

    test('does not see a sitting that changed only the dive', () async {
      final id = await copyAltitude(null);

      expect(await seenBy('them', id), isNull);
      expect(await repository.getVisibleOperation(id, 'them'), isNull);
    });
  });

  test(
    "the owner of another diver's site a sitting changed sees its rows",
    () async {
      final id = await copyAltitude('wall');

      final owner = (await seenBy('them', id))!;
      expect(owner.rootTable, 'dive_sites');
      expect(owner.rootId, 'wall');
      expect(owner.shownRoots, {(table: 'dive_sites', id: 'wall')});
    },
  );

  test(
    'a diver with no share in any record it changed does not see it',
    () async {
      final id = await copyAltitude('reef');

      expect(await seenBy('other', id), isNull);
    },
  );
}
