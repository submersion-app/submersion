import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/shortcut_registry.dart';

void main() {
  group('ShortcutEntry', () {
    test('displayKey shows Cmd prefix on macOS', () {
      const entry = ShortcutEntry(
        label: 'Test',
        category: 'General',
        activator: SingleActivator(LogicalKeyboardKey.keyN, meta: true),
      );

      expect(entry.displayKey(TargetPlatform.macOS), equals('Cmd+N'));
    });

    test('displayKey shows Ctrl prefix on Windows/Linux', () {
      const entry = ShortcutEntry(
        label: 'Test',
        category: 'General',
        activator: SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
        ),
      );

      expect(entry.displayKey(TargetPlatform.windows), equals('Ctrl+N'));
      expect(entry.displayKey(TargetPlatform.linux), equals('Ctrl+N'));
    });

    test('displayKey shows Shift modifier', () {
      const entry = ShortcutEntry(
        label: 'Test',
        category: 'General',
        activator: SingleActivator(
          LogicalKeyboardKey.keyS,
          meta: true,
          shift: true,
        ),
      );

      expect(entry.displayKey(TargetPlatform.macOS), equals('Cmd+Shift+S'));
    });

    test('displayKey shows Alt/Option modifier', () {
      const entry = ShortcutEntry(
        label: 'Test',
        category: 'General',
        activator: SingleActivator(
          LogicalKeyboardKey.keyA,
          meta: true,
          alt: true,
        ),
      );

      expect(entry.displayKey(TargetPlatform.macOS), equals('Cmd+Option+A'));
    });

    test('displayKey shows Esc for escape key', () {
      const entry = ShortcutEntry(
        label: 'Close',
        category: 'General',
        activator: SingleActivator(LogicalKeyboardKey.escape),
      );

      expect(entry.displayKey(TargetPlatform.macOS), equals('Esc'));
    });

    test('displayKey shows / for slash key', () {
      const entry = ShortcutEntry(
        label: 'Help',
        category: 'Help',
        activator: SingleActivator(LogicalKeyboardKey.slash, meta: true),
      );

      expect(entry.displayKey(TargetPlatform.macOS), equals('Cmd+/'));
    });

    test('displayKey shows , for comma key', () {
      const entry = ShortcutEntry(
        label: 'Settings',
        category: 'Navigation',
        activator: SingleActivator(LogicalKeyboardKey.comma, meta: true),
      );

      expect(entry.displayKey(TargetPlatform.macOS), equals('Cmd+,'));
    });

    test('displayKey shows digit keys correctly', () {
      const entry = ShortcutEntry(
        label: 'Tab 1',
        category: 'Navigation',
        activator: SingleActivator(LogicalKeyboardKey.digit1, meta: true),
      );

      expect(entry.displayKey(TargetPlatform.macOS), equals('Cmd+1'));
    });
  });

  group('ShortcutCatalog', () {
    setUp(() {
      ShortcutCatalog.instance.clear();
    });

    test('starts empty', () {
      expect(ShortcutCatalog.instance.entries, isEmpty);
    });

    test('register adds a single entry', () {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test',
          category: 'General',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      expect(ShortcutCatalog.instance.entries, hasLength(1));
      expect(ShortcutCatalog.instance.entries.first.label, equals('Test'));
    });

    test('registerAll adds multiple entries', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'Entry 1',
          category: 'Nav',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
        const ShortcutEntry(
          label: 'Entry 2',
          category: 'Nav',
          activator: SingleActivator(LogicalKeyboardKey.keyB),
        ),
      ]);

      expect(ShortcutCatalog.instance.entries, hasLength(2));
    });

    test('entries is unmodifiable', () {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test',
          category: 'General',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      expect(
        () => ShortcutCatalog.instance.entries.add(
          const ShortcutEntry(
            label: 'Hacked',
            category: 'Bad',
            activator: SingleActivator(LogicalKeyboardKey.keyZ),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('byCategory groups entries correctly', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'New',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.keyN),
        ),
        const ShortcutEntry(
          label: 'Search',
          category: 'Search',
          activator: SingleActivator(LogicalKeyboardKey.keyF),
        ),
        const ShortcutEntry(
          label: 'Settings',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.comma),
        ),
      ]);

      final grouped = ShortcutCatalog.instance.byCategory;
      expect(grouped.keys, contains('Navigation'));
      expect(grouped.keys, contains('Search'));
      expect(grouped['Navigation'], hasLength(2));
      expect(grouped['Search'], hasLength(1));
    });

    test('byCategory sorts categories in priority order', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'Help',
          category: 'Help',
          activator: SingleActivator(LogicalKeyboardKey.slash),
        ),
        const ShortcutEntry(
          label: 'Search',
          category: 'Search',
          activator: SingleActivator(LogicalKeyboardKey.keyF),
        ),
        const ShortcutEntry(
          label: 'Nav',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.keyN),
        ),
        const ShortcutEntry(
          label: 'Escape',
          category: 'General',
          activator: SingleActivator(LogicalKeyboardKey.escape),
        ),
      ]);

      final keys = ShortcutCatalog.instance.byCategory.keys.toList();
      expect(keys, equals(['Navigation', 'Search', 'General', 'Help']));
    });

    test('unregisterCategory removes all entries in a category', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'New',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.keyN),
        ),
        const ShortcutEntry(
          label: 'Save',
          category: 'Editing',
          activator: SingleActivator(LogicalKeyboardKey.keyS),
        ),
      ]);

      ShortcutCatalog.instance.unregisterCategory('Navigation');
      expect(ShortcutCatalog.instance.entries, hasLength(1));
      expect(
        ShortcutCatalog.instance.entries.first.category,
        equals('Editing'),
      );
    });

    test('clear removes all entries', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'A',
          category: 'Nav',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
        const ShortcutEntry(
          label: 'B',
          category: 'Nav',
          activator: SingleActivator(LogicalKeyboardKey.keyB),
        ),
      ]);

      ShortcutCatalog.instance.clear();
      expect(ShortcutCatalog.instance.entries, isEmpty);
    });
  });
}
