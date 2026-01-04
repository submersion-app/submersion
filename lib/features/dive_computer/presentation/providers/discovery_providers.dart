import 'package:submersion/core/providers/provider.dart';

import '../../data/device_library.dart';
import '../../data/services/bluetooth_connection_manager.dart';
import '../../data/services/permissions_service.dart';
import '../../data/services/usb_device_scanner.dart';
import '../../domain/entities/device_model.dart';
import '../../domain/services/connection_manager.dart';

/// Provider for the device library singleton.
final deviceLibraryProvider = Provider<DeviceLibrary>((ref) {
  return DeviceLibrary.instance;
});

/// Provider for the permissions service.
final permissionsServiceProvider = Provider<DiveComputerPermissionsService>((
  ref,
) {
  return DiveComputerPermissionsService();
});

/// Provider for the Bluetooth connection manager.
final bluetoothConnectionManagerProvider = Provider<BluetoothConnectionManager>(
  (ref) {
    final manager = BluetoothConnectionManager();
    ref.onDispose(() => manager.dispose());
    return manager;
  },
);

/// Stream provider for the connection state.
final connectionStateProvider = StreamProvider<ConnectionState>((ref) {
  final manager = ref.watch(bluetoothConnectionManagerProvider);
  return manager.connectionState;
});

/// Stream provider for discovered devices.
final discoveredDevicesProvider = StreamProvider<List<DiscoveredDevice>>((ref) {
  final manager = ref.watch(bluetoothConnectionManagerProvider);
  return manager.discoveredDevices;
});

/// Provider for the USB device scanner.
final usbDeviceScannerProvider = Provider<UsbDeviceScanner>((ref) {
  final library = ref.watch(deviceLibraryProvider);
  final scanner = UsbDeviceScanner(deviceLibrary: library);
  ref.onDispose(() => scanner.dispose());
  return scanner;
});

/// Provider for USB-capable device models.
final usbDeviceModelsProvider = Provider<List<DeviceModel>>((ref) {
  final scanner = ref.watch(usbDeviceScannerProvider);
  return scanner.getUsbCapableDevices();
});

/// Provider for USB devices grouped by manufacturer.
final usbDevicesByManufacturerProvider =
    Provider<Map<String, List<DeviceModel>>>((ref) {
      final scanner = ref.watch(usbDeviceScannerProvider);
      return scanner.getUsbDevicesByManufacturer();
    });

/// Provider for Bluetooth availability check.
final bluetoothAvailabilityProvider = FutureProvider<BluetoothAvailability>((
  ref,
) async {
  final service = ref.watch(permissionsServiceProvider);
  return await service.checkBluetoothAvailability();
});

/// Provider for checking if all permissions are granted.
final hasPermissionsProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(permissionsServiceProvider);
  return await service.hasAllPermissions();
});

/// State for the device discovery wizard.
class DiscoveryState {
  final DiscoveryStep currentStep;
  final DiscoveredDevice? selectedDevice;
  final bool isScanning;
  final String? errorMessage;
  final String? customDeviceName;

  const DiscoveryState({
    this.currentStep = DiscoveryStep.scan,
    this.selectedDevice,
    this.isScanning = false,
    this.errorMessage,
    this.customDeviceName,
  });

  DiscoveryState copyWith({
    DiscoveryStep? currentStep,
    DiscoveredDevice? selectedDevice,
    bool? isScanning,
    String? errorMessage,
    String? customDeviceName,
    bool clearError = false,
    bool clearDevice = false,
  }) {
    return DiscoveryState(
      currentStep: currentStep ?? this.currentStep,
      selectedDevice: clearDevice
          ? null
          : (selectedDevice ?? this.selectedDevice),
      isScanning: isScanning ?? this.isScanning,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      customDeviceName: customDeviceName ?? this.customDeviceName,
    );
  }
}

/// Steps in the device discovery wizard.
enum DiscoveryStep { scan, select, pair, confirm, download, summary }

