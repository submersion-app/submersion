import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

BuoyancyTwinOutcome _outcome({
  double leadKg = 6.0,
  double droppableLeadKg = 4.0,
  double minDitchableKg = 2.0,
  double peakLiftDemandKg = 3.0,
  double? wingLiftCapacityKg,
  double verdictNet = 1.8,
}) {
  final env = DiveEnvironment.forConditions(waterType: WaterType.salt);
  final input = TwinInput(
    profile: const [
      TwinProfileSample(timestamp: 0, depthM: 0),
      TwinProfileSample(timestamp: 60, depthM: 5),
    ],
    tanks: const [],
    suit: const TwinSuitInput(
      kind: TwinSuitKind.wetsuit,
      anchorKg: 3.0,
      source: TermSource.typeDefault,
    ),
    staticTerms: const [
      TwinStaticTerm(label: 'personal', kg: 5.0, source: TermSource.measured),
    ],
    leadKg: leadKg,
    droppableLeadKg: droppableLeadKg,
    environment: env,
  );
  final result = BuoyancyTwinResult(
    samples: const [
      TwinSample(timestamp: 0, depthM: 0, suitKg: 3, tanksKg: 0, netKg: 2),
      TwinSample(timestamp: 60, depthM: 5, suitKg: 3, tanksKg: 0, netKg: 1.8),
    ],
    staticKg: 5.0,
    suitSurfaceKg: 3.9,
    drysuitGasLiters: 0,
    pressuresEstimated: false,
    input: input,
  );
  final verdict = TwinVerdict(
    anchor: const TwinAnchor(
      kind: TwinAnchorKind.detectedStop,
      timestamp: 60,
      depthM: 5,
    ),
    netKg: verdictNet,
    terms: [
      const TwinStaticTerm(
        label: 'suit',
        kg: 3.0,
        source: TermSource.typeDefault,
      ),
      const TwinStaticTerm(
        label: 'personal',
        kg: 5.0,
        source: TermSource.measured,
      ),
      TwinStaticTerm(label: 'lead', kg: -leadKg, source: TermSource.measured),
    ],
  );
  final outputs = TwinOutputs(
    beginNetKg: 2.0,
    endNetKg: 1.8,
    peakLiftDemandKg: peakLiftDemandKg,
    minDitchableKg: minDitchableKg,
    droppableLeadKg: droppableLeadKg,
    idealLeadKg: leadKg + verdictNet,
    verdict: verdict,
    drysuitGasLiters: 0,
  );
  return BuoyancyTwinOutcome(
    result: result,
    outputs: outputs,
    wingLiftCapacityKg: wingLiftCapacityKg,
  );
}

Future<void> _pump(WidgetTester tester, BuoyancyTwinOutcome? outcome) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        buoyancyTwinProvider('d1').overrideWith((ref) async => outcome),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuoyancySection(
              diveId: 'd1',
              units: UnitFormatter(AppSettings()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the verdict and expands the breakdown', (tester) async {
    await _pump(tester, _outcome());
    // Verdict amount is rendered (1.8 kg buoyant).
    expect(find.textContaining('1.8'), findsWidgets);

    // Expand the breakdown and find the lead row.
    final expansion = find.byType(ExpansionTile);
    expect(expansion, findsOneWidget);
    await tester.ensureVisible(expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();
    expect(find.textContaining('-6.0'), findsWidgets);
  });

  testWidgets('warns when droppable lead is below the minimum ditchable', (
    tester,
  ) async {
    await _pump(tester, _outcome(minDitchableKg: 6.0, droppableLeadKg: 2.0));
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });

  testWidgets('renders nothing when the outcome is null', (tester) async {
    await _pump(tester, null);
    expect(find.byType(Card), findsNothing);
  });
}
