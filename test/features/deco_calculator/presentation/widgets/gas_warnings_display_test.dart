import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/deco_calculator/presentation/widgets/gas_warnings_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the card and hands back a ref so a test can drive the inputs.
Future<WidgetRef> _pump(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const GasWarningsDisplay();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  // The number helpers read the process-global Intl.defaultLocale rather than
  // MaterialApp.locale, so pin it per test; the German test overrides it.
  String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('a psi diver sees ppO2 in bar, not converted to psi', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final ref = await _pump(
      tester,
      settings: const AppSettings(pressureUnit: PressureUnit.psi),
    );

    // EAN32 at 30 m: 4.0 bar ambient x 0.32 = 1.28 bar, which formatPressure
    // would have shown as "19 psi".
    ref.read(calcDepthProvider.notifier).state = 30;
    ref.read(calcO2Provider.notifier).state = 32;
    await tester.pumpAndSettle();

    expect(find.text('1.28 bar'), findsOneWidget);
    expect(find.textContaining('psi'), findsNothing);

    // The tooltip is a status word and carries no pressure value or unit.
    expect(find.byTooltip('ppO2 Safe'), findsOneWidget);

    // The screen reader label is built from the displayed value, so it must
    // say bar as well.
    expect(find.bySemanticsLabel(RegExp(r'ppO₂: 1\.28 bar\.')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('psi')), findsNothing);

    semantics.dispose();
  });

  testWidgets('ppO2 keeps two decimals rather than rounding to whole bar', (
    tester,
  ) async {
    // Defaults: air at 18 m is 2.8 bar ambient x 0.21 = 0.588 bar, which the
    // zero-decimal pressure formatting rendered as "1 bar".
    await _pump(tester);

    expect(find.text('0.59 bar'), findsOneWidget);
  });

  testWidgets('ppO2 uses the locale decimal separator', (tester) async {
    Intl.defaultLocale = 'de';

    final ref = await _pump(
      tester,
      settings: const AppSettings(pressureUnit: PressureUnit.psi),
    );
    ref.read(calcDepthProvider.notifier).state = 30;
    ref.read(calcO2Provider.notifier).state = 32;
    await tester.pumpAndSettle();

    expect(find.text('1,28 bar'), findsOneWidget);
  });
}
