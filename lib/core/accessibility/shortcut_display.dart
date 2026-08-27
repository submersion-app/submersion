import 'package:flutter/services.dart';

import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display strings for [ShortcutEntry].
///
/// `ShortcutEntry.label` and `ShortcutEntry.category` are registered as const
/// English literals by `AppShortcuts.ensureRegistered` (a static method with no
/// BuildContext, called from the first build of the app shell), and
/// [ShortcutCatalog] additionally uses the category string as a grouping key,
/// as a sort key, and as the argument to `unregisterCategory`. Translating at
/// registration time would make all three locale-dependent, so the English
/// literal stays the stable identifier and the help sheet resolves it here at
/// render time -- the same shape as `builtInDiveTypeName` for seeded dive
/// types.
///
/// Both resolvers fall back to the stored English string so a page that
/// registers an ad-hoc shortcut still renders something readable.
String shortcutEntryLabel(AppLocalizations l10n, String label) =>
    switch (label) {
      'New dive' => l10n.accessibility_shortcut_newDive,
      'Go to Dives' => l10n.accessibility_shortcut_goToDives,
      'Go to Sites' => l10n.accessibility_shortcut_goToSites,
      'Go to Equipment' => l10n.accessibility_shortcut_goToEquipment,
      'Go to Statistics' => l10n.accessibility_shortcut_goToStatistics,
      'Go to Settings' => l10n.accessibility_shortcut_goToSettings,
      'Go back' => l10n.accessibility_shortcut_goBack,
      'Search dives' => l10n.accessibility_shortcut_searchDives,
      'Close / Cancel' => l10n.accessibility_shortcut_closeCancel,
      'Open settings' => l10n.accessibility_shortcut_openSettings,
      'Switch diver' => l10n.accessibility_shortcut_switchDiver,
      'Keyboard shortcuts' => l10n.accessibility_shortcut_keyboardShortcuts,
      _ => label,
    };

/// Localized name for a built-in shortcut category; the raw string otherwise.
String shortcutCategoryLabel(AppLocalizations l10n, String category) =>
    switch (category) {
      'Navigation' => l10n.accessibility_shortcutCategory_navigation,
      'Search' => l10n.accessibility_shortcutCategory_search,
      'Editing' => l10n.accessibility_shortcutCategory_editing,
      'General' => l10n.accessibility_shortcutCategory_general,
      'Help' => l10n.accessibility_shortcutCategory_help,
      _ => category,
    };

extension ShortcutEntryDisplay on ShortcutEntry {
  /// Localized twin of [ShortcutEntry.displayKey].
  ///
  /// `displayKey` stays as the context-free English formatter used by the
  /// registry's own unit tests and by any caller without an [AppLocalizations];
  /// the help sheet uses this one so modifier names ("Cmd+", "Option+") and
  /// named keys ("Esc", "Enter") follow the UI language.
  String localizedDisplayKey(AppLocalizations l10n, TargetPlatform platform) {
    final buffer = StringBuffer();
    final isMac = platform == TargetPlatform.macOS;

    if (activator.meta) {
      buffer.write(
        isMac
            ? l10n.accessibility_modifierKey_cmd
            : l10n.accessibility_modifierKey_super,
      );
    }
    if (activator.control) {
      buffer.write(l10n.accessibility_modifierKey_ctrl);
    }
    if (activator.alt) {
      buffer.write(
        isMac
            ? l10n.accessibility_modifierKey_option
            : l10n.accessibility_modifierKey_alt,
      );
    }
    if (activator.shift) {
      buffer.write(l10n.accessibility_modifierKey_shift);
    }

    buffer.write(_localizedKeyLabel(l10n, activator.trigger));
    return buffer.toString();
  }
}

/// Readable, localized name for the trigger key.
///
/// Punctuation keys ('/', '?', ',') and single letters are returned as-is:
/// they are printed on the physical keyboard and do not translate.
String _localizedKeyLabel(AppLocalizations l10n, LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.escape) {
    return l10n.accessibility_keyLabel_esc;
  }
  if (key == LogicalKeyboardKey.delete) {
    return l10n.accessibility_keyLabel_delete;
  }
  if (key == LogicalKeyboardKey.backspace) {
    return l10n.accessibility_keyLabel_backspace;
  }
  if (key == LogicalKeyboardKey.enter) {
    return l10n.accessibility_keyLabel_enter;
  }
  if (key == LogicalKeyboardKey.arrowUp) {
    return l10n.accessibility_keyLabel_up;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    return l10n.accessibility_keyLabel_down;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return l10n.accessibility_keyLabel_left;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return l10n.accessibility_keyLabel_right;
  }
  if (key == LogicalKeyboardKey.slash) return '/';
  if (key == LogicalKeyboardKey.question) return '?';
  if (key == LogicalKeyboardKey.comma) return ',';

  final label = key.keyLabel;
  if (label.length == 1) return label.toUpperCase();
  return label;
}
