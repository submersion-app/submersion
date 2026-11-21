import 'dart:math' as math;

import 'package:clock/clock.dart';

import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
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

/// The first day of the [months] months ending today, the window the
/// activity calendar and the averages cover: the day after the same date
/// [months] months back. The day is clamped to that month's length, so 31
/// August looks back to 28 February and starts on 1 March, not on 4 March.
DateTime homeWindowStart(DateTime now, {int months = 12}) {
  final back = DateTime(now.year, now.month - months);
  final lastDay = DateTime(back.year, back.month + 1, 0).day;
  return DateTime(back.year, back.month, math.min(now.day, lastDay) + 1);
}

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
/// SAC is averaged over every dive with one in the same window, read with a
/// date filter, not from the trend panel's newest 30.
final homeAveragesProvider =
    FutureProvider<({HomeAverages averages, double? sac})>((ref) async {
      final repository = ref.watch(insightsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchInsightsChanges());
      ref.invalidateSelfWhen(localDayChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      final pressure = ref.watch(homeSacLaneProvider) == GasConsumptionLane.sac;
      final since = homeWindowStart(clock.now());
      final window = DiveFilterState(startDate: since);
      // Started together: the two reads do not depend on each other. Awaited
      // through Future.wait, which listens to both at once: awaiting them in
      // turn would leave the second unheard, and an error it raised before
      // the first finished would be reported as uncaught.
      final sacF = pressure
          ? repository.getSacPressurePerDive(diverId: diverId, filter: window)
          : repository.getSacVolumePerDive(diverId: diverId, filter: window);
      final averagesF = repository.getAveragesSince(
        diverId: diverId,
        since: since,
      );
      await Future.wait<Object>([sacF, averagesF]);
      final sac = await sacF;
      final averages = await averagesF;
      return (
        averages: averages,
        sac: averageOf([for (final p in sac) p.value]),
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
      // Null when the newest dive was deleted between the two reads: the
      // panel collapses until the recent dives catch up, rather than drawing
      // the stale list copy of a dive that is gone.
      final dive = await ref.watch(diveProvider(newest.id).future);
      if (dive == null) return null;
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

/// Whether the diver has any active gear, scheduled for service or not: the
/// gear service panel tells "no gear" from "no service schedules" by it,
/// since only scheduled gear has a clock.
final homeHasGearProvider = FutureProvider<bool>((ref) async {
  final clocks = await ref.watch(activeEquipmentClocksProvider.future);
  return clocks.isNotEmpty;
});

/// Gear services, insurance, certifications and documents coming due.
///
/// Documents are read in full rather than taken from the status lights,
/// which hold only those already inside their reminder window: the panel
/// looks a year ahead.
final homeComingDueProvider = FutureProvider<List<ComingDueItem>>((ref) async {
  ref.invalidateSelfWhen(localDayChanges());
  final documentRepository = ref.watch(documentRepositoryProvider);
  ref.invalidateSelfWhen(documentRepository.watchChanges());
  // Watched together before any await, so they load in parallel.
  final clocksF = ref.watch(activeEquipmentClocksProvider.future);
  final gaugesF = ref.watch(dashboardGaugesProvider.future);
  final diverF = ref.watch(validatedCurrentDiverIdProvider.future);
  // A state notifier, not a future: certifications join once loaded, and
  // the panel rebuilds when they do.
  final certs = ref.watch(certificationListNotifierProvider).value ?? const [];
  final clocks = await clocksF;
  final gauges = await gaugesF;
  final diverId = await diverF;
  return comingDueItems(
    clocks: clocks,
    insurance: gauges.insurance,
    certifications: [
      for (final c in certs)
        if (c.expiryDate != null)
          (id: c.id, name: c.name, expiry: c.expiryDate!),
    ],
    documents: diverId == null
        ? const []
        : await _expiringDocuments(documentRepository, diverId),
    now: clock.now(),
  );
});

const _log = LoggerService('HomePanels');

/// The diver's dated documents other than insurance, which the panel takes
/// from the diver's policy. A failed read leaves the documents out rather
/// than hiding the gear and certifications with it.
Future<List<DocumentExpiry>> _expiringDocuments(
  DocumentRepository repository,
  String diverId,
) async {
  try {
    return [
      for (final doc in await repository.getRemindingForDiver(diverId))
        if (doc.type != DocumentType.insurance && doc.expiryDate != null)
          (
            id: doc.id,
            name: doc.title.trim(),
            expiry: doc.expiryDate!,
            type: doc.type,
          ),
    ];
  } catch (e, stackTrace) {
    _log.error(
      'Failed to read documents for coming due',
      error: e,
      stackTrace: stackTrace,
    );
    return const [];
  }
}

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

/// The deepest dive this calendar year, which the deepest tile names by its
/// site and opens.
final homeDeepestThisYearProvider =
    FutureProvider<({String id, String? site})?>((ref) async {
      final repository = ref.watch(insightsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchInsightsChanges());
      // The year is read once per build, so New Year must rebuild it too.
      ref.invalidateSelfWhen(localDayChanges());
      return repository.getDeepestDiveOfYear(
        clock.now().year,
        diverId: ref.watch(currentDiverIdProvider),
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
  final deepestF = ref.watch(homeDeepestThisYearProvider.future);

  // Only the career totals are essential: any other source failing leaves
  // its tile out instead of turning every tile into an error.
  Future<T?> optional<T>(Future<T> f) async {
    try {
      return await f;
    } catch (e, stackTrace) {
      _log.error(
        'A key number source failed; its tile is left out',
        error: e,
        stackTrace: stackTrace,
      );
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
  final deepest = await optional(deepestF);

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
    lastDiveDate: latest?.effectiveEntryTime,
    avgSac: avgSac,
    avgSacChange: avgSac != null && prevSac != null ? avgSac - prevSac : null,
    sacSeries: sacValues,
    sacLane: lane,
    deepestThisYear: year?.current.maxDepth,
    deepestLastYear: year?.previous.maxDepth,
    deepestDiveId: deepest?.id,
    deepestDiveSite: deepest?.site,
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
