import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/data/services/pdf_thumbnail_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';

void main() {
  test('rounds the physical width up to a cache bucket, capped at 2048', () {
    expect(pdfPreviewBucket(360, 2), 1024);
    expect(pdfPreviewBucket(600, 2), 1536);
    expect(pdfPreviewBucket(700, 2), 1536);
    expect(pdfPreviewBucket(800, 2), 2048);
    expect(pdfPreviewBucket(1400, 3), 2048);
    expect(pdfPreviewBucket(0, 1), 1024);
  });

  group('pdfLargePreviewProvider', () {
    late Directory tmp;
    final pdf = MediaItem(
      id: 'm1',
      mediaType: MediaType.document,
      originalFilename: 'map.pdf',
      takenAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('pdf_preview_provider');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    ProviderContainer container({
      required ResolvedAssetResult resolved,
      required List<(Uint8List?, int)> renders,
    }) {
      final c = ProviderContainer(
        overrides: [
          mediaBytesProvider(pdf).overrideWith((ref) async => resolved),
          pdfThumbnailServiceProvider.overrideWithValue(
            PdfThumbnailService(
              cacheDir: () async => Directory(p.join(tmp.path, 'cache')),
              previewRenderer:
                  ({file, bytes, maxDimension = 0, quality = 0}) async {
                    renders.add((bytes, maxDimension));
                    return PdfPagePreview(
                      jpeg: Uint8List.fromList([9]),
                      pageCount: 2,
                    );
                  },
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('renders the resolved bytes at the requested bucket', () async {
      final renders = <(Uint8List?, int)>[];
      final bytes = Uint8List.fromList([1, 2, 3]);
      final c = container(
        resolved: ResolvedAssetResult(
          bytes: bytes,
          status: ResolutionStatus.resolved,
        ),
        renders: renders,
      );

      // A card watches the provider while it renders; so does this test,
      // or the autoDispose entry would be gone before the bytes are read.
      final request = (item: pdf, maxDimension: 1536);
      final sub = c.listen(pdfLargePreviewProvider(request), (_, _) {});
      addTearDown(sub.close);
      final preview = await c.read(pdfLargePreviewProvider(request).future);

      expect(preview!.pageCount, 2);
      expect(renders.single.$1, bytes);
      expect(renders.single.$2, 1536);
    });

    test('a render survives an unwatched gap', () async {
      final renders = <(Uint8List?, int)>[];
      final c = container(
        resolved: ResolvedAssetResult(
          bytes: Uint8List.fromList([4]),
          status: ResolutionStatus.resolved,
        ),
        renders: renders,
      );

      // Nobody listens: a card rebuilding at another size, or the diver
      // stepping away mid-render. The render must still land, not be thrown
      // away by auto-disposal halfway through.
      final preview = await c.read(
        pdfLargePreviewProvider((item: pdf, maxDimension: 2048)).future,
      );

      expect(preview, isNotNull);
      expect(renders.single.$2, 2048);
    });

    test('an unavailable PDF yields no preview and renders nothing', () async {
      final renders = <(Uint8List?, int)>[];
      final c = container(
        resolved: const ResolvedAssetResult(
          status: ResolutionStatus.unavailable,
        ),
        renders: renders,
      );

      // A card watches the provider while it renders; so does this test,
      // or the autoDispose entry would be gone before the bytes are read.
      final request = (item: pdf, maxDimension: 1024);
      final sub = c.listen(pdfLargePreviewProvider(request), (_, _) {});
      addTearDown(sub.close);
      final preview = await c.read(pdfLargePreviewProvider(request).future);

      expect(preview, isNull);
      expect(renders, isEmpty);
    });
  });
}
