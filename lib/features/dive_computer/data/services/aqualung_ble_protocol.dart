import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/domain/services/download_manager.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_parser_service.dart';

/// Pelagic BLE service UUIDs used by Aqualung/Apeks/Sherwood dive computers.
///
/// Different hardware generations use different service UUIDs:
/// - Pelagic Gen1: i770R, i200C, i300C, Pro Plus X, Geo 4.0
/// - Pelagic Gen2: i330R, DSX
/// - Legacy HM-10 UART: older firmware revisions (FFE0/FFAA)
///
/// Characteristics are discovered dynamically by property (write/notify)
/// rather than hardcoded, since they vary across hardware revisions.
const pelagicServiceUuid = 'cb3c4555-d670-4670-bc20-b61dbc851e9a';
const pelagicGen2ServiceUuid = 'ca7b0001-f785-4c38-b599-c7c5fbadb034';

/// Legacy HM-10 UART service UUIDs (older firmware revisions)
const legacyUartServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
const legacyUartAltServiceUuid = '0000ffaa-0000-1000-8000-00805f9b34fb';

/// Known Pelagic Gen1 UART characteristic UUIDs.
///
/// Many Aqualung/Sherwood/Apeks models expose additional writable
/// characteristics in the same service. This TX/RX pair is the protocol
/// channel used for command/response traffic.
const pelagicGen1RxCharacteristicUuid = 'a60b8e5c-b267-44d7-9764-837caf96489e';
const pelagicGen1TxCharacteristicUuid = '6606ab42-89d5-4a00-a8ce-4eb5e1414ee0';
const pelagicGen1ReadCharacteristicUuid =
    'a60b8e5c-b267-44d7-9d65-857bad95479f';

/// All known Pelagic/Aqualung service UUIDs in priority order
const pelagicServiceUuids = [
  pelagicServiceUuid,
  pelagicGen2ServiceUuid,
  legacyUartServiceUuid,
  legacyUartAltServiceUuid,
];

/// BLE transport constants used by Oceanic Atom2/Pelagic protocol.
const blePacketStart = 0xCD;
const bleStatusCommandBase = 0x40;
const bleStatusReplyBase = 0xC0;
const bleStatusMoreFragments = 0x20;
const blePacketPayloadMax = 16;

/// Oceanic Atom2 command codes used by Aqualung i300C family.
const cmdVersion = 0x84;
const cmdHandshake = 0xE5;
const cmdRead1 = 0xB1;
const cmdRead8 = 0xB4;
const cmdRead16 = 0xB8;
const cmdRead16High = 0xF6;
const cmdKeepAlive = 0x91;
const cmdQuit = 0x6A;

/// Protocol ACK/NAK codes.
const commandAck = 0x5A;
const commandNak = 0xA5;

