import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DivesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  // tripSightingsByDiveProvider self-invalidates on the dive repository's
  // watch stream, which needs a real (in-memory) database.
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

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

  test(
    'tripSightingsByDiveProvider batches sightings for the trip dives',
    () async {
      final db = DatabaseService.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('d1'),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      final species = await SpeciesRepository().createSpecies(
        commonName: 'Reef shark',
        category: SpeciesCategory.shark,
      );
      await SpeciesRepository().addSighting(
        diveId: 'd1',
        speciesId: species.id,
      );

      final container = ProviderContainer(
        overrides: [
          ...await getBaseOverrides(),
          diveIdsForTripProvider('trip-1').overrideWith((ref) async => ['d1']),
        ].cast(),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        tripSightingsByDiveProvider('trip-1').future,
      );
      expect(result['d1'], hasLength(1));
      expect(result['d1']!.single.speciesName, 'Reef shark');
    },
  );
}
