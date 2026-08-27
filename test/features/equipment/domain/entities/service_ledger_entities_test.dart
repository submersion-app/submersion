import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  ServiceKind kind({List<EquipmentType> types = const [EquipmentType.tank]}) =>
      ServiceKind(
        id: 'hydro',
        name: 'Hydrostatic test',
        applicableTypes: types,
        defaultIntervalDays: 1825,
        autoAttach: true,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      );

  test('appliesTo matches listed types; empty list matches all', () {
    expect(kind().appliesTo(EquipmentType.tank), isTrue);
    expect(kind().appliesTo(EquipmentType.regulator), isFalse);
    expect(kind(types: const []).appliesTo(EquipmentType.fins), isTrue);
  });

  test('copyWith preserves unset fields', () {
    final s = ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'hydro',
      createdAt: t0,
      updatedAt: t0,
    );
    final s2 = s.copyWith(intervalDays: 365);
    expect(s2.intervalDays, 365);
    expect(s2.equipmentId, 'e1');
    expect(s.intervalDays, null); // immutability
  });

  test('ServiceKind.copyWith covers every field', () {
    final base = kind();
    final copy = base.copyWith(
      id: 'x',
      diverId: 'd1',
      name: 'Renamed',
      applicableTypes: const [EquipmentType.regulator],
      defaultIntervalDays: 1,
      defaultIntervalDives: 2,
      defaultIntervalHours: 3.0,
      autoAttach: false,
      isBuiltIn: false,
      createdAt: DateTime(2027),
      updatedAt: DateTime(2027, 2),
    );
    expect(copy.id, 'x');
    expect(copy.diverId, 'd1');
    expect(copy.name, 'Renamed');
    expect(copy.applicableTypes, const [EquipmentType.regulator]);
    expect(copy.defaultIntervalDays, 1);
    expect(copy.defaultIntervalDives, 2);
    expect(copy.defaultIntervalHours, 3.0);
    expect(copy.autoAttach, isFalse);
    expect(copy.isBuiltIn, isFalse);
    expect(copy.createdAt, DateTime(2027));
    expect(copy.updatedAt, DateTime(2027, 2));
    expect(copy == base, isFalse);
    expect(base.copyWith(), base); // Equatable identity
  });

  test('ServiceKind.copyWith clears nullable fields when passed null', () {
    final full = kind().copyWith(
      diverId: 'd1',
      defaultIntervalDives: 100,
      defaultIntervalHours: 50.0,
    );
    // Explicit null clears each nullable field (e.g. promote a custom kind to
    // shared by clearing diverId, or drop a default interval to leave it unset)
    // via the _undefined sentinel, not just overwrite with a non-null value.
    final cleared = full.copyWith(
      diverId: null,
      defaultIntervalDays: null,
      defaultIntervalDives: null,
      defaultIntervalHours: null,
    );
    expect(cleared.diverId, isNull);
    expect(cleared.defaultIntervalDays, isNull);
    expect(cleared.defaultIntervalDives, isNull);
    expect(cleared.defaultIntervalHours, isNull);

    // Omitting a nullable arg leaves the existing value untouched.
    final untouched = full.copyWith(name: 'Renamed');
    expect(untouched.diverId, 'd1');
    expect(untouched.defaultIntervalDays, 1825);
    expect(untouched.defaultIntervalDives, 100);
    expect(untouched.defaultIntervalHours, 50.0);
  });

  test('ServiceSchedule.copyWith covers every field', () {
    final base = ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'hydro',
      createdAt: t0,
      updatedAt: t0,
    );
    final copy = base.copyWith(
      id: 's2',
      equipmentId: 'e2',
      serviceKindId: 'vip',
      intervalDays: 10,
      intervalDives: 20,
      intervalHours: 30.0,
      anchorDate: DateTime(2026, 5, 5),
      enabled: false,
      createdAt: DateTime(2027),
      updatedAt: DateTime(2027, 2),
    );
    expect(copy.id, 's2');
    expect(copy.equipmentId, 'e2');
    expect(copy.serviceKindId, 'vip');
    expect(copy.intervalDays, 10);
    expect(copy.intervalDives, 20);
    expect(copy.intervalHours, 30.0);
    expect(copy.anchorDate, DateTime(2026, 5, 5));
    expect(copy.enabled, isFalse);
    expect(base.copyWith(), base);
  });

  test(
    'ServiceSchedule.copyWith clears nullable overrides when passed null',
    () {
      final full = ServiceSchedule(
        id: 's1',
        equipmentId: 'e1',
        serviceKindId: 'hydro',
        intervalDays: 365,
        intervalDives: 100,
        intervalHours: 50.0,
        anchorDate: DateTime(2026, 5, 5),
        createdAt: t0,
        updatedAt: t0,
      );

      // Explicit null clears the field (e.g. "Clear baseline date", or resetting
      // an interval override to inherit the kind default).
      final cleared = full.copyWith(
        intervalDays: null,
        intervalDives: null,
        intervalHours: null,
        anchorDate: null,
      );
      expect(cleared.intervalDays, isNull);
      expect(cleared.intervalDives, isNull);
      expect(cleared.intervalHours, isNull);
      expect(cleared.anchorDate, isNull);

      // Omitting an argument leaves the existing value untouched.
      final untouched = full.copyWith(enabled: false);
      expect(untouched.intervalDays, 365);
      expect(untouched.intervalDives, 100);
      expect(untouched.intervalHours, 50.0);
      expect(untouched.anchorDate, DateTime(2026, 5, 5));

      // Clearing one override does not disturb the others.
      final onlyAnchorCleared = full.copyWith(anchorDate: null);
      expect(onlyAnchorCleared.anchorDate, isNull);
      expect(onlyAnchorCleared.intervalDays, 365);
    },
  );

  test('ServiceClockStatus equality and null daysUntilDue', () {
    final schedule = ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'hydro',
      createdAt: t0,
      updatedAt: t0,
    );
    final a = ServiceClockStatus(
      schedule: schedule,
      kind: kind(),
      anchor: t0,
      divesSinceAnchor: 5,
      divesRemaining: 95,
      hoursSinceAnchor: 1.5,
      hoursRemaining: 3.5,
      severity: ServiceClockSeverity.ok,
      now: DateTime(2026, 1, 15),
    );
    final b = ServiceClockStatus(
      schedule: schedule,
      kind: kind(),
      anchor: t0,
      divesSinceAnchor: 5,
      divesRemaining: 95,
      hoursSinceAnchor: 1.5,
      hoursRemaining: 3.5,
      severity: ServiceClockSeverity.ok,
      now: DateTime(2026, 1, 15),
    );
    expect(a, b);
    expect(a.daysUntilDue, isNull); // no date trigger
  });

  test('ServiceClockStatus.daysUntilDue is negative when overdue', () {
    final status = ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'e1',
        serviceKindId: 'hydro',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: kind(),
      anchor: t0,
      dueDate: DateTime(2026, 1, 10),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 1, 15),
    );
    expect(status.daysUntilDue, -5);
  });
}
