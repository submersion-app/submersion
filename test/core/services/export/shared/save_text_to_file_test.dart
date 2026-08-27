import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

/// [saveTextToFile] is the string counterpart to saveImageToFile /
/// savePdfToFile: picker-based, cancellable, returns null on cancel. Distinct
/// from saveAndShareFile, which always opens the share sheet.
void main() {
  late MockFilePickerPlatform mockPicker;
  late FilePickerPlatform originalPicker;
  late Directory tempDir;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    mockPicker = MockFilePickerPlatform();
    FilePickerPlatform.instance = mockPicker;
    tempDir = Directory.systemTemp.createTempSync('save_text_test');
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('returns null when the user cancels the picker', () async {
    mockPicker.saveFileResult = null;
    final result = await saveTextToFile(
      '<gpx/>',
      'track.gpx',
      dialogTitle: 'Save GPX',
      mimeType: 'text/plain',
    );
    expect(result, isNull);
  });

  test('returns the chosen path and writes the content', () async {
    final target = '${tempDir.path}/track.gpx';
    mockPicker.saveFileResult = Uri.file(target);

    final result = await saveTextToFile(
      '<gpx>hello</gpx>',
      'track.gpx',
      dialogTitle: 'Save GPX',
      mimeType: 'text/plain',
    );

    expect(result, target);
    expect(File(target).readAsStringSync(), '<gpx>hello</gpx>');
  });

  test('writes UTF-8 so non-ASCII track names survive', () async {
    final target = '${tempDir.path}/track.gpx';
    mockPicker.saveFileResult = Uri.file(target);

    await saveTextToFile(
      '<name>Cozumel – Palancar</name>',
      'track.gpx',
      dialogTitle: 'Save GPX',
      mimeType: 'text/plain',
    );

    expect(File(target).readAsStringSync(), '<name>Cozumel – Palancar</name>');
  });
}