/// Notifier for managing the discovery wizard state.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final BluetoothConnectionManager _connectionManager;
  final DiveComputerPermissionsService _permissionsService;

  DiscoveryNotifier({
    required BluetoothConnectionManager connectionManager,
    required DiveComputerPermissionsService permissionsService,
  }) : _connectionManager = connectionManager,
       _permissionsService = permissionsService,
       super(const DiscoveryState());

  /// Start scanning for devices.
  Future<void> startScan() async {
    try {
      state = state.copyWith(isScanning: true, clearError: true);

      // Check permissions
      final hasPermissions = await _permissionsService.hasAllPermissions();
      if (!hasPermissions) {
        final granted = await _permissionsService.requestPermissions();
        if (!granted) {
          state = state.copyWith(
            isScanning: false,
            errorMessage: 'Bluetooth permissions are required',
          );
          return;
        }
      }

      // Check Bluetooth availability
      final availability = await _permissionsService
          .checkBluetoothAvailability();
      if (availability != BluetoothAvailability.available) {
        state = state.copyWith(
          isScanning: false,
          errorMessage: _getBluetoothErrorMessage(availability),
        );
        return;
      }

      // Start scanning
      await _connectionManager.startScan();
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Failed to start scanning: $e',
      );
    }
  }

  String _getBluetoothErrorMessage(BluetoothAvailability availability) {
    switch (availability) {
      case BluetoothAvailability.disabled:
        return 'Bluetooth is turned off. Please enable Bluetooth.';
      case BluetoothAvailability.notSupported:
        return 'Bluetooth is not supported on this device.';
      case BluetoothAvailability.unauthorized:
        return 'Bluetooth access is not authorized. Please grant permission.';
      default:
        return 'Bluetooth is not available.';
    }
  }

  /// Stop scanning.
  Future<void> stopScan() async {
    await _connectionManager.stopScan();
    state = state.copyWith(isScanning: false);
  }

  /// Select a device and move to the next step.
  void selectDevice(DiscoveredDevice device) {
    state = state.copyWith(
      selectedDevice: device,
      currentStep: DiscoveryStep.confirm,
    );
  }

  /// Set a custom name for the device.
  void setCustomName(String name) {
    state = state.copyWith(customDeviceName: name);
  }

  /// Connect to the selected device.
  Future<bool> connectToDevice() async {
    final device = state.selectedDevice;
    if (device == null) return false;

    try {
      state = state.copyWith(currentStep: DiscoveryStep.pair, clearError: true);
      await _connectionManager.connect(device);
      state = state.copyWith(currentStep: DiscoveryStep.download);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to connect: $e',
        currentStep: DiscoveryStep.confirm,
      );
      return false;
    }
  }

  /// Move to the summary step.
  void goToSummary() {
    state = state.copyWith(currentStep: DiscoveryStep.summary);
  }

  /// Go to a specific step.
  void goToStep(DiscoveryStep step) {
    state = state.copyWith(currentStep: step);
  }

  /// Go back one step.
  void goBack() {
    final currentIndex = DiscoveryStep.values.indexOf(state.currentStep);
    if (currentIndex > 0) {
      state = state.copyWith(
        currentStep: DiscoveryStep.values[currentIndex - 1],
      );
    }
  }

  /// Reset the wizard to the initial state.
  void reset() {
    _connectionManager.disconnect();
    state = const DiscoveryState();
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    await _connectionManager.disconnect();
  }
}

/// Provider for the discovery notifier.
final discoveryNotifierProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
      final connectionManager = ref.watch(bluetoothConnectionManagerProvider);
      final permissionsService = ref.watch(permissionsServiceProvider);

      return DiscoveryNotifier(
        connectionManager: connectionManager,
        permissionsService: permissionsService,
      );
    });

/// Provider for getting the list of manufacturers from the device library.
final deviceManufacturersProvider = Provider<List<String>>((ref) {
  final library = ref.watch(deviceLibraryProvider);
  return library.manufacturers;
});

/// Provider for getting devices by manufacturer.
final devicesByManufacturerProvider =
    Provider.family<List<DeviceModel>, String>((ref, manufacturer) {
      final library = ref.watch(deviceLibraryProvider);
      return library.getByManufacturer(manufacturer);
    });
