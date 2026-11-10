import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_photo_import_helper.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

import '../../../media/data/services/media_import_service_test.mocks.dart';
import '../../../media/presentation/support/media_widget_harness.dart';

AssetInfo _asset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2026, 11, 3, 10, 30),
  width: 1920,
  height: 1080,
);

class _LinkedA1 extends GearPhotoRepository {
  @override
  Future<List<MediaItem>> galleryLinksFor(String equipmentId) async => [
    MediaItem(
      id: 'm-a1',
      equipmentId: equipmentId,
      platformAssetId: 'a1',
      mediaType: MediaType.photo,
      takenAt: DateTime.utc(2026),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<Set<String>> linkedLocalPathsFor(String equipmentId) async => {};
}

class _NoLinks extends GearPhotoRepository {
  @override
  Future<List<MediaItem>> galleryLinksFor(String equipmentId) async => [];

  @override
  Future<Set<String>> linkedLocalPathsFor(String equipmentId) async => {};
}

/// Gear photos (issue #3355): the picker's selection is linked to the item
/// and the check-in, and the outcome is reported.
void main() {
  late MockMediaRepository repository;
  late MediaImportService service;

  setUp(() {
    repository = MockMediaRepository();
    service = MediaImportService(
      mediaRepository: repository,
      enrichmentService: MockEnrichmentService(),
      gearPhotos: _NoLinks(),
    );
    when(repository.createMedia(any)).thenAnswer((invocation) async {
      final item = invocation.positionalArguments.first as MediaItem;
      return item.copyWith(id: 'saved-${item.platformAssetId}');
    });
  });

  Future<bool> runLink(
    WidgetTester tester, {
    required List<AssetInfo>? selected,
    String? observationId,
  }) async {
    late WidgetRef capturedRef;
    late BuildContext capturedContext;
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [mediaImportServiceProvider.overrideWithValue(service)],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    final imported = await GearPhotoImportHelper.linkSelectedAssets(
      context: capturedContext,
      ref: capturedRef,
      equipmentId: 'reg-1',
      observationId: observationId,
      selectedAssets: selected,
    );
    await tester.pumpAndSettle();
    return imported;
  }

  testWidgets('linkSelectedAssets links to the item and reports the count', (
    tester,
  ) async {
    final imported = await runLink(
      tester,
      selected: [_asset('a1'), _asset('a2')],
      observationId: 'obs-1',
    );

    expect(imported, isTrue);
    expect(find.text('Imported 2 photos'), findsOneWidget);
    final captured = verify(repository.createMedia(captureAny)).captured;
    for (final m in captured.cast<MediaItem>()) {
      expect(m.equipmentId, 'reg-1');
      expect(m.observationId, 'obs-1');
    }
  });

  testWidgets('a re-picked photo is reported as already linked', (
    tester,
  ) async {
    service = MediaImportService(
      mediaRepository: repository,
      enrichmentService: MockEnrichmentService(),
      gearPhotos: _LinkedA1(),
    );
    await runLink(tester, selected: [_asset('a1')]);

    expect(find.textContaining('1 already linked'), findsOneWidget);
    verifyNever(repository.createMedia(any));
  });

  testWidgets('a failed import says so and links nothing', (tester) async {
    when(repository.createMedia(any)).thenThrow(StateError('disk full'));
    final imported = await runLink(tester, selected: [_asset('a1')]);

    // Each failed asset is recorded, so nothing was imported.
    expect(imported, isFalse);
  });

  testWidgets('an empty selection links nothing', (tester) async {
    expect(await runLink(tester, selected: const []), isFalse);
    verifyNever(repository.createMedia(any));
  });
}
