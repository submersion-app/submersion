import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/battery_cycles.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';

import 'gear_catalog.dart';
import 'seed_context.dart';

/// Clocks the story leaves overdue today: the lake cylinder's visual
/// inspection, and the drysuit's seals (it leaks).
const overdueClocks = {('tank-12', 'vip'), ('drysuit', 'drysuit-seals')};

/// Clocks the story leaves due soon: two batteries.
const dueSoonClocks = {
  ('computer-ai', 'computer-battery'),
  ('transmitter-cold', 'transmitter-battery'),
};

/// Schedules the app does not attach by itself.
const _manualSchedules = [
  ('drysuit', 'drysuit-seals', null),
  ('stage-2', 'o2-clean', null),
  ('reg-stage-2', 'o2-clean', null),
  ('dpv', 'general-service', 365),
  ('housing', 'general-service', 365),
];

/// Every service clock on the diver's active gear at [now], wired as the
/// app's own provider wires the engine (fitted parts only, rebreather loop
/// time, battery cycles).
Future<List<(String key, ServiceClockStatus status)>> demoClockStatuses(
  DemoSeedContext ctx,
  DateTime now,
) async {
  final repo = EquipmentRepository();
  final schedules = ServiceScheduleRepository();
  final records = ServiceRecordRepository();
  final kinds = {
    for (final k in await ServiceKindRepository().getAllKinds()) k.id: k,
  };
  final window = await schedules.getDueSoonWindowDays(
    diverId: DemoSeedContext.diverId,
  );
  final keyOf = {for (final e in ctx.equipment.entries) e.value: e.key};
  final out = <(String, ServiceClockStatus)>[];
  for (final item in await repo.getActiveEquipment(
    diverId: DemoSeedContext.diverId,
  )) {
    final itemSchedules = await schedules.getSchedulesForEquipment(item.id);
    if (itemSchedules.isEmpty) continue;
    for (final status in await _evaluate(
      repo,
      item,
      itemSchedules,
      kinds,
      await records.getRecordsForEquipment(item.id),
      window,
      now,
    )) {
      out.add((keyOf[item.id]!, status));
    }
  }
  return out;
}

Future<List<ServiceClockStatus>> _evaluate(
  EquipmentRepository repo,
  EquipmentItem item,
  List<ServiceSchedule> schedules,
  Map<String, ServiceKind> kinds,
  List<ServiceRecord> records,
  int window,
  DateTime now,
) async {
  final exposure = await repo.getItemExposure(item);
  return const ServiceDueEngine().evaluate(
    schedules: schedules,
    kindsById: kinds,
    records: records,
    usage: exposure.samples,
    classifier: ExposureClassifier(
      thresholds: ExposureThresholds.defaults,
      loopTimeOnly: exposure.isRebreather,
      countsCycles: accruesBatteryCycles(
        type: item.type,
        schedules: schedules,
        kindsById: kinds,
      ),
      hasBatteryChild: exposure.fittedChildren.any(
        (c) => c.type == EquipmentType.battery,
      ),
    ),
    purchaseDate: item.purchaseDate,
    equipmentCreatedAt: item.createdAt ?? now,
    dueSoonWindowDays: window,
    now: now,
  );
}

/// The service history of every clock: each one serviced on a home day as
/// it comes due, by the calendar or by use, from purchase until the item
/// left. Today two clocks are overdue and two due soon; the rest are fine.
class GearServiceSeeder implements DemoSeeder {
  @override
  String get name => 'service history';

