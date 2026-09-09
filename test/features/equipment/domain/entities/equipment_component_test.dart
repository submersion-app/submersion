import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  EquipmentComponent row({String role = ''}) => EquipmentComponent(
    id: 'c1',
    parentEquipmentId: 'reg',
    componentEquipmentId: 'hose',
    role: role,
    sortOrder: 2,
    createdAt: t0,
    updatedAt: t0,
  );

  test('defaults role to empty and sortOrder to zero', () {
    final c = EquipmentComponent(
      id: 'c1',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'hose',
      createdAt: t0,
      updatedAt: t0,
    );
    expect(c.role, '');
    expect(c.sortOrder, 0);
    expect(c.component, isNull);
  });

  test('copyWith replaces only what is passed', () {
    const hose = EquipmentItem(
      id: 'hose',
      name: 'LP hose',
      type: EquipmentType.hose,
    );
    final copy = row().copyWith(role: 'Primary', component: hose);
    expect(copy.role, 'Primary');
    expect(copy.component, hose);
    expect(copy.sortOrder, 2);
    expect(copy.parentEquipmentId, 'reg');
  });

  test('equality is by value, hydrated item included', () {
    expect(row(role: 'a'), row(role: 'a'));
    expect(row(role: 'a'), isNot(row(role: 'b')));
  });
}
