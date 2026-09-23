import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Every chip type the gauge strip can show. [name] is the stable id
/// stored in AppSettings.hiddenHomeChips; all types are visible by
/// default.
enum HomeChipType {
  gear,
  insurance,
  noFly,
  lastDive,
  certifications,
  trip,
  checklist,
  course,
  uploads,
  backup,
  sync,
  dataQuality,
  flightWindow,
}

/// The worst service clock for one equipment type, shown as one chip.
class GearGauge {
  final EquipmentType type;

  /// Id of the item the chip names, so the tap can open that item rather
  /// than the equipment list (issue #816).
  final String itemId;
  final String itemName;
  final ServiceClockStatus status;

  const GearGauge({
    required this.type,
    required this.itemId,
    required this.itemName,
    required this.status,
  });
}

/// One severity bucket of due gear, rendered as a single chip.
///
/// [count] is a count of ITEMS rather than of clocks, because it is also the
/// row count of the filtered equipment list the chip opens: a chip promising
/// three and landing on five rows would be lying about where it goes.
class GearSeverityGroup {
  final int count;

  /// The bucket's most urgent member. It names the chip when [count] is 1,
  /// and supplies the remaining days when it is not.
  final GearGauge worst;

  const GearSeverityGroup({required this.count, required this.worst});
}

/// Always-on status values for the dashboard gauge strip.
class DashboardGauges {
  /// Gear whose worst service clock has lapsed, or null if none has.
  final GearSeverityGroup? gearOverdue;

  /// Gear due for service soon, excluding anything already overdue, or null
  /// if none is.
  final GearSeverityGroup? gearDueSoon;

  final bool hasGear;
  final DiverInsurance? insurance;
  final NoFlyStatus? noFlyStatus;
  final int? daysSinceLastDive;

  /// Certifications expiring within 90 days plus already-expired ones.
  final int expiringCertCount;

  /// Next trip whose start date is in the future, if any.
  final Trip? nextTrip;

  /// Id of the pre-dive checklist run in progress, if any.
  final String? activeChecklistId;

  /// First in-progress course with requirements, if any.
  final ActiveCourseProgress? firstCourse;

  /// Media-store transfers that are pending, in flight, or failed.
  final int uploadsPending;

  /// Timestamp of the last successful backup (manual or automatic).
  final DateTime? lastBackupTime;

  /// Whether a cloud sync backend is configured; sync chip hides otherwise.
  final bool syncEnabled;

  /// Records waiting to be synced.
  final int syncPending;

  /// Open data-quality findings.
  final int dataQualityFindings;

  /// Dive window before the active trip's return flight, if one is set.
  final FlightWindowStatus? flightWindow;

  const DashboardGauges({
    this.gearOverdue,
    this.gearDueSoon,
    required this.hasGear,
    required this.insurance,
    required this.noFlyStatus,
    required this.daysSinceLastDive,
    this.expiringCertCount = 0,
    this.nextTrip,
    this.activeChecklistId,
    this.firstCourse,
    this.uploadsPending = 0,
    this.lastBackupTime,
    this.syncEnabled = false,
    this.syncPending = 0,
    this.dataQualityFindings = 0,
    this.flightWindow,
  });
}

int _severityRank(ServiceClockSeverity s) => switch (s) {
  ServiceClockSeverity.overdue => 2,
  ServiceClockSeverity.dueSoon => 1,
  ServiceClockSeverity.ok => 0,
};

/// Orders gauges of equal severity by urgency: earliest dueDate first,
/// undated last.
int _byDueDate(GearGauge a, GearGauge b) {
  final ad = a.status.dueDate;
  final bd = b.status.dueDate;
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1;
  if (bd == null) return -1;
  return ad.compareTo(bd);
}

/// The worst clock on one item, or null if the item has no clocks.
ServiceClockStatus? _worstStatus(List<ServiceClockStatus> statuses) {
  ServiceClockStatus? worst;
  for (final status in statuses) {
    if (worst == null) {
      worst = status;
      continue;
    }
    final rankNew = _severityRank(status.severity);
    final rankCur = _severityRank(worst.severity);
    if (rankNew > rankCur) {
      worst = status;
    } else if (rankNew == rankCur) {
      final newDue = status.dueDate;
      final curDue = worst.dueDate;
      if (newDue != null && (curDue == null || newDue.isBefore(curDue))) {
        worst = status;
      }
    }
  }
  return worst;
}

