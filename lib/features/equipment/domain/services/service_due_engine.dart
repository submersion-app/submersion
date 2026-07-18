import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// Evaluates an equipment item's service clocks. Pure: no database, no
/// DateTime.now() -- callers supply `now` so results are testable and
/// consistent across a single UI frame.
class ServiceDueEngine {
  const ServiceDueEngine();

  List<ServiceClockStatus> evaluate({
    required List<ServiceSchedule> schedules,
    required Map<String, ServiceKind> kindsById,
    required List<ServiceRecord> records,
    required List<DiveUsageSample> usage,
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

      final intervalDays = schedule.intervalDays ?? kind.defaultIntervalDays;
      final intervalDives = schedule.intervalDives ?? kind.defaultIntervalDives;
      final intervalHours = schedule.intervalHours ?? kind.defaultIntervalHours;
      if (intervalDays == null &&
          intervalDives == null &&
          intervalHours == null) {
        continue; // no triggers configured
      }

      final anchor = _anchorFor(
        schedule: schedule,
        records: records,
        purchaseDate: purchaseDate,
        equipmentCreatedAt: equipmentCreatedAt,
      );

      final dueDate = intervalDays != null
          ? anchor.add(Duration(days: intervalDays))
          : null;

      final usageSince = usage.where((u) => u.date.isAfter(anchor)).toList();
      int? divesSince;
      int? divesRemaining;
      if (intervalDives != null) {
        divesSince = usageSince.length;
        divesRemaining = intervalDives - divesSince;
      }
      double? hoursSince;
      double? hoursRemaining;
      if (intervalHours != null) {
        hoursSince =
            usageSince.fold<int>(0, (sum, u) => sum + u.durationSeconds) /
            3600.0;
        hoursRemaining = intervalHours - hoursSince;
      }

      statuses.add(
        ServiceClockStatus(
          schedule: schedule,
          kind: kind,
          anchor: anchor,
          dueDate: dueDate,
          divesSinceAnchor: divesSince,
          divesRemaining: divesRemaining,
          hoursSinceAnchor: hoursSince,
          hoursRemaining: hoursRemaining,
          severity: _severity(
            dueDate: dueDate,
            divesRemaining: divesRemaining,
            intervalDives: intervalDives,
            hoursRemaining: hoursRemaining,
            intervalHours: intervalHours,
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
    required int? divesRemaining,
    required int? intervalDives,
    required double? hoursRemaining,
    required double? intervalHours,
    required int dueSoonWindowDays,
    required DateTime now,
  }) {
    // Date trigger becomes overdue strictly after the due date, matching the
    // legacy single-clock EquipmentItem.isServiceDue (now.isAfter(dueDate)).
    // At exactly the due instant the clock reads dueSoon, not overdue.
    if ((dueDate != null && now.isAfter(dueDate)) ||
        (divesRemaining != null && divesRemaining <= 0) ||
        (hoursRemaining != null && hoursRemaining <= 0)) {
      return ServiceClockSeverity.overdue;
    }
    if (dueDate != null &&
        dueDate.difference(now).inDays <= dueSoonWindowDays) {
      return ServiceClockSeverity.dueSoon;
    }
    if (divesRemaining != null &&
        intervalDives != null &&
        divesRemaining <= (intervalDives * 0.1).ceil()) {
      return ServiceClockSeverity.dueSoon;
    }
    if (hoursRemaining != null &&
        intervalHours != null &&
        hoursRemaining <= intervalHours * 0.1) {
      return ServiceClockSeverity.dueSoon;
    }
    return ServiceClockSeverity.ok;
  }
}
