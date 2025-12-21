import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/services/download_manager.dart';

/// Shearwater BLE service UUID (full 128-bit custom UUID)
const shearwaterServiceUuid = 'fe25c237-0ece-443c-b0aa-e02033e7029d';

/// Shearwater BLE characteristic UUIDs
const shearwaterTxCharUuid = '27b7570b-359e-45a3-91bb-cf7e70049bd2'; // Write
const shearwaterRxCharUuid = '27b7570a-359e-45a3-91bb-cf7e70049bd2'; // Notify

/// SLIP protocol constants
const slipEnd = 0xC0;
const slipEsc = 0xDB;
const slipEscEnd = 0xDC;
const slipEscEsc = 0xDD;

/// Shearwater protocol constants
const rdbiRequest = 0x22;
const rdbiResponse = 0x62;
const nak = 0x7F;

/// Shearwater RDBI identifiers (2-byte IDs, not addresses)
const idSerial = 0x8010; // Serial number
const idLogUpload = 0x8021; // Logbook upload info (base address)

/// Shearwater manifest location (memory address) and layout
const manifestAddress = 0xE0000000; // Manifest memory address
const manifestSize = 0x600; // Size of manifest data
const recordSize = 0x20; // Size of each manifest entry
const diveDownloadSize = 0xFFFFFF; // Max dive size used by Shearwater

/// BLE packet size
const blePacketSize = 32;

class _ShearwaterBleProtocol {}

final _log = LoggerService.forClass(_ShearwaterBleProtocol);

/// Protocol implementation for Shearwater dive computers over BLE.
///
/// Implements the SLIP-encoded protocol used by Shearwater devices
/// to download dive data over Bluetooth Low Energy.
class ShearwaterBleProtocol {
  final BluetoothDevice _device;

  /// TX characteristic for writing commands
  BluetoothCharacteristic? _txCharacteristic;

  /// RX characteristic for receiving notifications
  BluetoothCharacteristic? _rxCharacteristic;

  StreamSubscription<List<int>>? _notifySubscription;
  final _responseController = StreamController<List<int>>.broadcast();
  final _receivedData = <int>[];
  int? _logUploadBaseAddress;

  bool _isConnected = false;
  final int _timeout = 10000; // milliseconds (increased for slow responses)

  ShearwaterBleProtocol(this._device);

  /// Connect to the Shearwater device and discover services.
  Future<void> connect() async {
    _log.info('Connecting to Shearwater device: ${_device.remoteId}');

    // Discover services
    final services = await _device.discoverServices();

    // Log all discovered services for debugging
    _log.info('Discovered ${services.length} services:');
    for (final service in services) {
      _log.info('  Service: ${service.uuid.str}');
    }

    // Find the Shearwater service
    BluetoothService? shearwaterService;
    for (final service in services) {
      final uuid = service.uuid.str.toLowerCase();
      if (uuid == shearwaterServiceUuid) {
        shearwaterService = service;
        _log.info('Found Shearwater service: $uuid');
        break;
      }
    }

    if (shearwaterService == null) {
      throw DownloadException(
        'Shearwater service not found on device. '
        'Available services: ${services.map((s) => s.uuid.str).join(", ")}',
        phase: DownloadPhase.connecting,
      );
    }

    // Request larger MTU for better throughput
    _log.info('Requesting MTU...');
    try {
      final mtu = await _device.requestMtu(512);
      _log.info('MTU negotiated: $mtu');
    } catch (e) {
      _log.warning('MTU request failed: $e');
    }

    // Find TX (write) and RX (notify) characteristics
    _log.info('Looking for characteristics...');
    for (final char in shearwaterService.characteristics) {
      final uuid = char.uuid.str.toLowerCase();
      final props = char.properties;
      _log.info('  Characteristic: $uuid');
      _log.info('    Properties: read=${props.read}, write=${props.write}, writeNoResponse=${props.writeWithoutResponse}, notify=${props.notify}, indicate=${props.indicate}');

      if (uuid == shearwaterTxCharUuid.toLowerCase()) {
        _txCharacteristic = char;
        _log.info('    -> TX characteristic');
      }
      if (uuid == shearwaterRxCharUuid.toLowerCase()) {
        _rxCharacteristic = char;
        _log.info('    -> RX characteristic');
      }
    }

    // If RX not found separately, use TX for both (some firmware versions)
    if (_rxCharacteristic == null && _txCharacteristic != null) {
      _log.info('RX characteristic not found, using TX for both read/write');
      _rxCharacteristic = _txCharacteristic;
    }

    if (_txCharacteristic == null) {
      throw DownloadException(
        'TX characteristic not found. '
        'Available: ${shearwaterService.characteristics.map((c) => c.uuid.str).join(", ")}',
        phase: DownloadPhase.connecting,
      );
    }

    if (_rxCharacteristic == null) {
      throw DownloadException(
        'RX characteristic not found. '
        'Available: ${shearwaterService.characteristics.map((c) => c.uuid.str).join(", ")}',
        phase: DownloadPhase.connecting,
      );
    }

    // Enable notifications on the RX characteristic
    _log.info('Enabling notifications on RX characteristic...');
    final rxProps = _rxCharacteristic!.properties;

    if (rxProps.notify || rxProps.indicate) {
      await _rxCharacteristic!.setNotifyValue(true);
      _notifySubscription =
          _rxCharacteristic!.onValueReceived.listen(_onDataReceived);
      _log.info(
          'Notifications enabled (notify=${rxProps.notify}, indicate=${rxProps.indicate})');
    } else {
      _log.warning(
          'RX characteristic does not support notify or indicate! Will try polling.');
    }

    // Give device time to stabilize after notification setup
    await Future.delayed(const Duration(milliseconds: 300));

    // Note: For BLE, we don't send wake-up bytes - the BLE frame format
    // handles synchronization via the 2-byte header [nframes, frame_index]

    _isConnected = true;
    _log.info('Connected to Shearwater device');
  }