/// Oceanic page size in bytes.
const oceanicPageSize = 0x10;

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
  BluetoothCharacteristic? _notifyCharacteristic;
  bool _useWriteWithoutResponse = false;
  StreamSubscription<List<int>>? _notifySubscription;
  final _responseController = StreamController<List<int>>.broadcast();
  final _pendingReplyPayload = <int>[];
  int? _pendingResponseCommandSequence;
  int _expectedReplyPacketIndex = 0;
  int _commandSequence = 0;

  bool _isConnected = false;
  final int _timeout = 20000; // milliseconds

  // Device info
  final String? _deviceNameHint;
  String? _versionString;
  String _parserProduct = 'i300C';
  _AqualungMemoryLayout _layout = _AqualungMemoryLayout.defaultLayout();

  /// PIN code callback - called when device displays a PIN
  /// The application should prompt the user for this PIN
  Future<String?> Function()? onPinRequired;

  /// Progress callback while reading flash memory pages.
  ///
  /// [pagesRead] is 1-based and [totalPages] is the planned total for the
  /// current memory read pass.
  void Function(int pagesRead, int totalPages)? onMemoryReadProgress;

  AqualungBleProtocol(this._device, {String? deviceName})
    : _deviceNameHint = deviceName;

  /// Connect to the Aqualung device and discover services.
  Future<void> connect() async {
    _log.info('Connecting to Aqualung device: ${_device.remoteId}');

    // Discover services
    final services = await _device.discoverServices();

    _log.info('Discovered ${services.length} services:');
    for (final service in services) {
      _log.info('  Service: ${service.uuid.str}');
    }

    // Find the Pelagic/Aqualung service by checking all known UUIDs
    BluetoothService? pelagicService;
    String? matchedServiceUuid;

    for (final knownUuid in pelagicServiceUuids) {
      for (final service in services) {
        if (service.uuid.str.toLowerCase() == knownUuid.toLowerCase()) {
          pelagicService = service;
          matchedServiceUuid = knownUuid;
          _log.info('Found Pelagic service: $knownUuid');
          break;
        }
      }
      if (pelagicService != null) break;
    }

    if (pelagicService == null) {
      throw DownloadException(
        'Pelagic/Aqualung service not found on device. '
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

    // Dynamically discover TX (write) and RX (notify) characteristics.
    //
    // Pelagic BLE services use the UART pattern: separate characteristics
    // for each direction. The RX characteristic (device -> app) has a CCCD
    // descriptor (UUID 2902) for notifications. The TX characteristic
    // (app -> device) is write-only without a CCCD.
    //
    // Key: the CCCD descriptor distinguishes notify-only from write-only
    // characteristics, even if both have the write property bit set.
    _log.info('Discovering characteristics for service: $matchedServiceUuid');

    BluetoothCharacteristic? rxWithCccd; // notify char with CCCD descriptor
    BluetoothCharacteristic? rxNotifiable; // fallback: any notify/indicate char
    final txPreferredCandidates = <BluetoothCharacteristic>[
      // writable, non-notify chars without CCCD
    ];
    final txFallbackCandidates = <BluetoothCharacteristic>[
      // any writable chars without CCCD
    ];
    BluetoothCharacteristic? combinedChar; // fallback: single char does both
    BluetoothCharacteristic? knownPelagicGen1Rx;
    BluetoothCharacteristic? knownPelagicGen1Tx;

    for (final char in pelagicService.characteristics) {
      final props = char.properties;
      final hasCccd = char.descriptors.any(
        (d) => _isBleUuidMatch(d.uuid.str, '2902'),
      );
      final isWritable = props.write || props.writeWithoutResponse;
      final isNotifiable = props.notify || props.indicate;
      final isKnownPelagicGen1Rx = _isBleUuidMatch(
        char.uuid.str,
        pelagicGen1RxCharacteristicUuid,
      );
      final isKnownPelagicGen1Tx = _isBleUuidMatch(
        char.uuid.str,
        pelagicGen1TxCharacteristicUuid,
      );
      final isKnownPelagicGen1Read = _isBleUuidMatch(
        char.uuid.str,
        pelagicGen1ReadCharacteristicUuid,
      );

      _log.info(
        '  Char: ${char.uuid.str} '
        '[write=${props.write}, writeNoResp=${props.writeWithoutResponse}, '
        'notify=${props.notify}, indicate=${props.indicate}, '
        'cccd=$hasCccd]',
      );

      // Notifiable characteristic is a potential RX (device -> app)
      if (isNotifiable) {
        rxNotifiable ??= char;
        if (hasCccd) {
          rxWithCccd ??= char;
          _log.info('    -> RX candidate (has CCCD)');
        } else {
          _log.info('    -> RX fallback candidate (notify/indicate)');
        }
      }

      // Capture known Pelagic Gen1 UART pair explicitly.
      if (isKnownPelagicGen1Rx && (isNotifiable || hasCccd)) {
        knownPelagicGen1Rx = char;
        _log.info('    -> RX candidate (known Pelagic Gen1 UART)');
      }
      if (isKnownPelagicGen1Tx && isWritable) {
        knownPelagicGen1Tx = char;
        _log.info('    -> TX candidate (known Pelagic Gen1 UART)');
      }
      if (isKnownPelagicGen1Read) {
        _log.info('    -> Read-only info characteristic (known Pelagic Gen1)');
      }

      // Writable characteristic WITHOUT CCCD → TX candidate (we send to device)
      if (isWritable && !hasCccd) {
        txFallbackCandidates.add(char);
        if (!isNotifiable) {
          txPreferredCandidates.add(char);
          _log.info('    -> TX preferred candidate (no CCCD, not notify)');
        } else {
          _log.info('    -> TX fallback candidate (no CCCD)');
        }
      }

      // Track combined characteristic as last resort
      if (isWritable && isNotifiable) {
        combinedChar ??= char;
      }
    }

    final rxCharacteristic = rxWithCccd ?? rxNotifiable;
    final txCandidates = txPreferredCandidates.isNotEmpty
        ? txPreferredCandidates
        : txFallbackCandidates;
    final txCandidatesExcludingRx = rxCharacteristic == null
        ? txCandidates
        : txCandidates
              .where(
                (c) =>
                    c.uuid.str.toLowerCase() !=
                    rxCharacteristic.uuid.str.toLowerCase(),
              )
              .toList();

    // Select the best TX characteristic from candidates.
    //
    // Priority order:
    //   1. TX candidate whose UUID prefix matches the RX characteristic
    //      (paired TX/RX — standard for Pelagic BLE UART)
    //   2. First writable candidate without CCCD + separate RX characteristic
    //      (fallback when UUID pairing is not obvious)
    //   3. Combined characteristic that supports both write and notify
    //      (single-char TX/RX — last resort)
    //   4. First writable candidate (no RX discovered)
    //
    // We do NOT blindly use the first writable candidate because Pelagic
    // services expose multiple writable characteristics for configuration,
    // firmware, etc. — only one is the actual protocol TX.
    BluetoothCharacteristic? pairedTx;
    if (txCandidatesExcludingRx.isNotEmpty && rxCharacteristic != null) {
      final rxPrefix = _uuidPrefix(rxCharacteristic.uuid.str);
      for (final candidate in txCandidatesExcludingRx) {
        if (_uuidPrefix(candidate.uuid.str) == rxPrefix) {
          pairedTx = candidate;
          _log.info(
            '    -> TX selected (UUID prefix matches RX): '
            '${candidate.uuid.str}',
          );
          break;
        }
      }
    }

    // Apply priority: paired TX > fallback TX+RX > combined char > TX-only
    //
    // Write mode: prefer writeWithoutResponse when available. Many BLE dive
    // computers (including Pelagic) only implement the Write Command (0x52)
    // handler and reject Write Requests (0x12) with ATT error 0x80. Using
    // writeWithoutResponse avoids this and is faster for data transfer.
    if (knownPelagicGen1Tx != null && knownPelagicGen1Rx != null) {
      // 1. Explicit Pelagic Gen1 UART pair
      _txRxCharacteristic = knownPelagicGen1Tx;
      _notifyCharacteristic = knownPelagicGen1Rx;
      _useWriteWithoutResponse = _initialWriteWithoutResponse(
        knownPelagicGen1Tx,
      );
      _log.info(
        'Using known Pelagic Gen1 UART pair '
        'TX (${knownPelagicGen1Tx.uuid.str}) '
        'RX (${knownPelagicGen1Rx.uuid.str}) '
        '(writeMode=${_useWriteWithoutResponse ? "withoutResponse" : "withResponse"})',
      );
    } else if (pairedTx != null && rxCharacteristic != null) {
      // 2. Paired TX/RX: separate characteristics sharing a UUID base
      _txRxCharacteristic = pairedTx;
      _notifyCharacteristic = rxCharacteristic;
      _useWriteWithoutResponse = _initialWriteWithoutResponse(pairedTx);
      _log.info(
        'Using paired TX (${pairedTx.uuid.str}) '
        'and RX (${rxCharacteristic.uuid.str}) characteristics '
        '(writeMode=${_useWriteWithoutResponse ? "withoutResponse" : "withResponse"})',
      );
    } else if (txCandidatesExcludingRx.isNotEmpty && rxCharacteristic != null) {
      // 3. Fallback TX + separate RX
      final fallbackTx = txCandidatesExcludingRx.first;
      _txRxCharacteristic = fallbackTx;
      _notifyCharacteristic = rxCharacteristic;
      _useWriteWithoutResponse = _initialWriteWithoutResponse(fallbackTx);
      _log.info(
        'Using fallback TX (${fallbackTx.uuid.str}) '
        'and RX (${rxCharacteristic.uuid.str}) characteristics '
        '(writeMode=${_useWriteWithoutResponse ? "withoutResponse" : "withResponse"})',
      );
    } else if (combinedChar != null) {
      // 4. Combined TX/RX: single characteristic handles both directions
      _txRxCharacteristic = combinedChar;
      _notifyCharacteristic = combinedChar;
      _useWriteWithoutResponse = _initialWriteWithoutResponse(combinedChar);
      _log.info(
        'Using combined TX/RX (${combinedChar.uuid.str}) '
        '(writeMode=${_useWriteWithoutResponse ? "withoutResponse" : "withResponse"})',
      );
    } else if (txCandidates.isNotEmpty) {
      // 5. Last resort: writable TX only, no RX discovered
      final fallbackTx = txCandidates.first;
      _txRxCharacteristic = fallbackTx;
      _notifyCharacteristic = null;
      _useWriteWithoutResponse = _initialWriteWithoutResponse(fallbackTx);
      _log.warning(
        'Using TX-only fallback characteristic (${fallbackTx.uuid.str}); '
        'no RX notify characteristic discovered',
      );
    }

    if (_txRxCharacteristic == null) {
      throw DownloadException(
        'No suitable TX/RX characteristic found in service $matchedServiceUuid. '
        'Characteristics: ${pelagicService.characteristics.map((c) => c.uuid.str).join(", ")}',
        phase: DownloadPhase.connecting,
      );
    }

    // Enable notifications on the appropriate characteristic
    final rxChar = _notifyCharacteristic ?? _txRxCharacteristic!;
    _log.info('Enabling notifications on ${rxChar.uuid.str}...');
    final rxProps = rxChar.properties;

    if (rxProps.notify || rxProps.indicate) {
      await rxChar.setNotifyValue(true);
      _notifySubscription = rxChar.onValueReceived.listen(_onDataReceived);
      _log.info('Notifications enabled');
    } else {
      _log.warning('Characteristic does not support notify!');
    }

    await Future.delayed(const Duration(milliseconds: 300));

    _isConnected = true;
    _log.info('Connected to Aqualung device');

    // Ensure OS-level bonding before protocol commands.
    // Pelagic devices require BLE bonding and will reject writes (ATT 0x80)
    // until the OS has completed the pairing/bonding handshake.
    await _ensureBonded();

    // Initialize protocol session (version + BLE handshake).
    await _initializeProtocolSession();
  }

  /// Ensure the device is bonded at the OS level before sending protocol
  /// commands. Pelagic devices reject writes (ATT error 0x80) from unbonded
  /// peers. On Android, [createBond] triggers the system pairing dialog.
  /// On iOS, bonding is triggered automatically when accessing encrypted
  /// characteristics, but we nudge it here and wait for completion.
  Future<void> _ensureBonded() async {
    _log.info('Ensuring device is bonded...');

    try {
      // Check current bond state
      final currentState = await _device.bondState.first;
      if (currentState == BluetoothBondState.bonded) {
        _log.info('Device already bonded');
        return;
      }

      _log.info('Device not bonded (state: $currentState), requesting bond...');

      // Request bonding — on Android this shows the system pairing dialog,
      // on iOS this may trigger pairing via encrypted characteristic access.
      await _device.createBond();

      // Wait for bond state to become bonded, with timeout for user
      // to complete the pairing dialog on their phone.
      _log.info('Waiting for bonding to complete...');
      await _device.bondState
          .where((state) => state == BluetoothBondState.bonded)
          .first
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              _log.warning('Bond timeout — proceeding anyway');
              return BluetoothBondState.none;
            },
          );

      _log.info('Bonding complete');
    } catch (e) {
      // Bonding may not be supported on all platforms or may fail
      // for devices that don't require it. Log and continue.
      _log.warning('Bond request failed: $e — proceeding without bonding');
    }

    // Give the BLE stack time to stabilize after bonding
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _onDataReceived(List<int> data) {
    _log.debug(
      'Received ${data.length} bytes: '
      '${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    if (data.length < 4) {
      _log.warning('Ignoring short BLE packet (${data.length} bytes)');
      return;
    }

    if (data[0] != blePacketStart) {
      _log.warning(
        'Ignoring packet with unexpected start byte: '
        '0x${data[0].toRadixString(16).padLeft(2, '0')}',
      );
      return;
    }

    final status = data[1];
    final isReply = (status & 0xC0) == bleStatusReplyBase;
    if (!isReply) {
      _log.warning(
        'Ignoring non-reply BLE packet status: '
        '0x${status.toRadixString(16).padLeft(2, '0')}',
      );
      return;
    }

    final commandSequence = data[2];
    final expectedSequence = _pendingResponseCommandSequence;
    if (expectedSequence == null) {
      _log.warning(
        'Ignoring unsolicited reply packet for seq=$commandSequence',
      );
      return;
    }
    if (commandSequence != expectedSequence) {
      _log.warning(
        'Ignoring reply packet with unexpected command sequence '
        '(got=$commandSequence expected=$expectedSequence)',
      );
      return;
    }

    final packetIndex = status & 0x1F;
    if (packetIndex != _expectedReplyPacketIndex) {
      _log.warning(
        'Unexpected reply packet index (got=$packetIndex '
        'expected=$_expectedReplyPacketIndex); resetting accumulator',
      );
      _resetPendingResponse();
      return;
    }

    final payloadLength = data[3];
    if (payloadLength + 4 > data.length) {
      _log.warning(
        'Ignoring malformed packet length '
        '(payload=$payloadLength total=${data.length})',
      );
      return;
    }

    _pendingReplyPayload.addAll(data.sublist(4, 4 + payloadLength));
    _expectedReplyPacketIndex++;

    final hasMoreFragments = (status & bleStatusMoreFragments) != 0;
    if (!hasMoreFragments) {
      _responseController.add(List<int>.from(_pendingReplyPayload));
      _resetPendingResponse();
    }
  }

  void _preparePendingResponse(int commandSequence) {
    _pendingResponseCommandSequence = commandSequence & 0xFF;
    _expectedReplyPacketIndex = 0;
    _pendingReplyPayload.clear();
  }

  void _resetPendingResponse() {
    _pendingResponseCommandSequence = null;
    _expectedReplyPacketIndex = 0;
    _pendingReplyPayload.clear();
  }

  Future<void> _initializeProtocolSession() async {
    _commandSequence = 0;

    final versionData = await _sendCommand(
      command: const [cmdVersion],
      expectedAck: commandAck,
      expectedDataLength: oceanicPageSize,
      checksumBytes: 1,
    );
    _versionString = _sanitizeAscii(versionData);
    _layout = _AqualungMemoryLayout.fromVersion(_versionString ?? '');
    _parserProduct = _layout.parserProduct;
    _log.info(
      'Device version string: ${_versionString ?? "<unknown>"} '
      '(layout=${_layout.parserProduct}, mem=0x${_layout.memorySize.toRadixString(16)})',
    );

    final handshakeCommand = _buildHandshakeCommand();
    if (handshakeCommand == null) {
      _log.warning(
        'Skipping BLE handshake: no usable serial-style device name found',
      );
      return;
    }

    try {
      await _sendCommand(command: handshakeCommand, expectedAck: commandAck);
      _log.info('BLE handshake complete');
    } on _UnsupportedCommandException {
      _log.warning('BLE handshake command not supported by device; continuing');
    }
  }

  String _sanitizeAscii(List<int> data) {
    final ascii = latin1.decode(data, allowInvalid: true);
    return ascii.replaceAll('\u0000', '').trim();
  }

  List<int>? _buildHandshakeCommand() {
    final serialName = _resolveHandshakeSerialName();
    if (serialName == null) return null;

    final payload = List<int>.filled(8, 0);
    for (var i = 0; i < 6; i++) {
      payload[i] = serialName.codeUnitAt(i + 2) - 0x30;
    }
    final checksum = _checksum8(payload);

    _log.info('Using handshake serial source: $serialName');
    return [cmdHandshake, ...payload, checksum];
  }

  String? _resolveHandshakeSerialName() {
    final candidates = <String?>[_deviceNameHint, _device.platformName];

    for (final candidate in candidates) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final uppercase = candidate.trim().toUpperCase();
      final match = RegExp(r'([A-Z]{2}[0-9]{6})').firstMatch(uppercase);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  List<List<int>> _buildBlePackets(List<int> command, int commandSequence) {
    final packets = <List<int>>[];
    var offset = 0;
    var packetSequence = 0;

    while (offset < command.length) {
      final remaining = command.length - offset;
      final payloadLength = min(blePacketPayloadMax, remaining);
      var status = bleStatusCommandBase | (packetSequence & 0x1F);
      if (remaining > blePacketPayloadMax) {
        status |= bleStatusMoreFragments;
      }

      packets.add([
        blePacketStart,
        status,
        commandSequence & 0xFF,
        payloadLength,
        ...command.sublist(offset, offset + payloadLength),
      ]);

      offset += payloadLength;
      packetSequence++;
    }

    return packets;
  }

  Future<List<int>> _sendCommand({
    required List<int> command,
    required int expectedAck,
    int expectedDataLength = 0,
    int checksumBytes = 0,
  }) async {
    if (!_isConnected) {
      throw const DownloadException(
        'Not connected to device',
        phase: DownloadPhase.downloading,
      );
    }

    final commandSequence = _commandSequence & 0xFF;
    final packets = _buildBlePackets(command, commandSequence);
    final isReadCommand =
        command.length == 3 &&
        (command.first == cmdRead1 ||
            command.first == cmdRead8 ||
            command.first == cmdRead16 ||
            command.first == cmdRead16High);

    final sendMessage =
        'Sending command seq=$commandSequence '
        'cmd=0x${command.first.toRadixString(16)} '
        '(payload=${command.length} bytes, packets=${packets.length})';
    if (isReadCommand) {
      _log.debug(sendMessage);
    } else {
      _log.info(sendMessage);
    }

    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    const writeTimeout = Duration(seconds: 8);
    var useWithoutResponse = _useWriteWithoutResponse;

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      _preparePendingResponse(commandSequence);
      final completer = Completer<List<int>>();
      final subscription = _responseController.stream.listen(
        (data) {
          if (!completer.isCompleted) completer.complete(data);
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      try {
        final attemptMessage =
            'Write attempt $attempt/$maxRetries '
            '(mode=${useWithoutResponse ? "withoutResponse" : "withResponse"})';
        if (isReadCommand) {
          _log.debug(attemptMessage);
        } else {
          _log.info(attemptMessage);
        }

        for (final packet in packets) {
          await _txRxCharacteristic!
              .write(packet, withoutResponse: useWithoutResponse)
              .timeout(
                writeTimeout,
                onTimeout: () => throw TimeoutException('Write timeout'),
              );
        }

        final rawResponse = await completer.future.timeout(
          Duration(milliseconds: _timeout),
          onTimeout: () => throw TimeoutException('Response timeout'),
        );
        final response = _validateCommandResponse(
          rawResponse: rawResponse,
          expectedAck: expectedAck,
          expectedDataLength: expectedDataLength,
          checksumBytes: checksumBytes,
        );
        if (isReadCommand) {
          _log.debug('Got response: ${response.length} data bytes');
        } else {
          _log.info('Got response: ${response.length} data bytes');
        }

        if (useWithoutResponse != _useWriteWithoutResponse) {
          _log.info(
            'Write mode auto-corrected to '
            '${useWithoutResponse ? "withoutResponse" : "withResponse"}',
          );
          _useWriteWithoutResponse = useWithoutResponse;
        }

        _commandSequence = (_commandSequence + 1) & 0xFF;
        return response;
      } on _UnsupportedCommandException {
        rethrow;
      } on _ProtocolException catch (e) {
        if (attempt < maxRetries) {
          _log.warning(
            'Protocol error on attempt $attempt/$maxRetries: $e '
            '(retrying in ${retryDelay.inSeconds}s)',
          );
          await Future.delayed(retryDelay);
          continue;
        }

        throw DownloadException(
          'Communication error: $e',
          phase: DownloadPhase.downloading,
        );
      } on TimeoutException catch (e) {
        final canFlip =
            _txRxCharacteristic!.properties.write &&
            _txRxCharacteristic!.properties.writeWithoutResponse;
        if (attempt < maxRetries) {
          if (attempt == 1 && canFlip) {
            useWithoutResponse = !useWithoutResponse;
            _log.warning(
              'Timeout (${e.message ?? e}) on attempt $attempt/$maxRetries, '
              'flipping write mode to '
              '${useWithoutResponse ? "withoutResponse" : "withResponse"} '
              'and retrying',
            );
          } else {
            _log.warning(
              'Timeout (${e.message ?? e}) on attempt $attempt/$maxRetries, '
              'retrying after ${retryDelay.inSeconds}s',
            );
          }
          await Future.delayed(retryDelay);
          continue;
        }

        throw DownloadException(
          'Communication error: ${e.message ?? "Timeout"}',
          phase: DownloadPhase.downloading,
          originalError: e,
        );
      } catch (e) {
        final errorText = e.toString();
        final writeNotSupported = errorText.contains(
          'WRITE property is not supported',
        );
        final writeNoRespNotSupported = errorText.contains(
          'WRITE WITHOUT RESPONSE property is not supported',
        );

        if ((writeNotSupported || writeNoRespNotSupported) &&
            attempt < maxRetries) {
          if (writeNotSupported && !useWithoutResponse) {
            useWithoutResponse = true;
            _log.warning(
              'Write withResponse is not supported; switching to '
              'withoutResponse for retry: $e',
            );
            await Future.delayed(retryDelay);
            continue;
          }
          if (writeNoRespNotSupported && useWithoutResponse) {
            useWithoutResponse = false;
            _log.warning(
              'Write withoutResponse is not supported; switching to '
              'withResponse for retry: $e',
            );
            await Future.delayed(retryDelay);
            continue;
          }
        }

        final isAttError =
            errorText.contains('ATT error') ||
            errorText.contains('apple-code: 128') ||
            errorText.contains('FlutterBluePlusException');

        if (isAttError && attempt < maxRetries) {
          // On first ATT error, flip write mode for the next attempt
          final canFlip =
              _txRxCharacteristic!.properties.write &&
              _txRxCharacteristic!.properties.writeWithoutResponse;
          if (attempt == 1 && canFlip) {
            useWithoutResponse = !useWithoutResponse;
            _log.warning(
              'Write failed with ATT error, flipping write mode to '
              '${useWithoutResponse ? "withoutResponse" : "withResponse"} '
              'for next attempt: $e',
            );
          } else {
            _log.warning(
              'Write failed (attempt $attempt/$maxRetries), '
              'retrying after ${retryDelay.inSeconds}s: $e',
            );
          }
          await Future.delayed(retryDelay);
          continue;
        }

        throw DownloadException(
          'Communication error: $e',
          phase: DownloadPhase.downloading,
          originalError: e,
        );
      } finally {
        _resetPendingResponse();
        await subscription.cancel();
      }
    }

    throw const DownloadException(
      'Communication error: All write attempts failed',
      phase: DownloadPhase.downloading,
    );
  }

  List<int> _validateCommandResponse({
    required List<int> rawResponse,
    required int expectedAck,
    required int expectedDataLength,
    required int checksumBytes,
  }) {
    if (rawResponse.isEmpty) {
      throw const _ProtocolException('Empty response packet');
    }

    final ackByte = rawResponse.first;
    if (ackByte != expectedAck) {
      final invertedAck = (~expectedAck) & 0xFF;
      if (ackByte == invertedAck || ackByte == commandNak) {
        throw _UnsupportedCommandException(
          'Command not supported (ack=0x${ackByte.toRadixString(16).padLeft(2, '0')})',
        );
      }
      throw _ProtocolException(
        'Unexpected ACK byte '
        '(got=0x${ackByte.toRadixString(16).padLeft(2, '0')} '
        'expected=0x${expectedAck.toRadixString(16).padLeft(2, '0')})',
      );
    }

    if (expectedDataLength == 0) {
      return const [];
    }

    final minimumLength = 1 + expectedDataLength + checksumBytes;
    if (rawResponse.length < minimumLength) {
      throw _ProtocolException(
        'Response too short '
        '(got=${rawResponse.length}, expected>=$minimumLength)',
      );
    }

    const payloadStart = 1;
    final payloadEnd = payloadStart + expectedDataLength;
    final payload = rawResponse.sublist(payloadStart, payloadEnd);

    if (checksumBytes == 1) {
      final expectedChecksum = rawResponse[payloadEnd];
      final calculatedChecksum = _checksum8(payload);
      if (expectedChecksum != calculatedChecksum) {
        throw _ProtocolException(
          'Checksum mismatch (8-bit): '
          'got=0x${expectedChecksum.toRadixString(16).padLeft(2, '0')} '
          'expected=0x${calculatedChecksum.toRadixString(16).padLeft(2, '0')}',
        );
      }
    } else if (checksumBytes == 2) {
      final expectedChecksum =
          rawResponse[payloadEnd] | (rawResponse[payloadEnd + 1] << 8);
      final calculatedChecksum = _checksum16(payload);
      if (expectedChecksum != calculatedChecksum) {
        throw _ProtocolException(
          'Checksum mismatch (16-bit): '
          'got=0x${expectedChecksum.toRadixString(16).padLeft(4, '0')} '
          'expected=0x${calculatedChecksum.toRadixString(16).padLeft(4, '0')}',
        );
      }
    }

    if (rawResponse.length > minimumLength) {
      _log.warning(
        'Ignoring ${rawResponse.length - minimumLength} excess byte(s) in response',
      );
    }

    return payload;
  }

  int _checksum8(Iterable<int> data, [int seed = 0x00]) {
    var checksum = seed & 0xFF;
    for (final byte in data) {
      checksum = (checksum + byte) & 0xFF;
    }
    return checksum;
  }

  int _checksum16(Iterable<int> data, [int seed = 0x0000]) {
    var checksum = seed & 0xFFFF;
    for (final byte in data) {
      checksum = (checksum + byte) & 0xFFFF;
    }
    return checksum;
  }

  /// Extract the first 3 segments of a UUID for prefix matching.
  /// e.g. "a60b8e5c-b267-44d7-9d65-857bad95479f" → "a60b8e5c-b267-44d7"
  /// Used to identify paired TX/RX characteristics that share a UUID base.
  String _uuidPrefix(String uuid) {
    final parts = uuid.toLowerCase().split('-');
    if (parts.length >= 3) return parts.sublist(0, 3).join('-');
    return uuid.toLowerCase();
  }

  /// Pick initial write mode for a characteristic.
  ///
  /// For known Pelagic Gen1 TX (`6606ab42-...`), prefer write-without-response:
  /// this matches field-tested behavior and avoids stalls seen with write
  /// requests on some firmware revisions.
  ///
  /// Otherwise, prefer write-with-response when available so we get explicit
  /// ACK/errors, and fallback to write-without-response only when write-with-
  /// response is not supported by the characteristic.
  bool _initialWriteWithoutResponse(BluetoothCharacteristic characteristic) {
    final props = characteristic.properties;
    if (_isBleUuidMatch(
      characteristic.uuid.str,
      pelagicGen1TxCharacteristicUuid,
    )) {
      return true;
    }
    return props.writeWithoutResponse && !props.write;
  }

  /// Compare BLE UUIDs while handling short vs full 128-bit base UUID forms.
  bool _isBleUuidMatch(String left, String right) {
    return _normalizeBleUuid(left) == _normalizeBleUuid(right);
  }

  /// Normalize BLE UUID for comparison (e.g. 2902 == 00002902-... base UUID).
  String _normalizeBleUuid(String uuid) {
    final lower = uuid.toLowerCase().trim();

    // Already short form (16/32-bit)
    if (lower.length <= 8 && !lower.contains('-')) {
      return lower;
    }

    // Standard Bluetooth base UUID: extract significant 16-bit section.
    const baseSuffix = '-0000-1000-8000-00805f9b34fb';
    if (lower.endsWith(baseSuffix) && lower.startsWith('0000')) {
      return lower.substring(4, 8);
    }

    // Vendor-specific 128-bit UUIDs compare as full lowercase strings.
    return lower;
  }

  /// Download dives from the device.
  Future<List<DownloadedDive>> downloadDives() async {
    _log.info('Downloading dive data...');

    // Read flash memory using Oceanic Atom2 page commands.
    final diveData = await _readFlashMemory();

    if (diveData.isEmpty) {
      _log.warning('No dive data read from device');
      return [];
    }

    return _parseDives(diveData);
  }

  Future<List<int>> _readFlashMemory() async {
    final data = <int>[];
    final pageSize = oceanicPageSize * _layout.pageMultiplier;
    final totalPages = _layout.profileEnd ~/ pageSize;

    _log.info(
      'Reading full device memory: $totalPages pages '
      '(pageSize=$pageSize, range=0x0000-0x${_layout.profileEnd.toRadixString(16)}, '
      'readCmd=0x${_layout.readCommand.toRadixString(16)})',
    );

    for (var page = 0; page < totalPages; page++) {
      final command = [_layout.readCommand, (page >> 8) & 0xFF, page & 0xFF];

      final response = await _sendCommand(
        command: command,
        expectedAck: commandAck,
        expectedDataLength: pageSize,
        checksumBytes: _layout.checksumBytes,
      );
      data.addAll(response);

      final pagesRead = page + 1;
      if (onMemoryReadProgress != null &&
          (pagesRead == 1 || pagesRead == totalPages || pagesRead % 8 == 0)) {
        onMemoryReadProgress!(pagesRead, totalPages);
      }

      if (pagesRead % 128 == 0) {
        _log.info('Read $pagesRead / $totalPages pages');
      }
    }

    _log.info(
      'Read ${data.length} bytes from device memory '
      '(version=${_versionString ?? "unknown"})',
    );

    // Log config area header for debugging ringbuffer pointers
    if (data.length >= 16) {
      _log.info(
        'Config header [0x00-0x0F]: '
        '${data.sublist(0, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    }

    return data;
  }

  List<DownloadedDive> _parseDives(List<int> fullMemory) {
    _log.info('Parsing dive data from ${fullMemory.length} bytes of memory');

    final diveBlocks = _extractDiveDataBlocks(fullMemory);

    if (diveBlocks.isEmpty) {
      _log.warning(
        'No dive data blocks found in logbook; '
        'falling back to raw profile parse',
      );
      final profileStart = _layout.profileBegin;
      final profileEnd = min(_layout.profileEnd, fullMemory.length);
      if (profileStart < profileEnd) {
        return _parseSingleDiveBlock(
          fullMemory.sublist(profileStart, profileEnd),
        );
      }
      return [];
    }

    final dives = <DownloadedDive>[];
    for (var i = 0; i < diveBlocks.length; i++) {
      _log.info(
        'Parsing dive ${i + 1}/${diveBlocks.length} '
        '(${diveBlocks[i].length} bytes)',
      );
      final result = _parseSingleDiveBlock(diveBlocks[i]);
      dives.addAll(result);
    }

    _log.info('Successfully parsed ${dives.length} dives from memory');
    return dives;
  }

  List<DownloadedDive> _parseSingleDiveBlock(List<int> data) {
    try {
      final parserService = LibdcParserService.instance;
      if (!parserService.isInitialized) {
        parserService.initialize();
      }

      final parsedDive = parserService.parseDiveData(
        vendor: 'Aqualung',
        product: _parserProduct,
        data: data,
      );

      if (parsedDive != null) {
        _log.info(
          'Parsed dive: ${parsedDive.profile.length} samples, '
          'duration=${parsedDive.durationSeconds}s, '
          'maxDepth=${parsedDive.maxDepth}m',
        );
        return [parsedDive];
      }
    } catch (e, stack) {
      _log.warning('Failed to parse dive block: $e', e, stack);
    }
    return [];
  }

  /// Extract individual dive data blocks from the full device memory by
  /// parsing the Oceanic Atom2 logbook entries.
  ///
  /// This mirrors libdivecomputer's oceanic_common_device_logbook() and
  /// oceanic_common_device_profile() logic:
  /// 1. Read logbook ringbuffer pointers from the cf_pointers page.
  /// 2. Iterate valid logbook entries.
  /// 3. Extract profile start/end from each entry using pt_mode_logbook.
  /// 4. Prepend the logbook entry bytes to the profile data (the parser
  ///    expects this as its header).
  List<List<int>> _extractDiveDataBlocks(List<int> memory) {
    final cfPointers = _layout.cfPointers;
    final logbookBegin = _layout.logbookBegin;
    final logbookEnd =
        _layout.profileBegin; // logbook ends where profile begins
    final entrySize = _layout.logbookEntrySize;
    final profileBegin = _layout.profileBegin;
    final profileEnd = _layout.profileEnd;
    final ptMode = _layout.ptModeLogbook;

    // Profile page size for pointer arithmetic (not the BLE read page size).
    // Non-highmem models use 16 bytes; highmem models use 256 bytes.
    final profilePageSize = _layout.highmem > 0
        ? 16 * oceanicPageSize
        : oceanicPageSize;

    // Pointer mask depends on the number of addressable pages.
    final npages = (_layout.memorySize - _layout.highmem) ~/ profilePageSize;
    final pointerMask = npages > 0x4000
        ? 0x7FFF
        : npages > 0x2000
        ? 0x3FFF
        : npages > 0x1000
        ? 0x1FFF
        : 0x0FFF;

    // Need at least the pointer page + logbook area in memory.
    if (memory.length < cfPointers + 16) {
      _log.warning(
        'Memory too short for pointer page '
        '(${memory.length} < ${cfPointers + 16})',
      );
      return [];
    }
    if (memory.length < logbookEnd) {
      _log.warning(
        'Memory too short for logbook area '
        '(${memory.length} < $logbookEnd)',
      );
      return [];
    }

    // Read logbook ringbuffer pointers from the cf_pointers page.
    // Bytes 4-5 (LE): address of the oldest logbook entry.
    // Bytes 6-7 (LE): address of the newest logbook entry.
    final rbLogbookFirst =
        memory[cfPointers + 4] | (memory[cfPointers + 5] << 8);
    final rbLogbookLast =
        memory[cfPointers + 6] | (memory[cfPointers + 7] << 8);

    _log.info(
      'Logbook pointers: first=0x${rbLogbookFirst.toRadixString(16)}, '
      'last=0x${rbLogbookLast.toRadixString(16)} '
      '(range 0x${logbookBegin.toRadixString(16)}'
      '-0x${logbookEnd.toRadixString(16)})',
    );

    // Validate the last pointer (newest entry).
    if (rbLogbookLast < logbookBegin || rbLogbookLast >= logbookEnd) {
      _log.warning(
        'Invalid logbook last pointer '
        '0x${rbLogbookLast.toRadixString(16)}',
      );
      return [];
    }

    // Calculate the end of the valid logbook range.
    // pt_mode_global == 0 for all Aqualung models.
    final rbLogbookEndAddr = _rbIncrement(
      rbLogbookLast,
      entrySize,
      logbookBegin,
      logbookEnd,
    );

    // Calculate how many bytes of logbook data to process.
    int rbLogbookSize;
    if (rbLogbookFirst < logbookBegin || rbLogbookFirst >= logbookEnd) {
      _log.warning(
        'Invalid logbook first pointer '
        '0x${rbLogbookFirst.toRadixString(16)}; '
        'reading entire logbook area',
      );
      rbLogbookSize = logbookEnd - logbookBegin;
    } else {
      rbLogbookSize = _rbDistance(
        rbLogbookFirst,
        rbLogbookEndAddr,
        logbookBegin,
        logbookEnd,
      );
    }

    final entryCount = rbLogbookSize ~/ entrySize;
    _log.info(
      'Logbook: $rbLogbookSize bytes, $entryCount entries '
      '(end=0x${rbLogbookEndAddr.toRadixString(16)})',
    );

    if (rbLogbookSize == 0) return [];

    // Iterate logbook entries forward (oldest to newest) and collect dives.
    // We start at rbLogbookFirst and advance by entrySize, wrapping at the
    // logbook boundaries.
    final dives = <List<int>>[];
    var validCount = 0;
    var skippedCount = 0;

    // Determine the starting offset for forward iteration.
    int iterOffset;
    if (rbLogbookFirst >= logbookBegin && rbLogbookFirst < logbookEnd) {
      iterOffset = rbLogbookFirst;
    } else {
      // Invalid first pointer - start from beginning of logbook area
      iterOffset = _rbIncrement(rbLogbookEndAddr, 0, logbookBegin, logbookEnd);
    }

    for (var i = 0; i < entryCount; i++) {
      if (iterOffset + entrySize > memory.length) break;

      final entry = memory.sublist(iterOffset, iterOffset + entrySize);

      // Skip uninitialized entries (all 0xFF).
      if (entry.every((b) => b == 0xFF)) {
        skippedCount++;
        iterOffset = _rbIncrement(
          iterOffset,
          entrySize,
          logbookBegin,
          logbookEnd,
        );
        continue;
      }

      // Extract profile pointers based on pt_mode_logbook.
      final profileFirst = _getProfilePointer(
        entry,
        ptMode,
        true,
        pointerMask,
        profilePageSize,
        _layout.highmem,
      );
      final profileLast = _getProfilePointer(
        entry,
        ptMode,
        false,
        pointerMask,
        profilePageSize,
        _layout.highmem,
      );

      // Validate pointers against profile ringbuffer range.
      if (profileFirst < profileBegin ||
          profileFirst >= profileEnd ||
          profileLast < profileBegin ||
          profileLast >= profileEnd) {
        _log.warning(
          'Entry $i: invalid profile pointers '
          '(first=0x${profileFirst.toRadixString(16)}, '
          'last=0x${profileLast.toRadixString(16)})',
        );
        skippedCount++;
        iterOffset = _rbIncrement(
          iterOffset,
          entrySize,
          logbookBegin,
          logbookEnd,
        );
        continue;
      }

      // Calculate profile data size (handles ringbuffer wrapping).
      final profileSize =
          _rbDistance(profileFirst, profileLast, profileBegin, profileEnd) +
          profilePageSize;

      // Extract profile data from the ringbuffer.
      final profileData = _extractFromRingbuffer(
        memory,
        profileFirst,
        profileSize,
        profileBegin,
        profileEnd,
      );

      // Prepend the logbook entry to the profile data. This is what
      // libdivecomputer's parser expects: [logbook_entry][profile_data].
      final diveData = [...entry, ...profileData];
      dives.add(diveData);
      validCount++;

      iterOffset = _rbIncrement(
        iterOffset,
        entrySize,
        logbookBegin,
        logbookEnd,
      );
    }

    _log.info(
      'Extracted $validCount dive data blocks '
      '($skippedCount entries skipped)',
    );
    return dives;
  }

  /// Extract a profile pointer (first or last) from a logbook entry.
  ///
  /// Mirrors libdivecomputer's get_profile_first() / get_profile_last().
  static int _getProfilePointer(
    List<int> entry,
    int ptMode,
    bool isFirst,
    int mask,
    int pageSize,
    int highmem,
  ) {
    int raw;

    if (isFirst) {
      if (ptMode == 0) {
        // LE16 at offset 5, shared byte 6
        raw = entry[5] | (entry[6] << 8);
      } else {
        // LE16 at offset 4
        raw = entry[4] | (entry[5] << 8);
      }
    } else {
      if (ptMode == 0) {
        // LE16 at offset 6, shifted right 4 bits
        raw = (entry[6] | (entry[7] << 8)) >> 4;
      } else {
        // LE16 at offset 6
        raw = entry[6] | (entry[7] << 8);
      }
    }

    return highmem + (raw & mask) * pageSize;
  }

  /// Ringbuffer forward distance from [a] to [b].
  static int _rbDistance(int a, int b, int begin, int end) {
    if (a <= b) return b - a;
    return (end - a) + (b - begin);
  }

  /// Increment an address within a ringbuffer by [amount].
  static int _rbIncrement(int address, int amount, int begin, int end) {
    var result = address + amount;
    if (result >= end) result = begin + (result - end);
    return result;
  }

  /// Extract [size] bytes starting at [start] from a ringbuffer region,
  /// handling wrapping from [end] back to [begin].
  static List<int> _extractFromRingbuffer(
    List<int> memory,
    int start,
    int size,
    int begin,
    int end,
  ) {
    final data = <int>[];
    var remaining = size;
    var offset = start;

    while (remaining > 0) {
      final available = end - offset;
      final chunk = remaining < available ? remaining : available;
      if (offset + chunk > memory.length) {
        // Memory too short - take what we can.
        final safe = memory.length - offset;
        if (safe > 0) data.addAll(memory.sublist(offset, offset + safe));
        break;
      }
      data.addAll(memory.sublist(offset, offset + chunk));
      remaining -= chunk;
      offset = begin; // wrap to start of ringbuffer
    }

    return data;
  }

  /// Disconnect from the device.
  Future<void> disconnect() async {
    _isConnected = false;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _resetPendingResponse();
    _log.info('Disconnected from Aqualung device');
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _responseController.close();
  }
}

class _AqualungMemoryLayout {
  final int memorySize;

  /// Address of the pointer page containing logbook/profile ringbuffer state.
  /// Bytes 4-5 (LE): oldest logbook entry address.
  /// Bytes 6-7 (LE): newest logbook entry address.
  /// All Oceanic/Aqualung models use 0x0040 for cf_pointers.
  final int cfPointers = 0x0040;

  /// Start address of the logbook ringbuffer.
  final int logbookBegin;

  /// Size of each logbook entry in bytes.
  final int logbookEntrySize;

  /// Start address of the profile ringbuffer.
  final int profileBegin;

  /// End address of the profile ringbuffer (exclusive).
  final int profileEnd;

  /// High memory boundary (non-zero for models like i770R).
  /// Affects profile page size calculation (16 vs 256 bytes).
  final int highmem;

  /// Profile pointer extraction mode from logbook entries:
  ///   0: first=LE16(entry+5), last=LE16(entry+6)>>4
  ///   1: first=LE16(entry+4), last=LE16(entry+6)
  final int ptModeLogbook;

  final int pageMultiplier;
  final int checksumBytes;
  final int readCommand;
  final String parserProduct;

  const _AqualungMemoryLayout({
    required this.memorySize,
    this.logbookBegin = 0x0240,
    this.logbookEntrySize = 8,
    required this.profileBegin,
    required this.profileEnd,
    this.highmem = 0,
    this.ptModeLogbook = 0,
    required this.pageMultiplier,
    required this.checksumBytes,
    required this.readCommand,
    required this.parserProduct,
  });

  factory _AqualungMemoryLayout.defaultLayout() {
    return const _AqualungMemoryLayout(
      memorySize: 0x10000,
      profileBegin: 0x0A40,
      profileEnd: 0xFE00,
      pageMultiplier: 1,
      checksumBytes: 1,
      readCommand: cmdRead1,
      parserProduct: 'i300C',
    );
  }

  /// Match the version string to the correct memory layout.
  ///
  /// Layout values are taken directly from libdivecomputer's oceanic_atom2.c
  /// version table and oceanic_common_layout_t structs.
  factory _AqualungMemoryLayout.fromVersion(String version) {
    final normalized = version.toUpperCase();

    // Aqualung i300C -> oceanic_atom2b_layout
    if (normalized.contains('AQUA300C')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x10000,
        logbookBegin: 0x0240,
        profileBegin: 0x0A40,
        profileEnd: 0xFE00,
        pageMultiplier: 1,
        checksumBytes: 1,
        readCommand: cmdRead1,
        parserProduct: 'i300C',
      );
    }

    // Aqualung i300 -> oceanic_atom2b_layout
    if (normalized.contains('AQUAI300')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x10000,
        logbookBegin: 0x0240,
        profileBegin: 0x0A40,
        profileEnd: 0xFE00,
        pageMultiplier: 1,
        checksumBytes: 1,
        readCommand: cmdRead1,
        parserProduct: 'i300',
      );
    }

    // Aqualung i200 / i200C -> oceanic_atom2a_layout (512K) or
    // oceanic_oc1_layout (1024) depending on memory size suffix.
    // The 512K variant is detected first; 1024 falls through below.
    if (normalized.contains('AQUAI200') || normalized.contains('AQUA200C')) {
      if (normalized.contains('1024')) {
        // i200C v2 -> oceanic_oc1_layout
        return const _AqualungMemoryLayout(
          memorySize: 0x20000,
          logbookBegin: 0x0240,
          profileBegin: 0x0A40,
          profileEnd: 0x1FE00,
          ptModeLogbook: 1,
          pageMultiplier: 16,
          checksumBytes: 2,
          readCommand: cmdRead16,
          parserProduct: 'i200C',
        );
      }
      return const _AqualungMemoryLayout(
        memorySize: 0xFFF0,
        logbookBegin: 0x0240,
        profileBegin: 0x0A40,
        profileEnd: 0xFE00,
        pageMultiplier: 1,
        checksumBytes: 1,
        readCommand: cmdRead1,
        parserProduct: 'i200C',
      );
    }

    // Aqualung i550 / i550C -> oceanic_oc1_layout
    if (normalized.contains('AQUAI550') || normalized.contains('AQUA550C')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x20000,
        logbookBegin: 0x0240,
        profileBegin: 0x0A40,
        profileEnd: 0x1FE00,
        ptModeLogbook: 1,
        pageMultiplier: 16,
        checksumBytes: 2,
        readCommand: cmdRead16,
        parserProduct: 'i550C',
      );
    }

    // Aqualung i470TC -> oceanic_oc1_layout
    if (normalized.contains('AQUA470C')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x20000,
        logbookBegin: 0x0240,
        profileBegin: 0x0A40,
        profileEnd: 0x1FE00,
        ptModeLogbook: 1,
        pageMultiplier: 16,
        checksumBytes: 2,
        readCommand: cmdRead16,
        parserProduct: 'i470TC',
      );
    }

    // Aqualung i450T -> aqualung_i450t_layout
    if (normalized.contains('AQUAI450')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x40000,
        logbookBegin: 0x10C0,
        logbookEntrySize: 16,
        profileBegin: 0x1400,
        profileEnd: 0x3FE00,
        ptModeLogbook: 1,
        pageMultiplier: 16,
        checksumBytes: 2,
        readCommand: cmdRead16,
        parserProduct: 'i450T',
      );
    }

    // Aqualung i750TC -> aeris_a300cs_layout
    if (normalized.contains('AQUAI750')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x40000,
        logbookBegin: 0x0900,
        logbookEntrySize: 16,
        profileBegin: 0x1000,
        profileEnd: 0x3FE00,
        ptModeLogbook: 1,
        pageMultiplier: 16,
        checksumBytes: 2,
        readCommand: cmdRead16,
        parserProduct: 'i750TC',
      );
    }

    // Aqualung i770R -> aqualung_i770r_layout
    if (normalized.contains('AQUA770R')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x640000,
        logbookBegin: 0x2000,
        logbookEntrySize: 16,
        profileBegin: 0x40000,
        profileEnd: 0x640000,
        highmem: 0x40000,
        ptModeLogbook: 1,
        pageMultiplier: 16,
        checksumBytes: 2,
        readCommand: cmdRead16High,
        parserProduct: 'i770R',
      );
    }

    // Fallback by memory size suffix (matches libdivecomputer's fallback)
    if (normalized.contains('1024')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x20000,
        logbookBegin: 0x0240,
        profileBegin: 0x0A40,
        profileEnd: 0x1FE00,
        ptModeLogbook: 1,
        pageMultiplier: 16,
        checksumBytes: 2,
        readCommand: cmdRead16,
        parserProduct: 'i550C',
      );
    }

    if (normalized.contains('2048')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x40000,
        logbookBegin: 0x0780,
        profileBegin: 0x1000,
        profileEnd: 0x40000,
        ptModeLogbook: 1,
        pageMultiplier: 16,
        checksumBytes: 2,
        readCommand: cmdRead16,
        parserProduct: 'i450T',
      );
    }

    if (normalized.contains('512K')) {
      return const _AqualungMemoryLayout(
        memorySize: 0x10000,
        logbookBegin: 0x0240,
        profileBegin: 0x0A40,
        profileEnd: 0xFE00,
        pageMultiplier: 1,
        checksumBytes: 1,
        readCommand: cmdRead1,
        parserProduct: 'i300C',
      );
    }

    return _AqualungMemoryLayout.defaultLayout();
  }
}

class _ProtocolException implements Exception {
  final String message;
  const _ProtocolException(this.message);

  @override
  String toString() => message;
}

class _UnsupportedCommandException extends _ProtocolException {
  const _UnsupportedCommandException(super.message);
}
