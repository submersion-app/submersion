import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/test_database.dart';

/// Records what the save dialog was asked for so tests can assert the file
/// name reaching the picker, not just the value handed back.
class _RecordingPicker extends MockFilePickerPlatform {
  String? requestedFileName;
  List<String>? requestedExtensions;
  Uint8List? offeredBytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    requestedFileName = fileName;
    requestedExtensions = allowedExtensions;
    offeredBytes = bytes;
    return saveFileResult;
  }
}

/// [PdfExportService.savePdfBytesToFile] is the seam the template-aware save
/// flow uses so the selected detail level survives to disk (#644).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingPicker picker;
  late FilePickerPlatform originalPicker;
  late Directory workDir;
  late PdfExportService service;

  setUp(() async {
    await setUpTestDatabase();
    originalPicker = FilePickerPlatform.instance;
    picker = _RecordingPicker();
    FilePickerPlatform.instance = picker;
    workDir = await Directory.systemTemp.createTemp('pdf_save_bytes_test_');
    service = PdfExportService();
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    if (await workDir.exists()) await workDir.delete(recursive: true);
    await tearDownTestDatabase();
  });

  final pdfBytes = <int>[...'%PDF-1.4'.codeUnits, 0x0A, 0x25, 0xE2, 0x0A];

  test('writes the supplied bytes to the chosen path', () async {
    final target = '${workDir.path}/dive_logbook_padiStyle_2026-01-15.pdf';
    picker.saveFileResult = target;

    final path = await service.savePdfBytesToFile(
      pdfBytes,
      'dive_logbook_padiStyle_2026-01-15.pdf',
    );

    expect(path, target);
    expect(await File(target).readAsBytes(), pdfBytes);
  });

  test('offers the caller file name and a .pdf filter to the picker', () async {
    picker.saveFileResult = '${workDir.path}/out.pdf';

    await service.savePdfBytesToFile(
      pdfBytes,
      'dive_logbook_nauiStyle_2026-01-15.pdf',
    );

    expect(
      picker.requestedFileName,
      'dive_logbook_nauiStyle_2026-01-15.pdf',
      reason: 'the template name must survive into the suggested file name',
    );
    expect(picker.requestedExtensions, ['pdf']);
    expect(picker.offeredBytes, pdfBytes);
  });

  test('returns null and writes nothing when the user cancels', () async {
    picker.saveFileResult = null;

    expect(await service.savePdfBytesToFile(pdfBytes, 'cancelled.pdf'), isNull);
    expect(workDir.listSync(), isEmpty);
  });

  test('saveDivesToPdfFile routes the generated logbook through it', () async {
    final target = '${workDir.path}/logbook.pdf';
    picker.saveFileResult = target;

    final path = await service.saveDivesToPdfFile([
      Dive(
        id: 'd1',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 15, 9),
        runtime: const Duration(minutes: 62),
        maxDepth: 25.0,
      ),
    ]);

    expect(path, target);
    expect(picker.requestedFileName, startsWith('dive_logbook_'));
    expect(picker.requestedFileName, endsWith('.pdf'));
    final written = await File(target).readAsBytes();
    expect(String.fromCharCodes(written.take(4)), '%PDF');
  });

  test(
    'ExportService.savePdfBytesToFile delegates to the PDF service',
    () async {
      final target = '${workDir.path}/facade.pdf';
      picker.saveFileResult = target;

      final path = await ExportService().savePdfBytesToFile(
        pdfBytes,
        'facade.pdf',
      );

      expect(path, target);
      expect(picker.requestedFileName, 'facade.pdf');
      expect(await File(target).readAsBytes(), pdfBytes);
    },
  );
}