  void _onDataReceived(List<int> data) {
    _log.info('Received ${data.length} bytes: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    // For BLE, skip the 2-byte frame header [nframes, frame_index] and
    // stream bytes until a SLIP END marker is found.
    if (data.length < 2) {
      _log.warning('BLE frame too short (${data.length} bytes), ignoring');
      return;
    }

    _receivedData.addAll(data.sublist(2));
    _tryParseResponse();
  }

  void _tryParseResponse() {
    _log.info('Parsing response buffer: ${_receivedData.length} bytes: ${_receivedData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    // Look for SLIP END byte to find complete frame
    final endIndex = _receivedData.indexOf(slipEnd);
    if (endIndex == -1) {
      _log.info('No SLIP END byte found yet, waiting for more data');
      return;
    }

    _log.info('Found SLIP END at index $endIndex');

    // Skip leading END bytes (used to flush)
    var startIndex = 0;
    while (startIndex < endIndex && _receivedData[startIndex] == slipEnd) {
      startIndex++;
    }

    if (startIndex >= endIndex) {
      // Only END bytes, clear and wait for more
      _receivedData.removeRange(0, endIndex + 1);
      return;
    }

    // Extract and decode the SLIP frame
    final frame = _receivedData.sublist(startIndex, endIndex);
    _receivedData.removeRange(0, endIndex + 1);

    _log.info('Extracted SLIP frame: ${frame.length} bytes');
    final decoded = _decodeSlip(frame);
    if (decoded.isEmpty) {
      _log.warning('Decoded frame is empty');
      return;
    }

    _log.info('Decoded SLIP: ${decoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    // Validate Shearwater packet header
    // Response format: [0x01, 0xFF, length, 0x00, ...data]
    if (decoded.length < 4) {
      _log.warning('Response too short for packet header');
      return;
    }

    if (decoded[0] != 0x01 || decoded[1] != 0xFF || decoded[3] != 0x00) {
      _log.warning('Invalid packet header: ${decoded.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return;
    }

    final length = decoded[2];
    _log.info('Packet header valid, payload length: $length');

    // Extract payload (skip 4-byte header)
    final payload = decoded.sublist(4);
    _log.info('Payload: ${payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    if (payload.isNotEmpty) {
      _responseController.add(payload);
    }
  }

  List<int> _decodeSlip(List<int> data) {
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      final byte = data[i];
      if (byte == slipEsc) {
        i++;
        if (i >= data.length) break;
        final escaped = data[i];
        if (escaped == slipEscEnd) {
          result.add(slipEnd);
        } else if (escaped == slipEscEsc) {
          result.add(slipEsc);
        }
      } else if (byte != slipEnd) {
        result.add(byte);
      }
      i++;
    }

    return result;
  }

  /// Send a command and wait for response.
  ///
  /// The command is wrapped in Shearwater's packet format:
  /// - 4-byte header: [0xFF, 0x01, length+1, 0x00]
  /// - Command data
  /// Then SLIP encoded with BLE frame headers.
  Future<List<int>> transfer(List<int> request) async {
    if (!_isConnected) {
      throw const DownloadException(
        'Not connected to device',
        phase: DownloadPhase.downloading,
      );
    }

    _log.info(
      'Sending request: ${request.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    // Build the packet with Shearwater header
    final packet = <int>[
      0xFF, // Start marker
      0x01, // Packet type (request)
      request.length + 1, // Length (including the extra byte)
      0x00, // Reserved
      ...request, // Command data
    ];

    _log.info(
      'Packet with header: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    // Encode with SLIP and BLE framing
    final encoded = _encodeSlipBle(packet);
    _log.info('Encoded ${encoded.length} bytes with SLIP+BLE framing');
    _log.info(
      'Writing: ${encoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    // Clear any stale data in the receive buffer
    _receivedData.clear();

    // Subscribe to response stream BEFORE sending (device responds very fast!)
    final responseFuture = _responseController.stream.first.timeout(
      Duration(milliseconds: _timeout),
      onTimeout: () => throw TimeoutException('Response timeout'),
    );

    // Write the frame(s)
    for (var i = 0; i < encoded.length; i += blePacketSize) {
      final chunk =
          encoded.sublist(i, (i + blePacketSize).clamp(0, encoded.length));
      await _txCharacteristic!.write(chunk, withoutResponse: false);
    }
    _log.info('Write completed, waiting for response...');

    // Wait for response
    try {
      final response = await responseFuture;
      _log.info('Got response: ${response.length} bytes');
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

  /// Encode data with SLIP and BLE framing (matching libdivecomputer).
  ///
  /// For BLE transport:
  /// - Each 32-byte frame has 2-byte header: [nframes, frame_index]
  /// - Data is SLIP-encoded (no leading END for BLE)
  /// - Frame ends with SLIP END byte (0xC0)
  /// - Frames are not padded
  List<int> _encodeSlipBle(List<int> data) {
    // Calculate total SLIP-encoded size (including trailing END) for frame count.
    var slipSize = 1; // Trailing END byte.
    for (final byte in data) {
      slipSize += (byte == slipEnd || byte == slipEsc) ? 2 : 1;
    }

    final frameCount = (slipSize + blePacketSize - 1) ~/ blePacketSize;
    _log.info('SLIP size: $slipSize bytes, frames: $frameCount');

    final result = <int>[];
    var frameIndex = 0;
    var frameBytes = 0;

    void startFrame() {
      result.add(frameCount);
      result.add(frameIndex);
      frameBytes = 2;
    }

    void addByte(int byte, {bool flushIfFull = true}) {
      result.add(byte);
      frameBytes++;
      if (flushIfFull && frameBytes >= blePacketSize) {
        frameIndex++;
        startFrame();
      }
    }

    // Start first frame with header.
    startFrame();

    // SLIP encode the data (no leading END for BLE).
    for (final byte in data) {
      if (byte == slipEnd) {
        addByte(slipEsc);
        addByte(slipEscEnd);
      } else if (byte == slipEsc) {
        addByte(slipEsc);
        addByte(slipEscEsc);
      } else {
        addByte(byte);
      }
    }

    // Add trailing END byte without flushing into a new empty frame.
    addByte(slipEnd, flushIfFull: false);

    return result;
  }

  /// Read data by identifier (RDBI command).
  /// Shearwater uses 2-byte identifiers, not 4-byte addresses.
  Future<List<int>> readById(int identifier) async {
    final request = [
      rdbiRequest,
      (identifier >> 8) & 0xFF,
      identifier & 0xFF,
    ];

    _log.info('RDBI request for ID 0x${identifier.toRadixString(16)}');
    final response = await transfer(request);

    // Validate response
    if (response.isEmpty) {
      throw const DownloadException(
        'Empty response from device',
        phase: DownloadPhase.downloading,
      );
    }

    if (response.length >= 3 &&
        response[0] == nak &&
        response[1] == rdbiRequest) {
      throw DownloadException(
        'Device returned NAK: 0x${response[2].toRadixString(16)}',
        phase: DownloadPhase.downloading,
      );
    }

    if (response.length < 3 ||
        response[0] != rdbiResponse ||
        response[1] != request[1] ||
        response[2] != request[2]) {
      throw DownloadException(
        'Unexpected response: ${response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        phase: DownloadPhase.downloading,
      );
    }

    // Skip response header (1 byte command + 2 bytes identifier)
    return response.sublist(3);
  }

  /// Download the dive manifest.
  Future<List<DiveManifestEntry>> downloadManifest() async {
    _log.info('Downloading dive manifest');

    // First, try reading serial number to verify communication works
    _log.info('Reading serial number first to verify protocol...');
    try {
      final serialData = await readById(idSerial);
      _log.info('Serial number response: ${serialData.length} bytes');
    } catch (e) {
      _log.warning('Failed to read serial: $e');
      // Continue anyway to try manifest
    }

    // Download manifest from memory address.
    final manifestData = await _downloadMemory(
      address: manifestAddress,
      size: manifestSize,
      compressed: false,
    );
    _log.info('Received ${manifestData.length} bytes of manifest data');

    final entries = <DiveManifestEntry>[];

    // Parse manifest entries (32 bytes each)
    for (var i = 0; i < manifestData.length; i += recordSize) {
      if (i + recordSize > manifestData.length) break;

      final record = manifestData.sublist(i, i + recordSize);

      // Check if record is valid (not all zeros or 0xFF)
      if (record.every((b) => b == 0) || record.every((b) => b == 0xFF)) {
        continue;
      }

      final entry = DiveManifestEntry.fromBytes(record);
      if (entry != null) {
        entries.add(entry);
      }
    }

    _log.info('Found ${entries.length} dives in manifest');
    return entries;
  }

  /// Download a single dive's data.
  Future<DownloadedDive> downloadDive(DiveManifestEntry entry) async {
    final baseAddress = await _resolveLogUploadBaseAddress();
    final absoluteAddress = baseAddress + entry.dataAddress;

    _log.info(
      'Downloading dive ${entry.diveNumber}: base=0x${baseAddress.toRadixString(16)}, '
      'offset=0x${entry.dataAddress.toRadixString(16)}, '
      'address=0x${absoluteAddress.toRadixString(16)}, '
      'size=${entry.dataSize}',
    );

    List<int> diveData;

    try {
      diveData = await _downloadMemory(
        address: absoluteAddress,
        size: diveDownloadSize,
        compressed: true,
      );
    } on DownloadException {
      if (entry.dataSize <= 0) rethrow;
      _log.info('Compressed download rejected, trying uncompressed...');
      diveData = await _downloadMemory(
        address: absoluteAddress,
        size: entry.dataSize,
        compressed: false,
      );
    }

    _log.info('Downloaded ${diveData.length} bytes of dive data');

    return _parseDive(entry, diveData);
  }

  Future<int> _resolveLogUploadBaseAddress() async {
    if (_logUploadBaseAddress != null) {
      return _logUploadBaseAddress!;
    }

    _log.info('Reading log upload base address...');
    final logUploadData = await readById(idLogUpload);
    if (logUploadData.length < 5) {
      throw DownloadException(
        'Log upload info too short: ${logUploadData.length} bytes',
        phase: DownloadPhase.downloading,
      );
    }

    final rawBase = (logUploadData[1] << 24) |
        (logUploadData[2] << 16) |
        (logUploadData[3] << 8) |
        logUploadData[4];

    int baseAddress;
    switch (rawBase) {
      case 0xDD000000:
      case 0xC0000000:
      case 0x90000000:
        baseAddress = 0xC0000000;
        break;
      case 0x80000000:
        baseAddress = 0x80000000;
        break;
      default:
        baseAddress = rawBase;
        _log.warning(
          'Unknown log upload base address 0x${rawBase.toRadixString(16)}',
        );
    }

    _log.info(
      'Log upload base address resolved: 0x${baseAddress.toRadixString(16)}',
    );

    _logUploadBaseAddress = baseAddress;
    return baseAddress;
  }

  List<int> _decompressData(List<int> data) {
    // First, RLE decompress
    final rleDecompressed = _rleDecompress(data);

    // Then, XOR decompress (each 32-byte block XORed with previous)
    _xorDecompress(rleDecompressed);

    return rleDecompressed;
  }

  Future<List<int>> _downloadMemory({
    required int address,
    required int size,
    required bool compressed,
  }) async {
    if (size <= 0) {
      throw const DownloadException(
        'Invalid download size',
        phase: DownloadPhase.downloading,
      );
    }

    final initRequest = [
      0x35,
      compressed ? 0x10 : 0x00,
      0x34,
      (address >> 24) & 0xFF,
      (address >> 16) & 0xFF,
      (address >> 8) & 0xFF,
      address & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
    ];

    _log.info(
      'RequestDownload: address=0x${address.toRadixString(16)}, '
      'size=$size, compressed=$compressed',
    );

    final initResponse = await transfer(initRequest);

    // Check for NAK response
    if (initResponse.isNotEmpty && initResponse[0] == nak) {
      final errorCode =
          initResponse.length >= 3 ? initResponse[2] : 0;
      _log.warning(
        'NAK received for RequestDownload: error=0x${errorCode.toRadixString(16)}',
      );
      throw DownloadException(
        'Device rejected download request: '
        '${initResponse.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} '
        '(address=0x${address.toRadixString(16)}, size=$size, compressed=$compressed)',
        phase: DownloadPhase.downloading,
      );
    }

    if (initResponse.length < 3 ||
        initResponse[0] != 0x75 ||
        initResponse[1] != 0x10) {
      throw DownloadException(
        'Unexpected init response: ${initResponse.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        phase: DownloadPhase.downloading,
      );
    }

    final buffer = <int>[];
    var block = 1;
    var done = false;

    while (buffer.length < size && !done) {
      final response = await transfer([0x36, block & 0xFF]);
      if (response.length < 2 ||
          response[0] != 0x76 ||
          response[1] != (block & 0xFF)) {
        throw DownloadException(
          'Unexpected block response for $block: ${response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
          phase: DownloadPhase.downloading,
        );
      }

      final payload = response.sublist(2);
      buffer.addAll(payload);
      if (compressed && _rleHasTerminator(buffer)) {
        done = true;
      }

      block++;
    }

    final quitResponse = await transfer([0x37]);
    if (quitResponse.length < 2 ||
        quitResponse[0] != 0x77 ||
        quitResponse[1] != 0x00) {
      throw DownloadException(
        'Unexpected quit response: ${quitResponse.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        phase: DownloadPhase.downloading,
      );
    }

    if (compressed) {
      return _decompressData(buffer);
    }

    if (buffer.length > size) {
      return buffer.sublist(0, size);
    }

    return buffer;
  }

  bool _rleHasTerminator(List<int> data) {
    var bitOffset = 0;
    final totalBits = data.length * 8;

    while (bitOffset + 9 <= totalBits) {
      final byteOffset = bitOffset ~/ 8;
      final bitShift = bitOffset % 8;

      int value;
      if (byteOffset + 1 < data.length) {
        value = ((data[byteOffset] << 8) | data[byteOffset + 1]) >>
            (16 - bitShift - 9);
      } else {
        value = data[byteOffset] >> (8 - bitShift - 1);
      }
      value &= 0x1FF;

      if (value == 0) {
        return true;
      }

      bitOffset += 9;
    }

    return false;
  }

  List<int> _rleDecompress(List<int> data) {
    final result = <int>[];

    // The RLE algorithm uses 9-bit values
    var bitOffset = 0;

    while (bitOffset + 9 <= data.length * 8) {
      // Extract 9-bit value
      final byteOffset = bitOffset ~/ 8;
      final bitShift = bitOffset % 8;

      int value;
      if (byteOffset + 1 < data.length) {
        value = ((data[byteOffset] << 8) | data[byteOffset + 1]) >> (16 - bitShift - 9);
      } else {
        value = data[byteOffset] >> (8 - bitShift - 1);
      }
      value &= 0x1FF;

      if (value & 0x100 != 0) {
        // Not a run, add the byte directly
        result.add(value & 0xFF);
      } else if (value == 0) {
        // End of compressed data
        break;
      } else {
        // Run of zero bytes
        result.addAll(List.filled(value, 0));
      }

      bitOffset += 9;
    }

    return result;
  }

  void _xorDecompress(List<int> data) {
    // XOR each 32-byte block with the previous block
    for (var i = 32; i < data.length; i++) {
      data[i] ^= data[i - 32];
    }
  }

  DownloadedDive _parseDive(DiveManifestEntry entry, List<int> data) {
    // Parse dive header and samples from decompressed data
    // This is a simplified parser - real implementation would need full format details

    final samples = <ProfileSample>[];
    var offset = 0;

    // Skip header (size varies by firmware version)
    // For now, assume samples start after a 128-byte header
    offset = 128.clamp(0, data.length);

    // Parse samples (simplified - actual format is more complex)
    var timeSeconds = 0;
    const sampleInterval = 10; // seconds

    while (offset + 4 <= data.length) {
      final depth = ((data[offset] << 8) | data[offset + 1]) / 100.0; // cm to m
      double? temp;
      if (offset + 3 < data.length) {
        temp = ((data[offset + 2] << 8) | data[offset + 3]) / 10.0 - 273.15; // K to C
      }

      if (depth >= 0 && depth < 200) {
        // Reasonable depth check
        samples.add(
          ProfileSample(
            timeSeconds: timeSeconds,
            depth: depth,
            temperature: temp,
          ),
        );
      }

      timeSeconds += sampleInterval;
      offset += 4;
    }

    return DownloadedDive(
      diveNumber: entry.diveNumber,
      startTime: entry.dateTime,
      durationSeconds: entry.durationSeconds,
      maxDepth: entry.maxDepth,
      avgDepth: samples.isEmpty ? 0 : samples.map((s) => s.depth).reduce((a, b) => a + b) / samples.length,
      profile: samples,
      fingerprint: entry.fingerprint,
    );
  }

  /// Disconnect from the device.
  Future<void> disconnect() async {
    _isConnected = false;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _receivedData.clear();
    _log.info('Disconnected from Shearwater device');
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _responseController.close();
  }
}

/// Represents an entry in the dive manifest.
class DiveManifestEntry {
  final int diveNumber;
  final DateTime dateTime;
  final int durationSeconds;
  final double maxDepth;
  final int dataAddress;
  final int dataSize;
  final String fingerprint;

  DiveManifestEntry({
    required this.diveNumber,
    required this.dateTime,
    required this.durationSeconds,
    required this.maxDepth,
    required this.dataAddress,
    required this.dataSize,
    required this.fingerprint,
  });

  /// Parse a manifest entry from raw bytes.
  static DiveManifestEntry? fromBytes(List<int> data) {
    if (data.length < 32) return null;

    try {
      final allZero = data.every((b) => b == 0);
      final allFF = data.every((b) => b == 0xFF);
      if (allZero || allFF) return null;

      final header = (data[0] << 8) | data[1];
      final isPetrelFormat = header == 0xA5C4 || header == 0x5A23;

      if (isPetrelFormat) {
        // Petrel/Teric manifest format (32 bytes):
        // 0-1: Record header (0xA5C4 valid, 0x5A23 deleted)
        // 2-3: Dive number (best-effort)
        // 4-7: Fingerprint
        // 8-11: Timestamp (Unix, best-effort)
        // 12-13: Duration (minutes, best-effort)
        // 14-15: Max depth (cm, best-effort)
        // 20-23: Data address
        if (header == 0x5A23) return null;

        final diveNumber = (data[2] << 8) | data[3];
        final timestamp = (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11];
        final durationMin = (data[12] << 8) | data[13];
        final maxDepthCm = (data[14] << 8) | data[15];
        final dataAddress =
            (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23];
        final dataSize =
            (data[24] << 24) | (data[25] << 16) | (data[26] << 8) | data[27];

        final fingerprint = data
            .sublist(4, 8)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();

        if (dataAddress == 0) return null;

        final dateTime = _safeTimestamp(timestamp);

        return DiveManifestEntry(
          diveNumber: diveNumber,
          dateTime: dateTime,
          durationSeconds: durationMin * 60,
          maxDepth: maxDepthCm / 100.0,
          dataAddress: dataAddress,
          dataSize: dataSize,
          fingerprint: fingerprint,
        );
      }

      // Legacy manifest format (32 bytes):
      // 0-3: Data address
      // 4-7: Data size
      // 8-11: Timestamp (Unix)
      // 12-13: Dive number
      // 14-15: Max depth (cm)
      // 16-17: Duration (minutes)
      // 18-21: Fingerprint
      // 22-31: Reserved

      final dataAddress =
          (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      final dataSize =
          (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
      final timestamp =
          (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11];
      final diveNumber = (data[12] << 8) | data[13];
      final maxDepthCm = (data[14] << 8) | data[15];
      final durationMin = (data[16] << 8) | data[17];

      final fingerprint = data
          .sublist(18, 22)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      if (dataAddress == 0 || dataSize == 0) return null;

      return DiveManifestEntry(
        diveNumber: diveNumber,
        dateTime: _safeTimestamp(timestamp),
        durationSeconds: durationMin * 60,
        maxDepth: maxDepthCm / 100.0,
        dataAddress: dataAddress,
        dataSize: dataSize,
        fingerprint: fingerprint,
      );
    } catch (e) {
      return null;
    }
  }

  static DateTime _safeTimestamp(int timestampSeconds) {
    if (timestampSeconds <= 0) {
      return DateTime.now();
    }
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);
    if (dateTime.year < 1990 || dateTime.year > 2100) {
      return DateTime.now();
    }
    return dateTime;
  }
}
