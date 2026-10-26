import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/device_item_providers.dart';

/// Serves the Dive Computers list (issue #3676) from whatever
/// [allDiveComputersProvider] holds in a test: one Dive Computer item per
/// computer, `gear-<computer id>`, named after it. Lets list tests keep
/// their computer fixtures now that the list reads Equipment items.
final computerItemsFromComputers = computerItemsProvider.overrideWith((
  ref,
) async {
  final computers = await ref.watch(allDiveComputersProvider.future);
  return [
    for (final c in computers)
      (
        item: EquipmentItem(
          id: 'gear-${c.id}',
          name: c.name,
          type: EquipmentType.computer,
          brand: c.manufacturer,
          model: c.model,
        ),
        computers: [c],
      ),
  ];
});
