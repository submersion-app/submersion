import 'package:clock/clock.dart';

import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/career_totals_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// The data behind the Home panels (issue #4824).
//
// Every provider here reads the repository directly with the current diver
// and no filter. None watches a provider from insights_providers.dart other
// than the repository itself: those follow the Insights page's filter, and a
// filter set there must not change Home's numbers.

/// The window the activity calendar and the averages cover.
DateTime homeWindowStart(DateTime now) =>
    DateTime(now.year - 1, now.month, now.day + 1);

/// Dives per calendar day over the last twelve months.
final homeActivityDaysProvider = FutureProvider<Map<DateTime, int>>((
  ref,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  ref.invalidateSelfWhen(localDayChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final now = clock.now();
  return repository.getDailyDiveCounts(
    diverId: diverId,
    from: homeWindowStart(now),
    to: now,
  );
});

/// Dives per month for the last twelve months, empty months as zero.
final homeMonthlyDivesProvider = FutureProvider<List<MonthCount>>((ref) async {
  ref.invalidateSelfWhen(localDayChanges());
  final stats = await ref.watch(diveStatisticsProvider.future);
  return zeroFilledMonths(stats.divesByMonth, clock.now());
});

/// Which consumption lane Home shows: bar a minute for a diver who reads
/// only SAC, litres a minute otherwise.
final homeSacLaneProvider = Provider<GasConsumptionLane>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.gasConsumptionDisplay)) ==
          GasConsumptionDisplay.sac
      ? GasConsumptionLane.sac
      : GasConsumptionLane.rmv,
);

/// The newest 30 dives' SAC (or RMV), oldest first.
final homeSacSeriesProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final lane = ref.watch(homeSacLaneProvider);
  return repository.getRecentSacPerDive(
    diverId: diverId,
    limit: 30,
    pressure: lane == GasConsumptionLane.sac,
  );
});

/// Averages over the last twelve months, for "latest dive against average".
/// SAC is averaged from the series, which already holds the recent dives.
final homeAveragesProvider =
    FutureProvider<({HomeAverages averages, double? sac})>((ref) async {
      final repository = ref.watch(insightsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchInsightsChanges());
      ref.invalidateSelfWhen(localDayChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final since = homeWindowStart(clock.now());
      // Started together: the two reads do not depend on each other.
      final seriesF = ref.watch(homeSacSeriesProvider.future);
      final averagesF = repository.getAveragesSince(
        diverId: diverId,
        since: since,
      );
      final series = await seriesF;
      final averages = await averagesF;
      // Series dates are the wall clock flagged UTC, as in the SQL window.
      final sinceUtc = DateTime.utc(since.year, since.month, since.day);
      return (
        averages: averages,
        sac: averageOf([
          for (final p in series)
            if (!p.date.isBefore(sinceUtc)) p.value,
        ]),
      );
    });

final homeGasMixProvider = FutureProvider<List<DistributionSegment>>((
  ref,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  return repository.getGasMixDistribution(
    diverId: ref.watch(currentDiverIdProvider),
  );
});

final homeDiveTypesProvider = FutureProvider<List<DistributionSegment>>((
  ref,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  return repository.getDiveTypeDistribution(
    diverId: ref.watch(currentDiverIdProvider),
  );
});

final homeTopBuddiesProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  return repository.getTopBuddies(
    diverId: ref.watch(currentDiverIdProvider),
    limit: 3,
  );
});

/// Species seen most over the diver's last 20 dives.
final homeRecentSpeciesProvider = FutureProvider<List<SpeciesSighting>>((
  ref,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  return repository.getRecentSpeciesSightings(
    diverId: ref.watch(currentDiverIdProvider),
    recentDives: 20,
    limit: 3,
  );
});

/// The newest dive with its depth profile thinned to at most 120 points,
/// as (seconds, metres) pairs. Read through the detail provider, as the old
/// preview did, so a reparse or a sync rewriting the samples refreshes it;
/// that read decodes off the UI isolate.
final homeLatestProfileProvider =
    FutureProvider<({Dive dive, List<(double, double)> points})?>((ref) async {
      final dives = await ref.watch(recentDivesProvider.future);
      final newest = dives.firstOrNull;
      if (newest == null) return null;
      final dive = await ref.watch(diveProvider(newest.id).future) ?? newest;
      final profile = dive.profile;
      final times = downsample([
        for (final p in profile) p.timestamp.toDouble(),
      ], 120);
      final depths = downsample([for (final p in profile) p.depth], 120);
      return (
        dive: dive,
        points: [for (var i = 0; i < times.length; i++) (times[i], depths[i])],
      );
    });

/// Gear bars, the items nearest their service.
final homeGearServiceProvider = FutureProvider<List<GearServiceBar>>((
  ref,
) async {
  ref.invalidateSelfWhen(localDayChanges());
  final clocks = await ref.watch(activeEquipmentClocksProvider.future);
  return gearServiceBars(clocks);
});

