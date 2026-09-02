import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host({
    TrendAggregation aggregation = TrendAggregation.none,
    bool showRollingMean = true,
    bool showLinearFit = false,
    String? rateLabel,
    ValueChanged<TrendAggregation>? onAggregationChanged,
    VoidCallback? onToggleRollingMean,
    VoidCallback? onToggleLinearFit,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TrendControlStrip(
          chartId: 'depth',
          aggregation: aggregation,
          onAggregationChanged: onAggregationChanged ?? (_) {},
          showRollingMean: showRollingMean,
          onToggleRollingMean: onToggleRollingMean ?? () {},
          showLinearFit: showLinearFit,
          onToggleLinearFit: onToggleLinearFit ?? () {},
          seriesColor: Colors.indigo,
          rollingColor: Colors.blue,
          rateColor: Colors.orange,
          rateLabel: rateLabel,
        ),
      ),
    );
  }

  testWidgets('shows the active aggregation mode', (tester) async {
    await tester.pumpWidget(host(aggregation: TrendAggregation.monthly));

    expect(find.text('Monthly average'), findsOneWidget);
  });

  testWidgets('opening the dropdown and choosing weekly reports the change', (
    tester,
  ) async {
    TrendAggregation? chosen;
    await tester.pumpWidget(host(onAggregationChanged: (m) => chosen = m));

    await tester.tap(find.byKey(const ValueKey('trend-aggregation-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly average').last);
    await tester.pumpAndSettle();

    expect(chosen, TrendAggregation.weekly);
  });

  testWidgets('tapping the rolling legend entry toggles it', (tester) async {
    var toggled = false;
    await tester.pumpWidget(host(onToggleRollingMean: () => toggled = true));

    await tester.tap(find.byKey(const ValueKey('trend-legend-rolling-depth')));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('tapping the rate legend entry toggles it', (tester) async {
    var toggled = false;
    await tester.pumpWidget(host(onToggleLinearFit: () => toggled = true));

    await tester.tap(find.byKey(const ValueKey('trend-legend-rate-depth')));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('shows the rate value when the fit is on and a label is given', (
    tester,
  ) async {
    await tester.pumpWidget(host(showLinearFit: true, rateLabel: '+4.4 m'));

    expect(find.text('+4.4 m/yr'), findsOneWidget);
  });

  testWidgets('shows the plain rate label when the fit is off', (tester) async {
    await tester.pumpWidget(host(rateLabel: '+4.4 m'));

    expect(find.text('Overall trend'), findsOneWidget);
    expect(find.text('+4.4 m/yr'), findsNothing);
  });

  testWidgets('the mode control carries the series colour as its swatch', (
    tester,
  ) async {
    // "What is the blue line?" The control that chooses what the series shows
    // also identifies it, so the legend explains all three layers without
    // naming the mode twice on one row.
    await tester.pumpWidget(host());

    final swatch = tester.widget<Container>(
      find.byKey(const ValueKey('trend-series-swatch-depth')),
    );
    final decoration = swatch.decoration! as BoxDecoration;

    expect(decoration.color, Colors.indigo);
  });
}
