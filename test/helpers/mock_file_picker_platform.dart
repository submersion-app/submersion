import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
// file_picker 12 moved the platform interface into its own package and made it
// public, so the old `file_picker/src/...` import is gone. Re-exported here so
// test files keep depending only on this helper.
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Exported wholesale rather than with a `show`: test fakes must reproduce the
// platform signatures exactly, which now mention the per-platform option
// classes (AndroidOptions, WindowsOptions, LinuxOptions, WebOptions).
export 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// A [PlatformFile] backed by a real file on disk.
///
/// file_picker 12 turned [PlatformFile] into an abstract handle and ships no
/// constructible implementation, so tests need their own. Reading goes through
/// the real file, which keeps the fake honest: a test that hands back a path
/// it never wrote will fail the same way production would.
final class FakePlatformFile extends PlatformFile {
  FakePlatformFile(String path, {String? name})
    : uri = Uri.file(path),
      name = name ?? path.split(Platform.pathSeparator).last,
      _bytes = null;

  /// A pick with no local file, the way an Android SAF `content://` result
  /// arrives: [path] is null and only the handle can read it.
  FakePlatformFile.contentUri(this.uri, {required this.name, Uint8List? bytes})
    : _bytes = bytes;

  @override
  final String name;

  @override
  final Uri uri;

  final Uint8List? _bytes;

  @override
  XFile get xFile => path != null
      ? XFile(path!, name: name)
      : XFile.fromData(_bytes ?? Uint8List(0), name: name);

  @override
  Future<int> length() async => (await readAsBytes()).lengthInBytes;

  @override
  Future<Uint8List> readAsBytes() async {
    final local = path;
    if (local != null) return File(local).readAsBytes();
    return _bytes ?? Uint8List(0);
  }

  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield await readAsBytes();
  }
}

/// A mock [FilePickerPlatform] that returns pre-configured results
/// without invoking real platform channels.
class MockFilePickerPlatform extends FilePickerPlatform
    implements MockPlatformInterfaceMixin {
  /// The Uri `saveFile` hands back. file_picker 12 writes the bytes itself, so
  /// tests that assert on file contents should point this at a real path.
  Uri? saveFileResult;

  /// Results for `pickFiles`; the first of these also answers `pickFile`.
  List<PlatformFile> pickFilesResult = const [];

  String? directoryPathResult;

  /// The bytes the last `saveFile` call was asked to write.
  Uint8List? lastSavedBytes;

  /// The fileName the last `saveFile` call was asked to use.
  String? lastSavedFileName;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    lastSavedFileName = fileName;
    lastSavedBytes = bytes;
    final target = saveFileResult;
    // Mirror the real plugin: it writes the bytes, so anything asserting on
    // the saved file sees them without the caller writing separately.
    if (target != null && target.isScheme('file')) {
      await File(target.toFilePath()).writeAsBytes(bytes);
    }
    return target;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => pickFilesResult;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => pickFilesResult.isEmpty ? null : pickFilesResult.first;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => directoryPathResult;
}
