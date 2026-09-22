import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final _t0 = DateTime(2026, 1, 1);
final _now = DateTime(2026, 7, 24);

EquipmentItem _item(String name, EquipmentType type) =>
    EquipmentItem(id: name, name: name, type: type);

ServiceClockStatus _status(
  ServiceClockSeverity severity, {
  DateTime? dueDate,
}) => ServiceClockStatus(
  schedule: ServiceSchedule(
    id: 'schedule',
    equipmentId: 'equipment',
    serviceKindId: 'kind',
    createdAt: _t0,
    updatedAt: _t0,
  ),
  kind: ServiceKind(
    id: 'kind',
    name: 'Annual service',
    createdAt: _t0,
    updatedAt: _t0,
  ),
  anchor: _t0,
  dueDate: dueDate,
  severity: severity,
  now: _now,
);

EquipmentClocks _clocks(
  EquipmentItem item,
  List<ServiceClockStatus> statuses,
) => (item: item, statuses: statuses);

void main() {
  group('gearSeverityGroups', () {
    test('empty input yields no groups', () {
      final result = gearSeverityGroups([]);
      expect(result.overdue, isNull);
      expect(result.dueSoon, isNull);
    });

    test('all-ok gear yields no groups', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.ok),
        ]),
      ]);
      expect(result.overdue, isNull);
      expect(result.dueSoon, isNull);
    });

    test('counts every overdue item, not one per type', () {
      // Four lapsed regulators are four things the diver has to service, and
      // the equipment list the chip opens shows four rows.
      final result = gearSeverityGroups([
        for (var i = 0; i < 4; i++)
          _clocks(_item('Reg $i', EquipmentType.regulator), [
            _status(
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1 + i),
            ),
          ]),
      ]);
      expect(result.overdue?.count, 4);
      expect(result.dueSoon, isNull);
    });

    test('counts every due-soon item, not one per type', () {
      // The count has to match the row count of the filtered list the chip
      // opens, and that list is per item.
      final result = gearSeverityGroups([
        _clocks(_item('Reg early', EquipmentType.regulator), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
        _clocks(_item('Reg late', EquipmentType.regulator), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 9)),
        ]),
      ]);
      expect(result.dueSoon?.count, 2);
    });

    test('an item is counted once however many clocks it has', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 5, 1)),
        ]),
      ]);
      expect(result.overdue?.count, 1);
    });

    test('an overdue item does not also count as due soon', () {
      // Its worst clock is what the diver has to act on, and the overdue
      // list it lands in already carries the item.
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.overdue?.count, 1);
      expect(result.dueSoon, isNull);
    });

    test('separates the two severities into their own groups', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
        ]),
        _clocks(_item('BCD', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.overdue?.count, 1);
      expect(result.overdue?.worst.itemName, 'Reg');
      expect(result.dueSoon?.count, 1);
      expect(result.dueSoon?.worst.itemName, 'BCD');
    });

    test('the worst of a group is its earliest due date', () {
      final result = gearSeverityGroups([
        _clocks(_item('Later', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 9)),
        ]),
        _clocks(_item('Earlier', EquipmentType.bcd), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
        ]),
      ]);
      expect(result.overdue?.worst.itemName, 'Earlier');
      expect(result.overdue?.worst.status.dueDate, DateTime(2026, 6, 1));
    });

    test('an undated clock loses to a dated one however it is ordered', () {
      for (final dated in [false, true]) {
        final entries = [
          _clocks(_item('Undated', EquipmentType.regulator), [
            _status(ServiceClockSeverity.dueSoon),
          ]),
          _clocks(_item('Dated', EquipmentType.bcd), [
            _status(
              ServiceClockSeverity.dueSoon,
              dueDate: DateTime(2026, 8, 1),
            ),
          ]),
        ];
        final result = gearSeverityGroups(
          dated ? entries.reversed.toList() : entries,
        );
        expect(result.dueSoon?.worst.itemName, 'Dated');
      }
    });

    test('the worst of an item is its own earliest clock', () {
      final result = gearSeverityGroups([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 5, 1)),
        ]),
      ]);
      expect(result.overdue?.worst.status.dueDate, DateTime(2026, 5, 1));
    });

    test('carries the worst item id so a lone chip can deep-link', () {
      // Id and name deliberately differ: the chip labels with the name but
      // must route with the id.
      final result = gearSeverityGroups([
        _clocks(
          const EquipmentItem(
            id: 'reg-b-id',
            name: 'Reg B',
            type: EquipmentType.regulator,
          ),
          [
            _status(
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
            ),
          ],
        ),
      ]);
      expect(result.overdue?.worst.itemId, 'reg-b-id');
      expect(result.overdue?.worst.itemName, 'Reg B');
    });

    test('an item with no clocks at all is ignored', () {
      final result = gearSeverityGroups([
        _clocks(_item('Untracked', EquipmentType.regulator), const []),
      ]);
      expect(result.overdue, isNull);
      expect(result.dueSoon, isNull);
    });
  });
}
