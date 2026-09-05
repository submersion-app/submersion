import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Whether the running platform's share sheet can carry files.
///
/// share_plus has no file sharing on Linux: its backend there is a `mailto:`
/// launcher whose `share` throws `UnimplementedError` as soon as
/// [ShareParams.files] is non-empty. Every helper in this file shares files,
/// so on Linux each export wrote its file into the documents directory and
/// then appeared to do nothing at all -- the throw only ever reached the log.
///
/// Where the sheet cannot take files the share helpers fall back to the same
/// save dialog the `save*ToFile` helpers use, which is the destination a
/// desktop user expects anyway.
bool get canShareFiles => _canShareFilesOverride ?? !Platform.isLinux;

bool? _canShareFilesOverride;

/// Pin [canShareFiles] for a test; null restores the platform default.
///
/// The gate reads the host platform, so without this the share-sheet tests
/// take the save-dialog branch whenever the suite runs on Linux, and the
/// save-dialog tests pass for the wrong reason everywhere else.
@visibleForTesting
set debugCanShareFiles(bool? value) => _canShareFilesOverride = value;

/// Save string content and hand it to the system share sheet, or to the save
/// dialog where [canShareFiles] is false.
///
/// This is the "share" half of the export idiom. Callers that want the user to
/// pick a destination on every platform should use the matching `save*ToFile`
/// helper instead -- those return `null` when the save dialog is cancelled,
/// which this function has no way to express.
///
/// [sharePositionOrigin] is the screen rect the iPad share popover points at,
/// normally from `shareAnchorFrom` on the button's context. It is optional
/// because not every caller can name a control: the settings export chain runs
/// several service layers below the widget that started it, and dismisses its
/// format picker before sharing. Null means "let the platform decide", which
/// share_plus honours by centring the popover.
Future<String> saveAndShareFile(
  String content,
  String fileName,
  String mimeType, {
  Rect? sharePositionOrigin,
}) => _shareOrSave(
  Uint8List.fromList(utf8.encode(content)),
  fileName,
  mimeType,
  sharePositionOrigin: sharePositionOrigin,
);

/// Save raw bytes and hand them to the system share sheet, or to the save
/// dialog where [canShareFiles] is false.
///
/// See [saveAndShareFile] for why this never reports a cancelled dialog, and
/// for what [sharePositionOrigin] is and when it is null.
Future<String> saveAndShareFileBytes(
  List<int> bytes,
  String fileName,
  String mimeType, {
  Rect? sharePositionOrigin,
}) => _shareOrSave(
  Uint8List.fromList(bytes),
  fileName,
  mimeType,
  sharePositionOrigin: sharePositionOrigin,
);

Future<String> _shareOrSave(
  Uint8List bytes,
  String fileName,
  String mimeType, {
  Rect? sharePositionOrigin,
}) async {
  if (!canShareFiles) return _saveViaDialog(bytes, fileName, mimeType);

  // The sheet takes a file, not bytes, so the export has to exist on disk
  // before it opens.
  final path = await _writeToDocuments(bytes, fileName);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: mimeType)],
      subject: fileName,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );

  return path;
}

/// The share sheet's stand-in: let the user choose where the export lands.
///
/// [FilePicker.saveFile] writes the bytes itself, so nothing is written to the
/// documents directory first -- doing both would leave a stray copy of every
/// export behind. Cancelling picks no destination but does not throw the
/// export away: the bytes are already built and callers are promised a path,
/// so the file lands where the share path would have left it.
Future<String> _saveViaDialog(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final saved = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );

  if (saved != null) return savedFileLocation(saved);
  return _writeToDocuments(bytes, fileName);
}

Future<String> _writeToDocuments(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
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
Future<String> exportImageAsPng(
  List<int> pngBytes,
  String fileName, {
  Rect? sharePositionOrigin,
}) async {
  return saveAndShareFileBytes(
    pngBytes,
    fileName,
    'image/png',
    sharePositionOrigin: sharePositionOrigin,
  );
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

/// A user-visible location for a file [FilePicker.saveFile] has just written.
///
/// file_picker 12 writes the bytes itself on every platform and returns a
/// [Uri] whose scheme varies: `file` on the desktops and iOS, `content` for an
/// Android SAF document. Only a `file` Uri can become a filesystem path, so
/// anything else is surfaced as the Uri string. Callers use this purely for
/// display and for "reveal in folder" affordances, never to re-open the file.
String savedFileLocation(Uri uri) =>
    uri.isScheme('file') ? uri.toFilePath() : uri.toString();

/// Save an image to a user-selected file location.
///
/// Opens a file picker dialog allowing the user to choose where to save.
/// Returns the saved file location, or null if the user cancelled.
Future<String?> saveImageToFile(List<int> pngBytes, String fileName) async {
  final result = await FilePicker.saveFile(
    dialogTitle: 'Save Profile Image',
    fileName: fileName,
    type: FileType.image,
    bytes: Uint8List.fromList(pngBytes),
    mimeType: 'image/png',
  );

  if (result == null) return null;
  return savedFileLocation(result);
}

/// Share PDF bytes via the system share sheet.
Future<String> sharePdfBytes(
  List<int> pdfBytes,
  String fileName, {
  Rect? sharePositionOrigin,
}) async {
  return saveAndShareFileBytes(
    pdfBytes,
    fileName,
    'application/pdf',
    sharePositionOrigin: sharePositionOrigin,
  );
}

/// Save string content to a user-selected file location.
///
/// Opens a file picker dialog allowing the user to choose where to save.
/// Returns the saved file path, or null if the user cancelled.
///
/// The string counterpart to [savePdfToFile]. Deliberately distinct from
/// [saveAndShareFile], which always opens the share sheet and cannot be
/// cancelled - a "Save to..." menu item needs this one.
Future<String?> saveTextToFile(
  String content,
  String fileName, {
  required String dialogTitle,
  required String mimeType,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final result = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    bytes: bytes,
    mimeType: mimeType,
  );

  if (result == null) return null;
  return savedFileLocation(result);
}

/// Save PDF bytes to a user-selected file location.
///
/// Opens a file picker dialog allowing the user to choose where to save.
/// Returns the saved file path, or null if the user cancelled.
Future<String?> savePdfToFile(List<int> pdfBytes, String fileName) async {
  final result = await FilePicker.saveFile(
    dialogTitle: 'Save PDF',
    fileName: fileName,
    type: FileType.custom,
    bytes: Uint8List.fromList(pdfBytes),
    mimeType: 'application/pdf',
  );

  if (result == null) return null;
  return savedFileLocation(result);
}
