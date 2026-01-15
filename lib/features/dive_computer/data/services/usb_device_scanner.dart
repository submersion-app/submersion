import 'dart:async';

import 'package:dive_computer/dive_computer.dart' as dc;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/data/device_library.dart';

const _log = LoggerService('UsbDeviceScanner');

/// Service for scanning and discovering USB dive computers.
///
/// Since USB devices don't advertise themselves like BLE devices,
/// this scanner provides a list of known USB-capable dive computers
/// that the user can select from. The actual device connection is
/// attempted when the user initiates a download.
class UsbDeviceScanner {
  final DeviceLibrary _deviceLibrary;

  /// Cached list of supported computers from libdivecomputer
  List<dc.Computer>? _supportedComputers;

  UsbDeviceScanner({DeviceLibrary? deviceLibrary})
    : _deviceLibrary = deviceLibrary ?? DeviceLibrary.instance;

  /// Get all USB-capable device models from the library.
  ///
  /// This returns device models that support USB connection,
  /// which the user can select from to attempt a connection.
  List<DeviceModel> getUsbCapableDevices() {
    return _deviceLibrary.getByConnectionType(DeviceConnectionType.usb);
  }

  /// Get USB-capable devices grouped by manufacturer.
  Map<String, List<DeviceModel>> getUsbDevicesByManufacturer() {
    final devices = getUsbCapableDevices();
    final grouped = <String, List<DeviceModel>>{};

    for (final device in devices) {
      grouped.putIfAbsent(device.manufacturer, () => []).add(device);
    }

    // Sort manufacturers alphabetically
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  /// Create a discovered device entry for a USB device model.
  ///
  /// Since USB devices can't be scanned like BLE, we create a
  /// "virtual" discovered device that the user selects manually.
  DiscoveredDevice createDiscoveredDevice(DeviceModel model) {
    return DiscoveredDevice(
      id: 'usb-${model.id}',
      name: model.fullName,
      connectionType: DeviceConnectionType.usb,
      address: 'USB', // Generic address for USB devices
      recognizedModel: model,
      discoveredAt: DateTime.now(),
    );
  }

  /// Check if libdivecomputer supports the given device model.
  ///
  /// This checks if there's a matching driver in libdivecomputer
  /// for the given device model.
  Future<bool> isDeviceSupported(DeviceModel model) async {
    try {
      final computers = await _getSupportedComputers();

      for (final computer in computers) {
        if (_matchesModel(computer, model)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _log.warning('Failed to check device support', e);
      return false;
    }
  }

  /// Get the list of devices supported by libdivecomputer.
  ///
  /// This queries libdivecomputer for its supported devices and
  /// filters to those that support USB/Serial transports.
  Future<List<dc.Computer>> getLibdcSupportedDevices({
    bool usbOnly = true,
  }) async {
    final computers = await _getSupportedComputers();

    if (!usbOnly) return computers;

    // Filter to devices that support USB-like transports
    return computers.where((c) {
      return c.transports.any(
        (t) =>
            t == dc.ComputerTransport.usb ||
            t == dc.ComputerTransport.usbhid ||
            t == dc.ComputerTransport.serial,
      );
    }).toList();
  }

  /// Get cached supported computers from libdivecomputer.
  Future<List<dc.Computer>> _getSupportedComputers() async {
    if (_supportedComputers != null) {
      return _supportedComputers!;
    }

    try {
      dc.DiveComputer.instance.openConnection();
      _supportedComputers = await dc.DiveComputer.instance.supportedComputers;
      return _supportedComputers!;
    } catch (e) {
      _log.error('Failed to get supported computers from libdivecomputer', e);
      rethrow;
    }
  }

  /// Check if a libdivecomputer Computer matches a DeviceModel.
  bool _matchesModel(dc.Computer computer, DeviceModel model) {
    final vendorMatch =
        computer.vendor.toLowerCase() == model.manufacturer.toLowerCase();
    final productMatch =
        computer.product.toLowerCase() == model.model.toLowerCase();

    if (vendorMatch && productMatch) return true;

    // Try partial product match
    if (vendorMatch &&
        computer.product.toLowerCase().contains(model.model.toLowerCase())) {
      return true;
    }

    return false;
  }

  /// Get USB device models that are confirmed supported by libdivecomputer.
  ///
  /// This cross-references our device library with libdivecomputer's
  /// supported devices to return only those that will actually work.
  Future<List<DeviceModel>> getConfirmedSupportedDevices() async {
    final usbDevices = getUsbCapableDevices();
    final libdcComputers = await getLibdcSupportedDevices();
    final confirmed = <DeviceModel>[];

    for (final model in usbDevices) {
      for (final computer in libdcComputers) {
        if (_matchesModel(computer, model)) {
          confirmed.add(model);
          break;
        }
      }
    }

    return confirmed;
  }

  /// Stream that emits USB device models.
  ///
  /// This is provided for UI consistency with BLE scanning,
  /// but USB devices are returned immediately since they don't
  /// require active scanning.
  Stream<DiscoveredDevice> scanForDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    _log.info('Starting USB device listing...');

    final devices = getUsbCapableDevices();
    _log.info('Found ${devices.length} USB-capable device models');

    // Emit devices one by one with a small delay for UI effect
    for (final model in devices) {
      yield createDiscoveredDevice(model);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _log.info('USB device listing complete');
  }

  void dispose() {
    // Clean up if needed
  }
}
