import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import 'media_import_service_test.mocks.dart';

/// Preparing a pick for a sitting, which holds it until Save, and writing
/// it then (issue #4527, plan 6).
void main() {
  late MockMediaRepository repository;
  late MediaImportService service;
  final dive = Dive(id: 'dive-1', dateTime: DateTime(2024, 1, 15, 10));

  AssetInfo asset(String id) => AssetInfo(
    id: id,
    type: AssetType.image,
    createDateTime: DateTime(2024, 1, 15, 10, 30),
    width: 1920,
    height: 1080,
  );

  setUp(() {
    repository = MockMediaRepository();
    service = MediaImportService(
      mediaRepository: repository,
      enrichmentService: MockEnrichmentService(),
    );
    when(
      repository.getLinkedLocalPathsForDive(any),
    ).thenAnswer((_) async => <String>{});
    when(
      repository.getGalleryLinksForDive(any),
    ).thenAnswer((_) async => const <MediaItem>[]);
    when(repository.createMedia(any)).thenAnswer(
      (invocation) async => invocation.positionalArguments.single as MediaItem,
    );
  });

  test('prepareForDive builds the rows importPhotosForDive writes, with '
      'their own ids, and writes none', () async {
    final prepared = await service.prepareForDive(
      selectedAssets: [asset('a1'), asset('a2')],
      dive: dive,
    );

    expect(prepared, hasLength(2));
    expect(prepared.map((p) => p.item.diveId), ['dive-1', 'dive-1']);
    expect(prepared.map((p) => p.item.platformAssetId), ['a1', 'a2']);
    expect(prepared.every((p) => p.item.id.isNotEmpty), isTrue);
    verifyNever(repository.createMedia(any));
  });

  test('prepareForDive leaves out what the dive already links', () async {
    when(repository.getGalleryLinksForDive('dive-1')).thenAnswer(
      (_) async => [
        MediaItem(
          id: 'm1',
          diveId: 'dive-1',
          platformAssetId: 'a1',
          mediaType: MediaType.photo,
          takenAt: DateTime(2024),
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ],
    );
    final prepared = await service.prepareForDive(
      selectedAssets: [asset('a1'), asset('a2')],
      dive: dive,
    );
    expect(prepared.map((p) => p.item.platformAssetId), ['a2']);
  });

  test('writePrepared writes each row under its own id and queues '
      'nothing', () async {
    var queued = 0;
    service = MediaImportService(
      mediaRepository: repository,
      enrichmentService: MockEnrichmentService(),
      onMediaCreated: (_) => queued++,
    );
    final prepared = await service.prepareForDive(
      selectedAssets: [asset('a1')],
      dive: dive,
    );

    final written = await service.writePrepared(prepared);
    expect(written.single.id, prepared.single.item.id);
    verify(repository.createMedia(any)).called(1);
    expect(queued, 0);
  });
}
