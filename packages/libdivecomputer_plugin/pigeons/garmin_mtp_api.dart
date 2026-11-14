import 'package:pigeon/pigeon.dart';

// Reads dive FIT files off a Garmin watch that connects over MTP rather than
// mounting as a drive (issue #4223). Windows only: the native side is a thin
// Windows Portable Devices reader, so only Dart and C++ are generated, and the
// shared dive_computer_api.dart and the other platforms are untouched.
//
// Its own C++ namespace, because every Pigeon file defines FlutterError,
// ErrorOr and its codec, which would collide with dive_computer_api.g.h's.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/garmin_mtp_api.g.dart',
    cppHeaderOut: 'windows/garmin_mtp_api.g.h',
    cppSourceOut: 'windows/garmin_mtp_api.g.cc',
    cppOptions: CppOptions(namespace: 'garmin_mtp'),
  ),
)
// === Data Classes ===
/// A Garmin (USB vendor 0x091E) portable device.
class GarminMtpDevice {
  const GarminMtpDevice({
    required this.id,
    required this.friendlyName,
    this.manufacturer,
    this.model,
    this.serialNumber,
  });

  /// The WPD PnP device ID, passed back to the other calls.
  final String id;

  /// The name Windows shows for it, such as "Descent G2".
  final String friendlyName;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
}

/// A file in the watch's GARMIN/Activity folder.
class GarminMtpFile {
  const GarminMtpFile({
    required this.objectId,
    required this.name,
    required this.size,
    this.modifiedMillis,
  });

  /// The WPD object ID, valid while the device stays connected.
  final String objectId;

  /// The original file name, such as "2026-11-01-10-22-31.fit".
  final String name;

  /// Size in bytes; -1 when the device does not report one.
  final int size;

  /// Last-modified time in milliseconds since the epoch (UTC), if reported.
  final int? modifiedMillis;
}

// === Host API (Dart -> Native) ===

/// Errors arrive as PlatformException with one of these codes:
/// `notFound` (the device or folder is gone), `busy` (another app holds the
/// device), `ioError` (anything else). The message carries the HRESULT.
@HostApi()
abstract class GarminMtpHostApi {
  @async
  List<GarminMtpDevice> listDevices();

  /// Every file directly under GARMIN/Activity, on every storage of the
  /// device. Empty when the watch has no such folder.
  @async
  List<GarminMtpFile> listActivityFiles(String deviceId);

  @async
  Uint8List readFile(String deviceId, String objectId);
}
