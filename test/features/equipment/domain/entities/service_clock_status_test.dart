import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  final schedule = ServiceSchedule(
    id: 's',
    equipmentId: 'e',
    serviceKindId: 'k',
    createdAt: t0,
    updatedAt: t0,
  );
  final kind = ServiceKind(id: 'k', name: 'K', createdAt: t0, updatedAt: t0);

  test('legacy dives and hours arguments populate usageByUnit', () {
    final s = ServiceClockStatus(
      schedule: schedule,
      kind: kind,
      anchor: t0,
      divesSinceAnchor: 40,
      divesRemaining: 60,
      hoursSinceAnchor: 2.5,
      hoursRemaining: 0.5,
      severity: ServiceClockSeverity.ok,
      now: t0,
    );
    expect(
      s.usageByUnit[ExposureUnit.dives],
      const ClockUsage(interval: 100, since: 40),
    );
    expect(
      s.usageByUnit[ExposureUnit.hours],
      const ClockUsage(interval: 3.0, since: 2.5),
    );
    expect(s.divesRemaining, 60);
    expect(s.hoursRemaining, closeTo(0.5, 1e-9));
  });

  test('usageByUnit drives the legacy getters', () {
    final s = ServiceClockStatus(
      schedule: schedule,
      kind: kind,
      anchor: t0,
      usageByUnit: const {
        ExposureUnit.dives: ClockUsage(interval: 10, since: 12),
        ExposureUnit.coldDives: ClockUsage(interval: 50, since: 3),
      },
      severity: ServiceClockSeverity.overdue,
      now: t0,
    );
    expect(s.divesSinceAnchor, 12);
    expect(s.divesRemaining, -2);
    expect(s.hoursRemaining, isNull);
    expect(s.usageByUnit[ExposureUnit.coldDives]!.remaining, 47);
  });

  test('a sample equals only a sample of the same dive as last edited', () {
    // The condition fingerprint and the providers compare samples; the
    // dive and its edit stamp are what tell two apart.
    EquipmentExposureSample sample({String diveId = 'd1', int updatedAt = 1}) =>
        EquipmentExposureSample(
          diveId: diveId,
          date: DateTime.utc(2026),
          durationSeconds: 3000,
          updatedAt: updatedAt,
        );
    expect(sample(), sample());
    expect(sample(diveId: 'd2'), isNot(sample()));
    expect(sample(updatedAt: 2), isNot(sample()));
  });
}
