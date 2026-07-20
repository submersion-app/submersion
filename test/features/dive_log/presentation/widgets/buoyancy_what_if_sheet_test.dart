import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_what_if_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

TwinInput _base() => TwinInput(
  profile: const [
    TwinProfileSample(timestamp: 0, depthM: 0),
    TwinProfileSample(timestamp: 60, depthM: 5),
    TwinProfileSample(timestamp: 120, depthM: 5),
  ],
  tanks: const [],
  suit: const TwinSuitInput(
    kind: TwinSuitKind.wetsuit,
    anchorKg: 3.0,
    source: TermSource.typeDefault,
  ),
  staticTerms: const [
    TwinStaticTerm(label: 'personal', kg: 5.0, source: TermSource.measured),
    TwinStaticTerm(label: 'water', kg: 0.0, source: TermSource.physics),
  ],
  leadKg: 6.0,
  droppableLeadKg: 4.0,
  environment: DiveEnvironment.forConditions(waterType: WaterType.salt),
  totalMassKg: 90,
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showBuoyancyWhatIfSheet(
              context,
              baseInput: _base(),
              units: const UnitFormatter(AppSettings()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adjusting lead updates the value and reset restores it', (
    tester,
  ) async {
    await _open(tester);

    // Base lead is 6.0 kg.
    expect(find.text('6.0 kg'), findsOneWidget);

    // Two +0.5 kg steps -> 7.0 kg.
    final plus = find.byIcon(Icons.add);
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(find.text('7.0 kg'), findsOneWidget);

    // Reset restores the original lead.
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('6.0 kg'), findsOneWidget);
  });

  testWidgets('decrementing lead below zero clamps to 0 without crashing', (
    tester,
  ) async {
    await _open(tester);

    // Base lead 6.0 kg at 0.5 kg steps: 12 taps reach 0.0. The 13th once
    // computed (0.0 - 0.5).clamp(0, 100), which returns an int and threw on the
    // double assignment; double bounds keep it at 0.0.
    final minus = find.byIcon(Icons.remove);
    for (var i = 0; i < 13; i++) {
      await tester.tap(minus);
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('0.0 kg'), findsOneWidget);
  });
}
