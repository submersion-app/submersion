import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(Locale locale) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _TestSettingsNotifier(const AppSettings()),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ModCalculator()),
    ),
  );
}

void main() {
  testWidgets(
    'the result card semantics label is localised, not hardcoded English',
    (tester) async {
      // Screen readers under a German locale used to read this out in
      // English, since the label was built with a raw string literal
      // instead of going through context.l10n.
      await tester.pumpWidget(_host(const Locale('de')));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Maximale Einsatztiefe:.*ppO2.*')),
      );
      expect(semantics, isNotNull);
      expect(
        find.bySemanticsLabel(RegExp('^Maximum Operating Depth:')),
        findsNothing,
      );
    },
  );
}
