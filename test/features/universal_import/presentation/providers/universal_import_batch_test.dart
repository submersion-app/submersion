// Drives the notifier's multi-file batch paths end-to-end: multi-select
// picker, folder pick, drag-and-drop load, and the batch parse/merge/dedup
// flow (`confirmSource` -> `_parseBatch`) against a real in-memory database.

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/test_database.dart';

/// A fake file picker whose results are scripted by the test.
class _FakeFilePicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  List<String>? nextPickPaths;
  String? nextDirectory;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    final paths = nextPickPaths;
    if (paths == null) return null;
    return FilePickerResult([
      for (final path in paths)
        PlatformFile(path: path, name: p.basename(path), size: 0),
    ]);
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    return nextDirectory;
  }
}

/// Batch parse service that simulates the user cancelling right after the
/// first file parsed: file 0 comes back [ImportFileStatus.parsed], the rest
/// stay pending, and the payloads are NOT surfaced (mirroring the real
/// service, which discards partial payloads on cancel).
class _CancelAfterFirstParseService extends BatchParseService {
  const _CancelAfterFirstParseService();

  @override
  Future<BatchParseResult> parseAll(
    List<PickedImportFile> files, {
    void Function(int current, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final updated = [
      files.first.copyWith(status: ImportFileStatus.parsed, diveCount: 3),
      ...files.skip(1),
    ];
    return BatchParseResult(parsed: const [], files: updated, cancelled: true);
  }
}

const _uddfA = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg">
      <dive id="A1">
        <informationbeforedive><datetime>2024-01-15T10:00:00</datetime></informationbeforedive>
        <informationafterdive><greatestdepth>30.0</greatestdepth><diveduration>2400.0</diveduration></informationafterdive>
        <samples><waypoint><divetime>0.0</divetime><depth>0.0</depth></waypoint><waypoint><divetime>60.0</divetime><depth>10.0</depth></waypoint></samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

const _uddfB = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg">
      <dive id="B1">
        <informationbeforedive><datetime>2024-03-20T09:00:00</datetime></informationbeforedive>
        <informationafterdive><greatestdepth>18.0</greatestdepth><diveduration>1800.0</diveduration></informationafterdive>
        <samples><waypoint><divetime>0.0</divetime><depth>0.0</depth></waypoint><waypoint><divetime>60.0</divetime><depth>8.0</depth></waypoint></samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

void main() {
  late ProviderContainer container;
  late UniversalImportNotifier notifier;
  late _FakeFilePicker picker;
  late FilePickerPlatform originalPicker;
  late Directory tmp;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    notifier = container.read(universalImportNotifierProvider.notifier);
    originalPicker = FilePickerPlatform.instance;
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker;
    tmp = await Directory.systemTemp.createTemp('bulk_batch_test');
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    container.dispose();
    await tearDownTestDatabase();
    await tmp.delete(recursive: true);
  });

