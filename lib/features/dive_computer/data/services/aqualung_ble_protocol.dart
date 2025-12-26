import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/services/download_manager.dart';
import 'libdc_parser_service.dart';

/// Aqualung/Pelagic BLE service UUIDs
/// These devices use a UART-like service for communication
const aqualungServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
const aqualungCharUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

/// Alternative service UUID (some models)
const aqualungAltServiceUuid = '0000ffaa-0000-1000-8000-00805f9b34fb';
const aqualungAltCharUuid = '0000ffab-0000-1000-8000-00805f9b34fb';

/// Protocol constants
const packetStart = 0xCD;
const flagRequest = 0x40;
const flagData = 0x80;
const flagLast = 0xC0;

/// Command codes
const cmdAccessRequest = 0xFA;
const cmdAccessCode = 0xFB;
const cmdAuthenticate = 0x97;
const cmdWakeupReadOnly = 0x21;
const cmdWakeupReadWrite = 0x22;
const cmdFlashRead = 0x0D;
const cmdHardwareCalibration = 0x27;

class _AqualungBleProtocol {}

final _log = LoggerService.forClass(_AqualungBleProtocol);

/// Protocol implementation for Aqualung/Pelagic dive computers over BLE.
///
/// Implements the packet-based protocol used by Aqualung i300C, i330R, i550,
/// i770R, and Apeks DSX devices to download dive data over Bluetooth Low Energy.
///
/// Note: These devices use a proprietary PIN-based pairing mechanism that
/// differs from standard Bluetooth pairing. The device displays a PIN code
/// that must be entered to establish the connection.
class AqualungBleProtocol {
  final BluetoothDevice _device;

  BluetoothCharacteristic? _txRxCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  final _responseController = StreamController<List<int>>.broadcast();
  final _receivedData = <int>[];

  bool _isConnected = false;
  final int _timeout = 15000; // milliseconds

  // Device info
  String? _deviceId;
  int _model = 0;

  /// PIN code callback - called when device displays a PIN
  /// The application should prompt the user for this PIN
  Future<String?> Function()? onPinRequired;

  AqualungBleProtocol(this._device);

  /// Connect to the Aqualung device and discover services.
  Future<void> connect() async {
    _log.info('Connecting to Aqualung device: ${_device.remoteId}');

    // Discover services
    final services = await _device.discoverServices();

    _log.info('Discovered ${services.length} services:');
    for (final service in services) {
      _log.info('  Service: ${service.uuid.str}');
    }

    // Find the Aqualung service (try both UUIDs)
    BluetoothService? aqualungService;
    String? serviceUuid;
    String? charUuid;

    for (final service in services) {
      final uuid = service.uuid.str.toLowerCase();
      if (uuid == aqualungServiceUuid) {
        aqualungService = service;
        serviceUuid = aqualungServiceUuid;
        charUuid = aqualungCharUuid;
        _log.info('Found Aqualung FFE0 service');
        break;
      }
      if (uuid == aqualungAltServiceUuid) {
        aqualungService = service;
        serviceUuid = aqualungAltServiceUuid;
        charUuid = aqualungAltCharUuid;
        _log.info('Found Aqualung FFAA service');
        break;
      }
    }

    if (aqualungService == null || charUuid == null) {
      throw DownloadException(
        'Aqualung service not found on device. '
        'Available services: ${services.map((s) => s.uuid.str).join(", ")}',
        phase: DownloadPhase.connecting,
      );
    }

    // Request larger MTU
    _log.info('Requesting MTU...');
    try {
      final mtu = await _device.requestMtu(512);
      _log.info('MTU negotiated: $mtu');
    } catch (e) {
      _log.warning('MTU request failed: $e');
    }

    // Find the TX/RX characteristic
    _log.info('Looking for characteristic: $charUuid');
    for (final char in aqualungService.characteristics) {
      final uuid = char.uuid.str.toLowerCase();
      _log.info('  Characteristic: $uuid');

      if (uuid == charUuid.toLowerCase()) {
        _txRxCharacteristic = char;
        _log.info('    -> TX/RX characteristic found');
        break;
      }
    }

    if (_txRxCharacteristic == null) {
      throw DownloadException(
        'TX/RX characteristic not found for service $serviceUuid',
        phase: DownloadPhase.connecting,
      );
    }

    // Enable notifications
    _log.info('Enabling notifications...');
    final props = _txRxCharacteristic!.properties;

    if (props.notify || props.indicate) {
      await _txRxCharacteristic!.setNotifyValue(true);
      _notifySubscription =
          _txRxCharacteristic!.onValueReceived.listen(_onDataReceived);
      _log.info('Notifications enabled');
    } else {
      _log.warning('Characteristic does not support notify!');
    }

    await Future.delayed(const Duration(milliseconds: 300));

    _isConnected = true;
    _log.info('Connected to Aqualung device');

    // Perform authentication handshake
    await _authenticate();
  }

