import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import 'media_import_service_test.mocks.dart';

void main() {
  late MockMediaRepository mockMediaRepository;
  late MockEnrichmentService mockEnrichmentService;
  late MediaImportService service;
  late Directory docsDir;
  late Directory sourceDir;

  setUp(() async {
    mockMediaRepository = MockMediaRepository();
    mockEnrichmentService = MockEnrichmentService();
    docsDir = await Directory.systemTemp.createTemp('ocr_docs');
    sourceDir = await Directory.systemTemp.createTemp('ocr_src');
    service = MediaImportService(
      mediaRepository: mockMediaRepository,
      enrichmentService: mockEnrichmentService,
      documentsDirectory: () async => docsDir,
    );
    when(mockMediaRepository.createMedia(any)).thenAnswer(
      (invocation) async => invocation.positionalArguments[0] as MediaItem,
    );
  });

  tearDown(() async {
    await docsDir.delete(recursive: true);
    await sourceDir.delete(recursive: true);
  });

  test(
    'copies file into scanned_logs and creates localFile media row',
    () async {
      final source = File('${sourceDir.path}/page.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes

      final item = await service.importLocalFileForDive(
        sourceFile: source,
        diveId: 'dive-1',
      );

      expect(item.sourceType, MediaSourceType.localFile);
      expect(item.diveId, 'dive-1');
      expect(item.mediaType, MediaType.photo);
      expect(item.filePath, contains('scanned_logs'));
      expect(item.originalFilename, 'page.jpg');
      expect(File(item.filePath!).existsSync(), isTrue);
      verify(mockMediaRepository.createMedia(any)).called(1);
    },
  );

  test('extensionless source defaults to .jpg', () async {
    final source = File('${sourceDir.path}/scan')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

    final item = await service.importLocalFileForDive(
      sourceFile: source,
      diveId: 'dive-2',
    );

    expect(item.filePath, endsWith('.jpg'));
  });
  group('coordinates and destination', () {
    test(
      'stores coordinates and writes into the requested subdirectory',
      () async {
        final source = File('${sourceDir.path}/photo.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

        final item = await service.importLocalFileForDive(
          sourceFile: source,
          diveId: 'dive-1',
          takenAt: DateTime.utc(2025, 1, 15, 10, 3, 20),
          latitude: 18.465562,
          longitude: -66.084902,
          subdirectory: 'imported_photos',
        );

        expect(item.latitude, closeTo(18.465562, 1e-6));
        expect(item.longitude, closeTo(-66.084902, 1e-6));
        expect(item.takenAt, DateTime.utc(2025, 1, 15, 10, 3, 20));
        expect(item.filePath, contains('imported_photos'));
        expect(item.filePath, isNot(contains('scanned_logs')));
      },
    );

    test('defaults to scanned_logs with no coordinates', () async {
      final source = File('${sourceDir.path}/scan2.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

      final item = await service.importLocalFileForDive(
        sourceFile: source,
        diveId: 'dive-1',
      );

      expect(item.latitude, isNull);
      expect(item.longitude, isNull);
      expect(item.filePath, contains('scanned_logs'));
    });

    test('a rapid batch never overwrites an earlier copy', () async {
      // Twenty copies in a tight loop reliably land several inside the same
      // millisecond, which is the case the counter suffix exists for.
      final paths = <String>{};
      for (var i = 0; i < 20; i++) {
        final source = File('${sourceDir.path}/batch$i.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF, i]);
        final item = await service.importLocalFileForDive(
          sourceFile: source,
          diveId: 'dive-1',
          subdirectory: 'imported_photos',
        );
        paths.add(item.filePath!);
        // Each copy must hold its OWN bytes, not a later one's.
        expect(File(item.filePath!).readAsBytesSync().last, i);
      }
      expect(paths, hasLength(20));
    });

    test('two photos imported back to back get distinct paths', () async {
      final a = File('${sourceDir.path}/a.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
      final b = File('${sourceDir.path}/b.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE1]);

      final first = await service.importLocalFileForDive(
        sourceFile: a,
        diveId: 'dive-1',
        subdirectory: 'imported_photos',
      );
      final second = await service.importLocalFileForDive(
        sourceFile: b,
        diveId: 'dive-1',
        subdirectory: 'imported_photos',
      );

      expect(first.filePath, isNot(second.filePath));
      expect(File(first.filePath!).existsSync(), isTrue);
      expect(File(second.filePath!).existsSync(), isTrue);
      // The first copy must still hold its own bytes, not the second's.
      expect(File(first.filePath!).readAsBytesSync().last, 0xE0);
      expect(File(second.filePath!).readAsBytesSync().last, 0xE1);
    });
  });
}
