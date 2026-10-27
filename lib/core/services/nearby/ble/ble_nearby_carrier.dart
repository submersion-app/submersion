import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/ble/ble_chunker.dart';
import 'package:submersion/core/services/nearby/ble/ble_outbox.dart';
import 'package:submersion/core/services/nearby/ble/nearby_gatt.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';

/// The nearby link over Bluetooth LE.
///
/// As a central (every platform) it scans for the Submersion service,
/// connects, writes its bytes to the inbox and reads the peer's bytes from
/// the outbox. As a peripheral (all but Linux) it hosts the service and
/// turns each central that subscribes or writes into an incoming endpoint.
///
/// Both directions are flow-controlled by the link itself: writes with
/// response one way, reads the other. A one-byte outbox notification only
/// rings the central's doorbell when bytes are waiting; a slow poll covers
/// a doorbell the platform dropped.
///
/// Tested on real devices only (see the spec's manual checklist); every
/// layer above it runs against the in-memory carrier in CI.
class BleNearbyCarrier implements NearbyCarrier {
  BleNearbyCarrier({this.writeWithoutResponse = false});

  /// Central writes without an acknowledgement are faster but can be
  /// dropped when a platform's buffer is full; a lost chunk ends the
  /// session (the frame or the cipher fails) and a full copy resumes.
  final bool writeWithoutResponse;

  static final _log = LoggerService.forClass(BleNearbyCarrier);

  final _sightings = StreamController<NearbyPeerSighting>.broadcast();
  final _incoming = StreamController<NearbyEndpoint>.broadcast();
  final _peripheralEnds = <String, _PeripheralEnd>{};
  StreamSubscription<BleDevice>? _scanSub;
  final _peripheralSubs = <StreamSubscription<Object?>>[];
  bool _serviceAdded = false;

  @override
  bool get canAdvertise => BleCapabilities.supportsPeripheralApi;

  @override
  Stream<NearbyPeerSighting> get sightings => _sightings.stream;

  @override
  Stream<NearbyEndpoint> get incoming => _incoming.stream;

  @override
  Stream<NearbyAvailability> get availability =>
      UniversalBle.availabilityStream.map(_map);

  static NearbyAvailability _map(AvailabilityState state) => switch (state) {
    AvailabilityState.poweredOn => NearbyAvailability.ready,
    AvailabilityState.unauthorized => NearbyAvailability.unauthorized,
    AvailabilityState.unsupported => NearbyAvailability.unsupported,
    AvailabilityState.poweredOff ||
    AvailabilityState.resetting ||
    AvailabilityState.unknown => NearbyAvailability.bluetoothOff,
  };

  @override
  Future<NearbyAvailability> checkAvailability() async {
    try {
      if (BleCapabilities.requiresRuntimePermission &&
          !await UniversalBle.hasPermissions()) {
        await UniversalBle.requestPermissions();
        if (!await UniversalBle.hasPermissions()) {
          return NearbyAvailability.unauthorized;
        }
      }
      return _map(await UniversalBle.getBluetoothAvailabilityState());
    } on Object catch (e) {
      _log.warning('Bluetooth availability check failed: $e');
      return NearbyAvailability.unsupported;
    }
  }

  // -------------------------------------------------------------------
  // Central

