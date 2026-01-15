import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:submersion/features/dive_computer/domain/services/connection_manager.dart';

/// Service for handling Bluetooth and location permissions.
///
/// Different platforms have different permission requirements:
/// - Android 12+: BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION
/// - iOS: Bluetooth (handled by system)
/// - macOS: Bluetooth entitlement
/// - Windows/Linux: No special permissions needed
class DiveComputerPermissionsService {
  /// Check if all required permissions are granted.
  Future<bool> hasAllPermissions() async {
    if (kIsWeb) return false; // Web not supported

    if (Platform.isAndroid) {
      final bluetooth = await Permission.bluetooth.isGranted;
      final bluetoothScan = await Permission.bluetoothScan.isGranted;
      final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
      final location = await Permission.locationWhenInUse.isGranted;
      return bluetooth && bluetoothScan && bluetoothConnect && location;
    }

    if (Platform.isIOS) {
      final bluetooth = await Permission.bluetooth.isGranted;
      return bluetooth;
    }

    // macOS, Windows, Linux don't require explicit permissions
    return true;
  }

  /// Request all required permissions.
  ///
  /// Returns true if all permissions were granted.
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      throw const PermissionDeniedException(
        'bluetooth',
        'Bluetooth is not supported on web',
      );
    }

    if (Platform.isAndroid) {
      return await _requestAndroidPermissions();
    }

    if (Platform.isIOS) {
      return await _requestIOSPermissions();
    }

    // macOS, Windows, Linux
    return true;
  }

  Future<bool> _requestAndroidPermissions() async {
    // Android 12+ requires explicit Bluetooth permissions
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      // Check which permissions were denied
      final denied = <String>[];
      if (!statuses[Permission.bluetooth]!.isGranted) {
        denied.add('Bluetooth');
      }
      if (!statuses[Permission.bluetoothScan]!.isGranted) {
        denied.add('Bluetooth Scan');
      }
      if (!statuses[Permission.bluetoothConnect]!.isGranted) {
        denied.add('Bluetooth Connect');
      }
      if (!statuses[Permission.locationWhenInUse]!.isGranted) {
        denied.add('Location');
      }

      throw PermissionDeniedException(
        denied.join(', '),
        'Please grant the required permissions in Settings',
      );
    }

    return true;
  }

  Future<bool> _requestIOSPermissions() async {
    final status = await Permission.bluetooth.request();

    if (!status.isGranted) {
      throw const PermissionDeniedException(
        'Bluetooth',
        'Please enable Bluetooth access in Settings',
      );
    }

    return true;
  }

  /// Check if Bluetooth is available and enabled.
  Future<BluetoothAvailability> checkBluetoothAvailability() async {
    try {
      // Check if Bluetooth is supported
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        return BluetoothAvailability.notSupported;
      }

      // Wait for a definitive adapter state (skip 'unknown' states)
      // The Bluetooth stack may take a moment to initialize on some platforms
      final state = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => BluetoothAdapterState.unknown,
          );

      switch (state) {
        case BluetoothAdapterState.on:
          return BluetoothAvailability.available;
        case BluetoothAdapterState.off:
          return BluetoothAvailability.disabled;
        case BluetoothAdapterState.unavailable:
          return BluetoothAvailability.notSupported;
        case BluetoothAdapterState.unauthorized:
          return BluetoothAvailability.unauthorized;
        default:
          return BluetoothAvailability.unknown;
      }
    } catch (e) {
      return BluetoothAvailability.unknown;
    }
  }

  /// Request the user to enable Bluetooth.
  ///
  /// Only works on Android. Returns true if Bluetooth is now on.
  Future<bool> requestEnableBluetooth() async {
    try {
      // Only supported on Android
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }

      // Wait a moment for Bluetooth to enable
      await Future.delayed(const Duration(milliseconds: 500));

      final availability = await checkBluetoothAvailability();
      return availability == BluetoothAvailability.available;
    } catch (e) {
      return false;
    }
  }

  /// Open the app settings page for the user to enable permissions.
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Open the Bluetooth settings page.
  Future<void> openBluetoothSettings() async {
    // This is platform-specific and may not work on all platforms
    if (Platform.isAndroid) {
      // On Android, we can try to turn on Bluetooth
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        // If that fails, open settings
        await openSettings();
      }
    } else {
      // On iOS/macOS, we can only suggest the user open settings
      await openSettings();
    }
  }
}

/// Bluetooth availability status.
enum BluetoothAvailability {
  /// Bluetooth is available and enabled
  available,

  /// Bluetooth is supported but turned off
  disabled,

  /// Bluetooth is not supported on this device
  notSupported,

  /// App is not authorized to use Bluetooth
  unauthorized,

  /// Unknown state
  unknown,
}
