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
}