  void _onDataReceived(List<int> data) {
    _log.info(
      'Received ${data.length} bytes: '
      '${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    _receivedData.addAll(data);
    _tryParsePacket();
  }

  void _tryParsePacket() {
    // Look for packet start byte
    final startIndex = _receivedData.indexOf(packetStart);
    if (startIndex == -1) return;

    // Need at least header (start + flag + cmd + len) = 4 bytes
    if (_receivedData.length < startIndex + 4) return;

    // Packet format: [start, flag, cmd, length, ...payload, crc_hi, crc_lo]
    final length = _receivedData[startIndex + 3];
    final totalLength = 4 + length + 2; // header + payload + checksum

    if (_receivedData.length < startIndex + totalLength) return;

    // Extract packet
    final packet = _receivedData.sublist(startIndex, startIndex + totalLength);
    _receivedData.removeRange(0, startIndex + totalLength);

    // Verify checksum
    if (!_verifyChecksum(packet)) {
      _log.warning('Checksum verification failed');
      return;
    }

    // Extract payload (skip header, exclude checksum)
    final payload = packet.sublist(4, packet.length - 2);
    _responseController.add(payload);
  }

  bool _verifyChecksum(List<int> packet) {
    if (packet.length < 6) return false;

    // CRC-16-CCITT on the packet data (excluding checksum bytes)
    final data = packet.sublist(0, packet.length - 2);
    final expectedCrc = (packet[packet.length - 2] << 8) | packet[packet.length - 1];
    final calculatedCrc = _calculateCrc16(data);

    return expectedCrc == calculatedCrc;
  }

  int _calculateCrc16(List<int> data) {
    // CRC-16-CCITT
    var crc = 0xFFFF;
    const polynomial = 0x1021;

    for (final byte in data) {
      crc ^= (byte << 8);
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc;
  }

  List<int> _buildPacket(int flag, int command, [List<int>? payload]) {
    final data = payload ?? [];
    final packet = <int>[
      packetStart,
      flag,
      command,
      data.length,
      ...data,
    ];

    // Add CRC-16
    final crc = _calculateCrc16(packet);
    packet.add((crc >> 8) & 0xFF);
    packet.add(crc & 0xFF);

    return packet;
  }

  Future<List<int>> transfer(int flag, int command, [List<int>? payload]) async {
    if (!_isConnected) {
      throw const DownloadException(
        'Not connected to device',
        phase: DownloadPhase.downloading,
      );
    }

    final packet = _buildPacket(flag, command, payload);

    _log.info(
      'Sending cmd 0x${command.toRadixString(16)}: '
      '${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    // Clear stale data
    _receivedData.clear();

    // Subscribe before sending
    final responseFuture = _responseController.stream.first.timeout(
      Duration(milliseconds: _timeout),
      onTimeout: () => throw TimeoutException('Response timeout'),
    );

    // Write packet
    await _txRxCharacteristic!.write(packet, withoutResponse: false);

    try {
      final response = await responseFuture;
      _log.info('Got response: ${response.length} bytes');
      return response;
    } on TimeoutException {
      _log.warning('Response timeout');
      throw const DownloadException(
        'Communication error: Response timeout',
        phase: DownloadPhase.downloading,
      );
    } catch (e) {
      throw DownloadException(
        'Communication error: $e',
        phase: DownloadPhase.downloading,
        originalError: e,
      );
    }
  }

  Future<void> _authenticate() async {
    _log.info('Starting authentication...');

    // Step 1: Request access
    try {
      final accessResponse = await transfer(flagRequest, cmdAccessRequest);
      _log.info('Access response: ${accessResponse.length} bytes');

      // If access denied, device will display PIN
      if (accessResponse.isEmpty || accessResponse[0] != 0x00) {
        _log.info('Access denied, PIN required');

        // Request PIN from user
        String? pin;
        if (onPinRequired != null) {
          pin = await onPinRequired!();
        }

        if (pin == null || pin.isEmpty) {
          throw const DownloadException(
            'PIN required but not provided. '
            'Check the dive computer display for the PIN code.',
            phase: DownloadPhase.connecting,
          );
        }

        // Send PIN
        final pinBytes = pin.codeUnits;
        final pinResponse = await transfer(flagRequest, cmdAccessCode, pinBytes);

        if (pinResponse.isEmpty || pinResponse[0] != 0x00) {
          throw const DownloadException(
            'PIN authentication failed. Please verify the PIN code.',
            phase: DownloadPhase.connecting,
          );
        }
      }
    } catch (e) {
      if (e is DownloadException) rethrow;
      _log.warning('Access request failed: $e, trying wakeup directly...');
    }

    // Step 2: Wakeup handshake
    final wakeupResponse = await transfer(flagRequest, cmdWakeupReadOnly);
    if (wakeupResponse.length >= 4) {
      _deviceId = wakeupResponse
          .take(4)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      _log.info('Device ID: $_deviceId');
    }

    // Step 3: Determine model and authenticate
    if (wakeupResponse.length >= 5) {
      _model = wakeupResponse[4];
      _log.info('Model code: $_model');
    }

    final authPayload = _getAuthPayload();
    final authResponse = await transfer(flagRequest, cmdAuthenticate, authPayload);
    if (authResponse.isEmpty || authResponse[0] != 0x00) {
      _log.warning('Authentication response: $authResponse');
    }

    _log.info('Authentication complete');
  }

  List<int> _getAuthPayload() {
    // Model-specific authentication payload
    // These are placeholder values - actual values depend on the specific model
    return [0x00, 0x00, 0x00, 0x00];
  }

  /// Download dives from the device.
  Future<List<DownloadedDive>> downloadDives() async {
    _log.info('Downloading dive data...');

    // Read hardware calibration to get memory layout
    final calibResponse = await transfer(flagRequest, cmdHardwareCalibration);
    _log.info('Calibration data: ${calibResponse.length} bytes');

    // Read flash memory containing dive data
    // This is a simplified implementation - actual memory layout is device-specific
    final diveData = await _readFlashMemory();

    if (diveData.isEmpty) {
      _log.warning('No dive data read from device');
      return [];
    }

    return _parseDives(diveData);
  }

  Future<List<int>> _readFlashMemory() async {
    final data = <int>[];
    const chunkSize = 128;
    const maxSize = 0x10000; // 64KB - adjust based on device

    var address = 0;
    while (address < maxSize) {
      final addressBytes = [
        (address >> 16) & 0xFF,
        (address >> 8) & 0xFF,
        address & 0xFF,
        chunkSize,
      ];

      try {
        final response = await transfer(flagRequest, cmdFlashRead, addressBytes);

        if (response.isEmpty) break;

        data.addAll(response);
        address += chunkSize;

        // Check for end of data (all 0xFF)
        if (response.every((b) => b == 0xFF)) {
          _log.info('End of data detected at address 0x${address.toRadixString(16)}');
          break;
        }
      } catch (e) {
        _log.warning('Flash read failed at 0x${address.toRadixString(16)}: $e');
        break;
      }
    }

    _log.info('Read ${data.length} bytes from flash');
    return data;
  }

  List<DownloadedDive> _parseDives(List<int> data) {
    _log.info('Parsing dive data: ${data.length} bytes');

    final dives = <DownloadedDive>[];

    try {
      final parserService = LibdcParserService.instance;

      if (!parserService.isInitialized) {
        _log.info('Initializing libdivecomputer parser service');
        parserService.initialize();
      }

      // Parse using libdivecomputer's Pelagic parser
      final parsedDive = parserService.parseDiveData(
        vendor: 'Aqualung',
        product: 'i330R', // TODO: Use actual model
        data: data,
      );

      if (parsedDive != null) {
        dives.add(parsedDive);
        _log.info(
          'Successfully parsed dive with ${parsedDive.profile.length} samples',
        );
      }
    } catch (e, stack) {
      _log.warning('Failed to parse dives: $e', e, stack);
    }

    return dives;
  }

  /// Disconnect from the device.
  Future<void> disconnect() async {
    _isConnected = false;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _receivedData.clear();
    _log.info('Disconnected from Aqualung device');
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _responseController.close();
  }
}
