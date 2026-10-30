import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_query_providers.dart';

/// The equipment item a list returned to reopens: its last-opened one, while the
/// list still shows it (#3301).
void main() {
  AsyncValue<String?> remembered(String? highlighted) {
    final container = ProviderContainer(
      overrides: [
        filteredEquipmentProvider.overrideWithValue(
          const AsyncData([
            EquipmentItem(
              id: 'r1',
              name: 'Regulator',
              type: EquipmentType.regulator,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(highlightedEquipmentIdProvider.notifier).state = highlighted;
    return container.read(rememberedEquipmentIdProvider);
  }

  test('a listed equipment item is remembered', () {
    expect(remembered('r1'), const AsyncData<String?>('r1'));
  });

  test('a equipment item the list does not show is not', () {
    expect(remembered('gone'), const AsyncData<String?>(null));
  });
}
