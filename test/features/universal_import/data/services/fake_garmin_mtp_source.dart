import 'package:flutter/services.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_source.dart';

/// An in-memory Garmin watch (or several) behind [GarminMtpSource], standing
/// in for the Windows Portable Devices reader in tests.
class FakeGarminMtpSource implements GarminMtpSource {
  FakeGarminMtpSource({
    this.devices = const [],
    Map<String, Map<String, Uint8List>> filesByDevice = const {},
    this.listError,
    this.listFilesError,
    this.failingFiles = const {},
  }) : _filesByDevice = filesByDevice;

  final List<GarminMtpDevice> devices;

  /// Activity files per device id: file name to bytes. A file's object id
  /// is `<device id>/<name>`.
  final Map<String, Map<String, Uint8List>> _filesByDevice;

  /// Thrown by [listDevices] when set.
  final Object? listError;

  /// Thrown by [listActivityFiles] when set.
  final Object? listFilesError;

  /// File names whose [readFile] fails.
  final Set<String> failingFiles;

  final List<String> readObjectIds = [];

  @override
  Future<List<GarminMtpDevice>> listDevices() async {
    if (listError != null) throw listError!;
    return devices;
  }

  @override
  Future<List<GarminMtpFile>> listActivityFiles(String deviceId) async {
    if (listFilesError != null) throw listFilesError!;
    final files = _filesByDevice[deviceId] ?? const {};
    return [
      for (final entry in files.entries)
        GarminMtpFile(
          objectId: '$deviceId/${entry.key}',
          name: entry.key,
          size: entry.value.length,
        ),
    ];
  }

  @override
  Future<Uint8List> readFile(String deviceId, String objectId) async {
    readObjectIds.add(objectId);
    final name = objectId.substring(deviceId.length + 1);
    if (failingFiles.contains(name)) {
      throw PlatformException(code: 'ioError', message: 'read failed');
    }
    final bytes = _filesByDevice[deviceId]?[name];
    if (bytes == null) {
      throw PlatformException(code: 'notFound', message: 'no such file');
    }
    return bytes;
  }
}

GarminMtpDevice fakeGarminWatch({
  String id = r'\\?\usb#vid_091e&pid_4fb8#0000abcd#{6ac27878}',
  String name = 'Descent G2',
  String? serial = '3456789012',
}) => GarminMtpDevice(id: id, friendlyName: name, serialNumber: serial);
