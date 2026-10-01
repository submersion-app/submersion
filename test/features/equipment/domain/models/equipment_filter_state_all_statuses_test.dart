import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

/// The All Equipment choice (issue #2590): a third value of the single
/// status axis, beside the default view (which hides retired and sold gear,
/// #636), the service-due severities and the single statuses.
void main() {
  group('EquipmentFilterState.allStatuses', () {
    test('is off by default', () {
      expect(const EquipmentFilterState().allStatuses, isFalse);
    });

    test('counts as a status narrowing and lights the badge', () {
      const all = EquipmentFilterState(allStatuses: true);
      expect(all.hasStatusFilter, isTrue);
      expect(all.hasActiveFilters, isTrue);
    });

    test('cannot be combined with a status or a service severity', () {
      expect(
        () => EquipmentFilterState(
          allStatuses: true,
          status: EquipmentStatus.retired,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => EquipmentFilterState(
          allStatuses: true,
          serviceDue: ServiceDueFilter.any,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('takes part in equality and the hash', () {
      expect(
        const EquipmentFilterState(allStatuses: true),
        const EquipmentFilterState(allStatuses: true),
      );
      expect(
        const EquipmentFilterState(allStatuses: true).hashCode,
        const EquipmentFilterState(allStatuses: true).hashCode,
      );
      expect(
        const EquipmentFilterState(allStatuses: true),
        isNot(const EquipmentFilterState()),
      );
    });

    test('clearStatus turns it off with the rest of the axis', () {
      const all = EquipmentFilterState(
        allStatuses: true,
        type: EquipmentType.bcd,
      );
      final cleared = all.copyWith(clearStatus: true);
      expect(cleared.allStatuses, isFalse);
      expect(cleared.type, EquipmentType.bcd);
    });

    test('picking a status or a severity replaces it', () {
      const all = EquipmentFilterState(allStatuses: true);
      final retired = all.copyWith(status: EquipmentStatus.retired);
      expect(retired.allStatuses, isFalse);
      expect(retired.status, EquipmentStatus.retired);
      final due = all.copyWith(serviceDue: ServiceDueFilter.overdue);
      expect(due.allStatuses, isFalse);
      expect(due.serviceDue, ServiceDueFilter.overdue);
    });

    test('choosing it replaces a status or a severity', () {
      final fromStatus = const EquipmentFilterState(
        status: EquipmentStatus.sold,
      ).copyWith(allStatuses: true);
      expect(fromStatus.allStatuses, isTrue);
      expect(fromStatus.status, isNull);
      final fromDue = const EquipmentFilterState(
        serviceDue: ServiceDueFilter.dueSoon,
      ).copyWith(allStatuses: true);
      expect(fromDue.allStatuses, isTrue);
      expect(fromDue.serviceDue, isNull);
    });

    test('other axes leave it alone', () {
      final typed = const EquipmentFilterState(
        allStatuses: true,
      ).copyWith(type: EquipmentType.regulator);
      expect(typed.allStatuses, isTrue);
    });
  });
}
