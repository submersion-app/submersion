import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/services/checklist_dive_linker.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreDiveSessionRepository sessions;
  late ChecklistDiveLinker linker;

  setUp(() async {
    await setUpTestDatabase();
    sessions = PreDiveSessionRepository();
    linker = ChecklistDiveLinker();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('dive-1', 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'me', 0, 0), ('other-diver', 'other-diver', 0, 0)",
    );
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final diveStart = DateTime(2026, 7, 16, 9, 30);

  domain.PreDiveChecklistTemplate template() {
    final now = DateTime.now();
    return domain.PreDiveChecklistTemplate(
      id: '',
      name: 'BWRAF',
      createdAt: now,
      updatedAt: now,
    );
  }

  // startSession stamps startedAt = now, so tests adjust it directly in SQL.
  Future<domain.PreDiveSession> sessionStartedAt(
    DateTime t, {
    String? diverId,
    DateTime? completedAt,
  }) async {
    final s = await sessions.startSession(
      template: template(),
      items: const [],
      diverId: diverId,
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'UPDATE pre_dive_sessions SET started_at = ${t.millisecondsSinceEpoch} '
      "WHERE id = '${s.id}'",
    );
    if (completedAt != null) {
      await db.customStatement(
        'UPDATE pre_dive_sessions SET '
        "status = 'completed', "
        'completed_at = ${completedAt.millisecondsSinceEpoch} '
        "WHERE id = '${s.id}'",
      );
    }
    return (await sessions.getSessionById(s.id))!;
  }

  test('links the nearest unlinked session inside the window', () async {
    final far = await sessionStartedAt(
      diveStart.subtract(const Duration(hours: 2, minutes: 30)),
    );
    final near = await sessionStartedAt(
      diveStart.subtract(const Duration(minutes: 20)),
    );
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: null,
      diveStart: diveStart,
    );
    expect(linked, isTrue);
    expect((await sessions.getSessionById(near.id))!.diveId, 'dive-1');
    expect((await sessions.getSessionById(far.id))!.diveId, isNull);
  });

  test('ignores sessions outside the 3h window or too far forward', () async {
    await sessionStartedAt(diveStart.subtract(const Duration(hours: 4)));
    await sessionStartedAt(diveStart.add(const Duration(hours: 1)));
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: null,
      diveStart: diveStart,
    );
    expect(linked, isFalse);
  });

  test('one-to-one: a dive that already has a session is skipped', () async {
    final s1 = await sessionStartedAt(
      diveStart.subtract(const Duration(minutes: 30)),
    );
    await sessions.linkToDive(s1.id, 'dive-1');
    final s2 = await sessionStartedAt(
      diveStart.subtract(const Duration(minutes: 10)),
    );
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: null,
      diveStart: diveStart,
    );
    expect(linked, isFalse);
    expect((await sessions.getSessionById(s2.id))!.diveId, isNull);
  });

  test('cross-diver isolation', () async {
    await sessionStartedAt(
      diveStart.subtract(const Duration(minutes: 10)),
      diverId: 'other-diver',
    );
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: 'me',
      diveStart: diveStart,
    );
    expect(linked, isFalse);
  });

  test('forward grace absorbs small clock skew', () async {
    final s = await sessionStartedAt(
      diveStart.add(const Duration(minutes: 10)),
    );
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: null,
      diveStart: diveStart,
    );
    expect(linked, isTrue);
    expect((await sessions.getSessionById(s.id))!.diveId, 'dive-1');
  });

  group('the window is anchored on completion, not start', () {
    test(
      'a long run that finished just before the splash still links',
      () async {
        // Started 4 h out (outside the window on startedAt) but ticked off its
        // last item 20 min before the dive: it is this dive's checklist.
        final s = await sessionStartedAt(
          diveStart.subtract(const Duration(hours: 4)),
          completedAt: diveStart.subtract(const Duration(minutes: 20)),
        );
        final linked = await linker.autoLinkForDive(
          diveId: 'dive-1',
          diverId: null,
          diveStart: diveStart,
        );
        expect(linked, isTrue);
        expect((await sessions.getSessionById(s.id))!.diveId, 'dive-1');
      },
    );

    test('a run completed a day earlier does not link', () async {
      await sessionStartedAt(
        diveStart.subtract(const Duration(minutes: 30)),
        completedAt: diveStart.subtract(const Duration(days: 1)),
      );
      final linked = await linker.autoLinkForDive(
        diveId: 'dive-1',
        diverId: null,
        diveStart: diveStart,
      );
      expect(linked, isFalse);
    });

    test('nearest completion wins over nearest start', () async {
      // `early` started closer to the splash but was finished long before it;
      // `late` started earlier and finished right before the diver got in.
      final early = await sessionStartedAt(
        diveStart.subtract(const Duration(minutes: 40)),
        completedAt: diveStart.subtract(const Duration(minutes: 35)),
      );
      final closer = await sessionStartedAt(
        diveStart.subtract(const Duration(hours: 2)),
        completedAt: diveStart.subtract(const Duration(minutes: 5)),
      );
      await linker.autoLinkForDive(
        diveId: 'dive-1',
        diverId: null,
        diveStart: diveStart,
      );
      expect((await sessions.getSessionById(closer.id))!.diveId, 'dive-1');
      expect((await sessions.getSessionById(early.id))!.diveId, isNull);
    });

    test('an unfinished run still falls back to its start time', () async {
      final s = await sessionStartedAt(
        diveStart.subtract(const Duration(minutes: 25)),
      );
      final linked = await linker.autoLinkForDive(
        diveId: 'dive-1',
        diverId: null,
        diveStart: diveStart,
      );
      expect(linked, isTrue);
      expect((await sessions.getSessionById(s.id))!.diveId, 'dive-1');
    });
  });

  test('a running session ignores a stale completion stamp', () async {
    // Contradictory data: status still inProgress, yet a finish stamp sits on
    // the row 4.5 h before the splash. Anchoring on that stamp puts the run
    // outside the window and loses the link; the run has not finished, so its
    // start is the only honest anchor.
    final s = await sessionStartedAt(
      diveStart.subtract(const Duration(minutes: 20)),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'UPDATE pre_dive_sessions SET completed_at = '
      '${diveStart.subtract(const Duration(hours: 4, minutes: 30)).millisecondsSinceEpoch} '
      "WHERE id = '${s.id}'",
    );
    final running = (await sessions.getSessionById(s.id))!;
    expect(running.status, domain.PreDiveSessionStatus.inProgress);
    expect(running.completedAt, isNotNull);
    expect(
      ChecklistDiveLinker.anchorOf(running),
      running.startedAt,
      reason: 'a run still in progress anchors on its start',
    );

    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: null,
      diveStart: diveStart,
    );
    expect(linked, isTrue);
    expect((await sessions.getSessionById(s.id))!.diveId, 'dive-1');
  });
}
