import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

/// Feeds [chunks] into a fresh decoder and collects what it emits, values
/// and errors alike, in order.
Future<List<Object>> _decode(
  List<Uint8List> chunks, {
  int maxFrameBytes = 1 << 20,
}) async {
  final decoder = FrameDecoder(maxFrameBytes: maxFrameBytes);
  final seen = <Object>[];
  final done = Completer<void>();
  decoder.messages.listen(
    seen.add,
    onError: (Object e) => seen.add(e),
    onDone: done.complete,
  );
  for (final chunk in chunks) {
    decoder.add(chunk);
  }
  await decoder.close();
  await done.future;
  return seen;
}

void main() {
  group('FrameEncoder', () {
    test(
      'writes a big-endian length of type plus body, then type, then body',
      () {
        final frame = FrameEncoder.encode(
          NearbyMessageType.watermarks,
          _bytes([0xAA, 0xBB]),
        );
        expect(frame, [
          0,
          0,
          0,
          3,
          NearbyMessageType.watermarks.code,
          0xAA,
          0xBB,
        ]);
      },
    );
  });

  group('FrameDecoder', () {
    test(
      'encode then decode round-trips one message split at every index',
      () async {
        final body = _bytes(List.generate(40, (i) => i));
        final frame = FrameEncoder.encode(NearbyMessageType.changeset, body);
        for (var cut = 0; cut <= frame.length; cut++) {
          final seen = await _decode([
            Uint8List.sublistView(frame, 0, cut),
            Uint8List.sublistView(frame, cut),
          ]);
          expect(seen, hasLength(1), reason: 'cut at $cut');
          final message = seen.single as NearbyMessage;
          expect(message.type, NearbyMessageType.changeset);
          expect(message.body, body);
        }
      },
    );

    test('decoder reassembles two messages from one chunk', () async {
      final a = FrameEncoder.encode(NearbyMessageType.hello, _bytes([1]));
      final b = FrameEncoder.encode(NearbyMessageType.bye, _bytes([]));
      final seen = await _decode([
        _bytes([...a, ...b]),
      ]);
      expect(seen.map((m) => (m as NearbyMessage).type), [
        NearbyMessageType.hello,
        NearbyMessageType.bye,
      ]);
      expect((seen.last as NearbyMessage).body, isEmpty);
    });

    test('decoder rejects a frame longer than maxFrameBytes', () async {
      // A declared length of 2 GB: the decoder must refuse it from the
      // header alone, never trying to buffer that much.
      final huge = _bytes([0x7F, 0xFF, 0xFF, 0xFF, 1, 2, 3]);
      final seen = await _decode([huge], maxFrameBytes: 1024);
      expect(seen, hasLength(1));
      expect(seen.single, isA<FrameTooLarge>());
      expect((seen.single as FrameTooLarge).declaredBytes, 0x7FFFFFFF);
    });

    test(
      'decoder keeps working after an oversized frame on a fresh buffer',
      () async {
        // After FrameTooLarge the stream of bytes is no longer framed, so the
        // decoder drops everything it holds; a frame that starts in a later
        // chunk decodes normally.
        final huge = _bytes([0x7F, 0xFF, 0xFF, 0xFF, 1, 2, 3]);
        final ok = FrameEncoder.encode(NearbyMessageType.bye, _bytes([]));
        final seen = await _decode([huge, ok], maxFrameBytes: 1024);
        expect(seen.first, isA<FrameTooLarge>());
        expect((seen.last as NearbyMessage).type, NearbyMessageType.bye);
      },
    );

    test(
      'an unknown type code is reported and the next frame still decodes',
      () async {
        final unknown = _bytes([0, 0, 0, 2, 200, 9]);
        final ok = FrameEncoder.encode(NearbyMessageType.applied, _bytes([5]));
        final seen = await _decode([
          _bytes([...unknown, ...ok]),
        ]);
        expect(seen.first, isA<UnknownMessageType>());
        expect((seen.first as UnknownMessageType).code, 200);
        final message = seen.last as NearbyMessage;
        expect(message.type, NearbyMessageType.applied);
        expect(message.body, [5]);
      },
    );

    test(
      'a zero declared length is a malformed frame, not a message',
      () async {
        final seen = await _decode([
          _bytes([0, 0, 0, 0]),
        ]);
        expect(seen.single, isA<FrameMalformed>());
      },
    );
  });

  group('NearbyMessageType', () {
    test('fromCode maps every code back and unknown codes to null', () {
      for (final t in NearbyMessageType.values) {
        expect(NearbyMessageType.fromCode(t.code), t);
      }
      expect(NearbyMessageType.fromCode(0), isNull);
      expect(NearbyMessageType.fromCode(255), isNull);
    });
  });

  test('a large frame fed in tiny chunks decodes in linear time', () async {
    // A 20-byte MTU before the exchange: 1 MiB arrives as 52 429 chunks.
    // Copying the whole partial frame on every chunk is tens of GB.
    final body = Uint8List((1 << 20) - 5);
    final frame = FrameEncoder.encode(NearbyMessageType.basePart, body);
    final chunks = [
      for (var i = 0; i < frame.length; i += 20)
        Uint8List.sublistView(
          frame,
          i,
          i + 20 > frame.length ? frame.length : i + 20,
        ),
    ];
    final watch = Stopwatch()..start();
    final seen = await _decode(chunks, maxFrameBytes: 1 << 20);
    watch.stop();
    expect((seen.single as NearbyMessage).body.length, body.length);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
