import 'package:drift/drift.dart' show UpdateKind, Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_media_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/test_database.dart';

class _CountingRepository extends TripMediaRepository {
  int previews = 0;
  int fullLoads = 0;

  @override
  Future<TripMediaPreview> getPreview(String tripId, {String? diverId}) {
    previews++;
    return super.getPreview(tripId, diverId: diverId);
  }

  @override
  Future<List<MediaItem>> getMediaForTrip(String tripId, {String? diverId}) {
    fullLoads++;
    return super.getMediaForTrip(tripId, diverId: diverId);
  }
}

/// Past the trailing debounce of the media and dive-detail ticks.
Future<void> _tickSettled() =>
    Future<void>.delayed(MediaRepository.changeTickDebounce * 2);

void main() {
  late AppDatabase db;
  late _CountingRepository repository;
  final dive1 = Dive(id: 'd1', dateTime: DateTime(2024, 1, 15, 9));
  final dive2 = Dive(id: 'd2', dateTime: DateTime(2024, 1, 15, 14));
  final emptyDive = Dive(id: 'empty', dateTime: DateTime(2024, 1, 16, 9));

  // customInsert rather than customStatement: only a declared update reaches
  // Drift's change ticks.
  Future<void> media(String id, String diveId, int takenAt) => db.customInsert(
    'INSERT INTO media (id, dive_id, file_path, file_type, taken_at, '
    "created_at, updated_at) VALUES (?, ?, 'p', 'photo', ?, 0, 0)",
    variables: [
      Variable.withString(id),
      Variable.withString(diveId),
      Variable.withInt(takenAt),
    ],
    updates: {db.media},
  );

  ProviderContainer container({List<Dive>? dives}) {
    final tripDives = dives ?? [dive1, dive2, emptyDive];
    final result = ProviderContainer(
      overrides: [
        tripMediaRepositoryProvider.overrideWithValue(repository),
        divesForTripProvider('T').overrideWith((ref) async => tripDives),
        diveIdsForTripProvider(
          'T',
        ).overrideWith((ref) async => [for (final dive in tripDives) dive.id]),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        // A trip read must never fall back to one query per dive.
        mediaForDiveProvider.overrideWith(
          (ref, diveId) => throw StateError('per-dive read of $diveId'),
        ),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = _CountingRepository();
    await db.customStatement(
      'INSERT INTO trips (id, name, start_date, end_date, created_at, '
      "updated_at) VALUES ('T', 'T', 0, 0, 0, 0)",
    );
    for (final dive in [dive1, dive2, emptyDive]) {
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, trip_id, created_at, '
        "updated_at) VALUES (?, 0, 'T', 0, 0)",
        [dive.id],
      );
    }
  });
  tearDown(tearDownTestDatabase);

  group('tripMediaPreviewProvider', () {
    test('an empty trip skips the query', () async {
      final preview = await container(
        dives: const [],
      ).read(tripMediaPreviewProvider('T').future);

      expect(preview, TripMediaPreview.empty);
      expect(repository.previews, 0);
    });

    test('reads the trip once, however many dives it has', () async {
      await media('m1', 'd1', 1000);
      await media('m2', 'd2', 2000);

      final preview = await container().read(
        tripMediaPreviewProvider('T').future,
      );

      expect(preview.byDiveId.keys, unorderedEquals(['d1', 'd2']));
      expect(repository.previews, 1);
      expect(repository.fullLoads, 0);
    });

    test('a media write refreshes it', () async {
      final c = container();
      final sub = c.listen(tripMediaPreviewProvider('T').future, (_, _) {});
      addTearDown(sub.close);
      await sub.read();

      await media('m1', 'd1', 1000);
      await _tickSettled();

      expect((await sub.read()).mediaCount, 1);
    });

    test('deleting a dive refreshes it without a media write', () async {
      await media('m1', 'd1', 1000);
      final c = ProviderContainer(
        overrides: [
          tripMediaRepositoryProvider.overrideWithValue(repository),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(tripMediaPreviewProvider('T').future, (_, _) {});
      addTearDown(sub.close);
      expect((await sub.read()).mediaCount, 1);

      await db.customUpdate(
        "DELETE FROM dives WHERE id = 'd1'",
        updates: {db.dives},
        updateKind: UpdateKind.delete,
      );
      await _tickSettled();

      expect((await sub.read()).mediaCount, 0);
    });

    test('an enrichment write does not re-read it', () async {
      await media('m1', 'd1', 1000);
      final c = container();
      final sub = c.listen(tripMediaPreviewProvider('T').future, (_, _) {});
      addTearDown(sub.close);
      await sub.read();

      await db.customInsert(
        'INSERT INTO media_enrichment (id, media_id, dive_id, created_at) '
        "VALUES ('e1', 'm1', 'd1', 0)",
        updates: {db.mediaEnrichment},
      );
      await _tickSettled();
      await sub.read();

      expect(repository.previews, 1);
    });

    test('an unrelated dive detail write does not re-read it', () async {
      final c = container();
      final sub = c.listen(tripMediaPreviewProvider('T').future, (_, _) {});
      addTearDown(sub.close);
      await sub.read();

      // On the dive-detail tick the per-dive providers listen to, but no
      // part of a trip's media.
      var detailTicks = 0;
      final detail = DiveRepository().watchDiveDetailChanges().listen(
        (_) => detailTicks++,
      );
      addTearDown(detail.cancel);
      await db.customInsert(
        'INSERT INTO tags (id, name, created_at, updated_at) '
        "VALUES ('t1', 'Reef', 0, 0)",
        updates: {db.tags},
      );
      await _tickSettled();
      await sub.read();

      expect(detailTicks, 1);
      expect(repository.previews, 1);
    });
  });

  group('mediaForTripProvider', () {
    Future<Map<Dive, List<MediaItem>>> read(ProviderContainer c) {
      final sub = c.listen(mediaForTripProvider('T').future, (_, _) {});
      addTearDown(sub.close);
      return sub.read();
    }

    test('returns an empty map when the trip has no dives', () async {
      final result = await read(container(dives: const []));

      expect(result, isEmpty);
      expect(repository.fullLoads, 0);
    });

    test('groups a single read by dive, leaving out empty dives', () async {
      await media('m1', 'd1', 1000);
      await media('m2', 'd1', 2000);
      await media('m3', 'd2', 3000);

      final result = await read(container());

      expect(result.keys, [dive1, dive2]);
      expect(result[dive1]!.map((m) => m.id), ['m1', 'm2']);
      expect(result[dive2]!.map((m) => m.id), ['m3']);
      expect(repository.fullLoads, 1);
    });

    test('is released when nothing is watching it', () async {
      final c = container();
      final sub = c.listen(mediaForTripProvider('T').future, (_, _) {});
      await sub.read();
      expect(c.exists(mediaForTripProvider('T')), isTrue);

      sub.close();
      await c.pump();

      expect(c.exists(mediaForTripProvider('T')), isFalse);
    });
  });

  group('mediaCountForTripProvider', () {
    test('returns 0 when the trip has no media', () async {
      final count = await container().read(
        mediaCountForTripProvider('T').future,
      );

      expect(count, 0);
    });

    test('totals every dive past the preview limit', () async {
      for (var i = 0; i < tripMediaPreviewLimit + 3; i++) {
        await media('a$i', 'd1', i);
      }
      await media('b', 'd2', 0);

      final count = await container().read(
        mediaCountForTripProvider('T').future,
      );

      expect(count, tripMediaPreviewLimit + 4);
    });
  });

  group('flatMediaListForTripProvider', () {
    Future<List<MediaItem>> read(ProviderContainer c) {
      final sub = c.listen(flatMediaListForTripProvider('T').future, (_, _) {});
      addTearDown(sub.close);
      return sub.read();
    }

    test('returns an empty list when the trip has no media', () async {
      expect(await read(container()), isEmpty);
    });

    test('sorts across dives chronologically', () async {
      await media('late', 'd1', 3000);
      await media('early', 'd2', 1000);
      await media('middle', 'd1', 2000);

      final result = await read(container());

      expect(result.map((m) => m.id), ['early', 'middle', 'late']);
    });
  });
}
