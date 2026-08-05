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
  group('worstGaugePerType', () {
    test('keeps the worst severity per equipment type', () {
      final result = worstGaugePerType([
        _clocks(_item('Reg A', EquipmentType.regulator), [
          _status(ServiceClockSeverity.ok),
        ]),
        _clocks(_item('Reg B', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
        ]),
        _clocks(_item('BCD', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 14)),
        ]),
      ]);
      expect(result, hasLength(2));
      final reg = result.firstWhere((g) => g.type == EquipmentType.regulator);
      expect(reg.status.severity, ServiceClockSeverity.overdue);
      expect(reg.itemName, 'Reg B');
      final bcd = result.firstWhere((g) => g.type == EquipmentType.bcd);
      expect(bcd.status.severity, ServiceClockSeverity.dueSoon);
    });

    test('tie on severity resolved by earlier dueDate', () {
      final result = worstGaugePerType([
        _clocks(_item('BCD later', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 9, 1)),
        ]),
        _clocks(_item('BCD sooner', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.single.itemName, 'BCD sooner');
    });

    test('null dueDate loses severity ties to a dated clock', () {
      final result = worstGaugePerType([
        _clocks(_item('Undated', EquipmentType.computer), [
          _status(ServiceClockSeverity.dueSoon),
        ]),
        _clocks(_item('Dated', EquipmentType.computer), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.single.itemName, 'Dated');
    });

    test('empty input yields empty output', () {
      expect(worstGaugePerType([]), isEmpty);
    });

    test('a dated clock beats an undated one when tied on severity', () {
      // The first-seen item is undated; the dated candidate must replace it,
      // exercising the null-dueDate tie-break branch.
      final result = worstGaugePerType([
        _clocks(_item('Undated', EquipmentType.regulator), [
          _status(ServiceClockSeverity.dueSoon),
        ]),
        _clocks(_item('Dated', EquipmentType.regulator), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.single.itemName, 'Dated');
    });
  });

  group('dueGearGauges', () {
    test('null due dates sort after dated clocks of equal severity', () {
      final result = dueGearGauges([
        _clocks(_item('Undated', EquipmentType.regulator), [
          _status(ServiceClockSeverity.dueSoon),
        ]),
        _clocks(_item('Dated', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.map((g) => g.itemName), ['Dated', 'Undated']);
    });

    test('drops types whose worst clock is ok', () {
      final result = dueGearGauges([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.ok),
        ]),
        _clocks(_item('BCD', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.map((g) => g.itemName), ['BCD']);
    });

    test('sorts overdue before due-soon, then earliest due date', () {
      final result = dueGearGauges([
        _clocks(_item('Soon-late', EquipmentType.bcd), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 9, 1)),
        ]),
        _clocks(_item('Overdue', EquipmentType.regulator), [
          _status(ServiceClockSeverity.overdue, dueDate: DateTime(2026, 6, 1)),
        ]),
        _clocks(_item('Soon-early', EquipmentType.computer), [
          _status(ServiceClockSeverity.dueSoon, dueDate: DateTime(2026, 8, 1)),
        ]),
      ]);
      expect(result.map((g) => g.itemName), [
        'Overdue',
        'Soon-early',
        'Soon-late',
      ]);
    });

    test('caps the list', () {
      final types = [
        EquipmentType.regulator,
        EquipmentType.bcd,
        EquipmentType.computer,
        EquipmentType.transmitter,
        EquipmentType.drysuit,
        EquipmentType.wetsuit,
        EquipmentType.light,
        EquipmentType.camera,
      ];
      final result = dueGearGauges([
        for (var i = 0; i < types.length; i++)
          _clocks(_item('Item $i', types[i]), [
            _status(
              ServiceClockSeverity.dueSoon,
              dueDate: DateTime(2026, 8, 1 + i),
            ),
          ]),
      ]);
      expect(result, hasLength(6));
      expect(result.first.itemName, 'Item 0');
    });

    test('all-ok gear yields empty list', () {
      final result = dueGearGauges([
        _clocks(_item('Reg', EquipmentType.regulator), [
          _status(ServiceClockSeverity.ok),
        ]),
      ]);
      expect(result, isEmpty);
    });
  });
}
