import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/services/download_manager.dart';
import 'libdc_parser_service.dart';

/// Suunto BLE service UUID (shared with EON Steel, EON Core, D5)
const suuntoServiceUuid = '98ae7120-e62e-11e3-badd-0002a5d5c51b';

/// Suunto BLE characteristic UUIDs
/// These are the standard Suunto EON Steel/D5 characteristics
const suuntoWriteCharUuid = '98ae7121-e62e-11e3-badd-0002a5d5c51b';
const suuntoReadCharUuid = '98ae7122-e62e-11e3-badd-0002a5d5c51b';

/// HDLC protocol constants
const hdlcEnd = 0x7E;
const hdlcEsc = 0x7D;
const hdlcEscBit = 0x20;

/// Suunto protocol command IDs
const cmdInit = 0x0000;
const cmdFileOpen = 0x0010;
const cmdFileRead = 0x0110;
const cmdFileClose = 0x0210;
const cmdFileStat = 0x0710;
const cmdDirOpen = 0x0810;
const cmdDirReaddir = 0x0910;
const cmdDirClose = 0x0A10;

/// BLE packet size
const suuntoBlePacketSize = 20;

class _SuuntoBleProtocol {}

final _log = LoggerService.forClass(_SuuntoBleProtocol);

/// Protocol implementation for Suunto dive computers over BLE.
///
/// Implements the HDLC-framed protocol used by Suunto EON Steel, EON Core,
/// and D5 devices to download dive data over Bluetooth Low Energy.
///
/// The protocol uses a file-system-like approach where dives are stored
/// as files in directories on the device.
class SuuntoBleProtocol {
  final BluetoothDevice _device;

  /// Write characteristic for sending commands
  BluetoothCharacteristic? _writeCharacteristic;

  /// Read characteristic for receiving responses
  BluetoothCharacteristic? _readCharacteristic;

  StreamSubscription<List<int>>? _notifySubscription;
  final _responseController = StreamController<List<int>>.broadcast();
  final _receivedData = <int>[];

  bool _isConnected = false;
  int _sequenceNumber = 0;
  int _magic = 0x0001;
  final int _timeout = 15000; // milliseconds

  SuuntoBleProtocol(this._device);

