import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A sitting is one History entry about its dive, found in the dive's
/// History, whatever other records it wrote along the way (issue #4527).
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late DiveEditSaveService service;
  final changeLog = ChangeLogRepository();

  /// The dive's History, as its page opens it.
  Future<List<ChangeLogOperation>> diveHistory() async {
    await changeLog.settleAll();
    return changeLog.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(rootTable: 'dives', rootId: 'dive'),
    );
  }

  /// A sitting whose only change is [write] to another record.
  Future<void> onlyWrite(Future<void> Function() write) => service.save(
    diveId: 'dive',
    apply: (dive) => dive,
    changedCardIds: ['documents'],
    alsoWrite: write,
    alsoWriteIsAChange: true,
  );

  void expectAboutTheDive(ChangeLogOperation operation) {
    expect(operation.rootTable, 'dives');
    expect(operation.rootId, 'dive');
    expect(operation.isBulk, isFalse);
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    dives = DiveRepository();
    service = DiveEditSaveService(dives, TripRepository());
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site',
            name: 'Lake',
            createdAt: 0,
            updatedAt: 0,
            diverId: const Value('me'),
          ),
        );
    await db.customStatement(
      'INSERT INTO documents (id, diver_id, type, created_at, updated_at) '
      "VALUES ('doc', 'me', 'other', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_plans (id, diver_id, name, created_at, updated_at) '
      "VALUES ('plan', 'me', 'Plan', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO nav_tracks (id, diver_id, source, start_time, end_time, '
      'point_count, points, created_at, updated_at) VALUES '
      "('route', 'me', 'suunto_route', 0, 60, 0, ?, 0, 0)",
      [Uint8List(0)],
    );
    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  test('a sitting that also copies an altitude to the site is one entry '
      'about the dive', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current'),
      changedCardIds: ['notes', 'altitude'],
      alsoWrite: () => SiteRepository().updateSiteAltitude('site', 512),
    );

    expectAboutTheDive((await diveHistory()).single);
  });

  test(
    'a sitting that only files a document is in the dive\'s History',
    () async {
      await onlyWrite(
        () => db.customStatement(
          "UPDATE documents SET dive_id = 'dive' WHERE id = 'doc'",
        ),
      );

      expectAboutTheDive((await diveHistory()).single);
    },
  );

  test('a sitting that only links a plan is in the dive\'s History', () async {
    await onlyWrite(() => DivePlanRepository().linkPlanToDive('plan', 'dive'));

    expectAboutTheDive((await diveHistory()).single);
  });

  test('a sitting that only links a route is in the dive\'s History', () async {
    await onlyWrite(
      () => NavTrackRepository().link(
        'route',
        'dive',
        linkMode: NavTrackLinkMode.manual,
      ),
    );

    expectAboutTheDive((await diveHistory()).single);
  });

  test('the document\'s own History lists the same entry', () async {
    await onlyWrite(
      () => db.customStatement(
        "UPDATE documents SET dive_id = 'dive' WHERE id = 'doc'",
      ),
    );

    final diveEntry = (await diveHistory()).single;
    final documentHistory = await changeLog.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(rootTable: 'documents', rootId: 'doc'),
    );
    expect(documentHistory.single.id, diveEntry.id);
  });

  // One sitting with every kind of change the spec names (issue #4527): the
  // notes, readings moved between cylinders, a dismissed safety finding, a
  // document filed under the dive, a plan linked and a route linked and
  // made primary.
  group('one sitting, every kind of change', () {
    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});

    Future<Object?> cell(String sql) async =>
        (await db.customSelect(sql).getSingle()).data.values.single;

    setUp(() async {
      for (final tank in ['a', 'b']) {
        await db.customStatement(
          "INSERT INTO dive_tanks (id, dive_id) VALUES (?, 'dive')",
          [tank],
        );
      }
      await db.customStatement(
        'INSERT INTO tank_pressure_series (id, dive_id, tank_id, '
        'sample_count, start_timestamp, end_timestamp, codec_version, '
        'samples, created_at, updated_at) VALUES '
        "('series', 'dive', 'a', 2, 0, 60, 1, X'010203', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO dive_safety_findings (id, dive_id, rule_id, severity, '
        "engine_version, created_at) VALUES ('finding', 'dive', "
        "'fast_ascent', 'warning', 1, 0)",
      );
      await changeLog.settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
    });

    /// The sitting. [removeB] also removes cylinder b, which the readings
    /// were moved onto.
    Future<void> sitting({bool removeB = false}) => service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(
        notes: 'Current',
        tanks: removeB
            ? [
                for (final t in dive.tanks)
                  if (t.id != 'b') t,
              ]
            : null,
      ),
      changedCardIds: [
        'diveLab',
        'documents',
        'navTrack',
        'notes',
        'safetyReview',
        'tanks',
      ],
      writeFirst: () => TankPressureRepository().exchangeTankSources(
        diveId: 'dive',
        tankIdA: 'a',
        tankIdB: 'b',
        includePressures: false,
      ),
      alsoWrite: () async {
        await SafetyFindingsRepository().setDismissed(
          findingId: 'finding',
          dismissed: true,
          now: DateTime.fromMillisecondsSinceEpoch(7000),
        );
        await db.customStatement(
          "UPDATE documents SET dive_id = 'dive' WHERE id = 'doc'",
        );
        await DivePlanRepository().linkPlanToDive('plan', 'dive');
        final routes = NavTrackRepository();
        await routes.link('route', 'dive', linkMode: NavTrackLinkMode.manual);
        await routes.setPrimary('route');
      },
    );

    Future<String> theEntry() async => (await diveHistory()).single.id;

    test(
      'it is one operation, about the dive, in the dive\'s History',
      () async {
        await sitting();

        expectAboutTheDive((await diveHistory()).single);
        final all = await db
            .customSelect('SELECT id FROM change_log_operations')
            .get();
        expect(all, hasLength(1));
      },
    );

    test('the entry lists the notes, the readings, the dismissal, the '
        'document, the plan and the route', () async {
      await sitting();

      final events = await changeLog.getEvents(await theEntry());
      expect(
        {for (final e in events) e.table},
        containsAll([
          'dives',
          'tank_pressure_series',
          'dive_safety_findings',
          'documents',
          'dive_plans',
          'nav_tracks',
        ]),
      );
    });

    test('reverting it restores every value, the readings on their own '
        'cylinders', () async {
      await sitting();

      await revert.execute(await revert.planOperation(await theEntry()));

      expect((await dives.getDiveById('dive'))!.notes, 'Calm');
      expect(
        await cell(
          "SELECT tank_id FROM tank_pressure_series WHERE id = 'series'",
        ),
        'a',
      );
      expect(
        await cell(
          "SELECT dismissed_at FROM dive_safety_findings WHERE id = 'finding'",
        ),
        isNull,
      );
      expect(
        await cell("SELECT dive_id FROM documents WHERE id = 'doc'"),
        isNull,
      );
      expect(
        await cell("SELECT linked_dive_id FROM dive_plans WHERE id = 'plan'"),
        isNull,
      );
      expect(
        await cell("SELECT dive_id FROM nav_tracks WHERE id = 'route'"),
        isNull,
      );
    });

    test('readings moved onto a cylinder the sitting removes come back with '
        'it on revert', () async {
      await sitting(removeB: true);
      expect(
        await db.customSelect("SELECT id FROM dive_tanks WHERE id = 'b'").get(),
        isEmpty,
      );

      await revert.execute(await revert.planOperation(await theEntry()));

      expect(
        await cell("SELECT dive_id FROM dive_tanks WHERE id = 'b'"),
        'dive',
      );
      expect(
        await cell(
          "SELECT tank_id FROM tank_pressure_series WHERE id = 'series'",
        ),
        'a',
      );
    });

    test('a finding deleted before the revert is reported blocked; the rest '
        'goes back', () async {
      await sitting();
      await db.customStatement(
        "DELETE FROM dive_safety_findings WHERE id = 'finding'",
      );

      final result = await revert.execute(
        await revert.planOperation(await theEntry()),
      );

      expect(
        result.keptItems.map((i) => i.event.table),
        contains('dive_safety_findings'),
      );
      expect((await dives.getDiveById('dive'))!.notes, 'Calm');
    });

    test(
      'after the revert the finding and the series are pending for sync',
      () async {
        await sitting();
        await SyncRepository().clearPendingRecords();

        await revert.execute(await revert.planOperation(await theEntry()));

        final pending = {
          for (final r in await SyncRepository().getPendingRecords())
            (r.entityType, r.recordId),
        };
        expect(pending, contains(('diveSafetyFindings', 'finding')));
        expect(pending, contains(('tankPressureSeries', 'series')));
      },
    );

    test('a write made after save returns is not in the entry', () async {
      await sitting();
      final entry = await theEntry();

      await dives.updateDive(
        (await dives.getDiveById('dive'))!.copyWith(notes: 'Later'),
      );
      await changeLog.settleAll();

      final history = await diveHistory();
      expect(history, hasLength(2));
      expect(history.last.id, entry);
      expect(history.first.label, isNull);
    });
  });
}
