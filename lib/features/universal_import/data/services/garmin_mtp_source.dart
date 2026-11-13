import 'dart:typed_data';

import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';

/// Reads a Garmin watch that connects over MTP instead of mounting as a
/// drive, such as the Descent G2 (issue #4223).
///
/// Windows only: the plugin implements it with Windows Portable Devices, and
/// no other platform registers the channel. Failures are
/// `PlatformException`s with code `notFound`, `busy` or `ioError`.
abstract interface class GarminMtpSource {
  /// Connected portable devices with Garmin's USB vendor ID.
  Future<List<GarminMtpDevice>> listDevices();

  /// Every file directly under the watch's GARMIN/Activity folder.
  Future<List<GarminMtpFile>> listActivityFiles(String deviceId);

  Future<Uint8List> readFile(String deviceId, String objectId);
}

/// [GarminMtpSource] over the plugin's Pigeon API.
class PigeonGarminMtpSource implements GarminMtpSource {
  PigeonGarminMtpSource([GarminMtpHostApi? api])
    : _api = api ?? GarminMtpHostApi();

  final GarminMtpHostApi _api;

  @override
  Future<List<GarminMtpDevice>> listDevices() => _api.listDevices();

  @override
  Future<List<GarminMtpFile>> listActivityFiles(String deviceId) =>
      _api.listActivityFiles(deviceId);

  @override
  Future<Uint8List> readFile(String deviceId, String objectId) =>
      _api.readFile(deviceId, objectId);
}
