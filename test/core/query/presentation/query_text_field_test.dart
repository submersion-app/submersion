import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_error_controller.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({
      QuerySubject.sites: {'Salt Pier': 's1'},
    }),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 9, 25),
  );
  const fieldKey = Key('query-text');

  Widget host({
    required QueryNode? value,
    required ValueChanged<QueryNode?> onChanged,
  }) => MaterialApp(
    home: Scaffold(
      body: QueryTextField(
        context: context,
        value: value,
        onChanged: onChanged,
        fieldKey: fieldKey,
      ),
    ),
  );

  QueryErrorHighlightController controllerOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(fieldKey)).controller!
          as QueryErrorHighlightController;

  testWidgets('a valid query is committed', (tester) async {
    QueryNode? committed;
    await tester.pumpWidget(host(value: null, onChanged: (n) => committed = n));
    await tester.enterText(find.byKey(fieldKey), 'depth > 30');
    await tester.pump();
    expect(
      committed,
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.gt,
        const NumberValue(30, null),
      ),
    );
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('a parse failure keeps the previous committed value', (
    tester,
  ) async {
    final calls = <QueryNode?>[];
    await tester.pumpWidget(host(value: null, onChanged: calls.add));
    await tester.enterText(find.byKey(fieldKey), 'depth > 30');
    await tester.pump();
    await tester.enterText(find.byKey(fieldKey), 'depth >');
    await tester.pump();
    expect(calls.length, 1);
    expect(find.textContaining('expected a value'), findsOneWidget);
    expect(controllerOf(tester).errorOffset, 7);
  });

  testWidgets('a misspelt field shows suggestions that replace the span', (
    tester,
  ) async {
    QueryNode? committed;
    await tester.pumpWidget(host(value: null, onChanged: (n) => committed = n));
    await tester.enterText(find.byKey(fieldKey), 'dpeth > 30');
    await tester.pump();
    expect(find.widgetWithText(ActionChip, 'depth'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'depth'));
    await tester.pump();
    expect(controllerOf(tester).text, 'depth > 30');
    expect(committed, isNotNull);
  });

  testWidgets('empty text commits null', (tester) async {
    final calls = <QueryNode?>[];
    await tester.pumpWidget(host(value: null, onChanged: calls.add));
    await tester.enterText(find.byKey(fieldKey), 'depth > 30');
    await tester.pump();
    await tester.enterText(find.byKey(fieldKey), '   ');
    await tester.pump();
    expect(calls, [isNotNull, isNull]);
  });

  testWidgets('a value set from outside is printed into the field', (
    tester,
  ) async {
    final tree = ConditionNode(
      FieldPath(['site']),
      QueryOp.eq,
      const RefValue('s1', 'Salt Pier'),
    );
    await tester.pumpWidget(host(value: null, onChanged: (_) {}));
    await tester.pumpWidget(host(value: tree, onChanged: (_) {}));
    await tester.pump();
    expect(controllerOf(tester).text, 'site = "Salt Pier"');
  });

  testWidgets('completions appear while typing and insert on tap', (
    tester,
  ) async {
    await tester.pumpWidget(host(value: null, onChanged: (_) {}));
    await tester.enterText(find.byKey(fieldKey), 'dep');
    await tester.pump();
    expect(find.widgetWithText(ActionChip, 'depth'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'depth'));
    await tester.pump();
    expect(controllerOf(tester).text, 'depth');
  });

  test('QueryErrorHighlightController underlines the error span only', () {
    final c = QueryErrorHighlightController(text: 'depth >> 30')
      ..setError(offset: 6, length: 2);
    final span = c.buildTextSpan(
      context: _FakeContext(),
      style: const TextStyle(),
      withComposing: false,
    );
    final children = span.children!.cast<TextSpan>();
    expect(children.map((s) => s.text), ['depth ', '>>', ' 30']);
    expect(children[1].style?.decoration, TextDecoration.underline);
    expect(children[0].style?.decoration, isNull);
    c.setError();
    expect(
      c
          .buildTextSpan(
            context: _FakeContext(),
            style: const TextStyle(),
            withComposing: false,
          )
          .children,
      isNull,
    );
  });
}

class _FakeContext extends Fake implements BuildContext {}
