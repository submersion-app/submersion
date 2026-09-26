import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
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
    ValueChanged<SavedQueryLoad> onApply, {
    Locale locale = const Locale('en'),
  }) => testApp(
    locale: locale,
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
      expect(
        find.text('Cannot be read by this version of the app'),
        findsOneWidget,
      );
      // The detail is the loader's English text, never shown.
      expect(find.textContaining('version 99'), findsNothing);
    },
  );

  testWidgets('an invalid query explains itself in the diver\'s language', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [
          SavedQueryLoad(
            saved('c', 'Warp'),
            problem: SavedQueryProblem.invalid,
            detail: 'unknown field "warp"',
            error: const QueryError(
              QueryErrorCode.unknownField,
              args: {'name': 'warp'},
            ),
          ),
        ],
        (_) {},
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Warp'));
    await tester.pump();
    expect(
      find.text(
        'Verwendet etwas, das diese Version nicht kennt: '
        'unbekanntes Feld "warp"',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('unknown field'), findsNothing);
  });

  testWidgets('a query for an unknown list says which list', (tester) async {
    await tester.pumpWidget(
      host([
        SavedQueryLoad(
          saved('d', 'Whales'),
          problem: SavedQueryProblem.unknownSubject,
          detail: 'whales',
        ),
      ], (_) {}),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Whales'));
    await tester.pump();
    expect(
      find.text('For a list this version does not have: whales'),
      findsOneWidget,
    );
  });
}
