import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/services/reported_model_relabel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/cloud_computer_identity.dart';
import 'package:submersion/features/import_wizard/domain/models/import_source_details.dart';

/// What the Review step shows about a dive computer download (issue #161).
///
/// What this session's download reported ([device], [serialNumber],
/// [firmwareVersion], [reportedProduct]) wins over the [stored] record, which
/// a quick download from a known computer starts from. [customName] is the
/// name typed on the confirm step.
ImportSourceDetails diveComputerSourceDetails({
  String? customName,
  DiveComputer? stored,
  DiscoveredDevice? device,
  String? serialNumber,
  String? firmwareVersion,
  String? reportedProduct,
}) {
  final saved = device == null
      ? stored
      : _asDownloadSavesIt(stored, serialNumber, reportedProduct);
  final hasStoredModel =
      saved != null &&
      (normalizedIdentityPart(saved.manufacturer) ??
              normalizedIdentityPart(saved.model)) !=
          null;
  return ImportSourceDetails(
    title: customName ?? saved?.displayName ?? device?.displayName,
    // fullName falls back to the computer's name when the record has no
    // manufacturer or model, which would hide the recognized device.
    model: hasStoredModel ? saved.fullName : device?.recognizedModel?.fullName,
    serialNumber: serialNumber ?? saved?.serialNumber,
    firmwareVersion: firmwareVersion ?? saved?.firmwareVersion,
    connection:
        device?.connectionType ?? _storedConnection(saved?.connectionType),
  );
}

/// [stored] as the download step saves it once the download completes: a
/// known computer whose device named a different model is relabeled to it
/// (issue #422), unless the serials say the device is another computer.
/// The adapter's own copy of a known computer is never refreshed, so the
/// Review step would otherwise show the model it was scanned as.
DiveComputer? _asDownloadSavesIt(
  DiveComputer? stored,
  String? serialNumber,
  String? reportedProduct,
) {
  if (stored == null) return null;
  final storedSerial = stored.serialNumber;
  if (storedSerial != null &&
      serialNumber != null &&
      storedSerial != serialNumber) {
    return stored;
  }
  return relabelToReportedProduct(stored, reportedProduct);
}

/// The connection a stored computer was last saved with, read the way the
/// device detail page reads it. This app saves 'bluetooth' for both Bluetooth
/// LE and Classic, so that reads as plain Bluetooth; older rows may say 'ble'
/// or 'bluetoothClassic', in any case.
DeviceConnectionType? _storedConnection(String? stored) => switch (stored
    ?.toLowerCase()) {
  'ble' => DeviceConnectionType.ble,
  'bluetooth' || 'bluetoothclassic' => DeviceConnectionType.bluetoothClassic,
  'usb' => DeviceConnectionType.usb,
  'infrared' => DeviceConnectionType.infrared,
  _ => null,
};
