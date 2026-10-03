import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/accessibility/shortcut_display.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';

/// Cmd/Ctrl+E (Explore) is gone with the page (#2773); the help sheet
/// lists Cmd/Ctrl+Enter, which asks from the dive search field, wherever
/// the on-device model can run.
void main() {
  const askLabel = 'Ask about your dives';

  bool listed() =>
      ShortcutCatalog.instance.entries.any((e) => e.label == askLabel);

  /// Builds the global bindings under [supported] and returns them. The
  /// catalog is process-wide, so its Ask entry is put back as it was.
  Future<Map<ShortcutActivator, VoidCallback>> bindingsUnder(
    WidgetTester tester, {
    required bool supported,
  }) async {
    final wasListed = listed();
    addTearDown(() {
      if (listed() == wasListed) return;
      if (wasListed) {
        ShortcutCatalog.instance.register(
          ShortcutEntry(
            label: askLabel,
            category: 'Search',
            activator: platformShortcut(LogicalKeyboardKey.enter),
          ),
        );
      } else {
        ShortcutCatalog.instance.unregisterLabel(askLabel);
      }
    });
    late Map<ShortcutActivator, VoidCallback> bindings;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          explorePlatformSupportedProvider.overrideWithValue(supported),
        ],
        child: Builder(
          builder: (context) {
            bindings = AppShortcuts.globalBindings(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return bindings;
  }

  testWidgets('no binding and no catalog entry for Cmd/Ctrl+E', (tester) async {
    final bindings = await bindingsUnder(tester, supported: true);
    expect(
      bindings.keys.whereType<SingleActivator>().where(
        (a) => a.trigger == LogicalKeyboardKey.keyE,
      ),
      isEmpty,
    );
    expect(
      ShortcutCatalog.instance.entries.where(
        (e) =>
            e.activator.trigger == LogicalKeyboardKey.keyE ||
            e.label == 'Explore with a sentence',
      ),
      isEmpty,
    );
  });

  testWidgets('the Ask entry is listed only where the model can run', (
    tester,
  ) async {
    await bindingsUnder(tester, supported: true);
    final entry = ShortcutCatalog.instance.entries.singleWhere(
      (e) => e.label == askLabel,
    );
    expect(entry.activator.trigger, LogicalKeyboardKey.enter);
    await bindingsUnder(tester, supported: false);
    expect(listed(), isFalse);
  });

  test('the Ask entry has a translated label', () {
    expect(hasShortcutEntryTranslation(askLabel), isTrue);
    expect(hasShortcutEntryTranslation('Explore with a sentence'), isFalse);
  });
}
