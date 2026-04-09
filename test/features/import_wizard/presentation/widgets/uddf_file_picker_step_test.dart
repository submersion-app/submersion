import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_parser_service.dart';
import 'package:submersion/features/import_wizard/data/adapters/uddf_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/uddf_file_picker_step.dart';

import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Mock FilePicker
// ---------------------------------------------------------------------------

class _MockFilePicker extends FilePicker {
  FilePickerResult? mockResult;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return mockResult;
  }
}

// ---------------------------------------------------------------------------
// Fake UddfParserService
// ---------------------------------------------------------------------------

class _FakeUddfParserService extends UddfParserService {
  _FakeUddfParserService() : super(ExportService());

  UddfImportResult? resultToReturn;
  Exception? exceptionToThrow;

  @override
  Future<UddfImportResult> parseContent(String uddfContent) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return resultToReturn ?? const UddfImportResult();
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _buildTestWidget({
  required UddfParserService parser,
  required void Function(UddfImportResult) onDataParsed,
}) {
  return testApp(
    child: SizedBox(
      height: 600,
      child: UddfFilePickerStep(parser: parser, onDataParsed: onDataParsed),
    ),
  );
}

/// Tap the Select File button and allow async operations (file I/O, parser)
/// to complete, then pump the widget tree to reflect the state change.
Future<void> _tapAndSettle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Select File'));
    // Allow real async operations (file I/O, parser) to complete.
    // Multiple delays to flush the microtask queue.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  late _MockFilePicker mockFilePicker;
  late _FakeUddfParserService fakeParser;

  setUp(() {
    mockFilePicker = _MockFilePicker();
    FilePicker.platform = mockFilePicker;
    fakeParser = _FakeUddfParserService();
  });

