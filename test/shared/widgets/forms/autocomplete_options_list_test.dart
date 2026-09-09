import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/autocomplete_options_list.dart';

/// Minimal RawAutocomplete host so the options list sees the framework's
/// AutocompleteHighlightedOption notifier, exactly as it does in the app.
Widget _host({
  required List<String> suggestions,
  required void Function(String) onSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RawAutocomplete<String>(
        optionsBuilder: (value) => value.text.isEmpty
            ? const Iterable<String>.empty()
            : suggestions.where(
                (s) => s.toLowerCase().contains(value.text.toLowerCase()),
              ),
        onSelected: onSelected,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
            TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) => onFieldSubmitted(),
            ),
        optionsViewBuilder: (context, onSelect, options) =>
            AutocompleteOptionsList<String>(
              options: options,
              onSelected: onSelect,
              labelFor: (option) => option,
            ),
      ),
    ),
  );
}

bool _isSelected(WidgetTester tester, String label) =>
    tester.widget<ListTile>(find.widgetWithText(ListTile, label)).selected;

void main() {
  testWidgets('first option starts highlighted', (tester) async {
    await tester.pumpWidget(
      _host(
        suggestions: const ['Diving', 'Dining', 'Medical'],
        onSelected: (_) {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'di');
    await tester.pumpAndSettle();

    expect(_isSelected(tester, 'Diving'), isTrue);
    expect(_isSelected(tester, 'Dining'), isFalse);
  });

  testWidgets('arrow down moves the highlight to the next option', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        suggestions: const ['Diving', 'Dining', 'Medical'],
        onSelected: (_) {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'di');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_isSelected(tester, 'Diving'), isFalse);
    expect(_isSelected(tester, 'Dining'), isTrue);
  });

  testWidgets('arrow up moves the highlight back', (tester) async {
    await tester.pumpWidget(
      _host(
        suggestions: const ['Diving', 'Dining', 'Medical'],
        onSelected: (_) {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'di');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_isSelected(tester, 'Diving'), isTrue);
  });

  testWidgets('submitting commits the highlighted option', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _host(
        suggestions: const ['Diving', 'Dining', 'Medical'],
        onSelected: (value) => selected = value,
      ),
    );
    await tester.enterText(find.byType(TextField), 'di');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected, 'Dining');
  });

  testWidgets('tapping an option still selects it', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _host(
        suggestions: const ['Diving', 'Dining', 'Medical'],
        onSelected: (value) => selected = value,
      ),
    );
    await tester.enterText(find.byType(TextField), 'di');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Medical'));
    await tester.pumpAndSettle();

    expect(selected, 'Medical');
  });

  testWidgets('leadingFor renders a leading widget per option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RawAutocomplete<String>(
            optionsBuilder: (value) =>
                value.text.isEmpty ? const <String>[] : const ['Diving'],
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) => TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: (_) => onFieldSubmitted(),
                ),
            optionsViewBuilder: (context, onSelect, options) =>
                AutocompleteOptionsList<String>(
                  options: options,
                  onSelected: onSelect,
                  labelFor: (option) => option,
                  leadingFor: (context, option) => const Icon(Icons.label),
                ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'di');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.label), findsOneWidget);
  });

  testWidgets('jumping to an option outside the built range scrolls to it', (
    tester,
  ) async {
    final many = List<String>.generate(
      40,
      (i) => 'Option ${i.toString().padLeft(2, '0')}',
    );
    await tester.pumpWidget(_host(suggestions: many, onSelected: (_) {}));
    await tester.enterText(find.byType(TextField), 'Option');
    await tester.pumpAndSettle();

    // Ctrl+ArrowDown highlights the last option, which is far outside the
    // rows the ListView has built.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final row = find.widgetWithText(ListTile, 'Option 39');
    expect(row, findsOneWidget);
    expect(tester.widget<ListTile>(row).selected, isTrue);

    // It must actually be on screen, not merely built in the cache extent.
    final listRect = tester.getRect(find.byType(ListView));
    final rowRect = tester.getRect(row);
    expect(rowRect.top, greaterThanOrEqualTo(listRect.top - 0.5));
    expect(rowRect.bottom, lessThanOrEqualTo(listRect.bottom + 0.5));
  });

  testWidgets('stepping down a long list keeps the highlight on screen', (
    tester,
  ) async {
    final many = List<String>.generate(
      40,
      (i) => 'Option ${i.toString().padLeft(2, '0')}',
    );
    await tester.pumpWidget(_host(suggestions: many, onSelected: (_) {}));
    await tester.enterText(find.byType(TextField), 'Option');
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    final row = find.widgetWithText(ListTile, 'Option 12');
    expect(row, findsOneWidget);
    expect(tester.widget<ListTile>(row).selected, isTrue);

    final listRect = tester.getRect(find.byType(ListView));
    final rowRect = tester.getRect(row);
    expect(rowRect.top, greaterThanOrEqualTo(listRect.top - 0.5));
    expect(rowRect.bottom, lessThanOrEqualTo(listRect.bottom + 0.5));
  });
}
