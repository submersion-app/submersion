import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/services/download_manager.dart';
import 'libdc_parser_service.dart';

/// Mares BLE service UUID (same as Suunto for bluelink devices)
const maresServiceUuid = '98ae7120-e62e-11e3-badd-0002a5d5c51b';

/// Mares BLE characteristic UUIDs
const maresWriteCharUuid = '98ae7121-e62e-11e3-badd-0002a5d5c51b';
const maresReadCharUuid = '98ae7122-e62e-11e3-badd-0002a5d5c51b';

/// Mares protocol commands
const cmdVersion = 0xC2;
const cmdRead = 0xE7;
const cmdFlashSize = 0xB3;

/// Protocol constants
const maxPacketSize = 244;
const ack = 0x55;
const nak = 0xAA;
const startByte = 0xEA;
const endByte = 0xE5;

class _MaresBleProtocol {}

final _log = LoggerService.forClass(_MaresBleProtocol);

/// Protocol implementation for Mares dive computers over BLE.
///
/// Implements the packet-based protocol used by Mares dive computers
/// (Smart, Puck Pro, Quad, etc.) to download dive data over Bluetooth
/// Low Energy via the Blue Link adapter.
class MaresBleProtocol {
  final BluetoothDevice _device;

  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;

  StreamSubscription<List<int>>? _notifySubscription;
  final _responseController = StreamController<List<int>>.broadcast();
  final _receivedData = <int>[];

  bool _isConnected = false;
  final int _timeout = 10000; // milliseconds

  // Device info
  String? _model;
  int _memorySize = 0;

  MaresBleProtocol(this._device);

