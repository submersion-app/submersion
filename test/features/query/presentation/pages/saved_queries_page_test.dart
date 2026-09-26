import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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

  Future<void> pump(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: overrides,
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
}
