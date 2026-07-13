import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  test('tripStoryProvider composes sources into a TripStory', () async {
    final trip = Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 28),
      endDate: DateTime(2026, 3, 28),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    // Helper fixes dateTime to 2026-03-28, inside the trip range above.
    final dive = createTestDiveWithBottomTime(
      id: 'd1',
      diveNumber: 1,
      bottomTime: const Duration(minutes: 45),
      maxDepth: 25.0,
    );

    final container = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        tripByIdProvider('trip-1').overrideWith((ref) async => trip),
        divesForTripProvider('trip-1').overrideWith((ref) async => [dive]),
        itineraryDaysProvider('trip-1').overrideWith((ref) async => []),
        mediaForTripProvider('trip-1').overrideWith((ref) async => {}),
        tripChecklistProvider('trip-1').overrideWith((ref) async => []),
        tripSightingsByDiveProvider('trip-1').overrideWith((ref) async => {}),
      ].cast(),
    );
    addTearDown(container.dispose);

    final story = await container.read(tripStoryProvider('trip-1').future);
    expect(story.trip.id, 'trip-1');
    expect(story.days, isNotEmpty);
    expect(story.days.expand((d) => d.dives).single.id, 'd1');
  });

  test(
    'tripSightingsByDiveProvider is empty when the trip has no dives',
    () async {
      final container = ProviderContainer(
        overrides: [
          ...await getBaseOverrides(),
          diveIdsForTripProvider(
            'trip-1',
          ).overrideWith((ref) async => <String>[]),
        ].cast(),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        tripSightingsByDiveProvider('trip-1').future,
      );
      expect(result, isEmpty);
    },
  );

  test(
    'siteHistoryByNameProvider returns zero history without a diver',
    () async {
      final container = ProviderContainer(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ].cast(),
      );
      addTearDown(container.dispose);

      final history = await container.read(
        siteHistoryByNameProvider('Blue Corner').future,
      );
      expect(history.diveCount, 0);
      expect(history.avgWaterTemp, isNull);
    },
  );
}
