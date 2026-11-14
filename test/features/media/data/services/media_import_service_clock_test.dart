import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import 'media_import_service_test.mocks.dart';

/// Issue #4539: a picked photo is placed on the dive's media clock at import,
/// so it does not wait for the next backfill to land on the right depth.
void main() {
  late MockMediaRepository repository;

  // Logged at 10:00:00; the computer began at 10:00:30 and the camera runs
  // 30 seconds ahead of it.
  final dive = Dive(
    id: 'dive-1',
    dateTime: DateTime.utc(2026, 7, 1, 10),
    entryTime: DateTime.utc(2026, 7, 1, 10),
    mediaTimeOffsetSeconds: -30,
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 1800, depth: 18),
      DiveProfilePoint(timestamp: 3600, depth: 0),
    ],
  );

  // Stamped 10:31:00 by the camera: the computer's 10:30:30.
  final asset = AssetInfo(
    id: 'asset-1',
    type: AssetType.image,
    createDateTime: DateTime.utc(2026, 7, 1, 10, 31),
    width: 1920,
    height: 1080,
  );

  setUp(() {
    repository = MockMediaRepository();
    when(
      repository.getGalleryLinksForDive(any),
    ).thenAnswer((_) async => const []);
    when(repository.createMedia(any)).thenAnswer(
      (invocation) async => (invocation.positionalArguments[0] as MediaItem)
          .copyWith(id: 'media-1'),
    );
    when(repository.saveEnrichment(any)).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments[0] as MediaEnrichment,
    );
  });

  Future<MediaEnrichment> importWith(
    Future<DateTime?> Function(String diveId)? primarySourceEntry,
  ) async {
    final service = MediaImportService(
      mediaRepository: repository,
      enrichmentService: const EnrichmentService(),
      primarySourceEntry: primarySourceEntry,
    );
    await service.importPhotosForDive(selectedAssets: [asset], dive: dive);
    return verify(repository.saveEnrichment(captureAny)).captured.single
        as MediaEnrichment;
  }

  test("counts from the primary computer's entry, shifted", () async {
    final asked = <String>[];
    final enrichment = await importWith((diveId) async {
      asked.add(diveId);
      return DateTime.utc(2026, 7, 1, 10, 0, 30);
    });

    expect(asked, ['dive-1'], reason: 'one read for the whole pick');
    expect(enrichment.elapsedSeconds, 1800);
    expect(enrichment.depthMeters, 18);
  });

  test('counts from the dive start when it is given no source', () async {
    final enrichment = await importWith(null);

    // 10:31:00 less the 30 second shift, from 10:00:00.
    expect(enrichment.elapsedSeconds, 1830);
  });
}
