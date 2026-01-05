import 'package:equatable/equatable.dart';

/// Connection types supported by dive computers.
enum DeviceConnectionType {
  /// Bluetooth Low Energy (BLE)
  ble('Bluetooth LE'),

  /// Bluetooth Classic (Serial Port Profile)
  bluetoothClassic('Bluetooth'),

  /// USB serial connection
  usb('USB'),

  /// Infrared (legacy devices)
  infrared('Infrared');

  final String displayName;
  const DeviceConnectionType(this.displayName);
}

/// Represents a known dive computer model from the device library.
///
/// This is used to identify devices during scanning and provide
/// user-friendly names and connection information.
class DeviceModel extends Equatable {
  /// Unique identifier for this model (e.g., "shearwater_perdix")
  final String id;

  /// Manufacturer name (e.g., "Shearwater")
  final String manufacturer;

  /// Model name (e.g., "Perdix AI")
  final String model;

  /// List of supported connection types
  final List<DeviceConnectionType> connectionTypes;

  /// USB Vendor ID for auto-detection (hex string, e.g., "0x0403")
  final String? usbVendorId;

  /// USB Product ID for auto-detection (hex string, e.g., "0x6015")
  final String? usbProductId;

  /// BLE service UUID for auto-detection
  final String? bleServiceUuid;

  /// Bluetooth Classic service UUID for auto-detection
  final String? btServiceUuid;

  /// libdivecomputer family identifier
  final String? dcFamily;

  /// libdivecomputer model identifier
  final int? dcModel;

  const DeviceModel({
    required this.id,
    required this.manufacturer,
    required this.model,
    required this.connectionTypes,
    this.usbVendorId,
    this.usbProductId,
    this.bleServiceUuid,
    this.btServiceUuid,
    this.dcFamily,
    this.dcModel,
  });

  /// Full display name combining manufacturer and model
  String get fullName => '$manufacturer $model';

  /// Whether this device supports BLE
  bool get supportsBle => connectionTypes.contains(DeviceConnectionType.ble);

  /// Whether this device supports Bluetooth Classic
  bool get supportsBluetoothClassic =>
      connectionTypes.contains(DeviceConnectionType.bluetoothClassic);

  /// Whether this device supports USB
  bool get supportsUsb => connectionTypes.contains(DeviceConnectionType.usb);

  /// Whether this device supports any Bluetooth connection
  bool get supportsBluetooth => supportsBle || supportsBluetoothClassic;

  @override
  List<Object?> get props => [
    id,
    manufacturer,
    model,
    connectionTypes,
    usbVendorId,
    usbProductId,
    bleServiceUuid,
    btServiceUuid,
    dcFamily,
    dcModel,
  ];
}

/// A discovered device during scanning.
///
/// This combines the raw device information from scanning with
/// any matched device model from the library.
class DiscoveredDevice extends Equatable {
  /// Unique identifier for this device instance
  final String id;

  /// Device name as reported by the device
  final String name;

  /// Type of connection this device was discovered on
  final DeviceConnectionType connectionType;

  /// Bluetooth address or USB port identifier
  final String address;

  /// Signal strength for Bluetooth devices (RSSI in dBm)
  final int? signalStrength;

  /// Matched device model from the library (if recognized)
  final DeviceModel? recognizedModel;

  /// Raw service UUIDs for BLE devices
  final List<String> serviceUuids;

  /// Timestamp when this device was discovered
  final DateTime discoveredAt;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.address,
    this.signalStrength,
    this.recognizedModel,
    this.serviceUuids = const [],
    required this.discoveredAt,
  });

  /// Whether this device was recognized as a known dive computer model
  bool get isRecognized => recognizedModel != null;

  /// Display name for the device (uses recognized model if available)
  String get displayName =>
      recognizedModel?.fullName ?? (name.isNotEmpty ? name : 'Unknown Device');

  /// Manufacturer name (if recognized)
  String? get manufacturer => recognizedModel?.manufacturer;

  /// Model name (if recognized)
  String? get model => recognizedModel?.model;

  /// Signal strength as a percentage (0-100)
  int? get signalStrengthPercent {
    if (signalStrength == null) return null;
    // RSSI typically ranges from -100 dBm (weak) to -40 dBm (strong)
    final clamped = signalStrength!.clamp(-100, -40);
    return ((clamped + 100) * 100 / 60).round();
  }

  /// Signal strength as a qualitative level
  SignalStrength get signalLevel {
    final percent = signalStrengthPercent;
    if (percent == null) return SignalStrength.unknown;
    if (percent >= 75) return SignalStrength.excellent;
    if (percent >= 50) return SignalStrength.good;
    if (percent >= 25) return SignalStrength.fair;
    return SignalStrength.weak;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    connectionType,
    address,
    signalStrength,
    recognizedModel,
    serviceUuids,
    discoveredAt,
  ];
}

/// Signal strength levels for Bluetooth devices.
enum SignalStrength { unknown, weak, fair, good, excellent }
