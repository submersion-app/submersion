import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

/// share_plus has no file sharing on Linux: `share` throws UnimplementedError
/// the moment ShareParams.files is non-empty. Every helper in
/// file_export_utils shares files, so before the fallback each export menu
/// item wrote its file into the documents directory and then appeared to do
/// nothing -- the throw only ever reached the log.
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
  late Directory chosen;
  late MockFilePickerPlatform picker;
  late FilePickerPlatform originalPicker;
  final sharePlatform = _FakeSharePlatform();

  setUpAll(() => SharePlatform.instance = sharePlatform);

  setUp(() {
    documents = Directory.systemTemp.createTempSync('share_fallback_docs');
    chosen = Directory.systemTemp.createTempSync('share_fallback_chosen');
    PathProviderPlatform.instance = _FakePathProvider(documents.path);
    originalPicker = FilePickerPlatform.instance;
    picker = MockFilePickerPlatform();
    FilePickerPlatform.instance = picker;
    sharePlatform.calls.clear();
    debugCanShareFiles = false;
  });

  tearDown(() {
    debugCanShareFiles = true;
    FilePickerPlatform.instance = originalPicker;
    documents.deleteSync(recursive: true);
    chosen.deleteSync(recursive: true);
  });

  group('without a file-capable share sheet', () {
    test('saveAndShareFile saves through the dialog, not the sheet', () async {
      final target = '${chosen.path}/dives.uddf';
      picker.saveFileResult = Uri.file(target);

      final path = await saveAndShareFile(
        '<uddf/>',
        'dives.uddf',
        'application/xml',
      );

      expect(path, target);
      expect(File(target).readAsStringSync(), '<uddf/>');
      expect(sharePlatform.calls, isEmpty);
      expect(picker.lastSavedFileName, 'dives.uddf');
    });

    test('saveAndShareFileBytes saves through the dialog', () async {
      final target = '${chosen.path}/dives.xlsx';
      picker.saveFileResult = Uri.file(target);

      final path = await saveAndShareFileBytes(
        [1, 2, 3],
        'dives.xlsx',
        'application/vnd.ms-excel',
        sharePositionOrigin: const Rect.fromLTWH(1, 2, 3, 4),
      );

      expect(path, target);
      expect(File(target).readAsBytesSync(), [1, 2, 3]);
      expect(sharePlatform.calls, isEmpty);
    });

    test('sharePdfBytes reaches the dialog as a PDF', () async {
      picker.saveFileResult = Uri.file('${chosen.path}/logbook.pdf');

      await sharePdfBytes([4, 5, 6], 'logbook.pdf');

      expect(picker.lastSavedFileName, 'logbook.pdf');
      expect(picker.lastSavedBytes, [4, 5, 6]);
    });

    test('a chosen destination leaves no copy in the documents dir', () async {
      // The share path writes into the documents directory because the sheet
      // needs a file to hand over. The dialog writes the bytes itself, so
      // doing both would litter the user's Documents with every export.
      picker.saveFileResult = Uri.file('${chosen.path}/dives.uddf');

      await saveAndShareFile('<uddf/>', 'dives.uddf', 'application/xml');

      expect(documents.listSync(), isEmpty);
    });

    test('cancelling keeps the export in the documents dir', () async {
      // Callers promise a path and the bytes are already built, so a cancelled
      // destination dialog must not throw the work away.
      picker.saveFileResult = null;

      final path = await saveAndShareFile(
        '<uddf>kept</uddf>',
        'dives.uddf',
        'application/xml',
      );

      expect(path, '${documents.path}/dives.uddf');
      expect(File(path).readAsStringSync(), '<uddf>kept</uddf>');
    });

    test('non-ASCII content survives the dialog as UTF-8', () async {
      final target = '${chosen.path}/sites.kml';
      picker.saveFileResult = Uri.file(target);

      await saveAndShareFile(
        '<name>Cozumel – Palancar</name>',
        'sites.kml',
        'application/vnd.google-earth.kml+xml',
      );

      expect(
        File(target).readAsStringSync(),
        '<name>Cozumel – Palancar</name>',
      );
    });
  });

  group('with a file-capable share sheet', () {
    setUp(() => debugCanShareFiles = true);

    test('the sheet is used and the dialog is left alone', () async {
      final path = await saveAndShareFile(
        '<uddf/>',
        'dives.uddf',
        'application/xml',
      );

      expect(path, '${documents.path}/dives.uddf');
      expect(sharePlatform.calls.single.subject, 'dives.uddf');
      expect(picker.lastSavedFileName, isNull);
    });
  });
}
