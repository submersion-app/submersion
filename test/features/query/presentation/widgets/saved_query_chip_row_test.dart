import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/features/query/presentation/widgets/saved_query_chip_row.dart';

import '../../../../helpers/test_app.dart';

void main() {
  SavedQuery saved(String id, String name) => SavedQuery(
    id: id,
    subject: 'dives',
    name: name,
    queryJson: '{}',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final depth = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30, null),
  );

  Widget host(
    List<SavedQueryLoad> loads,
    ValueChanged<SavedQueryLoad> onApply,
  ) => testApp(
    locale: const Locale('en'),
    overrides: [
      savedQueryLoadsProvider('dives').overrideWith((ref) async => loads),
    ],
    child: SavedQueryChipRow(subject: QuerySubject.dives, onApply: onApply),
  );

  testWidgets('renders nothing with no saved queries', (tester) async {
    await tester.pumpWidget(host(const [], (_) {}));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a readable query applies on tap', (tester) async {
    SavedQueryLoad? applied;
    await tester.pumpWidget(
      host([SavedQueryLoad(saved('a', 'Deep'), node: depth)], (l) {
        applied = l;
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Deep'));
    expect(applied?.node, depth);
  });

  testWidgets(
    'a flagged query applies with a warning; an unreadable one explains itself',
    (tester) async {
      final applied = <SavedQueryLoad>[];
      await tester.pumpWidget(
        host([
          SavedQueryLoad(
            saved('a', 'Old site'),
            node: depth,
            problem: SavedQueryProblem.unresolvedRef,
            detail: 'site',
          ),
          SavedQueryLoad(
            saved('b', 'Future'),
            problem: SavedQueryProblem.unreadable,
            detail: 'version 99',
          ),
        ], applied.add),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Old site'));
      await tester.tap(find.widgetWithText(ActionChip, 'Future'));
      await tester.pump();
      expect(applied.map((l) => l.saved.id), ['a']);
      expect(find.textContaining('version 99'), findsOneWidget);
    },
  );
}
