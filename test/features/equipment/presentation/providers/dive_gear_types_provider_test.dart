import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

void main() {
  test('dive gear types leave out a type held only by wanted gear', () async {
    final container = ProviderContainer(
      overrides: [
        allEquipmentProvider.overrideWith(
          (ref) async => const [
            EquipmentItem(id: 'r', name: 'Reg', type: EquipmentType.regulator),
            EquipmentItem(
              id: 'w',
              name: 'Dream wing',
              type: EquipmentType.bcd,
              status: EquipmentStatus.wanted,
              isActive: false,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(allEquipmentProvider.future);

    expect(container.read(diveGearTypesProvider), [EquipmentType.regulator]);
    // The Equipment page's own type chips still offer it: its status axis
    // can put wanted gear on screen.
    expect(
      container.read(ownedEquipmentTypesProvider),
      containsAll([EquipmentType.regulator, EquipmentType.bcd]),
    );
  });
}
