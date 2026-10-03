import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/not_while_typing_activator.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/accessibility/shortcuts_help_dialog.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_switcher_sheet.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Creates a platform-appropriate shortcut activator.
///
/// Uses Meta (Cmd) on macOS, Control on Windows/Linux.
SingleActivator platformShortcut(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) {
  final isMac = defaultTargetPlatform == TargetPlatform.macOS;
  return SingleActivator(
    key,
    meta: isMac,
    control: !isMac,
    shift: shift,
    alt: alt,
  );
}

/// Global keyboard shortcuts available throughout the application.
class AppShortcuts {
  AppShortcuts._();

  static bool _registered = false;

  /// Forget that the shortcuts were registered, so the next
  /// [ensureRegistered] fills the catalog again.
  ///
  /// [ShortcutCatalog.clear] empties the catalog but cannot reach this flag,
  /// so a test that clears the catalog resets the flag with it.
  @visibleForTesting
  static void debugReset() {
    _registered = false;
    _askSubscription?.close();
    _askSubscription = null;
    _askContainer = null;
  }

  /// Register all global shortcuts with the [ShortcutCatalog].
  ///
  /// Safe to call multiple times -- only registers once.
  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;

    // The `label` and `category` strings below are deliberately English
    // literals, NOT `context.l10n` lookups. Registration happens once from
    // a static method with no BuildContext, and ShortcutCatalog uses the
    // category string as a grouping key, a sort key and the argument to
    // unregisterCategory. They are stable identifiers; the help sheet
    // resolves them to the UI language at render time through
    // shortcutEntryLabel / shortcutCategoryLabel in shortcut_display.dart.
    ShortcutCatalog.instance.registerAll([
      // Navigation
      ShortcutEntry(
        label: 'New dive',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.keyN),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Go to Dives',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.digit1),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Go to Sites',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.digit2),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Go to Equipment',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.digit3),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Go to Insights',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.digit4),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Go to Settings',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.digit5),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Go back',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.keyW),
        isGlobal: true,
      ),

      // Search
      ShortcutEntry(
        label: 'Search dives',
        category: 'Search',
        activator: platformShortcut(LogicalKeyboardKey.keyF),
        isGlobal: true,
      ),
      // 'Ask about your dives' is listed by globalBindings, which can read
      // the platform gate from the provider graph.

      // General
      const ShortcutEntry(
        label: 'Close / Cancel',
        category: 'General',
        activator: SingleActivator(LogicalKeyboardKey.escape),
        isGlobal: true,
      ),

      // Settings
      ShortcutEntry(
        label: 'Open settings',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.comma),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Switch diver',
        category: 'Navigation',
        activator: platformShortcut(LogicalKeyboardKey.keyD, shift: true),
        isGlobal: true,
      ),

      // Help. Bare "?" is ignored while typing in a text field; the modified
      // key works everywhere, including inside one (#2145).
      const ShortcutEntry(
        label: 'Keyboard shortcuts',
        category: 'Help',
        activator: SingleActivator(LogicalKeyboardKey.question),
        isGlobal: true,
      ),
      ShortcutEntry(
        label: 'Keyboard shortcuts',
        category: 'Help',
        activator: platformShortcut(LogicalKeyboardKey.slash),
        isGlobal: true,
      ),
    ]);
  }

  static const _askLabel = 'Ask about your dives';

  /// The container Ask's catalog entry follows, and its subscription.
  static ProviderContainer? _askContainer;
  static ProviderSubscription<bool>? _askSubscription;

  /// Keeps Ask's catalog entry in step with whether Ask can answer (the
  /// platform, the model probe and the locale), which changes while the
  /// app runs: the catalog itself is filled once (#2773). One subscription
  /// per container, however often the shell rebuilds.
  static void _followAskAvailability(ProviderContainer container) {
    if (identical(container, _askContainer)) return;
    _askSubscription?.close();
    _askContainer = container;
    _askSubscription = container.listen<bool>(
      exploreEnabledProvider,
      (_, enabled) => _syncAskEntry(enabled),
      fireImmediately: true,
    );
  }

  /// Lists or unlists Ask (Cmd/Ctrl+Enter in the dive search field, #2773)
  /// in the catalog.
  /// The gate is a provider so every entry point, and every test override,
  /// agrees; registration has no container, so the entry follows here.
  static void _syncAskEntry(bool supported) {
    final catalog = ShortcutCatalog.instance;
    final listed = catalog.entries.any((e) => e.label == _askLabel);
    if (listed == supported) return;
    if (supported) {
      catalog.register(
        ShortcutEntry(
          label: _askLabel,
          category: 'Search',
          // Not global: it works inside the dive search field.
          activator: platformShortcut(LogicalKeyboardKey.enter),
        ),
      );
    } else {
      catalog.unregisterLabel(_askLabel);
    }
  }

  /// Returns the global shortcut bindings map for [CallbackShortcuts].
  static Map<ShortcutActivator, VoidCallback> globalBindings(
    BuildContext context,
  ) {
    ensureRegistered();
    _followAskAvailability(ProviderScope.containerOf(context, listen: false));

    return {
      // Navigation.
      //
      // The numbered section shortcuts below use `go` deliberately: switching
      // top-level sections SHOULD reset the stack. The child routes here use
      // `push`, because these bindings are mounted around the entire shell and
      // `go` into a `/dives` child would rebuild the stack as [dive list, X],
      // stranding a user who pressed the key from Media or Insights.
      platformShortcut(LogicalKeyboardKey.keyN): () {
        // PUSH (not go): the digit shortcuts below switch tabs, but this
        // opens a sub-page and must stay poppable (#647).
        context.push('/dives/new');
      },
      platformShortcut(LogicalKeyboardKey.digit1): () {
        context.go('/dives');
      },
      platformShortcut(LogicalKeyboardKey.digit2): () {
        context.go('/sites');
      },
      platformShortcut(LogicalKeyboardKey.digit3): () {
        context.go('/equipment');
      },
      platformShortcut(LogicalKeyboardKey.digit4): () {
        context.go('/insights');
      },
      platformShortcut(LogicalKeyboardKey.digit5): () {
        context.go('/settings');
      },
      platformShortcut(LogicalKeyboardKey.keyW): () {
        if (context.canPop()) {
          context.pop();
        }
      },

      // Search: the dive list's search row (#2773), opened with the caret
      // in it. From another section this switches to Dives, like digit1.
      platformShortcut(LogicalKeyboardKey.keyF): () {
        final container = ProviderScope.containerOf(context, listen: false);
        container.read(diveSearchBarOpenProvider.notifier).state = true;
        container.read(diveSearchFocusPendingProvider.notifier).state = true;
        final uri = GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.uri;
        // The phone map view (/dives?view=map) has no search row; wide
        // layouts show the list beside the map, so they stay put.
        final phoneMap =
            uri.queryParameters['view'] == 'map' &&
            !ResponsiveBreakpoints.isMasterDetail(context);
        if (uri.path != '/dives' || phoneMap) context.go('/dives');
      },

      // Settings
      platformShortcut(LogicalKeyboardKey.comma): () {
        context.go('/settings');
      },
      platformShortcut(LogicalKeyboardKey.keyD, shift: true): () {
        showDiverSwitcherSheet(context);
      },

      // Help overlay. Bare "?" follows the common convention, but it must not
      // fire while the diver is typing, or no field could ever contain a "?"
      // (#2145). Ctrl+/ (Cmd+/ on macOS) opens the help from anywhere.
      const NotWhileTypingActivator(CharacterActivator('?')): () {
        showShortcutsHelpDialog(context);
      },
      platformShortcut(LogicalKeyboardKey.slash): () {
        showShortcutsHelpDialog(context);
      },
    };
  }
}
