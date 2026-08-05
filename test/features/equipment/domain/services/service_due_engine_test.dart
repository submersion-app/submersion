import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';

void main() {
  const engine = ServiceDueEngine();
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 7, 16);

  ServiceKind hydro() => ServiceKind(
    id: 'hydro',
    name: 'Hydro',
    defaultIntervalDays: 1825,
    applicableTypes: const [EquipmentType.tank],
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  ServiceKind regService() => ServiceKind(
    id: 'regulator-service',
    name: 'Reg service',
    defaultIntervalDays: 365,
    defaultIntervalDives: 100,
    applicableTypes: const [EquipmentType.regulator],
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  ServiceSchedule sched(
    String kindId, {
    int? days,
    int? dives,
    double? hours,
    DateTime? anchor,
    bool enabled = true,
  }) => ServiceSchedule(
    id: 's-$kindId',
    equipmentId: 'e1',
    serviceKindId: kindId,
    intervalDays: days,
    intervalDives: dives,
    intervalHours: hours,
    anchorDate: anchor,
    enabled: enabled,
    createdAt: t0,
    updatedAt: t0,
  );
  ServiceRecord record(String kindId, DateTime date) => ServiceRecord(
    id: 'r-$kindId-${date.millisecondsSinceEpoch}',
    equipmentId: 'e1',
    serviceType: ServiceType.other,
    serviceKindId: kindId,
    serviceDate: date,
    createdAt: date,
    updatedAt: date,
  );

  List<ServiceClockStatus> run({
    required List<ServiceSchedule> schedules,
    List<ServiceKind> kinds = const [],
    List<ServiceRecord> records = const [],
    List<DiveUsageSample> usage = const [],
    DateTime? purchaseDate,
  }) => engine.evaluate(
    schedules: schedules,
    kindsById: {for (final k in kinds) k.id: k},
    records: records,
    usage: usage,
    purchaseDate: purchaseDate,
    equipmentCreatedAt: t0,
    dueSoonWindowDays: 30,
    now: now,
  );

  test('date trigger: anchor from newest matching record', () {
    final statuses = run(
      schedules: [sched('hydro')],
      kinds: [hydro()],
      records: [
        record('hydro', DateTime(2022, 6, 1)),
        record('hydro', DateTime(2024, 6, 1)), // newest wins
      ],
    );
    expect(statuses.single.anchor, DateTime(2024, 6, 1));
    expect(
      statuses.single.dueDate,
      DateTime(2024, 6, 1).add(const Duration(days: 1825)),
    );
    expect(statuses.single.severity, ServiceClockSeverity.ok);
  });

  test('anchor fallback chain: anchorDate, purchaseDate, createdAt', () {
    expect(
      run(
        schedules: [sched('hydro', anchor: DateTime(2023, 3, 1))],
        kinds: [hydro()],
      ).single.anchor,
      DateTime(2023, 3, 1),
    );
    expect(
      run(
        schedules: [sched('hydro')],
        kinds: [hydro()],
        purchaseDate: DateTime(2024, 2, 2),
      ).single.anchor,
      DateTime(2024, 2, 2),
    );
    expect(
      run(schedules: [sched('hydro')], kinds: [hydro()]).single.anchor,
      t0,
    );
  });

  test('overdue when date trigger passed', () {
    final statuses = run(
      schedules: [sched('hydro', anchor: DateTime(2021, 1, 1))],
      kinds: [hydro()],
    );
    expect(statuses.single.severity, ServiceClockSeverity.overdue);
    expect(statuses.single.daysUntilDue, isNegative);
  });

  test('at the exact due instant reads dueSoon, not overdue', () {
    // Regression: the date trigger must become overdue strictly AFTER the due
    // date (now.isAfter), matching legacy EquipmentItem.isServiceDue. At the
    // exact due instant it should still read dueSoon (within the window).
    final anchor = now.subtract(const Duration(days: 1825)); // due == now
    final statuses = run(
      schedules: [sched('hydro', anchor: anchor)],
      kinds: [hydro()],
    );
    expect(statuses.single.dueDate, now);
    expect(statuses.single.severity, ServiceClockSeverity.dueSoon);
  });

  test('dueSoon when date within window', () {
    // due = anchor + 1825d; pick anchor so due lands 20 days from now.
    final anchor = now.add(const Duration(days: 20 - 1825));
    final statuses = run(
      schedules: [sched('hydro', anchor: anchor)],
      kinds: [hydro()],
    );
    expect(statuses.single.severity, ServiceClockSeverity.dueSoon);
  });

  test('whichever comes first: dive trigger overdue beats healthy date', () {
    final usage = List.generate(
      100,
      (i) => DiveUsageSample(
        date: DateTime(2026, 1, 1).add(Duration(days: i)),
        durationSeconds: 3600,
      ),
    );
    final statuses = run(
      schedules: [sched('regulator-service', anchor: DateTime(2025, 12, 1))],
      kinds: [regService()],
      usage: usage,
    );
    // Date due is 2026-11-30 (fine) but 100 of 100 dives are used up.
    expect(statuses.single.divesSinceAnchor, 100);
    expect(statuses.single.divesRemaining, 0);
    expect(statuses.single.severity, ServiceClockSeverity.overdue);
  });

  test('usage dueSoon at 10 percent remaining', () {
    final usage = List.generate(
      91,
      (i) => DiveUsageSample(
        date: DateTime(2026, 1, 1).add(Duration(hours: i)),
        durationSeconds: 3600,
      ),
    );
    final statuses = run(
      schedules: [sched('regulator-service', anchor: DateTime(2025, 12, 1))],
      kinds: [regService()],
      usage: usage,
    );
    expect(statuses.single.divesRemaining, 9);
    expect(statuses.single.severity, ServiceClockSeverity.dueSoon);
  });

  test('hours trigger', () {
    final usage = [
      DiveUsageSample(date: DateTime(2026, 2, 1), durationSeconds: 7200),
      DiveUsageSample(date: DateTime(2026, 3, 1), durationSeconds: 5400),
    ];
    final statuses = run(
      schedules: [
        sched('regulator-service', hours: 3.0, anchor: DateTime(2026, 1, 1)),
      ],
      kinds: [regService()],
      usage: usage,
    );
    expect(statuses.single.hoursSinceAnchor, closeTo(3.5, 0.001));
    expect(statuses.single.severity, ServiceClockSeverity.overdue);
  });

  test('usage before anchor does not count', () {
    final usage = [
      DiveUsageSample(date: DateTime(2025, 1, 1), durationSeconds: 3600),
      DiveUsageSample(date: DateTime(2026, 2, 1), durationSeconds: 3600),
    ];
    final statuses = run(
      schedules: [sched('regulator-service', anchor: DateTime(2026, 1, 1))],
      kinds: [regService()],
      usage: usage,
    );
    expect(statuses.single.divesSinceAnchor, 1);
  });

  test('disabled, missing-kind, and no-trigger schedules are skipped', () {
    final noTriggerKind = ServiceKind(
      id: 'general-service',
      name: 'General service',
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );
    final statuses = run(
      schedules: [
        sched('hydro', enabled: false),
        sched('unknown-kind'),
        sched('general-service'),
      ],
      kinds: [hydro(), noTriggerKind],
    );
    expect(statuses, isEmpty);
  });

  test('sorted overdue first, then soonest due date', () {
    final statuses = run(
      schedules: [
        sched('hydro', anchor: now.subtract(const Duration(days: 1800))),
        sched('regulator-service', anchor: DateTime(2020, 1, 1)),
      ],
      kinds: [hydro(), regService()],
    );
    expect(statuses.first.kind.id, 'regulator-service'); // overdue
    expect(statuses.first.severity, ServiceClockSeverity.overdue);
  });
}
