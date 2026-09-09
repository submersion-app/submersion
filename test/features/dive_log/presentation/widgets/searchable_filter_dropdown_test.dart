import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/utils/filter_option_search.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';

void main() {
  const allSitesLabel = 'All sites';
  const searchHint = 'Type to search sites';

  final options = [
    FilterDropdownOption(
      value: 's1',
      label: 'Blue Hole',
      searchText: buildFilterSearchText(['Blue Hole', 'Dahab', 'Egypt']),
    ),
    FilterDropdownOption(
      value: 's2',
      label: 'Cancún Reef',
      searchText: buildFilterSearchText(['Cancún Reef', 'Cancún', 'Mexico']),
    ),
    FilterDropdownOption(
      value: 's3',
      label: 'Thistlegorm',
      searchText: buildFilterSearchText(['Thistlegorm', 'Red Sea', 'Egypt']),
    ),
  ];

  /// Every value reported by the dropdown, so a test can tell "called with
  /// null" apart from "never called".
  late List<String?> reported;

  Future<void> pumpDropdown(WidgetTester tester, {String? value}) async {
    reported = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 400,
                  child: SearchableFilterDropdown<String>(
                    value: value,
                    options: options,
                    allOptionLabel: allSitesLabel,
                    searchHintText: searchHint,
                    icon: Icons.location_on,
                    onChanged: reported.add,
                  ),
                ),
                // Another field in the sheet for focus to move to, standing
                // in for the depth and duration fields that surround these
                // dropdowns.
                const SizedBox(
                  width: 400,
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Elsewhere'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The entries currently rendered in the open suggestion list.
  Iterable<String> openMenuLabels(WidgetTester tester) {
    return tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(searchableFilterOptionsKey),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '')
        .where((label) => label.isNotEmpty);
  }

  /// The dropdown's own text field, as opposed to the sibling field the
  /// tests use to move focus away.
  Finder dropdownField() => find.descendant(
    of: find.byType(SearchableFilterDropdown<String>),
    matching: find.byType(TextField),
  );

  /// The suggestion row offering [label], scoped to the suggestion list.
  Finder suggestion(String label) => find.descendant(
    of: find.byKey(searchableFilterOptionsKey),
    matching: find.widgetWithText(InkWell, label),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(dropdownField());
    await tester.pumpAndSettle();
  }

  testWidgets('shows the all-options label when nothing is selected', (
    tester,
  ) async {
    await pumpDropdown(tester);

    expect(find.text(allSitesLabel), findsOneWidget);
  });

  // The point of the hint is to tell the diver the field can be typed into,
  // which only works if it is on screen before they touch it. Asserted on the
  // decoration rather than with find.text: InputDecorator builds a hintText
  // into the tree even while it is holding it at zero opacity, so find.text
  // cannot tell a shown hint from a hidden one.
  testWidgets('shows the search hint without being touched first', (
    tester,
  ) async {
    await pumpDropdown(tester);

    final decoration = tester.widget<TextField>(dropdownField()).decoration;
    expect(decoration?.helperText, searchHint);
    expect(
      decoration?.hintText,
      isNull,
      reason: 'a hint under a field that always carries text is never seen',
    );
    expect(find.text(searchHint), findsOneWidget);
  });

  testWidgets('shows the selected option label', (tester) async {
    await pumpDropdown(tester, value: 's3');

    expect(find.text('Thistlegorm'), findsOneWidget);
    expect(find.text(allSitesLabel), findsNothing);
  });

  testWidgets('offers every option plus the all-options entry when opened', (
    tester,
  ) async {
    await pumpDropdown(tester);
    await openMenu(tester);

    expect(
      openMenuLabels(tester),
      containsAll(<String>[
        allSitesLabel,
        'Blue Hole',
        'Cancún Reef',
        'Thistlegorm',
      ]),
    );
  });

  testWidgets('typing narrows the menu to matching options', (tester) async {
    await pumpDropdown(tester);
    await openMenu(tester);

    await tester.enterText(dropdownField(), 'thist');
    await tester.pumpAndSettle();

    expect(openMenuLabels(tester), contains('Thistlegorm'));
    expect(openMenuLabels(tester), isNot(contains('Blue Hole')));
  });

  testWidgets('typing matches option text that is not shown in the label', (
    tester,
  ) async {
    await pumpDropdown(tester);
    await openMenu(tester);

    await tester.enterText(dropdownField(), 'egypt');
    await tester.pumpAndSettle();

    expect(
      openMenuLabels(tester),
      containsAll(<String>['Blue Hole', 'Thistlegorm']),
    );
    expect(openMenuLabels(tester), isNot(contains('Cancún Reef')));
  });

  testWidgets('typing ignores diacritics', (tester) async {
    await pumpDropdown(tester);
    await openMenu(tester);

    await tester.enterText(dropdownField(), 'cancun');
    await tester.pumpAndSettle();

    expect(openMenuLabels(tester), contains('Cancún Reef'));
    expect(openMenuLabels(tester), isNot(contains('Blue Hole')));
  });

  testWidgets('selecting a narrowed option reports its value', (tester) async {
    await pumpDropdown(tester);
    await openMenu(tester);

    await tester.enterText(dropdownField(), 'blue');
    await tester.pumpAndSettle();
    await tester.tap(suggestion('Blue Hole'));
    await tester.pumpAndSettle();

    expect(reported, ['s1']);
  });

  // The host applies the new filter on its own schedule, so the field must
  // show what was just picked without waiting to be rebuilt with it.
  testWidgets('the field shows the option just selected', (tester) async {
    await pumpDropdown(tester, value: 's3');
    await openMenu(tester);

    await tester.enterText(dropdownField(), 'blue');
    await tester.pumpAndSettle();
    await tester.tap(suggestion('Blue Hole'));
    await tester.pumpAndSettle();

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(
      find.text('Thistlegorm'),
      findsNothing,
      reason: 'the previous selection must not come back',
    );
  });

  testWidgets('selecting the all-options entry reports null', (tester) async {
    await pumpDropdown(tester, value: 's1');
    await openMenu(tester);

    await tester.tap(suggestion(allSitesLabel));
    await tester.pumpAndSettle();

    expect(reported, [null]);
  });

  testWidgets('reopening after an unmatched query offers every option again', (
    tester,
  ) async {
    await pumpDropdown(tester, value: 's3');
    await openMenu(tester);

    await tester.enterText(dropdownField(), 'no such site');
    await tester.pumpAndSettle();
    expect(openMenuLabels(tester), isEmpty);

    // Dismiss without picking anything, then come back.
    await tester.tap(find.widgetWithText(TextField, 'Elsewhere'));
    await tester.pumpAndSettle();
    await openMenu(tester);

    expect(
      openMenuLabels(tester),
      containsAll(<String>[allSitesLabel, 'Blue Hole', 'Thistlegorm']),
      reason: 'a dead-end query must not strand the diver with an empty menu',
    );
    expect(reported, isEmpty, reason: 'no selection was made');
  });

  // A site can be renamed, or a host can resolve its list after first build,
  // without the selected id ever changing.
  testWidgets('follows a renamed option even though the value is unchanged', (
    tester,
  ) async {
    Future<void> pumpWithLabel(String label) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SearchableFilterDropdown<String>(
                  value: 's1',
                  options: [
                    FilterDropdownOption(value: 's1', label: label),
                    FilterDropdownOption(value: 's2', label: 'Coral Garden'),
                  ],
                  allOptionLabel: allSitesLabel,
                  searchHintText: searchHint,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWithLabel('Blue Hole');
    expect(find.text('Blue Hole'), findsOneWidget);

    await pumpWithLabel('Blue Hole (north)');

    expect(find.text('Blue Hole (north)'), findsOneWidget);
    expect(find.text('Blue Hole'), findsNothing);
  });

  // The prepared rows are cached, so a genuinely longer list has to invalidate
  // that cache rather than keep offering the old one.
  testWidgets('offers an option that appears after the first build', (
    tester,
  ) async {
    Future<void> pumpWith(List<FilterDropdownOption<String>> opts) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SearchableFilterDropdown<String>(
                  value: null,
                  options: opts,
                  allOptionLabel: allSitesLabel,
                  searchHintText: searchHint,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWith([FilterDropdownOption(value: 's1', label: 'Blue Hole')]);
    await pumpWith([
      FilterDropdownOption(value: 's1', label: 'Blue Hole'),
      FilterDropdownOption(value: 's9', label: 'Late Arrival'),
    ]);

    await tester.tap(dropdownField());
    await tester.pumpAndSettle();

    expect(openMenuLabels(tester), contains('Late Arrival'));
  });

  /// The background colour of the suggestion row offering [label].
  Color? rowColor(WidgetTester tester, String label) => tester
      .widget<Container>(
        find.descendant(
          of: suggestion(label),
          matching: find.byType(Container),
        ),
      )
      .color;

  // Enter commits whichever row the arrow keys have moved to, so a keyboard
  // user has to be able to see which one that is.
  testWidgets('marks the row the arrow keys moved to', (tester) async {
    await pumpDropdown(tester);
    await openMenu(tester);

    final focusColor = Theme.of(
      tester.element(find.byType(SearchableFilterDropdown<String>)),
    ).focusColor;

    // The all-options row starts highlighted; one press moves to the first site.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(rowColor(tester, 'Blue Hole'), focusColor);
    expect(rowColor(tester, allSitesLabel), isNull);
    expect(rowColor(tester, 'Thistlegorm'), isNull);
  });

  testWidgets('the highlighted row is exposed as selected to semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpDropdown(tester);
    await openMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(suggestion('Blue Hole')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(suggestion('Thistlegorm')).flagsCollection.isSelected,
      isNot(Tristate.isTrue),
    );
    handle.dispose();
  });

  testWidgets('enter commits the row the arrow keys moved to', (tester) async {
    await pumpDropdown(tester);
    await openMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    // Enter reaches a TextField through the text input channel, not as a raw
    // key event, so a sendKeyEvent here would prove nothing.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(reported, ['s1']);
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('moving focus away discards an uncommitted query', (
    tester,
  ) async {
    await pumpDropdown(tester, value: 's3');
    await openMenu(tester);

    await tester.enterText(dropdownField(), 'no such site');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextField, 'Elsewhere'));
    await tester.pumpAndSettle();

    expect(reported, isEmpty, reason: 'no selection was made');
    expect(
      find.text('Thistlegorm'),
      findsOneWidget,
      reason: 'the field must show the filter that is actually in force',
    );
    expect(find.text('no such site'), findsNothing);
  });
}
