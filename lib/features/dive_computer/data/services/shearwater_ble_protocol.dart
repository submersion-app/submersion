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
const wdbiRequest = 0x2E;
const wdbiResponse = 0x6E;
const nak = 0x7F;

/// Shearwater RDBI identifiers (2-byte IDs, not addresses)
const idSerial = 0x8010; // Serial number
const idManifest = 0xE000; // Dive manifest
const manifestSize = 0x600; // Size of manifest data
const recordSize = 0x20; // Size of each manifest entry

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

  // Multi-frame response tracking
  int _expectedFrames = 0;
  int _receivedFrames = 0;

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

    // For BLE, skip the 2-byte frame header [nframes, frame_index]
    if (data.length >= 2) {
      final nframes = data[0];
      final frameIndex = data[1];
      _log.info('BLE frame header: nframes=$nframes, index=$frameIndex');

      // Track multi-frame responses
      if (frameIndex == 0) {
        // First frame - reset tracking
        _expectedFrames = nframes;
        _receivedFrames = 1;
      } else {
        _receivedFrames++;
      }

      // Add payload (skip header)
      _receivedData.addAll(data.sublist(2));

      // Only try to parse when we have all frames
      if (_receivedFrames >= _expectedFrames) {
        _log.info('All $nframes frame(s) received, parsing...');
        _tryParseResponse();
      } else {
        _log.info('Waiting for more frames: $_receivedFrames/$_expectedFrames');
      }
    } else {
      _receivedData.addAll(data);
      _tryParseResponse();
    }
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

    // Clear any stale data in the receive buffer and reset frame tracking
    _receivedData.clear();
    _expectedFrames = 0;
    _receivedFrames = 0;

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

  /// Standard SLIP encoding with leading and trailing END bytes
  /// RFC 1055 specifies END at both start and end to flush receiver state
  List<int> _encodeSlip(List<int> data) {
    final result = <int>[];

    // Leading END byte to flush any partial frame in receiver
    result.add(slipEnd);

    // SLIP encode the data (escape special bytes)
    for (final byte in data) {
      if (byte == slipEnd) {
        result.add(slipEsc);
        result.add(slipEscEnd);
      } else if (byte == slipEsc) {
        result.add(slipEsc);
        result.add(slipEscEsc);
      } else {
        result.add(byte);
      }
    }

    // Trailing END byte to terminate the frame
    result.add(slipEnd);

    // No padding - send just the SLIP frame
    return result;
  }

  /// Encode data with SLIP and BLE framing (matching libdivecomputer).
  ///
  /// For BLE transport:
  /// - Each 32-byte frame has 2-byte header: [nframes, frame_index]
  /// - Data is SLIP-encoded (no leading END for BLE)
  /// - Frame ends with SLIP END byte (0xC0)
  /// - Remaining bytes padded with zeros
  List<int> _encodeSlipBle(List<int> data) {
    // First, calculate total SLIP-encoded size (for frame count)
    var slipSize = 1; // Trailing END byte
    for (final byte in data) {
      if (byte == slipEnd || byte == slipEsc) {
        slipSize += 2; // Escaped
      } else {
        slipSize += 1;
      }
    }

    // Calculate number of frames needed
    // Each frame has 2-byte header, leaving 30 bytes for payload
    const payloadPerFrame = blePacketSize - 2;
    final frameCount = (slipSize + payloadPerFrame - 1) ~/ payloadPerFrame;

    _log.info('SLIP size: $slipSize bytes, frames: $frameCount');

    // Build frames
    final result = <int>[];
    var frameIndex = 0;
    var payloadBytes = 0;

    // Start first frame with header
    result.add(frameCount);
    result.add(frameIndex);
    payloadBytes = 0;

    // SLIP encode the data (no leading END for BLE)
    for (final byte in data) {
      if (byte == slipEnd) {
        _addByteToFrame(result, slipEsc, frameCount, payloadBytes, payloadPerFrame);
        payloadBytes++;
        if (payloadBytes >= payloadPerFrame) {
          frameIndex++;
          result.add(frameCount);
          result.add(frameIndex);
          payloadBytes = 0;
        }
        _addByteToFrame(result, slipEscEnd, frameCount, payloadBytes, payloadPerFrame);
        payloadBytes++;
        if (payloadBytes >= payloadPerFrame) {
          frameIndex++;
          result.add(frameCount);
          result.add(frameIndex);
          payloadBytes = 0;
        }
      } else if (byte == slipEsc) {
        _addByteToFrame(result, slipEsc, frameCount, payloadBytes, payloadPerFrame);
        payloadBytes++;
        if (payloadBytes >= payloadPerFrame) {
          frameIndex++;
          result.add(frameCount);
          result.add(frameIndex);
          payloadBytes = 0;
        }
        _addByteToFrame(result, slipEscEsc, frameCount, payloadBytes, payloadPerFrame);
        payloadBytes++;
        if (payloadBytes >= payloadPerFrame) {
          frameIndex++;
          result.add(frameCount);
          result.add(frameIndex);
          payloadBytes = 0;
        }
      } else {
        result.add(byte);
        payloadBytes++;
        if (payloadBytes >= payloadPerFrame) {
          frameIndex++;
          result.add(frameCount);
          result.add(frameIndex);
          payloadBytes = 0;
        }
      }
    }

    // Add trailing END byte
    result.add(slipEnd);
    payloadBytes++;

    // Pad final frame to 32 bytes
    while (result.length % blePacketSize != 0) {
      result.add(0);
    }

    return result;
  }

  void _addByteToFrame(List<int> result, int byte, int frameCount,
      int payloadBytes, int payloadPerFrame) {
    result.add(byte);
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
    if (response.isEmpty || response[0] == nak) {
      throw const DownloadException(
        'Device returned NAK',
        phase: DownloadPhase.downloading,
      );
    }

    if (response[0] != rdbiResponse) {
      throw DownloadException(
        'Unexpected response: 0x${response[0].toRadixString(16)}',
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

    // Read manifest using RDBI with identifier 0xE000
    final manifestData = await readById(idManifest);
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
    _log.info('Downloading dive ${entry.diveNumber}');

    // TODO: Implement dive data download using RDBI with dive-specific identifier
    // For now, return a placeholder dive with info from manifest
    _log.warning('Dive data download not yet implemented, using manifest info only');

    return DownloadedDive(
      diveNumber: entry.diveNumber,
      startTime: entry.dateTime,
      durationSeconds: entry.durationSeconds,
      maxDepth: entry.maxDepth,
      avgDepth: entry.maxDepth * 0.6, // Estimate
      profile: [], // No profile data yet
      fingerprint: entry.fingerprint,
    );
  }

  List<int> _decompressData(List<int> data) {
    // First, RLE decompress
    final rleDecompressed = _rleDecompress(data);

    // Then, XOR decompress (each 32-byte block XORed with previous)
    _xorDecompress(rleDecompressed);

    return rleDecompressed;
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
      // Manifest entry format (32 bytes):
      // 0-3: Data address
      // 4-7: Data size
      // 8-11: Timestamp (Unix)
      // 12-13: Dive number
      // 14-15: Max depth (cm)
      // 16-17: Duration (minutes)
      // 18-21: Fingerprint
      // 22-31: Reserved

      final dataAddress = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      final dataSize = (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
      final timestamp = (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11];
      final diveNumber = (data[12] << 8) | data[13];
      final maxDepthCm = (data[14] << 8) | data[15];
      final durationMin = (data[16] << 8) | data[17];

      // Build fingerprint hex string
      final fingerprint = data.sublist(18, 22)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();

      if (dataAddress == 0 || dataSize == 0) return null;

      return DiveManifestEntry(
        diveNumber: diveNumber,
        dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
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
}
