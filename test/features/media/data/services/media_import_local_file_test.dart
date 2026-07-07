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
}
