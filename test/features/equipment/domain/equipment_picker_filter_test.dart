import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';

void main() {
  const activeReg = EquipmentItem(
    id: 'reg-1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );
  const loanedReg = EquipmentItem(
    id: 'reg-2',
    name: 'Aqualung',
    type: EquipmentType.regulator,
    status: EquipmentStatus.loaned,
  );
  const lostTank = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
    status: EquipmentStatus.lost,
  );

  const gear = [activeReg, loanedReg, lostTank];

  test('no filter passes everything through unchanged', () {
    expect(EquipmentPickerFilter.none.apply(gear), same(gear));
    expect(EquipmentPickerFilter.none.hasActiveFilters, isFalse);
  });

  test('filters by type', () {
    const filter = EquipmentPickerFilter(type: EquipmentType.regulator);

    expect(filter.apply(gear).map((e) => e.id), ['reg-1', 'reg-2']);
    expect(filter.hasActiveFilters, isTrue);
  });

  test('filters by status', () {
    const filter = EquipmentPickerFilter(status: EquipmentStatus.loaned);

    expect(filter.apply(gear).map((e) => e.id), ['reg-2']);
  });

  test('the two axes compose with AND', () {
    const filter = EquipmentPickerFilter(
      status: EquipmentStatus.loaned,
      type: EquipmentType.tank,
    );

    expect(filter.apply(gear), isEmpty);
  });

  test('preserves the order it was given', () {
    // The picker filters BEFORE arranging, so this must not reorder anything.
    const filter = EquipmentPickerFilter(type: EquipmentType.regulator);

    expect(filter.apply([loanedReg, activeReg]).map((e) => e.id), [
      'reg-2',
      'reg-1',
    ]);
  });

  test('copyWith clears an axis explicitly', () {
    const filter = EquipmentPickerFilter(
      status: EquipmentStatus.loaned,
      type: EquipmentType.tank,
    );

    expect(filter.copyWith(clearStatus: true).status, isNull);
    expect(filter.copyWith(clearStatus: true).type, EquipmentType.tank);
    expect(filter.copyWith(clearType: true).type, isNull);
  });

  test('equal filters hash equally, and every axis participates', () {
    const a = EquipmentPickerFilter(
      status: EquipmentStatus.loaned,
      type: EquipmentType.tank,
    );
    const b = EquipmentPickerFilter(
      status: EquipmentStatus.loaned,
      type: EquipmentType.tank,
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect({
      EquipmentPickerFilter.none,
      const EquipmentPickerFilter(status: EquipmentStatus.loaned),
      const EquipmentPickerFilter(type: EquipmentType.tank),
      a,
    }, hasLength(4));
  });

  test('equality is by value', () {
    expect(
      const EquipmentPickerFilter(type: EquipmentType.tank),
      const EquipmentPickerFilter(type: EquipmentType.tank),
    );
    expect(
      const EquipmentPickerFilter(type: EquipmentType.tank),
      isNot(const EquipmentPickerFilter(type: EquipmentType.mask)),
    );
  });

  test('the picker filter does not survive the picker closing', () async {
    // A narrowing applied to find one regulator must not still be hiding gear
    // the next time a dive's picker opens. StateProvider state otherwise
    // lives for the whole ProviderContainer, i.e. the app session.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(
      equipmentPickerFilterProvider,
      (_, _) {},
      fireImmediately: true,
    );
    container.read(equipmentPickerFilterProvider.notifier).state =
        const EquipmentPickerFilter(type: EquipmentType.regulator);
    expect(
      container.read(equipmentPickerFilterProvider).type,
      EquipmentType.regulator,
    );

    // The picker closes: its watch goes away.
    sub.close();
    await pumpEventQueue();

    expect(
      container.read(equipmentPickerFilterProvider),
      EquipmentPickerFilter.none,
    );
  });
}
