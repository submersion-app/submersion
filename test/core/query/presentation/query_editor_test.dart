import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_editor.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';
import 'query_value_editor_test.dart' show kTestBuilderStrings;

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({}),
    labels: const MapQueryLabels(
      fields: {'depth': 'Max depth', 'rating': 'Rating'},
    ),
    now: () => DateTime(2026, 9, 25),
  );
  const strings = QueryEditorStrings(
    tabText: 'Text',
    tabBuilder: 'Builder',
    hint: 'Type a query',
    save: 'Save query',
    builder: kTestBuilderStrings,
  );

  Widget host(
    QueryNode? value,
    ValueChanged<QueryNode?> onChanged, {
    VoidCallback? onSave,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: QueryEditor(
          context: context,
          value: value,
          onChanged: onChanged,
          strings: strings,
          onSave: onSave,
        ),
      ),
    ),
  );

  testWidgets('the builder round-trips a nested group typed in the text tab', (
    tester,
  ) async {
    QueryNode? value;
    await tester.pumpWidget(host(null, (n) => value = n));
    await tester.enterText(
      find.byType(TextField).first,
      'depth > 30 AND (rating >= 4 OR NOT rating:any)',
    );
    await tester.pump();
    expect(value, isNotNull);
    await tester.pumpWidget(host(value, (n) => value = n));
    await tester.tap(find.text('Builder'));
    await tester.pumpAndSettle();
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('Rating'), findsNWidgets(2));
    // Flip the nested group to AND and check the text tab prints it.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('group-1')),
        matching: find.text('All of'),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(host(value, (n) => value = n));
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'depth > 30 AND (rating >= 4 AND NOT rating:any)',
    );
  });

  testWidgets('save is enabled only with a query and calls back', (
    tester,
  ) async {
    var saved = 0;
    await tester.pumpWidget(host(null, (_) {}, onSave: () => saved++));
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text('Save query'),
              matching: find.bySubtype<ButtonStyleButton>(),
            ),
          )
          .enabled,
      isFalse,
    );
    final tree = ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30, null),
    );
    await tester.pumpWidget(host(tree, (_) {}, onSave: () => saved++));
    await tester.tap(find.text('Save query'));
    expect(saved, 1);
  });

  testWidgets('no onSave hides the button', (tester) async {
    await tester.pumpWidget(host(null, (_) {}));
    expect(find.text('Save query'), findsNothing);
  });
}
