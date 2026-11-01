import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';
// ignore: implementation_imports
import 'package:universal_ble/src/universal_ble.g.dart' show PeripheralService;
// ignore: implementation_imports
import 'package:universal_ble/src/universal_ble_pigeon/universal_ble_pigeon_channel.dart';

/// Stand-ins for CoreBluetooth at universal_ble's platform layer (issue
/// #4093). They keep the behaviour a real Apple radio has and the in-memory
/// nearby carrier cannot show: what is dropped before power-on, and one
/// callback serving both read answers and notifications.
///
/// Puts [central] and [peripheral] in place of the plugin until the test
/// ends. The plugin keeps no way to read its current platform, so the
/// restore names the one a host running tests starts with. Register a
/// carrier's dispose after this, so it runs first.
void useFakeBleRadio({
  FakeAppleCentral? central,
  FakeApplePeripheralManager? peripheral,
}) {
  if (central != null) UniversalBle.setInstance(central);
  if (peripheral != null) UniversalBlePeripheral.setInstance(peripheral);
  addTearDown(() {
    if (central != null) {
      UniversalBle.setInstance(UniversalBlePigeonChannel.instance);
    }
    if (peripheral != null) {
      UniversalBlePeripheral.setInstance(UniversalBlePeripheralUnsupported());
    }
  });
}

/// A `CBPeripheralManager` behind universal_ble's Apple plugin.
///
/// [database] is what CoreBluetooth hosts; [registry] is the plugin's own
/// list, which records a service whether or not CoreBluetooth took it, and
/// survives Bluetooth going off.
class FakeApplePeripheralManager extends UniversalBlePeripheralPlatform {
  PeripheralReadinessState state = PeripheralReadinessState.unknown;
  final database = <PeripheralService>[];
  final registry = <String>{};
  final rungCharacteristics = <String>[];
  bool advertising = false;

  /// The next add fails after power-on, as `didAdd` reporting an error does.
  bool failNextAdd = false;

  /// The one hosted service's id, for a test to name what it expects.
  String get hostedServiceUuid => database.single.uuid;

  /// The properties a hosted characteristic was declared with.
  List<CharacteristicProperty> propertiesOf(String characteristicUuid) =>
      database.single.characteristics
          .singleWhere((c) => c.uuid == characteristicUuid)
          .properties;

  void powerOn() => state = PeripheralReadinessState.ready;

  /// Bluetooth off: advertising stops and CoreBluetooth empties its local
  /// database, but nothing tells the plugin's list.
  void bluetoothOff() {
    state = PeripheralReadinessState.bluetoothOff;
    database.clear();
    advertising = false;
  }

  void subscribe(String deviceId, String characteristicId) {
    updateCharacteristicSubscription(
      BlePeripheralCharacteristicSubscriptionChanged(
        deviceId: deviceId,
        characteristicId: characteristicId,
        isSubscribed: true,
        name: null,
      ),
    );
  }

  @override
  Future<PeripheralReadinessState> getAvailabilityState() async => state;

  /// A command before power-on never reports back, so the plugin gives up
  /// on its own timeout; the plugin's list keeps the service regardless.
  @override
  Future<void> addService(
    PeripheralService service, {
    Duration? timeout,
  }) async {
    registry.add(service.uuid);
    if (state != PeripheralReadinessState.ready || failNextAdd) {
      failNextAdd = false;
      throw PlatformException(
        code: 'service-add-failed',
        message: 'Service add timed out',
      );
    }
    database.add(service);
  }

  @override
  Future<void> clearServices() async {
    if (state == PeripheralReadinessState.ready) database.clear();
    registry.clear();
  }

  @override
  Future<List<String>> getServices() async => [
    for (final uuid in registry) uuid.toUpperCase(),
  ];

  @override
  Future<void> startAdvertising({
    required List<String> services,
    String? localName,
    Duration? timeout,
    ManufacturerData? manufacturerData,
    PeripheralPlatformConfig? platformConfig,
  }) async {
    advertising = state == PeripheralReadinessState.ready;
  }

  @override
  Future<void> stopAdvertising() async => advertising = false;

  @override
  Future<void> updateCharacteristicValue({
    required String characteristicId,
    required Uint8List value,
    String? deviceId,
  }) async => rungCharacteristics.add(characteristicId);

  @override
  Future<int?> getMaximumNotifyLength(String deviceId) async => 182;

  @override
  void setReadRequestHandler(OnPeripheralReadRequest? handler) {}

  @override
  void setWriteRequestHandler(OnPeripheralWriteRequest? handler) {}

  @override
  void setDescriptorReadRequestHandler(
    OnPeripheralDescriptorReadRequest? handler,
  ) {}

  @override
  void setDescriptorWriteRequestHandler(
    OnPeripheralDescriptorWriteRequest? handler,
  ) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A `CBCentralManager` connected to one peer, behind universal_ble's Apple
/// plugin.
///
/// CoreBluetooth has one callback for a read answer and a notification
/// alike, and the plugin handles it the same way either way: a subscribed
/// characteristic reports the value to the notification stream, and the
/// oldest outstanding read of that characteristic takes it as its answer.
class FakeAppleCentral extends UniversalBlePlatform {
  /// What the peer has to send, one read answer at a time.
  final peerOutbox = Queue<Uint8List>();

  /// Characteristics this central has subscribed to.
  final subscribed = <String>{};
  int reads = 0;

  /// Leaves reads outstanding until [releaseReads].
  bool holdReads = false;
  final _outstanding =
      <({String characteristic, Completer<Uint8List> answer})>[];

  int get outstandingReads => _outstanding.length;

  /// The peer rings: a one-byte notification on whatever is subscribed.
  void peerRings(String deviceId) {
    for (final characteristic in subscribed) {
      _didUpdateValue(deviceId, characteristic, Uint8List.fromList(const [1]));
    }
  }

  void releaseReads(String deviceId) {
    holdReads = false;
    for (final read in _outstanding.toList()) {
      _didUpdateValue(deviceId, read.characteristic, _nextAnswer());
    }
  }

  Uint8List _nextAnswer() =>
      peerOutbox.isEmpty ? Uint8List(0) : peerOutbox.removeFirst();

  void _didUpdateValue(
    String deviceId,
    String characteristic,
    Uint8List value,
  ) {
    if (subscribed.contains(characteristic)) {
      updateCharacteristicValue(deviceId, characteristic, value, null);
    }
    final index = _outstanding.indexWhere(
      (read) => read.characteristic == characteristic,
    );
    if (index >= 0) _outstanding.removeAt(index).answer.complete(value);
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async => updateConnection(deviceId, true);

  @override
  Future<void> disconnect(String deviceId) async =>
      updateConnection(deviceId, false);

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async =>
      BleConnectionState.connected;

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors, {
    DiscoverServicesPlatformConfig? platformConfig,
  }) async => [BleService(serviceUuid, const [])];

  /// The service [discoverServices] finds.
  String serviceUuid = '';

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async => 247;

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async => subscribed.add(characteristic);

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) {
    reads++;
    final answer = Completer<Uint8List>();
    _outstanding.add((characteristic: characteristic, answer: answer));
    if (!holdReads) {
      Timer.run(() {
        if (!answer.isCompleted) {
          _didUpdateValue(deviceId, characteristic, _nextAnswer());
        }
      });
    }
    return answer.future;
  }

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