  final _records = ServiceRecordRepository();
  var _n = 0;

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final repo = EquipmentRepository();
    final schedules = ServiceScheduleRepository();
    final kinds = {
      for (final k in await ServiceKindRepository().getAllKinds()) k.id: k,
    };
    for (final (key, kind, days) in _manualSchedules) {
      final at = ctx.timeline.boughtOn(key)!;
      await schedules.createSchedule(
        ServiceSchedule(
          id: 'demo-schedule-$key-$kind',
          equipmentId: ctx.equipment[key]!,
          serviceKindId: kind,
          intervalDays: days,
          enabled: true,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }

    const classifier = ExposureClassifier(
      thresholds: ExposureThresholds.defaults,
    );
    for (final g in demoGear) {
      final bought = ctx.timeline.boughtOn(g.key);
      if (bought == null) continue;
      final id = ctx.equipment[g.key]!;
      final item = (await repo.getEquipmentById(id))!;
      final exposure = await repo.getItemExposure(item);
      final until = ctx.timeline.leftOn(g.key) ?? ctx.anchor;
      for (final schedule in await schedules.getSchedulesForEquipment(id)) {
        final kind = kinds[schedule.serviceKindId];
        if (kind == null) continue;
        final dates = _history(
          ctx,
          from: bought,
          until: until,
          days: schedule.intervalFor(ExposureUnit.days, kind),
          usage: {
            for (final unit in ExposureUnit.values)
              if (unit != ExposureUnit.days)
                if (schedule.intervalFor(unit, kind) case final v? when v > 0)
                  unit: v,
          },
          samples: [
            for (final s in exposure.samples)
              (
                s.date,
                {
                  for (final unit in ExposureUnit.values)
                    unit: classifier.contribution(s, unit),
                },
              ),
          ],
          clock: (g.key, kind.id),
        );
        for (final date in dates) {
          await _record(ctx, g.key, kind, date);
        }
      }
    }

    // Clocks the app attached itself are stamped with the build clock; each
    // belongs to its item's purchase.
    await ctx.db.customStatement(
      'UPDATE service_schedules SET created_at = (SELECT purchase_date FROM '
      'equipment e WHERE e.id = service_schedules.equipment_id), updated_at = '
      '(SELECT purchase_date FROM equipment e WHERE e.id = '
      'service_schedules.equipment_id) WHERE created_at > ? AND EXISTS '
      '(SELECT 1 FROM equipment e WHERE e.id = service_schedules.equipment_id '
      'AND e.purchase_date IS NOT NULL)',
      [ctx.anchor.millisecondsSinceEpoch],
    );

    // Anything else the dice left due in the explorer's first two weeks gets
    // serviced after the last weekend, as a diver clears the list.
    final tidy = ctx.timeline.homeDayOnOrBefore(
      ctx.anchor.subtract(const Duration(days: 2)),
    );
    final explorerLatest = ctx.anchor.add(const Duration(days: 14));
    for (final (key, status) in await demoClockStatuses(ctx, explorerLatest)) {
      final clock = (key, status.kind.id);
      if (status.severity == ServiceClockSeverity.ok ||
          overdueClocks.contains(clock) ||
          dueSoonClocks.contains(clock)) {
        continue;
      }
      await _record(ctx, key, status.kind, tidy);
    }
  }

  /// When one clock was serviced. Designated clocks stop early enough to be
  /// overdue or due soon today.
  List<DateTime> _history(
    DemoSeedContext ctx, {
    required DateTime from,
    required DateTime until,
    required double? days,
    required Map<ExposureUnit, double> usage,
    required List<(DateTime, Map<ExposureUnit, double>)> samples,
    required (String, String) clock,
  }) {
    var last = from;
    final dates = <DateTime>[];
    final used = {for (final u in usage.keys) u: 0.0};
    void service(DateTime when) {
      var day = ctx.timeline.homeDayOnOrBefore(when);
      if (!day.isAfter(last)) day = ctx.timeline.homeDayOnOrAfter(when);
      if (!day.isAfter(last) || !day.isBefore(until)) return;
      dates.add(day);
      last = day;
      for (final u in used.keys) {
        used[u] = 0;
      }
    }

    DateTime? calendarDue() =>
        days == null ? null : last.add(Duration(days: (days * 0.92).round()));
    // Services by the calendar up to [limit].
    void catchUp(DateTime limit) {
      for (
        var due = calendarDue();
        due != null && due.isBefore(limit);
        due = calendarDue()
      ) {
        final before = last;
        service(due);
        if (last == before) break;
      }
    }

    for (final (date, contribution) in samples) {
      if (!date.isAfter(from) || !date.isBefore(until)) continue;
      catchUp(date);
      final over = usage.entries.any(
        (e) => used[e.key]! + (contribution[e.key] ?? 0) > e.value * 0.9,
      );
      if (over) service(date.subtract(const Duration(days: 1)));
      for (final u in used.keys) {
        used[u] = used[u]! + (contribution[u] ?? 0);
      }
    }
    catchUp(until);

    // Today's state for the designated clocks.
    if (days != null && overdueClocks.contains(clock)) {
      final cutoff = ctx.anchor.subtract(Duration(days: days.round() + 40));
      dates.removeWhere((d) => d.isAfter(cutoff));
    }
    if (days != null && dueSoonClocks.contains(clock)) {
      final target = ctx.timeline.homeDayOnOrBefore(
        ctx.anchor.subtract(Duration(days: days.round() - 15)),
      );
      dates
        ..removeWhere((d) => !d.isBefore(target))
        ..add(target);
    }
    return dates;
  }

  Future<void> _record(
    DemoSeedContext ctx,
    String key,
    ServiceKind kind,
    DateTime date,
  ) async {
    final category = switch (kind.id) {
      'hydro' || 'vip' || 'bcd-inspection' => ServiceCategory.inspection,
      'o2-clean' => ServiceCategory.cleaning,
      'computer-battery' ||
      'transmitter-battery' ||
      'scrubber-repack' ||
      'o2-cell-replacement' => ServiceCategory.replacement,
      'drysuit-seals' => ServiceCategory.repair,
      _ => ServiceCategory.annual,
    };
    final (provider, cost) = switch (category) {
      ServiceCategory.inspection => ('Dive centre test station', 25.0),
      ServiceCategory.cleaning => ('Gas blending shop', 45.0),
      ServiceCategory.replacement => ('Self', 15.0),
      ServiceCategory.repair => ('Drysuit repair', 140.0),
      _ => ('Regulator service shop', 95.0),
    };
    await _records.createRecord(
      ServiceRecord(
        id: 'demo-service-${_n++}',
        equipmentId: ctx.equipment[key]!,
        serviceCategory: category,
        serviceKindId: kind.id,
        serviceDate: date,
        provider: provider,
        cost: cost,
        currency: 'EUR',
        notes: kind.name,
        createdAt: date,
        updatedAt: date,
      ),
    );
  }
}
