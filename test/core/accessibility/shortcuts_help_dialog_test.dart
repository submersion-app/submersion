import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/accessibility/shortcuts_help_dialog.dart';

void main() {
  setUp(() {
    ShortcutCatalog.instance.clear();
  });

  group('ShortcutsHelpDialog', () {
    testWidgets('renders dialog title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutsHelpDialog())),
      );

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    });

    testWidgets('renders keyboard icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutsHelpDialog())),
      );

      expect(find.byIcon(Icons.keyboard), findsOneWidget);
    });

    testWidgets('displays registered shortcuts grouped by category', (
      tester,
    ) async {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'New dive',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.keyN, meta: true),
          isGlobal: true,
        ),
        const ShortcutEntry(
          label: 'Search',
          category: 'Search',
          activator: SingleActivator(LogicalKeyboardKey.keyF, meta: true),
          isGlobal: true,
        ),
        const ShortcutEntry(
          label: 'Close',
          category: 'General',
          activator: SingleActivator(LogicalKeyboardKey.escape),
          isGlobal: true,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutsHelpDialog())),
      );

      // Category headers
      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);

      // Shortcut labels
      expect(find.text('New dive'), findsOneWidget);
      // "Search" appears as both category header and shortcut label
      expect(find.text('Search'), findsWidgets);
      // "Close" may appear as label and as IconButton tooltip
      expect(find.text('Close'), findsWidgets);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showShortcutsHelpDialog(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });

    testWidgets('showShortcutsHelpDialog opens the dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showShortcutsHelpDialog(context),
                child: const Text('Show Shortcuts'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Shortcuts'));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('displays empty state when no shortcuts registered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutsHelpDialog())),
      );

      // Title should still render
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      // But no category headers
      expect(find.text('Navigation'), findsNothing);
      expect(find.text('Search'), findsNothing);
    });
  });
}
