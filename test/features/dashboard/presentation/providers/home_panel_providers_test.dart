import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/career_totals.dart';
import 'package:submersion/features/insights/presentation/providers/career_totals_provider.dart';

ProviderContainer _container({
  List<double> sac = const [],
  List<Dive> recent = const [],
  bool gaugesFail = false,
}) {
  final container = ProviderContainer(
    overrides: [
      careerTotalsProvider.overrideWith(
        (ref) async =>
            CareerTotals.from(loggedDives: 12, loggedTimeSeconds: 36000),
      ),
      yearInReviewProvider.overrideWith(
        (ref) async => const YearInReview(
          year: 2026,
          current: YearStats(diveCount: 5, totalSeconds: 9000, maxDepth: 30),
          previous: YearStats(diveCount: 7, totalSeconds: 12000),
        ),
      ),
      homeMonthlyDivesProvider.overrideWith((ref) async => const []),
      recentDivesProvider.overrideWith((ref) async => recent),
      daysSinceLastDiveProvider.overrideWith((ref) async => 4),
      homeSacSeriesProvider.overrideWith(
        (ref) async => [
          for (var i = 0; i < sac.length; i++)
            TrendDataPoint(
              date: DateTime(2026, 1, i + 1),
              value: sac[i],
              label: '',
            ),
        ],
      ),
      dashboardGaugesProvider.overrideWith(
        (ref) async => gaugesFail
            ? throw StateError('gauges')
            : const DashboardGauges(
                hasGear: false,
                insurance: null,
                noFlyStatus: null,
                daysSinceLastDive: null,
              ),
      ),
      homeTripChecklistProvider.overrideWith((ref) async => null),
      dashboardQuickStatsProvider.overrideWith(
        (ref) async => const DashboardQuickStats(speciesDiscovered: 0),
      ),
      homeNewSpeciesThisYearProvider.overrideWith((ref) async => 0),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('with no SAC, no trip and no dives those tiles are left out', () async {
    final n = await _container().read(homeKeyNumbersProvider.future);
    expect(n.careerDives, 12);
    expect(n.has(HomeKeyNumber.avgSac), isFalse);
    expect(n.has(HomeKeyNumber.nextTrip), isFalse);
    expect(n.has(HomeKeyNumber.lastDive), isFalse);
    expect(n.has(HomeKeyNumber.species), isFalse);
    expect(n.deepestThisYear, 30);
  });

  test('average SAC is the last ten, compared with the ten before', () async {
    final n = await _container(
      sac: [for (var i = 0; i < 20; i++) i < 10 ? 16.0 : 14.0],
      recent: [Dive(id: 'd', dateTime: DateTime(2026, 11, 16))],
    ).read(homeKeyNumbersProvider.future);
    expect(n.avgSac, 14);
    expect(n.avgSacChange, -2);
    expect(n.daysSinceLastDive, 4);
    expect(n.lastDiveId, 'd');
  });

  test('one SAC value gives an average and no comparison', () async {
    final n = await _container(
      sac: const [15],
    ).read(homeKeyNumbersProvider.future);
    expect(n.avgSac, 15);
    expect(n.avgSacChange, isNull);
  });

  test('a failing optional source leaves the other numbers', () async {
    final n = await _container(
      gaugesFail: true,
    ).read(homeKeyNumbersProvider.future);
    expect(n.careerDives, 12);
    expect(n.nextTrip, isNull);
  });

  test('no change is claimed with fewer than ten earlier dives', () async {
    final n = await _container(
      sac: [for (var i = 0; i < 14; i++) 15.0],
    ).read(homeKeyNumbersProvider.future);
    expect(n.avgSac, 15);
    expect(n.avgSacChange, isNull);
  });
}
