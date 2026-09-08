import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  // Shared exposure: 43 OTU this dive, 42 OTU from prior same-day dives
  // Daily total = 42 + 43 = 85 / 300 (28%)
  const exposure = O2Exposure(
    cnsStart: 5.0,
    cnsEnd: 12.0,
    otu: 43.0,
    otuStart: 42.0,
    maxPpO2: 1.3,
    maxPpO2Depth: 28.0,
  );

  Widget buildPanel({
    O2Exposure exp = exposure,
    double? selectedOtu,
    double? weeklyOtu,
  }) {
    return localizedMaterialApp(
      home: Scaffold(
        body: CompactO2ToxicityPanel(
          exposure: exp,
          selectedOtu: selectedOtu,
          weeklyOtu: weeklyOtu,
        ),
      ),
    );
  }

  group('CompactO2ToxicityPanel OTU bars', () {
    testWidgets('renders daily OTU header with value and limit', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();

      // Should show "Daily" label
      expect(find.text('Daily'), findsOneWidget);
      // Should show "85 / 300 OTU" (otuDaily / dailyOtuLimit)
      expect(find.text('85 / 300 OTU'), findsOneWidget);
    });

    testWidgets('renders weekly OTU header with value and limit', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: 320));
      await tester.pumpAndSettle();

      expect(find.text('Weekly'), findsOneWidget);
      // weeklyOtu = 320, limit = 850
      expect(find.text('320 / 850 OTU'), findsOneWidget);
    });

    testWidgets('renders daily footer with start and delta', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();

      // Footer: "Start: 42 OTU" (daily only) and "+43 this dive" (both bars)
      expect(find.text('Start: 42 OTU'), findsOneWidget);
      expect(find.text('+43 this dive'), findsAtLeast(1));
    });

    testWidgets('renders weekly footer with prior and delta', (tester) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: 320));
      await tester.pumpAndSettle();

      // Prior = weeklyOtu - otu = 320 - 43 = 277
      expect(find.text('Prior: 277 OTU'), findsOneWidget);
      // "+43 this dive" appears twice (daily + weekly)
      expect(find.text('+43 this dive'), findsAtLeast(2));
    });

    testWidgets(
      'shows cursor value in daily header when selectedOtu provided',
      (tester) async {
        await tester.pumpWidget(buildPanel(selectedOtu: 21));
        await tester.pumpAndSettle();

        // Cursor mode: "21 / 85 / 300 OTU"
        expect(find.text('21 / 85 / 300 OTU'), findsOneWidget);
      },
    );

    testWidgets('falls back to this-dive OTU when weeklyOtu is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: null));
      await tester.pumpAndSettle();

      // When weeklyOtu is null, total = exposure.otu = 43, prior = 0
      expect(find.text('43 / 850 OTU'), findsOneWidget);
      expect(find.text('Prior: 0 OTU'), findsOneWidget);
    });

    testWidgets('does not render old 3-column text metrics', (tester) async {
      await tester.pumpWidget(buildPanel(weeklyOtu: 320));
      await tester.pumpAndSettle();

      // The old "This Dive" text metric column should be gone
      expect(find.text('This Dive'), findsNothing);
    });

    testWidgets('renders no prior segment when otuStart is zero', (
      tester,
    ) async {
      const noPrior = O2Exposure(
        cnsStart: 0,
        cnsEnd: 10,
        otu: 43,
        otuStart: 0,
        maxPpO2: 1.2,
        maxPpO2Depth: 25,
      );

      await tester.pumpWidget(buildPanel(exp: noPrior));
      await tester.pumpAndSettle();

      // Start = 0, so footer shows "Start: 0 OTU"
      expect(find.text('Start: 0 OTU'), findsOneWidget);
    });

    testWidgets('renders the "time above ppO2 limit" lines when set', (
      tester,
    ) async {
      const overLimit = O2Exposure(
        cnsStart: 0,
        cnsEnd: 10,
        otu: 43,
        otuStart: 0,
        maxPpO2: 1.7,
        maxPpO2Depth: 42,
        timeAboveWarning: 150,
        timeAboveCritical: 40,
        warningThreshold: 1.4,
        criticalThreshold: 1.6,
      );

      await tester.pumpWidget(buildPanel(exp: overLimit));
      await tester.pumpAndSettle();

      expect(find.textContaining('Time above 1.4 bar'), findsOneWidget);
      expect(find.textContaining('Time above 1.6 bar'), findsOneWidget);
    });

    testWidgets('omits the "time above" lines when the dive stayed in range', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel()); // shared exposure, maxPpO2 1.3
      await tester.pumpAndSettle();

      expect(find.textContaining('Time above'), findsNothing);
    });
  });
}
