import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/icd_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/icd_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the calculator and hands back a ref so a test can drive providers.
Future<WidgetRef> _pump(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const IcdCalculator();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

final _apply = find.widgetWithText(TextButton, 'Apply');

void main() {
  testWidgets('the default Tx 18/45 to EAN32 switch is a violation', (
    tester,
  ) async {
    await _pump(tester);

    // N2 rises 37 -> 68 (31); He falls 45 -> 0, so at most 9 is allowed.
    expect(
      find.text(
        'Rule of fifths violated: nitrogen rises 31.0%, the allowed '
        'maximum is 9.0%.',
      ),
      findsOneWidget,
    );
    expect(_apply, findsNWidgets(2));
  });

  testWidgets('applying the keep-current-gas fix sets He on the new gas', (
    tester,
  ) async {
    final ref = await _pump(tester);

    await tester.tap(_apply.first);
    await tester.pumpAndSettle();

    expect(ref.read(icdHeBProvider), closeTo(31, 0.001));
    expect(ref.read(icdHeAProvider), 45);
    expect(find.text('No ICD risk under the rule of fifths.'), findsOneWidget);
  });

  testWidgets('applying the keep-new-gas fix sets He on the current gas', (
    tester,
  ) async {
    final ref = await _pump(tester);

    await tester.tap(_apply.last);
    await tester.pumpAndSettle();

    expect(ref.read(icdHeAProvider), closeTo(14, 0.001));
    expect(ref.read(icdHeBProvider), 0);
    expect(find.text('No ICD risk under the rule of fifths.'), findsOneWidget);
  });

  testWidgets('a caution already complies, so it offers no fixes', (
    tester,
  ) async {
    final ref = await _pump(tester);
    // Tx 20/25 to 40% O2: N2 rises exactly the 5 the rule allows.
    ref.read(icdO2AProvider.notifier).state = 20;
    ref.read(icdHeAProvider.notifier).state = 25;
    ref.read(icdO2BProvider.notifier).state = 40;
    ref.read(icdHeBProvider.notifier).state = 0;
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Borderline: the nitrogen increase is close to the allowed maximum.',
      ),
      findsOneWidget,
    );
    expect(_apply, findsNothing);
  });

  testWidgets('turned off in settings, it shows the notice and no verdict', (
    tester,
  ) async {
    await _pump(tester, settings: const AppSettings(icdWarningsEnabled: false));

    expect(
      find.text(
        'The ICD assessment is turned off in Settings > Decompression.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Rule of fifths violated'), findsNothing);
    expect(_apply, findsNothing);
  });

  testWidgets('the violation percentages use the locale decimal separator', (
    tester,
  ) async {
    final previousLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousLocale);
    Intl.defaultLocale = 'de';

    await _pump(tester, locale: const Locale('de'));

    expect(find.textContaining('31,0'), findsOneWidget);
    expect(find.textContaining('9,0'), findsOneWidget);
  });
}
