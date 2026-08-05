import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);
  ServiceClockStatus status(
    String eid,
    ServiceClockSeverity sev,
    DateTime? due,
  ) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's-$eid',
      equipmentId: eid,
      serviceKindId: 'general-service',
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: ServiceKind(
      id: 'general-service',
      name: 'General service',
      createdAt: t0,
      updatedAt: t0,
    ),
    anchor: t0,
    dueDate: due,
    severity: sev,
    now: DateTime(2026, 1, 1),
  );

  test(
    'serviceDue ascending orders overdue, then soonest, then no-clock last',
    () {
      const overdue = EquipmentItem(
        id: 'a',
        name: 'A',
        type: EquipmentType.tank,
      );
      const soon = EquipmentItem(id: 'b', name: 'B', type: EquipmentType.tank);
      const none = EquipmentItem(id: 'c', name: 'C', type: EquipmentType.tank);

      final sorted = applyEquipmentSorting(
        [none, soon, overdue],
        const SortState(
          field: EquipmentSortField.serviceDue,
          direction: SortDirection.ascending,
        ),
        serviceUrgency: {
          'a': status('a', ServiceClockSeverity.overdue, DateTime(2025, 6, 1)),
          'b': status('b', ServiceClockSeverity.dueSoon, DateTime(2026, 3, 1)),
        },
      );

      expect(sorted.map((e) => e.id).toList(), ['a', 'b', 'c']);
    },
  );

  test('serviceDue breaks ties deterministically by name (empty urgency)', () {
    // No urgency data: every item has equal rank/dueDate, so the comparator
    // must fall back to a stable key or a non-stable List.sort could reorder
    // them between rebuilds (flicker).
    const charlie = EquipmentItem(
      id: 'i3',
      name: 'Charlie',
      type: EquipmentType.tank,
    );
    const alpha = EquipmentItem(
      id: 'i1',
      name: 'Alpha',
      type: EquipmentType.tank,
    );
    const bravo = EquipmentItem(
      id: 'i2',
      name: 'Bravo',
      type: EquipmentType.tank,
    );

    final sorted = applyEquipmentSorting(
      [charlie, alpha, bravo],
      const SortState(
        field: EquipmentSortField.serviceDue,
        direction: SortDirection.ascending,
      ),
    );

    expect(sorted.map((e) => e.name).toList(), ['Alpha', 'Bravo', 'Charlie']);
  });
}
