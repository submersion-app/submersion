import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_equipment_page.dart';
import 'package:submersion/features/statistics/presentation/providers/equipment_condition_statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
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

  final askedLocales = <Locale>[];

  Future<void> pumpPage(
    WidgetTester tester, {
    bool failRankings = false,
    Locale locale = const Locale('en'),
    DiveFilterState? filter,
  }) async {
    askedLocales.clear();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          if (filter != null)
            statisticsFilterProvider.overrideWith((ref) => filter),
          exposureRankingProvider.overrideWith(
            (ref, locale) async => failRankings
                ? throw StateError('no db')
                : [
                    RankingItem(
                      id: 'reg',
                      name: 'Apeks XTX',
                      count: 12,
                      value: 12.4,
                      // Distinct from the badge so a test can tell the
                      // count label from the dive count beneath it.
                      subtitle: '9 dives',
                    ),
                  ],
          ),
          findingsByRuleProvider.overrideWith(
            (ref, locale) async => failRankings
                ? throw StateError('no db')
                : [
                    RankingItem(
                      id: 'issueRecurring',
                      name: 'Recurring issue',
                      count: 2,
                    ),
                  ],
          ),
          issueTagRankingProvider.overrideWith((ref, locale) async {
            askedLocales.add(locale);
            return failRankings
                ? throw StateError('no db')
                : [RankingItem(id: 'freeFlow', name: 'Free flow', count: 3)];
          }),
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
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StatisticsEquipmentPage(embedded: true),
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

  testWidgets('asks for the rankings in the language it renders', (
    tester,
  ) async {
    // The settings mock keeps its own locale; the page is German. On the
    // "system" setting the platform language can change without the
    // setting moving, so the labels must follow what the page shows.
    await pumpPage(tester, locale: const Locale('de'));
    expect(askedLocales, isNotEmpty);
    expect(askedLocales.toSet(), {const Locale('de')});
  });

  testWidgets('under a filter the findings card says it spans all dives', (
    tester,
  ) async {
    // Exposure and reported issues narrow to the filter; findings are the
    // gear's state now, so the card says plainly that the filter does not
    // narrow it.
    await pumpPage(
      tester,
      filter: DiveFilterState(startDate: DateTime(2026, 1, 1)),
    );
    expect(
      find.text('Open findings by rule, across all dives'),
      findsOneWidget,
    );
    expect(find.text('Open findings by rule'), findsNothing);
  });

  testWidgets('with no filter the findings card keeps its plain subtitle', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Open findings by rule'), findsOneWidget);
    expect(find.text('Open findings by rule, across all dives'), findsNothing);
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

  testWidgets('the count label keeps the casing each locale wants', (
    tester,
  ) async {
    // German capitalises its nouns, so lowercasing a localised label in
    // code produced "12 stunden". The label is translated per locale in
    // the casing it needs after a number, and never transformed here.
    await pumpPage(tester);
    expect(find.text('12 hours'), findsOneWidget);

    await pumpPage(tester, locale: const Locale('de'));
    expect(find.text('12 Stunden'), findsOneWidget);
    expect(find.text('12 stunden'), findsNothing);
  });

  testWidgets('every offered unit has its own label', (tester) async {
    // The switch used to map days and dives to the hours label, so a unit
    // set programmatically would have shown the wrong word. Each has its
    // own string now, and dives is offered since items genuinely rank by
    // dive count; days is not, because a date trigger accrues no usage.
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('exposure-unit')));
    await tester.pumpAndSettle();
    expect(find.text('Dives').hitTestable(), findsOneWidget);
    expect(find.text('Days'), findsNothing);

    await tester.tap(find.text('Dives').hitTestable());
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(StatisticsEquipmentPage)),
    );
    expect(scope.read(exposureRankingUnitProvider), ExposureUnit.dives);
    expect(find.text('12 dives'), findsOneWidget);
  });
}
