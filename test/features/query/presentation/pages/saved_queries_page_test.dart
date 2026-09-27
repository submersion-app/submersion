import 'dart:async';

import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/query/presentation/pages/saved_queries_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../../dive_log/query/dive_query_fixture.dart';

void main() {
  late AppDatabase db;
  late SavedQueryRepository repo;
  final depth = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30, null),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
    repo = SavedQueryRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: [...overrides, ...extraOverrides],
        child: const SavedQueriesPage(),
      ),
    );
    final element = tester.element(find.byType(SavedQueriesPage));
    await ProviderScope.containerOf(
      element,
    ).read(currentDiverIdProvider.notifier).setCurrentDiver('me');
    await tester.pumpAndSettle();
  }

  testWidgets('lists queries with their printed text and renames one', (
    tester,
  ) async {
    await repo.create(
      subject: QuerySubject.dives,
      name: 'Deep',
      node: depth,
      diverId: 'me',
    );
    await pump(tester);
    expect(find.text('Deep'), findsOneWidget);
    expect(find.text('depth > 30'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Deeper');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Deeper'), findsOneWidget);
  });

  testWidgets('an unreadable row is flagged and can be deleted', (
    tester,
  ) async {
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db.customStatement(
      'INSERT INTO saved_queries (id, diver_id, subject, name, query_json, '
      'sort_order, created_at, updated_at) VALUES '
      "('bad', 'me', 'dives', 'Future', '{\"version\":99,\"node\":{}}', 0, "
      '$now, $now)',
    );
    await pump(tester);
    expect(find.text('Future'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Future'), findsNothing);
    expect(await repo.getById('bad'), isNull);
  });

  testWidgets('dragging a row persists the new order', (tester) async {
    final a = await repo.create(
      subject: QuerySubject.dives,
      name: 'A',
      node: depth,
      diverId: 'me',
    );
    final b = await repo.create(
      subject: QuerySubject.dives,
      name: 'B',
      node: depth,
      diverId: 'me',
    );
    await pump(tester);
    final handle = find.descendant(
      of: find.widgetWithText(ListTile, 'A'),
      matching: find.byIcon(Icons.drag_handle),
    );
    await tester.timedDrag(
      handle,
      const Offset(0, 150),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    final order = (await repo.getAll(
      subject: 'dives',
      diverId: 'me',
    )).map((q) => q.id);
    expect(order, [b.id, a.id]);
  });

  testWidgets('an empty list explains where queries come from', (tester) async {
    await pump(tester);
    expect(find.textContaining('No saved queries yet'), findsOneWidget);
  });

  testWidgets('a row with a deleted reference is flagged with a warning', (
    tester,
  ) async {
    await repo.create(
      subject: QuerySubject.dives,
      name: 'Old site',
      node: ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('gone', 'Old Wall'),
      ),
      diverId: 'me',
    );
    await pump(tester);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('a load failure shows a plain message, not the exception', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          savedQueryLoadsProvider(
            null,
          ).overrideWith((ref) async => throw StateError('db is locked')),
        ],
        child: const SavedQueriesPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('db is locked'), findsNothing);
  });

  testWidgets('a load failure is logged once, not on every rebuild', (
    tester,
  ) async {
    final logged = <String>[];
    final sub = LoggerService.logStream.listen((e) {
      if (e.message.contains('Failed to load saved queries')) {
        logged.add(e.message);
      }
    });
    addTearDown(sub.cancel);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          savedQueryLoadsProvider(
            null,
          ).overrideWith((ref) async => throw StateError('db is locked')),
        ],
        child: const SavedQueriesPage(),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      tester.element(find.byType(SavedQueriesPage)).markNeedsBuild();
      await tester.pump();
    }
    expect(logged, hasLength(1));
  });

  testWidgets('a row no diver owns cannot be dragged', (tester) async {
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db
        .into(db.savedQueries)
        .insert(
          SavedQueriesCompanion.insert(
            id: 'shared',
            subject: 'dives',
            name: 'Shared',
            queryJson: '{"version":1,"node":{"type":"text","words":["reef"]}}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await repo.create(
      subject: QuerySubject.dives,
      name: 'Mine',
      node: depth,
      diverId: 'me',
    );
    await pump(tester);
    Finder handleOf(String name) => find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.byIcon(Icons.drag_handle),
    );
    expect(handleOf('Mine'), findsOneWidget);
    expect(handleOf('Shared'), findsNothing);
  });

  testWidgets('a drop below rows no diver owns stays with the diver\'s own', (
    tester,
  ) async {
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db
        .into(db.savedQueries)
        .insert(
          SavedQueriesCompanion.insert(
            id: 'shared',
            subject: 'dives',
            name: 'Shared',
            queryJson: '{"version":1,"node":{"type":"text","words":["reef"]}}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final a = await repo.create(
      subject: QuerySubject.dives,
      name: 'A',
      node: depth,
      diverId: 'me',
    );
    final b = await repo.create(
      subject: QuerySubject.dives,
      name: 'B',
      node: depth,
      diverId: 'me',
    );
    // The write never lands, so the list shows only the local drop.
    final written = _PendingReorderRepository();
    await pump(
      tester,
      extraOverrides: [savedQueryRepositoryProvider.overrideWithValue(written)],
    );
    await tester.timedDrag(
      find.descendant(
        of: find.widgetWithText(ListTile, 'A'),
        matching: find.byIcon(Icons.drag_handle),
      ),
      const Offset(0, 400),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    double top(String name) =>
        tester.getTopLeft(find.widgetWithText(ListTile, name)).dy;
    expect(top('B'), lessThan(top('A')));
    expect(top('A'), lessThan(top('Shared')));
    // Only the diver's own queries are renumbered; the shared one is not sent.
    expect(written.orders.single, [b.id, a.id]);
  });

  testWidgets('a drag reorders only its own subject\'s queries', (
    tester,
  ) async {
    final a = await repo.create(
      subject: QuerySubject.dives,
      name: 'A',
      node: depth,
      diverId: 'me',
    );
    final b = await repo.create(
      subject: QuerySubject.dives,
      name: 'B',
      node: depth,
      diverId: 'me',
    );
    await repo.create(
      subject: QuerySubject.sites,
      name: 'C',
      node: TextNode(const ['reef']),
      diverId: 'me',
    );
    final written = _PendingReorderRepository();
    await pump(
      tester,
      extraOverrides: [savedQueryRepositoryProvider.overrideWithValue(written)],
    );
    Finder handleOf(String name) => find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.byIcon(Icons.drag_handle),
    );
    double top(String name) =>
        tester.getTopLeft(find.widgetWithText(ListTile, name)).dy;
    // The sites query dragged to the top stays after the dives queries.
    await tester.timedDrag(
      handleOf('C'),
      const Offset(0, -400),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(top('B'), lessThan(top('C')));
    // A dives drag renumbers the dives queries only.
    await tester.timedDrag(
      handleOf('B'),
      const Offset(0, -150),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(written.orders.last, [b.id, a.id]);
  });
}

/// Records each reorder and never finishes it, so a test sees the page's
/// own drop result rather than the reloaded rows.
class _PendingReorderRepository extends SavedQueryRepository {
  final orders = <List<String>>[];

  @override
  Future<void> reorder(List<String> orderedIds) {
    orders.add(orderedIds);
    return Completer<void>().future;
  }
}