  /// Connect to the Mares device and discover services.
  Future<void> connect() async {
    _log.info('Connecting to Mares device: ${_device.remoteId}');

    // Discover services
    final services = await _device.discoverServices();

    _log.info('Discovered ${services.length} services:');
    for (final service in services) {
      _log.info('  Service: ${service.uuid.str}');
    }

    // Find the Mares service
    BluetoothService? maresService;
    for (final service in services) {
      final uuid = service.uuid.str.toLowerCase();
      if (uuid == maresServiceUuid) {
        maresService = service;
        _log.info('Found Mares service: $uuid');
        break;
      }
    }

    if (maresService == null) {
      throw DownloadException(
        'Mares service not found on device. '
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

    // Find characteristics
    _log.info('Looking for characteristics...');
    for (final char in maresService.characteristics) {
      final uuid = char.uuid.str.toLowerCase();
      final props = char.properties;
      _log.info('  Characteristic: $uuid');
      _log.info(
        '    Properties: read=${props.read}, write=${props.write}, '
        'notify=${props.notify}',
      );

      if (uuid == maresWriteCharUuid.toLowerCase()) {
        _writeCharacteristic = char;
        _log.info('    -> Write characteristic');
      }
      if (uuid == maresReadCharUuid.toLowerCase()) {
        _readCharacteristic = char;
        _log.info('    -> Read characteristic');
      }
    }

    if (_writeCharacteristic == null) {
      throw const DownloadException(
        'Write characteristic not found.',
        phase: DownloadPhase.connecting,
      );
    }

    if (_readCharacteristic == null) {
      throw const DownloadException(
        'Read characteristic not found.',
        phase: DownloadPhase.connecting,
      );
    }

    // Enable notifications
    _log.info('Enabling notifications...');
    final readProps = _readCharacteristic!.properties;

    if (readProps.notify || readProps.indicate) {
      await _readCharacteristic!.setNotifyValue(true);
      _notifySubscription =
          _readCharacteristic!.onValueReceived.listen(_onDataReceived);
      _log.info('Notifications enabled');
    }

    await Future.delayed(const Duration(milliseconds: 300));

    _isConnected = true;
    _log.info('Connected to Mares device');

    // Get device info
    await _getDeviceInfo();
  }

  void _onDataReceived(List<int> data) {
    _log.info(
      'Received ${data.length} bytes: '
      '${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    _receivedData.addAll(data);
    _tryParseResponse();
  }

  void _tryParseResponse() {
    // Look for start byte
    final startIndex = _receivedData.indexOf(startByte);
    if (startIndex == -1) return;

    // Need at least header + end byte
    if (_receivedData.length < startIndex + 3) return;

    // Get length from header
    final length = _receivedData[startIndex + 1];
    final totalLength = length + 3; // start + length + data + checksum + end

    if (_receivedData.length < startIndex + totalLength) return;

    // Check end byte
    if (_receivedData[startIndex + totalLength - 1] != endByte) {
      _log.warning('Invalid end byte, discarding');
      _receivedData.removeAt(0);
      return;
    }

    // Extract packet
    final packet = _receivedData.sublist(startIndex, startIndex + totalLength);
    _receivedData.removeRange(0, startIndex + totalLength);

    // Verify checksum
    if (!_verifyChecksum(packet)) {
      _log.warning('Checksum failed');
      return;
    }

    // Extract payload (skip start, length, checksum, end)
    final payload = packet.sublist(2, packet.length - 2);
    _responseController.add(payload);
  }

  bool _verifyChecksum(List<int> packet) {
    if (packet.length < 4) return false;

    var xorSum = 0;
    for (var i = 1; i < packet.length - 2; i++) {
      xorSum ^= packet[i];
    }

    return xorSum == packet[packet.length - 2];
  }

  List<int> _buildPacket(List<int> data) {
    final packet = <int>[startByte, data.length, ...data];

    // Calculate XOR checksum
    var xorSum = 0;
    for (var i = 1; i < packet.length; i++) {
      xorSum ^= packet[i];
    }

    packet.add(xorSum);
    packet.add(endByte);

    return packet;
  }

  Future<List<int>> transfer(List<int> command) async {
    if (!_isConnected) {
      throw const DownloadException(
        'Not connected to device',
        phase: DownloadPhase.downloading,
      );
    }

    _log.info(
      'Sending: ${command.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    final packet = _buildPacket(command);

    // Clear stale data
    _receivedData.clear();

    // Subscribe before sending
    final responseFuture = _responseController.stream.first.timeout(
      Duration(milliseconds: _timeout),
      onTimeout: () => throw TimeoutException('Response timeout'),
    );

    // Write packet
    await _writeCharacteristic!.write(packet, withoutResponse: false);

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

  Future<void> _getDeviceInfo() async {
    _log.info('Getting device info...');

    // Get version/model
    final versionResponse = await transfer([cmdVersion]);
    if (versionResponse.isNotEmpty) {
      _model = String.fromCharCodes(
        versionResponse.takeWhile((b) => b != 0 && b >= 32),
      );
      _log.info('Device model: $_model');
    }

    // Get memory size
    final flashResponse = await transfer([cmdFlashSize]);
    if (flashResponse.length >= 4) {
      _memorySize = flashResponse[0] |
          (flashResponse[1] << 8) |
          (flashResponse[2] << 16) |
          (flashResponse[3] << 24);
      _log.info('Memory size: $_memorySize bytes');
    }
  }

  /// Download dive data from the device.
  ///
  /// Mares devices store dives in a ring buffer. This method reads the
  /// entire memory and parses individual dives from it.
  Future<List<DownloadedDive>> downloadDives() async {
    _log.info('Downloading dive data...');

    if (_memorySize == 0) {
      throw const DownloadException(
        'Unknown memory size',
        phase: DownloadPhase.downloading,
      );
    }

    // Read the dive memory
    final data = await _readMemory(0, _memorySize);
    _log.info('Downloaded ${data.length} bytes of memory');

    // Parse dives using libdivecomputer
    return _parseDives(data);
  }

  Future<List<int>> _readMemory(int address, int size) async {
    final data = <int>[];
    const chunkSize = 128; // Read in chunks

    while (data.length < size) {
      final offset = address + data.length;
      final toRead =
          (size - data.length) > chunkSize ? chunkSize : (size - data.length);

      final command = [
        cmdRead,
        offset & 0xFF,
        (offset >> 8) & 0xFF,
        (offset >> 16) & 0xFF,
        toRead & 0xFF,
      ];

      final response = await transfer(command);

      // First byte is status/ack
      if (response.isEmpty || response[0] != ack) {
        _log.warning('Read failed at offset $offset');
        break;
      }

      data.addAll(response.sublist(1));

      // Log progress periodically
      if (data.length % 1024 == 0) {
        _log.info('Read ${data.length}/$size bytes');
      }
    }

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

      // Determine product name
      final product = _model ?? 'Smart';

      // For Mares, the entire memory dump contains all dives
      // libdivecomputer's parser handles splitting them
      final parsedDive = parserService.parseDiveData(
        vendor: 'Mares',
        product: product,
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
    _log.info('Disconnected from Mares device');
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _responseController.close();
  }
}
