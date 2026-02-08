import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Save string content to a file and open the system share sheet.
Future<String> saveAndShareFile(
  String content,
  String fileName,
  String mimeType,
) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
    ),
  );

  return file.path;
}

/// Save raw bytes to a file and open the system share sheet.
Future<String> saveAndShareFileBytes(
  List<int> bytes,
  String fileName,
  String mimeType,
) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
    ),
  );

  return file.path;
}

/// Get temporary file path for export.
Future<String> getExportFilePath(String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  return '${directory.path}/$fileName';
}

/// Export PNG image bytes via the system share sheet.
///
/// Use this with RenderRepaintBoundary.toImage() to export widgets as images.
Future<String> exportImageAsPng(List<int> pngBytes, String fileName) async {
  return saveAndShareFileBytes(pngBytes, fileName, 'image/png');
}

/// Save an image directly to the device's photo library.
///
/// Returns the file path where the image was saved.
/// Throws an exception if saving fails.
Future<String> saveImageToPhotos(List<int> pngBytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(Uint8List.fromList(pngBytes));

  // Save to photo gallery
  await Gal.putImage(filePath, album: 'Submersion');

  // Clean up temp file
  await file.delete();

  return filePath;
}

/// Save an image to a user-selected file location.
///
/// Opens a file picker dialog allowing the user to choose where to save.
/// Returns the saved file path, or null if the user cancelled.
Future<String?> saveImageToFile(List<int> pngBytes, String fileName) async {
  final result = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Profile Image',
    fileName: fileName,
    type: FileType.image,
    bytes: Uint8List.fromList(pngBytes),
  );

  if (result == null) return null;

  // On some platforms, saveFile returns a path but doesn't write the file
  if (!Platform.isAndroid) {
    final file = File(result);
    await file.writeAsBytes(Uint8List.fromList(pngBytes));
  }

  return result;
}

/// Share PDF bytes via the system share sheet.
Future<String> sharePdfBytes(List<int> pdfBytes, String fileName) async {
  return saveAndShareFileBytes(pdfBytes, fileName, 'application/pdf');
}

/// Save PDF bytes to a user-selected file location.
///
/// Opens a file picker dialog allowing the user to choose where to save.
/// Returns the saved file path, or null if the user cancelled.
Future<String?> savePdfToFile(List<int> pdfBytes, String fileName) async {
  final result = await FilePicker.platform.saveFile(
    dialogTitle: 'Save PDF',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    bytes: Uint8List.fromList(pdfBytes),
  );

  if (result == null) return null;

  // On some platforms, saveFile returns a path but doesn't write the file
  if (!Platform.isAndroid) {
    final file = File(result);
    await file.writeAsBytes(Uint8List.fromList(pdfBytes));
  }

  return result;
}
