import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/accessibility/app_shortcuts.dart';

void main() {
  group('ShortcutCatalog', () {
    setUp(() {
      ShortcutCatalog.instance.clear();
    });
    test('starts empty', () {
      expect(ShortcutCatalog.instance.entries, isEmpty);
    });

    test('register adds an entry', () {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      expect(ShortcutCatalog.instance.entries, hasLength(1));
      expect(ShortcutCatalog.instance.entries.first.label, 'Test');
    });

    test('registerAll adds multiple entries', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'First',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
        const ShortcutEntry(
          label: 'Second',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyB),
        ),
      ]);

      expect(ShortcutCatalog.instance.entries, hasLength(2));
    });

    test('unregisterCategory removes only that category', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'Keep',
          category: 'Keepers',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
        const ShortcutEntry(
          label: 'Remove',
          category: 'Removable',
          activator: SingleActivator(LogicalKeyboardKey.keyB),
        ),
      ]);

      ShortcutCatalog.instance.unregisterCategory('Removable');

      expect(ShortcutCatalog.instance.entries, hasLength(1));
      expect(ShortcutCatalog.instance.entries.first.label, 'Keep');
    });

    test('clear removes all entries', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'One',
          category: 'Cat',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
        const ShortcutEntry(
          label: 'Two',
          category: 'Cat',
          activator: SingleActivator(LogicalKeyboardKey.keyB),
        ),
      ]);

      ShortcutCatalog.instance.clear();
      expect(ShortcutCatalog.instance.entries, isEmpty);
    });

    test('entries list is unmodifiable', () {
      ShortcutCatalog.instance.register(
        const ShortcutEntry(
          label: 'Test',
          category: 'Testing',
          activator: SingleActivator(LogicalKeyboardKey.keyA),
        ),
      );

      expect(
        () => ShortcutCatalog.instance.entries.add(
          const ShortcutEntry(
            label: 'Hack',
            category: 'Hack',
            activator: SingleActivator(LogicalKeyboardKey.keyZ),
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('byCategory groups and sorts entries', () {
      ShortcutCatalog.instance.registerAll([
        const ShortcutEntry(
          label: 'Shortcut Help',
          category: 'Help',
          activator: SingleActivator(LogicalKeyboardKey.slash),
        ),
        const ShortcutEntry(
          label: 'Go to Dives',
          category: 'Navigation',
          activator: SingleActivator(LogicalKeyboardKey.digit1),
        ),
        const ShortcutEntry(
          label: 'Search',
          category: 'Search',
          activator: SingleActivator(LogicalKeyboardKey.keyF),
        ),
      ]);

      final grouped = ShortcutCatalog.instance.byCategory;
      final categories = grouped.keys.toList();

      // Navigation should come before Search, which comes before Help
      expect(
        categories.indexOf('Navigation'),
        lessThan(categories.indexOf('Search')),
      );
      expect(
        categories.indexOf('Search'),
        lessThan(categories.indexOf('Help')),
      );
    });
  });

  group('ShortcutEntry', () {
    test('displayKey shows Cmd prefix on macOS', () {
      final entry = ShortcutEntry(
        label: 'Test',
        category: 'Testing',
        activator: platformShortcut(LogicalKeyboardKey.keyN),
      );

      final display = entry.displayKey(TargetPlatform.macOS);
      // On macOS the platform shortcut uses meta
      expect(display, contains('N'));
    });

    test('displayKey shows Esc for escape key', () {
      const entry = ShortcutEntry(
        label: 'Close',
        category: 'General',
        activator: SingleActivator(LogicalKeyboardKey.escape),
      );

      expect(entry.displayKey(TargetPlatform.macOS), 'Esc');
      expect(entry.displayKey(TargetPlatform.windows), 'Esc');
    });

    test('displayKey shows uppercase letter for simple keys', () {
      const entry = ShortcutEntry(
        label: 'Test',
        category: 'Testing',
        activator: SingleActivator(LogicalKeyboardKey.keyA),
      );

      expect(entry.displayKey(TargetPlatform.macOS), 'A');
    });
  });

  group('AppShortcuts', () {
    // Clear stale entries from earlier groups and register once.
    // AppShortcuts._registered is a static flag, so ensureRegistered()
    // only populates the catalog on its first call.
    setUpAll(() {
      ShortcutCatalog.instance.clear();
      AppShortcuts.ensureRegistered();
    });

    test('ensureRegistered populates catalog with global shortcuts', () {
      final entries = ShortcutCatalog.instance.entries;
      expect(entries, isNotEmpty);

      // Verify expected global shortcuts exist
      final labels = entries.map((e) => e.label).toList();
      expect(labels, contains('New dive'));
      expect(labels, contains('Go to Dives'));
      expect(labels, contains('Go to Sites'));
      expect(labels, contains('Go to Equipment'));
      expect(labels, contains('Go to Statistics'));
      expect(labels, contains('Go to Settings'));
      expect(labels, contains('Search dives'));
      expect(labels, contains('Go back'));
      expect(labels, contains('Close / Cancel'));
      expect(labels, contains('Keyboard shortcuts'));
    });

    test('ensureRegistered is idempotent', () {
      AppShortcuts.ensureRegistered();
      final countAfterFirst = ShortcutCatalog.instance.entries.length;

      AppShortcuts.ensureRegistered();
      final countAfterSecond = ShortcutCatalog.instance.entries.length;

      expect(countAfterFirst, countAfterSecond);
    });

    test('all global shortcuts are marked isGlobal', () {
      AppShortcuts.ensureRegistered();

      for (final entry in ShortcutCatalog.instance.entries) {
        expect(
          entry.isGlobal,
          isTrue,
          reason: '${entry.label} should be global',
        );
      }
    });

    test('navigation shortcuts use expected categories', () {
      AppShortcuts.ensureRegistered();

      final grouped = ShortcutCatalog.instance.byCategory;
      expect(grouped.containsKey('Navigation'), isTrue);
      expect(grouped.containsKey('Search'), isTrue);
      expect(grouped.containsKey('General'), isTrue);
      expect(grouped.containsKey('Help'), isTrue);
    });
  });
}
