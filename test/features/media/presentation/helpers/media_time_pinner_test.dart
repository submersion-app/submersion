import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_pinner.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1090: applying the dialog's choice is one write to the media row
/// followed by one enrichment pass, so the chart and viewer reposition on
/// the next tick rather than waiting for a later backfill.
void main() {
  late MediaRepository repository;
  late MediaTimePinner pinner;
  late String diveId;

  final dive = domain.Dive(
    id: '',
    dateTime: DateTime.utc(2026, 1, 1, 10),
    entryTime: DateTime.utc(2026, 1, 1, 10),
    profile: const [
      domain.DiveProfilePoint(timestamp: 0, depth: 0),
      domain.DiveProfilePoint(timestamp: 600, depth: 20, temperature: 24),
      domain.DiveProfilePoint(timestamp: 1200, depth: 0),
    ],
  );

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaRepository();
    diveId = (await DiveRepository().createDive(dive)).id;
    // A real enricher over the real repository; only the dive load is
    // stubbed, since the dive's profile is the only thing it needs.
    pinner = MediaTimePinner(
      repository: repository,
      enricher: DiveMediaEnricher(
        loadDive: (_) async => dive.copyWith(id: diveId),
        loadMediaForDive: repository.getMediaForDive,
        saveEnrichments: repository.saveEnrichments,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<MediaItem> linkedItem() async {
    return repository.createMedia(
      MediaItem(
        id: '',
        diveId: diveId,
        filePath: '/photos/a.jpg',
        mediaType: MediaType.photo,
        // A decade off, as in the report.
        takenAt: DateTime.utc(2016, 1, 6, 0, 3),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
  }

  test('pinning writes the offset and re-enriches at it', () async {
    final item = await linkedItem();

    await pinner.apply(item, const MediaTimePinned(600));

    final fetched = (await repository.getMediaById(item.id))!;
    expect(fetched.manualElapsedSeconds, 600);
    expect(fetched.enrichment?.elapsedSeconds, 600);
    expect(fetched.enrichment?.depthMeters, 20);
    expect(fetched.enrichment?.matchConfidence, MatchConfidence.manual);
  });

  test(
    'resetting clears the offset and re-enriches from the capture time',
    () async {
      final item = await linkedItem();
      await pinner.apply(item, const MediaTimePinned(600));

      await pinner.apply(item, const MediaTimeReset());

      final fetched = (await repository.getMediaById(item.id))!;
      expect(fetched.manualElapsedSeconds, isNull);
      expect(fetched.enrichment?.matchConfidence, MatchConfidence.estimated);
      expect(fetched.enrichment?.elapsedSeconds, isNot(600));
    },
  );

  test('an item with no dive link is left untouched', () async {
    final item = await repository.createMedia(
      MediaItem(
        id: '',
        filePath: '/photos/b.jpg',
        mediaType: MediaType.photo,
        takenAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await pinner.apply(item, const MediaTimePinned(600));

    expect(
      (await repository.getMediaById(item.id))!.manualElapsedSeconds,
      isNull,
    );
  });
}
