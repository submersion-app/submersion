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

  /// Whether Ask can answer, switchable while the app runs.
  final enabled = StateProvider<bool>((ref) => false);
  late ProviderContainer container;

  /// Builds the global bindings with Ask [available] and returns them. The
  /// catalog is process-wide, so its Ask entry is put back as it was.
  Future<Map<ShortcutActivator, VoidCallback>> bindingsUnder(
    WidgetTester tester, {
    required bool available,
  }) async {
    final wasListed = listed();
    addTearDown(AppShortcuts.debugReset);
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
          enabled.overrideWith((ref) => available),
          exploreEnabledProvider.overrideWith((ref) => ref.watch(enabled)),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            bindings = AppShortcuts.globalBindings(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return bindings;
  }

  testWidgets('no binding and no catalog entry for Cmd/Ctrl+E', (tester) async {
    final bindings = await bindingsUnder(tester, available: true);
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

  // Copilot review: the entry followed the platform alone, so the help
  // listed Cmd/Ctrl+Enter where the model could not answer.
  testWidgets('the Ask entry follows whether Ask can answer', (tester) async {
    await bindingsUnder(tester, available: false);
    expect(listed(), isFalse);
    // The download finishes, or the locale changes to one the model reads.
    container.read(enabled.notifier).state = true;
    await tester.pump();
    final entry = ShortcutCatalog.instance.entries.singleWhere(
      (e) => e.label == askLabel,
    );
    expect(entry.activator.trigger, LogicalKeyboardKey.enter);
    container.read(enabled.notifier).state = false;
    await tester.pump();
    expect(listed(), isFalse);
  });

  test('the Ask entry has a translated label', () {
    expect(hasShortcutEntryTranslation(askLabel), isTrue);
    expect(hasShortcutEntryTranslation('Explore with a sentence'), isFalse);
  });
}
