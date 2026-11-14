import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/presentation/widgets/garmin_nothing_new_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4223: the card a Garmin download shows when nothing is new.
void main() {
  Widget card({VoidCallback? onDownloadAll}) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: GarminNothingNewCard(onDownloadAll: onDownloadAll ?? () {}),
      ),
    ),
  );

  const message = 'No new dives on the watch since your last download.';

  testWidgets('the message keeps most of the width on a phone', (tester) async {
    tester.view.physicalSize = const Size(300, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(card());

    // The button sat beside the message and left it a word per line.
    expect(tester.getSize(find.text(message)).width, greaterThan(180));
  });

  testWidgets('Download All Again calls back', (tester) async {
    var calls = 0;
    await tester.pumpWidget(card(onDownloadAll: () => calls++));

    await tester.tap(find.text('Download All Again'));

    expect(calls, 1);
  });
}
