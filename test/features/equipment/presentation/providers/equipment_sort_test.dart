import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
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

  test(
    'serviceDue descending reverses urgency: no clock first, overdue last',
    () {
      // The service-due branch ranks urgency and due dates before the shared
      // direction flip, so pin the descending order separately.
      const overdue = EquipmentItem(
        id: 'a',
        name: 'A',
        type: EquipmentType.tank,
      );
      const soon = EquipmentItem(id: 'b', name: 'B', type: EquipmentType.tank);
      const later = EquipmentItem(id: 'c', name: 'C', type: EquipmentType.tank);
      const none = EquipmentItem(id: 'd', name: 'D', type: EquipmentType.tank);

      final sorted = applyEquipmentSorting(
        [soon, overdue, none, later],
        const SortState(
          field: EquipmentSortField.serviceDue,
          direction: SortDirection.descending,
        ),
        serviceUrgency: {
          'a': status('a', ServiceClockSeverity.overdue, DateTime(2025, 6, 1)),
          'b': status('b', ServiceClockSeverity.dueSoon, DateTime(2026, 2, 1)),
          'c': status('c', ServiceClockSeverity.dueSoon, DateTime(2026, 3, 1)),
        },
      );

      expect(sorted.map((e) => e.id).toList(), ['d', 'c', 'b', 'a']);
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

  group('direction matches the dive-surface arrangement', () {
    // The Equipment page and the dive surfaces share one sheet layout, so the
    // same arrow must mean the same thing on both: ascending is A to Z and
    // oldest first. The page used to invert text fields, so its ascending
    // arrow read Z to A while the dive view's read A to Z.
    const zeagle = EquipmentItem(
      id: 'z',
      name: 'Zeagle',
      type: EquipmentType.bcd,
    );
    const apeks = EquipmentItem(
      id: 'a',
      name: 'apeks',
      type: EquipmentType.regulator,
    );
    const bravo = EquipmentItem(
      id: 'b',
      name: 'Bravo',
      type: EquipmentType.tank,
    );

    test('name ascending reads A to Z, ignoring case', () {
      final sorted = applyEquipmentSorting(
        const [zeagle, apeks, bravo],
        const SortState(
          field: EquipmentSortField.name,
          direction: SortDirection.ascending,
        ),
      );

      expect(sorted.map((e) => e.name).toList(), ['apeks', 'Bravo', 'Zeagle']);
    });

    test('name descending reads Z to A', () {
      final sorted = applyEquipmentSorting(
        const [apeks, zeagle, bravo],
        const SortState(
          field: EquipmentSortField.name,
          direction: SortDirection.descending,
        ),
      );

      expect(sorted.map((e) => e.name).toList(), ['Zeagle', 'Bravo', 'apeks']);
    });

    test('undated items sort last in both directions', () {
      final old = EquipmentItem(
        id: 'o',
        name: 'Old',
        type: EquipmentType.tank,
        purchaseDate: DateTime(2020),
      );
      final recent = EquipmentItem(
        id: 'r',
        name: 'Recent',
        type: EquipmentType.tank,
        purchaseDate: DateTime(2024),
      );
      const undated = EquipmentItem(
        id: 'u',
        name: 'Undated',
        type: EquipmentType.tank,
      );

      List<String> order(SortDirection direction) => applyEquipmentSorting(
        [undated, recent, old],
        SortState(field: EquipmentSortField.purchaseDate, direction: direction),
      ).map((e) => e.name).toList();

      expect(order(SortDirection.ascending), ['Old', 'Recent', 'Undated']);
      expect(order(SortDirection.descending), ['Recent', 'Old', 'Undated']);
    });

    test('equal dates break ties by name in both directions', () {
      final day = DateTime(2023, 5, 1);
      final charlie = EquipmentItem(
        id: 'c',
        name: 'Charlie',
        type: EquipmentType.tank,
        lastServiceDate: day,
      );
      final alpha = EquipmentItem(
        id: 'a',
        name: 'Alpha',
        type: EquipmentType.tank,
        lastServiceDate: day,
      );

      for (final direction in SortDirection.values) {
        final sorted = applyEquipmentSorting(
          [charlie, alpha],
          SortState(
            field: EquipmentSortField.lastServiceDate,
            direction: direction,
          ),
        );
        expect(sorted.map((e) => e.name).toList(), [
          'Alpha',
          'Charlie',
        ], reason: '$direction');
      }
    });

    test('the page opens on name ascending, which reads A to Z', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(equipmentSortProvider),
        const SortState(
          field: EquipmentSortField.name,
          direction: SortDirection.ascending,
        ),
      );
    });
  });
}
