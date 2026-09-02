import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_equipment_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          weightTrendProvider.overrideWith(
            (ref) async => List.generate(
              20,
              (i) => TrendDataPoint(
                date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
                value: 6.0 + (i % 3),
              ),
            ),
          ),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatisticsEquipmentPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the weight trend as a per-dive chart', (tester) async {
    await pumpPage(tester);

    expect(find.byType(DiveTrendChart), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trend-aggregation-weight')),
      findsOneWidget,
    );
  });

  testWidgets('starts in per-dive mode', (tester) async {
    await pumpPage(tester);

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.none);
  });
}