  /// Connect to the Suunto device and discover services.
  Future<void> connect() async {
    _log.info('Connecting to Suunto device: ${_device.remoteId}');

    // Discover services
    final services = await _device.discoverServices();

    _log.info('Discovered ${services.length} services:');
    for (final service in services) {
      _log.info('  Service: ${service.uuid.str}');
    }

    // Find the Suunto service
    BluetoothService? suuntoService;
    for (final service in services) {
      final uuid = service.uuid.str.toLowerCase();
      if (uuid == suuntoServiceUuid) {
        suuntoService = service;
        _log.info('Found Suunto service: $uuid');
        break;
      }
    }

    if (suuntoService == null) {
      throw DownloadException(
        'Suunto service not found on device. '
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

    // Find write and read characteristics
    _log.info('Looking for characteristics...');
    for (final char in suuntoService.characteristics) {
      final uuid = char.uuid.str.toLowerCase();
      final props = char.properties;
      _log.info('  Characteristic: $uuid');
      _log.info(
        '    Properties: read=${props.read}, write=${props.write}, '
        'writeNoResponse=${props.writeWithoutResponse}, '
        'notify=${props.notify}, indicate=${props.indicate}',
      );

      if (uuid == suuntoWriteCharUuid.toLowerCase()) {
        _writeCharacteristic = char;
        _log.info('    -> Write characteristic');
      }
      if (uuid == suuntoReadCharUuid.toLowerCase()) {
        _readCharacteristic = char;
        _log.info('    -> Read characteristic');
      }
    }

    if (_writeCharacteristic == null) {
      throw DownloadException(
        'Write characteristic not found. '
        'Available: ${suuntoService.characteristics.map((c) => c.uuid.str).join(", ")}',
        phase: DownloadPhase.connecting,
      );
    }

    if (_readCharacteristic == null) {
      throw DownloadException(
        'Read characteristic not found. '
        'Available: ${suuntoService.characteristics.map((c) => c.uuid.str).join(", ")}',
        phase: DownloadPhase.connecting,
      );
    }

    // Enable notifications on the read characteristic
    _log.info('Enabling notifications on read characteristic...');
    final readProps = _readCharacteristic!.properties;

    if (readProps.notify || readProps.indicate) {
      await _readCharacteristic!.setNotifyValue(true);
      _notifySubscription =
          _readCharacteristic!.onValueReceived.listen(_onDataReceived);
      _log.info(
        'Notifications enabled (notify=${readProps.notify}, indicate=${readProps.indicate})',
      );
    } else {
      _log.warning(
        'Read characteristic does not support notify or indicate!',
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));

    _isConnected = true;
    _sequenceNumber = 0;
    _magic = 0x0001;
    _log.info('Connected to Suunto device');

    // Initialize the connection
    await _initializeDevice();
  }

  void _onDataReceived(List<int> data) {
    _log.info(
      'Received ${data.length} bytes: '
      '${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    _receivedData.addAll(data);
    _tryParseHdlcFrame();
  }

  void _tryParseHdlcFrame() {
    // Look for HDLC frame boundaries (0x7E...0x7E)
    final startIndex = _receivedData.indexOf(hdlcEnd);
    if (startIndex == -1) return;

    // Find the end of the frame
    final endIndex = _receivedData.indexOf(hdlcEnd, startIndex + 1);
    if (endIndex == -1) return;

    // Extract the frame content
    final frameData = _receivedData.sublist(startIndex + 1, endIndex);
    _receivedData.removeRange(0, endIndex + 1);

    if (frameData.isEmpty) {
      return;
    }

    // Decode HDLC escaping
    final decoded = _decodeHdlc(frameData);
    if (decoded.isNotEmpty) {
      _responseController.add(decoded);
    }
  }

  List<int> _decodeHdlc(List<int> data) {
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      final byte = data[i];
      if (byte == hdlcEsc) {
        i++;
        if (i < data.length) {
          result.add(data[i] ^ hdlcEscBit);
        }
      } else {
        result.add(byte);
      }
      i++;
    }

    return result;
  }

  List<int> _encodeHdlc(List<int> data) {
    final result = <int>[hdlcEnd];

    for (final byte in data) {
      if (byte == hdlcEnd || byte == hdlcEsc) {
        result.add(hdlcEsc);
        result.add(byte ^ hdlcEscBit);
      } else {
        result.add(byte);
      }
    }

    result.add(hdlcEnd);
    return result;
  }

  /// Send a command and wait for response.
  Future<List<int>> transfer(int command, [List<int>? payload]) async {
    if (!_isConnected) {
      throw const DownloadException(
        'Not connected to device',
        phase: DownloadPhase.downloading,
      );
    }

    final data = payload ?? [];
    _sequenceNumber++;

    // Build command packet
    // Format: [cmd_low, cmd_high, magic(4), seq_low, seq_high, len(4), data...]
    final packet = <int>[
      command & 0xFF,
      (command >> 8) & 0xFF,
      _magic & 0xFF,
      (_magic >> 8) & 0xFF,
      (_magic >> 16) & 0xFF,
      (_magic >> 24) & 0xFF,
      _sequenceNumber & 0xFF,
      (_sequenceNumber >> 8) & 0xFF,
      data.length & 0xFF,
      (data.length >> 8) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 24) & 0xFF,
      ...data,
    ];

    // Add CRC32
    final crc = _calculateCrc32(packet);
    packet.addAll([
      crc & 0xFF,
      (crc >> 8) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 24) & 0xFF,
    ]);

    _log.info(
      'Sending command 0x${command.toRadixString(16)}, '
      'seq=$_sequenceNumber, payload=${data.length} bytes',
    );

    // Encode with HDLC
    final encoded = _encodeHdlc(packet);

    // Clear any stale data
    _receivedData.clear();

    // Subscribe to response before sending
    final responseFuture = _responseController.stream.first.timeout(
      Duration(milliseconds: _timeout),
      onTimeout: () => throw TimeoutException('Response timeout'),
    );

    // Write in chunks
    for (var i = 0; i < encoded.length; i += suuntoBlePacketSize) {
      final chunk = encoded.sublist(
        i,
        (i + suuntoBlePacketSize).clamp(0, encoded.length),
      );
      await _writeCharacteristic!.write(chunk, withoutResponse: false);
    }

    // Wait for response
    try {
      final response = await responseFuture;
      _log.info('Got response: ${response.length} bytes');

      // Update magic from response (increments by 5)
      if (response.length >= 6) {
        _magic = response[2] |
            (response[3] << 8) |
            (response[4] << 16) |
            (response[5] << 24);
      }

      return response;
    } on TimeoutException {
      _log.warning('Response timeout after ${_timeout}ms');
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

  int _calculateCrc32(List<int> data) {
    // CRC-32 (IEEE 802.3 polynomial)
    const polynomial = 0xEDB88320;
    var crc = 0xFFFFFFFF;

    for (final byte in data) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ polynomial;
        } else {
          crc >>= 1;
        }
      }
    }

