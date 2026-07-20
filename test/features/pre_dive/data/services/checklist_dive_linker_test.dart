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
}
