import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// Namespace for deterministic dive computer connection ids (issue #3106).
/// Frozen: every device must derive the same id for the same connection, or
/// two devices recording `(computer, ble)` would each add a row.
const String kDiveComputerConnectionNamespace =
    '7bd854b9-1e72-422b-8f8e-784bd64924b7';

/// How a dive computer reached the library: a direct transport, a file
/// format, or a cloud provider. The wire value is the enum name.
enum DiveComputerConnectionKind {
  ble,
  bluetoothClassic,
  usb,
  infrared,
  file,
  cloud;

  /// A transport the app can reopen to download again.
  bool get isDirect => this != file && this != cloud;

  static DiveComputerConnectionKind? fromWire(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  static DiveComputerConnectionKind fromDevice(DeviceConnectionType type) =>
      switch (type) {
        DeviceConnectionType.ble => ble,
        DeviceConnectionType.bluetoothClassic => bluetoothClassic,
        DeviceConnectionType.usb => usb,
        DeviceConnectionType.infrared => infrared,
      };

  /// The discovery transport for a direct kind; null for file and cloud.
  DeviceConnectionType? get deviceConnectionType => switch (this) {
    ble => DeviceConnectionType.ble,
    bluetoothClassic => DeviceConnectionType.bluetoothClassic,
    usb => DeviceConnectionType.usb,
    infrared => DeviceConnectionType.infrared,
    file || cloud => null,
  };

  /// The `dive_computers.connection_type` value this kind mirrors into, so
  /// a peer still on a build before connections keeps working.
  String? get legacyConnectionType => switch (this) {
    ble || bluetoothClassic => 'bluetooth',
    usb => 'usb',
    infrared => 'infrared',
    cloud => 'cloud',
    file => null,
  };
}

/// The deterministic id of a computer's connection.
String diveComputerConnectionId({
  required String computerId,
  required DiveComputerConnectionKind kind,
  String? detail,
}) => diveComputerConnectionIdForWire(
  computerId: computerId,
  kindName: kind.name,
  detail: detail,
);

/// [diveComputerConnectionId] from the stored kind text, for a row whose
/// kind a newer build wrote and this one cannot name.
String diveComputerConnectionIdForWire({
  required String computerId,
  required String kindName,
  String? detail,
}) => const Uuid().v5(
  kDiveComputerConnectionNamespace,
  '$computerId|$kindName|${detail?.trim() ?? ''}',
);

/// One way a dive computer has reached the library (issue #3106).
class DiveComputerConnection extends Equatable {
  const DiveComputerConnection({
    required this.id,
    required this.computerId,
    required this.kind,
    this.detail,
    required this.firstUsedAt,
    required this.lastUsedAt,
    this.address,
    this.localLastUsedAt,
  });

  final String id;
  final String computerId;
  final DiveComputerConnectionKind kind;

  /// The file format (`ImportFormat.name`) or cloud provider.
  final String? detail;
  final DateTime firstUsedAt;
  final DateTime lastUsedAt;

  /// This device's BLE identifier or USB port; never synced.
  final String? address;

  /// When this device last used the connection; never synced.
  final DateTime? localLastUsedAt;

  bool get isDirect => kind.isDirect;

  /// Whether this device can download over the connection right now.
  bool get reachableHere =>
      kind.isDirect && (address?.trim().isNotEmpty ?? false);

  DiveComputerConnection copyWith({
    String? id,
    String? computerId,
    DiveComputerConnectionKind? kind,
    String? detail,
    DateTime? firstUsedAt,
    DateTime? lastUsedAt,
    String? address,
    DateTime? localLastUsedAt,
  }) => DiveComputerConnection(
    id: id ?? this.id,
    computerId: computerId ?? this.computerId,
    kind: kind ?? this.kind,
    detail: detail ?? this.detail,
    firstUsedAt: firstUsedAt ?? this.firstUsedAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    address: address ?? this.address,
    localLastUsedAt: localLastUsedAt ?? this.localLastUsedAt,
  );

  @override
  List<Object?> get props => [
    id,
    computerId,
    kind,
    detail,
    firstUsedAt,
    lastUsedAt,
    address,
    localLastUsedAt,
  ];
}
