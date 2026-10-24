import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';

/// The dive center a list returned to reopens: its last-opened one, while the
/// list still shows it (#3301).
void main() {
  AsyncValue<String?> remembered(String? highlighted) {
    final container = ProviderContainer(
      overrides: [
        filteredDiveCentersProvider.overrideWithValue(
          AsyncData([
            DiveCenter(
              id: 'r1',
              name: 'Reef Divers',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(highlightedDiveCenterIdProvider.notifier).state =
        highlighted;
    return container.read(rememberedDiveCenterIdProvider);
  }

  test('a listed dive center is remembered', () {
    expect(remembered('r1'), const AsyncData<String?>('r1'));
  });

  test('a dive center the list does not show is not', () {
    expect(remembered('gone'), const AsyncData<String?>(null));
  });
}
