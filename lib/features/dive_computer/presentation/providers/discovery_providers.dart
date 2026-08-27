import 'dart:async';
import 'dart:io';

import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:permission_handler/permission_handler.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// Provider for the DiveComputerService singleton.
final diveComputerServiceProvider = Provider<pigeon.DiveComputerService>((ref) {
  final service = pigeon.DiveComputerService();
  pigeon.DiveComputerFlutterApi.setUp(service);

  const nativeLog = LoggerService('Native');
  service.logEvents.listen((event) {
    final category = LogCategory.fromTag(event.category);
    if (category == null) return;
    switch (event.level) {
      case 'DEBUG':
        nativeLog.debug(event.message, category: category);
      case 'INFO':
        nativeLog.info(event.message, category: category);
      case 'WARN':
        nativeLog.warning(event.message, category: category);
      case 'ERROR':
        nativeLog.error(event.message, category: category);
    }
  });

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

/// Logger for the scan lifecycle.
///
/// The native scanner reports the devices it sees, but only this layer knows
/// that a scan was requested at all. Without these entries a submitted debug
/// log cannot distinguish "the user never scanned" from "the scan started and
/// found nothing" from "permissions were refused" (issue #123).
const _discoveryLog = LoggerService('Discovery');

/// Notifier for managing the discovery wizard state.
///
/// Uses DiveComputerService for BLE discovery via libdivecomputer's
/// native platform backends. Accumulates discovered devices in state.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final pigeon.DiveComputerService _service;

  /// Whether this platform gates BLE scanning behind runtime permissions.
  ///
  /// Only Android does. Injectable because a refused permission is one of the
  /// likelier reasons a scan finds nothing, and the branch that reports it is
  /// otherwise unreachable in tests, which run where `Platform.isAndroid` is
  /// false (issue #123).
  final bool _requiresRuntimePermissions;

  StreamSubscription<pigeon.DiscoveredDevice>? _discoverySubscription;
  StreamSubscription<void>? _discoveryCompleteSubscription;

  DiscoveryNotifier({
    required pigeon.DiveComputerService service,
    bool? requiresRuntimePermissions,
  }) : _service = service,
       _requiresRuntimePermissions =
           requiresRuntimePermissions ?? Platform.isAndroid,
       super(const DiscoveryState()) {
    _discoveryCompleteSubscription = _service.discoveryComplete.listen((_) {
      state = state.copyWith(isScanning: false);
    });
  }

  /// Start scanning for devices via BLE.
  Future<void> startScan() async {
    try {
      // Request Bluetooth permissions on Android before scanning.
      if (_requiresRuntimePermissions) {
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();

        final denied = statuses.entries
            .where((e) => !e.value.isGranted)
            .map((e) => e.key.toString())
            .toList();

        if (denied.isNotEmpty) {
          _discoveryLog.warning(
            'Scan blocked: Bluetooth permissions denied (${denied.join(', ')})',
            category: LogCategory.bluetooth,
          );
          state = state.copyWith(
            isScanning: false,
            errorMessage:
                'Bluetooth permissions are required to scan for dive computers. '
                'Please grant Bluetooth access in Settings.',
          );
          return;
        }
      }

      state = state.copyWith(
        isScanning: true,
        clearError: true,
        discoveredDevices: [],
      );

      _discoverySubscription?.cancel();
      _discoverySubscription = _service.discoveredDevices.listen(
        _onDeviceDiscovered,
      );

      _discoveryLog.info(
        'Starting BLE scan for dive computers',
        category: LogCategory.bluetooth,
      );
      await _service.startDiscovery(pigeon.TransportType.ble);
    } catch (e, stackTrace) {
      _discoveryLog.error(
        'Failed to start BLE scan',
        category: LogCategory.bluetooth,
        error: e,
        stackTrace: stackTrace,
      );
      // Cancel the event subscription so stray events from the native side
      // cannot mutate state after a synchronous start failure.
      _discoverySubscription?.cancel();
      _discoverySubscription = null;
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

    _discoveryLog.info(
      'Discovered ${device.name} (${device.address}) '
      'as ${pigeonDevice.vendor} ${pigeonDevice.product}',
      category: LogCategory.bluetooth,
    );
    state = state.copyWith(discoveredDevices: [...existing, device]);
  }

  /// Stop scanning.
  Future<void> stopScan() async {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _service.stopDiscovery();
    _discoveryLog.info(
      'Stopped BLE scan; '
      '${state.discoveredDevices.length} supported device(s) found',
      category: LogCategory.bluetooth,
    );
    state = state.copyWith(isScanning: false);
  }

  /// Scans until a device advertising [address] is seen, then stops.
  ///
  /// Resolves with the freshly discovered device, or with null when the scan
  /// could not start, native discovery ended, or [timeout] elapsed without
  /// seeing the address. The scan is stopped on every path.
  ///
  /// The saved-computer download path uses this to re-acquire the device
  /// before connecting. A direct connect to a stored address that the
  /// Bluetooth stack has not seen advertise recently fails on Android and
  /// Windows, while the very same address connects fine right after a scan
  /// (issue #1232). macOS and iOS re-scan natively before connecting; this
  /// gives the other platforms the same behaviour.
  Future<DiscoveredDevice?> scanForAddress(
    String address, {
    required Duration timeout,
  }) async {
    final completer = Completer<DiscoveredDevice?>();

    void check(DiscoveryState current) {
      if (completer.isCompleted) return;
      final match = current.discoveredDevices
          .where((d) => bluetoothAddressesMatch(d.address, address))
          .firstOrNull;
      if (match != null) {
        completer.complete(match);
      } else if (!current.isScanning) {
        completer.complete(null);
      }
    }

    // startScan settles isScanning before returning: true once discovery is
    // running, false (with an error message) when it could not start.
    await startScan();
    final subscription = stream.listen(check);
    check(state);
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      // Not awaited: a broadcast subscription's cancel() resolves to the
      // root-zone null future, which a fake-async widget test can never
      // flush. Cancellation itself is synchronous.
      unawaited(subscription.cancel());
      await stopScan();
    }
  }

  /// Select a device and move to the next step.
  void selectDevice(DiscoveredDevice device) {
    state = state.copyWith(
      selectedDevice: device,
      currentStep: DiscoveryStep.confirm,
    );
  }

  /// Drop the selected device without touching the rest of the state.
  ///
  /// Used when a selection left over from an earlier discovery session must
  /// not be reused, e.g. it does not carry the address of the saved computer
  /// about to be downloaded from.
  void clearSelectedDevice() {
    state = state.copyWith(clearDevice: true);
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

/// Whether two transport addresses name the same device.
///
/// Android reports colon-separated MACs and Windows colon-free hex; both are
/// stable per platform, so only letter case is normalized.
bool bluetoothAddressesMatch(String a, String b) =>
    a.toUpperCase() == b.toUpperCase();

/// Provider for the discovery notifier.
final discoveryNotifierProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
      final service = ref.watch(diveComputerServiceProvider);
      return DiscoveryNotifier(service: service);
    });
