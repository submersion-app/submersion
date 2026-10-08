import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  const units = UnitFormatter(AppSettings());

  Widget buildCard(O2Exposure exposure, {Locale? locale}) =>
      localizedMaterialApp(
        locale: locale,
        home: Scaffold(
          body: SingleChildScrollView(
            child: O2ToxicityCard(exposure: exposure, units: units),
          ),
        ),
      );

  group('O2ToxicityCard "time above ppO2 limit" detail rows', () {
    testWidgets('shows both rows when the dive spent time above each ceiling', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(
          const O2Exposure(
            maxPpO2: 1.7,
            maxPpO2Depth: 42,
            timeAboveWarning: 180,
            timeAboveCritical: 45,
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Default thresholds: warning 1.4 bar, critical 1.6 bar.
      expect(find.text('Time above 1.4 bar'), findsOneWidget);
      expect(find.text('Time above 1.6 bar'), findsOneWidget);
    });

    testWidgets('the threshold follows the configured ppO2 limits', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(
          const O2Exposure(
            maxPpO2: 1.8,
            maxPpO2Depth: 48,
            timeAboveWarning: 120,
            timeAboveCritical: 30,
            warningThreshold: 1.5,
            criticalThreshold: 1.6,
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Time above 1.5 bar'), findsOneWidget);
      expect(find.text('Time above 1.6 bar'), findsOneWidget);
    });

    testWidgets('the row label comes from the active locale', (tester) async {
      await tester.pumpWidget(
        buildCard(
          const O2Exposure(
            maxPpO2: 1.7,
            maxPpO2Depth: 40,
            timeAboveWarning: 90,
          ),
          locale: const Locale('fr'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Temps au-dessus de'), findsOneWidget);
    });

    testWidgets('neither row renders when the dive stayed within limits', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(
          const O2Exposure(maxPpO2: 1.2, maxPpO2Depth: 20),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Time above'), findsNothing);
    });
  });

  group('O2ToxicityCard live readout (liveCns)', () {
    Widget buildLive(
      O2Exposure exposure, {
      required double liveCns,
      double? dailyOtu,
      double? weeklyOtu,
    }) => localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: O2ToxicityCard(
            exposure: exposure,
            units: units,
            showDetails: false,
            liveCns: liveCns,
            dailyOtu: dailyOtu,
            weeklyOtu: weeklyOtu,
          ),
        ),
      ),
    );

    testWidgets('reads the live CNS but keeps the dive\'s own delta', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildLive(const O2Exposure(cnsStart: 10, cnsEnd: 50), liveCns: 12),
      );
      await tester.pumpAndSettle();

      expect(find.text('12%'), findsOneWidget);
      expect(find.text('50%'), findsNothing);
      expect(find.text('Before last dive: 10%'), findsOneWidget);
      expect(find.text('Last dive: +40.0%'), findsOneWidget);
      expect(find.text('Last Dive'), findsOneWidget);
    });

    testWidgets('warns on the live CNS, not the dive\'s end value', (
      tester,
    ) async {
      // 90% at the surface (a warning) has decayed to 30% (no warning).
      await tester.pumpWidget(
        buildLive(const O2Exposure(cnsEnd: 90), liveCns: 30),
      );
      await tester.pumpAndSettle();

      expect(find.text('WARNING'), findsNothing);
      expect(find.text('CRITICAL'), findsNothing);
    });

    testWidgets('ignores the dive\'s past ppO2 peak for the badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildLive(const O2Exposure(cnsEnd: 5, maxPpO2: 1.7), liveCns: 5),
      );
      await tester.pumpAndSettle();

      expect(find.text('CRITICAL'), findsNothing);
      expect(find.text('WARNING'), findsNothing);
    });

    testWidgets('the daily row shows the dailyOtu total it is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildLive(
          const O2Exposure(otuStart: 250, otu: 20),
          liveCns: 0,
          dailyOtu: 30,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30 / 300 OTU (10%)'), findsOneWidget);
      expect(find.textContaining('270 / 300'), findsNothing);
    });
  });
}
