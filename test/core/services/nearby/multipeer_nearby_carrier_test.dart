import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/multipeer/multipeer_nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';

/// The Dart side of the Multipeer carrier (issue #3728): one method channel
/// both ways, native events arriving as `onEvent` calls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.submersion/multipeer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late MultipeerNearbyCarrier carrier;
  var supported = true;

  setUp(() {
    calls = [];
    supported = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isSupported' => supported,
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    carrier = MultipeerNearbyCarrier(channel: channel);
    addTearDown(carrier.dispose);
  });

  Future<void> nativeSends(Map<String, Object?> event) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('onEvent', event)),
      (_) {},
    );
    await pumpEventQueue();
  }

  test('a found event becomes a sighting', () async {
    final sighting = carrier.sightings.first;
    await nativeSends({'type': 'found', 'peerId': 'p1'});
    expect((await sighting).transportId, 'p1');
  });

  test('scanning and advertising tell the native side', () async {
    await carrier.startAdvertising();
    await carrier.startScanning();
    await carrier.stopScanning();
    await carrier.stopAdvertising();
    expect(calls.map((c) => '${c.method} ${c.arguments}'), [
      'advertise true',
      'browse true',
      'browse false',
      'advertise false',
    ]);
  });

  test(
    'incoming becomes an endpoint whose inbound carries data in order',
    () async {
      final incoming = carrier.incoming.first;
      await nativeSends({'type': 'incoming', 'peerId': 'p1'});
      final end = await incoming;
      expect(end.isInitiator, isFalse);
      expect(end.transportId, 'p1');
      final got = <int>[];
      end.inbound.listen(got.addAll);
      await nativeSends({
        'type': 'data',
        'peerId': 'p1',
        'bytes': Uint8List.fromList([1, 2]),
      });
      await nativeSends({
        'type': 'data',
        'peerId': 'p1',
        'bytes': Uint8List.fromList([3]),
      });
      expect(got, [1, 2, 3]);
    },
  );

  test(
    'connect asks native and gives an initiator endpoint that sends',
    () async {
      final end = await carrier.connect('p2');
      expect(end.isInitiator, isTrue);
      await end.send(Uint8List.fromList([9]));
      expect(calls.map((c) => c.method), ['connect', 'send']);
      expect((calls.last.arguments as Map)['peerId'], 'p2');
      expect((calls.last.arguments as Map)['bytes'], [9]);
    },
  );

  test('closed closes the endpoint and later sends fail', () async {
    final end = await carrier.connect('p3');
    final done = Completer<void>();
    end.inbound.listen(null, onDone: done.complete);
    await nativeSends({'type': 'closed', 'peerId': 'p3'});
    await done.future;
    expect(() => end.send(Uint8List(1)), throwsA(isA<NearbyLinkClosed>()));
  });

  test('closing an endpoint tells native', () async {
    final end = await carrier.connect('p4');
    await end.close();
    expect(calls.last.method, 'close');
    expect((calls.last.arguments as Map)['peerId'], 'p4');
  });

  test('proximity events surface in metres', () async {
    final near = carrier.proximity.first;
    await nativeSends({'type': 'proximity', 'peerId': 'p1', 'meters': 0.12});
    final reading = await near;
    expect(reading.transportId, 'p1');
    expect(reading.meters, closeTo(0.12, 1e-9));
  });

  test('an unsupported device reports unsupported', () async {
    supported = false;
    expect(await carrier.checkAvailability(), NearbyAvailability.unsupported);
  });
}
