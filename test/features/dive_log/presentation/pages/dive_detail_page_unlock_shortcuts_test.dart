import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/accessibility/shortcut_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Unlock, Save and Cancel from the keyboard on the dive page and in the
/// list pane (issue #4527, plan 7).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  for (final embedded in [false, true]) {
    final where = embedded ? 'in the pane' : 'on the page';

    testWidgets('$where: Ctrl+L unlocks, Ctrl+S saves, Escape cancels', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        shortcuts: true,
        embedded: embedded,
        size: embedded ? const Size(1200, 900) : const Size(700, 1000),
      );

      await chord(tester, LogicalKeyboardKey.keyL);
      expect(find.text('Save'), findsOneWidget);

      await openNotes(tester);
      await tester.enterText(find.byType(TextField).first, 'Choppy');
      await settle(tester);
      await chord(tester, LogicalKeyboardKey.keyS);
      expect(page.save.calls, hasLength(1));
      expect(find.byTooltip('Unlock to edit').hitTestable(), findsOneWidget);

      await chord(tester, LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byTooltip('Unlock to edit').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('Escape with changes asks first', (tester) async {
    await pumpPage(tester, shortcuts: true);
    await chord(tester, LogicalKeyboardKey.keyL);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).first, 'Choppy');
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(find.text('Discard changes?'), findsOneWidget);
  });

  test('the help lists Unlock and Save under their own words', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(hasShortcutEntryTranslation('Unlock to edit'), isTrue);
    expect(hasShortcutEntryTranslation('Save changes'), isTrue);
    expect(
      shortcutEntryLabel(de, 'Save changes'),
      de.accessibility_shortcut_saveChanges,
    );
  });
}
