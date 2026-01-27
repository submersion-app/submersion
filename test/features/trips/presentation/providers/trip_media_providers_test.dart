import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

void main() {
  group('mediaForTripProvider', () {
    test('returns empty map when trip has no dives', () async {
      final container = ProviderContainer(
        overrides: [
          divesForTripProvider('trip-with-no-dives').overrideWith((ref) {
            return Future.value(<Dive>[]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        mediaForTripProvider('trip-with-no-dives').future,
      );

      expect(result, isEmpty);
    });

    test(
      'returns map of dives to media when trip has dives with media',
      () async {
        final testDive1 = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 9, 0),
        );
        final testDive2 = Dive(
          id: 'dive-2',
          dateTime: DateTime(2024, 1, 15, 14, 0),
        );
        final now = DateTime.now();
        final testMedia1 = MediaItem(
          id: 'media-1',
          diveId: 'dive-1',
          mediaType: MediaType.photo,
          takenAt: DateTime(2024, 1, 15, 9, 30),
          createdAt: now,
          updatedAt: now,
        );
        final testMedia2 = MediaItem(
          id: 'media-2',
          diveId: 'dive-1',
          mediaType: MediaType.photo,
          takenAt: DateTime(2024, 1, 15, 9, 45),
          createdAt: now,
          updatedAt: now,
        );
        final testMedia3 = MediaItem(
          id: 'media-3',
          diveId: 'dive-2',
          mediaType: MediaType.video,
          takenAt: DateTime(2024, 1, 15, 14, 30),
          createdAt: now,
          updatedAt: now,
        );

        final container = ProviderContainer(
          overrides: [
            divesForTripProvider('test-trip').overrideWith((ref) {
              return Future.value([testDive1, testDive2]);
            }),
            mediaForDiveProvider('dive-1').overrideWith((ref) {
              return Future.value([testMedia1, testMedia2]);
            }),
            mediaForDiveProvider('dive-2').overrideWith((ref) {
              return Future.value([testMedia3]);
            }),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          mediaForTripProvider('test-trip').future,
        );

        expect(result.length, equals(2));
        expect(result[testDive1]!.length, equals(2));
        expect(result[testDive2]!.length, equals(1));
      },
    );

    test('excludes dives with no media from result map', () async {
      final testDive1 = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 9, 0),
      );
      final testDive2 = Dive(
        id: 'dive-2',
        dateTime: DateTime(2024, 1, 15, 14, 0),
      );
      final now = DateTime.now();
      final testMedia1 = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 9, 30),
        createdAt: now,
        updatedAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          divesForTripProvider('test-trip').overrideWith((ref) {
            return Future.value([testDive1, testDive2]);
          }),
          mediaForDiveProvider('dive-1').overrideWith((ref) {
            return Future.value([testMedia1]);
          }),
          mediaForDiveProvider('dive-2').overrideWith((ref) {
            return Future.value(<MediaItem>[]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        mediaForTripProvider('test-trip').future,
      );

      // Only dive-1 should be in the map since dive-2 has no media
      expect(result.length, equals(1));
      expect(result.containsKey(testDive1), isTrue);
      expect(result.containsKey(testDive2), isFalse);
    });
  });

  group('mediaCountForTripProvider', () {
    test('returns 0 when trip has no media', () async {
      final container = ProviderContainer(
        overrides: [
          divesForTripProvider('empty-trip').overrideWith((ref) {
            return Future.value(<Dive>[]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final count = await container.read(
        mediaCountForTripProvider('empty-trip').future,
      );

      expect(count, equals(0));
    });

    test('returns total count across all dives', () async {
      final testDive1 = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 9, 0),
      );
      final testDive2 = Dive(
        id: 'dive-2',
        dateTime: DateTime(2024, 1, 15, 14, 0),
      );
      final now = DateTime.now();
      final testMedia1 = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 9, 30),
        createdAt: now,
        updatedAt: now,
      );
      final testMedia2 = MediaItem(
        id: 'media-2',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 9, 45),
        createdAt: now,
        updatedAt: now,
      );
      final testMedia3 = MediaItem(
        id: 'media-3',
        diveId: 'dive-2',
        mediaType: MediaType.video,
        takenAt: DateTime(2024, 1, 15, 14, 30),
        createdAt: now,
        updatedAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          divesForTripProvider('test-trip').overrideWith((ref) {
            return Future.value([testDive1, testDive2]);
          }),
          mediaForDiveProvider('dive-1').overrideWith((ref) {
            return Future.value([testMedia1, testMedia2]);
          }),
          mediaForDiveProvider('dive-2').overrideWith((ref) {
            return Future.value([testMedia3]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final count = await container.read(
        mediaCountForTripProvider('test-trip').future,
      );

      expect(count, equals(3));
    });
  });

  group('flatMediaListForTripProvider', () {
    test('returns empty list when trip has no media', () async {
      final container = ProviderContainer(
        overrides: [
          divesForTripProvider('test-trip').overrideWith((ref) {
            return Future.value(<Dive>[]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        flatMediaListForTripProvider('test-trip').future,
      );

      expect(result, isEmpty);
    });

    test('returns flat list sorted by takenAt chronologically', () async {
      final testDive1 = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 9, 0),
      );
      final testDive2 = Dive(
        id: 'dive-2',
        dateTime: DateTime(2024, 1, 15, 14, 0),
      );
      final now = DateTime.now();
      // Media from dive-1 taken at different times
      final testMedia1 = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 9, 30), // First
        createdAt: now,
        updatedAt: now,
      );
      final testMedia2 = MediaItem(
        id: 'media-2',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 9, 45), // Second
        createdAt: now,
        updatedAt: now,
      );
      // Media from dive-2 taken in between
      final testMedia3 = MediaItem(
        id: 'media-3',
        diveId: 'dive-2',
        mediaType: MediaType.video,
        takenAt: DateTime(2024, 1, 15, 14, 30), // Third
        createdAt: now,
        updatedAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          divesForTripProvider('test-trip').overrideWith((ref) {
            return Future.value([testDive1, testDive2]);
          }),
          mediaForDiveProvider('dive-1').overrideWith((ref) {
            return Future.value([testMedia1, testMedia2]);
          }),
          mediaForDiveProvider('dive-2').overrideWith((ref) {
            return Future.value([testMedia3]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        flatMediaListForTripProvider('test-trip').future,
      );

      expect(result.length, equals(3));
      // Verify chronological order
      expect(result[0].id, equals('media-1'));
      expect(result[1].id, equals('media-2'));
      expect(result[2].id, equals('media-3'));
    });

    test('flattens media from multiple dives into single list', () async {
      final testDive1 = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 9, 0),
      );
      final testDive2 = Dive(
        id: 'dive-2',
        dateTime: DateTime(2024, 1, 15, 14, 0),
      );
      final now = DateTime.now();
      final testMedia1 = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 9, 30),
        createdAt: now,
        updatedAt: now,
      );
      final testMedia2 = MediaItem(
        id: 'media-2',
        diveId: 'dive-2',
        mediaType: MediaType.video,
        takenAt: DateTime(2024, 1, 15, 14, 30),
        createdAt: now,
        updatedAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          divesForTripProvider('test-trip').overrideWith((ref) {
            return Future.value([testDive1, testDive2]);
          }),
          mediaForDiveProvider('dive-1').overrideWith((ref) {
            return Future.value([testMedia1]);
          }),
          mediaForDiveProvider('dive-2').overrideWith((ref) {
            return Future.value([testMedia2]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        flatMediaListForTripProvider('test-trip').future,
      );

      expect(result.length, equals(2));
      expect(result.any((m) => m.id == 'media-1'), isTrue);
      expect(result.any((m) => m.id == 'media-2'), isTrue);
    });
  });
}
