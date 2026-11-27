import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';
import 'package:submersion/core/query/syntax/query_parse_context.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/ui/app_actions.dart';

import '../fixtures/fixture_registry.dart';

/// The field under the app's actions, where a tap off a focused field drops
/// its focus, a finger's included (#4813).
void main() {
  final context = QueryEditorContext(
    registry: fixtureRegistry,
    root: fixtureDives,
    prefs: kMetricPrefs,
    names: const MapNameResolver({}),
    labels: const MapQueryLabels(),
    now: () => DateTime(2026, 9, 25),
  );
  const fieldKey = Key('query-text');

  testWidgets('a suggestion chip counts as part of the field', (tester) async {
    // The chips sit outside the TextField: they must join its tap region,
    // or a tap on one drops the focus and puts a phone's keyboard away.
    await tester.pumpWidget(
      MaterialApp(
        actions: appActions(),
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            fieldKey: fieldKey,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(fieldKey), 'dpeth > 30');
    await tester.pump();

    await tester.tap(find.widgetWithText(ActionChip, 'depth'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byKey(fieldKey));
    expect(field.controller!.text, 'depth > 30');
    expect(field.focusNode!.hasFocus, isTrue);
  });
}
