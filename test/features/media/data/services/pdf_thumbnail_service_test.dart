import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/pdf_thumbnail_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// The renderer is always injected: pdfrx cannot initialise under
/// flutter_test, and a failed init hangs the calling future rather than
/// throwing.
void main() {
  late Directory root;
  late int renderCalls;
  late int sourceCalls;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pdf_thumbs');
    renderCalls = 0;
    sourceCalls = 0;
  });

  tearDown(() => root.delete(recursive: true));

  final jpeg = Uint8List.fromList([255, 216, 255, 224, 7, 7]);

  MediaItem pdf({
    String id = 'doc-1',
    String? contentHash,
    String filename = 'reef-map.pdf',
    DateTime? updatedAt,
  }) => MediaItem(
    id: id,
    siteId: 'site-1',
    mediaType: MediaType.document,
    sourceType: MediaSourceType.localFile,
    originalFilename: filename,
    contentHash: contentHash,
    takenAt: DateTime(2026, 8, 12),
    createdAt: DateTime(2026, 8, 12),
    updatedAt: updatedAt ?? DateTime(2026, 8, 12),
  );

  PdfThumbnailService service({
    bool declines = false,
    Future<Directory> Function()? cacheDir,
  }) => PdfThumbnailService(
    cacheDir: cacheDir ?? () async => Directory('${root.path}/cache'),
    renderer:
        ({
          File? file,
          Uint8List? bytes,
          int maxDimension = 512,
          int quality = 80,
        }) async {
          renderCalls++;
          return declines ? null : jpeg;
        },
  );

  Future<MediaSourceData> Function() serving(MediaSourceData data) => () async {
    sourceCalls++;
    return data;
  };

  test('renders page 1 from resolved bytes', () async {
    final result = await service().thumbFor(
      pdf(),
      source: serving(BytesData(bytes: Uint8List.fromList([37, 80]))),
    );

    expect(result, equals(jpeg));
    expect(renderCalls, 1);
  });

  test('renders page 1 from a resolved file', () async {
    final file = File('${root.path}/reef-map.pdf')..writeAsBytesSync([37, 80]);

    final result = await service().thumbFor(
      pdf(),
      source: serving(FileData(file: file)),
    );

    expect(result, equals(jpeg));
  });

  // The cache is the whole point on Android, where resolving the source
  // reads the entire PDF back across a platform channel.
  test('a second request is served from disk without resolving or '
      're-rendering', () async {
    final svc = service();
    final source = serving(BytesData(bytes: Uint8List.fromList([37, 80])));

    await svc.thumbFor(pdf(), source: source);
    final second = await svc.thumbFor(pdf(), source: source);

    expect(second, equals(jpeg));
    expect(renderCalls, 1);
    expect(sourceCalls, 1);
  });

  test(
    'a row whose content hash changed does not reuse the old tile',
    () async {
      final svc = service();
      final source = serving(BytesData(bytes: Uint8List.fromList([37, 80])));

      await svc.thumbFor(pdf(contentHash: 'a' * 64), source: source);
      await svc.thumbFor(pdf(contentHash: 'b' * 64), source: source);

      expect(renderCalls, 2);
    },
  );

  test('without a content hash the update stamp busts the entry', () async {
    expect(
      PdfThumbnailService.cacheKeyFor(pdf(updatedAt: DateTime(2026, 8, 12))),
      isNot(
        PdfThumbnailService.cacheKeyFor(pdf(updatedAt: DateTime(2026, 8, 13))),
      ),
    );
  });

  test('an unresolvable source never reaches the renderer', () async {
    final result = await service().thumbFor(
      pdf(),
      source: serving(const UnavailableData(kind: UnavailableKind.notFound)),
    );

    expect(result, isNull);
    expect(renderCalls, 0);
  });

  test('a source that throws yields null rather than escaping into the '
      'grid', () async {
    final result = await service().thumbFor(
      pdf(),
      source: () async => throw const FileSystemException('denied'),
    );

    expect(result, isNull);
  });

  test('a declined render is not cached', () async {
    final svc = service(declines: true);
    final source = serving(BytesData(bytes: Uint8List.fromList([37, 80])));

    expect(await svc.thumbFor(pdf(), source: source), isNull);
    expect(await svc.thumbFor(pdf(), source: source), isNull);
    expect(renderCalls, 2);
  });

  test('a non-PDF document is never rendered', () async {
    final result = await service().thumbFor(
      pdf(filename: 'briefing.txt'),
      source: serving(BytesData(bytes: Uint8List.fromList([1]))),
    );

    expect(result, isNull);
    expect(sourceCalls, 0);
  });

  // pdfrx's worst failure is silence: a failed engine init crashes its
  // background worker isolate, so the render future never completes and
  // nothing throws. The budget is what turns that into a placeholder rather
  // than a tile that shimmers for the life of the screen.
  test('a render that never completes yields null', () async {
    final svc = PdfThumbnailService(
      cacheDir: () async => Directory('${root.path}/cache'),
      renderBudget: const Duration(milliseconds: 20),
      renderer:
          ({
            File? file,
            Uint8List? bytes,
            int maxDimension = 512,
            int quality = 80,
          }) => Completer<Uint8List?>().future,
    );

    expect(
      await svc.thumbFor(
        pdf(),
        source: serving(BytesData(bytes: Uint8List.fromList([37, 80]))),
      ),
      isNull,
    );
  });

  // A host that cannot hand out a support directory still gets thumbnails,
  // just without the cache -- losing the picture entirely would be a worse
  // trade than re-rendering.
  test('an unusable cache directory degrades to uncached rendering', () async {
    final svc = service(
      cacheDir: () async => throw const FileSystemException('no dir'),
    );
    final source = serving(BytesData(bytes: Uint8List.fromList([37, 80])));

    expect(await svc.thumbFor(pdf(), source: source), equals(jpeg));
    expect(await svc.thumbFor(pdf(), source: source), equals(jpeg));
    expect(renderCalls, 2);
  });
}