/// Gear services, insurance, certifications and documents coming due.
final homeComingDueProvider = FutureProvider<List<ComingDueItem>>((ref) async {
  ref.invalidateSelfWhen(localDayChanges());
  final clocks = await ref.watch(activeEquipmentClocksProvider.future);
  final gauges = await ref.watch(dashboardGaugesProvider.future);
  // A state notifier, not a future: certifications join once loaded, and
  // the panel rebuilds when they do.
  final certs = ref.watch(certificationListNotifierProvider).value ?? const [];
  return comingDueItems(
    clocks: clocks,
    insurance: gauges.insurance,
    certifications: [
      for (final c in certs)
        if (c.expiryDate != null)
          (id: c.id, name: c.name, expiry: c.expiryDate!),
    ],
    documents: [
      for (final (doc, _) in gauges.attentionDocuments)
        if (doc.expiryDate != null)
          (id: doc.id, name: doc.title, expiry: doc.expiryDate!),
    ],
    now: clock.now(),
  );
});

/// Distinct species the diver has seen.
final homeSpeciesCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  return repository.getUniqueSpeciesCount(
    diverId: ref.watch(currentDiverIdProvider),
  );
});

/// Species the diver saw for the first time this calendar year.
final homeNewSpeciesThisYearProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  ref.invalidateSelfWhen(localDayChanges());
  return repository.getSpeciesFirstSeenSince(
    diverId: ref.watch(currentDiverIdProvider),
    since: DateTime(clock.now().year),
  );
});

/// Everything the key numbers panel shows. Each source refreshes itself, so
/// this rebuilds whenever one of them does.
final homeKeyNumbersProvider = FutureProvider<HomeKeyNumbers>((ref) async {
  final lane = ref.watch(homeSacLaneProvider);

  // Watched together before any await, so they load in parallel.
  final careerF = ref.watch(careerTotalsProvider.future);
  final yearF = ref.watch(yearInReviewProvider.future);
  final monthsF = ref.watch(homeMonthlyDivesProvider.future);
  final recentF = ref.watch(recentDivesProvider.future);
  final daysF = ref.watch(daysSinceLastDiveProvider.future);
  final sacF = ref.watch(homeSacSeriesProvider.future);
  final gaugesF = ref.watch(dashboardGaugesProvider.future);
  final checklistF = ref.watch(homeTripChecklistProvider.future);
  final speciesF = ref.watch(homeSpeciesCountProvider.future);
  final newSpeciesF = ref.watch(homeNewSpeciesThisYearProvider.future);

  // Only the career totals are essential: any other source failing leaves
  // its tile out instead of turning every tile into an error.
  Future<T?> optional<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  final career = await careerF;
  final year = await optional(yearF);
  final months = await optional(monthsF) ?? const [];
  final recent = await optional(recentF) ?? const [];
  final days = await optional(daysF);
  final sac = await optional(sacF) ?? const [];
  final gauges = await optional(gaugesF);
  final checklist = await optional(checklistF);
  final species = await optional(speciesF);
  final newSpecies = await optional(newSpeciesF);

  final sacValues = [for (final p in sac) p.value];
  final last10 = sacValues.length <= 10
      ? sacValues
      : sacValues.sublist(sacValues.length - 10);
  // A change is claimed only against a full ten earlier dives.
  final prev10 = sacValues.length < 20
      ? const <double>[]
      : sacValues.sublist(sacValues.length - 20, sacValues.length - 10);
  final avgSac = averageOf(last10);
  final prevSac = averageOf(prev10);
  final trip = gauges?.nextTrip;
  final latest = recent.firstOrNull;

  return HomeKeyNumbers(
    careerDives: career.combinedDives,
    careerTimeSeconds: career.combinedTimeSeconds,
    divesThisYear: year?.current.diveCount,
    timeThisYearSeconds: year?.current.totalSeconds,
    monthlySeries: [for (final m in months) m.count.toDouble()],
    daysSinceLastDive: latest == null ? null : days,
    lastDiveId: latest?.id,
    lastDiveSite: latest?.site?.name ?? latest?.name,
    avgSac: avgSac,
    avgSacChange: avgSac != null && prevSac != null ? avgSac - prevSac : null,
    sacSeries: sacValues,
    sacLane: lane,
    deepestThisYear: year?.current.maxDepth,
    deepestLastYear: year?.previous.maxDepth,
    nextTrip: trip,
    tripChecklistDone: checklist != null && checklist.trip.id == trip?.id
        ? checklist.done
        : null,
    tripChecklistTotal: checklist != null && checklist.trip.id == trip?.id
        ? checklist.total
        : null,
    avgDepthThisYear: year?.current.avgMaxDepth,
    avgDepthLastYear: year?.previous.avgMaxDepth,
    species: species,
    newSpeciesThisYear: newSpecies,
  );
});
