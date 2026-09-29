import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/not_while_typing_activator.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/accessibility/shortcuts_help_dialog.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_switcher_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

  static const _log = LoggerService('AppShortcuts');

  /// Forget that the shortcuts were registered, so the next
  /// [ensureRegistered] fills the catalog again.
  ///
  /// [ShortcutCatalog.clear] empties the catalog but cannot reach this flag,
  /// so a test that clears the catalog resets the flag with it.
  @visibleForTesting
  static void debugReset() => _registered = false;

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
      // Listed only where an on-device model adapter exists at all.
      if (exploreSupportedOn(defaultTargetPlatform))
        ShortcutEntry(
          label: 'Explore with a sentence',
          category: 'Search',
          activator: platformShortcut(LogicalKeyboardKey.keyE),
          isGlobal: true,
        ),

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

  /// Opens Explore when the on-device model can answer, and says why not
  /// otherwise. The page is useless without a model, so this honours the
  /// same availability as the app bar action, but waits for the probe: a
  /// press before anything asked would otherwise read "still loading" and
  /// be dropped.
  static Future<void> _openExplore(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final NlAvailability availability;
    try {
      availability = await container.read(exploreAvailabilityProvider.future);
    } catch (e, stackTrace) {
      // A failed probe is an unavailable model, as the app bar reads it.
      _log.warning('Explore probe failed', error: e, stackTrace: stackTrace);
      if (context.mounted) _showExploreUnavailable(context);
      return;
    }
    if (!context.mounted) return;
    if (availability == NlAvailability.available) {
      context.push('/dives/explore');
    } else {
      _showExploreUnavailable(context);
    }
  }

  static void _showExploreUnavailable(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.explore_shortcut_unavailable)),
    );
  }

  /// Returns the global shortcut bindings map for [CallbackShortcuts].
  static Map<ShortcutActivator, VoidCallback> globalBindings(
    BuildContext context,
  ) {
    ensureRegistered();

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

      // Search
      platformShortcut(LogicalKeyboardKey.keyF): () {
        context.push('/dives/search');
      },
      if (exploreSupportedOn(defaultTargetPlatform))
        platformShortcut(LogicalKeyboardKey.keyE): () => _openExplore(context),

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
