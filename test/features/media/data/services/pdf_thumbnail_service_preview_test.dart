import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/data/services/pdf_thumbnail_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Issue #1039: the large site card shows page 1 of a PDF at card width,
/// with the document's page count.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_preview_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  MediaItem pdf({String name = 'map.pdf'}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.document,
    originalFilename: name,
    contentHash: 'abc',
    takenAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  final jpeg = Uint8List.fromList([1, 2, 3]);

  PdfThumbnailService service({
    required List<int> sizes,
    PdfPagePreview? result,
    bool throws = false,
  }) => PdfThumbnailService(
    cacheDir: () async => Directory(p.join(tmp.path, 'cache')),
    previewRenderer: ({file, bytes, maxDimension = 0, quality = 0}) async {
      sizes.add(maxDimension);
      if (throws) throw Exception('render failed');
      return result;
    },
  );

  test('renders at the requested size with the page count', () async {
    final sizes = <int>[];
    final svc = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 3),
    );
    final preview = await svc.previewFor(
      pdf(),
      maxDimension: 1536,
      bytes: () async => Uint8List(1),
    );
    expect(sizes, [1536]);
    expect(preview!.jpeg, jpeg);
    expect(preview.pageCount, 3);
  });

  test('a warm cache answers without reading or rendering', () async {
    final sizes = <int>[];
    final svc = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 2),
    );
    await svc.previewFor(
      pdf(),
      maxDimension: 1024,
      bytes: () async => Uint8List(1),
    );
    var reads = 0;
    final again = await svc.previewFor(
      pdf(),
      maxDimension: 1024,
      bytes: () async {
        reads++;
        return Uint8List(1);
      },
    );
    expect(reads, 0);
    expect(sizes, [1024]);
    expect(again!.pageCount, 2);
  });

  test('each size is cached separately', () async {
    final sizes = <int>[];
    final svc = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 1),
    );
    await svc.previewFor(
      pdf(),
      maxDimension: 1024,
      bytes: () async => Uint8List(1),
    );
    await svc.previewFor(
      pdf(),
      maxDimension: 2048,
      bytes: () async => Uint8List(1),
    );
    expect(sizes, [1024, 2048]);
    expect(
      PdfThumbnailService.previewCacheKeyFor(pdf(), 1024),
      isNot(PdfThumbnailService.previewCacheKeyFor(pdf(), 2048)),
    );
  });

  test('a non-PDF, missing bytes, or a failed render is null', () async {
    final sizes = <int>[];
    final ok = service(
      sizes: sizes,
      result: PdfPagePreview(jpeg: jpeg, pageCount: 1),
    );
    expect(
      await ok.previewFor(
        pdf(name: 'notes.txt'),
        maxDimension: 1024,
        bytes: () async => Uint8List(1),
      ),
      isNull,
    );
    expect(
      await ok.previewFor(pdf(), maxDimension: 1024, bytes: () async => null),
      isNull,
    );
    final failing = service(sizes: sizes, throws: true);
    expect(
      await failing.previewFor(
        pdf(),
        maxDimension: 1024,
        bytes: () async => Uint8List(1),
      ),
      isNull,
    );
  });
}
