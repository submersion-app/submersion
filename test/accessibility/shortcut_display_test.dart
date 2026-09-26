import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/accessibility/shortcut_display.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';

void main() {
  setUp(() {
    ShortcutCatalog.instance.clear();
    AppShortcuts.ensureRegistered();
  });

  // shortcutEntryLabel keys its translations on the English catalog label and
  // falls back to that label when nothing matches, so a label renamed on one
  // side only would silently render untranslated in every locale.
  test('every global shortcut label has a translation', () {
    final global = ShortcutCatalog.instance.entries.where((e) => e.isGlobal);

    expect(global, isNotEmpty);
    for (final entry in global) {
      expect(
        hasShortcutEntryTranslation(entry.label),
        isTrue,
        reason: entry.label,
      );
    }
  });

  test('an ad-hoc label has no translation and falls back to itself', () {
    expect(hasShortcutEntryTranslation('Refresh map tiles'), isFalse);
  });
}