/// Collapses the gauges of one severity into the chip that speaks for them,
/// or null when nothing is in the bucket.
GearSeverityGroup? _severityGroup(List<GearGauge> gauges) {
  if (gauges.isEmpty) return null;
  return GearSeverityGroup(
    count: gauges.length,
    worst: gauges.reduce((a, b) => _byDueDate(a, b) <= 0 ? a : b),
  );
}

/// Buckets active gear into one group per due severity, which the strip
/// renders as at most one chip each.
///
/// Every item lands in exactly one bucket, chosen by its WORST clock: a
/// regulator that is overdue for a service and also due soon for a hose swap
/// is one overdue thing to deal with, not two. That also matches the filtered
/// equipment lists the chips open, which show each item once.
///
/// Items are counted individually rather than collapsed per equipment type:
/// four lapsed regulators are four things the diver has to service, and the
/// list the chip opens has four rows in it.
({GearSeverityGroup? overdue, GearSeverityGroup? dueSoon}) gearSeverityGroups(
  List<EquipmentClocks> clocks,
) {
  final overdue = <GearGauge>[];
  final dueSoon = <GearGauge>[];
  for (final entry in clocks) {
    final worst = _worstStatus(entry.statuses);
    if (worst == null || worst.severity == ServiceClockSeverity.ok) continue;
    final gauge = GearGauge(
      type: entry.item.type,
      itemId: entry.item.id,
      itemName: entry.item.name,
      status: worst,
    );
    (worst.severity == ServiceClockSeverity.overdue ? overdue : dueSoon).add(
      gauge,
    );
  }
  return (overdue: _severityGroup(overdue), dueSoon: _severityGroup(dueSoon));
}

/// The next trip whose start date is still ahead, or null.
Trip? nextUpcomingTrip(List<Trip> trips, DateTime now) {
  Trip? next;
  for (final trip in trips) {
    if (!trip.startDate.isAfter(now)) continue;
    if (next == null || trip.startDate.isBefore(next.startDate)) {
      next = trip;
    }
  }
  return next;
}

/// Always-on gauges: due/overdue gear clocks (capped), insurance, no-fly,
/// days since last dive, plus attention chips (certifications, trip,
/// checklist, course, uploads, backup, sync, data quality).
final dashboardGaugesProvider = FutureProvider<DashboardGauges>((ref) async {
  final clocks = await ref.watch(activeEquipmentClocksProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);
  final noFly = await ref.watch(noFlyStatusProvider.future);
  final flightWindow = await ref.watch(activeTripFlightWindowProvider.future);
  final daysSince = await ref.watch(daysSinceLastDiveProvider.future);
  final certCount = await ref.watch(expiringCertificationCountProvider.future);
  final trips = await ref.watch(allTripsProvider.future);
  final activeSession = await ref.watch(preDiveActiveSessionProvider.future);
  final courses = await ref.watch(activeCoursesProgressProvider.future);
  final uploads =
      ref.watch(mediaTransferSummaryProvider).valueOrNull?.total ?? 0;
  final lastBackup = ref.watch(lastBackupTimeProvider);
  final syncEnabled = ref.watch(isSyncEnabledProvider);
  final syncPending = ref.watch(pendingChangesCountProvider);
  final findings = ref.watch(openQualityFindingsCountProvider).valueOrNull ?? 0;

  final firstCourse = courses
      .where((c) => c.progress.totalCount > 0)
      .firstOrNull;

  final gear = gearSeverityGroups(clocks);

  return DashboardGauges(
    gearOverdue: gear.overdue,
    gearDueSoon: gear.dueSoon,
    hasGear: clocks.isNotEmpty,
    insurance: diver?.insurance,
    noFlyStatus: noFly,
    daysSinceLastDive: daysSince,
    expiringCertCount: certCount,
    nextTrip: nextUpcomingTrip(trips, DateTime.now()),
    activeChecklistId: activeSession?.id,
    firstCourse: firstCourse,
    uploadsPending: uploads,
    lastBackupTime: lastBackup,
    syncEnabled: syncEnabled,
    syncPending: syncPending,
    dataQualityFindings: findings,
    flightWindow: flightWindow,
  );
});
