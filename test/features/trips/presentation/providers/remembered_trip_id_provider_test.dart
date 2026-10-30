import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The trip a list returned to reopens: its last-opened one, while the
/// list still shows it (#3301).
void main() {
  AsyncValue<String?> remembered(String? highlighted) {
    final container = ProviderContainer(
      overrides: [
        sortedFilteredTripsProvider.overrideWithValue(
          AsyncData([
            TripWithStats(
              trip: Trip(
                id: 'r1',
                name: 'Bonaire',
                startDate: DateTime(2024, 6, 1),
                endDate: DateTime(2024, 6, 7),
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
    container.read(highlightedTripIdProvider.notifier).state = highlighted;
    return container.read(rememberedTripIdProvider);
  }

  test('a listed trip is remembered', () {
    expect(remembered('r1'), const AsyncData<String?>('r1'));
  });

  test('a trip the list does not show is not', () {
    expect(remembered('gone'), const AsyncData<String?>(null));
  });
}
