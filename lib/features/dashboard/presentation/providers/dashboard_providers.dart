import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

/// Dashboard alerts data class
class DashboardAlerts {
  final List<EquipmentItem> equipmentServiceDue;
  final bool insuranceExpiringSoon;
  final bool insuranceExpired;
  final DateTime? insuranceExpiryDate;
  final String? insuranceProvider;

  const DashboardAlerts({
    required this.equipmentServiceDue,
    required this.insuranceExpiringSoon,
    required this.insuranceExpired,
    this.insuranceExpiryDate,
    this.insuranceProvider,
  });

  bool get hasAlerts =>
      equipmentServiceDue.isNotEmpty ||
      insuranceExpiringSoon ||
      insuranceExpired;

  int get alertCount {
    int count = equipmentServiceDue.length;
    if (insuranceExpiringSoon || insuranceExpired) count++;
    return count;
  }
}

/// Recent dives provider (last 5)
final recentDivesProvider = FutureProvider<List<Dive>>((ref) async {
  final allDives = await ref.watch(divesProvider.future);
  // Dives are already sorted by date descending in the repository
  final recent = allDives.take(5).toList();

  // Pre-load downsampled profiles so DiveListTile mini charts render
  // immediately (the batch cache is shared with the paginated dive list).
  if (recent.isNotEmpty) {
    final cache = ref.read(batchProfileCacheProvider);
    final uncached = recent
        .map((d) => d.id)
        .where((id) => !cache.containsKey(id))
        .toList();
    if (uncached.isNotEmpty) {
      final repository = ref.read(diveRepositoryProvider);
      final profiles = await repository.getBatchProfileSummaries(uncached);
      ref.read(batchProfileCacheProvider.notifier).state = {
        ...cache,
        ...profiles,
      };
    }
  }

  return recent;
});

/// Dashboard alerts provider - combines equipment and insurance alerts
final dashboardAlertsProvider = FutureProvider<DashboardAlerts>((ref) async {
  final serviceDue = await ref.watch(serviceDueEquipmentProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);

  return DashboardAlerts(
    equipmentServiceDue: serviceDue,
    insuranceExpiringSoon: diver?.insurance.isExpiringSoon ?? false,
    insuranceExpired: diver?.insurance.isExpired ?? false,
    insuranceExpiryDate: diver?.insurance.expiryDate,
    insuranceProvider: diver?.insurance.provider,
  );
});

/// Current diver provider (re-exported for convenience)
final dashboardDiverProvider = FutureProvider<Diver?>((ref) async {
  return ref.watch(currentDiverProvider.future);
});

/// Days since last dive provider
final daysSinceLastDiveProvider = FutureProvider<int?>((ref) async {
  final recentDives = await ref.watch(recentDivesProvider.future);
  if (recentDives.isEmpty) return null;

  final lastDiveDate = recentDives.first.dateTime;
  final now = DateTime.now();
  return now.difference(lastDiveDate).inDays;
});

/// Monthly dive count provider (dives in current month)
final monthlyDiveCountProvider = FutureProvider<int>((ref) async {
  final allDives = await ref.watch(divesProvider.future);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  return allDives.where((dive) => dive.dateTime.isAfter(startOfMonth)).length;
});

/// Year-to-date dive count provider
final yearToDateDiveCountProvider = FutureProvider<int>((ref) async {
  final allDives = await ref.watch(divesProvider.future);
  final now = DateTime.now();
  final startOfYear = DateTime(now.year, 1, 1);

  return allDives.where((dive) => dive.dateTime.isAfter(startOfYear)).length;
});

/// Personal records data class
class PersonalRecords {
  final Dive? deepestDive;
  final Dive? longestDive;
  final Dive? coldestDive;
  final Dive? warmestDive;
  final String? mostVisitedSiteId;
  final String? mostVisitedSiteName;
  final int? mostVisitedSiteCount;

