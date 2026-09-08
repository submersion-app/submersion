import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/overdue_service_entry.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  test('fromStatus copies just the fields needed for display', () {
    final status = ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 'sched1',
        equipmentId: 'g1',
        serviceKindId: 'vip',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'vip',
        name: 'Visual inspection',
        applicableTypes: const [],
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2025, 6, 1),
      divesSinceAnchor: 40,
      divesRemaining: -5,
      hoursSinceAnchor: 12.5,
      hoursRemaining: -1.5,
      severity: ServiceClockSeverity.overdue,
      now: now,
    );

    final entry = OverdueServiceEntry.fromStatus(status);

    expect(entry.kindName, 'Visual inspection');
    expect(entry.dueDate, DateTime(2025, 6, 1));
    expect(entry.divesSinceAnchor, 40);
    expect(entry.divesRemaining, -5);
    expect(entry.hoursSinceAnchor, 12.5);
    expect(entry.hoursRemaining, -1.5);
  });

  test('toJson/fromJson round-trips every field', () {
    const entry = OverdueServiceEntry(
      kindName: 'Hydrostatic test',
      divesSinceAnchor: 10,
      divesRemaining: -2,
      hoursSinceAnchor: 5.5,
      hoursRemaining: -0.5,
    );
    final restored = OverdueServiceEntry.fromJson(entry.toJson());
    expect(restored, entry);
  });

  test('toJson/fromJson round-trips a null dueDate and null count fields', () {
    final entry = OverdueServiceEntry(kindName: 'O2 clean', dueDate: t0);
    final restored = OverdueServiceEntry.fromJson(entry.toJson());
    expect(restored, entry);
    expect(restored.divesRemaining, isNull);
  });
}
