import 'package:equatable/equatable.dart';

/// Represents a dive computer device that records dive data.
///
/// Stores device information, connection details, and download history.
class DiveComputer extends Equatable {
  /// Unique identifier
  final String id;

  /// Owner diver ID
  final String? diverId;

  /// User-given name for this computer
  final String name;

  /// Manufacturer (e.g., "Shearwater", "Suunto", "Garmin")
  final String? manufacturer;

  /// Model name (e.g., "Perdix 2", "D5", "Descent Mk2i")
  final String? model;

  /// Serial number
  final String? serialNumber;

  /// Firmware version reported by the device
  final String? firmwareVersion;

  /// Connection type (e.g., "bluetooth", "usb", "infrared")
  final String? connectionType;

  /// Bluetooth MAC address or identifier
  final String? bluetoothAddress;

  /// Timestamp of last successful download
  final DateTime? lastDownload;

  /// Fingerprint of the newest dive from the last successful import.
  /// Used for incremental downloads -- libdivecomputer stops at this dive.
  final String? lastDiveFingerprint;

  /// Number of dives downloaded from this computer
  final int diveCount;

  /// Whether this is the user's primary/favorite computer
  final bool isFavorite;

  /// Additional notes
  final String notes;

  /// When this record was created
  final DateTime createdAt;

  /// When this record was last updated
  final DateTime updatedAt;

  const DiveComputer({
    required this.id,
    this.diverId,
    required this.name,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.firmwareVersion,
    this.connectionType,
    this.bluetoothAddress,
    this.lastDownload,
    this.lastDiveFingerprint,
    this.diveCount = 0,
    this.isFavorite = false,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Full display name combining manufacturer and model
  String get fullName {
    if (manufacturer != null && model != null) {
      return '$manufacturer $model';
    }
    if (model != null) return model!;
    if (manufacturer != null) return manufacturer!;
    return name;
  }

  /// Short display name for lists
  String get displayName => name.isNotEmpty ? name : fullName;

  /// Whether this computer has Bluetooth connectivity
  bool get hasBluetooth =>
      connectionType == 'bluetooth' && bluetoothAddress != null;

  /// Whether we have complete device info
  bool get hasDeviceInfo =>
      manufacturer != null && model != null && serialNumber != null;

  /// Create a new dive computer with minimal info
  factory DiveComputer.create({
    required String id,
    required String name,
    String? diverId,
    String? manufacturer,
    String? model,
  }) {
    final now = DateTime.now();
    return DiveComputer(
      id: id,
      diverId: diverId,
      name: name,
      manufacturer: manufacturer,
      model: model,
      createdAt: now,
      updatedAt: now,
    );
  }

  DiveComputer copyWith({
    String? id,
    String? diverId,
    String? name,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? firmwareVersion,
    String? connectionType,
    String? bluetoothAddress,
    DateTime? lastDownload,
    String? lastDiveFingerprint,
    int? diveCount,
    bool? isFavorite,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveComputer(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      connectionType: connectionType ?? this.connectionType,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      lastDownload: lastDownload ?? this.lastDownload,
      lastDiveFingerprint: lastDiveFingerprint ?? this.lastDiveFingerprint,
      diveCount: diveCount ?? this.diveCount,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    manufacturer,
    model,
    serialNumber,
    firmwareVersion,
    connectionType,
    bluetoothAddress,
    lastDownload,
    lastDiveFingerprint,
    diveCount,
    isFavorite,
    notes,
    createdAt,
    updatedAt,
  ];
}

/// Connection types for dive computers
enum DiveComputerConnectionType {
  bluetooth('Bluetooth'),
  usb('USB'),
  infrared('Infrared'),
  wifi('WiFi'),
  manual('Manual Entry');

  final String displayName;
  const DiveComputerConnectionType(this.displayName);
}
