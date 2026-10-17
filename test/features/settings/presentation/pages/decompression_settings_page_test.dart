import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/decompression_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _app({VoidCallback? onBack}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(
      (ref) => MockSettingsNotifier(const AppSettings(gfLow: 30, gfHigh: 70)),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DecompressionSettingsPage(onBack: onBack),
  ),
);

void main() {
  testWidgets('is its own page with an app bar and the current GF', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Decompression'),
      ),
      findsOneWidget,
    );
    expect(find.text('GF 30/70'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('GTR reserve pressure'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GTR reserve pressure'), findsOneWidget);
  });

  testWidgets('without onBack it shows no back arrow of its own', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('with onBack the back arrow calls it', (tester) async {
    var backs = 0;
    await tester.pumpWidget(_app(onBack: () => backs++));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(backs, 1);
  });
}