  Future<String> writeFile(String name, String contents) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsString(contents);
    return f.path;
  }

  group('pickFiles', () {
    test('single selection keeps the classic single-file flow', () async {
      final path = await writeFile('a.uddf', _uddfA);
      picker.nextPickPaths = [path];

      await notifier.pickFiles();

      expect(notifier.state.files, hasLength(1));
      expect(notifier.state.isBatch, isFalse);
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
      expect(notifier.state.fileName, 'a.uddf');
    });

    test('multi selection enters the batch triage flow', () async {
      final a = await writeFile('a.uddf', _uddfA);
      final b = await writeFile('b.uddf', _uddfB);
      picker.nextPickPaths = [a, b];

      await notifier.pickFiles();

      expect(notifier.state.isBatch, isTrue);
      expect(notifier.state.files, hasLength(2));
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
      expect(notifier.state.detectionResult, isNotNull);
    });

    test('cancelled picker leaves no files', () async {
      picker.nextPickPaths = null;
      await notifier.pickFiles();
      expect(notifier.state.files, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('confirmSource batch parse', () {
    test('parses, merges, and advances to review', () async {
      final a = await writeFile('a.uddf', _uddfA);
      final b = await writeFile('b.uddf', _uddfB);
      picker.nextPickPaths = [a, b];
      await notifier.pickFiles();

      await notifier.confirmSource();

      expect(notifier.state.currentStep, ImportWizardStep.review);
      final payload = notifier.state.payload;
      expect(payload, isNotNull);
      expect(payload!.metadata['batchFileCount'], 2);
      expect(notifier.state.duplicateResult, isNotNull);
      // Two distinct dives selected by default.
      expect(notifier.state.selectionFor(ImportEntityType.dives), hasLength(2));
    });

    test('a batch of only-excluded files ends in an error', () async {
      final a = await writeFile('a.csv', 'Date,Depth\n2024-01-01,30\n');
      final b = await writeFile('b.csv', 'Date,Depth\n2024-01-02,20\n');
      picker.nextPickPaths = [a, b];
      await notifier.pickFiles();

      await notifier.confirmSource();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.currentStep, isNot(ImportWizardStep.review));
      // Detection is cleared so the Confirm Source step's Next gate goes false
      // -- there is no payload to advance to.
      expect(notifier.state.detectionResult, isNull);
    });

    test('cancel resets already-parsed files to pending', () async {
      // Wire a service that reports file 0 parsed then a cancel. The parsed
      // payload is not retained anywhere, and parseAll skips non-pending files,
      // so leaving file 0 as "parsed" would silently drop it from a re-run.
      final prefs = await SharedPreferences.getInstance();
      final cancelContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          universalImportNotifierProvider.overrideWith(
            (ref) => UniversalImportNotifier(
              ref,
              batchParseService: const _CancelAfterFirstParseService(),
            ),
          ),
        ],
      );
      addTearDown(cancelContainer.dispose);
      final cancelNotifier = cancelContainer.read(
        universalImportNotifierProvider.notifier,
      );

      final a = await writeFile('a.uddf', _uddfA);
      final b = await writeFile('b.uddf', _uddfB);
      await cancelNotifier.loadFilesFromPaths([a, b]);
      expect(cancelNotifier.state.isBatch, isTrue);

      await cancelNotifier.confirmSource();

      // Cancel stays on the confirm/triage step and never advances to review.
      expect(
        cancelNotifier.state.currentStep,
        ImportWizardStep.sourceConfirmation,
      );
      expect(cancelNotifier.state.isLoading, isFalse);
      // No file is left in `parsed`; a re-run starts truly clean.
      expect(
        cancelNotifier.state.files.any(
          (f) => f.status == ImportFileStatus.parsed,
        ),
        isFalse,
      );
      expect(cancelNotifier.state.files.first.status, ImportFileStatus.pending);
      expect(cancelNotifier.state.files.first.diveCount, 0);
    });
  });

  group('pickFolder', () {
    test('folder with multiple importable files enters batch', () async {
      await writeFile('a.uddf', _uddfA);
      await writeFile('b.uddf', _uddfB);
      picker.nextDirectory = tmp.path;

      await notifier.pickFolder();

      expect(notifier.state.isBatch, isTrue);
      expect(notifier.state.files.length, greaterThanOrEqualTo(2));
    });

    test('folder with a single importable file is single-file flow', () async {
      await writeFile('only.uddf', _uddfA);
      picker.nextDirectory = tmp.path;

      await notifier.pickFolder();

      expect(notifier.state.isBatch, isFalse);
      expect(notifier.state.files, hasLength(1));
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
    });

    test('cancelled folder pick leaves no files', () async {
      picker.nextDirectory = null;
      await notifier.pickFolder();
      expect(notifier.state.files, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });

    test('folder with no importable files sets an error', () async {
      await writeFile('notes.txt', 'hello');
      picker.nextDirectory = tmp.path;

      await notifier.pickFolder();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.files, isEmpty);
    });
  });

  group('loadFilesFromPaths (drag-and-drop)', () {
    test('loads multiple files and marks external', () async {
      final a = await writeFile('a.uddf', _uddfA);
      final b = await writeFile('b.uddf', _uddfB);

      await notifier.loadFilesFromPaths([a, b]);

      expect(notifier.state.isBatch, isTrue);
      expect(notifier.state.wasLoadedExternally, isTrue);
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
    });
  });

  group('ZIP intake', () {
    Uint8List buildZip(Map<String, List<int>> entries) {
      final archive = Archive();
      for (final entry in entries.entries) {
        archive.addFile(
          ArchiveFile(entry.key, entry.value.length, entry.value),
        );
      }
      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    }

    List<int> zxuBytes(String start) =>
        ('FSH|^~<>{}|OCI201^^|ZXU|20240613080000|\n'
                'ZRH|^~<>{}||98765|MSWG|ThM|C|BAR|L|\n'
                'ZDH|1|1|I|Q1S|$start|28.0||FO2|\n'
                'ZDP{\n|0.00|0.0|1.00|\n|1.00|10.0|||||||||\n|2.00|0.5|||||||||\nZDP}\n'
                'ZDT|1|1|10.0|||\n')
            .codeUnits;

    test(
      'a dropped DiveCloud zip fans out into a batch with photos indexed',
      () async {
        final zipPath = '${tmp.path}/divecloud_export.zip';
        await File(zipPath).writeAsBytes(
          buildZip({
            'a_20240612093000_1.zxu': zxuBytes('20240612093000'),
            'a_20240612093000_1_photo.jpg': [1, 2, 3],
            'b_20240613100000_2.zxu': zxuBytes('20240613100000'),
          }),
        );

        await notifier.loadFilesFromPaths([zipPath]);

        final state = notifier.state;
        expect(state.files, hasLength(2));
        expect(
          state.files.every((f) => f.detection.format == ImportFormat.danDl7),
          isTrue,
        );
        expect(state.photoPathsByBaseName['a_20240612093000_1'], hasLength(1));
        expect(state.wasLoadedExternally, isTrue);
      },
    );

    test(
      'a zip with a single dive file routes to the single-file flow',
      () async {
        final zipPath = '${tmp.path}/single.zip';
        await File(
          zipPath,
        ).writeAsBytes(buildZip({'only_dive.zxu': zxuBytes('20240612093000')}));

        await notifier.loadFilesFromPaths([zipPath]);

        final state = notifier.state;
        expect(state.files, hasLength(1));
        expect(state.isBatch, isFalse);
        // Single-file flow keeps bytes in memory for the parse step.
        expect(state.fileBytes, isNotNull);
        expect(state.detectionResult?.format, ImportFormat.danDl7);
      },
    );

    test('loadFileFromBytes expands zip bytes from a share intent', () async {
      final bytes = buildZip({
        'x_1.zxu': zxuBytes('20240612093000'),
        'y_2.zxu': zxuBytes('20240613100000'),
      });

      final detection = await notifier.loadFileFromBytes(
        bytes,
        'shared_export.zip',
      );

      final state = notifier.state;
      expect(state.files, hasLength(2));
      expect(detection.format, ImportFormat.danDl7);
      expect(state.wasLoadedExternally, isTrue);
    });

    test('a zip with nothing importable reports an error', () async {
      final bytes = buildZip({
        'readme.txt': [65, 66],
      });
      final detection = await notifier.loadFileFromBytes(bytes, 'junk.zip');
      final state = notifier.state;
      expect(detection.format, ImportFormat.unknown);
      expect(state.error, contains('No importable files'));
    });

    test(
      'a later non-zip pick clears photos and deletes the prior temp dir',
      () async {
        // First import: a DiveCloud zip populates photos + a temp dir.
        final zipPath = '${tmp.path}/with_photos.zip';
        await File(zipPath).writeAsBytes(
          buildZip({
            'a_1.zxu': zxuBytes('20240612093000'),
            'a_1_photo.jpg': [1, 2, 3],
          }),
        );
        await notifier.loadFilesFromPaths([zipPath]);
        expect(notifier.state.photoPathsByBaseName, isNotEmpty);
        expect(notifier.state.zipTempDirPaths, hasLength(1));
        final tempDir = notifier.state.zipTempDirPaths.single;

        // Second import: a plain (non-zip) file via the picker. pickFiles
        // does not fully reset state, so without the fix the stale photo map
        // would linger and could be misattached to the new dive.
        final plain = await writeFile('plain.uddf', _uddfA);
        picker.nextPickPaths = [plain];
        await notifier.pickFiles();

        expect(
          notifier.state.photoPathsByBaseName,
          isEmpty,
          reason: 'the previous ZIP import\'s photos must not carry over',
        );
        expect(notifier.state.unmatchedPhotoCount, 0);
        expect(notifier.state.zipTempDirPaths, isEmpty);

        // The superseded temp dir is deleted (fire-and-forget). Allow the
        // microtask/IO to settle before asserting.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(Directory(tempDir).existsSync(), isFalse);
      },
    );

    test('reset() deletes tracked temp dirs', () async {
      final zipPath = '${tmp.path}/for_reset.zip';
      await File(
        zipPath,
      ).writeAsBytes(buildZip({'d_1.zxu': zxuBytes('20240612093000')}));
      await notifier.loadFilesFromPaths([zipPath]);
      final tempDir = notifier.state.zipTempDirPaths.single;
      expect(Directory(tempDir).existsSync(), isTrue);

      notifier.reset();

      expect(notifier.state.zipTempDirPaths, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(Directory(tempDir).existsSync(), isFalse);
    });
  });
}