  @override
  Future<void> startScanning() async {
    await _scanSub?.cancel();
    _scanSub = UniversalBle.scanStream.listen((device) {
      if (!device.services.contains(nearbyServiceUuid)) return;
      _sightings.add(
        NearbyPeerSighting(
          transportId: device.deviceId,
          seenAt: DateTime.now(),
        ),
      );
    });
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [nearbyServiceUuid]),
    );
  }

  @override
  Future<void> stopScanning() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await UniversalBle.stopScan();
    } on Object catch (e) {
      _log.info('Stopping the nearby scan failed: $e');
    }
  }

  @override
  Future<NearbyEndpoint> connect(String transportId) async {
    try {
      await UniversalBle.connect(
        transportId,
        timeout: const Duration(seconds: 15),
      );
      final mtu = await UniversalBle.requestMtu(transportId, 517);
      final services = await UniversalBle.discoverServices(transportId);
      if (!services.any((s) => s.uuid == nearbyServiceUuid)) {
        await UniversalBle.disconnect(transportId);
        throw NearbyConnectFailed('$transportId has no Submersion service');
      }
      final end = _CentralEnd(
        transportId,
        mtu: mtu,
        withoutResponse: writeWithoutResponse,
      );
      await UniversalBle.subscribeNotifications(
        transportId,
        nearbyServiceUuid,
        nearbyOutboxUuid,
      );
      return end;
    } on NearbyConnectFailed {
      rethrow;
    } on Object catch (e) {
      try {
        await UniversalBle.disconnect(transportId);
      } on Object {
        // Already gone.
      }
      throw NearbyConnectFailed('$e');
    }
  }

  // -------------------------------------------------------------------
  // Peripheral

  @override
  Future<void> startAdvertising() async {
    if (!canAdvertise) {
      throw UnsupportedError('This platform cannot host the nearby service');
    }
    if (!_serviceAdded) {
      await UniversalBlePeripheral.addService(
        BlePeripheralService(
          uuid: nearbyServiceUuid,
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: nearbyInboxUuid,
              properties: const [
                CharacteristicProperty.write,
                CharacteristicProperty.writeWithoutResponse,
              ],
              permissions: const [PeripheralAttributePermission.writeable],
            ),
            BlePeripheralCharacteristic(
              uuid: nearbyOutboxUuid,
              properties: const [
                CharacteristicProperty.read,
                CharacteristicProperty.notify,
              ],
              permissions: const [PeripheralAttributePermission.readable],
            ),
          ],
        ),
      );
      UniversalBlePeripheral.setWriteRequestHandlers((
        deviceId,
        characteristicId,
        offset,
        value,
      ) {
        if (characteristicId.toLowerCase() == nearbyInboxUuid &&
            value != null) {
          _peripheralEnd(deviceId).feed(value);
        }
        return null;
      });
      UniversalBlePeripheral.setReadRequestHandlers((
        deviceId,
        characteristicId,
        offset,
        value,
      ) {
        final end = characteristicId.toLowerCase() == nearbyOutboxUuid
            ? _peripheralEnds[deviceId]
            : null;
        if (end == null) {
          return PeripheralReadRequestResult(value: Uint8List(0));
        }
        return PeripheralReadRequestResult(
          value: end.answerRead(offset),
          offset: offset,
        );
      });
      _peripheralSubs.addAll([
        UniversalBlePeripheral.characteristicSubscriptionStream.listen((e) {
          if (e.characteristicId.toLowerCase() != nearbyOutboxUuid) return;
          if (e.isSubscribed) {
            _peripheralEnd(e.deviceId);
          } else {
            _peripheralEnds.remove(e.deviceId)?.drop();
          }
        }),
        UniversalBlePeripheral.connectionStateStream.listen((e) {
          if (!e.connected) _peripheralEnds.remove(e.deviceId)?.drop();
        }),
        UniversalBlePeripheral.mtuChangedStream.listen((e) {
          _peripheralEnds[e.deviceId]?.readLength = _readLengthFor(e.mtu);
        }),
      ]);
      _serviceAdded = true;
    }
    await UniversalBlePeripheral.startAdvertising(
      services: [nearbyServiceUuid],
    );
  }

  @override
  Future<void> stopAdvertising() async {
    if (!canAdvertise || !_serviceAdded) return;
    try {
      await UniversalBlePeripheral.stopAdvertising();
    } on Object catch (e) {
      _log.info('Stopping nearby advertising failed: $e');
    }
  }

  /// The largest read answer that cannot trigger a long read: an ATT read
  /// response holds MTU - 1 bytes, and one that fills it invites the
  /// central to ask for more.
  static int _readLengthFor(int mtu) => (mtu - 4).clamp(19, 508);

  /// The endpoint for a central, created on its first subscription or
  /// write, whichever arrives first.
  _PeripheralEnd _peripheralEnd(String deviceId) {
    final existing = _peripheralEnds[deviceId];
    if (existing != null) return existing;
    final end = _PeripheralEnd(
      deviceId,
      onClosed: () => _peripheralEnds.remove(deviceId),
    );
    _peripheralEnds[deviceId] = end;
    // Apple reports no MTU event to a peripheral; the notify limit is the
    // MTU less its 3-byte header, so a read answer one byte under it is safe.
    unawaited(
      UniversalBlePeripheral.getMaximumNotifyLength(deviceId).then((limit) {
        if (limit != null) end.readLength = (limit - 1).clamp(19, 508);
      }, onError: (Object _) {}),
    );
    _incoming.add(end);
    return end;
  }
}

