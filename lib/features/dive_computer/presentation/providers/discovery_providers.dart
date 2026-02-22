import 'dart:async';

import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// Provider for the DiveComputerService singleton.
final diveComputerServiceProvider = Provider<pigeon.DiveComputerService>((ref) {
  final service = pigeon.DiveComputerService();
  pigeon.DiveComputerFlutterApi.setUp(service);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for all known device descriptors from libdivecomputer.
final deviceDescriptorsProvider = FutureProvider<List<pigeon.DeviceDescriptor>>(
  (ref) async {
    final service = ref.watch(diveComputerServiceProvider);
    return service.getDeviceDescriptors();
  },
);

/// Provider for the libdivecomputer version string.
final libdcVersionProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(diveComputerServiceProvider);
  return service.getVersion();
});

/// Provider for USB-capable device models derived from descriptors.
final usbDeviceModelsProvider = FutureProvider<List<DeviceModel>>((ref) async {
  final descriptors = await ref.watch(deviceDescriptorsProvider.future);
  return descriptors
      .where(
        (d) => d.transports.any(
          (t) =>
              t == pigeon.TransportType.usb || t == pigeon.TransportType.serial,
        ),
      )
      .map(DeviceModel.fromDescriptor)
      .toList();
});

/// Provider for USB devices grouped by manufacturer.
final usbDevicesByManufacturerProvider =
    FutureProvider<Map<String, List<DeviceModel>>>((ref) async {
      final models = await ref.watch(usbDeviceModelsProvider.future);
      final result = <String, List<DeviceModel>>{};
      for (final model in models) {
        result.putIfAbsent(model.manufacturer, () => []).add(model);
      }
      return result;
    });

/// Provider for the accumulated list of discovered devices.
final discoveredDevicesProvider = Provider<List<DiscoveredDevice>>((ref) {
  return ref.watch(discoveryNotifierProvider).discoveredDevices;
});

/// State for the device discovery wizard.
class DiscoveryState {
  final DiscoveryStep currentStep;
  final DiscoveredDevice? selectedDevice;
  final List<DiscoveredDevice> discoveredDevices;
  final bool isScanning;
  final String? errorMessage;
  final String? customDeviceName;

  const DiscoveryState({
    this.currentStep = DiscoveryStep.scan,
    this.selectedDevice,
    this.discoveredDevices = const [],
    this.isScanning = false,
    this.errorMessage,
    this.customDeviceName,
  });

  DiscoveryState copyWith({
    DiscoveryStep? currentStep,
    DiscoveredDevice? selectedDevice,
    List<DiscoveredDevice>? discoveredDevices,
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
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      customDeviceName: customDeviceName ?? this.customDeviceName,
    );
  }
}

/// Steps in the device discovery wizard.
enum DiscoveryStep { scan, select, pair, confirm, download, summary }

/// Notifier for managing the discovery wizard state.
///
/// Uses DiveComputerService for BLE discovery via libdivecomputer's
/// native platform backends. Accumulates discovered devices in state.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final pigeon.DiveComputerService _service;
  StreamSubscription<pigeon.DiscoveredDevice>? _discoverySubscription;
  StreamSubscription<void>? _discoveryCompleteSubscription;

  DiscoveryNotifier({required pigeon.DiveComputerService service})
    : _service = service,
      super(const DiscoveryState()) {
    _discoveryCompleteSubscription = _service.discoveryComplete.listen((_) {
      state = state.copyWith(isScanning: false);
    });
  }

  /// Start scanning for devices via BLE.
  Future<void> startScan() async {
    try {
      state = state.copyWith(
        isScanning: true,
        clearError: true,
        discoveredDevices: [],
      );

      _discoverySubscription?.cancel();
      _discoverySubscription = _service.discoveredDevices.listen(
        _onDeviceDiscovered,
      );

      await _service.startDiscovery(pigeon.TransportType.ble);
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Failed to start scanning: $e',
      );
    }
  }

  void _onDeviceDiscovered(pigeon.DiscoveredDevice pigeonDevice) {
    final device = DiscoveredDevice.fromPigeon(pigeonDevice);
    final existing = state.discoveredDevices;

    // Deduplicate by address
    if (existing.any((d) => d.address == device.address)) return;

    state = state.copyWith(discoveredDevices: [...existing, device]);
  }

  /// Stop scanning.
  Future<void> stopScan() async {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _service.stopDiscovery();
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

  /// Advance to the download step.
  ///
  /// In the libdivecomputer flow, connection is handled internally
  /// during download. This just advances the wizard step.
  Future<bool> connectToDevice() async {
    if (state.selectedDevice == null) return false;
    state = state.copyWith(currentStep: DiscoveryStep.download);
    return true;
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

  /// Reset the wizard to the initial state and stop any active scan.
  void reset() {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _service.stopDiscovery();
    state = const DiscoveryState();
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _discoveryCompleteSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for the discovery notifier.
final discoveryNotifierProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
      final service = ref.watch(diveComputerServiceProvider);
      return DiscoveryNotifier(service: service);
    });
