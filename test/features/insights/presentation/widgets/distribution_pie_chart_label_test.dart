import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// The percentage on a pie slice was always white, which is unreadable on a
// pale slice such as amber or light cyan. It now follows the slice colour.

Future<List<PieChartSectionData>> _sections(
  WidgetTester tester,
  List<Color> colors,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DistributionPieChart(
          showLegend: false,
          colors: colors,
          data: [
            for (var i = 0; i < colors.length; i++)
              DistributionSegment(
                label: 'S$i',
                count: 1,
                percentage: 100 / colors.length,
              ),
          ],
        ),
      ),
    ),
  );
  return tester.widget<PieChart>(find.byType(PieChart)).data.sections;
}

void main() {
  testWidgets(
    'slice text is white on a dark slice, near-black on a light one',
    (tester) async {
      final sections = await _sections(tester, const [
        Color(0xFF14213D), // navy
        Color(0xFFF4B41A), // amber
        Color(0xFF00D2FC), // light cyan
      ]);

      expect(sections.map((s) => s.titleStyle?.color), [
        Colors.white,
        Colors.black87,
        Colors.black87,
      ]);
    },
  );
}
