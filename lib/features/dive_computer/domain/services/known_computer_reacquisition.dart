import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// The one discovered device that can stand in for [computer] when nothing
/// advertised its stored address.
///
/// The address saved for a Bluetooth computer is a host-local identifier, not
/// a property of the hardware: Android and Windows store the MAC, and iOS and
/// macOS store the CoreBluetooth identifier that the OS mints per address.
/// Computers that rotate their Bluetooth address (the Ratio iX3M in issue
/// #1423) therefore come back under a new identifier, and a scan that insists
/// on the stored one never finds them even while they are advertising.
///
/// Returns the single Bluetooth device that libdivecomputer recognized as the
/// saved computer's manufacturer and model, or null when there is none or
/// more than one. Names are compared ignoring case and surrounding
/// whitespace, as the repository's hardware-identity lookup does. Devices on
/// other transports are never candidates, because only a Bluetooth address
/// can go stale this way.
///
/// Interchangeable models (see [interchangeableBleModels]) count as the same
/// model.
///
/// With two candidates nothing distinguishes the saved computer from a
/// buddy's, so the caller keeps the stored address. The serial number that
/// the download reports later confirms or rejects the match before the
/// stored address is rewritten.
DiscoveredDevice? sameModelFallbackDevice({
  required DiveComputer computer,
  required Iterable<DiscoveredDevice> discovered,
}) {
  final manufacturer = _normalize(computer.manufacturer);
  final model = _normalize(computer.model);
  if (manufacturer.isEmpty || model.isEmpty) return null;

  final candidates = discovered
      .where(
        (device) =>
            _isBluetooth(device) &&
            _normalize(device.manufacturer) == manufacturer &&
            _sameModel(manufacturer, _normalize(device.model), model),
      )
      .toList();
  return candidates.length == 1 ? candidates.single : null;
}

bool _isBluetooth(DiscoveredDevice device) =>
    device.connectionType == DeviceConnectionType.ble ||
    device.connectionType == DeviceConnectionType.bluetoothClassic;

String _normalize(String? value) => (value ?? '').trim().toLowerCase();

/// Models that one physical Bluetooth computer can be scanned as and saved as
/// under different names, keyed by lowercase manufacturer (issue #422).
///
/// The Cressi Goa family shares one protocol, and Cressi's Bluetooth adapter
/// advertises the Cartesio's model code whatever computer sits behind it. A
/// download relabels the saved record to the model the device reports, so the
/// saved "Donatello" is scanned again as a "Cartesio". Pinned to the
/// DC_FAMILY_CRESSI_GOA rows of libdivecomputer's descriptor table by a test.
const Map<String, Set<String>> interchangeableBleModels = {
  'cressi': {
    'cartesio',
    'goa',
    'leonardo 2.0',
    'donatello',
    'michelangelo',
    'neon',
    'nepto',
  },
};

bool _sameModel(String manufacturer, String a, String b) {
  if (a == b) return true;
  final group = interchangeableBleModels[manufacturer];
  return group != null && group.contains(a) && group.contains(b);
}
