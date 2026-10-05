import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_switch_efficiency_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget testApp({required Widget child, bool imperial = false}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _StubSettingsNotifier(
          AppSettings(depthUnit: imperial ? DepthUnit.feet : DepthUnit.meters),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  const late = GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: 1630,
    idealDepth: 21,
    switchTimestamp: 1910,
    switchDepth: 15,
    endTimestamp: 1910,
    delaySeconds: 280,
    depthDelayMeters: 6,
    extraDecoSeconds: 125,
  );
  const missed = GasSwitchWindow(
    kind: GasSwitchWindowKind.missed,
    fO2: 1.0,
    fHe: 0,
    idealTimestamp: 2510,
    idealDepth: 6,
    endTimestamp: 3750,
    delaySeconds: 1240,
    extraDecoSeconds: 400,
  );

  testWidgets('lists each flagged switch and the total', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(
            evaluated: true,
            windows: [late, missed],
            totalExtraDecoSeconds: 480,
          ),
        ),
      ),
    );
    expect(find.text('Gas switches'), findsOneWidget);
    expect(find.text('EAN50'), findsOneWidget);
    expect(find.textContaining('Switched at 15'), findsOneWidget);
    expect(find.textContaining('4:40 late'), findsOneWidget);
    expect(find.text('O2'), findsOneWidget);
    expect(find.textContaining('Not switched (ideal at 6'), findsOneWidget);
    expect(find.text('Total extra deco: 8:00'), findsOneWidget);
  });

  testWidgets('says all switches were on time when none are flagged', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: const GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(evaluated: true),
        ),
      ),
    );
    expect(find.text('All gas switches on time'), findsOneWidget);
  });

  testWidgets('a switch late by time only reads as a delay at its depth', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(
            evaluated: true,
            windows: [
              late.copyWith(
                switchDepth: 21,
                depthDelayMeters: 0,
                delaySeconds: 130,
              ),
            ],
            totalExtraDecoSeconds: 0,
          ),
        ),
      ),
    );
    expect(find.textContaining('Switched 2:10 late at 21'), findsOneWidget);
    expect(find.textContaining('instead of'), findsNothing);
  });

  testWidgets('depths follow imperial units', (tester) async {
    await tester.pumpWidget(
      testApp(
        imperial: true,
        child: const GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(
            evaluated: true,
            windows: [late],
            totalExtraDecoSeconds: 125,
          ),
        ),
      ),
    );
    expect(find.textContaining('ft'), findsWidgets);
  });
}