/// This device as the central: writes to the peer's inbox, reads its
/// outbox whenever the doorbell rings or the poll comes round.
class _CentralEnd implements NearbyEndpoint {
  _CentralEnd(
    this.transportId, {
    required this.mtu,
    required this.withoutResponse,
  }) {
    _doorbellSub = UniversalBle.characteristicValueStream(
      transportId,
      nearbyOutboxUuid,
    ).listen((_) => _pump());
    _connectionSub = UniversalBle.connectionStream(transportId).listen((up) {
      if (!up) _drop();
    });
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) => _pump());
  }

  @override
  final String transportId;
  final int mtu;
  final bool withoutResponse;
  final _inbound = StreamController<Uint8List>();
  late final StreamSubscription<Uint8List> _doorbellSub;
  late final StreamSubscription<bool> _connectionSub;
  late final Timer _poll;
  bool _closed = false;
  bool _pumping = false;
  bool _again = false;

  @override
  bool get isInitiator => true;

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  /// Reads the outbox until the peer has nothing waiting. A doorbell that
  /// rings mid-pump runs one more round instead of a second pump.
  Future<void> _pump() async {
    if (_closed) return;
    if (_pumping) {
      _again = true;
      return;
    }
    _pumping = true;
    try {
      do {
        _again = false;
        while (!_closed) {
          final chunk = await UniversalBle.read(
            transportId,
            nearbyServiceUuid,
            nearbyOutboxUuid,
          );
          if (chunk.isEmpty) break;
          _inbound.add(chunk);
        }
      } while (_again && !_closed);
    } on Object {
      _drop();
    } finally {
      _pumping = false;
    }
  }

  @override
  Future<void> send(Uint8List bytes) async {
    if (_closed) throw const NearbyLinkClosed();
    try {
      for (final chunk in BleChunker.split(bytes, mtu)) {
        await UniversalBle.write(
          transportId,
          nearbyServiceUuid,
          nearbyInboxUuid,
          chunk,
          withoutResponse: withoutResponse,
        );
      }
    } on Object {
      _drop();
      throw const NearbyLinkClosed();
    }
  }

  void _drop() {
    if (_closed) return;
    _closed = true;
    _poll.cancel();
    _doorbellSub.cancel();
    _connectionSub.cancel();
    _inbound.close();
  }

  @override
  Future<void> close() async {
    _drop();
    try {
      await UniversalBle.disconnect(transportId);
    } on Object {
      // Already gone.
    }
  }
}

/// A central connected to this device: its inbox writes are the inbound
/// stream, and what this device sends waits in an outbox for its reads.
class _PeripheralEnd implements NearbyEndpoint {
  _PeripheralEnd(this.transportId, {required void Function() onClosed})
    : _onClosed = onClosed;

  @override
  final String transportId;
  final void Function() _onClosed;
  final _inbound = StreamController<Uint8List>();
  final _outbox = BleOutbox();
  int readLength = 19;
  bool _closed = false;

  static final _appleSlices =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool get isInitiator => false;

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  void feed(Uint8List value) {
    if (!_closed) _inbound.add(Uint8List.fromList(value));
  }

  Uint8List answerRead(int offset) => _outbox.read(
    offset: offset,
    maxLength: readLength,
    platformSlices: _appleSlices,
  );

  @override
  Future<void> send(Uint8List bytes) async {
    if (_closed) throw const NearbyLinkClosed();
    final ring = _outbox.isEmpty;
    final queued = _outbox.enqueue(bytes);
    if (ring) unawaited(_ringDoorbell());
    await queued;
  }

  /// Tells the central bytes are waiting. Best effort: a doorbell the
  /// platform drops is covered by the central's poll.
  Future<void> _ringDoorbell() async {
    try {
      await UniversalBlePeripheral.updateCharacteristicValue(
        characteristicId: nearbyOutboxUuid,
        value: Uint8List.fromList(const [1]),
        deviceId: transportId,
      );
    } on Object {
      // Queue full or the central is gone; the poll carries on.
    }
  }

  void drop() {
    if (_closed) return;
    _closed = true;
    _outbox.close();
    _inbound.close();
    _onClosed();
  }

  /// A peripheral cannot hang up on a central; it stops listening, and the
  /// central's own close (after its `bye`) ends the connection.
  @override
  Future<void> close() async => drop();
}
