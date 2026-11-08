import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';

import '../../../../helpers/fake_path_provider.dart';
import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/mock_file_picker_platform.dart';

/// Issue #4249: the full UDDF backup is written to a file as it is built,
/// so it is handed on as that file rather than as a string held in memory.
/// It goes where [saveAndShareFile] would have put the same text.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  late Directory documents;
  late Directory work;
  late Directory chosen;
  late MockFilePickerPlatform picker;
  late FilePickerPlatform originalPicker;
  final sharePlatform = _FakeSharePlatform();
  late SharePlatform originalSharePlatform;

  setUpAll(() {
    originalSharePlatform = SharePlatform.instance;
    SharePlatform.instance = sharePlatform;
  });
  tearDownAll(() => SharePlatform.instance = originalSharePlatform);

  setUp(() {
    documents = Directory.systemTemp.createTempSync('export_file_docs');
    work = Directory.systemTemp.createTempSync('export_file_work');
    chosen = Directory.systemTemp.createTempSync('export_file_chosen');
    useFakePathProvider(_FakePathProvider(documents.path));
    originalPicker = FilePickerPlatform.instance;
    picker = MockFilePickerPlatform();
    FilePickerPlatform.instance = picker;
    sharePlatform.calls.clear();
  });

  tearDown(() {
    applyGlobalTestDefaults();
    FilePickerPlatform.instance = originalPicker;
    for (final dir in [documents, work, chosen]) {
      dir.deleteSync(recursive: true);
    }
  });

  File built(String text) =>
      File(p.join(work.path, 'built.uddf'))..writeAsStringSync(text);

  group('with a file-capable share sheet', () {
    setUp(() => debugCanShareFiles = true);

    test('moves the file into the documents dir and shares it', () async {
      final file = built('<uddf>shared</uddf>');

      final path = await saveAndShareExportFile(
        file,
        'backup.uddf',
        'application/xml',
      );

      expect(path, p.join(documents.path, 'backup.uddf'));
      expect(File(path).readAsStringSync(), '<uddf>shared</uddf>');
      expect(file.existsSync(), isFalse);
      expect(sharePlatform.calls.single.files!.single.path, path);
      expect(sharePlatform.calls.single.subject, 'backup.uddf');
      expect(picker.lastSavedFileName, isNull);
    });

    test('replaces an earlier export of the same name', () async {
      File(p.join(documents.path, 'backup.uddf')).writeAsStringSync('old');

      final path = await saveAndShareExportFile(
        built('<uddf>new</uddf>'),
        'backup.uddf',
        'application/xml',
      );

      expect(File(path).readAsStringSync(), '<uddf>new</uddf>');
    });
  });

  group('without a file-capable share sheet', () {
    setUp(() => debugCanShareFiles = false);

    test('saves the file through the dialog, not the sheet', () async {
      final target = p.join(chosen.path, 'backup.uddf');
      picker.saveFileResult = Uri.file(target);

      final file = built('<name>Mañana Reef ü</name>');
      final path = await saveAndShareExportFile(
        file,
        'backup.uddf',
        'application/xml',
      );

      expect(path, target);
      expect(File(target).readAsStringSync(), '<name>Mañana Reef ü</name>');
      expect(picker.lastSavedFileName, 'backup.uddf');
      expect(sharePlatform.calls, isEmpty);
      expect(documents.listSync(), isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test('cancelling keeps the export in the documents dir', () async {
      picker.saveFileResult = null;

      final path = await saveAndShareExportFile(
        built('<uddf>kept</uddf>'),
        'backup.uddf',
        'application/xml',
      );

      expect(path, p.join(documents.path, 'backup.uddf'));
      expect(File(path).readAsStringSync(), '<uddf>kept</uddf>');
      expect(sharePlatform.calls, isEmpty);
    });
  });
}
