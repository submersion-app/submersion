import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// The Garmin entry in Connect New Computer's USB list (issue #4223).
///
/// libdivecomputer has no Garmin backend, so Garmin is never among the USB
/// models it reports. On Windows, where Submersion reads Garmin watches over
/// MTP, the list gets one entry of its own, which opens the Garmin device
/// import instead of the libdivecomputer pair-and-download steps.
abstract final class GarminWatchUsbEntry {
  static const manufacturer = 'Garmin';

  /// Not a libdivecomputer model id: it has no `dcModel`, and is never handed
  /// to a download.
  static const modelId = 'garmin_watch_import';

  /// Windows only, matching the platform that reads watches over MTP.
  static bool get isOffered =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool isEntry(DeviceModel model) => model.id == modelId;

  /// [devices] with the Garmin entry appended, labelled [label]. The label
  /// names Descent, Fenix and Epix, so a search for a model name finds it
  /// as a search for "Garmin" does through the manufacturer.
  static Map<String, List<DeviceModel>> addTo(
    Map<String, List<DeviceModel>> devices, {
    required String label,
  }) => {
    ...devices,
    manufacturer: [
      ...?devices[manufacturer],
      DeviceModel(
        id: modelId,
        manufacturer: manufacturer,
        model: label,
        connectionTypes: const [DeviceConnectionType.usb],
      ),
    ],
  };
}
