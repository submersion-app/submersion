import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_equipment_page.dart';
import 'package:submersion/features/statistics/presentation/providers/equipment_condition_statistics_providers.dart';
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

  Future<void> pumpPage(
    WidgetTester tester, {
    bool failRankings = false,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          exposureRankingProvider.overrideWith(
            (ref) async => failRankings
                ? throw StateError('no db')
                : [
                    RankingItem(
                      id: 'reg',
                      name: 'Apeks XTX',
                      count: 12,
                      value: 12.4,
                      subtitle: '12 dives',
                    ),
                  ],
          ),
          findingsByRuleProvider.overrideWith(
            (ref) async => failRankings
                ? throw StateError('no db')
                : [
                    RankingItem(
                      id: 'issueRecurring',
                      name: 'Recurring issue',
                      count: 2,
                    ),
                  ],
          ),
          issueTagRankingProvider.overrideWith(
            (ref) async => failRankings
                ? throw StateError('no db')
                : [RankingItem(id: 'freeFlow', name: 'Free flow', count: 3)],
          ),
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

  testWidgets('shows the three condition rankings', (tester) async {
    await pumpPage(tester);
    expect(find.text('Exposure'), findsOneWidget);
    expect(find.text('Apeks XTX'), findsOneWidget);
    expect(find.text('Condition findings'), findsOneWidget);
    expect(find.text('Recurring issue'), findsOneWidget);
    expect(find.text('Reported issues'), findsOneWidget);
    expect(find.text('Free flow'), findsOneWidget);
  });

  testWidgets('the exposure unit dropdown switches the unit', (tester) async {
    await pumpPage(tester);
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(StatisticsEquipmentPage)),
    );
    expect(scope.read(exposureRankingUnitProvider), ExposureUnit.hours);
    await tester.tap(find.byKey(const ValueKey('exposure-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cold dives').last);
    await tester.pumpAndSettle();
    expect(scope.read(exposureRankingUnitProvider), ExposureUnit.coldDives);
  });

  testWidgets('a failed ranking says so instead of showing the empty copy', (
    tester,
  ) async {
    await pumpPage(tester, failRankings: true);
    // "No dives with gear yet" would read as a fact about the library
    // rather than a load that failed.
    expect(find.text('Failed to load exposure data'), findsOneWidget);
    expect(find.text('No dives with gear yet'), findsNothing);
    expect(find.text('Failed to load condition findings'), findsOneWidget);
    expect(find.text('No open findings'), findsNothing);
    expect(find.text('Failed to load reported issues'), findsOneWidget);
    expect(find.text('No issues reported'), findsNothing);
  });
}
