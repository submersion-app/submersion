import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:submersion/core/platform/file_saver.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

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
bool get canShareFiles => _canShareFilesOverride ?? !HostPlatform.isLinux;

bool? _canShareFilesOverride;

/// Pin [canShareFiles] for a test; null restores the platform default.
///
/// The gate reads the host platform, so without this the share-sheet tests
/// take the save-dialog branch whenever the suite runs on Linux, and the
/// save-dialog tests pass for the wrong reason everywhere else.
@visibleForTesting
set debugCanShareFiles(bool? value) => _canShareFilesOverride = value;

/// Stands in for the browser download on the VM, so the routing can be
/// tested where there is no page; null restores the platform path.
@visibleForTesting
Future<String> Function(Uint8List bytes, String fileName, String mimeType)?
debugBrowserDownload;

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
}) async {
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.share);
  return _shareOrSave(
    Uint8List.fromList(utf8.encode(content)),
    fileName,
    mimeType,
    sharePositionOrigin: sharePositionOrigin,
  );
}

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
}) async {
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.share);
  return _shareOrSave(
    Uint8List.fromList(bytes),
    fileName,
    mimeType,
    sharePositionOrigin: sharePositionOrigin,
  );
}

Future<String> _shareOrSave(
  Uint8List bytes,
  String fileName,
  String mimeType, {
  Rect? sharePositionOrigin,
}) async {
  final download = debugBrowserDownload;
  if (download != null) return download(bytes, fileName, mimeType);
  // A page has no share sheet, no documents directory and no save dialog:
  // its export is a download (issue #4121).
  if (HostPlatform.isWeb) {
    await FileSaver.saveBytes(bytes, fileName: fileName, mimeType: mimeType);
    return fileName;
  }
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

/// [saveAndShareFile] for an export already written to [built], which it
/// moves out of the way: into the documents directory, where the share sheet
/// takes it, or into the location picked in the save dialog where
/// [canShareFiles] is false.
///
/// The share sheet reads the file from disk, so a large export is never
/// held in memory to share (issue #4249). The save dialog takes only bytes,
/// so there it is read back once. As with [saveAndShareFile], a cancelled
/// dialog leaves the file in the documents directory, and the result is
/// always a path.
Future<String> saveAndShareExportFile(
  File built,
  String fileName,
  String mimeType, {
  Rect? sharePositionOrigin,
}) async {
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.share);
  if (!canShareFiles) {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: await built.readAsBytes(),
      mimeType: mimeType,
    );
    if (saved != null) return savedFileLocation(saved);
  }
  final path = await _moveToDocuments(built, fileName);
  if (canShareFiles) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mimeType)],
        subject: fileName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
  return path;
}

/// [file] moved to [fileName] in the documents directory, replacing what
/// was there; copied when the two are on different volumes.
Future<String> _moveToDocuments(File file, String fileName) async {
  final target = await getExportFilePath(fileName);
  try {
    return (await file.rename(target)).path;
  } on FileSystemException {
    await file.copy(target);
    await file.delete();
    return target;
  }
}

/// Hand a file that already exists at [path] to the share sheet, or to the
/// save dialog where [canShareFiles] is false.
///
/// Unlike [saveAndShareFileBytes] nothing is copied into the documents
/// directory first, so an export built in temp space (an encrypted documents
/// archive) leaves no lasting copy behind. Returns the shared path, the saved
/// location, or null when the sheet is dismissed or the dialog cancelled.
Future<String?> shareFileAtPath(
  String path,
  String fileName,
  String mimeType, {
  required String dialogTitle,
  Rect? sharePositionOrigin,
}) async {
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.share);
  if (!canShareFiles) {
    return saveBytesToFile(
      await File(path).readAsBytes(),
      fileName,
      dialogTitle: dialogTitle,
      mimeType: mimeType,
    );
  }
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: mimeType, name: fileName)],
      subject: fileName,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
  return result.status == ShareResultStatus.dismissed ? null : path;
}

Future<String> _writeToDocuments(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Get temporary file path for export.
Future<String> getExportFilePath(String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  return p.join(directory.path, fileName);
}

/// Export PNG image bytes via the system share sheet.
///
/// Use this with RenderRepaintBoundary.toImage() to export widgets as images.
Future<String> exportImageAsPng(
  List<int> pngBytes,
  String fileName, {
  Rect? sharePositionOrigin,
}) async {
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.export);
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
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.export);
  final directory = await getApplicationDocumentsDirectory();
  final filePath = p.join(directory.path, fileName);
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
/// [dialogTitle] names what is being saved; the default is the dive profile
/// image, its first caller.
Future<String?> saveImageToFile(
  List<int> pngBytes,
  String fileName, {
  String dialogTitle = 'Save Profile Image',
}) async {
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.export);
  final result = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
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
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.share);
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
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.export);
  return saveBytesToFile(
    utf8.encode(content),
    fileName,
    dialogTitle: dialogTitle,
    mimeType: mimeType,
  );
}

/// Save raw bytes to a user-selected file location.
///
/// Opens a file picker dialog allowing the user to choose where to save.
/// Returns the saved file location, or null if the user cancelled.
///
/// The general form of [saveTextToFile] and [savePdfToFile], for callers that
/// deliver several file types through one path and so cannot pick a typed
/// helper up front.
Future<String?> saveBytesToFile(
  List<int> bytes,
  String fileName, {
  required String dialogTitle,
  required String mimeType,
}) async {
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.export);
  final result = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
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
  DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.export);
  return saveBytesToFile(
    pdfBytes,
    fileName,
    dialogTitle: 'Save PDF',
    mimeType: 'application/pdf',
  );
}
