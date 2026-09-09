import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';

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

  DateTime _anchorFor({
    required ServiceSchedule schedule,
    required List<ServiceRecord> records,
    required DateTime? purchaseDate,
    required DateTime equipmentCreatedAt,
  }) {
    DateTime? newest;
    for (final r in records) {
      if (r.serviceKindId != schedule.serviceKindId) continue;
      if (newest == null || r.serviceDate.isAfter(newest)) {
        newest = r.serviceDate;
      }
    }
    return newest ?? schedule.anchorDate ?? purchaseDate ?? equipmentCreatedAt;
  }

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
