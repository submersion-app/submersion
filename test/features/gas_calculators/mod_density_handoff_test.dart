import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/density_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod_calculator.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// Opening the density calculator from the MOD card (#3501) hands over the
/// mix, depth and the chosen gas temperature. A regression
/// here would leave the standalone calculator at its own previous
/// temperature while every MOD-only test still passes.
void main() {
  testWidgets(
    'opening the density calculator from MOD carries the chosen temperature',
    (tester) async {
      final base = await getBaseOverrides();
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/planning/gas-calculators',
        routes: [
          GoRoute(
            path: '/planning/gas-calculators',
            builder: (_, _) =>
                const Scaffold(body: Text('gas calculators hub')),
            routes: [
              for (final id in kGasCalculatorIds)
                GoRoute(
                  path: id,
                  builder: (_, _) => GasCalculatorDetailPage(toolId: id),
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          locale: const Locale('en'),
          overrides: base.cast(),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/planning/gas-calculators/mod');
      await tester.pumpAndSettle();
      expect(find.byType(ModCalculator), findsOneWidget);

      await tester.tap(find.text('OC Tec'));
      await tester.pumpAndSettle();
      final checkTemperature = find.text(
        'Check gas density at a different temperature',
      );
      await tester.ensureVisible(checkTemperature);
      await tester.tap(checkTemperature);
      await tester.pumpAndSettle();
      final twentyC = find.text('20°C');
      await tester.ensureVisible(twentyC);
      await tester.tap(twentyC);
      await tester.pumpAndSettle();

      final openDensity = find.text('Open in the gas density calculator');
      await tester.ensureVisible(openDensity);
      await tester.tap(openDensity);
      await tester.pumpAndSettle();

      expect(find.byType(DensityCalculator), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DensityCalculator)),
      );
      expect(
        container.read(densityTemperatureProvider),
        GasDensityTemperature.twentyC,
      );
    },
  );
}
