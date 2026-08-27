import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/site_media_import_helper.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

import '../../data/services/media_import_service_test.mocks.dart';
import '../support/media_widget_harness.dart';

AssetInfo _asset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2026, 3, 1, 10, 30),
  width: 1920,
  height: 1080,
);

void main() {
  late MockMediaRepository repository;
  late MediaImportService service;

  setUp(() {
    repository = MockMediaRepository();
    service = MediaImportService(
      mediaRepository: repository,
      enrichmentService: MockEnrichmentService(),
    );
    when(
      repository.getLinkedAssetIdsForSite(any),
    ).thenAnswer((_) async => <String>{});
    when(
      repository.getLinkedLocalPathsForSite(any),
    ).thenAnswer((_) async => <String>{});
    when(repository.createMedia(any)).thenAnswer((invocation) async {
      final item = invocation.positionalArguments.first as MediaItem;
      return item.copyWith(id: 'saved-${item.platformAssetId}');
    });
  });

  /// Drives [SiteMediaImportHelper.linkSelectedAssets] with a real
  /// BuildContext and WidgetRef, which is what it needs for the SnackBar
  /// and the provider invalidations.
  Future<bool> runLink(
    WidgetTester tester, {
    required List<AssetInfo>? selected,
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

    final imported = await SiteMediaImportHelper.linkSelectedAssets(
      context: capturedContext,
      ref: capturedRef,
      siteId: 'site-1',
      selectedAssets: selected,
    );
    await tester.pumpAndSettle();
    return imported;
  }

  testWidgets('links the selection and reports the imported count', (
    tester,
  ) async {
    final imported = await runLink(
      tester,
      selected: [_asset('a1'), _asset('a2')],
    );

    expect(imported, isTrue);
    expect(find.text('Imported 2 photos'), findsOneWidget);
    // Both rows were persisted against the site, not a dive.
    final captured = verify(repository.createMedia(captureAny)).captured;
    expect(captured, hasLength(2));
    expect(captured.every((m) => (m as MediaItem).siteId == 'site-1'), isTrue);
  });

  testWidgets('singular wording for a single photo', (tester) async {
    final imported = await runLink(tester, selected: [_asset('a1')]);

    expect(imported, isTrue);
    expect(find.text('Imported 1 photo'), findsOneWidget);
  });

  testWidgets('a cancelled picker links nothing and shows no SnackBar', (
    tester,
  ) async {
    final imported = await runLink(tester, selected: null);

    expect(imported, isFalse);
    expect(find.byType(SnackBar), findsNothing);
    verifyNever(repository.createMedia(any));
  });

  testWidgets('an empty selection links nothing', (tester) async {
    final imported = await runLink(tester, selected: const []);

    expect(imported, isFalse);
    expect(find.byType(SnackBar), findsNothing);
    verifyNever(repository.createMedia(any));
  });

  testWidgets('reports false and surfaces the error when the import throws', (
    tester,
  ) async {
    when(
      repository.getLinkedAssetIdsForSite(any),
    ).thenThrow(Exception('db is gone'));

    final imported = await runLink(tester, selected: [_asset('a1')]);

    expect(imported, isFalse);
    expect(
      find.textContaining('Failed to import photos: Exception: db is gone'),
      findsOneWidget,
    );
  });

  testWidgets('every asset failing still reports a zero-count import', (
    tester,
  ) async {
    // Per-asset failures are collected by the service rather than thrown,
    // so the helper takes its success path with an empty imported list.
    when(repository.createMedia(any)).thenThrow(Exception('write failed'));

    final imported = await runLink(tester, selected: [_asset('a1')]);

    expect(imported, isFalse);
    expect(find.text('Imported 0 photos'), findsOneWidget);
  });
}
