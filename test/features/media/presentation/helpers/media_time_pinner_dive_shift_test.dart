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

/// Issue #4539: a dive-wide shift is one write to the dive followed by one
/// enrichment pass, so every item on the dive moves on the next tick.
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
      repository: repository,
      setDiveShift: dives.setMediaTimeOffsetSeconds,
      enricher: DiveMediaEnricher(
        // The profile is stubbed; the shift is read back from the database,
        // which is where the pinner writes it.
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

  test('shifting the dive moves every item on it', () async {
    // Stamped 10:06 and 10:11 by a camera running a minute ahead.
    final first = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    final second = await linkedItem('b', DateTime.utc(2026, 1, 1, 10, 11));

    await pinner.apply(first, const MediaTimeDiveShifted(-60));

    expect((await dives.getDiveById(diveId))!.mediaTimeOffsetSeconds, -60);
    expect((await fetch(first)).enrichment?.elapsedSeconds, 300);
    expect((await fetch(first)).enrichment?.depthMeters, 10);
    expect((await fetch(second)).enrichment?.elapsedSeconds, 600);
    expect((await fetch(second)).enrichment?.depthMeters, 20);
  });

  // The item the diver lined up now sits there by the shift. A pin left on
  // it would hold it still the next time the shift changes.
  test('the item the shift was set from gives up its own pin', () async {
    final item = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    await pinner.apply(item, const MediaTimePinned(900));

    await pinner.apply(await fetch(item), const MediaTimeDiveShifted(-60));

    final fetched = await fetch(item);
    expect(fetched.manualElapsedSeconds, isNull);
    expect(fetched.enrichment?.elapsedSeconds, 300);
    expect(fetched.enrichment?.matchConfidence, MatchConfidence.exact);
  });

  test('another item keeps the pin the diver gave it', () async {
    final first = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    final pinned = await linkedItem('b', DateTime.utc(2026, 1, 1, 10, 11));
    await pinner.apply(pinned, const MediaTimePinned(900));

    await pinner.apply(first, const MediaTimeDiveShifted(-60));

    final fetched = await fetch(pinned);
    expect(fetched.manualElapsedSeconds, 900);
    expect(fetched.enrichment?.elapsedSeconds, 900);
  });

  test('removing the shift puts every item back', () async {
    final first = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    final second = await linkedItem('b', DateTime.utc(2026, 1, 1, 10, 11));
    await pinner.apply(first, const MediaTimeDiveShifted(-60));

    await pinner.apply(first, const MediaTimeDiveShiftRemoved());

    expect((await dives.getDiveById(diveId))!.mediaTimeOffsetSeconds, 0);
    expect((await fetch(first)).enrichment?.elapsedSeconds, 360);
    expect((await fetch(second)).enrichment?.elapsedSeconds, 660);
  });

  test('removing the shift leaves a pin alone', () async {
    final item = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    await pinner.apply(item, const MediaTimePinned(900));

    await pinner.apply(await fetch(item), const MediaTimeDiveShiftRemoved());

    expect((await fetch(item)).manualElapsedSeconds, 900);
  });

  // A dive that will not load costs the shift, not the dialog.
  test('automaticTimeFor is null when the dive cannot be read', () async {
    final item = await linkedItem('a', DateTime.utc(2026, 1, 1, 10, 6));
    final failing = MediaTimePinner(
      repository: repository,
      setDiveShift: dives.setMediaTimeOffsetSeconds,
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
    await pinner.apply(item, const MediaTimeDiveShifted(-60));

    final automatic = await pinner.automaticTimeFor(await fetch(item));

    expect(automatic!.elapsedSeconds, 300);
    expect(automatic.diveShiftSeconds, -60);
  });
}