  const PersonalRecords({
    this.deepestDive,
    this.longestDive,
    this.coldestDive,
    this.warmestDive,
    this.mostVisitedSiteId,
    this.mostVisitedSiteName,
    this.mostVisitedSiteCount,
  });

  bool get hasRecords =>
      deepestDive != null ||
      longestDive != null ||
      coldestDive != null ||
      warmestDive != null ||
      mostVisitedSiteName != null;
}

/// Personal records provider
final personalRecordsProvider = FutureProvider<PersonalRecords>((ref) async {
  final allDives = await ref.watch(divesProvider.future);
  if (allDives.isEmpty) return const PersonalRecords();

  // Find deepest dive
  Dive? deepestDive;
  double maxDepth = 0;
  for (final dive in allDives) {
    if (dive.maxDepth != null && dive.maxDepth! > maxDepth) {
      maxDepth = dive.maxDepth!;
      deepestDive = dive;
    }
  }

  // Find longest dive
  Dive? longestDive;
  int maxDuration = 0;
  for (final dive in allDives) {
    if (dive.duration != null && dive.duration!.inMinutes > maxDuration) {
      maxDuration = dive.duration!.inMinutes;
      longestDive = dive;
    }
  }

  // Find coldest dive
  Dive? coldestDive;
  double? minTemp;
  for (final dive in allDives) {
    if (dive.waterTemp != null) {
      if (minTemp == null || dive.waterTemp! < minTemp) {
        minTemp = dive.waterTemp;
        coldestDive = dive;
      }
    }
  }

  // Find warmest dive
  Dive? warmestDive;
  double? maxTemp;
  for (final dive in allDives) {
    if (dive.waterTemp != null) {
      if (maxTemp == null || dive.waterTemp! > maxTemp) {
        maxTemp = dive.waterTemp;
        warmestDive = dive;
      }
    }
  }

  // Find most visited site
  final siteCounts = <String, int>{};
  final siteNames = <String, String>{};
  for (final dive in allDives) {
    if (dive.site != null) {
      siteCounts[dive.site!.id] = (siteCounts[dive.site!.id] ?? 0) + 1;
      siteNames[dive.site!.id] = dive.site!.name;
    }
  }

  String? mostVisitedSiteId;
  String? mostVisitedSiteName;
  int mostVisitedCount = 0;
  for (final entry in siteCounts.entries) {
    if (entry.value > mostVisitedCount) {
      mostVisitedCount = entry.value;
      mostVisitedSiteId = entry.key;
      mostVisitedSiteName = siteNames[entry.key];
    }
  }

  return PersonalRecords(
    deepestDive: deepestDive,
    longestDive: longestDive,
    coldestDive: coldestDive,
    warmestDive: warmestDive,
    mostVisitedSiteId: mostVisitedSiteId,
    mostVisitedSiteName: mostVisitedSiteName,
    mostVisitedSiteCount: mostVisitedCount > 0 ? mostVisitedCount : null,
  );
});

/// Quick stats data class for dashboard
class DashboardQuickStats {
  final String? topBuddyName;
  final int? topBuddyDiveCount;
  final int countriesVisited;
  final int speciesDiscovered;

  const DashboardQuickStats({
    this.topBuddyName,
    this.topBuddyDiveCount,
    this.countriesVisited = 0,
    this.speciesDiscovered = 0,
  });
}

/// Quick stats provider for dashboard
final dashboardQuickStatsProvider = FutureProvider<DashboardQuickStats>((
  ref,
) async {
  // Get top buddy
  final topBuddies = await ref.watch(topBuddiesProvider.future);
  final topBuddy = topBuddies.isNotEmpty ? topBuddies.first : null;

  // Get countries visited
  final countries = await ref.watch(countriesVisitedProvider.future);

  // Get species count
  final speciesCount = await ref.watch(uniqueSpeciesCountProvider.future);

  return DashboardQuickStats(
    topBuddyName: topBuddy?.name,
    topBuddyDiveCount: topBuddy?.count,
    countriesVisited: countries.length,
    speciesDiscovered: speciesCount,
  );
});
