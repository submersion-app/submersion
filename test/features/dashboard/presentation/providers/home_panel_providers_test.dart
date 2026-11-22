import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/career_totals.dart';
import 'package:submersion/features/insights/presentation/providers/career_totals_provider.dart';

ProviderContainer _container({
  List<double> sac = const [],
  List<Dive> recent = const [],
  bool gaugesFail = false,
  int species = 0,
  ({String id, String? site})? deepest,
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
      homeSpeciesCountProvider.overrideWith((ref) async => species),
      homeNewSpeciesThisYearProvider.overrideWith((ref) async => 0),
      homeDeepestThisYearProvider.overrideWith((ref) async => deepest),
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

  test('a failing optional source is logged', () async {
    final captured = <LogEntry>[];
    final sub = LoggerService.logStream.listen(captured.add);
    addTearDown(sub.cancel);
    await _container(gaugesFail: true).read(homeKeyNumbersProvider.future);
    await pumpEventQueue();
    expect(
      captured.where(
        (e) => e.level == LogLevel.error && e.message.contains('key number'),
      ),
      isNotEmpty,
    );
  });

  test('the deepest tile gets its dive and the last dive its date', () async {
    final n = await _container(
      deepest: (id: 'd9', site: 'Blue Hole'),
      recent: [Dive(id: 'd12', dateTime: DateTime(2026, 11, 9, 10))],
    ).read(homeKeyNumbersProvider.future);
    expect(n.deepestDiveId, 'd9');
    expect(n.deepestDiveSite, 'Blue Hole');
    expect(n.lastDiveDate, DateTime(2026, 11, 9, 10));
  });

  test('the window start keeps to the month it lands in', () {
    // 31 August six months back is 28 February, so the window opens on
    // 1 March; a leap day a year back opens on 1 March too.
    expect(
      homeWindowStart(DateTime(2026, 8, 31), months: 6),
      DateTime(2026, 3, 1),
    );
    expect(homeWindowStart(DateTime(2028, 2, 29)), DateTime(2027, 3, 1));
    expect(homeWindowStart(DateTime(2026, 11, 21)), DateTime(2025, 11, 22));
  });

  test('no change is claimed with fewer than ten earlier dives', () async {
    final n = await _container(
      sac: [for (var i = 0; i < 14; i++) 15.0],
    ).read(homeKeyNumbersProvider.future);
    expect(n.avgSac, 15);
    expect(n.avgSacChange, isNull);
  });

  test('the species tile reads the species count', () async {
    final n = await _container(
      species: 143,
    ).read(homeKeyNumbersProvider.future);
    expect(n.species, 143);
  });

  test(
    'a newest dive deleted before its detail read collapses the profile',
    () async {
      final container = ProviderContainer(
        overrides: [
          recentDivesProvider.overrideWith(
            (ref) async => [Dive(id: 'gone', dateTime: DateTime(2026))],
          ),
          diveProvider.overrideWith((ref, id) async => null),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(homeLatestProfileProvider.future), isNull);
    },
  );

  test('days since the last dive count to the clock\'s today', () async {
    // Read from the clock, not the wall time, so the count follows the
    // local-day tick that refreshes it at midnight.
    final container = ProviderContainer(
      overrides: [
        recentDivesProvider.overrideWith(
          (ref) async => [Dive(id: 'd', dateTime: DateTime(2026, 3, 1, 10))],
        ),
      ],
    );
    addTearDown(container.dispose);
    final days = await withClock(
      Clock.fixed(DateTime(2026, 3, 4, 9)),
      () => container.read(daysSinceLastDiveProvider.future),
    );
    expect(days, 3);
  });
}
