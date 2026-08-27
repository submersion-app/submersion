import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_prediction_card.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  const units = UnitFormatter(AppSettings());

  const prediction = WeightPrediction(
    totalKg: 8.0,
    terms: [
      PredictionTerm(label: 'personal', kg: 3.0, source: TermSource.measured),
      PredictionTerm(label: '5mm Suit', kg: 4.5, source: TermSource.userSpec),
      PredictionTerm(label: 'Hood', kg: 0.3, source: TermSource.typeDefault),
      PredictionTerm(label: 'al80', kg: 1.0, source: TermSource.physics),
      PredictionTerm(label: 'water', kg: -0.8, source: TermSource.physics),
    ],
    confidence: PredictionConfidence.medium,
    supportingDives: 5,
  );

  testWidgets('renders placement rows, confidence, and delta chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const SingleChildScrollView(
          child: WeightPredictionCard(
            prediction: prediction,
            placement: {'integrated': 6.0, 'trimWeights': 2.0},
            units: units,
            deltaText: '+1.0 kg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suggested placement'), findsOneWidget);
    expect(find.text('Integrated Weights'), findsOneWidget);
    expect(find.text('Trim Weights'), findsOneWidget);
    expect(
      find.text('Medium confidence · Based on 5 logged dives'),
      findsOneWidget,
    );
    expect(find.text('+1.0 kg vs previous rig'), findsOneWidget);
  });

  testWidgets('breakdown expands to labeled terms with sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const SingleChildScrollView(
          child: WeightPredictionCard(prediction: prediction, units: units),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('How this was calculated'));
    await tester.pumpAndSettle();

    expect(
      find.text('Personal baseline (measured from your dives)'),
      findsOneWidget,
    );
    expect(find.text('5mm Suit (from your gear specs)'), findsOneWidget);
    expect(find.text('Hood (default estimate)'), findsOneWidget);
    expect(find.text('Water type (physics)'), findsOneWidget);
    expect(find.text('al80 (physics)'), findsOneWidget);
    // Negative water term keeps its sign, positives get a plus.
    expect(find.text('-0.8 kg'), findsOneWidget);
    expect(find.text('+1.0 kg'), findsOneWidget);
  });

  testWidgets('low confidence renders the estimate label', (tester) async {
    const lowPrediction = WeightPrediction(
      totalKg: 6.0,
      terms: [],
      confidence: PredictionConfidence.low,
      supportingDives: 0,
    );
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const SingleChildScrollView(
          child: WeightPredictionCard(prediction: lowPrediction, units: units),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Low confidence - estimate'), findsOneWidget);
  });
}
