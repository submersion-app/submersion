import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_fallback_buttons.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The other ways to swap under the nearby list (issue #3728).
void main() {
  testWidgets('Send file hands over the button rectangle for the iPad '
      'share popover', (tester) async {
    Rect? anchor;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SwapFallbackButtons(
            onShowCode: () {},
            onScanCode: () {},
            onSendFile: (rect) => anchor = rect,
            onOpenFile: () {},
            onWriteSticker: () {},
            onReadTag: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send file'));
    expect(anchor, isNotNull);
    expect(anchor, tester.getRect(find.byType(OutlinedButton).at(2)));
  });
}
