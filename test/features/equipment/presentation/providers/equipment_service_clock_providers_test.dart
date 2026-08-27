import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// dueClocksProvider and equipmentServiceUrgencyProvider both derive from the
/// single activeEquipmentClocksProvider base (so a screen watching both
/// evaluates each item's clocks once). Overriding the base and reading both
/// derived providers proves the derivation and the shared source.
void main() {
  final t0 = DateTime(2025, 1, 1);

  ServiceClockStatus st(String eid, ServiceClockSeverity sev, DateTime? due) =>
      ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-$eid',
          equipmentId: eid,
          serviceKindId: 'k',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(id: 'k', name: 'K', createdAt: t0, updatedAt: t0),
        anchor: t0,
        dueDate: due,
        severity: sev,
        now: DateTime(2026, 1, 1),
      );

  EquipmentItem item(String id) =>
      EquipmentItem(id: id, name: id, type: EquipmentType.tank);

  ProviderContainer containerWith(List<EquipmentClocks> base) =>
      ProviderContainer(
        overrides: [
          activeEquipmentClocksProvider.overrideWith((ref) async => base),
        ],
      );

  test(
    'dueClocks derives non-ok clocks from the base, overdue first',
    () async {
      final c = containerWith([
        (
          item: item('a'),
          statuses: [
            st('a', ServiceClockSeverity.dueSoon, DateTime(2026, 3, 1)),
            st('a', ServiceClockSeverity.overdue, DateTime(2025, 6, 1)),
          ],
        ),
        (
          item: item('b'),
          statuses: [st('b', ServiceClockSeverity.ok, DateTime(2027, 1, 1))],
        ),
      ]);
      addTearDown(c.dispose);

      final due = await c.read(dueClocksProvider.future);

      // b's ok clock is filtered out; a contributes two (overdue sorts first).
      expect(due.map((d) => d.item.id).toList(), ['a', 'a']);
      expect(due.map((d) => d.status.severity).toList(), [
        ServiceClockSeverity.overdue,
        ServiceClockSeverity.dueSoon,
      ]);
    },
  );

  test('urgency keeps the worst clock per item, INCLUDING ok', () async {
    final c = containerWith([
      (
        item: item('a'),
        statuses: [st('a', ServiceClockSeverity.overdue, DateTime(2025, 6, 1))],
      ),
      (
        item: item('b'),
        statuses: [st('b', ServiceClockSeverity.ok, DateTime(2027, 1, 1))],
      ),
      (item: item('c'), statuses: const []),
    ]);
    addTearDown(c.dispose);

    final urg = await c.read(equipmentServiceUrgencyProvider.future);

    expect(urg.keys.toSet(), {'a', 'b'}); // c has no clocks -> absent
    expect(urg['a']!.severity, ServiceClockSeverity.overdue);
    // ok is retained here (unlike dueClocks), so not-yet-due gear still sorts.
    expect(urg['b']!.severity, ServiceClockSeverity.ok);
  });
}
