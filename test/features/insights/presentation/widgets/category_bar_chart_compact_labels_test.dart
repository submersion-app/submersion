import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/category_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Labels that shorten only when they would not fit their bar (issue #4600).
/// The test font draws every glyph as a square of the font size, so widths
/// here are exact: bodySmall is 12 px, and "180-210" is 84 px wide.
Future<void> _pump(
  WidgetTester tester,
  List<String> labels, {
  double width = 400,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SizedBox(
          width: width,
          child: CategoryBarChart(
            data: [for (final label in labels) (label: label, count: 5)],
            compactXLabelFormatter: (label) => label.split('-').first,
            compactXLabelsToFit: true,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  const feetBands = [
    '0-30',
    '30-60',
    '60-90',
    '90-120',
    '120-150',
    '150-180',
    '180-210',
    '210+',
  ];

  testWidgets('labels that fit their bars stay whole', (tester) async {
    // Two bars share about 350 px, far more than 84 px each.
    await _pump(tester, const ['150-180', '180-210']);

    expect(find.text('150-180'), findsOneWidget);
    expect(find.text('180-210'), findsOneWidget);
  });

  testWidgets('labels wider than their bars shorten, all of them together', (
    tester,
  ) async {
    // Eight bars leave about 44 px each: "180-210" cannot fit, so every
    // label shortens, the ones that would have fit included.
    await _pump(tester, feetBands);

    expect(find.text('180-210'), findsNothing);
    expect(find.text('0-30'), findsNothing);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('210+'), findsOneWidget);
  });

  testWidgets('a larger text size shortens labels sooner', (tester) async {
    // Three 84 px labels fit three ~118 px bars, but not at double size.
    const labels = ['120-150', '150-180', '180-210'];
    await _pump(tester, labels);
    expect(find.text('180-210'), findsOneWidget);

    await _pump(tester, labels, textScale: 2);
    expect(find.text('180-210'), findsNothing);
    expect(find.text('180'), findsOneWidget);
  });

  testWidgets('without the fit option the fixed bar-width rule still applies', (
    tester,
  ) async {
    // Three bars are about 118 px each, over the 50 px rule, so nothing
    // shortens even though this label is wider than its bar.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: CategoryBarChart(
              data: const [
                (label: 'a-very-long-label', count: 1),
                (label: 'b', count: 1),
                (label: 'c', count: 1),
              ],
              compactXLabelFormatter: (label) => label.split('-').first,
            ),
          ),
        ),
      ),
    );

    expect(find.text('a-very-long-label'), findsOneWidget);
  });
}
