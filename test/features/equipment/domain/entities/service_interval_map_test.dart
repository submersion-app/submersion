import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  final kind = ServiceKind(
    id: 'regulator-service',
    name: 'Reg',
    defaultIntervalDays: 365,
    defaultIntervalDives: 100,
    exposureIntervals: const {ExposureUnit.coldDives: 50},
    createdAt: t0,
    updatedAt: t0,
  );

  test('a schedule inherits the kind map key by key', () {
    final s = ServiceSchedule(
      id: 's',
      equipmentId: 'e',
      serviceKindId: kind.id,
      exposureIntervals: const {ExposureUnit.saltHours: 120},
      createdAt: t0,
      updatedAt: t0,
    );
    expect(s.intervalFor(ExposureUnit.coldDives, kind), 50);
    expect(s.intervalFor(ExposureUnit.saltHours, kind), 120);
    expect(s.intervalFor(ExposureUnit.o2Hours, kind), isNull);
  });

  test('the legacy columns answer for days, dives and hours', () {
    final s = ServiceSchedule(
      id: 's',
      equipmentId: 'e',
      serviceKindId: kind.id,
      intervalDives: 80,
      createdAt: t0,
      updatedAt: t0,
    );
    expect(s.intervalFor(ExposureUnit.days, kind), 365);
    expect(s.intervalFor(ExposureUnit.dives, kind), 80);
    expect(s.intervalFor(ExposureUnit.hours, kind), isNull);
  });

  test('copyWith can replace the map', () {
    final k2 = kind.copyWith(
      exposureIntervals: const {ExposureUnit.o2Hours: 50},
    );
    expect(k2.exposureIntervals, const {ExposureUnit.o2Hours: 50});
    expect(kind.exposureIntervals, const {ExposureUnit.coldDives: 50});
  });
}
