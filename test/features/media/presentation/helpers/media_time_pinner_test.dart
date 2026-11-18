import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_pinner.dart';

import '../../../../helpers/test_database.dart';

/// What the Set-time dialog offers (issues #1090, #4539): the item's
/// automatic time, with the dive's shift, read through the enricher.
void main() {
  late MediaRepository repository;
  late DiveRepository dives;
  late MediaTimePinner pinner;
  late String diveId;

  // One metre every thirty seconds down to 600 s, so a depth names its time.
  final dive = domain.Dive(
    id: '',
    dateTime: DateTime.utc(2026, 1, 1, 10),
    entryTime: DateTime.utc(2026, 1, 1, 10),
    profile: const [
      domain.DiveProfilePoint(timestamp: 0, depth: 0),
      domain.DiveProfilePoint(timestamp: 300, depth: 10),
      domain.DiveProfilePoint(timestamp: 360, depth: 12),
      domain.DiveProfilePoint(timestamp: 600, depth: 20),
      domain.DiveProfilePoint(timestamp: 660, depth: 22),
      domain.DiveProfilePoint(timestamp: 1200, depth: 0),
    ],
  );

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaRepository();
    dives = DiveRepository();
    diveId = (await dives.createDive(dive)).id;
    pinner = MediaTimePinner(
      enricher: DiveMediaEnricher(
        // The profile is stubbed; the shift is read back from the database.
        loadDive: (id) async => dive.copyWith(
          id: id,
          mediaTimeOffsetSeconds: (await dives.getDiveById(
            id,
          ))!.mediaTimeOffsetSeconds,
        ),
        loadMediaForDive: repository.getMediaForDive,
        loadPrimarySourceEntry: (_) async => null,
        saveEnrichments: repository.saveEnrichments,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<MediaItem> linkedItem(String name, DateTime takenAt) =>
      repository.createMedia(
        MediaItem(
          id: '',
          diveId: diveId,
          filePath: '/photos/$name.jpg',
          mediaType: MediaType.photo,
          takenAt: takenAt,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  Future<MediaItem> fetch(MediaItem item) async =>
      (await repository.getMediaById(item.id))!;

  // A dive that will not load costs the shift, not the dialog.
  test('automaticTimeFor is null when the dive cannot be read', () async {
    final item = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    final failing = MediaTimePinner(
      enricher: DiveMediaEnricher(
        loadDive: (_) async => throw StateError('unreadable series'),
        loadMediaForDive: repository.getMediaForDive,
        loadPrimarySourceEntry: (_) async => null,
        saveEnrichments: repository.saveEnrichments,
      ),
    );

    expect(await failing.automaticTimeFor(item), isNull);
  });

  test('automaticTimeFor reads the enricher', () async {
    final item = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    await dives.setMediaTimeOffsetSeconds(diveId, -60);

    final automatic = await pinner.automaticTimeFor(await fetch(item));

    expect(automatic!.elapsedSeconds, 300);
    expect(automatic.diveShiftSeconds, -60);
  });
}
