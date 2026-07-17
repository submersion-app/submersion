import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreDiveSessionRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = PreDiveSessionRepository();
    // Persist the template row so the session's template FK resolves.
    await PreDiveTemplateRepository().createTemplate(
      domain.PreDiveChecklistTemplate(
        id: 'tpl-1',
        name: 'CCR Build',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime.now();

  Future<void> insertDive(String id) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('$id', 0, 0, 0)",
    );
  }

  Future<int> tombstoneCount(String entityType, String recordId) async {
    final db = DatabaseService.instance.database;
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM deletion_log '
          'WHERE entity_type = ? AND record_id = ?',
          variables: [Variable(entityType), Variable(recordId)],
        )
        .get();
    return rows.first.read<int>('n');
  }

  domain.PreDiveChecklistTemplate template({bool strict = false}) =>
      domain.PreDiveChecklistTemplate(
        id: 'tpl-1',
        name: 'CCR Build',
        strictOrder: strict,
        createdAt: now,
        updatedAt: now,
      );

  domain.PreDiveSessionItem draft(String title, {int order = 0}) =>
      domain.PreDiveSessionItem(
        id: '',
        sessionId: '',
        title: title,
        sortOrder: order,
        createdAt: now,
        updatedAt: now,
      );

  Future<domain.PreDiveSession> start({bool strict = false}) =>
      repository.startSession(
        template: template(strict: strict),
        items: [draft('A'), draft('B', order: 1)],
      );

  test('startSession snapshots template name and strictOrder', () async {
    final session = await start(strict: true);
    expect(session.id, isNotEmpty);
    expect(session.templateName, 'CCR Build');
    expect(session.strictOrder, isTrue);
    expect(session.status, domain.PreDiveSessionStatus.inProgress);
    final items = await repository.getItemsForSession(session.id);
    expect(items.map((i) => i.title).toList(), ['A', 'B']);
    expect(items.every((i) => i.sessionId == session.id), isTrue);
    expect(items.every((i) => i.id.isNotEmpty), isTrue);
  });

  test('updateItemState stamps and clears completedAt', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.updateItemState(
      sessionId: session.id,
      itemId: items[0].id,
      state: domain.PreDiveItemState.done,
    );
    var reread = await repository.getItemsForSession(session.id);
    expect(reread[0].state, domain.PreDiveItemState.done);
    expect(reread[0].completedAt, isNotNull);
    await repository.updateItemState(
      sessionId: session.id,
      itemId: items[0].id,
      state: domain.PreDiveItemState.pending,
    );
    reread = await repository.getItemsForSession(session.id);
    expect(reread[0].completedAt, isNull);
  });

  test('flag with note and value round-trip', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.updateItemState(
      sessionId: session.id,
      itemId: items[1].id,
      state: domain.PreDiveItemState.flagged,
      valueNumber: 7.9,
      note: 'cell 2 sluggish',
    );
    final reread = await repository.getItemsForSession(session.id);
    expect(reread[1].state, domain.PreDiveItemState.flagged);
    expect(reread[1].valueNumber, 7.9);
    expect(reread[1].note, 'cell 2 sluggish');
  });

  test('completed sessions are immutable', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.completeSession(session.id);
    final locked = await repository.getSessionById(session.id);
    expect(locked!.status, domain.PreDiveSessionStatus.completed);
    expect(locked.completedAt, isNotNull);
    expect(
      () => repository.updateItemState(
        sessionId: session.id,
        itemId: items[0].id,
        state: domain.PreDiveItemState.done,
      ),
      throwsStateError,
    );
    expect(() => repository.completeSession(session.id), throwsStateError);
    expect(() => repository.abortSession(session.id), throwsStateError);
  });

  test('link and unlink work on locked sessions', () async {
    await insertDive('dive-1');
    final session = await start();
    await repository.completeSession(session.id);
    await repository.linkToDive(session.id, 'dive-1');
    expect((await repository.getSessionForDive('dive-1'))!.id, session.id);
    expect(await repository.getUnlinkedSessions(), isEmpty);
    await repository.unlinkFromDive(session.id);
    expect(await repository.getSessionForDive('dive-1'), isNull);
    expect(await repository.getUnlinkedSessions(), hasLength(1));
  });

  test('getActiveSession returns latest inProgress only', () async {
    final s1 = await start();
    await repository.completeSession(s1.id);
    final s2 = await start();
    expect((await repository.getActiveSession())!.id, s2.id);
    await repository.abortSession(s2.id);
    expect(await repository.getActiveSession(), isNull);
  });

  test('deleteSession tombstones session and items', () async {
    final session = await start();
    final items = await repository.getItemsForSession(session.id);
    await repository.deleteSession(session.id);
    expect(await repository.getSessionById(session.id), isNull);
    expect(await repository.getItemsForSession(session.id), isEmpty);
    expect(items, hasLength(2));
    expect(await tombstoneCount('preDiveSessions', session.id), 1);
    for (final it in items) {
      expect(await tombstoneCount('preDiveSessionItems', it.id), 1);
    }
  });
}
