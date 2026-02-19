import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/services/connection_manager.dart';
import 'package:submersion/features/dive_computer/data/device_library.dart';
import 'package:submersion/features/dive_computer/data/services/permissions_service.dart';

final _log = LoggerService.forClass(BluetoothConnectionManager);

/// Implementation of [ConnectionManager] for Bluetooth devices.
///
/// Uses flutter_blue_plus for BLE scanning and connection.
class BluetoothConnectionManager implements ConnectionManager {
  final DiveComputerPermissionsService _permissionsService;
  final DeviceLibrary _deviceLibrary;

  // Stream controllers
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  // State
  ConnectionState _currentState = ConnectionState.disconnected;
  DiscoveredDevice? _connectedDevice;
  BluetoothDevice? _bluetoothDevice;
  final Map<String, DiscoveredDevice> _discoveredDevices = {};

  // Subscriptions
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  BluetoothConnectionManager({
    DiveComputerPermissionsService? permissionsService,
    DeviceLibrary? deviceLibrary,
  }) : _permissionsService =
           permissionsService ?? DiveComputerPermissionsService(),
       _deviceLibrary = deviceLibrary ?? DeviceLibrary.instance;

  @override
  Stream<ConnectionState> get connectionState => _stateController.stream;

  @override
  ConnectionState get currentState => _currentState;

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _devicesController.stream;

  @override
  DiscoveredDevice? get connectedDevice => _connectedDevice;

  @override
  bool get isConnected => _currentState == ConnectionState.connected;

  @override
  bool get isScanning => _currentState == ConnectionState.scanning;

