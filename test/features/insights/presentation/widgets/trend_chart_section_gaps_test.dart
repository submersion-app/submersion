import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

List<TrendDataPoint> series() => [
  for (var i = 0; i < 20; i++)
    TrendDataPoint(
      date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
      value: 10.0 + i,
    ),
];

void main() {
  testWidgets('the section passes the diver threshold and the menu sets it', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(trendGapThreshold: TrendGapThreshold.years2),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrendChartSection(
                chartId: TrendChartIds.depth,
                title: 'Maximum Depth Progression',
                subtitle: 'Every dive in range',
                pointsAsync: AsyncValue.data(series()),
                errorMessage: 'x',
                lineColor: Colors.indigo,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<DiveTrendChart>(find.byType(DiveTrendChart)).gapThreshold,
      TrendGapThreshold.years2,
    );

    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend-gaps-depth-off')));
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).trendGapThreshold,
      TrendGapThreshold.off,
    );
    expect(
      tester.widget<DiveTrendChart>(find.byType(DiveTrendChart)).gapThreshold,
      TrendGapThreshold.off,
    );
  });
}
