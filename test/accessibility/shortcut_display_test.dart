import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/accessibility/shortcut_display.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  setUp(() {
    ShortcutCatalog.instance.clear();
    AppShortcuts.ensureRegistered();
  });

  // shortcutEntryLabel keys its translations on the English catalog label and
  // falls back to that label when nothing matches. English cannot show a miss,
  // since the fallback reads the same, so German does: a label renamed on one
  // side only would come back untranslated.
  test('every global shortcut label resolves to a translation', () {
    final german = lookupAppLocalizations(const Locale('de'));
    final global = ShortcutCatalog.instance.entries.where((e) => e.isGlobal);

    expect(global, isNotEmpty);
    for (final entry in global) {
      expect(
        shortcutEntryLabel(german, entry.label),
        isNot(entry.label),
        reason: entry.label,
      );
    }
  });
}
