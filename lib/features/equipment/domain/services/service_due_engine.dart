import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';

/// The date a [serviceKindId] clock counts from, as far as its baseline and
/// its service records say; null when neither does (the caller falls back
/// to the purchase and creation dates).
///
/// A baseline date the diver set outranks the records: a service already
/// logged when the diver set it must not silently undo it. A record logged
/// after [baselineSetAt] and dated on or after the baseline takes the clock
/// over, and the clock then counts from the newest record. A backdated
/// record (older than the baseline) never does, so backfilling history
/// cannot move a clock backwards.
///
/// A null [baselineSetAt] marks a baseline set before v211 or a legacy
/// clock, and keeps the rule those were written under: any record of the
/// kind outranks the baseline. Deriving this from the rows, rather than
/// clearing the baseline when a service is logged, is what keeps it right
/// for a service that arrives by sync from a build that knows nothing of
/// baselines, and on a device that never ran the v211 rung.
DateTime? clockAnchorFromServices({
  required String serviceKindId,
  required DateTime? baseline,
  required DateTime? baselineSetAt,
  required Iterable<ServiceRecord> records,
}) {
  DateTime? newest;
  var supersedesBaseline = false;
  for (final r in records) {
    if (r.serviceKindId != serviceKindId) continue;
    if (newest == null || r.serviceDate.isAfter(newest)) {
      newest = r.serviceDate;
    }
    if (baseline != null &&
        (baselineSetAt == null ||
            (r.createdAt.isAfter(baselineSetAt) &&
                !r.serviceDate.isBefore(baseline)))) {
      supersedesBaseline = true;
    }
  }
  if (baseline != null && !supersedesBaseline) return baseline;
  return newest;
}

/// Evaluates an equipment item's service clocks. Pure: no database, no
/// DateTime.now() -- callers supply `now` so results are testable and
/// consistent across a single UI frame.
class ServiceDueEngine {
  const ServiceDueEngine();

  List<ServiceClockStatus> evaluate({
    required List<ServiceSchedule> schedules,
    required Map<String, ServiceKind> kindsById,
    required List<ServiceRecord> records,
    required List<EquipmentExposureSample> usage,
    ExposureClassifier classifier = const ExposureClassifier(),
    DateTime? purchaseDate,
    required DateTime equipmentCreatedAt,
    required int dueSoonWindowDays,
    required DateTime now,
  }) {
    final statuses = <ServiceClockStatus>[];

    for (final schedule in schedules) {
      if (!schedule.enabled) continue;
      final kind = kindsById[schedule.serviceKindId];
      if (kind == null) continue;

      final intervals = <ExposureUnit, double>{
        for (final unit in ExposureUnit.values)
          if (schedule.intervalFor(unit, kind) case final v? when v > 0)
            unit: v,
      };
      if (intervals.isEmpty) continue; // no triggers configured

      final anchor = _anchorFor(
        schedule: schedule,
        records: records,
        purchaseDate: purchaseDate,
        equipmentCreatedAt: equipmentCreatedAt,
      );

      final intervalDays = intervals[ExposureUnit.days];
      final dueDate = intervalDays != null
          ? anchor.add(Duration(days: intervalDays.round()))
          : null;

      final usageSince = usage.where((u) => u.date.isAfter(anchor)).toList();
      final usageByUnit = <ExposureUnit, ClockUsage>{
        for (final entry in intervals.entries)
          if (entry.key != ExposureUnit.days)
            entry.key: ClockUsage(
              interval: entry.value,
              since: usageSince.fold<double>(
                0,
                (sum, u) => sum + classifier.contribution(u, entry.key),
              ),
            ),
      };

      statuses.add(
        ServiceClockStatus(
          schedule: schedule,
          kind: kind,
          anchor: anchor,
          dueDate: dueDate,
          usageByUnit: usageByUnit,
          severity: _severity(
            dueDate: dueDate,
            usageByUnit: usageByUnit,
            dueSoonWindowDays: dueSoonWindowDays,
            now: now,
          ),
          now: now,
        ),
      );
    }

    statuses.sort((a, b) {
      if (a.severity != b.severity) {
        return b.severity.index.compareTo(a.severity.index);
      }
      final ad = a.dueDate, bd = b.dueDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return statuses;
  }

  /// Where the clock starts counting: [clockAnchorFromServices], else the
  /// purchase date, else when the item was added.
  DateTime _anchorFor({
    required ServiceSchedule schedule,
    required List<ServiceRecord> records,
    required DateTime? purchaseDate,
    required DateTime equipmentCreatedAt,
  }) =>
      clockAnchorFromServices(
        serviceKindId: schedule.serviceKindId,
        baseline: schedule.anchorDate,
        baselineSetAt: schedule.anchorSetAt,
        records: records,
      ) ??
      purchaseDate ??
      equipmentCreatedAt;

  ServiceClockSeverity _severity({
    required DateTime? dueDate,
    required Map<ExposureUnit, ClockUsage> usageByUnit,
    required int dueSoonWindowDays,
    required DateTime now,
  }) {
    // Date trigger becomes overdue strictly after the due date, matching the
    // legacy single-clock EquipmentItem.isServiceDue (now.isAfter(dueDate)).
    // At exactly the due instant the clock reads dueSoon, not overdue.
    if (dueDate != null && now.isAfter(dueDate)) {
      return ServiceClockSeverity.overdue;
    }
    for (final u in usageByUnit.values) {
      if (u.remaining <= 0) return ServiceClockSeverity.overdue;
    }
    if (dueDate != null &&
        dueDate.difference(now).inDays <= dueSoonWindowDays) {
      return ServiceClockSeverity.dueSoon;
    }
    for (final entry in usageByUnit.entries) {
      final u = entry.value;
      // Counts round the 10 percent band up (the v122 dives rule); hours
      // and other fractional units compare directly.
      final band = entry.key.isFractional
          ? u.interval * 0.1
          : (u.interval * 0.1).ceilToDouble();
      if (u.remaining <= band) return ServiceClockSeverity.dueSoon;
    }
    return ServiceClockSeverity.ok;
  }
}
