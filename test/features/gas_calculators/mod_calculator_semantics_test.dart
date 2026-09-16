import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
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

Widget _host(Locale locale, {AppSettings settings = const AppSettings()}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
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

  testWidgets('the result card semantics label announces the depth in the '
      "diver's configured unit", (tester) async {
    // The depth in the screen-reader label goes through UnitFormatter, so an
    // imperial diver hears feet. Only the ppO2 figure stays in bar: partial
    // pressure is a fixed diving convention, stated in bar app-wide (see the
    // planner's ppO2 warnings and the decompression settings), not a
    // diver-configurable unit.
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        RegExp(r'Maximum Operating Depth: [\d.]+ ft at [\d.]+ bar ppO2'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Maximum Operating Depth: [\d.]+ m ')),
      findsNothing,
    );
  });

  testWidgets('the metric diver hears metres in the same label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        settings: const AppSettings(depthUnit: DepthUnit.meters),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        RegExp(r'Maximum Operating Depth: [\d.]+ m at [\d.]+ bar ppO2'),
      ),
      findsOneWidget,
    );
  });
}
