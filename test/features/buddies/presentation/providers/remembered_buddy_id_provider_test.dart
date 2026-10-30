import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';

/// The buddy a list returned to reopens: its last-opened one, while the
/// list still shows it (#3301).
void main() {
  AsyncValue<String?> remembered(String? highlighted) {
    final container = ProviderContainer(
      overrides: [
        filteredBuddiesWithDiveCountProvider.overrideWithValue(
          AsyncData([
            BuddyWithDiveCount(
              buddy: Buddy(
                id: 'r1',
                name: 'Ann',
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024),
              ),
              diveCount: 0,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(highlightedBuddyIdProvider.notifier).state = highlighted;
    return container.read(rememberedBuddyIdProvider);
  }

  test('a listed buddy is remembered', () {
    expect(remembered('r1'), const AsyncData<String?>('r1'));
  });

  test('a buddy the list does not show is not', () {
    expect(remembered('gone'), const AsyncData<String?>(null));
  });
}
