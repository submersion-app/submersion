import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_info_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_pressure_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4228: the deco calculator's panel draws the same tissue chart as
/// the dive log's tissue card (markers, M-value line, localized tooltips),
/// instead of its own English-only copy.
void main() {
  Future<void> pumpPanel(WidgetTester tester, Locale locale) async {
    final algorithm = BuhlmannAlgorithm();
    algorithm.calculateSegment(
      depthMeters: 30,
      durationSeconds: 20 * 60,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
    final status = algorithm.getDecoStatus(currentDepth: 30);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: DecoInfoPanel(status: status)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the shared tissue chart with surface level markers', (
    tester,
  ) async {
    await pumpPanel(tester, const Locale('en'));

    expect(find.byType(TissuePressureBarChart), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tissue-surface-marker-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tissue-m-value-line')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('its bar tooltips are localized', (tester) async {
    await pumpPanel(tester, const Locale('de'));

    final tooltip = tester.widget<Tooltip>(
      find
          .descendant(
            of: find.byType(TissuePressureBarChart),
            matching: find.byType(Tooltip),
          )
          .first,
    );
    expect(tooltip.message, startsWith('Kompartiment 1\n'));
    expect(tooltip.message, isNot(contains('Half-time')));
  });
}