    return crc ^ 0xFFFFFFFF;
  }

  Future<void> _initializeDevice() async {
    _log.info('Initializing Suunto device...');
    await transfer(cmdInit);
    _log.info('Device initialized');
  }

  /// Download the list of dives from the device.
  Future<List<SuuntoDiveEntry>> downloadManifest() async {
    _log.info('Downloading dive manifest');

    final entries = <SuuntoDiveEntry>[];

    // Open the dive directory
    const dirPath = 'Dives';
    final openResult = await _openDirectory(dirPath);
    if (!openResult) {
      _log.warning('Failed to open Dives directory');
      return entries;
    }

    // Read directory entries
    while (true) {
      final entry = await _readDirectoryEntry();
      if (entry == null) break;

      if (entry.isFile && entry.name.endsWith('.bin')) {
        // Parse dive number from filename (e.g., "0001.bin")
        final diveNumber = int.tryParse(
          entry.name.replaceAll('.bin', ''),
        );

        entries.add(
          SuuntoDiveEntry(
            filename: entry.name,
            path: '$dirPath/${entry.name}',
            diveNumber: diveNumber ?? entries.length + 1,
            fileSize: entry.size,
          ),
        );
        _log.info('Found dive: ${entry.name}, size=${entry.size}');
      }
    }

    await _closeDirectory();

    _log.info('Found ${entries.length} dives in manifest');
    return entries;
  }

  Future<bool> _openDirectory(String path) async {
    final pathBytes = Uint8List.fromList(path.codeUnits);
    final response = await transfer(cmdDirOpen, pathBytes.toList());

    // Check for success (response code 0 at offset 0)
    return response.isNotEmpty && response[0] == 0;
  }

  Future<_DirectoryEntry?> _readDirectoryEntry() async {
    final response = await transfer(cmdDirReaddir);

    if (response.isEmpty || response[0] != 0) {
      return null; // End of directory or error
    }

    // Parse directory entry
    // Format varies, but typically: status(1), type(1), size(4), name...
    if (response.length < 7) return null;

    final isFile = response[1] == 0; // 0 = file, 1 = directory
    final size = response[2] |
        (response[3] << 8) |
        (response[4] << 16) |
        (response[5] << 24);
    final nameBytes = response.sublist(6);
    final name = String.fromCharCodes(
      nameBytes.takeWhile((b) => b != 0),
    );

    return _DirectoryEntry(name: name, isFile: isFile, size: size);
  }

  Future<void> _closeDirectory() async {
    await transfer(cmdDirClose);
  }

  /// Download a single dive's data.
  Future<DownloadedDive> downloadDive(SuuntoDiveEntry entry) async {
    _log.info('Downloading dive ${entry.diveNumber}: ${entry.path}');

    // Open the file
    final pathBytes = Uint8List.fromList(entry.path.codeUnits);
    final openResponse = await transfer(cmdFileOpen, pathBytes.toList());
    if (openResponse.isEmpty || openResponse[0] != 0) {
      throw DownloadException(
        'Failed to open dive file: ${entry.path}',
        phase: DownloadPhase.downloading,
      );
    }

    // Read the file in chunks
    final data = <int>[];
    const chunkSize = 1024;

    while (data.length < entry.fileSize) {
      final remaining = entry.fileSize - data.length;
      final toRead = remaining > chunkSize ? chunkSize : remaining;

      final offset = data.length;
      final readPayload = [
        offset & 0xFF,
        (offset >> 8) & 0xFF,
        (offset >> 16) & 0xFF,
        (offset >> 24) & 0xFF,
        toRead & 0xFF,
        (toRead >> 8) & 0xFF,
        (toRead >> 16) & 0xFF,
        (toRead >> 24) & 0xFF,
      ];

      final readResponse = await transfer(cmdFileRead, readPayload);
      if (readResponse.isEmpty || readResponse[0] != 0) {
        break;
      }

      // Skip status byte
      data.addAll(readResponse.sublist(1));
    }

    // Close the file
    await transfer(cmdFileClose);

    _log.info('Downloaded ${data.length} bytes of dive data');

    return _parseDive(entry, data);
  }

  DownloadedDive _parseDive(SuuntoDiveEntry entry, List<int> data) {
    _log.info('Parsing dive data: ${data.length} bytes');

    // Try to parse using libdivecomputer's parser
    try {
      final parserService = LibdcParserService.instance;

      if (!parserService.isInitialized) {
        _log.info('Initializing libdivecomputer parser service');
        parserService.initialize();
      }

      // Create manifest info
      final manifestInfo = DiveManifestInfo(
        diveNumber: entry.diveNumber,
        dateTime: DateTime.now(), // Will be overridden by parser
        durationSeconds: 0,
        maxDepth: 0,
      );

      // Determine product name based on device
      // TODO: Get actual product from device info
      const product = 'EON Steel';

      final parsedDive = parserService.parseDiveData(
        vendor: 'Suunto',
        product: product,
        data: data,
        manifestInfo: manifestInfo,
      );

      if (parsedDive != null) {
        _log.info(
          'Successfully parsed dive ${entry.diveNumber} with '
          '${parsedDive.profile.length} profile samples',
        );
        return parsedDive;
      }

      _log.warning('libdivecomputer parser returned null');
    } catch (e, stack) {
      _log.warning('Failed to parse with libdivecomputer: $e', e, stack);
    }

    // Fallback to minimal dive data
    return _createMinimalDive(entry);
  }

  DownloadedDive _createMinimalDive(SuuntoDiveEntry entry) {
    _log.info('Creating minimal dive from entry (no profile data)');
    return DownloadedDive(
      diveNumber: entry.diveNumber,
      startTime: DateTime.now(),
      durationSeconds: 0,
      maxDepth: 0,
      profile: [],
    );
  }

  /// Disconnect from the device.
  Future<void> disconnect() async {
    _isConnected = false;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _receivedData.clear();
    _log.info('Disconnected from Suunto device');
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _responseController.close();
  }
}

/// Represents a dive entry from the Suunto device.
class SuuntoDiveEntry {
  final String filename;
  final String path;
  final int diveNumber;
  final int fileSize;

  SuuntoDiveEntry({
    required this.filename,
    required this.path,
    required this.diveNumber,
    required this.fileSize,
  });
}

class _DirectoryEntry {
  final String name;
  final bool isFile;
  final int size;

  _DirectoryEntry({
    required this.name,
    required this.isFile,
    required this.size,
  });
}
