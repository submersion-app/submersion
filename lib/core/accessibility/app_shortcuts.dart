import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/accessibility/shortcuts_help_dialog.dart';

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

  /// Register all global shortcuts with the [ShortcutCatalog].
  ///
  /// Safe to call multiple times -- only registers once.
  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;

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
        label: 'Go to Statistics',
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

      // Help
      const ShortcutEntry(
        label: 'Keyboard shortcuts',
        category: 'Help',
        activator: SingleActivator(LogicalKeyboardKey.question),
        isGlobal: true,
      ),
    ]);
  }

  /// Returns the global shortcut bindings map for [CallbackShortcuts].
  static Map<ShortcutActivator, VoidCallback> globalBindings(
    BuildContext context,
  ) {
    ensureRegistered();

    return {
      // Navigation
      platformShortcut(LogicalKeyboardKey.keyN): () {
        context.go('/dives/new');
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
        context.go('/statistics');
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
        context.go('/dives/search');
      },

      // Settings
      platformShortcut(LogicalKeyboardKey.comma): () {
        context.go('/settings');
      },

      // Help overlay (bare "?" key, no modifier — matches convention)
      const CharacterActivator('?'): () {
        showShortcutsHelpDialog(context);
      },
    };
  }
}
