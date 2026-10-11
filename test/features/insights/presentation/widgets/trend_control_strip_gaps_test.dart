import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<TrendGapThreshold> onGap,
    required ValueChanged<TrendRangePreset> onRange,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TrendControlStrip(
          chartId: 'depth',
          aggregation: TrendAggregation.none,
          onAggregationChanged: (_) {},
          showRollingMean: true,
          onToggleRollingMean: () {},
          showLinearFit: false,
          onToggleLinearFit: () {},
          seriesColor: Colors.indigo,
          rollingColor: Colors.amber,
          rateColor: Colors.grey,
          range: TrendRange.all,
          onRangePresetSelected: onRange,
          gapThreshold: TrendGapThreshold.year1,
          onGapThresholdSelected: onGap,
        ),
      ),
    ),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
  }

  testWidgets('the Range menu lists the gap choices and checks the current', (
    tester,
  ) async {
    await pump(tester, onGap: (_) {}, onRange: (_) {});
    await openMenu(tester);
    expect(find.text('Collapse gaps'), findsOneWidget);
    for (final t in TrendGapThreshold.values) {
      final item = tester.widget<CheckedPopupMenuItem<Object>>(
        find.byKey(ValueKey('trend-gaps-depth-${t.name}')),
      );
      expect(item.checked, t == TrendGapThreshold.year1);
    }
  });

  testWidgets('picking a gap choice reports it and not a range', (
    tester,
  ) async {
    TrendGapThreshold? gap;
    TrendRangePreset? range;
    await pump(tester, onGap: (t) => gap = t, onRange: (p) => range = p);
    await openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('trend-gaps-depth-years2')));
    await tester.pumpAndSettle();
    expect(gap, TrendGapThreshold.years2);
    expect(range, isNull);
  });

  testWidgets('a range preset still reports as a range', (tester) async {
    TrendGapThreshold? gap;
    TrendRangePreset? range;
    await pump(tester, onGap: (t) => gap = t, onRange: (p) => range = p);
    await openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('trend-range-depth-year1')));
    await tester.pumpAndSettle();
    expect(range, TrendRangePreset.year1);
    expect(gap, isNull);
  });
}
