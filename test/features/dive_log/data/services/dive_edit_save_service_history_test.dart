import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
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
}