  void _updateState(ConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
    List<DeviceConnectionType>? connectionTypes,
  }) async {
    // Check permissions first
    final hasPermissions = await _permissionsService.hasAllPermissions();
    if (!hasPermissions) {
      final granted = await _permissionsService.requestPermissions();
      if (!granted) {
        throw const PermissionDeniedException(
          'Bluetooth',
          'Bluetooth permissions are required to scan for dive computers',
        );
      }
    }

    // Check Bluetooth availability
    final availability = await _permissionsService.checkBluetoothAvailability();
    if (availability != BluetoothAvailability.available) {
      if (availability == BluetoothAvailability.disabled) {
        throw const BluetoothNotAvailableException(
          'Bluetooth is turned off. Please enable Bluetooth.',
        );
      }
      throw BluetoothNotAvailableException(
        'Bluetooth is not available (${availability.name})',
      );
    }

    // Stop any existing scan
    await stopScan();

    // Clear previous results
    _discoveredDevices.clear();
    _devicesController.add([]);

    _updateState(ConnectionState.scanning);

    // Note: We scan for all devices and filter in software for better compatibility
    // This provides better device detection than filtering by service UUID

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        _processScanResult(result);
      }
    });

    // Auto-stop after timeout
    Future.delayed(timeout, () {
      if (_currentState == ConnectionState.scanning) {
        stopScan();
      }
    });
  }

  void _processScanResult(ScanResult result) {
    final device = result.device;
    final name = result.advertisementData.advName.isNotEmpty
        ? result.advertisementData.advName
        : device.platformName;

    // Get service UUIDs from advertisement
    final serviceUuids = result.advertisementData.serviceUuids
        .map((g) => g.str.toLowerCase())
        .toList();

    _log.info(
      'Scan result: name="$name", '
      'advName="${result.advertisementData.advName}", '
      'platformName="${device.platformName}", '
      'id=${device.remoteId.str}, '
      'serviceUuids=$serviceUuids, '
      'rssi=${result.rssi}',
    );

    // Try to match against known device models
    DeviceModel? recognizedModel;

    // First check by service UUID
    for (final uuid in serviceUuids) {
      recognizedModel = _deviceLibrary.findByBleServiceUuid(uuid);
      if (recognizedModel != null) {
        _log.info('  -> Matched by UUID: ${recognizedModel.fullName}');
        break;
      }
    }

    // Then try by name (if device has one)
    if (name.isNotEmpty && recognizedModel == null) {
      recognizedModel = _deviceLibrary.findByName(name);
      if (recognizedModel != null) {
        _log.info('  -> Matched by name: ${recognizedModel.fullName}');
      } else {
        _log.info('  -> No match for name "$name"');
      }
    }

    // Skip nameless devices unless they matched a known service UUID
    if (name.isEmpty && recognizedModel == null) return;

    // Use recognized model name as fallback for nameless devices
    final displayName = name.isNotEmpty
        ? name
        : (recognizedModel?.fullName ?? '');

    // Create discovered device
    final discovered = DiscoveredDevice(
      id: device.remoteId.str,
      name: displayName,
      connectionType: DeviceConnectionType.ble,
      address: device.remoteId.str,
      signalStrength: result.rssi,
      recognizedModel: recognizedModel,
      serviceUuids: serviceUuids,
      discoveredAt: DateTime.now(),
    );

    // Add or update in our map
    _discoveredDevices[device.remoteId.str] = discovered;

    // Emit updated list (sorted by signal strength, recognized devices first)
    final deviceList = _discoveredDevices.values.toList()
      ..sort((a, b) {
        // Recognized devices first
        if (a.isRecognized && !b.isRecognized) return -1;
        if (!a.isRecognized && b.isRecognized) return 1;
        // Then by signal strength (stronger first)
        final rssiA = a.signalStrength ?? -100;
        final rssiB = b.signalStrength ?? -100;
        return rssiB.compareTo(rssiA);
      });

    _devicesController.add(deviceList);
  }

  @override
  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (_currentState == ConnectionState.scanning) {
      _updateState(ConnectionState.disconnected);
    }
  }

  @override
  Future<void> connect(DiscoveredDevice device) async {
    if (_currentState == ConnectionState.connected ||
        _currentState == ConnectionState.connecting) {
      await disconnect();
    }

    _updateState(ConnectionState.connecting);

    try {
      // Get the Bluetooth device
      _bluetoothDevice = BluetoothDevice.fromId(device.address);

      // Connect
      await _bluetoothDevice!.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Listen for disconnection
      _connectionSubscription = _bluetoothDevice!.connectionState.listen((
        state,
      ) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Discover services
      await _bluetoothDevice!.discoverServices();

      _connectedDevice = device;
      _updateState(ConnectionState.connected);
    } catch (e) {
      _updateState(ConnectionState.error);
      await disconnect();
      throw DeviceConnectionException(
        'Failed to connect to ${device.displayName}: $e',
        deviceId: device.id,
        originalError: e,
      );
    }
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _bluetoothDevice = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_currentState != ConnectionState.disconnected) {
      _updateState(ConnectionState.disconnected);
    }
  }

  @override
  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_bluetoothDevice != null) {
      try {
        await _bluetoothDevice!.disconnect();
      } catch (e) {
        // Ignore disconnect errors
      }
    }

    _bluetoothDevice = null;
    _connectedDevice = null;
    _updateState(ConnectionState.disconnected);
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    _stateController.close();
    _devicesController.close();
  }

  /// Get the underlying BluetoothDevice for advanced operations.
  ///
  /// Used by the download manager to communicate with the device.
  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;

  /// Get a specific service from the connected device.
  Future<BluetoothService?> getService(String uuid) async {
    if (_bluetoothDevice == null) return null;

    final services = await _bluetoothDevice!.discoverServices();
    return services.cast<BluetoothService?>().firstWhere(
      (s) => s?.uuid.str.toLowerCase() == uuid.toLowerCase(),
      orElse: () => null,
    );
  }

  /// Get a specific characteristic from a service.
  Future<BluetoothCharacteristic?> getCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final service = await getService(serviceUuid);
    if (service == null) return null;

    return service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
      (c) => c?.uuid.str.toLowerCase() == characteristicUuid.toLowerCase(),
      orElse: () => null,
    );
  }
}
