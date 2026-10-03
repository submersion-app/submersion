import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
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

  testWidgets('a name typed before the index loaded commits once it loads', (
    tester,
  ) async {
    final calls = <QueryNode?>[];
    Widget hostWith(QueryEditorContext c) => MaterialApp(
      home: Scaffold(
        body: QueryTextField(
          context: c,
          value: null,
          onChanged: calls.add,
          fieldKey: fieldKey,
        ),
      ),
    );
    final loading = context.copyWith(names: const MapNameResolver({}));
    await tester.pumpWidget(hostWith(loading));
    await tester.enterText(find.byKey(fieldKey), 'site = "Salt Pier"');
    await tester.pump();
    expect(calls, isEmpty);
    // The index arrives: the same text now resolves, with no edit.
    await tester.pumpWidget(hostWith(context));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.single, isA<ConditionNode>());
    expect(
      tester.widget<TextField>(find.byKey(fieldKey)).decoration!.errorText,
      isNull,
    );
  });

  group('suggestionsReplaceSpan', () {
    const text = 'deph > 30';
    QueryError err({int? offset, int? length}) => QueryError(
      QueryErrorCode.unknownField,
      args: const {'name': 'deph'},
      offset: offset,
      length: length,
      suggestions: const ['depth'],
    );

    test('a span inside the text can be replaced', () {
      expect(suggestionsReplaceSpan(err(offset: 0, length: 4), text), isTrue);
    });

    test('an error with no span offers no replacement', () {
      // A validator error names a path, not a place in the text: a chip
      // would insert at the start of the field instead of replacing.
      expect(suggestionsReplaceSpan(err(), text), isFalse);
      expect(suggestionsReplaceSpan(err(offset: 0), text), isFalse);
    });

    test('a span past the end of the text offers no replacement', () {
      expect(suggestionsReplaceSpan(err(offset: 6, length: 9), text), isFalse);
    });

    test('an error with no suggestions offers none', () {
      const bare = QueryError(
        QueryErrorCode.unknownField,
        offset: 0,
        length: 4,
      );
      expect(suggestionsReplaceSpan(bare, text), isFalse);
    });
  });

  testWidgets('the hint uses the body font, typed text stays monospace', (
    tester,
  ) async {
    // A monospace hint runs about 0.6 em a glyph, too wide for a phone's
    // search row; the hint is prose, only the typed query is code.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            fieldKey: fieldKey,
            hintText: 'Search, or try depth > 30m',
          ),
        ),
      ),
    );
    final body = Theme.of(
      tester.element(find.byKey(fieldKey)),
    ).textTheme.bodyLarge!.fontFamily;
    expect(body, isNot('monospace'));
    final hint = tester.renderObject<RenderParagraph>(
      find.text('Search, or try depth > 30m'),
    );
    expect(hint.text.style!.fontFamily, body);
    final field = tester.widget<TextField>(find.byKey(fieldKey));
    expect(field.style!.fontFamily, 'monospace');
  });

  testWidgets('reports when the text stops and starts parsing', (tester) async {
    final validity = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            onValidityChanged: validity.add,
            fieldKey: fieldKey,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(fieldKey), 'manta');
    await tester.enterText(find.byKey(fieldKey), 'manta depth >');
    await tester.enterText(find.byKey(fieldKey), 'manta depth >=');
    // The same committed value as before the error: still reported valid.
    await tester.enterText(find.byKey(fieldKey), 'manta');
    await tester.enterText(find.byKey(fieldKey), '');
    expect(validity, [false, true]);
  });

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

  testWidgets('uses an outside focus node and leaves it undisposed', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            fieldKey: fieldKey,
            focusNode: focus,
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(fieldKey)).focusNode,
      same(focus),
    );
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    // Still usable: the field did not dispose a node it does not own.
    focus.addListener(() {});
  });

  testWidgets('Escape in the field calls onEscape', (tester) async {
    var escaped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            fieldKey: fieldKey,
            onEscape: () => escaped++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(fieldKey));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(escaped, 1);
  });

  testWidgets('a replaced outside focus node no longer drives the field', (
    tester,
  ) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    // [first] moves to another widget after the swap; if the field kept
    // listening to it, focusing it once the field is gone would call
    // setState on a disposed state.
    Widget host(FocusNode fieldNode, {bool field = true, bool other = false}) =>
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                if (other) Focus(focusNode: first, child: const SizedBox()),
                if (field)
                  QueryTextField(
                    context: context,
                    value: null,
                    onChanged: (_) {},
                    fieldKey: fieldKey,
                    focusNode: fieldNode,
                  ),
              ],
            ),
          ),
        );
    await tester.pumpWidget(host(first));
    await tester.pumpWidget(host(second, other: true));
    expect(
      tester.widget<TextField>(find.byKey(fieldKey)).focusNode,
      same(second),
    );
    await tester.pumpWidget(host(second, field: false, other: true));
    first.requestFocus();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(first.hasFocus, isTrue);
  });
}

class _FakeContext extends Fake implements BuildContext {}
