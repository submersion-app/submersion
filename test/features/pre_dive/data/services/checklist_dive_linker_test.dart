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
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'me', 0, 0), ('other-diver', 'other-diver', 0, 0)",
    );
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final diveStart = DateTime(2026, 7, 16, 9, 30);

  Future<void> insertDive(String id, DateTime dt, {String? diverId}) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_date_time, created_at, updated_at) '
      "VALUES ('$id', ${diverId == null ? 'NULL' : "'$diverId'"}, "
      '${dt.millisecondsSinceEpoch}, 0, 0)',
    );
  }

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

  test('links the nearest unlinked session before the dive', () async {
    await insertDive('dive-1', diveStart);
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
    // Both precede the dive with nothing in between, so both belong to it
    // (n:1) -- see the dedicated group below for the full behaviour.
    expect((await sessions.getSessionById(near.id))!.diveId, 'dive-1');
    expect((await sessions.getSessionById(far.id))!.diveId, 'dive-1');
  });

  test(
    'a check weeks before the dive still links when nothing closer exists',
    () async {
      await insertDive('dive-1', diveStart);
      final old = await sessionStartedAt(
        diveStart.subtract(const Duration(days: 40)),
      );
      final linked = await linker.autoLinkForDive(
        diveId: 'dive-1',
        diverId: null,
        diveStart: diveStart,
      );
      expect(linked, isTrue);
      expect((await sessions.getSessionById(old.id))!.diveId, 'dive-1');
    },
  );

  test('a check well after the dive does not link to it', () async {
    await insertDive('dive-1', diveStart);
    final after = await sessionStartedAt(
      diveStart.add(const Duration(hours: 4)),
    );
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: null,
      diveStart: diveStart,
    );
    expect(linked, isFalse);
    expect((await sessions.getSessionById(after.id))!.diveId, isNull);
  });

  test('cross-diver isolation', () async {
    await insertDive('dive-1', diveStart, diverId: 'me');
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

  test(
    'forward grace (3h, for clock skew / DST) absorbs a late completion',
    () async {
      await insertDive('dive-1', diveStart);
      final s = await sessionStartedAt(
        diveStart.add(const Duration(hours: 2, minutes: 59)),
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

  test('beyond the 3h forward grace, the check does not link', () async {
    await insertDive('dive-1', diveStart);
    final s = await sessionStartedAt(
      diveStart.add(const Duration(hours: 3, minutes: 1)),
    );
    final linked = await linker.autoLinkForDive(
      diveId: 'dive-1',
      diverId: null,
      diveStart: diveStart,
    );
    expect(linked, isFalse);
    expect((await sessions.getSessionById(s.id))!.diveId, isNull);
  });

  group('multiple checks before the same dive (n:1)', () {
    test('all link to the same dive when nothing separates them', () async {
      await insertDive('dive-1', diveStart);
      final s1 = await sessionStartedAt(
        diveStart.subtract(const Duration(hours: 20)),
      );
      final s2 = await sessionStartedAt(
        diveStart.subtract(const Duration(hours: 1)),
      );
      final s3 = await sessionStartedAt(
        diveStart.subtract(const Duration(minutes: 10)),
      );
      final linked = await linker.autoLinkForDive(
        diveId: 'dive-1',
        diverId: null,
        diveStart: diveStart,
      );
      expect(linked, isTrue);
      expect((await sessions.getSessionById(s1.id))!.diveId, 'dive-1');
      expect((await sessions.getSessionById(s2.id))!.diveId, 'dive-1');
      expect((await sessions.getSessionById(s3.id))!.diveId, 'dive-1');
    });

    test('a second dive that already has a session does not steal a third '
        "check that belongs to the first dive's group", () async {
      await insertDive('dive-1', diveStart);
      await insertDive('dive-0', diveStart.subtract(const Duration(days: 10)));
      final earlier = await sessionStartedAt(
        diveStart.subtract(const Duration(days: 10, minutes: 30)),
      );
      await linker.autoLinkForDive(
        diveId: 'dive-0',
        diverId: null,
        diveStart: diveStart.subtract(const Duration(days: 10)),
      );
      expect((await sessions.getSessionById(earlier.id))!.diveId, 'dive-0');

      final s = await sessionStartedAt(
        diveStart.subtract(const Duration(hours: 1)),
      );
      await linker.autoLinkForDive(
        diveId: 'dive-1',
        diverId: null,
        diveStart: diveStart,
      );
      expect((await sessions.getSessionById(s.id))!.diveId, 'dive-1');
      // dive-0's own check is untouched: dive-0 stays between it and
      // dive-1, so it is still the closer next dive for `earlier`.
      expect((await sessions.getSessionById(earlier.id))!.diveId, 'dive-0');
    });
  });

  group('re-splitting a group when an older dive is imported afterwards', () {
    test('a dive imported between two already-linked checks steals the closer '
        'one, leaving the farther one linked to the original dive', () async {
      await insertDive('dive-late', diveStart);
      final c1 = await sessionStartedAt(
        diveStart.subtract(const Duration(days: 5)),
      );
      final c2 = await sessionStartedAt(
        diveStart.subtract(const Duration(hours: 1)),
      );
      await linker.autoLinkForDive(
        diveId: 'dive-late',
        diverId: null,
        diveStart: diveStart,
      );
      expect((await sessions.getSessionById(c1.id))!.diveId, 'dive-late');
      expect((await sessions.getSessionById(c2.id))!.diveId, 'dive-late');

      // dive-mid sits between c1 and c2: only c1 should move to it.
      final mid = diveStart.subtract(const Duration(days: 2));
      await insertDive('dive-mid', mid);
      await linker.autoLinkForDive(
        diveId: 'dive-mid',
        diverId: null,
        diveStart: mid,
      );

      expect((await sessions.getSessionById(c1.id))!.diveId, 'dive-mid');
      expect((await sessions.getSessionById(c2.id))!.diveId, 'dive-late');
    });

    test('the same end state is reached regardless of import order', () async {
      final c1 = await sessionStartedAt(
        diveStart.subtract(const Duration(days: 5)),
      );
      final c2 = await sessionStartedAt(
        diveStart.subtract(const Duration(hours: 1)),
      );
      final mid = diveStart.subtract(const Duration(days: 2));

      // Import the later dive first, then the earlier one -- opposite order
      // from the test above.
      await insertDive('dive-mid', mid);
      await linker.autoLinkForDive(
        diveId: 'dive-mid',
        diverId: null,
        diveStart: mid,
      );
      await insertDive('dive-late', diveStart);
      await linker.autoLinkForDive(
        diveId: 'dive-late',
        diverId: null,
        diveStart: diveStart,
      );

      expect((await sessions.getSessionById(c1.id))!.diveId, 'dive-mid');
      expect((await sessions.getSessionById(c2.id))!.diveId, 'dive-late');
    });
  });

  group('the anchor is completion, not start', () {
    test(
      'a long run that finished just before the splash still links',
      () async {
        await insertDive('dive-1', diveStart);
        // Started 4 h out but ticked off its last item 20 min before the
        // dive: it is this dive's checklist.
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

    test('a check that started earlier but finished later attaches to the '
        'later dive, because completion (not start) is the anchor', () async {
      final splitPoint = diveStart.subtract(const Duration(days: 10));
      await insertDive('dive-early', splitPoint);
      await insertDive('dive-late', diveStart);

      // Started well before dive-early, but only ticked its last item off
      // well after dive-early already happened (beyond the forward-grace
      // tolerance): it belongs to dive-late.
      final startedFirst = await sessionStartedAt(
        splitPoint.subtract(const Duration(hours: 2)),
        completedAt: splitPoint.add(const Duration(hours: 5)),
      );
      // Started later than the one above, but finished before dive-early:
      // it belongs to dive-early.
      final finishedFirst = await sessionStartedAt(
        splitPoint.subtract(const Duration(hours: 1)),
        completedAt: splitPoint.subtract(const Duration(minutes: 5)),
      );

      await linker.autoLinkForDive(
        diveId: 'dive-early',
        diverId: null,
        diveStart: splitPoint,
      );
      await linker.autoLinkForDive(
        diveId: 'dive-late',
        diverId: null,
        diveStart: diveStart,
      );

      expect(
        (await sessions.getSessionById(finishedFirst.id))!.diveId,
        'dive-early',
      );
      expect(
        (await sessions.getSessionById(startedFirst.id))!.diveId,
        'dive-late',
      );
    });

    test('an unfinished run still falls back to its start time', () async {
      await insertDive('dive-1', diveStart);
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
    // the row 4.5 h before the splash. Anchoring on that stamp would move the
    // run's anchor far from the dive; the run has not finished, so its start
    // is the only honest anchor.
    await insertDive('dive-1', diveStart);
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
