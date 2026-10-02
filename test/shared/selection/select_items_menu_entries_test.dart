import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';

import '../../helpers/test_app.dart';

void main() {
  Widget host({
    required VoidCallback onSelect,
    ValueChanged<String>? onSelected,
  }) {
    return testApp(
      // Pinned: the assertions read the English label.
      locale: const Locale('en'),
      child: Scaffold(
        appBar: AppBar(
          actions: [
            PopupMenuButton<String>(
              key: const ValueKey('overflow'),
              onSelected: onSelected,
              itemBuilder: (context) => [
                ...selectItemsMenuEntries(context, onSelect: onSelect),
                const PopupMenuItem(value: 'other', child: Text('Other')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('shows "Select items" first, then a divider', (tester) async {
    await tester.pumpWidget(host(onSelect: () {}));
    await tester.tap(find.byKey(const ValueKey('overflow')));
    await tester.pumpAndSettle();

    final entry = find.byKey(selectItemsMenuKey);
    expect(entry, findsOneWidget);
    expect(
      find.descendant(of: entry, matching: find.text('Select items')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: entry, matching: find.byIcon(Icons.checklist)),
      findsOneWidget,
    );
    expect(find.byType(PopupMenuDivider), findsOneWidget);
    expect(
      tester.getTopLeft(entry).dy,
      lessThan(tester.getTopLeft(find.text('Other')).dy),
    );
  });

  testWidgets('choosing it calls onSelect and reports its value', (
    tester,
  ) async {
    var selects = 0;
    String? reported;
    await tester.pumpWidget(
      host(onSelect: () => selects++, onSelected: (v) => reported = v),
    );
    await tester.tap(find.byKey(const ValueKey('overflow')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(selectItemsMenuKey));
    await tester.pumpAndSettle();

    expect(selects, 1);
    // The value reaches onSelected too; it must match no other branch there.
    expect(reported, selectItemsMenuValue);
    expect(find.byKey(selectItemsMenuKey), findsNothing);
  });
}
