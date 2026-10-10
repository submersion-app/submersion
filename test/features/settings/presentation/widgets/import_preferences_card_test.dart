import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/import_preferences_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Widget host(MockSettingsNotifier notifier) => ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => notifier)],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: ImportPreferencesCard()),
      ),
    ),
  );

  Finder autoTagSwitch() =>
      find.widgetWithText(SwitchListTile, 'Tag imports automatically');

  group('auto-tag imports switch (issue #3193)', () {
    testWidgets('sits in the Import card and reflects the on default', (
      tester,
    ) async {
      await tester.pumpWidget(host(MockSettingsNotifier()));
      await tester.pumpAndSettle();

      expect(autoTagSwitch(), findsOneWidget);
      expect(tester.widget<SwitchListTile>(autoTagSwitch()).value, isTrue);
    });

    testWidgets('reflects an off value from settings', (tester) async {
      await tester.pumpWidget(
        host(MockSettingsNotifier(const AppSettings(autoTagImports: false))),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(autoTagSwitch()).value, isFalse);
    });

    testWidgets('toggling it updates settings', (tester) async {
      final notifier = MockSettingsNotifier();
      await tester.pumpWidget(host(notifier));
      await tester.pumpAndSettle();

      await tester.tap(autoTagSwitch());
      await tester.pumpAndSettle();

      expect(notifier.state.autoTagImports, isFalse);
    });
  });
}
