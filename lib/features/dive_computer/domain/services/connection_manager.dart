import '../entities/device_model.dart';

/// Connection states for the device discovery and communication process.
enum ConnectionState {
  /// Not connected to any device
  disconnected,

  /// Scanning for nearby devices
  scanning,

  /// Connecting to a specific device
  connecting,

  /// Successfully connected and ready for communication
  connected,

  /// Downloading dives from the connected device
  downloading,

  /// An error occurred
  error,
}

/// Abstract interface for managing connections to dive computers.
///
/// Implementations handle the specifics of Bluetooth or USB communication
/// while providing a consistent API for the UI layer.
abstract class ConnectionManager {
  /// Stream of connection state changes
  Stream<ConnectionState> get connectionState;

  /// Current connection state
  ConnectionState get currentState;

  /// Stream of discovered devices during scanning
  Stream<List<DiscoveredDevice>> get discoveredDevices;

  /// The currently connected device, if any
  DiscoveredDevice? get connectedDevice;

  /// Start scanning for nearby dive computers.
  ///
  /// [timeout] - How long to scan before automatically stopping.
  /// [connectionTypes] - Optional filter for specific connection types.
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
    List<DeviceConnectionType>? connectionTypes,
  });

  /// Stop any ongoing device scan
  Future<void> stopScan();

  /// Connect to a specific discovered device.
  ///
  /// Throws [DeviceConnectionException] if connection fails.
  Future<void> connect(DiscoveredDevice device);

  /// Disconnect from the current device
  Future<void> disconnect();

  /// Check if currently connected to a device
  bool get isConnected;

  /// Check if currently scanning for devices
  bool get isScanning;

  /// Dispose of resources
  void dispose();
}

/// Exception thrown when device connection fails.
class DeviceConnectionException implements Exception {
  final String message;
  final String? deviceId;
  final dynamic originalError;

  const DeviceConnectionException(
    this.message, {
    this.deviceId,
    this.originalError,
  });

  @override
  String toString() =>
      'DeviceConnectionException: $message${deviceId != null ? ' (device: $deviceId)' : ''}';
}

/// Exception thrown when Bluetooth is not available or disabled.
class BluetoothNotAvailableException implements Exception {
  final String message;

  const BluetoothNotAvailableException(this.message);

  @override
  String toString() => 'BluetoothNotAvailableException: $message';
}

/// Exception thrown when required permissions are not granted.
class PermissionDeniedException implements Exception {
  final String permission;
  final String message;

  const PermissionDeniedException(this.permission, this.message);

  @override
  String toString() => 'PermissionDeniedException: $permission - $message';
}
