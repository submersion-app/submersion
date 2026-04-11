import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// FilePickerPlatform is not publicly exported; centralise the src/ import here
// so test files only depend on this helper.
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
export 'package:file_picker/src/platform/file_picker_platform_interface.dart'
    show FilePickerPlatform;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A mock [FilePickerPlatform] that returns pre-configured results
/// without invoking real platform channels.
class MockFilePickerPlatform extends FilePickerPlatform
    implements MockPlatformInterfaceMixin {
  String? saveFileResult;
  FilePickerResult? pickFilesResult;
  String? directoryPathResult;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => saveFileResult;

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
  }) async => pickFilesResult;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => directoryPathResult;
}
