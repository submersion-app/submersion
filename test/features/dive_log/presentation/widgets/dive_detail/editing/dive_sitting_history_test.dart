import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_edit_save_provider.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_plan_link_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_safety_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../core/database/change_log/change_log_support.dart';
import '../../../../../../helpers/nav_track_fixtures.dart';
import '../../../../../../helpers/test_database.dart';

/// A sitting on a dive whose held changes reach the records the dive page
/// writes besides the dive (issue #4527, plan 9 Task 7): made through the
/// cards' own sitting functions and saved as the page saves a sitting, it
/// is one History entry about the dive, and reverting it puts all of it
/// back.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final changeLog = ChangeLogRepository();

  Future<Object?> cell(String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.single;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    // Each cylinder carries the index its computer gave it, as a downloaded
    // one does: without one, the exchange would first resolve a legacy
    // index for it and write that as well.
    for (final (id, order) in [('a', 0), ('b', 1)]) {
      await db.customStatement(
        'INSERT INTO dive_tanks (id, dive_id, tank_order, source_tank_index) '
        "VALUES (?, 'dive', ?, ?)",
        [id, order, order],
      );
    }
    await db.customStatement(
      'INSERT INTO tank_pressure_series (id, dive_id, tank_id, sample_count, '
      'start_timestamp, end_timestamp, codec_version, samples, created_at, '
      "updated_at) VALUES ('series', 'dive', 'a', 2, 0, 60, 1, X'010203', "
      '0, 0)',
    );
    await db.customStatement(
      'INSERT INTO dive_safety_reviews (dive_id, engine_version, '
      "reviewed_at) VALUES ('dive', 1, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_safety_findings (id, dive_id, rule_id, severity, '
      "engine_version, created_at) VALUES ('finding', 'dive', "
      "'rapidAscent', 'caution', 1, 0)",
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
      "('route', 'me', 'suunto_route', 0, 60, 0, X'', 0, 0)",
    );
    // A route the dive already has as its primary, so making the new one
    // primary is a change of its own.
    await db.customStatement(
      'INSERT INTO nav_tracks (id, diver_id, dive_id, link_mode, is_primary, '
      'source, start_time, end_time, point_count, points, created_at, '
      "updated_at) VALUES ('old', 'me', 'dive', 'manual', 1, 'suunto_route', "
      "0, 60, 0, X'', 0, 0)",
    );
    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  /// A sitting on the dive, started as the page starts one.
  Future<EditSession<Dive>> started() async {
    final dive = (await DiveRepository().getDiveById('dive'))!;
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    startDiveSitting(session, container.read);
    await session.settled();
    return session;
  }

  /// Notes edited, the finding dismissed, the readings moved between the
  /// cylinders, the document attached, the plan linked and the route linked
  /// and made primary, each through its card's sitting function.
  Future<void> changeEverything(EditSession<Dive> session) async {
    session.set(diveNotesField, 'Current');
    final review = await SafetyFindingsRepository().getReview('dive');
    setFindingDismissed(session, review!.findings.single, dismissed: true);
    exchangeTankSeries(
      session,
      'a',
      'b',
      exchange: (x, y) => TankPressureRepository().exchangeTankSources(
        diveId: 'dive',
        tankIdA: x,
        tankIdB: y,
        includePressures: false,
      ),
    );
    attachDocument(session, (await DocumentRepository().getById('doc'))!);
    setPlanLink(session, 'plan');
    setRouteDraft(
      session,
      sittingRouteDraft(
        session,
      )!.add(testNavTrack('route')).withPrimary('route'),
    );
  }

  /// Save, called as the dive page's `_saveSitting` calls it.
  Future<void> save(EditSession<Dive> session) => container
      .read(diveEditSaveServiceProvider)
      .save(
        diveId: session.stored.id,
        apply: (stored) => diveSittingApply(session, stored),
        changedCardIds: session.changedCardIds,
        writeFirst: session.hasHeldWritesBeforeRecord
            ? () => session.runHeldWrites(beforeRecord: true)
            : null,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      );

  /// Every record as the sitting left it at Save.
  Future<void> expectSaved() async {
    expect(await cell("SELECT notes FROM dives WHERE id = 'dive'"), 'Current');
    expect(
      await cell(
        "SELECT dismissed_at FROM dive_safety_findings WHERE id = 'finding'",
      ),
      isNotNull,
    );
    expect(
      await cell(
        "SELECT tank_id FROM tank_pressure_series WHERE id = 'series'",
      ),
      'b',
    );
    expect(
      await cell("SELECT source_tank_index FROM dive_tanks WHERE id = 'a'"),
      1,
    );
    expect(
      await cell("SELECT dive_id FROM documents WHERE id = 'doc'"),
      'dive',
    );
    expect(
      await cell("SELECT linked_dive_id FROM dive_plans WHERE id = 'plan'"),
      'dive',
    );
    expect(
      await cell("SELECT dive_id FROM nav_tracks WHERE id = 'route'"),
      'dive',
    );
    expect(
      await cell("SELECT is_primary FROM nav_tracks WHERE id = 'route'"),
      1,
    );
    expect(await cell("SELECT is_primary FROM nav_tracks WHERE id = 'old'"), 0);
  }

  /// The dive's History, as its page opens it.
  Future<List<ChangeLogOperation>> diveHistory() async {
    await changeLog.settleAll();
    return changeLog.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(rootTable: 'dives', rootId: 'dive'),
    );
  }

  test('a dismissal, an exchange, a document, a plan link and a route '
      'link: one entry about the dive', () async {
    final session = await started();
    await changeEverything(session);
    await save(session);

    final entry = (await diveHistory()).single;
    expect(entry.rootTable, 'dives');
    expect(entry.rootId, 'dive');
    expect(entry.isBulk, isFalse);
    final tables = {
      for (final event in await changeLog.getEvents(entry.id)) event.table,
    };
    expect(
      tables,
      containsAll([
        'dives',
        'dive_safety_findings',
        'tank_pressure_series',
        'documents',
        'dive_plans',
        'nav_tracks',
      ]),
    );
    await expectSaved();
    // Nothing of the sitting was filed apart from it.
    expect(
      await cell(
        'SELECT COUNT(*) FROM change_log_operations WHERE id <> '
        "'${entry.id}' AND event_count > 0",
      ),
      0,
    );
  });

  test('reverting it puts every one back', () async {
    final session = await started();
    await changeEverything(session);
    await save(session);
    final entry = (await diveHistory()).single;
    await expectSaved();
    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});

    await revert.execute(await revert.planOperation(entry.id));
    await changeLog.settleAll();

    expect(await cell("SELECT notes FROM dives WHERE id = 'dive'"), 'Calm');
    expect(
      await cell(
        "SELECT dismissed_at FROM dive_safety_findings WHERE id = 'finding'",
      ),
      isNull,
    );
    expect(
      await cell(
        "SELECT tank_id FROM tank_pressure_series WHERE id = 'series'",
      ),
      'a',
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
    expect(
      await cell("SELECT source_tank_index FROM dive_tanks WHERE id = 'a'"),
      0,
    );
    expect(
      await cell("SELECT source_tank_index FROM dive_tanks WHERE id = 'b'"),
      1,
    );
    expect(await cell("SELECT is_primary FROM nav_tracks WHERE id = 'old'"), 1);
    expect((await changeLog.getOperation(entry.id))!.isReverted, isTrue);
  });

  test(
    'Cancel (dispose without save) writes nothing and logs nothing',
    () async {
      final session = await started();
      await changeEverything(session);

      session.dispose();
      await changeLog.settleAll();

      expect(await cell("SELECT notes FROM dives WHERE id = 'dive'"), 'Calm');
      expect(
        await cell(
          "SELECT dismissed_at FROM dive_safety_findings WHERE id = 'finding'",
        ),
        isNull,
      );
      expect(
        await cell(
          "SELECT tank_id FROM tank_pressure_series WHERE id = 'series'",
        ),
        'a',
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
      expect(await logEvents(db), isEmpty);
      expect(await cell('SELECT COUNT(*) FROM change_log_operations'), 0);
    },
  );

  test("the entry's label names every card that changed", () async {
    final session = await started();
    await changeEverything(session);
    await save(session);

    final entry = (await diveHistory()).single;
    expect(RecordEditLabel.decode(entry.label!)!.cardIds, [
      'diveLab',
      'documents',
      'navTrack',
      'notes',
      'safetyReview',
      'tanks',
    ]);
  });
}
