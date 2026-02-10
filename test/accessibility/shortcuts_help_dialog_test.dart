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
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test shortcut',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    });

    testWidgets('renders category headers', (tester) async {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'Go to Dives',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.digit1),
        ),
        const ShortcutEntry(
          label: 'Search dives',
          category: 'Search',
          activator: SingleActivator(LogicalKeyboardKey.keyF),
        ),
      ]);

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('renders shortcut labels', (tester) async {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'New dive',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.keyN, meta: true),
        ),
        const ShortcutEntry(
          label: 'Close',
          category: 'General',
          activator: SingleActivator(LogicalKeyboardKey.escape),
        ),
      ]);

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.text('New dive'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('displays key chip for Escape', (tester) async {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Cancel',
          category: 'General',
          activator: SingleActivator(LogicalKeyboardKey.escape),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.text('Esc'), findsOneWidget);
    });

    testWidgets('has close button with tooltip', (tester) async {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      // find.byIcon returns the Icon widget, so use ancestor to get IconButton
      final closeButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.close),
          matching: find.byType(IconButton),
        ),
      );
      expect(closeButton.tooltip, 'Close');
    });

    testWidgets('dismisses when close button is tapped', (tester) async {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });

    testWidgets('shows all registered categories', (tester) async {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'Nav 1',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.digit1),
        ),
        const ShortcutEntry(
          label: 'Find dives',
          category: 'Search',
          activator: SingleActivator(LogicalKeyboardKey.keyF),
        ),
        const ShortcutEntry(
          label: 'Show help',
          category: 'Help',
          activator: SingleActivator(LogicalKeyboardKey.slash),
        ),
        const ShortcutEntry(
          label: 'Close dialog',
          category: 'General',
          activator: SingleActivator(LogicalKeyboardKey.escape),
        ),
      ]);

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
    });

    testWidgets('contains keyboard icon', (tester) async {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      showShortcutsHelpDialog(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard), findsOneWidget);
    });
  });
}
