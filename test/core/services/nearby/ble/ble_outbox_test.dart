import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/ble/ble_outbox.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';

Uint8List _b(int n, [int start = 0]) =>
    Uint8List.fromList(List.generate(n, (i) => (start + i) % 256));

void main() {
  test(
    'reads hand out queued bytes in order, at most maxLength each',
    () async {
      final box = BleOutbox();
      await box.enqueue(_b(5));
      await box.enqueue(_b(5, 5));
      final got = <int>[];
      for (
        var chunk = box.read(offset: 0, maxLength: 4, platformSlices: false);
        chunk.isNotEmpty;
        chunk = box.read(offset: 0, maxLength: 4, platformSlices: false)
      ) {
        expect(chunk.length, lessThanOrEqualTo(4));
        got.addAll(chunk);
      }
      expect(got, _b(10));
    },
  );

  test('an empty outbox reads as no bytes', () {
    expect(
      BleOutbox().read(offset: 0, maxLength: 20, platformSlices: false),
      isEmpty,
    );
  });

  test('a continued read returns the same chunk, sliced as the platform '
      'needs', () async {
    final box = BleOutbox();
    await box.enqueue(_b(8));
    final first = box.read(offset: 0, maxLength: 8, platformSlices: false);
    expect(first, _b(8));
    // Apple slices the value it is given by the offset itself.
    expect(box.read(offset: 3, maxLength: 8, platformSlices: true), _b(8));
    // Android sends exactly what it is given.
    expect(box.read(offset: 3, maxLength: 8, platformSlices: false), _b(5, 3));
  });

  test('enqueue waits while more than the high water mark is queued', () async {
    final box = BleOutbox(highWater: 10);
    var done = false;
    final pending = box.enqueue(_b(30)).then((_) => done = true);
    await pumpEventQueue();
    expect(done, isFalse);
    box.read(offset: 0, maxLength: 15, platformSlices: false);
    await pumpEventQueue();
    expect(done, isFalse, reason: '15 still queued');
    box.read(offset: 0, maxLength: 10, platformSlices: false);
    await pending;
    expect(done, isTrue);
  });

  test('closing fails a waiting enqueue and refuses new bytes', () async {
    final box = BleOutbox(highWater: 4);
    final pending = box.enqueue(_b(10));
    box.close();
    await expectLater(pending, throwsA(isA<NearbyLinkClosed>()));
    await expectLater(box.enqueue(_b(1)), throwsA(isA<NearbyLinkClosed>()));
  });

  test('drained completes once the central has read every queued byte, '
      'so a closing peripheral can let its last frames out', () async {
    final box = BleOutbox();
    await box.enqueue(_b(10));
    var drained = false;
    final wait = box.drained.then((_) => drained = true);
    box.read(offset: 0, maxLength: 4, platformSlices: false);
    await pumpEventQueue();
    expect(drained, isFalse, reason: '6 bytes still waiting');
    box.read(offset: 0, maxLength: 10, platformSlices: false);
    await wait;
    expect(drained, isTrue);
  });

  test('drained completes at once when nothing waits, and when the outbox '
      'closes', () async {
    await BleOutbox().drained;
    final box = BleOutbox();
    await box.enqueue(_b(5));
    final wait = box.drained;
    box.close();
    await wait;
  });

  test('wasEmpty reports the transition the doorbell rings on', () async {
    final box = BleOutbox();
    expect(box.isEmpty, isTrue);
    await box.enqueue(_b(3));
    expect(box.isEmpty, isFalse);
    box.read(offset: 0, maxLength: 10, platformSlices: false);
    expect(box.isEmpty, isTrue);
  });
}
