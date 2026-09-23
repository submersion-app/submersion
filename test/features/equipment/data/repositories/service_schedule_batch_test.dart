import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ServiceScheduleRepository schedules;
  late EquipmentRepository equipment;

  setUp(() async {
    await setUpTestDatabase();
    schedules = ServiceScheduleRepository();
    equipment = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> make(String name, EquipmentType type) =>
      equipment.createEquipment(EquipmentItem(id: '', name: name, type: type));

  test('agrees with the single-item lookup, item by item', () async {
    // Tanks and regulators auto-attach clocks; fins attach none.
    final items = [
      await make('AL80', EquipmentType.tank),
      await make('Reg', EquipmentType.regulator),
      await make('Fins', EquipmentType.fins),
    ];
    final batched = await schedules.getSchedulesForEquipmentIds([
      for (final i in items) i.id,
    ]);
    for (final item in items) {
      final single = await schedules.getSchedulesForEquipment(item.id);
      expect(
        {for (final s in batched[item.id] ?? const []) s.id},
        {for (final s in single) s.id},
        reason: item.name,
      );
    }
    expect(batched.containsKey(items.last.id), isFalse);
    expect(batched[items.first.id], isNotEmpty);
  });

  test('an empty list reads nothing', () async {
    expect(await schedules.getSchedulesForEquipmentIds(const []), isEmpty);
  });
}
