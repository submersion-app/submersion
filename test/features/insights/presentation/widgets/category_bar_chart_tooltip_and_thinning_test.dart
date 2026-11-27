import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/category_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The per-bar tooltip text and the label thinning the exposure card's
/// usage chart needs (issue #5074). The test font draws every glyph as a
/// square of the font size: bodySmall is 12 px, so "'96" is 36 px wide.
Future<void> _pump(
  WidgetTester tester,
  List<String> labels, {
  double width = 390,
  String Function(int index)? tooltipText,
  bool thin = true,
}) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: CategoryBarChart(
          data: [for (final label in labels) (label: label, count: 5)],
          compactXLabelFormatter: (label) => "'${label.substring(2)}",
          compactXLabelsToFit: true,
          thinXLabelsToFit: thin,
          tooltipText: tooltipText,
        ),
      ),
    ),
  ),
);

String _tooltipOf(WidgetTester tester, int index) {
  final chart = tester.widget<BarChart>(find.byType(BarChart));
  final group = chart.data.barGroups[index];
  return chart.data.barTouchData.touchTooltipData
      .getTooltipItem(group, index, group.barRods.first, 0)!
      .text;
}

void main() {
  final years = [for (var y = 1996; y <= 2026; y++) '$y'];

  testWidgets('tooltipText replaces the tooltip body', (tester) async {
    await _pump(tester, const [
      '2024',
      '2025',
      '2026',
    ], tooltipText: (i) => 'bar $i detail');

    expect(_tooltipOf(tester, 1), 'bar 1 detail');
  });

  testWidgets('without tooltipText the tooltip keeps label and count', (
    tester,
  ) async {
    await _pump(tester, const ['2024', '2025', '2026']);

    expect(_tooltipOf(tester, 0), '2024\n5');
  });

  testWidgets('thins labels that still overflow after compaction, keeping '
      'the last', (tester) async {
    // 31 bars share about 344 px, 11 px each; "'96" needs 40 px with its
    // gap, so every fourth label is drawn, counted back from the last.
    await _pump(tester, years);

    expect(find.text("'26"), findsOneWidget);
    expect(find.text("'25"), findsNothing);
    expect(find.text("'24"), findsNothing);
    expect(find.text("'23"), findsNothing);
    expect(find.text("'22"), findsOneWidget);
    expect(find.text('2026'), findsNothing);
  });

  testWidgets('bars stay narrower than their slots when there are many', (
    tester,
  ) async {
    // 31 bars share about 344 px: 11 px each, under the 12 px rod width a
    // crowded chart used to draw, so neighbouring bars overlapped.
    await _pump(tester, years);

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    const slot = (390 - 44 - 2) / 31;
    for (final group in chart.data.barGroups) {
      expect(group.barRods.single.width, lessThan(slot));
    }
  });

  testWidgets('labels that fit are all drawn even with thinning on', (
    tester,
  ) async {
    await _pump(tester, const ['2024', '2025', '2026'], width: 400);

    expect(find.text('2024'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('without thinning every crowded label is still drawn', (
    tester,
  ) async {
    await _pump(tester, years, thin: false);

    expect(find.text("'25"), findsOneWidget);
  });
}