  group('UddfFilePickerStep', () {
    testWidgets('renders initial empty state with Select File button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select File'), findsOneWidget);
      expect(find.text('No file loaded'), findsOneWidget);
      expect(
        find.text('Select a .uddf or .xml file to import dive data.'),
        findsOneWidget,
      );
      // file_open icon appears in both the button and the empty state
      expect(find.byIcon(Icons.file_open), findsWidgets);
    });

    testWidgets('button is enabled in initial state', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows empty state when file picker is cancelled', (
      tester,
    ) async {
      mockFilePicker.mockResult = null;

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      // Still shows empty state
      expect(find.text('No file loaded'), findsOneWidget);
      expect(find.text('Select File'), findsOneWidget);
    });

    testWidgets('shows empty state when file picker returns empty list', (
      tester,
    ) async {
      mockFilePicker.mockResult = const FilePickerResult([]);

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(find.text('No file loaded'), findsOneWidget);
    });

    testWidgets('shows error for non-UDDF file extension', (tester) async {
      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(name: 'data.txt', size: 100),
      ]);

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(find.text('Please select a UDDF or XML file'), findsOneWidget);
    });

    testWidgets('shows error for file with null path', (tester) async {
      // PlatformFile with .uddf extension but no path
      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(name: 'dives.uddf', size: 100),
      ]);

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(find.text('Could not access file'), findsOneWidget);
    });

    testWidgets('successfully parses UDDF file and shows summary', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('uddf_test_');
      final tempFile = File('${tempDir.path}/test_dives.uddf');
      tempFile.writeAsStringSync('<uddf>test content</uddf>');

      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'test_dives.uddf',
          size: tempFile.lengthSync(),
          path: tempFile.path,
        ),
      ]);

      fakeParser.resultToReturn = const UddfImportResult(
        dives: [
          {'dateTime': 'test'},
          {'dateTime': 'test2'},
          {'dateTime': 'test3'},
        ],
        sites: [
          {'name': 'Reef'},
        ],
      );

      UddfImportResult? capturedData;
      await tester.pumpWidget(
        _buildTestWidget(
          parser: fakeParser,
          onDataParsed: (data) => capturedData = data,
        ),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(find.text('File parsed successfully'), findsOneWidget);
      expect(find.text('4 items found'), findsOneWidget);
      expect(find.text('3 dives, 1 sites'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Verify callback was called with data including source filename
      expect(capturedData, isNotNull);
      expect(capturedData!.sourceFileName, equals('test_dives.uddf'));
    });

    testWidgets('shows error when parser throws UddfParseException', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('uddf_test_');
      final tempFile = File('${tempDir.path}/bad.uddf');
      tempFile.writeAsStringSync('bad content');

      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'bad.uddf',
          size: tempFile.lengthSync(),
          path: tempFile.path,
        ),
      ]);

      fakeParser.exceptionToThrow = const UddfParseException(
        'Invalid UDDF structure',
      );

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(find.text('Invalid UDDF structure'), findsOneWidget);
    });

    testWidgets('shows generic error when parser throws unexpected exception', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('uddf_test_');
      final tempFile = File('${tempDir.path}/crash.uddf');
      tempFile.writeAsStringSync('crash content');

      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'crash.uddf',
          size: tempFile.lengthSync(),
          path: tempFile.path,
        ),
      ]);

      fakeParser.exceptionToThrow = Exception('disk read error');

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(find.textContaining('Failed to parse file:'), findsOneWidget);
    });

    testWidgets('allows .xml extension', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('uddf_test_');
      final tempFile = File('${tempDir.path}/dives.xml');
      tempFile.writeAsStringSync('<uddf>xml content</uddf>');

      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'dives.xml',
          size: tempFile.lengthSync(),
          path: tempFile.path,
        ),
      ]);

      fakeParser.resultToReturn = const UddfImportResult(
        dives: [
          {'dateTime': 'test'},
        ],
      );

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(find.text('File parsed successfully'), findsOneWidget);
    });

    testWidgets(
      'sets uddfAdapterCanAdvanceProvider to true on non-empty result',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync('uddf_test_');
        final tempFile = File('${tempDir.path}/advance.uddf');
        tempFile.writeAsStringSync('<uddf/>');

        addTearDown(() {
          tempDir.deleteSync(recursive: true);
        });

        mockFilePicker.mockResult = FilePickerResult([
          PlatformFile(
            name: 'advance.uddf',
            size: tempFile.lengthSync(),
            path: tempFile.path,
          ),
        ]);

        fakeParser.resultToReturn = const UddfImportResult(
          dives: [
            {'dateTime': 'test'},
          ],
        );

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 600,
                  child: Consumer(
                    builder: (context, ref, _) {
                      capturedRef = ref;
                      return UddfFilePickerStep(
                        parser: fakeParser,
                        onDataParsed: (_) {},
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially false
        expect(capturedRef.read(uddfAdapterCanAdvanceProvider), isFalse);

        await _tapAndSettle(tester);

        // After successful parse with data, should be true
        expect(capturedRef.read(uddfAdapterCanAdvanceProvider), isTrue);
      },
    );

    testWidgets('sets uddfAdapterCanAdvanceProvider to false on empty result', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('uddf_test_');
      final tempFile = File('${tempDir.path}/empty.uddf');
      tempFile.writeAsStringSync('<uddf/>');

      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'empty.uddf',
          size: tempFile.lengthSync(),
          path: tempFile.path,
        ),
      ]);

      fakeParser.resultToReturn = const UddfImportResult();

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return UddfFilePickerStep(
                      parser: fakeParser,
                      onDataParsed: (_) {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      expect(capturedRef.read(uddfAdapterCanAdvanceProvider), isFalse);
    });

    testWidgets('shows summary text from UddfImportResult', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('uddf_test_');
      final tempFile = File('${tempDir.path}/mixed.uddf');
      tempFile.writeAsStringSync('<uddf/>');

      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      mockFilePicker.mockResult = FilePickerResult([
        PlatformFile(
          name: 'mixed.uddf',
          size: tempFile.lengthSync(),
          path: tempFile.path,
        ),
      ]);

      fakeParser.resultToReturn = const UddfImportResult(
        dives: [
          {'dateTime': 'a'},
          {'dateTime': 'b'},
        ],
        buddies: [
          {'name': 'Bob'},
        ],
        equipment: [
          {'name': 'BCD'},
          {'name': 'Reg'},
        ],
      );

      await tester.pumpWidget(
        _buildTestWidget(parser: fakeParser, onDataParsed: (_) {}),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester);

      // summary from UddfImportResult: "2 dives, 2 equipment, 1 buddies"
      expect(find.text('2 dives, 2 equipment, 1 buddies'), findsOneWidget);
      // totalItems = 2 + 2 + 1 = 5
      expect(find.text('5 items found'), findsOneWidget);
    });
  });
}
