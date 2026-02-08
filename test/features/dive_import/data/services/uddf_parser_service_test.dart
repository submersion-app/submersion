import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_parser_service.dart';

@GenerateMocks([ExportService])
import 'uddf_parser_service_test.mocks.dart';

void main() {
  late MockExportService mockExportService;
  late UddfParserService parserService;

  setUp(() {
    mockExportService = MockExportService();
    parserService = UddfParserService(mockExportService);
  });

  group('UddfParserService', () {
    group('validExtensions', () {
      test('accepts uddf extension', () {
        expect(UddfParserService.validExtensions.contains('uddf'), isTrue);
      });

      test('accepts xml extension', () {
        expect(UddfParserService.validExtensions.contains('xml'), isTrue);
      });
    });

    group('parseFile', () {
      test('rejects invalid file extension', () async {
        expect(
          () => parserService.parseFile('/path/to/file.txt'),
          throwsA(
            isA<UddfParseException>().having(
              (e) => e.message,
              'message',
              'Please select a UDDF or XML file',
            ),
          ),
        );
      });

      test('rejects json extension', () async {
        expect(
          () => parserService.parseFile('/path/to/file.json'),
          throwsA(isA<UddfParseException>()),
        );
      });

      test('rejects file with no extension', () async {
        // 'myfile' split by '.' gives ['myfile'], last is 'myfile'
        expect(
          () => parserService.parseFile('/path/to/myfile'),
          throwsA(isA<UddfParseException>()),
        );
      });

      test('throws when file does not exist', () async {
        expect(
          () => parserService.parseFile('/nonexistent/path/to/file.uddf'),
          throwsA(
            isA<UddfParseException>().having(
              (e) => e.message,
              'message',
              'File not found',
            ),
          ),
        );
      });

      test('parses valid uddf file', () async {
        // Create a temp file with UDDF content
        final tempDir = await Directory.systemTemp.createTemp('uddf_test_');
        final tempFile = File('${tempDir.path}/test.uddf');
        await tempFile.writeAsString('<uddf/>');

        when(
          mockExportService.importAllDataFromUddf('<uddf/>'),
        ).thenAnswer((_) async => const UddfImportResult());

        final result = await parserService.parseFile(tempFile.path);
        expect(result, isNotNull);
        expect(result.dives, isEmpty);

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('accepts xml extension', () async {
        final tempDir = await Directory.systemTemp.createTemp('uddf_test_');
        final tempFile = File('${tempDir.path}/test.xml');
        await tempFile.writeAsString('<uddf/>');

        when(
          mockExportService.importAllDataFromUddf('<uddf/>'),
        ).thenAnswer((_) async => const UddfImportResult());

        final result = await parserService.parseFile(tempFile.path);
        expect(result, isNotNull);

        await tempDir.delete(recursive: true);
      });

      test('extension check is case-insensitive', () async {
        final tempDir = await Directory.systemTemp.createTemp('uddf_test_');
        final tempFile = File('${tempDir.path}/test.UDDF');
        await tempFile.writeAsString('<uddf/>');

        when(
          mockExportService.importAllDataFromUddf('<uddf/>'),
        ).thenAnswer((_) async => const UddfImportResult());

        final result = await parserService.parseFile(tempFile.path);
        expect(result, isNotNull);

        await tempDir.delete(recursive: true);
      });
    });

    group('parseContent', () {
      test('delegates to ExportService', () async {
        const content = '<uddf>test</uddf>';
        final expectedResult = UddfImportResult(
          dives: [
            {'dateTime': DateTime(2024), 'maxDepth': 25.0},
          ],
        );

        when(
          mockExportService.importAllDataFromUddf(content),
        ).thenAnswer((_) async => expectedResult);

        final result = await parserService.parseContent(content);
        expect(result.dives, hasLength(1));
        verify(mockExportService.importAllDataFromUddf(content)).called(1);
      });
    });
  });

  group('UddfParseException', () {
    test('toString includes message', () {
      const exception = UddfParseException('test error');
      expect(exception.toString(), 'UddfParseException: test error');
    });

    test('message is accessible', () {
      const exception = UddfParseException('something broke');
      expect(exception.message, 'something broke');
    });
  });
}
