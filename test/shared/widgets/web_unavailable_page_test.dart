import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/router/web_unavailable_routes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/web_unavailable_page.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('names the reason for a hardware feature', (tester) async {
    await tester.pumpWidget(
      _app(
        const WebUnavailablePage(feature: WebUnavailableFeature.diveComputers),
      ),
    );
    expect(find.text('Not available in a browser'), findsWidgets);
    expect(
      find.textContaining('Bluetooth, USB, NFC or the camera'),
      findsOneWidget,
    );
  });

  testWidgets('names the reason for a file-bound feature', (tester) async {
    await tester.pumpWidget(
      _app(
        const WebUnavailablePage(feature: WebUnavailableFeature.offlineMaps),
      ),
    );
    expect(find.textContaining('files on the device'), findsOneWidget);
  });

  test('featureFromQuery reads a name and falls back to dive computers', () {
    expect(
      WebUnavailablePage.featureFromQuery('nearby'),
      WebUnavailableFeature.nearby,
    );
    expect(
      WebUnavailablePage.featureFromQuery('martian'),
      WebUnavailableFeature.diveComputers,
    );
    expect(
      WebUnavailablePage.featureFromQuery(null),
      WebUnavailableFeature.diveComputers,
    );
  });
}
